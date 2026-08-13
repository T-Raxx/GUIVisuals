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
        -- Task 4 (Hitmarker 3D+2D, este bloque). Tasks 5/7/8 (Damage Numbers, Hit Particles, Hit
        -- Chams) enganchan acá tambien mas adelante. Gate SOLO del lado del spawn (Combat_Enabled
        -- + el toggle de cada marker) -- ver nota en :_update sobre por que los updaters corren
        -- incondicionalmente.
        if not self:_flag("Enabled", false) then return end
        local now = os.clock()
        if self:_flag("Marker3D", false) then
            local ok, pos = pcall(function() return part.Position end)
            if ok and typeof(pos) == "Vector3" then self:_spawnMarker3D(pos, lethal, now) end
        end
        if self:_flag("Marker2D", false) then
            self:_spawnMarker2D(lethal, now)
        end
    end

    -- GV.tweenStep + TODOS los updaters (tracers + hitmarkers) corren SIEMPRE, sin gatear por
    -- Combat_Enabled -- igual convencion que Aura:_update/ESP:_update (tweenStep incondicional).
    -- Si se gatearan, apagar Combat_Enabled con un tracer/marker a mitad de fade lo congelaria
    -- (Drawing/Beam visibles) para siempre hasta re-activar o Unload -- el pool nunca liberaria el
    -- bundle ni el Beam se destruiria. El toggle solo debe frenar SPAWNS nuevos (ya gateado en
    -- :_onShot/:_onHit); lo ya disparado debe poder terminar su ciclo de vida (fade ->
    -- release/destroy) igual. Confirmado como review finding de Task 3, mandatorio para Task 4.
    function Combat:_update(now, dt)
        GV.tweenStep(now, dt)
        self:_updateLineTracers(now)
        self:_updateBeamTracers(now)
        self:_updateMarker3D(now)
        self:_updateMarker2D(now)
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
        -- hitmarkers (Task 4) NO necesitan destroy explicito -- sus Drawing "Line" (lineas +
        -- outlines) ya se crearon via self:_draw y quedaron registradas en self.Drawings, cubiertas
        -- por el loop de arriba. Solo hace falta vaciar los pools/listas de tracking.
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made)
        table.clear(self._linePool); table.clear(self._activeLine); table.clear(self._activeBeam)
        table.clear(self._marker3DPool); table.clear(self._active3D)
        table.clear(self._marker2DPool); table.clear(self._active2D)
    end

    GV.Combat = Combat
    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.new = function(o) return Combat.new(o) end
end
