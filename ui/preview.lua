return function(GV)
    local Preview = {}
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")

    local function huiParent()
        local ok, g = pcall(function() return gethui and gethui() end)
        if ok and g then return g end
        return game:GetService("CoreGui")
    end

    function Preview.mount(suite, opts)
        opts = opts or {}
        local flags = suite.flags
        local self = { suite = suite, _made = {}, _conns = {}, _grid = {} }

        local gui = Instance.new("ScreenGui")
        gui.Name = "PUIpv_" .. tostring(math.random(1e5, 9e5))
        gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = huiParent(); table.insert(self._made, gui)

        local root = Instance.new("Frame")
        root.Size = UDim2.fromOffset(260, 320)
        root.AnchorPoint = Vector2.new(1, 0.5)
        root.Position = UDim2.new(1, -12, 0.5, 0)
        root.BackgroundColor3 = Color3.fromRGB(18, 20, 26); root.BorderSizePixel = 0; root.Parent = gui
        Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)
        local st = Instance.new("UIStroke", root); st.Color = Color3.fromRGB(8, 8, 10); st.Thickness = 1
        self.Root = root

        local header = Instance.new("Frame"); header.Size = UDim2.new(1, 0, 0, 26)
        header.BackgroundColor3 = Color3.fromRGB(30, 30, 36); header.BorderSizePixel = 0; header.Parent = root
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
        local title = Instance.new("TextLabel"); title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -10, 1, 0); title.Position = UDim2.fromOffset(8, 0)
        title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.TextColor3 = Color3.fromRGB(202, 151, 161)
        title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "Preview"; title.Parent = header

        local dragging, sPos, sMouse
        header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; sPos = root.Position; sMouse = UIS:GetMouseLocation() end end)
        header.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        table.insert(self._conns, UIS.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local d = UIS:GetMouseLocation() - sMouse
                root.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
            end
        end))

        -- ViewportFrame estilo BLUEPRINT: fondo negro, grid gris 3D detras (en el WorldModel).
        local vf = Instance.new("ViewportFrame")
        vf.Position = UDim2.fromOffset(8, 32); vf.Size = UDim2.new(1, -16, 1, -40)
        vf.BackgroundColor3 = Color3.fromRGB(4, 6, 10); vf.BorderSizePixel = 0
        vf.Ambient = Color3.fromRGB(150, 150, 160); vf.LightColor = Color3.fromRGB(255, 255, 255)
        vf.LightDirection = Vector3.new(-0.4, -1, -0.5); vf.Parent = root
        Instance.new("UICorner", vf).CornerRadius = UDim.new(0, 6)
        local cam = Instance.new("Camera"); cam.Parent = vf; vf.CurrentCamera = cam
        local world = Instance.new("WorldModel"); world.Parent = vf
        self.VF, self.Cam, self.World = vf, cam, world

        -- overlay ESP: box + nombre + healthbar (sobre el 3D)
        local box = Instance.new("Frame"); box.BackgroundTransparency = 1; box.BorderSizePixel = 0
        box.AnchorPoint = Vector2.new(0.5, 0.5); box.Position = UDim2.new(0.5, 0, 0.5, 6)
        box.Size = UDim2.fromOffset(64, 150); box.ZIndex = 3; box.Parent = vf
        local boxStroke = Instance.new("UIStroke", box); boxStroke.Thickness = 1.5; boxStroke.Color = Color3.fromRGB(0, 255, 120)
        self._box, self._boxStroke = box, boxStroke
        local nameLbl = Instance.new("TextLabel"); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 12; nameLbl.AnchorPoint = Vector2.new(0.5, 1); nameLbl.Position = UDim2.new(0.5, 0, 0, -1)
        nameLbl.Size = UDim2.new(1, 0, 0, 14); nameLbl.ZIndex = 4; nameLbl.Parent = box; nameLbl.Text = "Preview"
        self._nameLbl = nameLbl
        local hpBg = Instance.new("Frame"); hpBg.BorderSizePixel = 0; hpBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        hpBg.AnchorPoint = Vector2.new(1, 0); hpBg.Position = UDim2.new(0, -3, 0, 0); hpBg.Size = UDim2.new(0, 3, 1, 0); hpBg.ZIndex = 3; hpBg.Parent = box
        local hpBar = Instance.new("Frame"); hpBar.BorderSizePixel = 0; hpBar.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
        hpBar.AnchorPoint = Vector2.new(0, 1); hpBar.Position = UDim2.new(0, 0, 1, 0); hpBar.Size = UDim2.new(1, 0, 0.7, 0); hpBar.ZIndex = 4; hpBar.Parent = hpBg
        self._hpBg, self._hpBar = hpBg, hpBar

        function self:_buildGrid()
            for _, p in ipairs(self._grid) do pcall(function() p:Destroy() end) end
            self._grid = {}
            if not self._center then return end
            local ext = math.max(self._radius * 2.2, 6)
            local step = ext / 5
            local y = self._center.Y - self._radius * 1.05
            local col = Color3.fromRGB(70, 90, 110)
            for i = -5, 5 do
                for _, axis in ipairs({ "X", "Z" }) do
                    local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
                    p.Material = Enum.Material.Neon; p.Color = col
                    if axis == "X" then
                        p.Size = Vector3.new(ext * 2, 0.04, 0.06)
                        p.CFrame = CFrame.new(self._center.X, y, self._center.Z + i * step)
                    else
                        p.Size = Vector3.new(0.06, 0.04, ext * 2)
                        p.CFrame = CFrame.new(self._center.X + i * step, y, self._center.Z)
                    end
                    p.Parent = self.World
                    table.insert(self._grid, p)
                end
            end
        end

        function self:SetModel(char)
            for _, c in ipairs(self.World:GetChildren()) do if c ~= nil then c:Destroy() end end
            self._grid = {}; self.Model = nil
            if not char then return end
            local m; local prev = char.Archivable; char.Archivable = true
            pcall(function() m = char:Clone() end); char.Archivable = prev
            if not m then return end
            for _, d in ipairs(m:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
            m.Parent = self.World; self.Model = m
            local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
            if ok and cf then
                self._center = cf.Position; self._radius = math.max(size.Magnitude / 2, 1)
                self._dist = self._radius / math.tan(math.rad(30)) + self._radius
            end
            self._angle = 0
            self:_buildGrid()
        end

        function self:_apply(a)
            if not self._center then return end
            local pos = self._center + Vector3.new(math.sin(a) * self._dist, self._radius * 0.35, math.cos(a) * self._dist)
            self.Cam.CFrame = CFrame.lookAt(pos, self._center)
        end

        function self:_step(dt)
            local show = opts.always or (flags.Suite_Preview and true or false)
            self.Root.Visible = show
            if not show or not self.Model then return end
            self._angle = (self._angle or 0) + math.rad(40) * dt
            self:_apply(self._angle)
            local t = tick()
            -- world lighting -> viewport ambient
            self.VF.Ambient = flags.World_Ambient and GV.Color.fade(flags, "World_AmbientColor", t) or Color3.fromRGB(150, 150, 160)
            self.VF.LightColor = flags.World_Fullbright and Color3.new(1, 1, 1) or Color3.fromRGB(255, 255, 255)
            -- chams
            local chamsOn = flags.ESP_Chams or flags.Local_SelfChams
            if chamsOn then
                if not self._chams then self._chams = Instance.new("Highlight"); self._chams.Parent = self.VF; table.insert(self._made, self._chams) end
                self._chams.Adornee = self.Model; self._chams.Enabled = true
                local isSelf = flags.Local_SelfChams and true or false
                self._chams.FillColor = GV.Color.fade(flags, isSelf and "Local_SelfChamsFill" or "ESP_ChamsFill", t)
                self._chams.OutlineColor = GV.Color.fade(flags, isSelf and "Local_SelfChamsOutline" or "ESP_ChamsOutline", t)
            elseif self._chams then self._chams.Enabled = false end
            -- ESP overlay refleja los flags
            local espOn = flags.ESP_Enabled and true or false
            self._box.Visible = espOn and (flags.ESP_Box ~= false)
            self._boxStroke.Color = GV.Color.fade(flags, "ESP_BoxColor", t)
            self._nameLbl.Visible = espOn and (flags.ESP_Name ~= false)
            self._nameLbl.TextColor3 = GV.Color.fade(flags, "ESP_NameColor", t)
            self._hpBg.Visible = espOn and (flags.ESP_Health ~= false)
        end

        table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)
            local ok, err = pcall(function() self:_step(dt) end); if not ok then warn("[Preview] " .. tostring(err)) end
        end))

        function self:Unload()
            for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
            for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
            table.clear(self._conns); table.clear(self._made)
        end

        local lp = Players.LocalPlayer
        if lp and lp.Character then self:SetModel(lp.Character) end
        return self
    end
    GV.Preview = Preview
end
