-- PrimordialUI bundle (auto-generado por build.lua) --
local P = {}
-- ==== Core/Signal ====
do local __m = (function()
return function(P)
    local Signal = {}
    Signal.__index = Signal
    function Signal.new()
        return setmetatable({ _cbs = {} }, Signal)
    end
    function Signal:Connect(fn)
        local conn = { fn = fn, _sig = self }
        function conn:Disconnect()
            for i, c in ipairs(self._sig._cbs) do
                if c == self then table.remove(self._sig._cbs, i) break end
            end
        end
        table.insert(self._cbs, conn)
        return conn
    end
    function Signal:Fire(...)
        for _, c in ipairs({ table.unpack(self._cbs) }) do
            task.spawn(c.fn, ...)
        end
    end
    function Signal:DisconnectAll() self._cbs = {} end
    P.Signal = Signal
end

end)(); __m(P) end
-- ==== Core/Theme ====
do local __m = (function()
return function(P)
    P.Theme = {
        Accent    = Color3.fromRGB(202, 151, 161),  -- rosa mauve exacto (swatch primordial)
        AccentDim = Color3.fromRGB(138, 102, 110),
        Bg        = Color3.fromRGB(29, 29, 32),      -- fondo window (no negro)
        Surface   = Color3.fromRGB(34, 34, 37),      -- panels
        Bar       = Color3.fromRGB(40, 40, 44),      -- header + barra de categorias (mas claro que bg/panels)
        Sidebar   = Color3.fromRGB(32, 32, 35),      -- sidebar (un pelin mas oscuro)
        Surface2  = Color3.fromRGB(23, 23, 26),      -- controls (toggle/dropdown/textbox/slider) mas oscuro que Bg
        Surface3  = Color3.fromRGB(56, 56, 62),      -- hover / pill categoria activa
        Knob      = Color3.fromRGB(206, 206, 211),   -- perilla gris clara
        Outline   = Color3.fromRGB(48, 48, 53),
        Border    = Color3.fromRGB(8, 8, 10),        -- borde negro thin de panels
        Text      = Color3.fromRGB(228, 228, 233),
        SubText   = Color3.fromRGB(132, 132, 140),
        Positive  = Color3.fromRGB(120, 200, 120),
        Negative  = Color3.fromRGB(210, 70, 70),
        Radius    = 5,
        RadiusBig = 7,
        Pad       = 6,
        RowH      = 22,          -- compacto (match primordial real)
        Font      = Enum.Font.Gotham,
        FontBold  = Enum.Font.GothamBold,
        TextSize  = 12,
        Shadow    = "rbxassetid://6014261993",       -- drop shadow 9-slice
    }
end

end)(); __m(P) end
-- ==== Core/Util ====
do local __m = (function()
return function(P)
    local TweenService = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")
    local Util = {}

    function Util.Create(class, props, children)
        local inst = Instance.new(class)
        for k, v in pairs(props or {}) do
            if k ~= "Parent" then inst[k] = v end
        end
        for _, c in ipairs(children or {}) do c.Parent = inst end
        if props and props.Parent then inst.Parent = props.Parent end
        return inst
    end

    function Util.Tween(inst, info, goal)
        local t = TweenService:Create(inst, info, goal); t:Play(); return t
    end

    function Util.Round(n, dec)
        local m = 10 ^ (dec or 0)
        return math.floor(n * m + 0.5) / m
    end

    function Util.GetGui()
        local parent
        local ok = pcall(function() parent = gethui() end)
        if not ok or not parent then
            parent = game:GetService("CoreGui")
        end
        return parent
    end

    -- Arrastre: handleGui recibe input, mueve targetFrame por delta.
    -- maid opcional: objeto con :Maid(conn) para limpiar la conexion global en Unload.
    function Util.Drag(handleGui, targetFrame, maid)
        local dragging, startPos, startInput
        local function reg(c) if maid then maid:Maid(c) end return c end
        reg(handleGui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                if maid and maid.CloseActivePopup then maid:CloseActivePopup() end
                dragging = true
                startPos = targetFrame.Position
                startInput = input.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end))
        reg(UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - startInput
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
    end

    -- Sombra suave y externa detras de un frame (elevacion sutil).
    -- Usar SOLO en frames que NO sean AutomaticSize (si no, la infla).
    function Util.Shadow(target, opts)
        opts = opts or {}
        local sp = opts.Spread or 22
        local sh = Instance.new("ImageLabel")
        sh.Name = "Shadow"
        sh.BackgroundTransparency = 1
        sh.Image = P.Theme.Shadow
        sh.ImageColor3 = opts.Color or Color3.new(0, 0, 0)
        sh.ImageTransparency = opts.Transparency or 0.78
        sh.ScaleType = Enum.ScaleType.Slice
        sh.SliceCenter = Rect.new(49, 49, 450, 450)
        sh.ZIndex = -1
        sh.AnchorPoint = Vector2.new(0.5, 0.5)
        sh.Position = UDim2.new(0.5, 0, 0.5, opts.YOffset or 4)
        sh.Size = UDim2.new(1, sp * 2, 1, sp * 2)
        sh.Parent = target
        return sh
    end

    -- Profundidad interna sutil para controles (Surface2). Oscurece hacia abajo
    -- (gradiente multiplicativo) + linea de highlight 1px arriba (borde superior con luz).
    -- opts.Bottom = cuanto oscurece abajo (0..1, default 0.14). opts.Highlight = agregar rim light.
    function Util.Depth(inst, opts)
        opts = opts or {}
        local b = 1 - (opts.Bottom or 0.14)
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(b, b, b)),
        })
        g.Parent = inst
        if opts.Highlight then
            local hl = Instance.new("Frame")
            hl.Name = "Rim"; hl.BorderSizePixel = 0
            hl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            hl.BackgroundTransparency = opts.HighlightT or 0.9
            hl.Position = UDim2.fromOffset(2, 1)
            hl.Size = UDim2.new(1, -4, 0, 1)
            hl.ZIndex = (inst.ZIndex or 1) + 1
            hl.Parent = inst
        end
        return g
    end

    P.Util = Util
end

end)(); __m(P) end
-- ==== Core/Registry ====
do local __m = (function()
return function(P)
    local Registry = {}
    Registry.__index = Registry
    function Registry.new() return setmetatable({ _items = {} }, Registry) end
    function Registry:Add(inst, role, prop)
        table.insert(self._items, { inst = inst, role = role, prop = prop })
        if P.Theme[role] then inst[prop] = P.Theme[role] end
    end
    function Registry:Apply(theme)
        for _, it in ipairs(self._items) do
            if it.inst and it.inst.Parent ~= nil and theme[it.role] then
                it.inst[it.prop] = theme[it.role]
            end
        end
    end
    P.Registry = Registry
end

end)(); __m(P) end
-- ==== Core/Icons ====
do local __m = (function()
return function(P)
    local Icons = {}
    -- fuente Lucide para Roblox (spritesheet), cargada lazy + cacheada
    Icons.URL = "https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"
    Icons._mod = nil  -- nil = sin intentar; false = fallo; table = cargado

    function Icons.load()
        if Icons._mod ~= nil then return Icons._mod or nil end
        local ok, mod = pcall(function()
            return loadstring(game:HttpGet(Icons.URL))()
        end)
        Icons._mod = (ok and type(mod) == "table" and mod) or false
        return Icons._mod or nil
    end

    -- resuelve un icono a props de ImageLabel.
    -- acepta: nombre Lucide ("crosshair"), "rbxassetid://123", "rbxasset://...", o numero.
    function Icons.resolve(icon)
        if not icon or icon == "" then return nil end
        icon = tostring(icon)
        if icon:match("^%d+$") then return { Image = "rbxassetid://" .. icon } end
        if icon:match("^rbxasset") then return { Image = icon } end
        local mod = Icons.load()
        if mod and mod.GetAsset then
            local ok, a = pcall(mod.GetAsset, icon)
            if ok and type(a) == "table" then
                return { Image = a.Url or a.Image, ImageRectOffset = a.ImageRectOffset, ImageRectSize = a.ImageRectSize }
            end
        end
        return nil
    end

    -- aplica el icono a un ImageLabel/ImageButton existente
    function Icons.apply(img, icon)
        local r = Icons.resolve(icon)
        if not r then img.Image = ""; return false end
        img.Image = r.Image
        img.ImageRectOffset = r.ImageRectOffset or Vector2.zero
        img.ImageRectSize = r.ImageRectSize or Vector2.zero
        return true
    end

    P.Icons = Icons
end

end)(); __m(P) end
-- ==== Core/Library ====
do local __m = (function()
return function(P)
    local UIS = game:GetService("UserInputService")
    local Library = {
        Flags = {}, Toggles = {}, Options = {}, Windows = {},
        Open = true, Unloaded = false,
        ToggleKey = Enum.KeyCode.RightShift,
        Connections = {}, _flagSignals = {},
    }
    Library.Registry = P.Registry.new()
    Library.FlagChanged = P.Signal.new()

    function Library:Maid(x) table.insert(self.Connections, x); return x end

    function Library:GetFlagSignal(flag)
        local s = self._flagSignals[flag]
        if not s then s = P.Signal.new(); self._flagSignals[flag] = s end
        return s
    end

    function Library:SetFlag(flag, value)
        self.Flags[flag] = value
        self.FlagChanged:Fire(flag, value)
        local s = self._flagSignals[flag]
        if s then s:Fire(value) end
    end

    -- solo un popup (dropdown/colorpicker/gear) abierto a la vez
    function Library:OpenPopup(closer)
        if self._activePopup and self._activePopup ~= closer then pcall(self._activePopup) end
        self._activePopup = closer
    end
    function Library:ClosePopup(closer)
        if self._activePopup == closer then self._activePopup = nil end
    end
    function Library:CloseActivePopup()
        if self._activePopup then local c = self._activePopup; self._activePopup = nil; pcall(c) end
    end

    function Library:SetTheme(patch)
        for k, v in pairs(patch or {}) do P.Theme[k] = v end
        self.Registry:Apply(P.Theme)
    end

    function Library:CreateWindow(opts)
        if not P.Window then warn("PrimordialUI: Window module ausente"); return nil end
        local w = P.Window.new(self, opts or {})
        table.insert(self.Windows, w)
        return w
    end

    function Library:Unload()
        self.Unloaded = true
        for _, c in ipairs(self.Connections) do
            pcall(function() if c.Disconnect then c:Disconnect() elseif c.Destroy then c:Destroy() end end)
        end
        self.Connections = {}
        for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
        self.Windows = {}
        if getgenv then getgenv().__PUI = nil end
    end

    -- toggle show/hide global
    Library:Maid(UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Library.ToggleKey then
            Library.Open = not Library.Open
            for _, w in ipairs(Library.Windows) do w:SetVisible(Library.Open) end
        end
    end))

    -- single-instance: descarga cualquier instancia previa al recargar la lib
    if getgenv then
        if getgenv().__PUI then pcall(function() getgenv().__PUI:Unload() end) end
        -- barrer guis huerfanas (windows PUI_ y overlays PUIo_) de instancias leakeadas
        pcall(function()
            local roots = {}
            local ok, hui = pcall(function() return gethui() end)
            if ok and hui then table.insert(roots, hui) end
            table.insert(roots, game:GetService("CoreGui"))
            for _, r in ipairs(roots) do
                for _, g in ipairs(r:GetChildren()) do
                    if g:IsA("ScreenGui") and (tostring(g.Name):match("^PUI_") or tostring(g.Name):match("^PUIo_")) then
                        g:Destroy()
                    end
                end
            end
        end)
        getgenv().__PUI = Library
    end
    P.Library = Library
end

