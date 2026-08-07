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
        local self = { suite = suite, _made = {}, _conns = {} }

        local gui = Instance.new("ScreenGui")
        gui.Name = "PUIpv_" .. tostring(math.random(1e5, 9e5))
        gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = huiParent(); table.insert(self._made, gui)

        local root = Instance.new("Frame")
        root.Size = UDim2.fromOffset(260, 320)
        root.AnchorPoint = Vector2.new(1, 0.5)
        root.Position = UDim2.new(1, -12, 0.5, 0) -- dockeado al borde derecho (draggable), al lado de la UI
        root.BackgroundColor3 = Color3.fromRGB(20, 20, 24); root.BorderSizePixel = 0; root.Parent = gui
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

        local vf = Instance.new("ViewportFrame")
        vf.Position = UDim2.fromOffset(8, 32); vf.Size = UDim2.new(1, -16, 1, -40)
        vf.BackgroundColor3 = Color3.fromRGB(6, 10, 6); vf.BorderSizePixel = 0
        vf.Ambient = Color3.fromRGB(170, 170, 175); vf.LightColor = Color3.fromRGB(255, 255, 255)
        vf.LightDirection = Vector3.new(-0.4, -1, -0.5); vf.Parent = root
        Instance.new("UICorner", vf).CornerRadius = UDim.new(0, 6)
        local cam = Instance.new("Camera"); cam.Parent = vf; vf.CurrentCamera = cam
        local world = Instance.new("WorldModel"); world.Parent = vf
        self.VF, self.Cam, self.World = vf, cam, world

        -- box overlay (borde ESP representativo, sobre el 3D)
        local box = Instance.new("Frame"); box.BackgroundTransparency = 1; box.BorderSizePixel = 0
        box.AnchorPoint = Vector2.new(0.5, 0.5); box.Position = UDim2.new(0.5, 0, 0.5, 6)
        box.Size = UDim2.fromOffset(66, 150); box.ZIndex = 3; box.Parent = vf
        local boxStroke = Instance.new("UIStroke", box); boxStroke.Thickness = 1.5; boxStroke.Color = Color3.fromRGB(0, 255, 120)
        self._box, self._boxStroke = box, boxStroke

        -- matrix rain (columnas verdes low-alpha delante del modelo)
        self._matrix = {}
        for i = 1, 10 do
            local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code
            l.TextSize = 12; l.TextColor3 = Color3.fromRGB(0, 255, 80); l.TextTransparency = 0.55
            l.Size = UDim2.fromOffset(12, 220); l.TextYAlignment = Enum.TextYAlignment.Top; l.Text = ""
            l.Position = UDim2.fromScale((i - 0.5) / 10, math.random()); l.ZIndex = 2; l.Parent = vf
            table.insert(self._matrix, l)
        end

        function self:SetModel(char)
            for _, c in ipairs(self.World:GetChildren()) do c:Destroy() end
            self.Model = nil
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
            -- world lighting -> viewport
            self.VF.Ambient = GV.Color.fade(flags, "World_Ambient", t)
            self.VF.LightColor = flags.World_Fullbright and Color3.new(1, 1, 1) or Color3.fromRGB(255, 255, 255)
            -- chams (ESP o self-chams) sobre el clone
            local chamsOn = flags.ESP_Chams or flags.Local_SelfChams
            if chamsOn then
                if not self._chams then self._chams = Instance.new("Highlight"); self._chams.Parent = self.VF; table.insert(self._made, self._chams) end
                self._chams.Adornee = self.Model; self._chams.Enabled = true
                local isSelf = flags.Local_SelfChams and true or false
                self._chams.FillColor = GV.Color.fade(flags, isSelf and "Local_SelfChamsFill" or "ESP_ChamsFill", t)
                self._chams.OutlineColor = GV.Color.fade(flags, isSelf and "Local_SelfChamsOutline" or "ESP_ChamsOutline", t)
            elseif self._chams then self._chams.Enabled = false end
            -- box overlay color (representativo)
            self._box.Visible = flags.ESP_Box ~= false
            self._boxStroke.Color = GV.Color.fade(flags, "ESP_BoxColor", t)
            -- matrix rain
            for i, l in ipairs(self._matrix) do
                local y = (l.Position.Y.Scale + dt * (0.15 + (i % 3) * 0.08)) % 1.3 - 0.3
                l.Position = UDim2.fromScale(l.Position.X.Scale, y)
                if math.floor(t * 6 + i) % 3 == 0 then
                    local s = {}; for k = 1, 9 do s[k] = string.char(48 + (i * 7 + k * 3) % 10) end
                    l.Text = table.concat(s, "\n")
                end
            end
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
