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

    -- color de un target para un flag base, segun ColorMode
    local TEAM_ENEMY, TEAM_ALLY = Color3.fromRGB(235, 64, 52), Color3.fromRGB(64, 200, 96)
    local GREY = Color3.fromRGB(90, 90, 90)
    function ESP:_col(tg, base, t)
        local mode = self:_flag("ColorMode", "Fijo")
        if mode == "Team" then return tg.isEnemy and TEAM_ENEMY or TEAM_ALLY end
        if mode == "Visibilidad" then
            return tg._visible and GV.Color.fade(self.Flags, "ESP_VisibleColor", t)
                or GV.Color.fade(self.Flags, "ESP_HiddenColor", t)
        end
        if mode == "Distancia" then
            local frac = math.clamp((tg._dist or 0) / self:_flag("MaxDistance", 1200), 0, 1)
            return GV.Color.fade(self.Flags, base, t):Lerp(GREY, frac)
        end
        return GV.Color.fade(self.Flags, base, t)
    end

    -- raycast LOS camara->root (ignora camara + char local)
    function ESP:_visible(root)
        local cam = self.Services.Workspace.CurrentCamera
        if not cam or not root then return true end
        local origin = cam.CFrame.Position
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { cam }
        local lp = self.Services.Players and self.Services.Players.LocalPlayer
        if lp and lp.Character then table.insert(ignore, lp.Character) end
        params.FilterDescendantsInstances = ignore
        local res = self.Services.Workspace:Raycast(origin, root.Position - origin, params)
        if not res then return true end
        return res.Instance and root.Parent and res.Instance:IsDescendantOf(root.Parent) or false
    end

    -- chams via Highlight (detectable). Uno por modelo en self.Highlights.
    function ESP:_chams(tg, t)
        if not self:_flag("Chams", false) then
            local h = self.Highlights[tg.model]; if h then h.Enabled = false end
            return
        end
        local h = self.Highlights[tg.model]
        if not h or not h.Parent then
            h = Instance.new("Highlight")
            h.Name = "LC"
            h.Adornee = tg.model
            h.Parent = self.Services.Workspace.CurrentCamera
            self.Highlights[tg.model] = h
        end
        h.Enabled = true
        h.FillColor = GV.Color.fade(self.Flags, "ESP_ChamsFill", t)
        h.OutlineColor = GV.Color.fade(self.Flags, "ESP_ChamsOutline", t)
        h.FillTransparency = self:_flag("ChamsFillTransparency", 0.5)
        h.OutlineTransparency = self:_flag("ChamsOutlineTransparency", 0)
        h.DepthMode = (self:_flag("ChamsDepthMode", "AlwaysOnTop") == "Occluded")
            and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
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
        b.box.Visible = showBox
        b.boxOl.Visible = showBox and self:_flag("BoxOutline", true)
        if showBox then
            b.box.Color = self:_col(tg, "ESP_BoxColor", t)
            b.box.Filled = self:_flag("BoxFilled", false)
            b.box.Thickness = self:_flag("BoxThickness", 1)
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
                    tg._dist = dist
                    if self:_flag("VisibleCheck", false) or self:_flag("ColorMode", "Fijo") == "Visibilidad" then
                        tg._visible = self:_visible(tg.root)
                    else
                        tg._visible = true
                    end
                    local b = self.Objects[tg.model] or self:_make()
                    self.Objects[tg.model] = b
                    self:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)
                    self:_chams(tg, t)
                end
            end
        end
        for model, b in pairs(self.Objects) do
            if not live[model] then
                hideBundle(b)
                local h = self.Highlights[model]; if h then h.Enabled = false end
                if not (model and model.Parent) then self.Objects[model] = nil end
            end
        end
        self:_updateObjects()
    end

    function ESP:_passFilters(tg)
        if self:_flag("DeadCheck", false) and (tg.health or 0) <= 0 then return false end
        if self:_flag("PlayersOnly", false) and tg.isPlayer == false then return false end
        return true
    end

    -- Object ESP: fuentes declaradas por el perfil (tag o clase) -> box+name+dist
    function ESP:_updateObjects()
        self._objBundles = self._objBundles or {}
        local live = {}
        if self:_flag("Objects", false) and self._objectSources then
            local cam = self.Services.Workspace.CurrentCamera
            if cam then
                local origin, vp, t = cam.CFrame.Position, cam.ViewportSize, tick()
                for _, src in ipairs(self._objectSources) do
                    if self:_flag("Obj_" .. (src.key or src.name), true) then
                        local insts = {}
                        if src.tag then insts = self.Services.CollectionService:GetTagged(src.tag)
                        elseif src.classFilter then
                            for _, d in ipairs(self.Services.Workspace:GetDescendants()) do
                                if d:IsA(src.classFilter) then table.insert(insts, d) end
                            end
                        end
                        for _, inst in ipairs(insts) do
                            local part = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart")
                            if part then
                                local dist = (part.Position - origin).Magnitude
                                if dist <= (src.maxDistance or self:_flag("MaxDistance", 1200)) then
                                    live[inst] = true
                                    local ob = self._objBundles[inst]
                                    if not ob then
                                        ob = { box = self:_draw("Square", { Filled = false, Thickness = 1 }),
                                            name = self:_draw("Text", { Center = true, Outline = true }),
                                            dist = self:_draw("Text", { Center = true, Outline = true }) }
                                        self._objBundles[inst] = ob
                                    end
                                    local v = cam:WorldToViewportPoint(part.Position)
                                    if v.Z > 0 then
                                        local col = src.color or GV.Color.fade(self.Flags, "ESP_ObjectColor", t)
                                        local ts = self:_flag("TextSize", 13)
                                        ob.box.Visible = true; ob.box.Color = col; ob.box.Size = Vector2.new(14, 14); ob.box.Position = Vector2.new(v.X - 7, v.Y - 7)
                                        ob.name.Visible = true; ob.name.Text = src.name; ob.name.Color = col; ob.name.Size = ts; ob.name.Position = Vector2.new(v.X, v.Y - 18)
                                        ob.dist.Visible = true; ob.dist.Text = math.floor(dist) .. "m"; ob.dist.Color = col; ob.dist.Size = ts; ob.dist.Position = Vector2.new(v.X, v.Y + 10)
                                    else
                                        for _, o in pairs(ob) do o.Visible = false end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        for inst, ob in pairs(self._objBundles) do
            if not live[inst] then
                for _, o in pairs(ob) do pcall(function() o.Visible = false end) end
                if not (inst and inst.Parent) then self._objBundles[inst] = nil end
            end
        end
    end

    -- Preview mode: dibuja box+skeleton de UN modelo con una camara de ViewportFrame (para §D)
    function ESP:RenderPreview(cam, model)
        if not (cam and model) then return end
        self._preview = self._preview or { box = self:_draw("Square", { Filled = false, Thickness = 1 }), skel = {} }
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
        local head = model:FindFirstChild("Head") or root
        if not root then return end
        local t = tick()
        local topV = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
        local botV = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
        if topV.Z > 0 then
            local h = math.abs(botV.Y - topV.Y); local w = h * 0.62
            self._preview.box.Visible = true
            self._preview.box.Color = GV.Color.fade(self.Flags, "ESP_BoxColor", t)
            self._preview.box.Size = Vector2.new(w, h)
            self._preview.box.Position = Vector2.new(topV.X - w / 2, topV.Y)
        else
            self._preview.box.Visible = false
        end
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