end)(); __m(P) end
-- ==== Core/Overlays ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local UIS = game:GetService("UserInputService")
    local Lib = P.Library

    Lib.DPIScale = 1
    function Lib:SetDPIScale(pct)
        self.DPIScale = math.clamp(pct / 100, 0.5, 2)
        for _, w in ipairs(self.Windows) do
            if w.UIScale then w.UIScale.Scale = self.DPIScale end
        end
    end

    -- ScreenGui compartido para overlays (no escala con el DPI del menu)
    local function overlay()
        if Lib._overlayGui and Lib._overlayGui.Parent then return Lib._overlayGui end
        Lib._overlayGui = U.Create("ScreenGui", { Name = "PUIo_" .. tostring(math.random(1e5, 9e5)),
            ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9999, Parent = U.GetGui() })
        Lib:Maid(Lib._overlayGui)
        return Lib._overlayGui
    end

    -- hace un overlay arrastrable y persiste su posicion en self._overlayPos[key]
    function Lib:_trackOverlay(key, frame)
        self._overlayPos = self._overlayPos or {}
        local p = self._overlayPos[key]
        if p then frame.Position = UDim2.fromOffset(p[1], p[2]) end
        U.Drag(frame, frame, self)
        frame:GetPropertyChangedSignal("Position"):Connect(function()
            self._overlayPos[key] = { frame.Position.X.Offset, frame.Position.Y.Offset }
        end)
    end
    -- aplica posiciones guardadas (llamado por LoadConfig)
    function Lib:ApplyOverlayPositions(pos)
        self._overlayPos = pos or {}
        if self._wm and self._overlayPos.watermark then
            local p = self._overlayPos.watermark; self._wm.Position = UDim2.fromOffset(p[1], p[2])
        end
        if self._kbFrame and self._overlayPos.keybindlist then
            local p = self._overlayPos.keybindlist; self._kbFrame.Position = UDim2.fromOffset(p[1], p[2])
        end
    end

    ---------------------------------------------------------------- WATERMARK
    function Lib:SetWatermark(text)
        local g = overlay()
        if not self._wm then
            self._wm = U.Create("Frame", { Parent = g, BackgroundColor3 = T.Bar, BorderSizePixel = 0,
                Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(10, 24),
                AutomaticSize = Enum.AutomaticSize.X,
            }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
                U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
                U.Create("Frame", { Name = "Bar", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                    Size = UDim2.new(0, 2, 1, 0) }),
                U.Create("TextLabel", { Name = "T", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
                    Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 0, 1, 0),
                    Font = T.FontBold, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left },
                    { U.Create("UIPadding", { PaddingRight = UDim.new(0, 10) }) }) })
            self.Registry:Add(self._wm.Bar, "Accent", "BackgroundColor3")
            self:_trackOverlay("watermark", self._wm)
        end
        self._wm.T.Text = text
    end
    function Lib:SetWatermarkVisibility(b)
        if not self._wm and b then self:SetWatermark("PrimordialUI") end
        if self._wm then self._wm.Visible = b end
    end

    ---------------------------------------------------------------- TOOLTIP
    local function tip()
        if Lib._tip and Lib._tip.Parent then return Lib._tip end
        Lib._tip = U.Create("TextLabel", { Parent = overlay(), Visible = false, ZIndex = 50,
            BackgroundColor3 = T.Surface2, AutomaticSize = Enum.AutomaticSize.XY,
            Font = T.Font, TextSize = 12, TextColor3 = T.Text, Text = "",
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }) })
        return Lib._tip
    end
    function Lib:ShowTooltip(text)
        local t = tip(); t.Text = text; t.Visible = true
        local m = UIS:GetMouseLocation()
        t.Position = UDim2.fromOffset(m.X + 14, m.Y + 6)
    end
    function Lib:MoveTooltip()
        if self._tip and self._tip.Visible then
            local m = UIS:GetMouseLocation()
            self._tip.Position = UDim2.fromOffset(m.X + 14, m.Y + 6)
        end
    end
    function Lib:HideTooltip() if self._tip then self._tip.Visible = false end end

    ---------------------------------------------------------------- NOTIFY
    function Lib:_notifyHolder()
        if self._nHolder and self._nHolder.Parent then return self._nHolder end
        self._nHolder = U.Create("Frame", { Parent = overlay(), BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
            Size = UDim2.fromOffset(250, 600),
        }, { U.Create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder }) })
        return self._nHolder
    end
    function Lib:Notify(a, b)
        local title, desc, time
        if type(a) == "table" then title, desc, time = a.Title, a.Description, a.Time
        else title, desc, time = a, nil, b end
        time = time or 4
        local card = U.Create("Frame", { Parent = self:_notifyHolder(), BackgroundColor3 = T.Bar,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("Frame", { Name = "Bar", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                Size = UDim2.new(0, 2, 1, 0) }) })
        local content = U.Create("Frame", { Parent = card, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -18, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
        U.Create("TextLabel", { Parent = content, BackgroundTransparency = 1, LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 16), Font = T.FontBold, TextSize = 13, TextColor3 = T.Text,
            Text = title or "", TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y })
        if desc then
            U.Create("TextLabel", { Parent = content, BackgroundTransparency = 1, LayoutOrder = 2,
                Size = UDim2.new(1, 0, 0, 14), Font = T.Font, TextSize = 12, TextColor3 = T.SubText,
                Text = desc, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y })
        end
        task.delay(time, function()
            if card and card.Parent then card:Destroy() end
        end)
        return card
    end

    ---------------------------------------------------------------- THEME PRESETS
    Lib.ThemePresets = {
        Default  = { Accent = Color3.fromRGB(202, 151, 161) },
        Crimson  = { Accent = Color3.fromRGB(214, 84, 84) },
        Ocean    = { Accent = Color3.fromRGB(96, 156, 214) },
        Emerald  = { Accent = Color3.fromRGB(104, 196, 140) },
        Amethyst = { Accent = Color3.fromRGB(168, 130, 214) },
        Amber    = { Accent = Color3.fromRGB(214, 168, 92) },
    }
    function Lib:ListThemePresets()
        local list = {}
        for k in pairs(self.ThemePresets) do table.insert(list, k) end
        table.sort(list)
        return list
    end
    function Lib:ApplyThemePreset(name)
        local p = self.ThemePresets[name]
        if p then self:SetTheme(p) end
    end

    ---------------------------------------------------------------- KEYBIND LIST
    function Lib:_kbHolder()
        if self._kbFrame and self._kbFrame.Parent then return self._kbFrame end
        self._kbFrame = U.Create("Frame", { Parent = overlay(), Visible = false,
            BackgroundColor3 = T.Bar, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 46),
            Size = UDim2.new(0, 160, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("Frame", { Name = "Bar", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2) }) })
        self.Registry:Add(self._kbFrame.Bar, "Accent", "BackgroundColor3")
        local body = U.Create("Frame", { Parent = self._kbFrame, Name = "Body", BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6),
                PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
        U.Create("TextLabel", { Parent = body, BackgroundTransparency = 1, LayoutOrder = 0,
            Size = UDim2.new(1, 0, 0, 15), Font = T.FontBold, TextSize = 13, TextColor3 = T.Text,
            Text = "Keybinds", TextXAlignment = Enum.TextXAlignment.Left })
        self._kbBody = body
        self:_trackOverlay("keybindlist", self._kbFrame)
        return self._kbFrame
    end
    function Lib:RegisterKeybind(kb)
        local body = self:_kbHolder().Body or self._kbBody
        local row = U.Create("TextLabel", { Parent = body, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14), Font = T.Font, TextSize = 12, TextColor3 = T.SubText,
            Text = "", TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = #self.KeybindEntries + 1 })
        local entry = { row = row, kb = kb }
        function entry:Update()
            local keyN = self.kb.Key and self.kb.Key.Name or "None"
            self.row.Text = ("%s  [%s]"):format(self.kb.Text or self.kb.Flag, keyN)
            self.row.TextColor3 = self.kb.Active and T.Accent or T.SubText
        end
        table.insert(self.KeybindEntries, entry)
        entry:Update()
        return entry
    end
    Lib.KeybindEntries = Lib.KeybindEntries or {}
    function Lib:SetKeybindListVisibility(b)
        self:_kbHolder().Visible = b
    end
end

end)(); __m(P) end
-- ==== Core/ConfigManager ====
do local __m = (function()
return function(P)
    local Lib = P.Library
    local HttpService = game:GetService("HttpService")

    Lib.ConfigFolder = "PrimordialUI/configs"

    local function ensure()
        if typeof(makefolder) == "function" then
            if not (typeof(isfolder) == "function" and isfolder(Lib.ConfigFolder)) then
                pcall(makefolder, Lib.ConfigFolder)
            end
        end
    end

    -- serializar tipos Roblox a JSON-safe
    local function ser(v)
        local t = typeof(v)
        if t == "boolean" or t == "number" or t == "string" then return v end
        if t == "Color3" then
            return { __ = "c3", r = math.floor(v.R * 255 + 0.5), g = math.floor(v.G * 255 + 0.5), b = math.floor(v.B * 255 + 0.5) }
        end
        if t == "EnumItem" then return { __ = "en", t = tostring(v.EnumType):gsub("^Enum%.", ""), n = v.Name } end
        if t == "table" then
            local o = {}
            for k, x in pairs(v) do o[k] = ser(x) end
            return o
        end
        return nil
    end
    local function deser(v)
        if type(v) ~= "table" then return v end
        if v.__ == "c3" then return Color3.fromRGB(v.r, v.g, v.b) end
        if v.__ == "en" then local ok, e = pcall(function() return Enum[v.t][v.n] end); return ok and e or nil end
        local o = {}
        for k, x in pairs(v) do if k ~= "__" then o[k] = deser(x) end end
        return o
    end

    Lib.ConfigIgnore = {}  -- flags a NO guardar (ej. los widgets del settings tab)
    function Lib:GetConfig()
        local out = {}
        for flag, t in pairs(self.Toggles) do
            if not self.ConfigIgnore[flag] then out[flag] = ser(t:GetValue()) end
        end
        for flag, o in pairs(self.Options) do
            if not self.ConfigIgnore[flag] and o.GetValue then
                local v = o:GetValue()
                if v ~= nil then out[flag] = ser(v) end
            end
        end
        if self._overlayPos then out.__overlays = self._overlayPos end
        return out
    end

    function Lib:LoadConfig(tbl)
        for flag, v in pairs(tbl or {}) do
            if flag ~= "__overlays" then
                local w = self.Toggles[flag] or self.Options[flag]
                if w and w.SetValue then pcall(function() w:SetValue(deser(v)) end) end
            end
        end
        if tbl and tbl.__overlays and self.ApplyOverlayPositions then
            self:ApplyOverlayPositions(tbl.__overlays)
        end
    end

    local function path(name) return Lib.ConfigFolder .. "/" .. name .. ".json" end

    function Lib:SaveConfig(name)
        if not name or name == "" then return false, "sin nombre" end
        ensure()
        local ok = pcall(function()
            writefile(path(name), HttpService:JSONEncode(self:GetConfig()))
        end)
        return ok
    end
    function Lib:LoadConfigFile(name)
        local p = path(name)
        if typeof(isfile) == "function" and not isfile(p) then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(p)) end)
        if ok and data then self:LoadConfig(data); return true end
        return false
    end
    function Lib:DeleteConfig(name)
        if typeof(delfile) == "function" then pcall(delfile, path(name)) end
    end
    function Lib:ListConfigs()
        local list = {}
        if typeof(listfiles) == "function" and typeof(isfolder) == "function" and isfolder(self.ConfigFolder) then
            for _, f in ipairs(listfiles(self.ConfigFolder)) do
                local n = tostring(f):match("([^/\\]+)%.json$")
                if n then table.insert(list, n) end
            end
        end
        return list
    end
    function Lib:SetAutoloadConfig(name)
        ensure()
        pcall(function() writefile(Lib.ConfigFolder .. "/autoload.txt", name or "") end)
    end
    function Lib:GetAutoloadConfig()
        local p = Lib.ConfigFolder .. "/autoload.txt"
        if typeof(isfile) == "function" and isfile(p) then
            local ok, n = pcall(readfile, p)
            if ok and n and n ~= "" then return n end
        end
        return nil
    end
    function Lib:LoadAutoloadConfig()
        local n = self:GetAutoloadConfig()
        if n then return self:LoadConfigFile(n) end
        return false
    end
