-- core/combat.lua — modulo "combat": tracers, hitmarker 2D/3D, damage numbers, target ring,
-- hit particles, hit chams (Tasks 3-8 del combat-vfx-port). Task 1 = solo scaffold: carga,
-- se engancha a provider.onShot/onHit, :_update no-op salvo GV.tweenStep. Sin render aun.
-- Skeleton mirror de core/selffx.lua (misma convencion de modulo Attach-instanciable).
--
-- Task 3 (Hit Tracers, este bloque): port de jujudotlol.lua L13276-13303 (menu) + L13364-13547
-- (beams bank / do_beam_bullet_tracer / do_line_bullet_tracer). Disparo: provider.onShot
-- (origin, hitPos, isLocal) <- LIP.Weapon.fireOne en cada op14.
return function(GV)
    local Combat = {}
    Combat.__index = Combat

    -- ventanas de fade POST-lifetime (constantes fijas en juju, no expuestas en el menu):
    -- linea L13518 (0.3s tras el lifetime, quad ease); beam L13414/destroy_beam (0.2s, quad ease).
    local LINE_FADE_DUR = 0.3
    local BEAM_FADE_DUR = 0.2

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
        table.insert(self._made, att0); table.insert(self._made, att1); table.insert(self._made, beam)
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
        -- Tasks 4/5/7/8 (Hitmarker, Damage Numbers, Hit Particles, Hit Chams) enganchan acá.
    end

    function Combat:_update(now, dt)
        if not self:_flag("Enabled", false) then return end
        GV.tweenStep(now, dt)
        self:_updateLineTracers(now)
        self:_updateBeamTracers(now)
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
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made)
        table.clear(self._linePool); table.clear(self._activeLine); table.clear(self._activeBeam)
    end

    GV.Combat = Combat
    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.new = function(o) return Combat.new(o) end
end
