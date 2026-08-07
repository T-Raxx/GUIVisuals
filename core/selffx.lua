return function(GV)
    local SelfFX = {}
    SelfFX.__index = SelfFX

    function SelfFX.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            UserInputService = game:GetService("UserInputService"),
            Workspace = workspace,
            Stats = game:FindService("Stats"),
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _orig = {}, _made = {}, Highlights = {}, Loaded = false,
        }, SelfFX)
    end

    function SelfFX:Set(k, v) self.Flags[k] = v end
    function SelfFX:Get(k) return self.Flags[k] end
    function SelfFX:_flag(k, d)
        local v = self.Flags["Local_" .. k]; if v ~= nil then return v end; return d
    end
    function SelfFX:UseProfile(p) if p then self._provider = p end end

    function SelfFX:_draw(class, props)
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end
        local o = Drawing.new(class); o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o); return o
    end

    -- escritura con memoria (restaura en Unload/off)
    function SelfFX:_set(obj, prop, val)
        if not obj then return end
        local ok, cur = pcall(function() return obj[prop] end)
        if not ok then return end
        local mem = self._orig[obj]; if not mem then mem = {}; self._orig[obj] = mem end
        if mem[prop] == nil then mem[prop] = cur end
        if cur ~= val then pcall(function() obj[prop] = val end) end
    end
    function SelfFX:_restoreAll()
        for obj, props in pairs(self._orig) do
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end
        end
        table.clear(self._orig)
    end

    -- Camara: FOV changer + 3ra persona + Custom Aspect Ratio.
    -- NOTA aspect: en Potassium ViewportSize es read-only duro (setscriptable/sethiddenproperty
    -- no lo escriben) -> stretch pixel-real NO reproducible sin render-hooks. Mecanismo entregable:
    -- FieldOfViewMode (Vertical/Diagonal/MaxAxis) + MaxAxisFieldOfView, que altera el mapeo FOV<->aspecto.
    -- restaura una prop guardada (revierte por-feature al apagar el toggle, sin esperar al master)
    function SelfFX:_restoreOne(obj, prop)
        local m = self._orig[obj]
        if m and m[prop] ~= nil then pcall(function() obj[prop] = m[prop] end); m[prop] = nil end
    end

    function SelfFX:_applyCamera()
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        -- FOV changer (cleanup al apagar)
        if self:_flag("FOV", false) then
            local fov = self:_flag("FOVValue", 70)
            if self._provider and self._provider.setFOV then self._provider.setFOV(fov - 70)
            else self:_set(cam, "FieldOfView", fov) end
        else
            if self._provider and self._provider.setFOV then self._provider.setFOV(0)
            else self:_restoreOne(cam, "FieldOfView") end
        end
        -- 3ra persona (cleanup al apagar)
        local plr = self.Services.Players and self.Services.Players.LocalPlayer
        if self:_flag("ThirdPerson", false) then
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(true)
            else self:_thirdPersonGeneric() end
        else
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(false)
            elseif plr then self:_restoreOne(plr, "CameraMode"); self:_restoreOne(plr, "CameraMaxZoomDistance") end
        end
    end

    -- Custom Aspect Ratio: stretch por matriz CFrame no-ortonormal (escala Right/Up de la camara).
    -- Funciona en CUALQUIER executor (no depende de ViewportSize). Se aplica DESPUES de la camara
    -- (BindToRenderStep Camera+1); reconstruye desde los vectores actuales cada frame -> NO compone.
    function SelfFX:_applyAspect()
        if not (self:_flag("Enabled", false) and self:_flag("Aspect", false)) then return end
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        local sx, sy = self:_flag("AspectH", 1), self:_flag("AspectV", 1)
        if sx == 1 and sy == 1 then return end
        -- post-multiplicar por una matriz de escala en espacio LOCAL de la camara (escala Right/Up).
        -- Corre en Camera+1 (cf ya ortonormal este frame) -> NO compone y es estable en cualquier pitch.
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, sx, 0, 0, 0, sy, 0, 0, 0, 1)
    end

    -- 3ra persona genérica (best-effort): habilita zoom-out (restaurado en unload).
    function SelfFX:_thirdPersonGeneric()
        local plr = self.Services.Players and self.Services.Players.LocalPlayer
        if not plr then return end
        pcall(function() self:_set(plr, "CameraMode", Enum.CameraMode.Classic) end)
        self:_set(plr, "CameraMaxZoomDistance", self:_flag("ThirdPersonDistance", 12))
    end

    -- fallback genérico (game-agnostic): CC/Blur en Lighting con nombre flash/blind
    function SelfFX:_genericFlashEffects()
        local out = {}
        local L = self.Services.Workspace and game:GetService("Lighting")
        if not L then return out end
        for _, e in ipairs(L:GetChildren()) do
            if (e:IsA("ColorCorrectionEffect") or e:IsA("BlurEffect")) then
                local n = string.lower(e.Name)
                if n:find("flash") or n:find("blind") then table.insert(out, e) end
            end
        end
        return out
    end

    -- Anti-flash / anti-smoke. Usa hooks del perfil si existen; si no, fallback genérico.
    function SelfFX:_applyAntiFlash()
        if self:_flag("AntiFlash", false) then
            local list
            if self._provider and self._provider.flashEffects then
                local ok, r = pcall(self._provider.flashEffects); list = ok and r or nil
            else
                list = self:_genericFlashEffects()
            end
            if list then for _, e in ipairs(list) do self:_set(e, "Enabled", false) end end
        end
        if self:_flag("AntiSmoke", false) and self._provider and self._provider.smokeEffects then
            local ok, list = pcall(self._provider.smokeEffects)
            if ok and list then for _, e in ipairs(list) do self:_set(e, "Enabled", false) end end
        end
    end

    -- Self-chams (Highlight sobre el char propio, detectable)
    function SelfFX:_applySelfChams(t)
        local plr = self.Services.Players and self.Services.Players.LocalPlayer
        local char = plr and plr.Character
        if not self:_flag("SelfChams", false) or not char then
            local h = self.Highlights["self"]; if h then h.Enabled = false end
            return
        end
        local h = self.Highlights["self"]
        if not h or not h.Parent then
            h = Instance.new("Highlight"); h.Name = "LC"; h.Parent = self.Services.Workspace.CurrentCamera
            self.Highlights["self"] = h
        end
        h.Adornee = char; h.Enabled = true
        h.FillColor = GV.Color.fade(self.Flags, "Local_SelfChamsFill", t)
        h.OutlineColor = GV.Color.fade(self.Flags, "Local_SelfChamsOutline", t)
        h.FillTransparency = self:_flag("SelfChamsFillTransparency", 0.5)
    end

    -- Crosshair (Drawing centrado en pantalla)
    function SelfFX:_makeCrosshair()
        if self._cross then return self._cross end
        self._cross = {
            top = self:_draw("Line", { Thickness = 1 }),
            bottom = self:_draw("Line", { Thickness = 1 }),
            left = self:_draw("Line", { Thickness = 1 }),
            right = self:_draw("Line", { Thickness = 1 }),
            dot = self:_draw("Square", { Filled = true }),
            circle = self:_draw("Circle", { Filled = false, NumSides = 32 }),
        }
        return self._cross
    end

    function SelfFX:_applyCrosshair(t)
        local c = self:_makeCrosshair()
        for _, o in pairs(c) do o.Visible = false end
        if not self:_flag("Crosshair", false) then return end
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        local col = GV.Color.fade(self.Flags, "Local_CrosshairColor", t)
        local style = self:_flag("CrosshairStyle", "Cross")
        local gap = self:_flag("CrosshairGap", 4)
        local size = self:_flag("CrosshairSize", 10)
        local th = self:_flag("CrosshairThickness", 1)
        local function line(o, fx, fy, tx, ty)
            o.Visible = true; o.From = Vector2.new(fx, fy); o.To = Vector2.new(tx, ty); o.Color = col; o.Thickness = th; o.ZIndex = 10
        end
        if style == "Cross" or style == "T" then
            line(c.left, cx - gap - size, cy, cx - gap, cy)
            line(c.right, cx + gap, cy, cx + gap + size, cy)
            line(c.bottom, cx, cy + gap, cx, cy + gap + size)
            if style == "Cross" then line(c.top, cx, cy - gap - size, cx, cy - gap) end
        elseif style == "Dot" then
            local d = math.max(2, size / 3)
            c.dot.Visible = true; c.dot.Size = Vector2.new(d, d); c.dot.Position = Vector2.new(cx - d / 2, cy - d / 2); c.dot.Color = col; c.dot.ZIndex = 10
        elseif style == "Circle" then
            c.circle.Visible = true; c.circle.Position = Vector2.new(cx, cy); c.circle.Radius = size; c.circle.Color = col; c.circle.Thickness = th; c.circle.ZIndex = 10
        end
    end

    -- HUD: watermark + hitmarker + keybind-list
    function SelfFX:_makeHUD()
        if self._hud then return self._hud end
        self._hud = {
            wm = self:_draw("Text", { Outline = true, Size = 14, Font = 2 }),
            kb = {},
            hit = { self:_draw("Line", { Thickness = 2 }), self:_draw("Line", { Thickness = 2 }),
                self:_draw("Line", { Thickness = 2 }), self:_draw("Line", { Thickness = 2 }) },
        }
        return self._hud
    end

    function SelfFX:_applyWatermark(t)
        local hud = self:_makeHUD()
        hud.wm.Visible = self:_flag("Watermark", false)
        if not hud.wm.Visible then return end
        local parts = {}
        if self:_flag("WM_Title", true) then table.insert(parts, "Visuals") end
        if self:_flag("WM_FPS", true) then table.insert(parts, (self._fps or 0) .. " fps") end
        if self:_flag("WM_Ping", true) then
            local ok, p = pcall(function() return math.floor(self.Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            if ok then table.insert(parts, p .. " ms") end
        end
        if self:_flag("WM_Name", true) then
            local ok, n = pcall(function() return self.Services.Players.LocalPlayer.Name end)
            if ok and n then table.insert(parts, n) end
        end
        if self:_flag("WM_Time", false) then
            local ok, ts = pcall(function() return os.date("%H:%M:%S") end); if ok then table.insert(parts, ts) end
        end
        if #parts == 0 then parts[1] = "Visuals" end
        hud.wm.Text = table.concat(parts, " | ")
        hud.wm.Color = GV.Color.fade(self.Flags, "Local_WatermarkColor", t)
        hud.wm.Position = Vector2.new(self:_flag("WatermarkX", 10), self:_flag("WatermarkY", 8))
        hud.wm.ZIndex = 10
    end

    function SelfFX:_applyHitmarker(t)
        local hud = self:_makeHUD()
        local active = self:_flag("Hitmarker", false) and self._hitUntil and tick() < self._hitUntil
        for _, l in ipairs(hud.hit) do l.Visible = active end
        if not active then return end
        local cam = self.Services.Workspace.CurrentCamera; if not cam then return end
        local vp = cam.ViewportSize; local cx, cy = vp.X / 2, vp.Y / 2
        local gap = self:_flag("HitmarkerGap", 4); local size = self:_flag("HitmarkerSize", 8)
        local col = GV.Color.fade(self.Flags, "Local_HitmarkerColor", t)
        local segs = {
            { cx - gap - size, cy - gap - size, cx - gap, cy - gap },
            { cx + gap, cy - gap, cx + gap + size, cy - gap - size },
            { cx - gap - size, cy + gap + size, cx - gap, cy + gap },
            { cx + gap, cy + gap, cx + gap + size, cy + gap + size },
        }
        for i, l in ipairs(hud.hit) do
            local s = segs[i]; l.From = Vector2.new(s[1], s[2]); l.To = Vector2.new(s[3], s[4]); l.Color = col; l.ZIndex = 11
        end
    end

    function SelfFX:_applyKeybindList(t)
        local hud = self:_makeHUD()
        for _, l in ipairs(hud.kb) do l.Visible = false end
        if hud.kb[0] then hud.kb[0].Visible = false end
        if not self:_flag("KeybindList", false) then return end
        -- fuente: provider.keybinds() > self._keybindList (features con keybind del schema)
        local list
        if self._provider and self._provider.keybinds then local ok, r = pcall(self._provider.keybinds); list = ok and r or nil end
        list = list or self._keybindList or {}
        local col = GV.Color.fade(self.Flags, "Local_KeybindColor", t)
        local x, y = self:_flag("KeybindX", 10), self:_flag("KeybindY", 120)
        local header = hud.kb[0]
        if not header then header = self:_draw("Text", { Outline = true, Size = 13, Font = 3 }); hud.kb[0] = header end
        header.Visible = true; header.Text = "[ keybinds ]"; header.Color = col; header.Position = Vector2.new(x, y); header.ZIndex = 10
        for i, kb in ipairs(list) do
            local o = hud.kb[i]
            if not o then o = self:_draw("Text", { Outline = true, Size = 13, Font = 2 }); hud.kb[i] = o end
            o.Visible = true
            o.Text = tostring(kb.name or "?") .. (kb.key and (" [" .. tostring(kb.key) .. "]") or "")
            o.Color = col; o.Position = Vector2.new(x, y + i * 15); o.ZIndex = 10
        end
    end

    function SelfFX:_off()
        self._wasOn = false
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false end) end
        for _, h in pairs(self.Highlights) do pcall(function() h.Enabled = false end) end
        self:_restoreAll()
    end

    function SelfFX:_update()
        if not self:_flag("Enabled", false) then
            if self._wasOn then self:_off() end
            return
        end
        self._wasOn = true
        local now = tick()
        if self._lastT then self._fps = math.floor(1 / math.max(1e-3, now - self._lastT) + 0.5) end
        self._lastT = now
        self:_applyCamera()
        self:_applyCrosshair(now)
        self:_applyWatermark(now)
        self:_applyHitmarker(now)
        self:_applyKeybindList(now)
        self:_applyAntiFlash()
        self:_applySelfChams(now)
    end

    function SelfFX:Init()
        if self.Loaded then return self end
        self.Loaded = true
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_update() end)
            if not ok then warn("[SelfFX] " .. tostring(err)) end
        end)
        if self._provider and self._provider.hitSignal then
            local ok, conn = pcall(function()
                return self._provider.hitSignal:Connect(function()
                    self._hitUntil = tick() + self:_flag("HitmarkerDuration", 0.3)
                end)
            end)
            if ok and conn then self.Conns[#self.Conns + 1] = conn end
        end
        -- aspect ratio: correr DESPUES de la camara (Camera+1) para que el stretch pegue
        local RS = self.Services.RunService
        if RS.BindToRenderStep then
            local ok = pcall(function()
                RS:BindToRenderStep("VisualsAspect", Enum.RenderPriority.Camera.Value + 1, function()
                    if self.Loaded then local o, e = pcall(function() self:_applyAspect() end); if not o then warn("[SelfFX aspect] " .. tostring(e)) end end
                end)
            end)
            self._aspectBound = ok
        end
        return self
    end

    function SelfFX:Unload()
        self.Loaded = false
        if self._aspectBound then pcall(function() self.Services.RunService:UnbindFromRenderStep("VisualsAspect") end); self._aspectBound = false end
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end
        self:_restoreAll()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Highlights); table.clear(self._made)
    end

    GV.SelfFX = SelfFX
    GV.Modules = GV.Modules or {}
    GV.Modules.selffx = GV.Modules.selffx or {}
    GV.Modules.selffx.new = function(o) return SelfFX.new(o) end
end