end

end)(); __m(P) end
-- ==== Chrome/Window ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Window = {}
    Window.__index = Window

    function Window.new(Library, opts)
        local self = setmetatable({ Library = Library, Categories = {}, ActiveCategory = nil }, Window)
        local size = opts.Size or Vector2.new(834, 586)

        self.Gui = U.Create("ScreenGui", {
            Name = "PUI_"..tostring(math.random(1e5,9e5)),
            ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent = U.GetGui(),
        })
        self.Root = U.Create("Frame", {
            Parent = self.Gui, Size = UDim2.fromOffset(size.X, size.Y),
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = T.Bg, BorderSizePixel = 0,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),   -- borde negro thin alrededor
        })
        self.UIScale = U.Create("UIScale", { Parent = self.Root, Scale = Library.DPIScale or 1 })
        Library.Registry:Add(self.Root, "Bg", "BackgroundColor3")

        -- Header (mismo alto que la barra inferior = 64); esquinas superiores redondeadas
        local HEADERH = 64
        self.Header = U.Create("Frame", {
            Parent = self.Root, Size = UDim2.new(1, 0, 0, HEADERH),
            BackgroundColor3 = T.Bar, BorderSizePixel = 0,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
            U.Create("Frame", { Name = "SquareBottom", BorderSizePixel = 0, BackgroundColor3 = T.Bar,
                Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10) }),
            U.Create("TextLabel", {
                Name = "Title", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(48, 0), Size = UDim2.new(0.5, -60, 1, 0),
                Font = T.FontBold, TextSize = 22, TextColor3 = T.Accent,
                Text = opts.Title or "primordial",
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })
        Library.Registry:Add(self.Header, "Bar", "BackgroundColor3")
        Library.Registry:Add(self.Header.SquareBottom, "Bar", "BackgroundColor3")

        -- barra de busqueda en el header (top-right): contenedor + icono separado del texto
        self.SearchBar = U.Create("Frame", {
            Parent = self.Header, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(220, 28), BackgroundColor3 = T.Surface2, BorderSizePixel = 0,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
                Size = UDim2.fromOffset(14, 14), Image = "rbxassetid://6031154871", ImageColor3 = T.SubText }) })
        self.Search = U.Create("TextBox", { Parent = self.SearchBar, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -36, 1, 0), ClearTextOnFocus = false,
            Font = T.Font, TextSize = 13, TextColor3 = T.Text, Text = "",
            PlaceholderText = "Search...", PlaceholderColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left })
        Library.Registry:Add(self.SearchBar, "Surface2", "BackgroundColor3")

        -- separador accent bajo header
        U.Create("Frame", { Parent = self.Root, Position = UDim2.fromOffset(0, HEADERH),
            Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = T.Accent })

        -- Category holder (franja inferior); esquinas inferiores redondeadas, superiores cuadradas
        self.CategoryHolder = U.Create("Frame", {
            Parent = self.Root, AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = T.Bar, BorderSizePixel = 0,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
            U.Create("Frame", { Name = "SquareTop", BorderSizePixel = 0, BackgroundColor3 = T.Bar,
                Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 10) }) })
        Library.Registry:Add(self.CategoryHolder, "Bar", "BackgroundColor3")
        Library.Registry:Add(self.CategoryHolder.SquareTop, "Bar", "BackgroundColor3")
        -- fila interna que ordena las categorias (fuera del cover)
        self.CategoryButtons = U.Create("Frame", { Parent = self.CategoryHolder,
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        }, { U.Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 18) }) })
        -- linea de theme (accent) que separa el content de la barra de categorias
        local catLine = U.Create("Frame", { Parent = self.Root, BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = T.Accent })
        Library.Registry:Add(catLine, "Accent", "BackgroundColor3")

        -- Body (entre header y category holder)
        self.Body = U.Create("Frame", {
            Parent = self.Root, Position = UDim2.fromOffset(0, 65),
            Size = UDim2.new(1, 0, 1, -(65 + 56)), BackgroundTransparency = 1,
        })

        U.Drag(self.Header, self.Root, Library)
        return self
    end

    -- callback de la barra de busqueda del header
    function Window:OnSearch(fn)
        self._searchConn = self.Search:GetPropertyChangedSignal("Text"):Connect(function()
            fn(self.Search.Text)
        end)
        return self
    end

    function Window:AddCategory(name, icon)
        if not P.CategoryBar then warn("PrimordialUI: CategoryBar ausente"); return nil end
        local cat = P.CategoryBar.new(self, name, icon)
        table.insert(self.Categories, cat)
        if not self.ActiveCategory then self:SetActiveCategory(cat) end
        return cat
    end

    function Window:SetActiveCategory(cat)
        if self.Library.CloseActivePopup then self.Library:CloseActivePopup() end
        for _, c in ipairs(self.Categories) do c:SetActive(c == cat) end
        self.ActiveCategory = cat
    end

    -- categoria estandar para configurar la UI (accent, DPI, keybind, watermark, themes, configs, unload)
    function Window:AddSettingsTab(name)
        local Lib = self.Library
        local cat = self:AddCategory(name or "Settings", "settings")
        local sec = cat:AddSection("Configuration", "Configure the UI")

        -- no guardar los widgets del settings tab en las configs del usuario
        for _, f in ipairs({ "UIAccent", "UIDPIScale", "UIMenuKey", "UIWatermark", "UIWatermarkText",
            "UITheme", "UIKeybindList", "UIConfigName", "UIConfigList", "UIAutoload" }) do
            if Lib.ConfigIgnore then Lib.ConfigIgnore[f] = true end
        end

        local menu = sec:AddPanel("Menu", { Column = 1 })
        menu:AddColorPicker("UIAccent", { Text = "Accent Color", Default = T.Accent,
            Callback = function(c) Lib:SetTheme({ Accent = c }) end })
        if Lib.ListThemePresets then
            menu:AddDropdown("UITheme", { Text = "Theme Preset", Values = Lib:ListThemePresets(), Default = "Default",
                Callback = function(v) Lib:ApplyThemePreset(v) end })
        end
        menu:AddSlider("UIDPIScale", { Text = "DPI Scale", Min = 50, Max = 200, Default = 100, Suffix = "%",
            Callback = function(v) Lib:SetDPIScale(v) end })
        menu:AddKeybind("UIMenuKey", { Text = "Menu Keybind", Default = Lib.ToggleKey, NoUI = true,
            BindCallback = function(k) Lib.ToggleKey = k end })
        if Lib.SetKeybindListVisibility then
            menu:AddToggle("UIKeybindList", { Text = "Show Keybind List", Default = false,
                Callback = function(v) Lib:SetKeybindListVisibility(v) end })
        end
        menu:AddDivider()
        menu:AddButton("Unload", function() Lib:Unload() end)

        local wm = sec:AddPanel("Watermark", { Column = 2 })
        wm:AddToggle("UIWatermark", { Text = "Show Watermark", Default = false,
            Callback = function(v) Lib:SetWatermarkVisibility(v) end })
        wm:AddTextBox("UIWatermarkText", { Text = "Watermark Text", Default = "primordial",
            Placeholder = "text", Callback = function(t) if Lib.Flags.UIWatermark then Lib:SetWatermark(t) end end })

        -- Config manager (save/load)
        if Lib.SaveConfig then
            local cfg = sec:AddPanel("Configs", { Column = 2 })
            cfg:AddTextBox("UIConfigName", { Text = "Config Name", Placeholder = "my config" })
            local list = cfg:AddDropdown("UIConfigList", { Text = "Saved", Values = Lib:ListConfigs(), AllowNull = true })
            local function refresh() list:SetValues(Lib:ListConfigs()) end
            cfg:AddButton("Save", function()
                local n = Lib.Flags.UIConfigName
                if n and n ~= "" and Lib:SaveConfig(n) then refresh(); Lib:Notify("Config saved: " .. n, 3)
                else Lib:Notify("Enter a config name", 3) end
            end)
            cfg:AddButton("Load", function()
                local n = Lib.Flags.UIConfigList
                if n and Lib:LoadConfigFile(n) then Lib:Notify("Config loaded: " .. n, 3) end
            end)
            cfg:AddButton("Delete", function()
                local n = Lib.Flags.UIConfigList
                if n then Lib:DeleteConfig(n); refresh(); Lib:Notify("Config deleted: " .. n, 3) end
            end)
            cfg:AddToggle("UIAutoload", { Text = "Autoload selected", Default = Lib:GetAutoloadConfig() ~= nil,
                Callback = function(v) Lib:SetAutoloadConfig(v and Lib.Flags.UIConfigList or "") end })
        end
        return cat
    end

    function Window:SetVisible(b) self.Root.Visible = b end
    function Window:Destroy() self.Gui:Destroy() end

    P.Window = Window
end

end)(); __m(P) end
-- ==== Chrome/CategoryBar ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Category = {}
    Category.__index = Category

    function Category.new(Window, name, icon)
        local self = setmetatable({ Window = Window, Name = name, Sections = {}, ActiveSection = nil }, Category)

        -- botón en la franja inferior (icono + label)
        self.Button = U.Create("TextButton", {
            Parent = Window.CategoryButtons, AutoButtonColor = false,
            BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 52), Text = "",
        }, {
            U.Create("Frame", { Name = "Hi", BackgroundColor3 = T.Surface3,
                BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
                { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }) }),
            U.Create("ImageLabel", {
                Name = "Icon", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
                Size = UDim2.fromOffset(24, 24), Image = "",
                ImageColor3 = T.SubText,
            }),
            U.Create("TextLabel", {
                Name = "Label", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
                Size = UDim2.new(1, 0, 0, 16), Font = T.Font, TextSize = 12,
                Text = name, TextColor3 = T.SubText,
            }),
        })

        -- icono: nombre Lucide ("crosshair") o rbxassetid
        if P.Icons then P.Icons.apply(self.Button.Icon, icon)
        elseif icon then self.Button.Icon.Image = icon end

        -- página de contenido
        self.Page = U.Create("Frame", {
            Parent = Window.Body, Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Visible = false,
        })
        self.Sidebar = U.Create("Frame", {
            Parent = self.Page, Size = UDim2.new(0, 172, 1, 0),
            BackgroundColor3 = T.Sidebar, BorderSizePixel = 0, ClipsDescendants = true,
        }, { U.Create("UIListLayout", { Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8) }) })
        Window.Library.Registry:Add(self.Sidebar, "Sidebar", "BackgroundColor3")
        self.Content = U.Create("Frame", {
            Parent = self.Page, Position = UDim2.fromOffset(180, 8),
            Size = UDim2.new(1, -188, 1, -16), BackgroundTransparency = 1,
        })
        -- separador vertical entre sidebar y content, con sombra suave
        U.Create("Frame", { Parent = self.Page, BorderSizePixel = 0,
            Position = UDim2.fromOffset(172, 0), Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = T.Border })
        U.Create("Frame", { Parent = self.Page, BorderSizePixel = 0,
            Position = UDim2.fromOffset(173, 0), Size = UDim2.new(0, 8, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0) },
            { U.Create("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.6),
                NumberSequenceKeypoint.new(1, 1) }) }) })

        self.Button.MouseButton1Click:Connect(function()
            Window:SetActiveCategory(self)
        end)
        return self
    end

    function Category:AddSection(title, subtitle, opts)
        if not P.Section then warn("PrimordialUI: Section ausente"); return nil end
        local s = P.Section.new(self, title, subtitle, opts)
        table.insert(self.Sections, s)
        if not self.ActiveSection then self:SetActiveSection(s) end
        return s
    end

    function Category:SetActiveSection(s)
        local Lib = self.Window.Library
        if Lib.CloseActivePopup then Lib:CloseActivePopup() end
        for _, sec in ipairs(self.Sections) do sec:SetActive(sec == s) end
        self.ActiveSection = s
    end

    function Category:SetActive(b)
        self.Page.Visible = b
        self.Button.Hi.BackgroundTransparency = b and 0.55 or 1
        self.Button.Icon.ImageColor3 = b and T.Accent or T.SubText
        self.Button.Label.TextColor3 = b and T.Text or T.SubText
    end

    P.Category = Category
    P.CategoryBar = Category  -- alias esperado por Window
