-- core/combat.lua — modulo "combat": tracers, hitmarker 2D/3D, damage numbers, target ring,
-- hit particles, hit chams (Tasks 3-8 del combat-vfx-port). Task 1 = solo scaffold: carga,
-- se engancha a provider.onShot/onHit, :_update no-op salvo GV.tweenStep. Sin render aun.
-- Skeleton mirror de core/selffx.lua (misma convencion de modulo Attach-instanciable).
--
-- Task 3 (Hit Tracers, este bloque): port de jujudotlol.lua L13276-13303 (menu) + L13364-13547
-- (beams bank / do_beam_bullet_tracer / do_line_bullet_tracer). Disparo: provider.onShot
-- (origin, hitPos, isLocal) <- LIP.Weapon.fireOne en cada op14.
--
-- Task 4 (Hitmarker 3D + 2D, este bloque): port de jujudotlol.lua L13322-13335 (menu) +
-- L14965-15085 (do_d3_hit_marker, cruz anclada al punto de impacto en world-space) + L15089-15200
-- (do_d2_hit_marker, misma cruz fija en el centro de pantalla). Disparo: provider.onHit
-- (player, part, damage, lethal) <- LIP.onHit. juju duplica los parametros por marker (3D/2D);
-- acá se comparte 1 solo set (Combat_Marker*) para ambos, permitido explicitamente por el brief.
--
-- Task 5 (Damage Numbers, este bloque): port de jujudotlol.lua L13314-13321 (menu) + L14875-
-- 14961 (do_damage_number). Disparo: mismo provider.onHit que Task 4. Texto = SOLO el valor
-- numerico de damage redondeado -- LiP no tiene el string de "razon del resolver" que juju
-- concatena via damage_number_show_ragebot_data; ese toggle/flag NO se porta (brief, nota de
-- adaptacion: no inventar un string equivalente).
--
-- Task 8 (Hit Chams, este bloque -- ULTIMA feature del combat-vfx-port): port de jujudotlol.lua
-- L15205-15211 (menu) + L15319-15473 (do_hit_chams/do_hit_chams_outline + los 3 animadores de
-- destroy). Disparo: mismo provider.onHit que Task 4/5/7, pero solo consume el arg `player` (el
-- Player golpeado) -- clona su `.Character` completo, recolorea, y lo deja fadeando in-place.
-- Adaptaciones vs juju (ver brief "adapt, do not invent"):
--   1) juju resuelve `destroy_hit_chams` (la variante de animacion) como un upvalue MUTABLE leido
--      recien cuando el `delay(hit_chams_lifetime, ...)` dispara -- si el usuario cambia el
--      dropdown "animation" MIENTRAS un chams esta en vuelo, ese chams termina usando la variante
--      NUEVA, no la que estaba seleccionada al momento del hit. Acá se lee Combat_ChamsAnimation
--      UNA sola vez al spawn (mismo criterio que TracerType/DamageFont/ParticlePreset en Tasks
--      3/5/7 -- todos los flags de "estilo" de este archivo se congelan al spawn).
--   2) juju usa closures push-into-heartbeat (`heartbeat[#heartbeat+1]=tween_function` +
--      `delay(...)`) para el ciclo fade -> destroy. Acá se adapta al patron per-frame ya
--      establecido en este archivo (e.fading/e.fadeStart, ver Tasks 3-5) -- gatea SIEMPRE desde
--      Combat:_update (ver nota grande sobre :_update mas abajo), evitando el equivalente de
--      "timer huerfano" que tendria un closure de juju cuyo `delay` nunca dispara si el modulo
--      se descarga a mitad de vuelo (Unload cubre esto explicitamente, ver mandato del brief).
--   3) (encontrado en verificacion LIVE, Task 9) juju filtra por `ClassName == "MeshPart"` en
--      ambas variantes (L15338 solido, L15397 outline+Head) porque su juego de referencia (Da
--      Hood) es R15 con el rig entero hecho de MeshPart. LiP es R6 y NINGUNA parte del cuerpo
--      (Head/Torso/brazos/piernas/HumanoidRootPart) es MeshPart -- son `Part` comunes -- asi que
--      un filtro `MeshPart`-only deja el clon solido VACIO (0 partes recoloreadas, sin error) y
--      el outline solo cubre Head (unico cubierto por el fallback de nombre). Se amplia el
--      filtro de seleccion de partes de MeshPart a BasePart (Material/Color/Transparency/
--      Anchored/CanCollide son props de BasePart, no exclusivas de MeshPart) en :_buildChamsSolid
--      y :_buildChamsOutline -- `TextureID` SI es exclusiva de MeshPart, queda gateada a
--      `part:IsA("MeshPart")` adentro del pcall. HumanoidRootPart se excluye explicitamente
--      (normalmente invisible/al centro del torso, sin valor visual) -- cae al mismo `else:
--      destroy(part)` que ya la alcanzaba antes de este fix (no era MeshPart tampoco). Verificado
--      LIVE ademas: LiP agrega 5 `RDCollision` Part por Character (Transparency=1,
--      CanCollide=false -- hitboxes de ragdoll por-limb, invisibles); excluida junto a
--      HumanoidRootPart (helper local `isChamsLimb`) para no dejarlas recoloreadas como cajas
--      fantasma flotantes. El manejo de Accessory (busca un `MeshPart` hijo, lo extrae) NO
--      cambia -- 1:1 juju, fuera de scope de este fix (accesorios con Handle no-MeshPart quedan
--      intactos, igual que antes).
return function(GV)
    local Combat = {}
    Combat.__index = Combat

    -- ventanas de fade POST-lifetime (constantes fijas en juju, no expuestas en el menu):
    -- linea L13518 (0.3s tras el lifetime, quad ease); beam L13414/destroy_beam (0.2s, quad ease).
    local LINE_FADE_DUR = 0.3
    local BEAM_FADE_DUR = 0.2
    -- ventanas de fade POST-lifetime de los hitmarkers (constantes fijas en juju tambien, no
    -- expuestas en el menu): 3D L15013 (0.3s, quad-out), 2D L15134 (0.2s, quad-out).
    local MARKER3D_FADE_DUR = 0.3
    local MARKER2D_FADE_DUR = 0.2
    -- offset de "rise" del damage number (juju L14879 show_offset = Vector3(0,1.5,0)). A
    -- diferencia de los fades de arriba, la ventana de fade-out del damage number NO es una
    -- constante fija -- es proporcional al lifetime de cada instancia (ver :_spawnDamageNumber).
    local DAMAGE_RISE_OFFSET = Vector3.new(0, 1.5, 0)

    -- Task 8 -- Hit Chams: ventanas de fade fijas (constantes en juju, no expuestas en el menu --
    -- mismo criterio que LINE_FADE_DUR/MARKER3D_FADE_DUR/MARKER2D_FADE_DUR arriba).
    -- destroy_hit_chams_fade (juju L15233-15261): la curva de transparencia Y la ventana total
    -- hasta destroy coinciden, ambas 0.25s. destroy_hit_chams_new_fade (juju L15265-15315): la
    -- curva (transparencia + grow de Size) dura 0.15s, pero la ventana total hasta destroy sigue
    -- siendo 0.25s (juju L15306 delay(0.25,...) en AMBAS variantes) -- tras completar la curva a
    -- los 0.15s, el modelo queda congelado en el estado final (transparency=1, size maxima) el
    -- resto de la ventana hasta el destroy real a los 0.25s. animType=="none" destruye de
    -- inmediato al vencer el lifetime, sin ventana ni curva.
    local CHAMS_FADE_CURVE_DUR = 0.25    -- animType == "fade"
    local CHAMS_NEWFADE_CURVE_DUR = 0.15 -- animType == "new fade"
    local CHAMS_TOTAL_FADE_DUR = 0.25    -- ventana total hasta destroy (ambas variantes con curva)
    local CHAMS_GROW_SIZE = Vector3.new(1, 1, 1) -- juju L15263 `size = vector3_new(1,1,1)`
    -- transparency base del clon (juju menu L15211 default_transparency=0.8 -- el colorpicker CF
    -- de este proyecto no tiene componente de transparencia, ver nota identica en schema/
    -- combat.lua Hit Chams / Hit Particles -- se porta como constante fija, no como fila de menu).
    local CHAMS_TRANSPARENCY = 0.8

    -- beams bank (juju L13364-13396, port 1:1 de props/valores por estilo). Se instancian LAZY
    -- (1 vez por estilo, cacheadas) y se clonan por disparo -- igual patron que Aura:_template.
    local function buildBeamStyle(name)
        local b = Instance.new("Beam")
        if name == "laser" then
            b.FaceCamera = true; b.TextureSpeed = 1.5; b.Width0 = 0.25; b.Width1 = 0.25
            b.TextureLength = 2; b.LightEmission = 3; b.Brightness = 2.5
            b.Texture = "rbxassetid://12781800668"
        elseif name == "light" then
            b.FaceCamera = true; b.TextureSpeed = 2; b.Width0 = 0.25; b.Width1 = 0.25
            b.LightInfluence = 1; b.LightEmission = 3; b.Segments = 1
            b.Texture = "http://www.roblox.com/asset/?id=2382169232"
            b.TextureLength = 15; b.TextureMode = Enum.TextureMode.Wrap
        elseif name == "flow" then
            b.FaceCamera = true; b.TextureSpeed = 2.5; b.Width0 = 0.2; b.Width1 = 0.2
            b.LightEmission = 3; b.Brightness = 5
            b.Texture = "rbxassetid://12788927812"
        else
            b:Destroy(); return nil
        end
        return b
    end

    -- Task 7 -- Hit Particles: preset library (juju L14313-14820, do-block "hit particle").
    -- ONE pooled anchored Part (juju L14316 hit_particle_part) holds ALL 10 preset emitters as
    -- children, prebuilt once (juju builds them EAGER at module-load; acá se difiere a la primera
    -- vez que se necesita -- ver :_ensureParticleLib mas abajo, mismo criterio lazy que
    -- _beamTemplate/Aura:_template). do_hit_particle (juju L14770) solo mueve el Part y llama
    -- :Emit(count) sobre los emitters del preset seleccionado -- no hace falta crear/destruir
    -- Instances por hit, el pool entero vive fijo desde la 1ra creacion hasta :Unload.
    --
    -- Preset NO portado: "custom .rbxm" (juju menu L13347 use_custom_extensions + getcustomasset
    -- L14800 -- carga un asset LOCAL del disco del usuario de juju). Esta abstraccion de proyecto
    -- (provider/schema declarativo, sin filesystem picker en el menu) no expone un mecanismo
    -- equivalente para que el usuario suba un .rbxm propio -- se omite, documentado acá y en el
    -- schema (brief: "otherwise omit and document"). Los 10 presets built-in cubren el dropdown completo.
    local function newParticle(parent, props)
        local e = Instance.new("ParticleEmitter")
        for k, v in pairs(props) do e[k] = v end
        e.Enabled = false -- todos los presets de juju traen Enabled=false explicito (fire-and-forget via :Emit, no stream continuo)
        e.Parent = parent
        return e
    end

    -- transcripcion 1:1 de juju L14325-14765 (mismos valores/texturas/curvas por preset). Cada
    -- entrada = { emitter = <ParticleEmitter>, count = <n de juju particle[2], el arg de :Emit()> }.
    local function buildHitParticlePresets(part)
        return {
            sparks = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    Acceleration = Vector3.new(0, -50, 0),
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1, 0.999969, 0.999985)),
                        ColorSequenceKeypoint.new(0.25, Color3.new(0.333333, 1, 0)),
                        ColorSequenceKeypoint.new(1, Color3.new(0.333333, 1, 0.498039)),
                    }),
                    Lifetime = NumberRange.new(0.5, 1),
                    LightEmission = 1,
                    Orientation = Enum.ParticleOrientation.VelocityParallel,
                    Rate = 0,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.6, 0), NumberSequenceKeypoint.new(0.5, 0.6, 0), NumberSequenceKeypoint.new(1, 0, 0),
                    }),
                    Speed = NumberRange.new(15, 15),
                    SpreadAngle = Vector2.new(50, -50),
                    Texture = "http://www.roblox.com/asset/?id=18540695516",
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.5, 0, 0), NumberSequenceKeypoint.new(1, 1, 0),
                    }),
                }), count = 30 },
            },
            bubble = {
                { emitter = newParticle(part, {
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 255)),
                    }),
                    LockedToPart = true,
                    Rate = 1.5,
                    Rotation = NumberRange.new(-5, 5),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.464, 0.768750011920929), NumberSequenceKeypoint.new(1, 1),
                    }),
                    Texture = "rbxassetid://17086075673",
                    Lifetime = NumberRange.new(0.450000001192092896, 0.450000001192092896),
                    LightEmission = 1,
                    Brightness = 5,
                    Speed = NumberRange.new(0, 0),
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.10000000149011612), NumberSequenceKeypoint.new(1, 6),
                    }),
                }), count = 1 },
            },
            orbs = {
                { emitter = newParticle(part, {
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
                    RotSpeed = NumberRange.new(-10, 10),
                    FlipbookFramerate = NumberRange.new(40, 40),
                    Drag = 1,
                    Rate = 1,
                    Texture = "rbxassetid://15011464541",
                    Rotation = NumberRange.new(-1000, 1000),
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
                    SpreadAngle = Vector2.new(-1000, 1000),
                    Lifetime = NumberRange.new(0.44999998807907104, 0.44999998807907104),
                    LightEmission = 1,
                    Brightness = 10,
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5.5), NumberSequenceKeypoint.new(1, 5.5) }),
                }), count = 3 },
            },
            air = {
                { emitter = newParticle(part, {
                    FlipbookMode = Enum.ParticleFlipbookMode.PingPong,
                    VelocityInheritance = 0.15000000596046448,
                    Texture = "rbxassetid://10536350143",
                    FlipbookFramerate = NumberRange.new(30, 30),
                    Drag = 4.5,
                    Rate = 1,
                    Speed = NumberRange.new(0, 0),
                    LightInfluence = 1,
                    Acceleration = Vector3.new(1, 0, 1),
                    LockedToPart = true,
                    Lifetime = NumberRange.new(1, 1),
                    LightEmission = 1,
                    Brightness = 10,
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 3) }),
                }), count = 1 },
            },
            blood = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.5, 0.75),
                    SpreadAngle = Vector2.new(90, 90),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.125, 0.5), NumberSequenceKeypoint.new(1, 1),
                    }),
                    Color = ColorSequence.new(Color3.fromRGB(130, 0, 0)),
                    Speed = NumberRange.new(5, 10),
                    Size = NumberSequence.new(0.5, 2),
                    Acceleration = Vector3.new(0, -20, 0),
                    RotSpeed = NumberRange.new(-90, 90),
                    Rate = 0,
                    Texture = "rbxassetid://241576804",
                    Rotation = NumberRange.new(-360, 360),
                }), count = 25 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.25, 0.5),
                    SpreadAngle = Vector2.new(360, 360),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(1, 1),
                    }),
                    Color = ColorSequence.new(Color3.fromRGB(100, 0, 0)),
                    Speed = NumberRange.new(15, 25),
                    Size = NumberSequence.new(0.125, 0.6874996),
                    Acceleration = Vector3.new(0, -75, 0),
                    Rate = 0,
                    Texture = "rbxassetid://4509687978",
                    Orientation = Enum.ParticleOrientation.VelocityParallel,
                }), count = 15 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.75, 0.75),
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5037407, 0), NumberSequenceKeypoint.new(1, 1),
                    }),
                    Color = ColorSequence.new(Color3.fromRGB(130, 0, 0)),
                    Speed = NumberRange.new(0.001, 0.001),
                    ZOffset = 4,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.376, 2.0625), NumberSequenceKeypoint.new(1, 2.6875),
                    }),
                    Rate = 0,
                    Texture = "rbxassetid://16664856199",
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 5 },
            },
            light = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    LightInfluence = 1,
                    Lifetime = NumberRange.new(1, 1),
                    LockedToPart = true,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2066, 0), NumberSequenceKeypoint.new(0.4947, 0),
                        NumberSequenceKeypoint.new(0.7996, 0), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Speed = NumberRange.new(0, 0),
                    ZOffset = 4,
                    Size = NumberSequence.new(7.5, 7.5),
                    RotSpeed = NumberRange.new(100, 100),
                    Rate = 0,
                    Texture = "rbxassetid://271370648",
                }), count = 1 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    LightInfluence = 1,
                    Lifetime = NumberRange.new(1, 1),
                    LockedToPart = true,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4947, 0), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Speed = NumberRange.new(0, 0),
                    ZOffset = 5,
                    Size = NumberSequence.new(7.5, 7.5),
                    Rate = 0,
                    Texture = "rbxassetid://13275495915",
                }), count = 2 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    LightInfluence = 1,
                    Lifetime = NumberRange.new(1, 1),
                    LockedToPart = true,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.504, 0.49375), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Speed = NumberRange.new(0, 0),
                    ZOffset = 5,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 7.4375) }),
                    Rate = 0,
                    Texture = "rbxassetid://15267994078",
                    Rotation = NumberRange.new(-360, 360),
                }), count = 3 },
            },
            lightning = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    FlipbookFramerate = NumberRange.new(17, 17),
                    Lifetime = NumberRange.new(0.1, 1),
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
                    LockedToPart = true,
                    Speed = NumberRange.new(0.01, 0.01),
                    Brightness = 15,
                    ZOffset = 3,
                    Size = NumberSequence.new(5, 5),
                    Rate = 0,
                    Texture = "rbxassetid://14582813693",
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 5 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.4, 0.4),
                    SpreadAngle = Vector2.new(360, 360),
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
                    LightEmission = 1,
                    Drag = 15,
                    Speed = NumberRange.new(0.0099, 0.0099),
                    Brightness = 5,
                    ZOffset = 4,
                    Size = NumberSequence.new(5, 5),
                    Rate = 0,
                    Texture = "rbxassetid://13305806509",
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
                }), count = 2 },
            },
            blackflash = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    LightInfluence = 0.2,
                    Lifetime = NumberRange.new(0.1, 0.25),
                    SpreadAngle = Vector2.new(360, 360),
                    LockedToPart = true,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.0375, 0.291), NumberSequenceKeypoint.new(0.131, 0.602),
                        NumberSequenceKeypoint.new(0.259, 0.788), NumberSequenceKeypoint.new(0.403, 0.906), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Color = ColorSequence.new(Color3.fromRGB(255, 17, 17)),
                    Speed = NumberRange.new(0.0135, 0.0135),
                    Brightness = 10,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.0645, 5.37), NumberSequenceKeypoint.new(0.236, 11.31),
                        NumberSequenceKeypoint.new(0.586, 15.7), NumberSequenceKeypoint.new(1, 18.56),
                    }),
                    RotSpeed = NumberRange.new(-20, 20),
                    Rate = 0,
                    Texture = "rbxassetid://10149702982",
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 3 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.07, 0.2),
                    SpreadAngle = Vector2.new(-360, 360),
                    LockedToPart = true,
                    LightEmission = 1,
                    Color = ColorSequence.new(Color3.fromRGB(255, 17, 17)),
                    Speed = NumberRange.new(0.0197, 0.0197),
                    Brightness = 15,
                    ZOffset = 3.96,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 25.55), NumberSequenceKeypoint.new(1, 0) }),
                    Rate = 0,
                    Texture = "rbxassetid://15446757636",
                    Orientation = Enum.ParticleOrientation.VelocityParallel,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 3 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.6, 1.3),
                    SpreadAngle = Vector2.new(180, 180),
                    LockedToPart = true,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.457, 0.9625), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Drag = 10,
                    Speed = NumberRange.new(72.6, 290.5),
                    Brightness = 0.75,
                    ZOffset = 3.46,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.58), NumberSequenceKeypoint.new(0.5, 16.25), NumberSequenceKeypoint.new(1, 20.34),
                    }),
                    Rate = 0,
                    Texture = "rbxassetid://15883763954",
                    Orientation = Enum.ParticleOrientation.VelocityParallel,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 3 },
            },
            gravity = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.6, 0.6),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.578, 0.7375), NumberSequenceKeypoint.new(1, 1),
                    }),
                    LightEmission = 1,
                    Color = ColorSequence.new(Color3.fromRGB(114, 44, 255)),
                    Speed = NumberRange.new(0.0629, 0.0629),
                    Brightness = 4,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 35.77) }),
                    RotSpeed = NumberRange.new(500, 800),
                    Rate = 0,
                    Texture = "rbxassetid://8030746658",
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
                    Rotation = NumberRange.new(-360, 360),
                }), count = 3 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.85, 1),
                    SpreadAngle = Vector2.new(-30, 30),
                    LightEmission = 1,
                    Color = ColorSequence.new(Color3.fromRGB(81, 62, 189)),
                    Speed = NumberRange.new(5, 10),
                    Brightness = 4,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.167, 0.875), NumberSequenceKeypoint.new(1, 0),
                    }),
                    Rate = 0,
                    Texture = "rbxassetid://8030760338",
                }), count = 35 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.2, 0.4),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.26, 0), NumberSequenceKeypoint.new(1, 0),
                    }),
                    LightEmission = 1,
                    Color = ColorSequence.new(Color3.fromRGB(114, 44, 255)),
                    Drag = 1,
                    Speed = NumberRange.new(5, 10),
                    Brightness = 3,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.11, 4.0975), NumberSequenceKeypoint.new(1, 0),
                    }),
                    Rate = 0,
                    Texture = "rbxassetid://8801300936",
                    Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
                }), count = 20 },
            },
            meteor = {
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.1, 0.3),
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
                    SpreadAngle = Vector2.new(40, 40),
                    LightEmission = 0.1,
                    Color = ColorSequence.new(Color3.fromRGB(72, 26, 255)),
                    Drag = 9,
                    Speed = NumberRange.new(100, 200),
                    Brightness = 4.57,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 14.17), NumberSequenceKeypoint.new(0.374, 16.19), NumberSequenceKeypoint.new(1, 10.31),
                    }),
                    Rate = 0,
                    Texture = "http://www.roblox.com/asset/?id=13136714025",
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
                    Rotation = NumberRange.new(0, 360),
                }), count = 30 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.15, 0.25),
                    SpreadAngle = Vector2.new(30, 30),
                    LockedToPart = true,
                    LightEmission = 0.6,
                    Color = ColorSequence.new(Color3.fromRGB(69, 44, 255)),
                    Drag = 26,
                    Speed = NumberRange.new(0.13, 0.13),
                    Brightness = 6.885,
                    ZOffset = 3,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.265, 1.16), NumberSequenceKeypoint.new(0.48, 7.56),
                        NumberSequenceKeypoint.new(0.72, 1.4), NumberSequenceKeypoint.new(1, 0),
                    }),
                    Rate = 0,
                    Texture = "rbxassetid://16722791958",
                    Rotation = NumberRange.new(150, 150),
                }), count = 50 },
                { emitter = newParticle(part, {
                    Name = "\0",
                    Lifetime = NumberRange.new(0.2, 0.4),
                    SpreadAngle = Vector2.new(50, 50),
                    Color = ColorSequence.new(Color3.fromRGB(84, 41, 255)),
                    Drag = 8,
                    Speed = NumberRange.new(141.44, 183.87),
                    Brightness = 12,
                    Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.259, 1.77), NumberSequenceKeypoint.new(1, 0),
                    }),
                    Acceleration = Vector3.new(0, -282.88, 0),
                    RotSpeed = NumberRange.new(-30, 30),
                    Rate = 0,
                    Texture = "rbxassetid://11995504618",
                    Orientation = Enum.ParticleOrientation.VelocityParallel,
                }), count = 40 },
            },
        }
    end

    function Combat.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
            Terrain = workspace:FindFirstChildOfClass("Terrain"),
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _made = {}, Loaded = false,
            -- Task 3: pool de Drawings (line mode, reusado entre disparos) + listas de tracers
            -- activos (line/beam) + cache de templates de Beam por estilo.
            _linePool = {}, _activeLine = {}, _activeBeam = {}, _beamTemplates = {},
            -- Task 4: pools de bundles cruz (8 Drawing Line c/u: 4 lineas + 4 outlines) + listas
            -- de hitmarkers activos. 3D y 2D tienen pool/lista propios porque conviven al mismo
            -- tiempo (un hit puede spawnear ambos si los 2 toggles estan ON).
            _marker3DPool = {}, _active3D = {}, _marker2DPool = {}, _active2D = {},
            -- Task 5: pool de Drawings "Text" (1 sola Drawing por numero, el outline vive en la
            -- misma Drawing via Outline/OutlineColor) + lista de damage numbers activos.
            _damagePool = {}, _activeDamage = {},
            -- Task 6: _ring queda nil hasta el primer :_updateRing -> :_ensureRing lo fabrica LAZY
            -- (mismo criterio lazy que _beamTemplates/_lineBundle arriba) como
            -- { lines = {32 Drawing "Line"}, radius = {r=...}, oldRadius = ..., bounce = nil|{...} }
            -- -- pool FIJO (no pool-de-prestamo), ver nota grande sobre :_updateRing.
            -- Task 8: lista de clones de char (hit chams) activos + referencia al ULTIMO clone
            -- spawneado (juju `last_model`, ver Combat:_spawnChams) para la logica only_last_hit --
            -- a diferencia de los pools de Tasks 3-5, no hay pool-de-prestamo acá (cada hit clona
            -- un Model nuevo, se destruye al terminar su fade -- mismo patron no-pooled que
            -- self._particleLib del Task 7, pero POR-HIT en vez de 1-sola-vez).
            _activeChams = {}, _lastChams = nil,
        }, Combat)
    end

    function Combat:Set(k, v) self.Flags[k] = v end
    function Combat:Get(k) return self.Flags[k] end
    function Combat:_flag(k, d)
        local v = self.Flags["Combat_" .. k]; if v ~= nil then return v end; return d
    end
    function Combat:UseProfile(p) if p then self._provider = p end end

    function Combat:_draw(class, props)
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end
        local o = Drawing.new(class); o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o); return o
    end

    -- resuelve un campo del provider que puede venir como Signal directa O function()->Signal.
    -- El perfil lifeinprison expone onShot/onHit como funciones LAZY a proposito: el bundle de
    -- GUIWorkspace se construye (y corre este modulo) ANTES de que Core.State cree
    -- getgenv().LIP.onShot/onHit -> capturar el valor directo en ese momento quedaria nil para
    -- siempre. Resolver en Init() (que corre despues, desde main.lua) evita el problema.
    local function resolveSignal(v)
        if type(v) == "function" then local ok, r = pcall(v); return ok and r or nil end
        return v
    end

    -- resuelve provider.target() de forma segura (mismo espiritu pcall-wrap que resolveSignal
    -- arriba, pero para el accessor de Task 6 -- ver interfaz en el brief: "provider.target()
    -- -> Player|nil", una funcion directa, no una Signal). Usado SOLO por :_updateRing.
    local function resolveTarget(provider)
        if not provider or type(provider.target) ~= "function" then return nil end
        local ok, t = pcall(provider.target)
        if ok and t then return t end
        return nil
    end

    ------------------------------------------------------------------------------------------
    -- Task 3 -- Hit Tracers: pool/template getters
    ------------------------------------------------------------------------------------------
    function Combat:_beamTemplate(style)
        local cached = self._beamTemplates[style]
        if cached ~= nil then return cached or nil end
        local ok, b = pcall(buildBeamStyle, style)
        local result = (ok and b) or false
        self._beamTemplates[style] = result
        return result or nil
    end

    -- pool de bundles {line, outline} (2 Drawing "Line" por tracer). Reusado entre disparos --
    -- no se allocan Drawings nuevas mientras haya bundles libres.
    function Combat:_lineBundle()
        local b = table.remove(self._linePool)
        if b then return b end
        return { line = self:_draw("Line", { Thickness = 1 }), outline = self:_draw("Line", { Thickness = 3 }) }
    end
    function Combat:_releaseLineBundle(b)
        b.line.Visible = false; b.outline.Visible = false
        table.insert(self._linePool, b)
    end

    ------------------------------------------------------------------------------------------
    -- Task 3 -- Hit Tracers: spawn (line / beam)
    ------------------------------------------------------------------------------------------
    -- line mode: 2 Drawing "Line" (juju L13460 do_line_bullet_tracer), proyectadas cada frame en
    -- :_updateLineTracers (world->viewport + edge-clamp si Z<0). Fade: GV.Tween Transparency->0
    -- (Drawing: 1=opaco/0=invisible, ver comentario ESP.lua) sobre LINE_FADE_DUR tras el lifetime.
    function Combat:_spawnLineTracer(origin, hitPos, now)
        local b = self:_lineBundle()
        b.line.Color = GV.Color.fade(self.Flags, "Combat_TracerColor", now)
        b.line.Transparency = 1; b.line.Visible = true
        b.outline.Color = GV.Color.fade(self.Flags, "Combat_TracerOutline", now)
        b.outline.Transparency = 1; b.outline.Visible = true
        table.insert(self._activeLine, {
            bundle = b, origin = origin, hitPos = hitPos, spawnT = now,
            lifetime = self:_flag("TracerLifetime", 0.8), fading = false,
        })
    end

    -- beam mode: clona el estilo de Beam elegido (juju L13438 do_beam_bullet_tracer), 2
    -- Attachment (origin/hitPos) parentados a Terrain. Fade: destroy_beam (juju L13406) --
    -- reconstruye el NumberSequence de Transparency cada frame desde un alpha 0->1 tweeneado
    -- via GV.Tween sobre una tabla Lua plana (GV.Tween/tweenStep solo interpolan numeros/
    -- Vector2/Vector3/Color3 -- un NumberSequence no es interpolable directo, se recompone acá).
    --
    -- NOTA: beam/att0/att1 NO se registran en self._made (a diferencia de otros modulos) -- son
    -- transitorios y ya viven en self._activeBeam mientras estan vivos (bounded: se remueven de
    -- ahi apenas :_updateBeamTracers los destruye). Si quedaran ademas en self._made, esa lista
    -- creceria sin limite durante una sesion larga (nunca se poda entre disparos, solo en
    -- Unload) -- self._activeBeam ya es el safety net de Unload para instancias de beam.
    function Combat:_spawnBeamTracer(origin, hitPos, now)
        local style = self:_flag("TracerStyle", "laser")
        local template = self:_beamTemplate(style)
        if not template then return end
        local beam = template:Clone()
        local mainColor = GV.Color.fade(self.Flags, "Combat_TracerColor", now)
        local gradColor = GV.Color.fade(self.Flags, "Combat_TracerGradient", now)
        beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, mainColor), ColorSequenceKeypoint.new(1, gradColor) })
        beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
        local terrain = self.Services.Terrain or self.Services.Workspace.Terrain
        local att0 = Instance.new("Attachment"); att0.CFrame = CFrame.new(origin); att0.Parent = terrain
        local att1 = Instance.new("Attachment"); att1.CFrame = CFrame.new(hitPos); att1.Parent = terrain
        beam.Attachment0 = att0; beam.Attachment1 = att1; beam.Parent = terrain
        table.insert(self._activeBeam, {
            beam = beam, att0 = att0, att1 = att1, spawnT = now,
            lifetime = self:_flag("TracerLifetime", 0.8), fading = false, fadeAlpha = 0,
        })
    end

    ------------------------------------------------------------------------------------------
    -- Task 3 -- Hit Tracers: per-frame update (proyeccion + fade)
    ------------------------------------------------------------------------------------------
    function Combat:_updateLineTracers(now)
        local cam = self.Services.Workspace.CurrentCamera
        local list = self._activeLine
        for i = #list, 1, -1 do
            local e = list[i]
            local b = e.bundle
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                GV.Tween(b.line, { Transparency = 0 }, "quad", LINE_FADE_DUR)
                GV.Tween(b.outline, { Transparency = 0 }, "quad", LINE_FADE_DUR)
            end
            if e.fading and (now - e.fadeStart) >= LINE_FADE_DUR then
                self:_releaseLineBundle(b)
                table.remove(list, i)
            elseif cam then
                -- world->viewport cada frame (camara puede moverse durante el lifetime) +
                -- edge-clamp detras de camara (juju L13505-13511: refleja al lado opuesto de
                -- pantalla, clampeado a los bordes, en vez de ocultar).
                local p1, on1 = cam:WorldToViewportPoint(e.origin)
                local p2, on2 = cam:WorldToViewportPoint(e.hitPos)
                if not on1 and not on2 then
                    b.line.Visible = false; b.outline.Visible = false
                else
                    local vp = cam.ViewportSize
                    local xh, yh = vp.X / 2, vp.Y / 2
                    local from = (p1.Z < 0)
                        and Vector2.new(math.clamp(xh + (xh - p1.X), 0, vp.X), math.clamp(yh + (yh - p1.Y), 0, vp.Y))
                        or Vector2.new(p1.X, p1.Y)
                    local to = (p2.Z < 0)
                        and Vector2.new(math.clamp(xh + (xh - p2.X), 0, vp.X), math.clamp(yh + (yh - p2.Y), 0, vp.Y))
                        or Vector2.new(p2.X, p2.Y)
                    b.line.Visible = true; b.outline.Visible = true
                    b.line.From = from; b.line.To = to
                    -- outline levemente mas corto que la linea principal (juju L13530-13533)
                    local diff = from - to
                    local offset = diff.Magnitude > 0 and diff.Unit or Vector2.new(0, 0)
                    b.outline.From = from + offset; b.outline.To = to - offset
                end
            end
        end
    end

    function Combat:_updateBeamTracers(now)
        local list = self._activeBeam
        for i = #list, 1, -1 do
            local e = list[i]
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                local ok, kps = pcall(function() return e.beam.Transparency.Keypoints end)
                if ok and kps and #kps >= 2 then e.oldT0, e.oldT1 = kps[1].Value, kps[#kps].Value
                else e.oldT0, e.oldT1 = 0, 0 end
                GV.Tween(e, { fadeAlpha = 1 }, "quad", BEAM_FADE_DUR)
            end
            if e.fading then
                pcall(function()
                    e.beam.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, e.oldT0 + (1 - e.oldT0) * e.fadeAlpha),
                        NumberSequenceKeypoint.new(1, e.oldT1 + (1 - e.oldT1) * e.fadeAlpha),
                    })
                end)
                if (now - e.fadeStart) >= BEAM_FADE_DUR then
                    pcall(function() e.beam:Destroy() end)
                    pcall(function() e.att0:Destroy() end)
                    pcall(function() e.att1:Destroy() end)
                    table.remove(list, i)
                end
            end
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 4 -- Hitmarker 3D + 2D: pool getters (bundle = cruz de 8 Drawing "Line": 4 lineas +
    -- 4 outlines, mismo patron de pooling que _lineBundle de Task 3).
    ------------------------------------------------------------------------------------------
    function Combat:_markerBundle(pool)
        local b = table.remove(pool)
        if b then return b end
        local lines, outlines = {}, {}
        for i = 1, 4 do
            lines[i] = self:_draw("Line", { ZIndex = 100 })
            outlines[i] = self:_draw("Line", { ZIndex = 99 })
        end
        return { lines = lines, outlines = outlines }
    end
    function Combat:_releaseMarkerBundle(pool, b)
        for i = 1, 4 do b.lines[i].Visible = false; b.outlines[i].Visible = false end
        table.insert(pool, b)
    end

    -- geometria de la cruz (juju L15021-15039 / L15142-15160, identica en 3D y 2D): 4 trazos
    -- diagonales cortos, uno por esquina, apuntando desde ±10px hacia ±5px del centro -- deja un
    -- hueco en el medio (no es una X continua ni un circulo).
    function Combat:_layoutMarkerCross(b, x, y)
        local corners = {
            { x - 10, y - 10, x - 5, y - 5 },
            { x + 10, y - 10, x + 5, y - 5 },
            { x - 10, y + 10, x - 5, y + 5 },
            { x + 10, y + 10, x + 5, y + 5 },
        }
        for i = 1, 4 do
            local c = corners[i]
            local from, to = Vector2.new(c[1], c[2]), Vector2.new(c[3], c[4])
            b.lines[i].From, b.lines[i].To = from, to
            b.outlines[i].From, b.outlines[i].To = from, to
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 4 -- Hitmarker 3D + 2D: spawn. Color: lethal (bool de provider.onHit) selecciona
    -- Combat_MarkerLethal vs Combat_MarkerColor (juju L14974/L15098: player_data[player][18]).
    -- Transparency=1 inicial (visible, ver convencion "Drawing.Transparency: 1=opaco/0=invisible"
    -- documentada en ESP.lua y usada igual por los tracers de Task 3).
    ------------------------------------------------------------------------------------------
    function Combat:_spawnMarker3D(pos, lethal, now)
        local b = self:_markerBundle(self._marker3DPool)
        local thickness = self:_flag("MarkerThickness", 2)
        local color = lethal and GV.Color.fade(self.Flags, "Combat_MarkerLethal", now)
            or GV.Color.fade(self.Flags, "Combat_MarkerColor", now)
        local outline = GV.Color.fade(self.Flags, "Combat_MarkerOutline", now)
        for i = 1, 4 do
            b.lines[i].Thickness = thickness; b.lines[i].Color = color
            b.lines[i].Transparency = 1; b.lines[i].Visible = true
            b.outlines[i].Thickness = thickness + 2; b.outlines[i].Color = outline
            b.outlines[i].Transparency = 1; b.outlines[i].Visible = true
        end
        table.insert(self._active3D, {
            bundle = b, pos = pos, spawnT = now,
            lifetime = self:_flag("MarkerLifetime", 0.7), fading = false,
        })
    end

    function Combat:_spawnMarker2D(lethal, now)
        local b = self:_markerBundle(self._marker2DPool)
        local thickness = self:_flag("MarkerThickness", 2)
        local color = lethal and GV.Color.fade(self.Flags, "Combat_MarkerLethal", now)
            or GV.Color.fade(self.Flags, "Combat_MarkerColor", now)
        local outline = GV.Color.fade(self.Flags, "Combat_MarkerOutline", now)
        for i = 1, 4 do
            b.lines[i].Thickness = thickness; b.lines[i].Color = color
            b.lines[i].Transparency = 1; b.lines[i].Visible = true
            b.outlines[i].Thickness = thickness + 2; b.outlines[i].Color = outline
            b.outlines[i].Transparency = 1; b.outlines[i].Visible = true
        end
        table.insert(self._active2D, {
            bundle = b, spawnT = now, lifetime = self:_flag("MarkerLifetime", 0.7), fading = false,
        })
    end

    ------------------------------------------------------------------------------------------
    -- Task 4 -- Hitmarker 3D + 2D: per-frame update (proyeccion/centro + fade). Mismo patron que
    -- _updateLineTracers: fade se dispara una vez vencido el lifetime, release al pool al
    -- terminar la ventana de fade.
    ------------------------------------------------------------------------------------------
    function Combat:_updateMarker3D(now)
        local cam = self.Services.Workspace.CurrentCamera
        local list = self._active3D
        for i = #list, 1, -1 do
            local e = list[i]
            local b = e.bundle
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                for j = 1, 4 do
                    GV.Tween(b.lines[j], { Transparency = 0 }, "quad", MARKER3D_FADE_DUR)
                    GV.Tween(b.outlines[j], { Transparency = 0 }, "quad", MARKER3D_FADE_DUR)
                end
            end
            if e.fading and (now - e.fadeStart) >= MARKER3D_FADE_DUR then
                self:_releaseMarkerBundle(self._marker3DPool, b)
                table.remove(list, i)
            elseif cam then
                -- posicion capturada 1 vez al spawn (juju L14994/L15000: anclada al punto de
                -- impacto en world-space, no re-lee part.Position cada frame) -- solo la camara
                -- moviendose actualiza la proyeccion. Fuera de camara -> oculto (juju L15040-
                -- 15044, sin edge-clamp como los tracers de Task 3).
                local vp, onScreen = cam:WorldToViewportPoint(e.pos)
                if onScreen then
                    self:_layoutMarkerCross(b, vp.X, vp.Y)
                    for j = 1, 4 do b.lines[j].Visible = true; b.outlines[j].Visible = true end
                else
                    for j = 1, 4 do b.lines[j].Visible = false; b.outlines[j].Visible = false end
                end
            end
        end
    end

    function Combat:_updateMarker2D(now)
        local cam = self.Services.Workspace.CurrentCamera
        local list = self._active2D
        for i = #list, 1, -1 do
            local e = list[i]
            local b = e.bundle
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                for j = 1, 4 do
                    GV.Tween(b.lines[j], { Transparency = 0 }, "quad", MARKER2D_FADE_DUR)
                    GV.Tween(b.outlines[j], { Transparency = 0 }, "quad", MARKER2D_FADE_DUR)
                end
            end
            if e.fading and (now - e.fadeStart) >= MARKER2D_FADE_DUR then
                self:_releaseMarkerBundle(self._marker2DPool, b)
                table.remove(list, i)
            elseif cam then
                -- centro de pantalla recalculado cada frame (juju L15123-15125), sin proyeccion
                -- ni check on-screen -- siempre visible mientras exista.
                local vp = cam.ViewportSize
                self:_layoutMarkerCross(b, vp.X / 2, vp.Y / 2)
                for j = 1, 4 do b.lines[j].Visible = true; b.outlines[j].Visible = true end
            end
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 5 -- Damage Numbers: pool getter (1 sola Drawing "Text" -- a diferencia de los
    -- bundles de Task 3/4, el outline vive en la MISMA Drawing via las props nativas
    -- Outline/OutlineColor de "Text", no hace falta una 2da Drawing).
    ------------------------------------------------------------------------------------------
    function Combat:_damageText()
        local t = table.remove(self._damagePool)
        if t then return t end
        -- ZIndex 5500 = mismo valor hardcodeado que juju (L14864/L14891) para que el numero
        -- SIEMPRE dibuje encima -- en particular, encima de la cruz de Task 4 (ZIndex 99/100,
        -- ver :_markerBundle) ya que Marker3D/2D y Damage suelen estar ON juntos y spawnean
        -- desde el mismo :_onHit en la misma posicion de pantalla. Sin esto, Drawing "Text" cae
        -- al ZIndex default (~0) y el numero renderiza DETRAS de la cruz. Review finding.
        return self:_draw("Text", { Center = false, Outline = true, ZIndex = 5500 })
    end
    function Combat:_releaseDamageText(t)
        t.Visible = false
        table.insert(self._damagePool, t)
    end

    ------------------------------------------------------------------------------------------
    -- Task 5 -- Damage Numbers: spawn (juju L14875-14961, do_damage_number). Color: lethal
    -- (bool de provider.onHit) selecciona Combat_DamageLethal vs Combat_DamageColor, mismo
    -- patron que Task 4. Texto: SOLO el valor numerico de damage, redondeado (ver nota de
    -- adaptacion en el header del archivo -- no se porta "show ragebot data").
    --
    -- Animacion (adaptada del original, ver brief): 2 fases, mismo patron 2-fase que
    -- tracers/markers de arriba --
    --   fase 1 [0, lifetime): sube en world-space desde part_position hasta part_position +
    --     DAMAGE_RISE_OFFSET (juju L14879 show_offset), ease-in (quad, t*t) via GV.Tween sobre
    --     un campo NUMERICO propio de la entry (e.riseAlpha 0->1) -- mismo patron que
    --     e.fadeAlpha de :_updateBeamTracers (GV.Tween/tweenStep no interpolan Vector3 escalado
    --     por un alpha directamente, se reconstruye la posicion cada frame en :_updateDamage).
    --     Transparency se mantiene opaca (=1) desde el spawn, sin fade-in propio -- juju SI
    --     tiene un sub-fade-in (0->transparency durante los primeros lifetime/1.6s); se omite
    --     acá para quedar consistente con el resto del archivo, que solo fadea UNA vez, al
    --     final (mismo criterio que tracers/markers: Transparency=1 desde el spawn).
    --   fase 2 [lifetime, lifetime*1.5): fade-out de Transparency 1->0, mismo gate que Task 3/4
    --     ("not e.fading and elapsed>=lifetime" dispara el GV.Tween) -- PERO la duracion de esa
    --     ventana NO es una constante fija del archivo (a diferencia de LINE_FADE_DUR/
    --     MARKER3D_FADE_DUR): es proporcional al lifetime de CADA instancia (lifetime*0.5, juju
    --     L14903 new_half = lifetime/2), porque el brief fija el ciclo de vida total en
    --     "lifetime*1.5" (juju L14931 delay(lifetime+new_half, ...)). Se guarda como
    --     e.fadeDur = e.lifetime * 0.5 en el momento del spawn.
    ------------------------------------------------------------------------------------------
    function Combat:_spawnDamageNumber(pos, damage, lethal, now)
        local t = self:_damageText()
        local font = tonumber(self:_flag("DamageFont", "2")) or 2
        local color = lethal and GV.Color.fade(self.Flags, "Combat_DamageLethal", now)
            or GV.Color.fade(self.Flags, "Combat_DamageColor", now)
        local outline = GV.Color.fade(self.Flags, "Combat_DamageOutline", now)
        local lifetime = self:_flag("DamageLifetime", 0.7)
        t.Text = tostring(math.floor((tonumber(damage) or 0) + 0.5))
        t.Size = 14
        t.Font = font
        t.Color = color
        t.OutlineColor = outline
        t.Transparency = 1
        t.Visible = true
        local entry = {
            text = t, basePos = pos, spawnT = now, lifetime = lifetime,
            fadeDur = lifetime * 0.5, fading = false, riseAlpha = 0,
        }
        GV.Tween(entry, { riseAlpha = 1 }, "quad", lifetime)
        table.insert(self._activeDamage, entry)
    end

    ------------------------------------------------------------------------------------------
    -- Task 5 -- Damage Numbers: per-frame update. basePos capturado 1 vez al spawn (igual que
    -- Marker3D, no re-lee part.Position) + offset de rise reconstruido cada frame desde
    -- e.riseAlpha (tweeneado por GV.tweenStep via GV.Tween en :_spawnDamageNumber, NO acá --
    -- mismo split que e.fadeAlpha/_updateBeamTracers). Fuera de camara -> oculto (juju
    -- L14924-14926, sin edge-clamp como los tracers de Task 3).
    ------------------------------------------------------------------------------------------
    function Combat:_updateDamage(now)
        local cam = self.Services.Workspace.CurrentCamera
        local list = self._activeDamage
        for i = #list, 1, -1 do
            local e = list[i]
            local t = e.text
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                GV.Tween(t, { Transparency = 0 }, "quad", e.fadeDur)
            end
            if e.fading and (now - e.fadeStart) >= e.fadeDur then
                self:_releaseDamageText(t)
                table.remove(list, i)
            elseif cam then
                local worldPos = e.basePos + DAMAGE_RISE_OFFSET * e.riseAlpha
                local vp, onScreen = cam:WorldToViewportPoint(worldPos)
                if onScreen then
                    t.Position = Vector2.new(vp.X + 13, vp.Y)
                    t.Visible = true
                else
                    t.Visible = false
                end
            end
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 6 -- Target Ring: pool FIJO (32 Drawing "Line" creadas 1 sola vez -- NO es el patron
    -- event-spawn / pool-de-prestamo de Tasks 3-5 arriba). Port de jujudotlol.lua L22690-22764
    -- ("target circle", do_target_circle): arco spinning de 32 segmentos alrededor de
    -- provider.target(), con gradiente color3_lerp "comet-tail". El arco NO es un circulo
    -- completo: el paso angular de juju (0.12566370614359174 rad = 2*pi/50) * 32 segmentos
    -- cubre solo ~230.4 grados, y el segmento i=32 SIEMPRE cae con Transparency=0 (invisible en
    -- la convencion Drawing de este proyecto, ver ESP.lua L238) porque `visible = (i+32) % 32`
    -- da 0 para i=32 -- en Lua/Luau 0 es TRUTHY (solo nil/false son falsy), asi que juju SIEMPRE
    -- deja `line["Visible"] = true` y usa fade=visible/32=0 para ocultar ese segmento via
    -- transparencia, no via el flag Visible. Se porta 1:1 esa mecanica (un `if visible ~= 0`
    -- seria un comportamiento distinto al original).
    --
    -- Trigger: CONTINUO (brief Task 6), no onShot/onHit -- corre cada frame desde :_update
    -- incondicionalmente (mismo mandato de la nota grande sobre :_update mas abajo) pero gatea
    -- su propia VISIBILIDAD adentro de :_updateRing (Combat_Ring off / sin target / sin torso
    -- -> oculta las 32 lineas y return), nunca en :_update mismo -- si se gateara ahi, apagar
    -- Combat_Ring o Combat_Enabled starvearia a _updateLineTracers/_updateBeamTracers/
    -- _updateMarker3D/_updateMarker2D/_updateDamage de su tick (mismo razonamiento que la nota
    -- de Task 3/4/5).
    ------------------------------------------------------------------------------------------
    local RING_ANGLE_STEP = 0.12566370614359174 -- 2*pi/50, exacto a juju L22706/22707

    function Combat:_ensureRing()
        local r = self._ring
        if r then return r end
        local lines = {}
        for i = 1, 32 do lines[i] = self:_draw("Line", { ZIndex = 10 }) end
        r = { lines = lines, radius = { r = 0 }, oldRadius = 0, bounce = nil }
        self._ring = r
        return r
    end

    -- Adaptaciones vs juju (ver brief "adapt, do not invent"):
    --  1) el radio se lee via char:GetBoundingBox() directo (pcall) en vez del truco de juju de
    --     extraer Model.GetBoundingBox de un Model descartable (evasion de hook -- no aplica
    --     aca, ningun otro feature de este archivo porta ese tipo de evasion).
    --  2) el "bounce" de radio en 2 fases (overshoot +3 studs en 0.07s quad-out -> asienta en
    --     0.14s circular-out, juju L22698-22704, disparado solo si el radio cambio >1.1 studs)
    --     se adapta del `tween(...); delay(0.07, function() if data[11]==new_radius+3 then
    --     tween(...) end end)` de juju (push-into-scheduler) al patron per-frame que ya usa
    --     este archivo para timers de 2 fases (e.fading/e.fadeStart de Tasks 3-5) en vez de
    --     `task.delay`/`delay` -- self._ring.bounce guarda {settle=, fireAt=} y :_updateRing
    --     dispara la 2da fase cuando `now >= fireAt`, con el mismo guard de juju ("solo si nadie
    --     disparo un nuevo bounce mientras tanto", ahi comparado contra `data[11]==new_radius+3`
    --     -- aca contra `ring.radius.r`).
    function Combat:_updateRing(now)
        local ring = self:_ensureRing()
        local lines = ring.lines
        local cam = self.Services.Workspace.CurrentCamera
        local on = self:_flag("Enabled", false) and self:_flag("Ring", false)
        local target = on and resolveTarget(self._provider) or nil
        local char = target and target.Character
        local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
        if not on or not target or not torso or not cam then
            for i = 1, 32 do lines[i].Visible = false end
            ring.oldRadius = 0
            ring.bounce = nil
            return
        end
        local okPos, position = pcall(function() return torso.Position end)
        if not okPos or typeof(position) ~= "Vector3" then
            for i = 1, 32 do lines[i].Visible = false end
            return
        end

        local baseColor = GV.Color.fade(self.Flags, "Combat_RingColor", now)
        local gradColor = GV.Color.fade(self.Flags, "Combat_RingGradient", now)
        local thickness = self:_flag("RingThickness", 2)
        local speed = self:_flag("RingSpeed", 4)

        -- radio: bounding box del char (juju L22696-22697, `(size.X+size.Z)/3` clampeado 2..10)
        local okBB, _, size = pcall(function() return char:GetBoundingBox() end)
        if okBB and size then
            local newRadius = math.clamp((size.X + size.Z) / 3, 2, 10)
            if newRadius ~= ring.oldRadius and math.abs(newRadius - ring.oldRadius) > 1.1 then
                ring.oldRadius = newRadius
                GV.Tween(ring.radius, { r = newRadius + 3 }, "quad", 0.07)
                ring.bounce = { settle = newRadius, fireAt = now + 0.07 }
            end
        end
        if ring.bounce and now >= ring.bounce.fireAt then
            if math.abs(ring.radius.r - (ring.bounce.settle + 3)) < 0.01 then
                GV.Tween(ring.radius, { r = ring.bounce.settle }, "circular", 0.14)
            end
            ring.bounce = nil
        end

        local offset = (now * speed) % (2 * math.pi)
        local radius = ring.radius.r

        for i = 1, 32 do
            local line = lines[i]
            local angle1 = RING_ANGLE_STEP * (i - 1) + offset
            local angle2 = RING_ANGLE_STEP * i + offset
            local p1, on1 = cam:WorldToViewportPoint(position + Vector3.new(math.cos(angle1) * radius, 0, math.sin(angle1) * radius))
            local p2, on2 = cam:WorldToViewportPoint(position + Vector3.new(math.cos(angle2) * radius, 0, math.sin(angle2) * radius))
            if on1 and on2 then
                local visible = i % 32 -- 0 para i=32 (juju: (i+32)%32, identico numericamente)
                local fade = visible / 32
                line.Thickness = thickness
                line.From = Vector2.new(p1.X, p1.Y)
                line.To = Vector2.new(p2.X, p2.Y)
                line.Transparency = math.max(0, fade)
                line.Color = GV.Color3Lerp(baseColor, gradColor, i / 32)
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 7 -- Hit Particles: pool lazy-create (mismo criterio que :_ensureRing arriba -- 1 sola
    -- fabricacion, sobrevive toggles on/off, se destruye solo en :Unload). El Part se registra en
    -- self._made (a diferencia de self._ring/self._marker*Pool, que son Drawings ya cubiertas por
    -- self.Drawings) -- es una Instance real (Instance.new("Part")), Destroy() en cascada se lleva
    -- consigo los 17 ParticleEmitter hijos (10 presets, 1-3 emitters c/u) sin loop adicional.
    ------------------------------------------------------------------------------------------
    function Combat:_ensureParticleLib()
        local lib = self._particleLib
        if lib then return lib end
        local part = Instance.new("Part")
        part.Name = "\0"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
        part.CastShadow = false
        part.Size = Vector3.new(0.01, 0.01, 0.01)
        part.Parent = self.Services.Workspace
        table.insert(self._made, part)
        lib = { part = part, presets = buildHitParticlePresets(part) }
        self._particleLib = lib
        return lib
    end

    -- juju do_hit_particle (L14770-14780): mueve el Part al CFrame de la parte golpeada (no solo
    -- Position -- varios emitters usan EmissionDirection/orientacion relativa al Part, ej. sparks
    -- Orientation=VelocityParallel + SpreadAngle(50,-50)), recolorea TODOS los emitters del preset
    -- seleccionado (color/lethal via provider.onHit lethal bool, mismo patron que Marker/Damage),
    -- fuerza ZOffset a 0/1 segun el toggle "behind walls" -- ESTO SOBREESCRIBE el ZOffset baked-in
    -- de cada emitter (ej. blood 3er emitter trae ZOffset=4, light trae 4/5, blackflash 3/3.96/3.46,
    -- meteor trae 3) -- comportamiento 1:1 de juju, no un bug de este port: cada hit fuerza 0 (o 1
    -- con behind_walls ON) en TODOS los emitters del preset, pisando su valor base. Y llama
    -- :Emit(count) por emitter -- fire-and-forget, sin ciclo de vida que trackear en :_update
    -- (brief: "particle emission is :Emit-based/self-expiring").
    function Combat:_fireParticle(cf, lethal, now)
        local lib = self:_ensureParticleLib()
        local presetName = self:_flag("ParticlePreset", "sparks")
        local preset = lib.presets[presetName] or lib.presets.sparks
        if not preset then return end
        local color = ColorSequence.new(lethal and GV.Color.fade(self.Flags, "Combat_ParticleLethal", now)
            or GV.Color.fade(self.Flags, "Combat_ParticleColor", now))
        local zOffset = self:_flag("ParticleBehindWalls", false) and 1 or 0
        lib.part.CFrame = cf
        for _, p in ipairs(preset) do
            p.emitter.Color = color
            p.emitter.ZOffset = zOffset
            p.emitter:Emit(p.count)
        end
    end

    ------------------------------------------------------------------------------------------
    -- Task 8 -- Hit Chams: clone helper (ver header del archivo para las 2 adaptaciones grandes
    -- ya documentadas -- animType congelado al spawn, animador per-frame en vez de heartbeat-
    -- push). Patron de clone YA establecido en este proyecto (ui/preview.lua L87-88,
    -- dist/Visuals.*.lua): guarda el Archivable previo y lo RESTAURA tras el clone -- a
    -- diferencia de juju (`character["Archivable"]=true -> clone -> character["Archivable"]=
    -- false`, que deja el Character ajeno permanentemente Archivable=false incluso si estaba
    -- true antes), esto no muta el estado del Character de otro jugador mas alla del instante
    -- del clone.
    ------------------------------------------------------------------------------------------
    function Combat:_cloneCharacter(character)
        local m
        local ok = pcall(function()
            local prev = character.Archivable
            character.Archivable = true
            m = character:Clone()
            character.Archivable = prev
        end)
        if not (ok and m) then return nil end
        return m
    end

    -- template SelectionBox lazy-cached (juju L15219-15225 `hit_chams_part`, clonado por-part en
    -- la variante outline) -- mismo criterio lazy que _beamTemplate/_particleLib arriba. Nunca se
    -- parentea (juju tampoco lo parentea, solo lo usa como fuente de :Clone()); se destruye en
    -- :Unload.
    --
    -- NOTA (review finding, fix): el accessor se nombra DISTINTO al campo que cachea
    -- (self._chamsOutlineTemplate) -- mismo criterio que _ensureRing()->self._ring y
    -- _ensureParticleLib()->self._particleLib arriba. Nombrar el metodo IGUAL al campo
    -- (`_chamsOutlineTemplate` -> `self._chamsOutlineTemplate`) rompia el lookup: con
    -- Combat.__index=Combat, `self._chamsOutlineTemplate` sin valor propio en la instancia cae
    -- al metodo del metatable (una funcion, truthy) -- el `if t then return t end` devolvia esa
    -- funcion en vez de fabricar el SelectionBox, y `_buildChamsOutline` llamaba `:Clone()` sobre
    -- una funcion -> error en TODO hit con Combat_ChamsType=="outline" (variante outline rota).
    function Combat:_ensureChamsOutlineTemplate()
        local t = self._chamsOutlineTemplate
        if t then return t end
        t = Instance.new("SelectionBox")
        t.LineThickness = 0.01
        t.Name = "\0"
        self._chamsOutlineTemplate = t
        return t
    end

    -- que cuenta como "limb visible del cuerpo" para el filtro BasePart-general (adaptacion 3,
    -- ver header). Ademas de HumanoidRootPart, LiP agrega 5 `RDCollision` Part por Character
    -- (verificado LIVE: Transparency=1, CanCollide=false -- hitboxes de ragdoll por-limb,
    -- invisibles) -- sin esta exclusion quedarian recoloreadas como cajas fantasma flotantes
    -- sobre cada limb (ni HumanoidRootPart ni RDCollision son MeshPart, asi que el filtro viejo
    -- las excluia "gratis"; el filtro nuevo, mas amplio, necesita excluirlas a mano). Compartida
    -- por :_buildChamsSolid y :_buildChamsOutline.
    local function isChamsLimb(part)
        return part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "RDCollision"
    end

    -- juju do_hit_chams (L15319-15376), variantes forcefield/neon -- comparten esta logica de
    -- recolor, difieren solo en `material`. Devuelve `faders` (las Instances que el animador de
    -- :_updateChams debe fade/grow) + `growSizes` ([Instance]=Vector3, snapshot de Size ANTES de
    -- crecer -- usado por el animador "new fade").
    --
    -- Adaptacion vs juju (ver brief "adapt, do not invent" + mandato de :_update sobre no-leak):
    -- juju itera TODOS los hijos del modelo en el animador (`get_children(model)`) y filtra ahi
    -- (`child_transparency ~= 1` salta las partes reales ocultas de la variante outline). Acá se
    -- arma explicitamente la lista `faders` con SOLO las Instances que este build efectivamente
    -- recoloreo/creo -- las partes reales ocultas de la variante outline (Transparency=1,
    -- Anchored=true) simplemente no entran en `faders`, logrando el mismo resultado visual
    -- (nunca se tocan) sin necesitar el guard `~= 1` en el animador.
    -- NOTA (review finding, fix): el recolor por-part esta pcall-wrapped (igual criterio
    -- defensivo que :_cloneCharacter arriba) -- una propiedad que tira error en UNA parte
    -- (mesh corrupta, propiedad no soportada por el executor, etc.) ya no aborta el :_spawnChams
    -- completo (que perderia el clone entero silenciosamente, antes de llegar a
    -- self._activeChams/model.Parent) -- esa parte simplemente no entra en `faders`/`growSizes`
    -- (no se anima), el resto del clone sigue su curso normal.
    -- NOTA (review finding, fix -- ver adaptacion 3 en el header del archivo): filtro ampliado de
    -- MeshPart a BasePart (verificado LIVE: LiP es R6, todo el cuerpo son `Part` comunes, no
    -- MeshPart -- el filtro viejo dejaba el clon solido vacio). `TextureID` es exclusiva de
    -- MeshPart -- gateada adentro del pcall para no cortar el resto de props en una parte comun.
    -- HumanoidRootPart/RDCollision excluidas via :isChamsLimb (caen al mismo `else:
    -- destroy(part)` de siempre).
    function Combat:_buildChamsSolid(model, material, color)
        local faders, growSizes = {}, {}
        for _, part in ipairs(model:GetChildren()) do
            if isChamsLimb(part) then
                local isMesh = part:IsA("MeshPart")
                local ok = pcall(function()
                    part.Material = material
                    part.Color = color
                    part.Transparency = CHAMS_TRANSPARENCY
                    if isMesh then part.TextureID = "" end
                    part.CanCollide = false
                    part.Anchored = true
                    if part.Name == "Head" then
                        local decal = part:FindFirstChildOfClass("Decal")
                        if decal then decal:Destroy() end
                    end
                end)
                if ok then
                    faders[#faders + 1] = part
                    growSizes[part] = part.Size
                end
            elseif part:IsA("Accessory") then
                -- juju L15354-15365: si el Accessory no trae un MeshPart adentro (`hat` nil), se
                -- deja INTACTO (ni recolor ni destroy) -- 1:1, no un caso omitido.
                local hat = part:FindFirstChildOfClass("MeshPart")
                if hat then
                    local ok = pcall(function()
                        hat.Material = material
                        hat.Color = color
                        hat.Transparency = CHAMS_TRANSPARENCY
                        hat.TextureID = ""
                        hat.CanCollide = false
                        hat.Anchored = true
                        hat.Parent = model
                    end)
                    if ok then
                        faders[#faders + 1] = hat
                        growSizes[hat] = hat.Size
                    end
                    part:Destroy() -- vacio (el hat ya salio, exito o no) -- siempre fuera del pcall, Destroy() no falla
                end
            else
                part:Destroy() -- Humanoid/HumanoidRootPart/RDCollision/scripts/Shirt/Pants/BodyColors/etc.
            end
        end
        return faders, growSizes
    end

    -- juju do_hit_chams_outline (L15378-15425): oculta la parte real (Transparency=1) y clona un
    -- SelectionBox adornado sobre ella, por cada parte visible del cuerpo. Sin growSizes
    -- (SelectionBox no tiene Size) -- animType "new fade" fadea igual, solo sin el efecto de
    -- crecimiento.
    -- NOTA (review finding, fix): mismo criterio pcall que :_buildChamsSolid arriba -- un fallo
    -- a mitad de una parte (ej. Adornee rechazado) no aborta el :_spawnChams completo. El
    -- `outline` sin trackear en `faders` (ok==false) igual se limpia solo: es descendiente de
    -- `model`, y ese Model entero se destruye en :_updateChams/Unload independientemente de
    -- `faders` -- no hay leak, solo pierde su animacion de fade individual.
    -- NOTA (review finding, fix -- ver adaptacion 3 en el header del archivo): filtro ampliado de
    -- "MeshPart O Head-por-nombre" a BasePart en general (verificado LIVE: LiP R6 -- juju's
    -- fallback de nombre solo rescataba Head, dejando Torso/brazos/piernas sin outline). El
    -- chequeo `isHead` se conserva SOLO para el strip del Decal "face" (logica sin relacion al
    -- filtro de inclusion, que ahora cubre el cuerpo entero). HumanoidRootPart/RDCollision
    -- excluidas via :isChamsLimb, mismo criterio que :_buildChamsSolid.
    function Combat:_buildChamsOutline(model, color)
        local template = self:_ensureChamsOutlineTemplate()
        local faders = {}
        for _, part in ipairs(model:GetChildren()) do
            if isChamsLimb(part) then
                local isHead = part.Name == "Head"
                local partName = part.Name
                local outline
                local ok = pcall(function()
                    part.Transparency = 1
                    part.CanCollide = false
                    part.Anchored = true
                    outline = template:Clone()
                    outline.Name = partName
                    outline.Color3 = color
                    outline.Transparency = CHAMS_TRANSPARENCY
                    outline.Adornee = part
                    outline.Parent = model
                    part.Name = "\0"
                    if isHead then
                        local face = part:FindFirstChild("face")
                        if face then face:Destroy() end
                    end
                end)
                if ok and outline then
                    faders[#faders + 1] = outline
                end
            else
                part:Destroy()
            end
        end
        return faders
    end

    -- juju L15319-15325 / L15378-15384: el destroy-si-only-last-hit pasa ANTES del chequeo de
    -- Character -- si el jugador golpeado no tiene char (edge case), el chams anterior igual se
    -- destruye y no se spawnea uno nuevo (1:1, mismo orden que juju).
    function Combat:_spawnChams(player, now)
        local ok, character = pcall(function() return player and player.Character end)
        character = (ok and character) or nil

        if self:_flag("ChamsOnlyLast", false) and self._lastChams then
            local prev = self._lastChams
            pcall(function() prev.model:Destroy() end)
            for i = #self._activeChams, 1, -1 do
                if self._activeChams[i] == prev then table.remove(self._activeChams, i); break end
            end
            self._lastChams = nil
        end

        if not character then return end

        local kind = self:_flag("ChamsType", "neon")
        -- animType leido UNA vez acá (congelado al spawn) -- ver header del archivo, adaptacion 1.
        local animType = self:_flag("ChamsAnimation", "new fade")
        local color = GV.Color.fade(self.Flags, "Combat_ChamsColor", now)
        local lifetime = self:_flag("ChamsLifetime", 0.8)

        local model = self:_cloneCharacter(character)
        if not model then return end
        model.Name = "\0"

        local faders, growSizes
        if kind == "outline" then
            faders = self:_buildChamsOutline(model, color)
        else
            -- juju L15454: "neon"->Neon, "forcefield" o cualquier otro valor->ForceField (mismo fallback).
            local material = (kind == "neon") and Enum.Material.Neon or Enum.Material.ForceField
            faders, growSizes = self:_buildChamsSolid(model, material, color)
        end
        model.Parent = self.Services.Workspace

        local entry = {
            model = model, faders = faders, growSizes = growSizes, animType = animType,
            curveDur = (animType == "new fade") and CHAMS_NEWFADE_CURVE_DUR or CHAMS_FADE_CURVE_DUR,
            spawnT = now, lifetime = lifetime, fading = false, fadeStart = nil, fadeAlpha = 0,
        }
        table.insert(self._activeChams, entry)
        self._lastChams = entry
    end

    -- animador per-frame (reemplaza destroy_hit_chams_fade/new_fade/none de juju, ver header del
    -- archivo adaptacion 2). animType=="none": destruye INMEDIATO al vencer el lifetime, sin
    -- ventana (juju destroy_hit_chams_none = destroy(model) directo, sin delay adicional).
    -- fade/new fade: dispara GV.Tween sobre `e.fadeAlpha` (0->1, mismo patron que e.fadeAlpha de
    -- :_updateBeamTracers) durante `e.curveDur`; la ventana total hasta destroy sigue siendo
    -- CHAMS_TOTAL_FADE_DUR (0.25s) para ambas variantes con curva (juju: el `delay(0.25,...)` de
    -- destroy es el mismo en L15252 y L15306 independiente de que la curva interna dure 0.25 o
    -- 0.15) -- tras completar la curva (curveDur<TOTAL_FADE_DUR en "new fade"), el modelo queda
    -- congelado en transparency=1/size maxima el resto de la ventana.
    function Combat:_updateChams(now)
        local list = self._activeChams
        for i = #list, 1, -1 do
            local e = list[i]
            if not e.fading and (now - e.spawnT) >= e.lifetime then
                e.fading = true; e.fadeStart = now
                if e.animType == "none" then
                    pcall(function() e.model:Destroy() end)
                    if self._lastChams == e then self._lastChams = nil end
                    table.remove(list, i)
                else
                    GV.Tween(e, { fadeAlpha = 1 }, "quad", e.curveDur)
                end
            elseif e.fading then
                local transparency = CHAMS_TRANSPARENCY + (1 - CHAMS_TRANSPARENCY) * e.fadeAlpha
                for _, part in ipairs(e.faders) do
                    pcall(function()
                        part.Transparency = transparency
                        local oldSize = e.growSizes and e.growSizes[part]
                        if oldSize then part.Size = oldSize + CHAMS_GROW_SIZE * transparency end
                    end)
                end
                if (now - e.fadeStart) >= CHAMS_TOTAL_FADE_DUR then
                    pcall(function() e.model:Destroy() end)
                    if self._lastChams == e then self._lastChams = nil end
                    table.remove(list, i)
                end
            end
        end
    end

    -- ── triggers del provider ──
    function Combat:_onShot(origin, hitPos, isLocal)
        if not (self:_flag("Enabled", false) and self:_flag("Tracer", false)) then return end
        if typeof(origin) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then return end
        local now = os.clock()
        local kind = self:_flag("TracerType", "beam")
        if kind == "line" then self:_spawnLineTracer(origin, hitPos, now)
        else self:_spawnBeamTracer(origin, hitPos, now) end
    end
    function Combat:_onHit(plr, part, dmg, lethal)
        -- Task 4 (Hitmarker 3D+2D) + Task 5 (Damage Numbers, este bloque). Tasks 7/8 (Hit
        -- Particles, Hit Chams) enganchan acá tambien mas adelante. Gate SOLO del lado del spawn
        -- (Combat_Enabled + el toggle de cada feature) -- ver nota en :_update sobre por que los
        -- updaters corren incondicionalmente.
        if not self:_flag("Enabled", false) then return end
        local now = os.clock()
        if self:_flag("Marker3D", false) then
            local ok, pos = pcall(function() return part.Position end)
            if ok and typeof(pos) == "Vector3" then self:_spawnMarker3D(pos, lethal, now) end
        end
        if self:_flag("Marker2D", false) then
            self:_spawnMarker2D(lethal, now)
        end
        if self:_flag("Damage", false) then
            local ok, pos = pcall(function() return part.Position end)
            if ok and typeof(pos) == "Vector3" then self:_spawnDamageNumber(pos, dmg, lethal, now) end
        end
        -- Task 7 (Hit Particles, este bloque). CFrame completo (no solo Position) -- ver nota en
        -- :_fireParticle sobre por que la orientacion del Part importa para varios emitters.
        if self:_flag("Particle", false) then
            local ok, cf = pcall(function() return part.CFrame end)
            if ok and typeof(cf) == "CFrame" then self:_fireParticle(cf, lethal, now) end
        end
        -- Task 8 (Hit Chams, este bloque -- ULTIMA feature). A diferencia de Marker/Damage/
        -- Particle arriba, no consume `part`/`dmg`/`lethal` -- solo `plr` (el Player golpeado,
        -- ver :_spawnChams).
        if self:_flag("Chams", false) then
            self:_spawnChams(plr, now)
        end
    end

    -- GV.tweenStep + TODOS los updaters (tracers + hitmarkers + damage numbers + target ring +
    -- hit chams) corren SIEMPRE, sin gatear por Combat_Enabled -- igual convencion que Aura:_update/
    -- ESP:_update (tweenStep incondicional). Si se gatearan, apagar Combat_Enabled con un
    -- tracer/marker/numero a mitad de fade lo congelaria (Drawing/Beam visibles) para siempre
    -- hasta re-activar o Unload -- el pool nunca liberaria el bundle ni el Beam se destruiria.
    -- El toggle solo debe frenar SPAWNS nuevos (ya gateado en :_onShot/:_onHit); lo ya disparado
    -- debe poder terminar su ciclo de vida (fade -> release/destroy) igual. Confirmado como
    -- review finding de Task 3, mandatorio para Task 4/5. Task 6 (:_updateRing) no es
    -- event-spawn (no tiene ciclo de vida que terminar), pero sigue el MISMO mandato de correr
    -- incondicional -- gatea su propia visibilidad adentro (ver nota grande sobre
    -- :_updateRing), nunca aca, para no starvear al resto de updaters de arriba si alguien
    -- intentara un `if not self:_flag("Ring") then return end` temprano en :_update.
    function Combat:_update(now, dt)
        GV.tweenStep(now, dt)
        self:_updateLineTracers(now)
        self:_updateBeamTracers(now)
        self:_updateMarker3D(now)
        self:_updateMarker2D(now)
        self:_updateDamage(now)
        self:_updateRing(now)
        self:_updateChams(now)
    end

    function Combat:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local lastT = os.clock()
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local now = os.clock(); local dt = now - lastT; lastT = now
            local ok, err = pcall(function() self:_update(now, dt) end)
            if not ok then warn("[Combat] " .. tostring(err)) end
        end)
        if self._provider then
            local shot = resolveSignal(self._provider.onShot)
            if shot and shot.Connect then
                local ok, conn = pcall(function()
                    return shot:Connect(function(origin, hitPos, isLocal) self:_onShot(origin, hitPos, isLocal) end)
                end)
                if ok and conn then self.Conns[#self.Conns + 1] = conn end
            end
            local hit = resolveSignal(self._provider.onHit)
            if hit and hit.Connect then
                local ok, conn = pcall(function()
                    return hit:Connect(function(plr, part, dmg, lethal) self:_onHit(plr, part, dmg, lethal) end)
                end)
                if ok and conn then self.Conns[#self.Conns + 1] = conn end
            end
        end
        return self
    end

    function Combat:Unload()
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        -- beams no viven en self._made (ver nota en :_spawnBeamTracer) -- self._activeBeam es su
        -- propio safety net: cualquier tracer todavia vivo/fading al momento de Unload se destruye acá.
        for _, e in ipairs(self._activeBeam) do
            pcall(function() e.beam:Destroy() end)
            pcall(function() e.att0:Destroy() end)
            pcall(function() e.att1:Destroy() end)
        end
        -- hitmarkers (Task 4), damage numbers (Task 5) y el target ring (Task 6) NO necesitan
        -- destroy explicito -- sus Drawing "Line"/"Text" ya se crearon via self:_draw y quedaron
        -- registradas en self.Drawings, cubiertas por el loop de arriba. Solo hace falta vaciar
        -- los pools/listas de tracking -- self._ring = nil (a diferencia de los table.clear() de
        -- abajo, que vacian pero conservan la MISMA tabla) fuerza a :_ensureRing a fabricar un
        -- pool de 32 Drawings NUEVO en el proximo Init -- las 32 lineas viejas ya fueron
        -- :Remove()-idas arriba, retener esa referencia las dejaria apuntando a Drawings muertas.
        -- self._particleLib (Task 7) sigue el mismo criterio que self._ring: el Part (y sus 17
        -- ParticleEmitter hijos, destruidos en cascada) ya fue :Destroy()-ido arriba via el loop de
        -- self._made (esta registrado ahi, ver :_ensureParticleLib) -- self._particleLib = nil solo
        -- fuerza una fabricacion NUEVA (Part + presets) en el proximo :_ensureParticleLib, evitando
        -- retener una referencia a un Part ya destruido.
        -- self._activeChams (Task 8) NO vive en self._made (mismo motivo que self._activeBeam:
        -- son Models parenteados directo a Workspace, con su propio ciclo de vida de fade->
        -- destroy) -- cualquier chams todavia vivo/fading al momento de Unload se destruye acá
        -- (mandato del brief: "no unbounded growth" cubre tambien el caso "modulo descargado a
        -- mitad de vuelo"). self._chamsOutlineTemplate sigue el mismo criterio que
        -- self._particleLib/self._ring: se destruye y se nillea para forzar una fabricacion
        -- nueva en el proximo :_ensureChamsOutlineTemplate.
        for _, e in ipairs(self._activeChams) do
            pcall(function() e.model:Destroy() end)
        end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made)
        table.clear(self._linePool); table.clear(self._activeLine); table.clear(self._activeBeam)
        table.clear(self._marker3DPool); table.clear(self._active3D)
        table.clear(self._marker2DPool); table.clear(self._active2D)
        table.clear(self._damagePool); table.clear(self._activeDamage)
        table.clear(self._activeChams)
        self._lastChams = nil
        if self._chamsOutlineTemplate then
            pcall(function() self._chamsOutlineTemplate:Destroy() end)
            self._chamsOutlineTemplate = nil
        end
        self._ring = nil
        self._particleLib = nil
    end

    GV.Combat = Combat
    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.new = function(o) return Combat.new(o) end
end
