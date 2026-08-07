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

    function SelfFX:_update() end

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