end

end)(); __m(P) end
-- ==== Chrome/Section ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Section = {}
    Section.__index = Section

    -- crea un set de N columnas (scrolling) dentro de parent, offset yOff arriba
    local function makeBoardSet(parent, yOff, nCols)
        nCols = nCols or 2
        local gap = 8
        local board = U.Create("Frame", { Parent = parent, BackgroundTransparency = 1, Visible = false,
            Position = UDim2.fromOffset(0, yOff), Size = UDim2.new(1, 0, 1, -yOff),
        }, { U.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }) })
        local cols = {}
        local off = -(gap * (nCols - 1) / nCols)
        for i = 1, nCols do
            cols[i] = U.Create("ScrollingFrame", { Parent = board, LayoutOrder = i,
                Size = UDim2.new(1 / nCols, off, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
            }, { U.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
                U.Create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2),
                    PaddingBottom = UDim.new(0, 2), PaddingRight = UDim.new(0, 5) }) })
        end
        return board, cols
    end

    function Section.new(Category, title, subtitle, opts)
        opts = opts or {}
        local self = setmetatable({ Category = Category, Panels = {}, Columns = {}, HasTabs = false,
            NumCols = math.clamp(opts.Columns or 2, 1, 4) }, Section)

        self.Button = U.Create("TextButton", {
            Parent = Category.Sidebar, AutoButtonColor = false, Text = "",
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44),
        }, {
            U.Create("Frame", { Name = "Hi", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(-8, 0),
            }, { U.Create("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.7),
                NumberSequenceKeypoint.new(0.65, 0.9),
                NumberSequenceKeypoint.new(1, 1) }) }) }),
            U.Create("Frame", { Name = "Bar", BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                Position = UDim2.fromOffset(-8, 0), Size = UDim2.new(0, 2, 1, 0), Visible = false }),
            U.Create("TextLabel", { Name = "Title", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 16),
                Font = T.FontBold, TextSize = 14, Text = title, TextColor3 = T.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }),
            U.Create("TextLabel", { Name = "Sub", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 14),
                Font = T.Font, TextSize = 12, Text = subtitle or "", TextColor3 = T.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }),
        })

        -- raiz de contenido (toggle por SetActive)
        self.Board = U.Create("Frame", { Parent = Category.Content, Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Visible = false })
        -- set de columnas por defecto (sin content-tabs)
        local b, c = makeBoardSet(self.Board, 0, self.NumCols)
        b.Visible = true
        self._defaultBoard = b
        self.Columns = c
        self._activeCols = c

        self.Button.MouseButton1Click:Connect(function()
            Category:SetActiveSection(self)
        end)
        return self
    end

    -- content-tabs de arma que abarcan AMBAS columnas (Rifles/Pistols/...)
    -- opts.PerRow = cuantos tabs por fila (default: todos en 1 fila). Envuelve en varias filas.
    function Section:AddTabs(list, opts)
        opts = opts or {}
        self.HasTabs = true
        self._defaultBoard.Visible = false
        self._tabBoards = {}
        self._tabOrder = list

        local n = #list
        local perRow = math.max(1, math.min(opts.PerRow or n, n))
        local rowH = 28
        local rows = math.ceil(n / perRow)
        local barH = rows * rowH

        self.TabBar = U.Create("Frame", { Parent = self.Board, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, barH),
        }, { U.Create("UIGridLayout", { CellSize = UDim2.new(1 / perRow, 0, 0, rowH),
            CellPadding = UDim2.fromOffset(0, 0), FillDirectionMaxCells = perRow,
            SortOrder = Enum.SortOrder.LayoutOrder }) })
        -- separador bajo la barra de tabs
        U.Create("Frame", { Parent = self.Board, Position = UDim2.fromOffset(0, barH),
            Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = T.Border })

        for i, name in ipairs(list) do
            local btn = U.Create("TextButton", { Parent = self.TabBar, AutoButtonColor = false,
                BackgroundTransparency = 1, LayoutOrder = i,
                Font = T.FontBold, TextSize = 13, Text = name, TextColor3 = T.SubText,
            }, { U.Create("Frame", { Name = "UL", BorderSizePixel = 0, BackgroundColor3 = T.Accent,
                AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
                Size = UDim2.new(0, 40, 0, 2), Visible = false }) })
            local board, cols = makeBoardSet(self.Board, barH + 4, self.NumCols)
            self._tabBoards[name] = { board = board, cols = cols, btn = btn }
            btn.MouseButton1Click:Connect(function() self:SetContentTab(name) end)
        end
        self:SetContentTab(list[1])
        return self
    end

    function Section:SetContentTab(name)
        local Lib = self.Category.Window.Library
        if Lib.CloseActivePopup then Lib:CloseActivePopup() end
        for n, t in pairs(self._tabBoards) do
            local on = n == name
            t.board.Visible = on
            t.btn.TextColor3 = on and T.Accent or T.SubText
            t.btn.UL.Visible = on
        end
        self._activeCols = self._tabBoards[name].cols
        self._activeTab = name
    end

    function Section:AddPanel(title, opts)
        opts = opts or {}
        local col = opts.Column
        if not col then col = (#self.Panels % self.NumCols) + 1 end
        col = math.clamp(col, 1, self.NumCols)
        local cols = self.Columns
        if self.HasTabs then
            local tab = opts.Tab or self._activeTab
            local tb = self._tabBoards[tab]
            cols = (tb and tb.cols) or self._activeCols
        end
        if not P.Panel then warn("PrimordialUI: Panel ausente"); return nil end
        local p = P.Panel.new(self, cols[col], title, opts)
        table.insert(self.Panels, p)
        return p
    end

    function Section:SetActive(b)
        self.Board.Visible = b
        self.Button.Bar.Visible = b
        self.Button.Hi.BackgroundTransparency = b and 0 or 1
        self.Button.Title.TextColor3 = b and T.Text or T.SubText
    end

    P.Section = Section
end

end)(); __m(P) end
-- ==== Chrome/Panel ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Panel = {}
    Panel.__index = Panel

    function Panel.new(Section, columnFrame, title, opts)
        local self = setmetatable({
            Section = Section,
            Library = Section.Category.Window.Library,
            _widgets = {}, Tabs = nil,
        }, Panel)

        local HH = 26 -- alto header (compacto)
        -- alto FIJO ligado al Body (no AutomaticSize) para que la sombra offset no lo infle
        self.Frame = U.Create("Frame", {
            Parent = columnFrame, Size = UDim2.new(1, 0, 0, HH + 1), ClipsDescendants = false,
            BackgroundColor3 = T.Surface, BorderSizePixel = 0, LayoutOrder = #Section.Panels + 1,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            -- gradiente sutil de profundidad (arriba mas claro -> abajo mas oscuro)
            U.Create("UIGradient", { Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(224, 224, 228)),
                }) }),
        })
        self.Library.Registry:Add(self.Frame, "Surface", "BackgroundColor3")

        -- sombra externa suave (Frame no es AutomaticSize => segura)
        U.Shadow(self.Frame, { Spread = 18, Transparency = 0.78, YOffset = 4 })

        self.Header = U.Create("TextLabel", {
            Parent = self.Frame, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -18, 0, HH),
            Font = T.FontBold, TextSize = 13, Text = title, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        -- separador bajo el titulo: color principal (accent)
        local sep = U.Create("Frame", { Parent = self.Frame, Position = UDim2.fromOffset(0, HH),
            Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = T.Accent })
        self.Library.Registry:Add(sep, "Accent", "BackgroundColor3")

        self.Body = U.Create("Frame", {
            Parent = self.Frame, Position = UDim2.fromOffset(0, HH + 1),
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        }, {
            U.Create("UIListLayout", { Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6),
                PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
        })

        -- ligar alto del Frame al contenido del Body
        local function resize()
            self.Frame.Size = UDim2.new(1, 0, 0, (HH + 1) + self.Body.AbsoluteSize.Y)
        end
        self.Library:Maid(self.Body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
        resize()
        return self
    end

    function Panel:_rowParent()
        if self.Tabs then return self.Tabs:ActiveContent() end
        return self.Body
    end

    local function widgetAdder(moduleKey)
        return function(self, flag, o)
            if not P[moduleKey] then warn("PrimordialUI: "..moduleKey.." ausente"); return nil end
            local W = P[moduleKey].new(self, flag, o or {})
            table.insert(self._widgets, W)
            return W
        end
    end
    Panel.AddToggle   = widgetAdder("Toggle")
    Panel.AddSlider   = widgetAdder("Slider")
    Panel.AddDropdown = widgetAdder("Dropdown")
    Panel.AddKeybind  = widgetAdder("Keybind")
    Panel.AddTextBox  = widgetAdder("TextBox")
    Panel.AddColorPicker = widgetAdder("ColorPicker")
    Panel.AddList        = widgetAdder("List")

    function Panel:AddButton(text, cb, opts)
        if not P.Button then return nil end
        opts = opts or {}
        local W = P.Button.new(self, nil, { Text = text, Callback = cb, DoubleClick = opts.DoubleClick })
        table.insert(self._widgets, W); return W
    end
    function Panel:AddLabel(text, opts)
        if not P.Label then return nil end
        local W = P.Label.new(self, nil, { Text = text, Header = opts and opts.Header })
        table.insert(self._widgets, W); return W
    end
    function Panel:AddDivider()
        if not P.Divider then return nil end
        local W = P.Divider.new(self, nil, {})
        table.insert(self._widgets, W); return W
    end
    function Panel:AddTabs(list)
        if not P.PanelTabs then return nil end
        self.Tabs = P.PanelTabs.new(self, list); return self.Tabs
    end
    function Panel:AddViewport(opts)
        if not P.Viewport then return nil end
        local W = P.Viewport.new(self, opts or {})
        table.insert(self._widgets, W); return W
    end
    function Panel:AddGrid(opts)
        if not P.Grid then return nil end
        local W = P.Grid.new(self, opts or {})
        table.insert(self._widgets, W); return W
    end

    P.Panel = Panel
end

end)(); __m(P) end
-- ==== Chrome/PanelTabs ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local PanelTabs = {}
    PanelTabs.__index = PanelTabs

    function PanelTabs.new(Panel, list)
        local self = setmetatable({ Panel = Panel, Tabs = {}, Contents = {}, Active = nil }, PanelTabs)

        self.Bar = U.Create("Frame", { Parent = Panel.Body, Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1, LayoutOrder = 0,
        }, { U.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

        for i, name in ipairs(list) do
            local btn = U.Create("TextButton", { Parent = self.Bar, AutoButtonColor = false,
                BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.new(0, 0, 1, 0), Font = T.FontBold, TextSize = 13,
                Text = name, TextColor3 = T.SubText, LayoutOrder = i,
            }, { U.Create("Frame", { Name = "UL", BorderSizePixel = 0, BackgroundColor3 = T.Accent,
                AnchorPoint = Vector2.new(0.5,1), Position = UDim2.new(0.5,0,1,0),
                Size = UDim2.new(1,0,0,2), Visible = false }) })
            local content = U.Create("Frame", { Parent = Panel.Body, LayoutOrder = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Visible = false,
            }, { U.Create("UIListLayout", { Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder }) })
            self.Tabs[name] = btn; self.Contents[name] = content
            btn.MouseButton1Click:Connect(function() self:SetActive(name) end)
            if i == 1 then self:SetActive(name) end
        end
        return self
    end

    function PanelTabs:SetActive(name)
        local Lib = self.Panel.Library
        if Lib and Lib.CloseActivePopup then Lib:CloseActivePopup() end
        for n, btn in pairs(self.Tabs) do
            local on = n == name
            btn.TextColor3 = on and T.Accent or T.SubText
            btn.UL.Visible = on
            self.Contents[n].Visible = on
        end
        self.Active = name
    end

    function PanelTabs:ActiveContent() return self.Contents[self.Active] end

    P.PanelTabs = PanelTabs
end

end)(); __m(P) end
-- ==== Widgets/_Base ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Base = {}
    Base.__index = Base

    function Base.new(Panel, opts)
        local self = setmetatable({
            Panel = Panel, Library = Panel.Library,
            Changed = P.Signal.new(), _deps = {},
        }, Base)
        local h = opts.Height or T.RowH
        self.Row = U.Create("Frame", {
            Parent = Panel:_rowParent(), Size = UDim2.new(1, 0, 0, h),
            BackgroundTransparency = 1, LayoutOrder = #Panel._widgets + 10,
        })
        if opts.LabelText ~= nil then
            self.Label = U.Create("TextLabel", { Parent = self.Row, BackgroundTransparency = 1,
                Size = UDim2.new(1, -120, 1, 0), Font = T.Font, TextSize = T.TextSize,
                Text = opts.LabelText, TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center })
            self.Library.Registry:Add(self.Label, "Text", "TextColor3")
        end
        self.Control = U.Create("Frame", { Parent = self.Row,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 110, 1, 0), BackgroundTransparency = 1 })
        if opts.Tooltip and self.Library.ShowTooltip then
            self.Row.MouseEnter:Connect(function() self.Library:ShowTooltip(opts.Tooltip) end)
            self.Row.MouseMoved:Connect(function() self.Library:MoveTooltip() end)
            self.Row.MouseLeave:Connect(function() self.Library:HideTooltip() end)
        end
        return self
    end

    function Base:SetVisible(b) self.Row.Visible = b end

    function Base:_evalDeps()
        local vis = true
        for _, d in ipairs(self._deps) do
            if self.Library.Flags[d.flag] ~= d.expected then vis = false break end
        end
        self:SetVisible(vis)
    end

    function Base:DependsOn(flag, expected)
        table.insert(self._deps, { flag = flag, expected = expected })
        self.Library:GetFlagSignal(flag):Connect(function() self:_evalDeps() end)
        self:_evalDeps()
        return self._widget or self
    end

    function Base:OnChanged(fn)
        self.Changed:Connect(fn)
        return self._widget or self
    end

    P.Base = Base
end

end)(); __m(P) end
-- ==== Widgets/Toggle ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Toggle = {}
    Toggle.__index = Toggle

    function Toggle.new(Panel, flag, opts)
        -- checkbox a la IZQUIERDA + label despues (estilo primordial)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 22, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Panel = Panel, Library = Panel.Library,
            Flag = flag, Value = opts.Default and true or false, Callback = opts.Callback }, Toggle)
        base._widget = self

        self.Box = U.Create("TextButton", { Parent = base.Row, AutoButtonColor = false,
            Text = "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1, 0.5, 0),
            Size = UDim2.fromOffset(14, 14), BackgroundColor3 = T.Surface2,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("UIGradient", { Name = "Depth", Rotation = 90, Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(0.82, 0.82, 0.82)) }) }),
            U.Create("ImageLabel", { Name = "Check", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.82, 0.82), Image = "rbxassetid://6031094667",
                ImageColor3 = Color3.fromRGB(18, 18, 20), ImageTransparency = 1 }),
        })
        self.Label = U.Create("TextLabel", { Parent = base.Row, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -140, 1, 0),
            Font = T.Font, TextSize = T.TextSize, Text = opts.Text or flag, TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center })

        self.Box.MouseButton1Click:Connect(function() self:SetValue(not self.Value) end)
        self.Library.Toggles[flag] = self
        self:_render()
        self.Library:SetFlag(flag, self.Value)
        return self
    end

    function Toggle:_render()
        self.Box.BackgroundColor3 = self.Value and T.Accent or T.Surface2
        self.Box.Check.ImageTransparency = self.Value and 0 or 1
        -- texto atenuado cuando esta apagado
        self.Label.TextColor3 = self.Value and T.Text or Color3.fromRGB(150, 150, 157)
    end

    function Toggle:SetValue(v)
        v = v and true or false
        if v == self.Value then return end
        self.Value = v; self:_render()
        self.Library:SetFlag(self.Flag, v)
        self._base.Changed:Fire(v)
        if self.Callback then task.spawn(self.Callback, v) end
    end
    function Toggle:GetValue() return self.Value end
    -- adjunta un swatch de color a la fila del toggle (patron Hitmarker); apilable
    function Toggle:AddColorPicker(flag, opts)
        if not P.ColorPicker then return self end
        self._cpCount = (self._cpCount or 0) + 1
        local xOffset = -(24 + (self._cpCount - 1) * 34)  -- deja lugar al checkbox + apila
        P.ColorPicker._attach(self.Library, self._base.Control, flag, opts or {}, xOffset)
        return self
    end
    function Toggle:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Toggle:OnChanged(fn) self._base:OnChanged(fn); return self end
    function Toggle:SetVisible(b) self._base:SetVisible(b) end

    P.Toggle = Toggle
