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

    local BLACK = Color3.new(0, 0, 0)
    local function hideBundle(b) for _, o in pairs(b) do pcall(function() o.Visible = false end) end end

    function ESP:_make()
        return {
            box    = self:_draw("Square", { Filled = false, Thickness = 1 }),
            boxOl  = self:_draw("Square", { Filled = false, Thickness = 3, Color = BLACK }),
            name   = self:_draw("Text", { Center = true, Outline = true }),
            dist   = self:_draw("Text", { Center = true, Outline = true }),
            hpBg   = self:_draw("Square", { Filled = true, Color = BLACK }),
            hpBar  = self:_draw("Square", { Filled = true }),
            hpText = self:_draw("Text", { Center = false, Outline = true }),
            tracer = self:_draw("Line", { Thickness = 1 }),
        }
    end

    function ESP:_healthColor(frac)
        return Color3.fromRGB(math.floor(220 * (1 - frac)) + 20, math.floor(200 * frac) + 20, 40)
    end

    -- color de un target para un flag base; E5 lo reemplaza para color modes
    function ESP:_col(tg, base, t)
        return GV.Color.fade(self.Flags, base, t)
    end

    function ESP:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)
        local topV = cam:WorldToViewportPoint(tg.head.Position + Vector3.new(0, 0.6, 0))
        local botV = cam:WorldToViewportPoint(tg.root.Position - Vector3.new(0, 3.0, 0))
        if topV.Z <= 0 and botV.Z <= 0 then hideBundle(b); return end
        local top = Vector2.new(topV.X, topV.Y)
        local bot = Vector2.new(botV.X, botV.Y)
        local h = math.abs(bot.Y - top.Y)
        local w = h * 0.62
        local x = top.X - w / 2
        local y = top.Y

        local showBox   = self:_flag("Box", true)
        local showName  = self:_flag("Name", true)
        local showHp    = self:_flag("Health", true)
        local showDist  = self:_flag("Distance", true)
        local showTrace = self:_flag("Tracer", false)
        local hpStyle   = self:_flag("HealthStyle", "Barra")
        local showBar   = hpStyle == "Barra" or hpStyle == "Barra+Numero"
        local showNum   = hpStyle == "Numero" or hpStyle == "Barra+Numero"

        -- box
        b.box.Visible, b.boxOl.Visible = showBox, showBox
        if showBox then
            local bc = self:_col(tg, "ESP_BoxColor", t)
            b.box.Color = bc
            b.box.Size = Vector2.new(w, h); b.box.Position = Vector2.new(x, y); b.box.ZIndex = 2
            b.boxOl.Size = b.box.Size; b.boxOl.Position = b.box.Position; b.boxOl.ZIndex = 1
        end

        -- health
        local frac = math.clamp((tg.health or 0) / (tg.maxHealth and tg.maxHealth > 0 and tg.maxHealth or 100), 0, 1)
        b.hpBg.Visible = showHp and showBar
        b.hpBar.Visible = showHp and showBar
        b.hpText.Visible = showHp and showNum
        if showHp and showBar then
            local bx = x - 5
            b.hpBg.Position = Vector2.new(bx, y - 1); b.hpBg.Size = Vector2.new(3, h + 2); b.hpBg.ZIndex = 2
            local bh = h * frac
            b.hpBar.Position = Vector2.new(bx, y + (h - bh)); b.hpBar.Size = Vector2.new(3, bh)
            b.hpBar.Color = self:_healthColor(frac); b.hpBar.ZIndex = 3
        end
        if showHp and showNum then
            b.hpText.Text = tostring(math.floor(tg.health or 0))
            b.hpText.Font = font; b.hpText.Size = textSize; b.hpText.Color = self:_healthColor(frac)
            b.hpText.Position = Vector2.new(x + w + 3, y); b.hpText.ZIndex = 4
        end

        -- name
        b.name.Visible = showName
        if showName then
            b.name.Text = tg.name or "?"
            b.name.Font = font; b.name.Size = textSize; b.name.Color = self:_col(tg, "ESP_NameColor", t)
            b.name.Position = Vector2.new(top.X, y - textSize - 2); b.name.ZIndex = 4
        end

        -- distance
        b.dist.Visible = showDist
        if showDist then
            b.dist.Text = math.floor(dist) .. "m"
            b.dist.Font = font; b.dist.Size = textSize; b.dist.Color = Color3.fromRGB(180, 180, 185)
            b.dist.Position = Vector2.new(top.X, bot.Y + 2); b.dist.ZIndex = 4
        end

        -- tracer
        b.tracer.Visible = showTrace
        if showTrace then
            local from = self:_flag("TracerFrom", "Bottom")
            local fx, fy = vp.X / 2, vp.Y
            if from == "Center" then fy = vp.Y / 2 elseif from == "Top" then fy = 0
            elseif from == "Mouse" then local m = self.Services.Workspace.CurrentCamera; fx, fy = vp.X / 2, vp.Y / 2 end
            b.tracer.From = Vector2.new(fx, fy)
            b.tracer.To = Vector2.new(top.X, bot.Y)
            b.tracer.Color = self:_col(tg, "ESP_TracerColor", t)
            b.tracer.ZIndex = 1
        end
    end

    function ESP:_update()
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        local enabled = self:_flag("Enabled", false)
        local targets = enabled and self:_provget() or {}
        local origin = cam.CFrame.Position
        local vp = cam.ViewportSize
        local font = self:_flag("Font", 2)
        local textSize = self:_flag("TextSize", 13)
        local maxDist = self:_flag("MaxDistance", 1200)
        local maxTargets = self:_flag("MaxTargets", 50)
        local t = tick()
        local live, count = {}, 0
        for _, tg in ipairs(targets) do
            if tg.root and tg.head and count < maxTargets and self:_passFilters(tg) then
                local dist = (tg.root.Position - origin).Magnitude
                if dist <= maxDist then
                    count += 1
                    live[tg.model] = true
                    local b = self.Objects[tg.model] or self:_make()
                    self.Objects[tg.model] = b
                    self:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)
                end
            end
        end
        for model, b in pairs(self.Objects) do
            if not live[model] then
                hideBundle(b)
                if not (model and model.Parent) then self.Objects[model] = nil end
            end
        end
    end

    -- filtros base (E5 extiende)
    function ESP:_passFilters(tg)
        if self:_flag("DeadCheck", false) and (tg.health or 0) <= 0 then return false end
        return true
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
