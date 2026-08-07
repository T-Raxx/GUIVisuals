# Visuals Suite §D — Preview Viewport (PrimordialUI-only) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ventana de preview SEPARADA al lado de la UI, **solo en PrimordialUI**, que muestra el modelo del char local rotando sobre fondo matrix oscuro, con world-lighting + chams (Highlight fade) + box ESP representativo aplicados en vivo. **ClaudeUI NO recibe preview** (0 instancias, undetected).

**Architecture:** `ui/preview.lua` = `GV.Preview.mount(suite, opts)` construye un pane instance-based bespoke (ScreenGui en `gethui()`, ViewportFrame+Camera+WorldModel, box overlay, matrix rain) y corre un RenderStepped que lee `suite.flags`. Gateado por capacidad del adapter: `adapter_primordial.supportsPreview=true` → attach lo monta; `adapter_claudeui` sin la capacidad → skip (nunca crea instancias).

**Tech Stack:** Luau executor, instancias Roblox (ViewportFrame/Highlight/Frame), `gethui()`, testing live MCP.

## Global Constraints

- **PrimordialUI-only.** El preview es instance-based (ViewportFrame es 1 instancia). ClaudeUI debe quedar 0-instancias → NO se monta ahí. Gate: `adapter.supportsPreview`.
- **`return function(GV) ... end`**, sin `require`.
- **Reusa** `suite.flags` (compartido) + `GV.Color.fade` + `ESP:RenderPreview` (ya existe). Lighting del preview = props propias del `ViewportFrame` (`Ambient/LightColor/LightDirection`), NO el `Lighting` global.
- **Cleanup total:** todo instance creado va a `_made`, destruido en Unload; conns en `_conns`.
- **Ruta/MCP:** mismo Test Loop. Preview se testea live en Baseplate (gethui + ViewportFrame reales).

## File Structure

- Create: `ui/preview.lua` — `GV.Preview.mount(suite, opts) -> handle`.
- Modify: `ui/adapter_primordial.lua` — `A.supportsPreview = true`.
- Modify: `ui/adapter_claudeui.lua` — (no cambia; sin `supportsPreview`).
- Modify: `schema/_helpers.lua` — `suiteRows` agrega `Suite_Preview` toggle.
- Modify: `entry/attach.lua` — si `adapter.supportsPreview` y `opts.preview~=false` → `GV.Preview.mount(suite)`; `suite:Unload` lo limpia.
- Modify: `init.lua` — ORDER agrega `ui/preview.lua`. `build.lua` — ORDER idem.
- Create tests: `test/test_preview.lua`, `test/demo_preview.lua`.

Referencia: `PrimordialUI/Widgets/Viewport.lua` (ViewportFrame+Camera+WorldModel, `SetModel` clona/encuadra/rota, mapea `VF.Ambient/LightColor`).

---

## Task 1: Preview core — ventana separada + viewport + modelo + auto-rotate

**Files:**
- Create: `ui/preview.lua`
- Modify: `init.lua` (ORDER: `ui/preview.lua` tras `ui/renderer.lua`)
- Create: `test/test_preview.lua`

**Interfaces:**
- Produces: `GV.Preview.mount(suite, opts) -> { Root, VF, Cam, World, SetModel(char), Unload() }`. Crea ScreenGui en gethui, ventana draggable al lado del centro, ViewportFrame+Camera+WorldModel, clona el char local, auto-rota. Loop RenderStepped gateado por `flags.Suite_Preview`.

- [ ] **Step 1: Write the failing test** — `test/test_preview.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local suite = { flags = { Suite_Preview = true } }
local p = GV.Preview.mount(suite, { always = true })
T.truthy(p and p.VF and p.VF:IsA("ViewportFrame"), "ViewportFrame creado")
T.truthy(p.World and p.World:IsA("WorldModel"), "WorldModel creado")
-- SetModel con un dummy
local dummy = T.spawnDummy()
p:SetModel(dummy)
T.truthy(p.Model and p.Model.Parent == p.World, "modelo clonado en el viewport")
p:Unload()
T.truthy(p.VF.Parent == nil, "Unload destruye el viewport")
dummy:Destroy()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.Preview` nil).

- [ ] **Step 3: Implementation** — `ui/preview.lua`

```lua
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
        root.Position = UDim2.new(0.5, 440, 0.5, -160) -- al lado de la UI principal
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

        -- drag por el header
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
            -- (world-lighting + chams + box + matrix en D2)
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
```
`init.lua` ORDER: agregar `"ui/preview.lua"` tras `"ui/renderer.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add ui/preview.lua init.lua test/test_preview.lua
git commit -m "feat: Preview viewport core (separate window + model + auto-rotate)"
```

---

## Task 2: Live application — world lighting + chams + box overlay + matrix rain

**Files:**
- Modify: `ui/preview.lua` (`_step` completo + `_makeOverlay`)
- Modify: `test/test_preview.lua` (asserts nuevos)

