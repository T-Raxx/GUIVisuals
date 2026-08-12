-- core/aura.lua — modulo "aura": 15 auras cosmeticas sobre el char local (6 procedural +
-- 9 rbxassetid, Task 2 del combat-vfx-port). Task 1 = solo scaffold: carga, se engancha a
-- provider.onShot/onHit/localCharacter, :_update no-op salvo GV.tweenStep. Sin render aun.
-- Skeleton mirror de core/selffx.lua (misma convencion de modulo Attach-instanciable).
return function(GV)
    local Aura = {}
    Aura.__index = Aura

    function Aura.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _made = {}, Loaded = false,
        }, Aura)
    end

    function Aura:Set(k, v) self.Flags[k] = v end
    function Aura:Get(k) return self.Flags[k] end
    function Aura:_flag(k, d)
        local v = self.Flags["Aura_" .. k]; if v ~= nil then return v end; return d
    end
    function Aura:UseProfile(p) if p then self._provider = p end end

    function Aura:_draw(class, props)
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end
        local o = Drawing.new(class); o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o); return o
    end

    -- ver comentario identico en core/combat.lua: onShot/onHit del perfil lifeinprison son
    -- funciones LAZY (getgenv().LIP no existe todavia cuando este modulo se construye).
    local function resolveSignal(v)
        if type(v) == "function" then local ok, r = pcall(v); return ok and r or nil end
        return v
    end

    -- ── triggers del provider (stubs; feature real = Task 2) ──
    function Aura:_onShot(origin, hitPos, isLocal) end
    function Aura:_onHit(plr, part, dmg, lethal) end

    function Aura:_update(now, dt)
        if not self:_flag("Enabled", false) then return end
        GV.tweenStep(now, dt)
        -- Task 2: (re)aplicar la aura seleccionada sobre provider.localCharacter() acá.
    end

    function Aura:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local lastT = os.clock()
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local now = os.clock(); local dt = now - lastT; lastT = now
            local ok, err = pcall(function() self:_update(now, dt) end)
            if not ok then warn("[Aura] " .. tostring(err)) end
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

    function Aura:Unload()
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made)
    end

    GV.Aura = Aura
    GV.Modules = GV.Modules or {}
    GV.Modules.aura = GV.Modules.aura or {}
    GV.Modules.aura.new = function(o) return Aura.new(o) end
end
