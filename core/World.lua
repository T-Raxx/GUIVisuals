return function(GV)
    local U = GV.Util
    local World = {}
    World.__index = World

    function World.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Lighting = game:GetService("Lighting"),
            Terrain = workspace:FindFirstChildOfClass("Terrain"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        local self = setmetatable({
            Flags = {}, Services = svc, Conns = {},
            _orig = {}, _made = {}, _fxCache = {}, _applies = {},
            Loaded = false, _wasOn = false,
        }, World)
        return self
    end

    function World:Set(flag, v) self.Flags[flag] = v end
    function World:Get(flag) return self.Flags[flag] end
    function World:_flag(name, default)
        local v = self.Flags[name]
        if v ~= nil then return v end
        return default
    end

    -- serializa para config (Color3/Enum -> tablas nombradas)
    function World:GetFlags()
        local out = {}
        for k, v in pairs(self.Flags) do
            if typeof(v) == "Color3" then out[k] = U.serColor(v)
            elseif typeof(v) == "EnumItem" then out[k] = U.serEnum(v)
            else out[k] = v end
        end
        return out
    end
    function World:LoadFlags(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" and v.__ == "c3" then self.Flags[k] = U.deColor(v)
            elseif type(v) == "table" and v.__ == "en" then self.Flags[k] = U.deEnum(v)
            else self.Flags[k] = v end
        end
    end

    function World:_set(obj, prop, val)
        if not obj then return end
        local ok, cur = pcall(function() return obj[prop] end)
        if not ok then return end
        local mem = self._orig[obj]
        if not mem then mem = {}; self._orig[obj] = mem end
        if mem[prop] == nil then mem[prop] = cur end
        if cur ~= val then pcall(function() obj[prop] = val end) end
    end
    function World:_restoreAll()
        for obj, props in pairs(self._orig) do
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end
        end
        table.clear(self._orig)
    end

    -- crear (una vez) un efecto propio, nombrado como los del juego para no cantar en scan
    function World:_fx(class, parent)
        local got = self._fxCache[class]
        if got and got.Parent then return got end
        local inst = Instance.new(class)
        inst.Name = "LightingController"
        pcall(function() inst.Parent = parent or self.Services.Lighting end)
        self._fxCache[class] = inst
        table.insert(self._made, inst)
        return inst
    end

    function World:_register(fn) table.insert(self._applies, fn) end

    function World:_step()
        if not self:_flag("World_Enabled", false) then
            if self._wasOn then self:_off() end
            return
        end
        self._wasOn = true
        for _, fn in ipairs(self._applies) do
            local ok, err = pcall(fn, self)
            if not ok then warn("[World] apply: " .. tostring(err)) end
        end
    end

    function World:_off()
        self._wasOn = false
        for _, inst in pairs(self._fxCache) do
            pcall(function() if inst:IsA("PostEffect") then inst.Enabled = false end end)
        end
        self:_restoreAll()
    end

    function World:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local conn = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_step() end)
            if not ok then warn("[World] step: " .. tostring(err)) end
        end)
        self.Conns[#self.Conns + 1] = conn
        return self
    end

    function World:Unload()
        if not self.Loaded then return end
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        table.clear(self.Conns)
        self:_restoreAll()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self._made)
        self._fxCache = {}
    end

    GV.World = World
end
