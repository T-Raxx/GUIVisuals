-- core/combat.lua — modulo "combat": tracers, hitmarker 2D/3D, damage numbers, target ring,
-- hit particles, hit chams (Tasks 3-8 del combat-vfx-port). Task 1 = solo scaffold: carga,
-- se engancha a provider.onShot/onHit, :_update no-op salvo GV.tweenStep. Sin render aun.
-- Skeleton mirror de core/selffx.lua (misma convencion de modulo Attach-instanciable).
return function(GV)
    local Combat = {}
    Combat.__index = Combat

    function Combat.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _made = {}, Loaded = false,
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

    -- ── triggers del provider (stubs; features reales llegan en Tasks 3-8) ──
    function Combat:_onShot(origin, hitPos, isLocal)
        -- Task 3 (Hit Tracers) engancha acá: linea/beam origin->hitPos.
    end
    function Combat:_onHit(plr, part, dmg, lethal)
        -- Tasks 4/5/7/8 (Hitmarker, Damage Numbers, Hit Particles, Hit Chams) enganchan acá.
    end

    function Combat:_update(now, dt)
        if not self:_flag("Enabled", false) then return end
        GV.tweenStep(now, dt)
        -- per-feature updaters (fade de tracers/hitmarker, subida de damage numbers, spin del
        -- target ring, etc.) se agregan en Tasks 3-8. Nada que renderizar todavia.
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
    end

    GV.Combat = Combat
    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.new = function(o) return Combat.new(o) end
end
