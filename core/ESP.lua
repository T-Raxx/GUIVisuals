return function(GV)
    if not (Drawing and Drawing.new) then
        GV.Modules = GV.Modules or {}; GV.Modules.esp = GV.Modules.esp or {}
        GV.Modules.esp.new = GV.Modules.esp.new or function() return { Init = function() end, Unload = function() end } end
        return
    end
    local ESP = {}
    ESP.__index = ESP

    function ESP.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
            CollectionService = game:GetService("CollectionService"),
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, Objects = {}, Highlights = {}, Loaded = false,
        }, ESP)
    end

    function ESP:Set(k, v) self.Flags[k] = v end
    function ESP:Get(k) return self.Flags[k] end
    function ESP:_flag(k, d)
        local v = self.Flags["ESP_" .. k]; if v ~= nil then return v end; return d
    end
    function ESP:UseProfile(p)
        if not p then return end
        if p.provider then self._provider = p.provider end
        if p.objectSources then self._objectSources = p.objectSources end
    end

    function ESP:_draw(class, props)
        local o = Drawing.new(class)
        o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o)
        return o
    end

    function ESP:_provget()
        local p = self._provider or GV.DefaultProvider
        if not p then return {} end
        local ok, list = pcall(p.getTargets, self)
        return (ok and list) or {}
    end

    function ESP:_update()
        -- (features se agregan en tasks siguientes)
    end

    function ESP:Init()
        if self.Loaded then return self end
        self.Loaded = true
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_update() end)
            if not ok then warn("[ESP] " .. tostring(err)) end
        end)
        return self
    end

    function ESP:Unload()
        if not self.Loaded then return end
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Objects); table.clear(self.Highlights)
    end

    GV.ESP = ESP
    GV.Modules = GV.Modules or {}
    GV.Modules.esp = GV.Modules.esp or {}
    GV.Modules.esp.new = function(o) return ESP.new(o) end
end
