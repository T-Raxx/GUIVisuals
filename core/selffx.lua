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
    function SelfFX:_applyCamera()
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        if self:_flag("FOV", false) then
            local fov = self:_flag("FOVValue", 70)
            if self._provider and self._provider.setFOV then self._provider.setFOV(fov - 70)
            else self:_set(cam, "FieldOfView", fov) end
        end
        if self:_flag("ThirdPerson", false) then
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(true)
            else self:_thirdPersonGeneric(cam) end
        end
        local am = self:_flag("AspectMode", "Off")
        if am ~= "Off" then
            pcall(function() self:_set(cam, "FieldOfViewMode", Enum.FieldOfViewMode[am]) end)
            if am == "MaxAxis" then self:_set(cam, "MaxAxisFieldOfView", self:_flag("MaxAxisFOV", 90)) end
        end
    end

    -- 3ra persona genérica (best-effort): sin provider no forzamos; placeholder para L5.
    function SelfFX:_thirdPersonGeneric(cam) end

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
        local t = tick()
        self:_applyCamera()
        self:_applyCrosshair(t)
    end

    function SelfFX:Init()
        if self.Loaded then return self end
        self.Loaded = true
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_update() end)
            if not ok then warn("[SelfFX] " .. tostring(err)) end
        end)
        return self
    end

    function SelfFX:Unload()
        self.Loaded = false
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