end

end)(); __m(P) end
-- ==== Widgets/Slider ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local UIS = game:GetService("UserInputService")
    local Slider = {}
    Slider.__index = Slider

    function Slider.new(Panel, flag, opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 40, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Library = Panel.Library, Flag = flag,
            Min = opts.Min or 0, Max = opts.Max or 100, Decimals = opts.Decimals or 0,
            Suffix = opts.Suffix or "", Prefix = opts.Prefix or "", OffAtMin = opts.OffAtMin,
            Callback = opts.Callback }, Slider)
        base._widget = self
        base.Control.Visible = false

        -- linea superior: nombre + box de valor pegado al lado
        local topRow = U.Create("Frame", { Parent = base.Row, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
        }, { U.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

        U.Create("TextLabel", { Parent = topRow, BackgroundTransparency = 1, LayoutOrder = 1,
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
            Font = T.FontBold, TextSize = T.TextSize, Text = opts.Text or flag,
            TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left })

        self.ValBox = U.Create("Frame", { Parent = topRow, LayoutOrder = 2,
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 15),
            BackgroundColor3 = T.Surface2,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            U.Create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
            U.Create("TextLabel", { Name = "V", BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
                Font = T.Font, TextSize = 12, Text = "", TextColor3 = T.SubText,
                TextYAlignment = Enum.TextYAlignment.Center }) })
        self.ValLabel = self.ValBox.V

        -- track con fill (gradient de textura) + perilla
        self.Track = U.Create("TextButton", { Parent = base.Row, Text = "", AutoButtonColor = false,
            Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 8),
            BackgroundColor3 = T.Surface2,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            U.Create("Frame", { Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = T.Accent,
                Size = UDim2.new(0, 0, 1, 0) }, {
                U.Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
                U.Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.15),
                    NumberSequenceKeypoint.new(0.5, 0),
                    NumberSequenceKeypoint.new(1, 0.2) }) }),
            }),
        })
        -- perilla deslizable GRIS con textura (gradient vertical claro->oscuro)
        self.Knob = U.Create("Frame", { Parent = self.Track, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(7, 13),
            BackgroundColor3 = T.Knob, ZIndex = 3,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 2) }),
            U.Create("UIStroke", { Color = Color3.fromRGB(20,20,22), Transparency = 0.5, Thickness = 1 }),
            U.Create("UIGradient", { Rotation = 90, Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(235,235,238)),
                ColorSequenceKeypoint.new(0.5, T.Knob),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(150,150,156)) }) }) })
        U.Depth(self.Track, { Bottom = 0.18 })
        U.Depth(self.ValBox, { Bottom = 0.12 })
        base.Control.Visible = false

        local function setFromX(px)
            local abs = self.Track.AbsolutePosition.X
            local w = self.Track.AbsoluteSize.X
            local a = math.clamp((px - abs) / w, 0, 1)
            self:SetValue(self.Min + a * (self.Max - self.Min))
        end
        local dragging = false
        self.Track.MouseButton1Down:Connect(function() dragging = true
            setFromX(UIS:GetMouseLocation().X) end)
        self.Library:Maid(UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
        self.Library:Maid(UIS.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                setFromX(UIS:GetMouseLocation().X) end end))

        self.Library.Options[flag] = self
        self:SetValue(opts.Default ~= nil and opts.Default or self.Min)
        return self
    end

    function Slider:_fmt(v)
        if self.OffAtMin and v <= self.Min then return "Off" end
        local num
        if self.Decimals > 0 then
            num = string.format("%." .. self.Decimals .. "f", v)
        else
            num = tostring(math.floor(v + 0.5))
        end
        return self.Prefix .. num .. self.Suffix
    end

    function Slider:SetValue(v)
        v = math.clamp(v, self.Min, self.Max)
        if self.Decimals == 0 then v = math.floor(v + 0.5) end
        self.Value = v
        local a = (v - self.Min) / (self.Max - self.Min)
        self.Track.Fill.Size = UDim2.new(a, 0, 1, 0)
        self.Knob.Position = UDim2.new(a, 0, 0.5, 0)
        self.ValLabel.Text = self:_fmt(v)
        self.Library:SetFlag(self.Flag, v)
        self._base.Changed:Fire(v)
        if self.Callback then task.spawn(self.Callback, v) end
    end
    function Slider:GetValue() return self.Value end
    function Slider:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Slider:OnChanged(fn) self._base:OnChanged(fn); return self end
    function Slider:SetVisible(b) self._base:SetVisible(b) end

    P.Slider = Slider
end

