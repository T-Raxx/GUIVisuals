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
    local function hideBundle(b)
        for k, o in pairs(b) do
            if k == "skel" then for _, l in ipairs(o) do pcall(function() l.Visible = false end) end
            else pcall(function() o.Visible = false end) end
        end
    end

    function ESP:_make()
        return {
            box     = self:_draw("Square", { Filled = false, Thickness = 1 }),
            boxOl   = self:_draw("Square", { Filled = false, Thickness = 3, Color = BLACK }),
            name    = self:_draw("Text", { Center = true, Outline = true }),
            dist    = self:_draw("Text", { Center = true, Outline = true }),
            hpBg    = self:_draw("Square", { Filled = true, Color = BLACK }),
            hpBar   = self:_draw("Square", { Filled = true }),
            hpText  = self:_draw("Text", { Center = false, Outline = true }),
            tracer  = self:_draw("Line", { Thickness = 1 }),
            headdot = self:_draw("Circle", { Filled = true, NumSides = 16 }),
            look    = self:_draw("Line", { Thickness = 1 }),
            arrow   = self:_draw("Triangle", { Filled = true }),
            skel    = {},
        }
    end

    function ESP:_drawArrow(b, tg, cam, t, vp)
        local center = Vector2.new(vp.X / 2, vp.Y / 2)
        local sp = cam:WorldToViewportPoint(tg.root.Position)
        local dir
        if sp.Z > 0 then dir = Vector2.new(sp.X, sp.Y) - center
        else dir = center - Vector2.new(sp.X, sp.Y) end
        if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
        dir = dir.Unit
        local radius = self:_flag("OffScreenRadius", 200)
        local size = self:_flag("OffScreenSize", 16)
        local perp = Vector2.new(-dir.Y, dir.X)
        local tip = center + dir * radius
        b.arrow.Visible = true
        b.arrow.PointA = tip
        b.arrow.PointB = tip - dir * size + perp * (size * 0.6)
        b.arrow.PointC = tip - dir * size - perp * (size * 0.6)
        b.arrow.Color = self:_col(tg, "ESP_OffScreenColor", t)
        b.arrow.ZIndex = 5
    end

    function ESP:_drawExtras(b, tg, cam, t)
        -- skeleton
        local showSkel = self:_flag("Skeleton", false)
        local bones = tg.bones or {}
        for i, bone in ipairs(bones) do
            local l = b.skel[i]
            if not l then l = self:_draw("Line", { Thickness = 1 }); b.skel[i] = l end
            local pa = tg.model:FindFirstChild(bone.a)
            local pb = tg.model:FindFirstChild(bone.b)
            if showSkel and pa and pb then
                local va = cam:WorldToViewportPoint(pa.Position)
                local vb = cam:WorldToViewportPoint(pb.Position)
                if va.Z > 0 and vb.Z > 0 then
                    l.Visible = true
                    l.From = Vector2.new(va.X, va.Y); l.To = Vector2.new(vb.X, vb.Y)
                    l.Color = self:_col(tg, "ESP_SkeletonColor", t); l.ZIndex = 2
                else l.Visible = false end
            else l.Visible = false end
        end
        for i = #bones + 1, #b.skel do b.skel[i].Visible = false end
        -- headdot
        local showDot = self:_flag("HeadDot", false)
        b.headdot.Visible = showDot
        if showDot then
            local hv = cam:WorldToViewportPoint(tg.head.Position)
            if hv.Z > 0 then
                b.headdot.Position = Vector2.new(hv.X, hv.Y)
                b.headdot.Radius = self:_flag("HeadDotRadius", 3)
                b.headdot.Color = self:_col(tg, "ESP_HeadDotColor", t)
                b.headdot.ZIndex = 4
            else b.headdot.Visible = false end
        end
        -- look direction
        local showLook = self:_flag("LookDir", false)
        b.look.Visible = showLook
        if showLook then
            local hp = tg.head.Position
            local a = cam:WorldToViewportPoint(hp)
            local c = cam:WorldToViewportPoint(hp + tg.head.CFrame.LookVector * self:_flag("LookLength", 2))
            if a.Z > 0 and c.Z > 0 then
                b.look.From = Vector2.new(a.X, a.Y); b.look.To = Vector2.new(c.X, c.Y)
                b.look.Color = self:_col(tg, "ESP_LookDirColor", t); b.look.ZIndex = 3
            else b.look.Visible = false end
        end
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
        local onScreen = topV.Z > 0 and topV.X >= 0 and topV.X <= vp.X and topV.Y >= 0 and topV.Y <= vp.Y
        b.arrow.Visible = false
        if not onScreen then
            -- ocultar el bundle on-screen; flecha off-screen si aplica
            for _, k in ipairs({ "box", "boxOl", "name", "dist", "hpBg", "hpBar", "hpText", "tracer", "headdot", "look" }) do
                b[k].Visible = false
            end
            for _, l in ipairs(b.skel) do l.Visible = false end
            if self:_flag("OffScreen", false) then self:_drawArrow(b, tg, cam, t, vp) end
            return
        end
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

        self:_drawExtras(b, tg, cam, t)
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