**Interfaces:**
- Produces: `_step` mapea flags a: `VF.Ambient/LightColor` (World_Ambient vía Color.fade + World_Brightness), Highlight sobre el clone (`ESP_Chams` o `Local_SelfChams` → FillColor/OutlineColor Color.fade), box overlay (Frame border color `ESP_BoxColor` Color.fade), matrix rain animada (TextLabels verdes cayendo).

- [ ] **Step 1: Add asserts** a `test/test_preview.lua` (chams: set `ESP_Chams=true` + `ESP_ChamsFill` → `p._chams` Highlight existe con FillColor; box: `p._box` stroke color = ESP_BoxColor).

- [ ] **Step 2: Implementation** — en `Preview.mount`, agregar en la construcción: box overlay Frame + UIStroke (`self._box`), matrix TextLabels (`self._matrix`, 10 columnas Font.Code verdes TextTransparency 0.6). En `_step` (tras rotar):
```lua
    local t = tick()
    -- world lighting -> viewport
    self.VF.Ambient = GV.Color.fade(flags, "World_Ambient", t)
    self.VF.LightColor = flags.World_Fullbright and Color3.new(1,1,1) or Color3.fromRGB(255,255,255)
    -- chams
    if flags.ESP_Chams or flags.Local_SelfChams then
        if not self._chams then self._chams = Instance.new("Highlight"); self._chams.Parent = self.VF; table.insert(self._made, self._chams) end
        self._chams.Adornee = self.Model; self._chams.Enabled = true
        self._chams.FillColor = GV.Color.fade(flags, flags.Local_SelfChams and "Local_SelfChamsFill" or "ESP_ChamsFill", t)
        self._chams.OutlineColor = GV.Color.fade(flags, flags.Local_SelfChams and "Local_SelfChamsOutline" or "ESP_ChamsOutline", t)
    elseif self._chams then self._chams.Enabled = false end
    -- box overlay color
    if self._box then self._box.Visible = flags.ESP_Box ~= false; self._boxStroke.Color = GV.Color.fade(flags, "ESP_BoxColor", t) end
    -- matrix rain
    for i, l in ipairs(self._matrix or {}) do
        l.Position = UDim2.new(l.Position.X.Scale, 0, (l.Position.Y.Scale + dt * (0.2 + (i % 3) * 0.1)) % 1.2 - 0.2, 0)
        if math.floor(t * 8 + i) % 4 == 0 then l.Text = string.rep(string.char(48 + (i * 7) % 10) .. "\n", 8) end
    end
```
(El chams en el ViewportFrame: el Highlight se parenta al VF y adornee = clone; renderiza dentro del viewport.)

- [ ] **Step 3: Run to verify it passes** — Expected asserts chams/box PASS. Live: screenshot muestra modelo rotando + chams + matrix.

- [ ] **Step 4: Commit**

```bash
git add ui/preview.lua test/test_preview.lua
git commit -m "feat: Preview live world-lighting + chams + box overlay + matrix rain"
```

---

## Task 3: Capacidad del adapter + wiring en attach + Suite_Preview toggle

**Files:**
- Modify: `ui/adapter_primordial.lua` (`A.supportsPreview = true`)
- Modify: `schema/_helpers.lua` (`suiteRows` + `Suite_Preview`)
- Modify: `entry/attach.lua` (montar Preview si `adapter.supportsPreview`)
- Modify: `init.lua`/`build.lua` (ORDER `ui/preview.lua`)

**Interfaces:**
- Produces: `Suite_Preview` toggle (grupo "Suite"). Attach, si `adapter.supportsPreview and opts.preview~=false` → `suite._preview = GV.Preview.mount(suite)`; `suite:Unload` destruye el preview. ClaudeUI (sin `supportsPreview`) → nunca monta preview.

- [ ] **Step 1: Write the failing test** — extender `test/test_preview.lua`

```lua
-- capacidad por adapter
T.eq(GV.Adapters.primordial.supportsPreview, true, "primordial soporta preview")
T.truthy(GV.Adapters.claudeui.supportsPreview ~= true, "claudeui NO soporta preview (undetected)")
-- Suite_Preview en suiteRows
local sr = GV.SchemaHelpers.suiteRows()
local hasPv = false; for _, r in ipairs(sr) do if r.flag == "Suite_Preview" then hasPv = true end end
T.truthy(hasPv, "Suite_Preview en suiteRows")
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation**
  - `ui/adapter_primordial.lua`: agregar `A.supportsPreview = true` antes de `GV.Adapters.primordial = A`.
  - `schema/_helpers.lua` `suiteRows`: agregar `{ tab="Mundo", group="Suite", side="Left", flag="Suite_Preview", type="toggle", text="Preview (solo Primordial)", default=false }`.
  - `entry/attach.lua`: tras `for _, inst in pairs(suite.modules) do inst:Init() end`, agregar:
    ```lua
    if adapter.supportsPreview and opts.preview ~= false and GV.Preview then
        local ok, pv = pcall(function() return GV.Preview.mount(suite) end)
        if ok then suite._preview = pv end
    end
    ```
    y en `suite:Unload`, antes/después del loop de módulos: `if self._preview then pcall(function() self._preview:Unload() end) end`.
  - `init.lua`/`build.lua` ORDER: `ui/preview.lua` tras `ui/renderer.lua`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY` con todos PASS (test_preview crece).