end)(); __m(P) end
-- ==== Widgets/Dropdown ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Dropdown = {}
    Dropdown.__index = Dropdown

    local function hamburger(parent)
        local f = U.Create("Frame", { Parent = parent, Name = "Ham", BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(14, 11) })
        for i = 0, 2 do
            U.Create("Frame", { Parent = f, BorderSizePixel = 0, BackgroundColor3 = T.SubText,
                Position = UDim2.new(0, 0, 0, i * 5), Size = UDim2.new(1, 0, 0, 1.5) })
        end
        return f
    end

    function Dropdown.new(Panel, flag, opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 46, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Library = Panel.Library, Flag = flag,
            Values = opts.Values or {}, AllowNull = opts.AllowNull, Callback = opts.Callback,
            Multi = opts.Multi and true or false, Searchable = opts.Searchable and true or false,
            Open = false }, Dropdown)
        base._widget = self
        base.Control.Visible = false

        self.Title = U.Create("TextLabel", { Parent = base.Row, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16), Font = T.FontBold, TextSize = T.TextSize,
            Text = opts.Text or flag, TextColor3 = T.SubText,
            TextXAlignment = Enum.TextXAlignment.Left })

        self.DControl = U.Create("TextButton", { Parent = base.Row, Text = "", AutoButtonColor = false,
            Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = T.Surface2,
        }, {
            U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("TextLabel", { Name = "Val", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0),
                Font = T.Font, TextSize = T.TextSize, Text = "...", TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }),
        })
        U.Depth(self.DControl, { Highlight = true })
        if self.Multi then
            hamburger(self.DControl)
            self.Value = {}
        else
            U.Create("ImageLabel", { Parent = self.DControl, Name = "Chev", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(14, 14), Image = "rbxassetid://6034818372",
                ImageColor3 = T.SubText })
        end
        self.DControl.MouseButton1Click:Connect(function() self:Toggle() end)

        self.Library.Options[flag] = self
        if self.Multi then
            local def = opts.Default
            if type(def) == "table" then for _, v in ipairs(def) do self.Value[v] = true end end
            self:_renderMulti()
            self.Library:SetFlag(flag, self:GetValue())
        else
            local def = opts.Default
            if def == nil and not self.AllowNull then def = self.Values[1] end
            self:SetValue(def)
        end
        return self
    end

    function Dropdown:_closePopup()
        if self.Popup then self.Popup:Destroy(); self.Popup = nil end
        self.Open = false
        self.Library:ClosePopup(self._closer)
    end

    function Dropdown:Toggle()
        if self.Open then self:_closePopup(); return end
        self._closer = self._closer or function() self:_closePopup() end
        self.Library:OpenPopup(self._closer)
        self.Open = true
        local gui = self.DControl:FindFirstAncestorWhichIsA("ScreenGui")
        local ap, sz = self.DControl.AbsolutePosition, self.DControl.AbsoluteSize
        local rows = math.min(#self.Values, 7)
        local searchH = self.Searchable and 26 or 0
        self.Popup = U.Create("Frame", { Parent = gui, ZIndex = 50,
            Position = UDim2.fromOffset(ap.X, ap.Y + sz.Y + 2),
            Size = UDim2.fromOffset(sz.X, rows * 24 + 4 + searchH), BackgroundColor3 = T.Surface2, BorderSizePixel = 0,
            ClipsDescendants = true,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
        local searchBox
        if self.Searchable then
            searchBox = U.Create("TextBox", { Parent = self.Popup, ZIndex = 52,
                Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 20),
                BackgroundColor3 = T.Bg, ClearTextOnFocus = false, Font = T.Font, TextSize = 12,
                TextColor3 = T.Text, PlaceholderText = "Search...", PlaceholderColor3 = T.SubText,
                Text = "", TextXAlignment = Enum.TextXAlignment.Left,
            }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
                U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
                U.Create("UIPadding", { PaddingLeft = UDim.new(0, 6) }) })
        end
        local scroll = U.Create("ScrollingFrame", { Parent = self.Popup, ZIndex = 51,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, searchH), Size = UDim2.new(1, 0, 1, -searchH),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 0,
        }, { U.Create("UIListLayout", {}), U.Create("UIPadding", {
            PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }) })

        local itemBtns = {}
        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local q = searchBox.Text:lower()
                for _, ib in ipairs(itemBtns) do
                    ib.btn.Visible = (q == "") or ib.name:lower():find(q, 1, true) ~= nil
                end
            end)
        end

        for _, v in ipairs(self.Values) do
            local sel = self.Multi and self.Value[v] or (v == self.Value)
            local it = U.Create("TextButton", { Parent = scroll, ZIndex = 52,
                BackgroundColor3 = T.Surface3, BackgroundTransparency = sel and 0.5 or 1,
                Size = UDim2.new(1, 0, 0, 24), AutoButtonColor = false,
                Font = T.Font, TextSize = T.TextSize, Text = "",
            }, { U.Create("TextLabel", { Name = "L", BackgroundTransparency = 1, ZIndex = 52,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -12, 1, 0),
                Font = T.Font, TextSize = T.TextSize, Text = tostring(v),
                TextColor3 = sel and T.Accent or T.Text, TextXAlignment = Enum.TextXAlignment.Left }) })
            table.insert(itemBtns, { btn = it, name = tostring(v) })
            it.MouseButton1Click:Connect(function()
                if self.Multi then
                    self.Value[v] = (not self.Value[v]) or nil
                    it.BackgroundTransparency = self.Value[v] and 0.5 or 1
                    it.L.TextColor3 = self.Value[v] and T.Accent or T.Text
                    self:_renderMulti()
                    self.Library:SetFlag(self.Flag, self:GetValue())
                    self._base.Changed:Fire(self:GetValue())
                    if self.Callback then task.spawn(self.Callback, self:GetValue()) end
                else
                    self:SetValue(v); self:_closePopup()
                end
            end)
        end
    end

    function Dropdown:_renderMulti()
        local list = {}
        for _, v in ipairs(self.Values) do if self.Value[v] then table.insert(list, v) end end
        self.DControl.Val.Text = (#list == 0) and "None Selected" or table.concat(list, ", ")
        self.DControl.Val.TextColor3 = (#list == 0) and T.SubText or T.Text
    end

    function Dropdown:SetValue(v)
        if self.Multi then
            self.Value = {}
            if type(v) == "table" then for _, x in ipairs(v) do self.Value[x] = true end end
            self:_renderMulti()
            self.Library:SetFlag(self.Flag, self:GetValue())
        else
            self.Value = v
            self.DControl.Val.Text = v == nil and "None" or tostring(v)
            self.DControl.Val.TextColor3 = v == nil and T.SubText or T.Text
            self.Library:SetFlag(self.Flag, v)
        end
        self._base.Changed:Fire(self:GetValue())
        if self.Callback then task.spawn(self.Callback, self:GetValue()) end
    end

    function Dropdown:GetValue()
        if not self.Multi then return self.Value end
        local list = {}
        for _, v in ipairs(self.Values) do if self.Value[v] then table.insert(list, v) end end
        return list
    end
    function Dropdown:SetValues(list) self.Values = list end
    -- gear ⚙ a la derecha del titulo, abre un mini-panel de settings
    function Dropdown:AddGear()
        if not P.Gear then return nil end
        local g = P.Gear.new(self.Library)
        local icon = P.Gear.icon(self._base.Row)
        g:attachTo(icon)
        return g
    end
    function Dropdown:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Dropdown:OnChanged(fn) self._base:OnChanged(fn); return self end
    function Dropdown:SetVisible(b) self._base:SetVisible(b) end

    P.Dropdown = Dropdown
end

end)(); __m(P) end
-- ==== Widgets/Keybind ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local UIS = game:GetService("UserInputService")
    local Keybind = {}
    Keybind.__index = Keybind

    local function keyName(kc) return kc and kc.Name or "None" end

    function Keybind.new(Panel, flag, opts)
        local base = P.Base.new(Panel, { LabelText = opts.Text or flag, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Library = Panel.Library, Flag = flag,
            Mode = opts.Mode or "Toggle", Key = opts.Default, Capturing = false, Active = false,
            Callback = opts.Callback, BindCallback = opts.BindCallback }, Keybind)
        base._widget = self

        self.Btn = U.Create("TextButton", { Parent = base.Control, AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(96, 20), BackgroundColor3 = T.Surface2,
            Font = T.Font, TextSize = 12, TextColor3 = T.Text, Text = "Key: "..keyName(self.Key),
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Outline, Thickness = 1 }) })

        self.Btn.MouseButton1Click:Connect(function()
            self.Capturing = true; self.Btn.Text = "Key: ..."
        end)

        self.Library:Maid(UIS.InputBegan:Connect(function(inp, gpe)
            if self.Capturing and inp.KeyCode ~= Enum.KeyCode.Unknown then
                self.Capturing = false; self:SetKey(inp.KeyCode); return
            end
            if not gpe and self.Key and inp.KeyCode == self.Key then
                if self.Mode == "Toggle" then self:_setActive(not self.Active)
                elseif self.Mode == "Hold" then self:_setActive(true) end
            end
        end))
        self.Library:Maid(UIS.InputEnded:Connect(function(inp)
            if self.Mode == "Hold" and self.Key and inp.KeyCode == self.Key then
                self:_setActive(false)
            end
        end))

        self.Library.Options[flag] = self
        self.Library.Flags[flag] = self.Key
        if opts.NoUI ~= true and self.Library.RegisterKeybind then
            self._kbEntry = self.Library:RegisterKeybind(self)
        end
        if self.Mode == "Always" then self:_setActive(true) end
        return self
    end

    function Keybind:_setActive(v)
        self.Active = v
        self.Library.Flags[self.Flag.."Active"] = v
        if self._kbEntry then self._kbEntry:Update() end
        if self.Callback then task.spawn(self.Callback, v) end
        self._base.Changed:Fire(v)
    end
    function Keybind:SetKey(kc)
        self.Key = kc; self.Btn.Text = "Key: "..keyName(kc)
        self.Library.Flags[self.Flag] = kc
        if self._kbEntry then self._kbEntry:Update() end
        if self.BindCallback then task.spawn(self.BindCallback, kc) end
    end
    function Keybind:GetKey() return self.Key end
    function Keybind:SetValue(kc) self:SetKey(kc) end
    function Keybind:GetValue() return self.Key end
    function Keybind:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Keybind:OnChanged(fn) self._base:OnChanged(fn); return self end
    function Keybind:SetVisible(b) self._base:SetVisible(b) end

    P.Keybind = Keybind
end

end)(); __m(P) end
-- ==== Widgets/TextBox ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local TextBox = {}
    TextBox.__index = TextBox
    function TextBox.new(Panel, flag, opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 46, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Library = Panel.Library, Flag = flag,
            Numeric = opts.Numeric, MaxLength = opts.MaxLength, Callback = opts.Callback }, TextBox)
        base._widget = self; base.Control.Visible = false
        U.Create("TextLabel", { Parent = base.Row, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16), Font = T.FontBold, TextSize = T.TextSize,
            Text = opts.Text or flag, TextColor3 = T.SubText,
            TextXAlignment = Enum.TextXAlignment.Left })
        self.Input = U.Create("TextBox", { Parent = base.Row, Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Surface2, ClearTextOnFocus = false,
            Font = T.Font, TextSize = T.TextSize, TextColor3 = T.Text,
            PlaceholderText = opts.Placeholder or "Enter Text...", PlaceholderColor3 = T.SubText,
            Text = opts.Default or "", TextXAlignment = Enum.TextXAlignment.Left,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Outline, Thickness = 1 }),
            U.Create("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
        U.Depth(self.Input, { Highlight = true })
        self.Input:GetPropertyChangedSignal("Text"):Connect(function()
            local t = self.Input.Text
            if self.Numeric then t = t:gsub("[^%d%.%-]", "") end
            if self.MaxLength then t = t:sub(1, self.MaxLength) end
            if t ~= self.Input.Text then self.Input.Text = t end
            self:_set(t)
        end)
        self.Library.Options[flag] = self
        self:_set(opts.Default or "")
        return self
    end
    function TextBox:_set(t) self.Value = t; self.Library:SetFlag(self.Flag, t)
        self._base.Changed:Fire(t); if self.Callback then task.spawn(self.Callback, t) end end
    function TextBox:SetValue(t) self.Input.Text = t end
    function TextBox:GetValue() return self.Value end
    function TextBox:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function TextBox:OnChanged(fn) self._base:OnChanged(fn); return self end
    function TextBox:SetVisible(b) self._base:SetVisible(b) end
    P.TextBox = TextBox
end

end)(); __m(P) end
-- ==== Widgets/Button ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Button = {}
    Button.__index = Button
    function Button.new(Panel, _flag, opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 30, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Callback = opts.Callback,
            Double = opts.DoubleClick, _last = 0 }, Button)
        base._widget = self; base.Control.Visible = false
        self.Btn = U.Create("TextButton", { Parent = base.Row, AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Surface2,
            Font = T.FontBold, TextSize = T.TextSize, TextColor3 = T.Text, Text = opts.Text or "Button",
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Outline, Thickness = 1 }) })
        self.Btn.MouseEnter:Connect(function() self.Btn.BackgroundColor3 = T.AccentDim end)
        self.Btn.MouseLeave:Connect(function() self.Btn.BackgroundColor3 = T.Surface2 end)
        self.Btn.MouseButton1Click:Connect(function()
            if self.Double then
                local now = os.clock()
                if now - self._last > 0.4 then self._last = now; self.Btn.Text = "Are you sure?"; return end
                self.Btn.Text = opts.Text or "Button"
            end
            if self.Callback then task.spawn(self.Callback) end
        end)
        return self
    end
    function Button:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Button:SetVisible(b) self._base:SetVisible(b) end
    P.Button = Button
end

end)(); __m(P) end
-- ==== Widgets/Label ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Label = {}
    Label.__index = Label
    function Label.new(Panel, _flag, opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = opts.Header and 20 or 18 })
        local self = setmetatable({ _base = base }, Label)
        base._widget = self; base.Control.Visible = false
        self.Text = U.Create("TextLabel", { Parent = base.Row, BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Text = opts.Text or "",
            Font = opts.Header and T.FontBold or T.Font, TextSize = T.TextSize,
            TextColor3 = opts.Header and T.Text or T.SubText,
            TextXAlignment = Enum.TextXAlignment.Left })
        return self
    end
    function Label:SetText(t) self.Text.Text = t end
    function Label:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Label:SetVisible(b) self._base:SetVisible(b) end
    P.Label = Label
end

end)(); __m(P) end
-- ==== Widgets/Divider ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Divider = {}
    Divider.__index = Divider
    function Divider.new(Panel, _flag, _opts)
        local base = P.Base.new(Panel, { LabelText = nil, Height = 9 })
        local self = setmetatable({ _base = base }, Divider)
        base._widget = self; base.Control.Visible = false
        U.Create("Frame", { Parent = base.Row, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0, BackgroundColor3 = T.Outline })
        return self
    end
    function Divider:SetVisible(b) self._base:SetVisible(b) end
    P.Divider = Divider
end

end)(); __m(P) end
-- ==== Widgets/ColorPicker ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local function mouseXY()
        local m = UIS:GetMouseLocation()
        local ins = GuiService:GetGuiInset()
        return m.X - ins.X, m.Y - ins.Y
    end
    local CP = {}
    CP.__index = CP

    local RAINBOW = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.51, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
    })

    local function swatch(parent)
        return U.Create("TextButton", { Parent = parent, Text = "", AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(28, 14), BackgroundColor3 = Color3.new(1, 1, 1),
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            U.Create("UIStroke", { Color = T.Outline, Thickness = 1 }) })
    end

    -- Crea el swatch en un parent arbitrario (uso standalone o adjunto a toggle)
    function CP._attach(Library, parentControl, flag, opts, xOffset)
        local self = setmetatable({ Library = Library, Flag = flag, Callback = opts.Callback,
            Open = false }, CP)
        self.Swatch = swatch(parentControl)
        if xOffset then self.Swatch.Position = UDim2.new(1, xOffset, 0.5, 0) end
        local d = opts.Default or Color3.fromRGB(255, 0, 0)
        self.H, self.S, self.V = d:ToHSV()
        self.Swatch.MouseButton1Click:Connect(function() self:Toggle() end)
        Library.Options[flag] = self
        self:_apply()
        return self
    end

    function CP.new(Panel, flag, opts)
        local base = P.Base.new(Panel, { LabelText = opts.Text or flag })
        local self = CP._attach(Panel.Library, base.Control, flag, opts, nil)
        self._base = base
        base._widget = self
        return self
    end

    function CP:_color() return Color3.fromHSV(self.H, self.S, self.V) end

    function CP:_apply()
        local c = self:_color()
        self.Value = c                      -- expone .Value como Color3 (fresco) para leerlo directo
        self.Swatch.BackgroundColor3 = c
        self.Library:SetFlag(self.Flag, c)
        if self._base then self._base.Changed:Fire(c) end
        if self.Callback then task.spawn(self.Callback, c) end
    end

    function CP:SetColor(c) self.H, self.S, self.V = c:ToHSV(); self:_apply()
        if self.SVCursor then self:_syncCursors() end end
    function CP:GetColor() return self:_color() end
    function CP:SetValue(c) self:SetColor(c) end
    function CP:GetValue() return self:_color() end

    function CP:_syncCursors()
        self.SVCursor.Position = UDim2.new(self.S, 0, 1 - self.V, 0)
        self.SV.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
        self.HueCursor.Position = UDim2.new(0.5, 0, self.H, 0)
    end

    function CP:_closePopup()
        if self._c1 then self._c1:Disconnect(); self._c1 = nil end
        if self._c2 then self._c2:Disconnect(); self._c2 = nil end
        if self.Popup then self.Popup:Destroy(); self.Popup = nil end
        self.Open = false
        self.Library:ClosePopup(self._closer)
    end

    function CP:Toggle()
        if self.Open then self:_closePopup(); return end
        self._closer = self._closer or function() self:_closePopup() end
        self.Library:OpenPopup(self._closer)
        self.Open = true
        local gui = self.Swatch:FindFirstAncestorWhichIsA("ScreenGui")
        local ap = self.Swatch.AbsolutePosition
        local PH = 150
        local py = ap.Y + 20
        if py + PH > gui.AbsoluteSize.Y - 8 then py = ap.Y - PH - 6 end  -- flip arriba si no cabe
        self.Popup = U.Create("Frame", { Parent = gui, ZIndex = 60,
            Position = UDim2.fromOffset(ap.X - 150, py),
            Size = UDim2.fromOffset(190, PH), BackgroundColor3 = T.Surface2, BorderSizePixel = 0,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Outline, Thickness = 1 }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0,8), PaddingLeft = UDim.new(0,8),
                PaddingBottom = UDim.new(0,8), PaddingRight = UDim.new(0,8) }) })

        -- cuadro SV (saturacion x, valor y)
        self.SV = U.Create("Frame", { Parent = self.Popup, ZIndex = 61,
            Size = UDim2.fromOffset(150, 134), BackgroundColor3 = Color3.fromHSV(self.H, 1, 1),
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            -- blanco horizontal (saturacion)
            U.Create("Frame", { BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.fromScale(1,1),
                ZIndex = 61 }, { U.Create("UICorner", { CornerRadius = UDim.new(0,4) }),
                U.Create("UIGradient", { Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }) }),
            -- negro vertical (valor)
            U.Create("Frame", { BackgroundColor3 = Color3.new(0,0,0), Size = UDim2.fromScale(1,1),
                ZIndex = 62 }, { U.Create("UICorner", { CornerRadius = UDim.new(0,4) }),
                U.Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }) }),
        })
        self.SVBtn = U.Create("TextButton", { Parent = self.SV, Text = "", BackgroundTransparency = 1,
            Size = UDim2.fromScale(1,1), ZIndex = 64 })
        self.SVCursor = U.Create("Frame", { Parent = self.SV, ZIndex = 63,
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Color3.new(1,1,1) },
            { U.Create("UICorner", { CornerRadius = UDim.new(1,0) }),
              U.Create("UIStroke", { Color = Color3.new(0,0,0), Thickness = 1 }) })

        -- barra de hue vertical
        self.Hue = U.Create("TextButton", { Parent = self.Popup, Text = "", AutoButtonColor = false,
            ZIndex = 61, Position = UDim2.fromOffset(160, 0), Size = UDim2.fromOffset(14, 134),
            BackgroundColor3 = Color3.new(1,1,1),
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            U.Create("UIGradient", { Rotation = 90, Color = RAINBOW }) })
        self.HueCursor = U.Create("Frame", { Parent = self.Hue, ZIndex = 62,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, self.H, 0),
            Size = UDim2.new(1, 4, 0, 3), BackgroundColor3 = Color3.new(1,1,1) },
            { U.Create("UIStroke", { Color = Color3.new(0,0,0), Thickness = 1 }) })

        self:_syncCursors()

        -- drag SV
        local function svFrom(px, py)
            local s = math.clamp((px - self.SV.AbsolutePosition.X) / self.SV.AbsoluteSize.X, 0, 1)
            local v = 1 - math.clamp((py - self.SV.AbsolutePosition.Y) / self.SV.AbsoluteSize.Y, 0, 1)
            self.S, self.V = s, v; self:_apply(); self:_syncCursors()
        end
        local function hueFrom(py)
            self.H = math.clamp((py - self.Hue.AbsolutePosition.Y) / self.Hue.AbsoluteSize.Y, 0, 1)
            self:_apply(); self:_syncCursors()
        end
        local svDrag, hueDrag = false, false
        self.SVBtn.MouseButton1Down:Connect(function() svDrag = true
            local mx, my = mouseXY(); svFrom(mx, my) end)
        self.Hue.MouseButton1Down:Connect(function() hueDrag = true
            local _, my = mouseXY(); hueFrom(my) end)
        self._c1 = UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then svDrag, hueDrag = false, false end end)
        self._c2 = UIS.InputChanged:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local mx, my = mouseXY()
            if svDrag then svFrom(mx, my) elseif hueDrag then hueFrom(my) end
        end)
    end

    function CP:DependsOn(f, e) if self._base then self._base:DependsOn(f, e) end; return self end
    function CP:OnChanged(fn) if self._base then self._base:OnChanged(fn) end; return self end
    function CP:SetVisible(b) if self._base then self._base:SetVisible(b) end end

    P.ColorPicker = CP
end