- [ ] **Step 5: Commit**

```bash
git add ui/adapter_primordial.lua schema/_helpers.lua entry/attach.lua init.lua build.lua test/test_preview.lua
git commit -m "feat: Preview adapter capability + attach wiring + Suite_Preview toggle (ClaudeUI skipped)"
```

---

## Task 4: Demo live (Primordial preview + ClaudeUI sin instancia) + dist + regresión

**Files:**
- Create: `test/demo_preview.lua`
- Modify: `test/run_all.lua` (agregar `test_preview`)
- Regenerar `dist/Visuals.<lib>.lua`

**Interfaces:**
- Verifica: montar suite en **Primordial** → existe ventana preview (ViewportFrame en gethui) con modelo. Montar en **ClaudeUI** → NINGÚN ViewportFrame nuevo en gethui (undetected). Screenshot del preview.

- [ ] **Step 1: Write demo** — `test/demo_preview.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local build = loadstring(readfile("GUIWorkspace/build.lua"))()
build(GV, "claudeui"); build(GV, "primordial")
local function countVPF()
    local n = 0
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then for _, d in ipairs(hui:GetDescendants()) do if d:IsA("ViewportFrame") then n = n + 1 end end end
    return n
end
-- Primordial: preview montado
local ModP = loadstring(readfile("GUIWorkspace/dist/Visuals.Primordial.lua"))()
local LibP = loadstring(readfile("PrimordialUI/dist/PrimordialUI.lua"))()
local WinP = LibP:CreateWindow({ Title = "Visuals", Size = Vector2.new(834, 586) })
local before = countVPF()
local sP = ModP.Attach(LibP, WinP, {})
sP.flags.Suite_Preview = true
task.wait(0.3)
print("[TEST] primordial preview mont -> " .. ((sP._preview and sP._preview.VF and sP._preview.VF.Parent) and "PASS" or "FAIL"))
print("[TEST] primordial ViewportFrame +1 -> " .. ((countVPF() > before) and "PASS" or "FAIL"))
sP:Unload(); LibP:Unload()
-- ClaudeUI: SIN preview (undetected)
local ModC = loadstring(readfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua"))()
local LibC = loadstring(readfile("Rivals/RivalsUI.lua"))()
local WinC = LibC:CreateWindow({ Title = "Visuals", Size = Vector2.new(560, 500) })
local c0 = countVPF()
local sC = ModC.Attach(LibC, WinC, {})
task.wait(0.2)
print("[TEST] claudeui SIN preview -> " .. ((sC._preview == nil and countVPF() == c0) and "PASS" or "FAIL"))
sC:Unload(); LibC:Unload()
print("[TEST] demo_preview DONE")
```

- [ ] **Step 2: Run demo live** — Expected: primordial preview PASS + ViewportFrame+1; claudeui SIN preview PASS. Screenshot Primordial (ventana preview con char rotando + matrix).

- [ ] **Step 3: Regenerar dist** — `build(GV,"claudeui"); build(GV,"primordial")` → copiar a `dist/`.

- [ ] **Step 4: Regresión** — agregar `"test_preview"` a `run_all.lua`; correr. Expected: todos `SUMMARY p/p`, 0 FAIL/CRASH.

- [ ] **Step 5: Commit**

```bash
git add test/demo_preview.lua test/run_all.lua dist/
git commit -m "feat: Preview live demo (Primordial only) + dist regen + regression green"
```

---

## Self-Review

**Spec coverage (§D, scope reducido):** preview core ventana separada (T1) ✓, world-lighting+chams+box+matrix live (T2) ✓, adapter capability + attach + Suite_Preview + **ClaudeUI skip** (T3) ✓, demos + verificación 0-instancias ClaudeUI + dist + regresión (T4) ✓. Modelo = char local (sin baconhair, per user). ESP box = overlay representativo (Frame border con ESP_BoxColor) — no proyección perfecta dentro del VF (documentado). `ESP:RenderPreview` existe pero NO se usa aquí (Drawing screen-space no alinea con ViewportFrame; el box overlay instance-based es lo correcto para el pane Primordial).

**Placeholder scan:** sin placeholders; código real. Matrix rain = animación simple de TextLabels (no dependencia externa).

**Type consistency:** `GV.Preview.mount(suite, opts) -> {Root,VF,Cam,World,SetModel,Unload}`, `adapter.supportsPreview`, `suite._preview`, `Suite_Preview` flag, `GV.Color.fade(flags, base, t)` (mismo contrato). Attach monta preview solo si `adapter.supportsPreview` (primordial=true, claudeui ausente). Cleanup vía `suite:Unload` → `_preview:Unload`.