end)(); __m(P) end
-- ==== Widgets/Gear ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local UIS = game:GetService("UserInputService")
    local Gear = {}
    Gear.__index = Gear

    -- icono engranaje
    function Gear.icon(parent)
        return U.Create("ImageButton", { Parent = parent, Name = "Gear", BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(14, 14),
            Image = "rbxassetid://6031280882", ImageColor3 = T.SubText, ZIndex = 5 })
    end

    -- mini-panel flotante que imita la interfaz de Panel (para reusar los widgets)
    function Gear.new(Library)
        local self = setmetatable({ Library = Library, _widgets = {}, Open = false }, Gear)
        self.Popup = U.Create("Frame", { Visible = false, ZIndex = 70, BackgroundColor3 = T.Surface,
            BorderSizePixel = 0, Size = UDim2.new(0, 210, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
        U.Shadow(self.Popup, { Spread = 18, Transparency = 0.72, YOffset = 5 })
        self.Body = U.Create("Frame", { Parent = self.Popup, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, { U.Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
        return self
    end

    function Gear:_rowParent() return self.Body end

    local function adder(key)
        return function(self, flag, o)
            if not P[key] then return nil end
            local W = P[key].new(self, flag, o or {})
            table.insert(self._widgets, W); return W
        end
    end
    Gear.AddToggle   = adder("Toggle")
    Gear.AddSlider   = adder("Slider")
    Gear.AddDropdown = adder("Dropdown")
    Gear.AddKeybind  = adder("Keybind")
    Gear.AddTextBox  = adder("TextBox")
    function Gear:AddButton(t, cb) local W = P.Button.new(self, nil, { Text = t, Callback = cb })
        table.insert(self._widgets, W); return W end
    function Gear:AddLabel(t, o) local W = P.Label.new(self, nil, { Text = t, Header = o and o.Header })
        table.insert(self._widgets, W); return W end
    function Gear:AddColorPicker(f, o) local W = P.ColorPicker.new(self, f, o or {})
        table.insert(self._widgets, W); return W end

    function Gear:attachTo(iconBtn)
        self._icon = iconBtn
        iconBtn.MouseButton1Click:Connect(function() self:Toggle() end)
    end

    function Gear:_forceClose()
        self.Popup.Visible = false; self.Open = false
        if self._icon then self._icon.ImageColor3 = T.SubText end
        self.Library:ClosePopup(self._closer)
    end

    function Gear:Toggle()
        if self.Open then self:_forceClose(); return end
        self._closer = self._closer or function() self:_forceClose() end
        self.Library:OpenPopup(self._closer)
        local gui = self._icon:FindFirstAncestorWhichIsA("ScreenGui")
        self.Popup.Parent = gui
        local ap = self._icon.AbsolutePosition
        self.Popup.Position = UDim2.fromOffset(ap.X - 210 + 20, ap.Y + 20)
        self.Popup.Visible = true; self.Open = true
        self._icon.ImageColor3 = T.Accent
    end

    P.Gear = Gear
end

end)(); __m(P) end
-- ==== Widgets/Viewport ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local RunService = game:GetService("RunService")
    local Viewport = {}
    Viewport.__index = Viewport

    -- handler generico: mete cualquier modelo/instancia y lo muestra (auto-frame + auto-rotate)
    function Viewport.new(Panel, opts)
        opts = opts or {}
        local base = P.Base.new(Panel, { LabelText = nil, Height = opts.Height or 180 })
        local self = setmetatable({ _base = base, Library = Panel.Library,
            AutoRotate = opts.AutoRotate ~= false, Speed = opts.RotateSpeed or 40,
            Pitch = opts.Pitch or 0.35, _angle = 0 }, Viewport)
        base._widget = self
        base.Control.Visible = false

        self.VF = U.Create("ViewportFrame", { Parent = base.Row, Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = opts.Background or T.Surface2, BorderSizePixel = 0,
            Ambient = Color3.fromRGB(170, 170, 175), LightColor = Color3.fromRGB(255, 255, 255),
            LightDirection = Vector3.new(-0.4, -1, -0.5),
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
        self.Cam = Instance.new("Camera"); self.Cam.Parent = self.VF; self.VF.CurrentCamera = self.Cam
        self.World = Instance.new("WorldModel"); self.World.Parent = self.VF
        self.Library:Maid(self.VF)
        return self
    end

    function Viewport:Clear()
        if self._conn then self._conn:Disconnect(); self._conn = nil end
        for _, c in ipairs(self.World:GetChildren()) do c:Destroy() end
        self.Model = nil
    end

    -- inst: cualquier Model / BasePart / Folder de partes. opts.AutoRotate opcional override.
    function Viewport:SetModel(inst, opts)
        self:Clear()
        if not inst then return end
        opts = opts or {}
        local m
        pcall(function() m = inst:Clone() end)
        if not m then
            -- Archivable=false devuelve nil: forzarlo temporalmente
            local prev = inst.Archivable
            inst.Archivable = true
            pcall(function() m = inst:Clone() end)
            inst.Archivable = prev
        end
        if not m then return end
        if not m:IsA("Model") then
            local wrap = Instance.new("Model")
            m.Parent = wrap
            m = wrap
        end
        m.Parent = self.World
        self.Model = m

        local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
        if not ok or not cf then cf, size = CFrame.new(), Vector3.new(4, 4, 4) end
        self._center = cf.Position
        self._radius = math.max(size.Magnitude / 2, 1)
        self._dist = self._radius / math.tan(math.rad(30)) + self._radius
        self:_apply(0)

        local rotate = opts.AutoRotate
        if rotate == nil then rotate = self.AutoRotate end
        if rotate then
            self._conn = RunService.RenderStepped:Connect(function(dt) self:_spin(dt) end)
            self.Library:Maid(self._conn)
        end
        return self
    end

    function Viewport:_apply(angle)
        local c = self._center
        local pos = c + Vector3.new(math.sin(angle) * self._dist, self._radius * self.Pitch, math.cos(angle) * self._dist)
        self.Cam.CFrame = CFrame.lookAt(pos, c)
    end
    function Viewport:_spin(dt)
        self._angle = self._angle + math.rad(self.Speed) * dt
        self:_apply(self._angle)
    end

    function Viewport:SetAutoRotate(b)
        self.AutoRotate = b
        if not b and self._conn then self._conn:Disconnect(); self._conn = nil
        elseif b and self.Model and not self._conn then
            self._conn = RunService.RenderStepped:Connect(function(dt) self:_spin(dt) end)
            self.Library:Maid(self._conn)
        end
    end
    function Viewport:SetSpeed(s) self.Speed = s end
    function Viewport:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function Viewport:SetVisible(b) self._base:SetVisible(b) end

    P.Viewport = Viewport
end

end)(); __m(P) end
-- ==== Widgets/Grid ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local Grid = {}
    Grid.__index = Grid

    -- grid de thumbnails (estilo Skins de primordial). opts: Height, CellSize, Callback
    function Grid.new(Panel, opts)
        opts = opts or {}
        local base = P.Base.new(Panel, { LabelText = nil, Height = opts.Height or 200 })
        local self = setmetatable({ _base = base, Library = Panel.Library,
            Cell = opts.CellSize or 54, Callback = opts.Callback, Items = {}, Selected = nil }, Grid)
        base._widget = self
        base.Control.Visible = false

        self.Scroll = U.Create("ScrollingFrame", { Parent = base.Row, BackgroundColor3 = T.Surface2,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }),
            U.Create("UIGridLayout", { CellSize = UDim2.fromOffset(self.Cell, self.Cell),
                CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Left }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 6) }) })
        return self
    end

    -- item: { Image = assetId, Name = string?, Callback = fn? }
    function Grid:AddItem(item)
        local i = #self.Items + 1
        local cell = U.Create("TextButton", { Parent = self.Scroll, AutoButtonColor = false, Text = "",
            BackgroundColor3 = T.Surface3, LayoutOrder = i,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            U.Create("UIStroke", { Name = "Sel", Color = T.Accent, Thickness = 1, Transparency = 1 }),
            U.Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = item.Image or "",
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.78, 0.78), ScaleType = Enum.ScaleType.Fit }) })
        if item.Name then
            cell.Icon.Position = UDim2.fromScale(0.5, 0.42)
            cell.Icon.Size = UDim2.fromScale(0.66, 0.66)
            U.Create("TextLabel", { Parent = cell, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -4, 0, 11),
                Font = T.Font, TextSize = 10, TextColor3 = T.SubText, Text = item.Name,
                TextTruncate = Enum.TextTruncate.AtEnd })
        end
        local rec = { cell = cell, item = item }
        table.insert(self.Items, rec)
        cell.MouseButton1Click:Connect(function() self:Select(i) end)
        return rec
    end

    function Grid:Select(i)
        for idx, rec in ipairs(self.Items) do
            rec.cell.Sel.Transparency = (idx == i) and 0 or 1
        end
        self.Selected = i
        local it = self.Items[i]
        if it then
            if it.item.Callback then task.spawn(it.item.Callback, it.item) end
            if self.Callback then task.spawn(self.Callback, it.item, i) end
        end
    end
    function Grid:GetSelected() local r = self.Items[self.Selected]; return r and r.item end
    function Grid:Clear()
        for _, r in ipairs(self.Items) do r.cell:Destroy() end
        self.Items = {}; self.Selected = nil
    end
    function Grid:SetVisible(b) self._base:SetVisible(b) end

    P.Grid = Grid
end

end)(); __m(P) end
-- ==== Widgets/List ====
do local __m = (function()
return function(P)
    local U, T = P.Util, P.Theme
    local List = {}
    List.__index = List

    -- list-box permanente (dropdown pre-abierto). opts: Text, Values, Multi, Default, Height, Callback
    function List.new(Panel, flag, opts)
        local titleH = opts.Text and 18 or 0
        local boxH = opts.Height or 120
        local base = P.Base.new(Panel, { LabelText = nil, Height = titleH + boxH, Tooltip = opts.Tooltip })
        local self = setmetatable({ _base = base, Library = Panel.Library, Flag = flag,
            Values = opts.Values or {}, Multi = opts.Multi and true or false, Callback = opts.Callback,
            Items = {} }, List)
        base._widget = self
        base.Control.Visible = false

        if opts.Text then
            self.Title = U.Create("TextLabel", { Parent = base.Row, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16), Font = T.FontBold, TextSize = T.TextSize,
                Text = opts.Text, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left })
        end

        self.Box = U.Create("Frame", { Parent = base.Row, Position = UDim2.fromOffset(0, titleH),
            Size = UDim2.new(1, 0, 0, boxH), BackgroundColor3 = T.Surface2, BorderSizePixel = 0, ClipsDescendants = true,
        }, { U.Create("UICorner", { CornerRadius = UDim.new(0, T.Radius) }),
            U.Create("UIStroke", { Color = T.Border, Thickness = 1 }) })
        self.Scroll = U.Create("ScrollingFrame", { Parent = self.Box, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
        }, { U.Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
            U.Create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }) })

        if self.Multi then self.Value = {} else self.Value = nil end
        self:_build()

        self.Library.Options[flag] = self
        local def = opts.Default
        if self.Multi then
            if type(def) == "table" then for _, v in ipairs(def) do self.Value[v] = true end end
        elseif def == nil and not opts.AllowNull then def = self.Values[1] end
        self:SetValue(self.Multi and self:GetValue() or def)
        return self
    end

    function List:_build()
        for _, it in ipairs(self.Items) do it.btn:Destroy() end
        self.Items = {}
        for i, v in ipairs(self.Values) do
            local btn = U.Create("TextButton", { Parent = self.Scroll, AutoButtonColor = false,
                BackgroundColor3 = T.Surface3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22),
                LayoutOrder = i, Text = "",
            }, { U.Create("TextLabel", { Name = "L", BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -12, 1, 0), Font = T.Font,
                TextSize = T.TextSize, Text = tostring(v), TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }) })
            table.insert(self.Items, { btn = btn, value = v })
            btn.MouseButton1Click:Connect(function() self:_click(v) end)
        end
        self:_render()
    end

    function List:_click(v)
        if self.Multi then
            self.Value[v] = (not self.Value[v]) or nil
        else
            self.Value = v
        end
        self:_render()
        self.Library:SetFlag(self.Flag, self:GetValue())
        self._base.Changed:Fire(self:GetValue())
        if self.Callback then task.spawn(self.Callback, self:GetValue()) end
    end

    function List:_isSel(v)
        if self.Multi then return self.Value[v] == true else return self.Value == v end
    end
    function List:_render()
        for _, it in ipairs(self.Items) do
            local sel = self:_isSel(it.value)
            it.btn.BackgroundTransparency = sel and 0.4 or 1
            it.btn.L.TextColor3 = sel and T.Accent or T.Text
        end
    end

    function List:GetValue()
        if not self.Multi then return self.Value end
        local out = {}
        for _, v in ipairs(self.Values) do if self.Value[v] then table.insert(out, v) end end
        return out
    end
    function List:SetValue(v)
        if self.Multi then
            self.Value = {}
            if type(v) == "table" then for _, x in ipairs(v) do self.Value[x] = true end end
        else
            self.Value = v
        end
        self:_render()
        self.Library:SetFlag(self.Flag, self:GetValue())
        self._base.Changed:Fire(self:GetValue())
        if self.Callback then task.spawn(self.Callback, self:GetValue()) end
    end
    function List:SetValues(list) self.Values = list; self:_build() end
    function List:DependsOn(f, e) self._base:DependsOn(f, e); return self end
    function List:OnChanged(fn) self._base:OnChanged(fn); return self end
    function List:SetVisible(b) self._base:SetVisible(b) end

    P.List = List
end

end)(); __m(P) end
return P.Library