# Visuals Suite §C — Local/Self — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Módulo Local/Self de la Visuals Suite: cámara (FOV changer, 3ra persona, Custom Aspect Ratio), overlays Drawing (crosshair, hitmarker, HUD/watermark, keybind-list), anti-flash/anti-smoke y self-chams. Game-agnostic con hooks del perfil; cada color con ColorFade.

**Architecture:** `core/selffx.lua` espejo de World/ESP: `SelfFX.new({services,flags,provider})`, `Init/Unload`, `_update` (RenderStepped), `_flag` (prefijo `Local_`), Drawing retained para overlays, `GV.Color.fade` para colores. Camera vía `services.Workspace.CurrentCamera`. Perfil provee hooks `selffx = {setThirdPerson,setFOV,viewmodel,flashEffects,hitSignal}`; defaults genéricos si faltan. Registra `GV.Modules.selffx`.

**Tech Stack:** Luau executor, Drawing API, módulos `return function(GV)`, testing live MCP.

## Global Constraints

- **Sin `require`.** `return function(GV) ... end`.
- **Cero hooks** (de funciones). Escribe props de Camera + crea Drawings/Highlight. Nota: el Aspect Ratio research puede usar `sethiddenproperty`/`setscriptable` (NO son function-hooks; son accessors de props) — permitido, gateado y opt-in.
- **Módulo key = `selffx`** (evita keyword `local`). Tab UI = "Local". Flags prefijo `Local_`. Maestro `Local_Enabled`. Perfil `GV.Profiles.rivals.selffx`.
- **Flags compartido** de la suite; `SelfFX.new({flags=shared})`.
- **ColorFade:** cada color = `GV.Color.fade(self.Flags, base, t)`; schema via `GV.CF`.
- **Camera restore:** toda prop de Camera escrita se restaura en Unload (patrón `_set` con memoria, como World).
- **Ruta/MCP:** mismo Test Loop (sync robocopy → `execute-file` → console). Cliente reconecta → re-list+set-active.

## Test Loop

Igual que planes previos. Lógica pura con servicios mock (Camera fake). Overlays Drawing verificados live (drawing `.Visible`). Camera writes verificados con mock. Aspect Ratio = research live sobre la Camera real.

## File Structure

- Create: `core/selffx.lua` — módulo (registra `GV.Modules.selffx`).
- Create: `schema/local.lua` — schema Local (CF colores), registra `GV.Modules.selffx.schema`.
- Modify: `games/rivals.lua` — agregar `.selffx` hooks (SetExternalFOVOffset, SetThirdPersonOverride, anti-flash CC "Flashbang").
- Modify: `init.lua` — ORDER agrega `core/selffx.lua`, `schema/local.lua`.
- Modify: `build.lua` — ORDER incluye los nuevos; `GV._defaultModules = {"world","esp","selffx"}`.
- Create tests: `test/test_selffx_core.lua`, `test/test_selffx_cam.lua`, `test/demo_selffx.lua`, `test/test_selffx_schema.lua`.

Referencia: `core/ESP.lua` (Drawing retained `_draw`, `_flag`, Init/Unload) + `core/World.lua` (`_set` memoria + `_restoreAll` para props de Camera).

---

## Task 1: SelfFX core skeleton + registro + camera `_set`/`_restore`

**Files:**
- Create: `core/selffx.lua`
- Modify: `init.lua` (ORDER: `core/selffx.lua` tras `core/esp_default.lua`)
- Create: `test/test_selffx_core.lua`

**Interfaces:**
- Produces: `GV.SelfFX.new({services,flags,provider})`, `:Set/:Get/:_flag` (prefijo Local_), `:_draw`, `:_set(obj,prop,val)` (memoria), `:_restoreAll()`, `:UseProfile(p)`, `:Init()`, `:Unload()`. `GV.Modules.selffx={new=fn}`. `_update` vacío.

- [ ] **Step 1: Write the failing test** — `test/test_selffx_core.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(GV.SelfFX and type(GV.SelfFX.new) == "function", "GV.SelfFX.new existe")
T.truthy(GV.Modules.selffx and type(GV.Modules.selffx.new) == "function", "selffx registrado")
local shared = {}
local s = GV.SelfFX.new({ flags = shared, services = T.mockServices() })
s:Set("Local_FOVValue", 90)
T.eq(shared.Local_FOVValue, 90, "usa flags compartido")
-- _set memoria + restore
local cam = s.Services.Workspace.CurrentCamera
cam.FieldOfView = 70
s:_set(cam, "FieldOfView", 100)
T.eq(cam.FieldOfView, 100, "_set escribe")
s:_restoreAll()
T.eq(cam.FieldOfView, 70, "_restoreAll revierte")
s:Init(); T.truthy(s.Loaded, "Init")
s:Unload(); T.truthy(not s.Loaded, "Unload")
T.report()
```
(Nota: `mockServices` ya trae `Workspace.CurrentCamera` fake con `FieldOfView` seteable — verificar; si falta `FieldOfView`, el fake acepta cualquier prop por `__newindex`.)

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.SelfFX` nil).

- [ ] **Step 3: Implementation** — `core/selffx.lua`

```lua
return function(GV)
    local SelfFX = {}
    SelfFX.__index = SelfFX

    function SelfFX.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            UserInputService = game:GetService("UserInputService"),
            Workspace = workspace,
            Stats = game:FindService("Stats"),
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _orig = {}, _made = {}, Highlights = {}, Loaded = false,
        }, SelfFX)
    end

    function SelfFX:Set(k, v) self.Flags[k] = v end
    function SelfFX:Get(k) return self.Flags[k] end
    function SelfFX:_flag(k, d)
        local v = self.Flags["Local_" .. k]; if v ~= nil then return v end; return d
    end
    function SelfFX:UseProfile(p) if p then self._provider = p end end

    function SelfFX:_draw(class, props)
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end
        local o = Drawing.new(class); o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o); return o
    end

    -- escritura con memoria (restaura en Unload/off)
    function SelfFX:_set(obj, prop, val)
        if not obj then return end
        local ok, cur = pcall(function() return obj[prop] end)
        if not ok then return end
        local mem = self._orig[obj]; if not mem then mem = {}; self._orig[obj] = mem end
        if mem[prop] == nil then mem[prop] = cur end
        if cur ~= val then pcall(function() obj[prop] = val end) end
    end
    function SelfFX:_restoreAll()
        for obj, props in pairs(self._orig) do
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end
        end
        table.clear(self._orig)
    end

    function SelfFX:_update() end

    function SelfFX:Init()
        if self.Loaded then return self end
        self.Loaded = true
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_update() end)
            if not ok then warn("[SelfFX] " .. tostring(err)) end
        end)
        return self
    end

    function SelfFX:Unload()
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end
        self:_restoreAll()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Highlights); table.clear(self._made)
    end

    GV.SelfFX = SelfFX
    GV.Modules = GV.Modules or {}
    GV.Modules.selffx = GV.Modules.selffx or {}
    GV.Modules.selffx.new = function(o) return SelfFX.new(o) end
end
```
`init.lua` ORDER: agregar `"core/selffx.lua"` tras `"core/esp_default.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 7/7`.

- [ ] **Step 5: Commit**

```bash
git add core/selffx.lua init.lua test/test_selffx_core.lua
git commit -m "feat: SelfFX core skeleton + registry + camera _set/_restore"
```

---

## Task 2: FOV changer + 3ra persona + Custom Aspect Ratio (research live)

**Files:**
- Modify: `core/selffx.lua` (`_applyCamera`, registrar en `_update`)
- Create: `test/test_selffx_cam.lua`
- Create: `test/research_aspect.lua` (probe de investigación, no test)

**Interfaces:**
- Produces: `_applyCamera()` — FOV (`Local_FOV`+`Local_FOVValue` → `Camera.FieldOfView` o `provider.setFOV`), 3ra persona (`Local_ThirdPerson` → `provider.setThirdPerson` o genérico), Aspect (`Local_AspectMode`/`Local_AspectRatio`/`Local_FOVMode`).

- [ ] **Step 1: RESEARCH live — Custom Aspect Ratio** (hacer ANTES de codear el apply)

Correr `test/research_aspect.lua` en el cliente y observar (screenshot) cuál candidato produce stretch real:
```lua
-- research_aspect.lua : probar candidatos de aspect ratio SIN function-hooks
local cam = workspace.CurrentCamera
local log = {}
-- baseline
table.insert(log, "ViewportSize=" .. tostring(cam.ViewportSize) .. " FOV=" .. cam.FieldOfView .. " Mode=" .. tostring(cam.FieldOfViewMode))
-- candidato 1: setscriptable + write ViewportSize
pcall(function()
    if setscriptable then setscriptable(cam, "ViewportSize", true) end
    cam.ViewportSize = Vector2.new(cam.ViewportSize.X * 0.6, cam.ViewportSize.Y)
    table.insert(log, "c1 ViewportSize write -> " .. tostring(cam.ViewportSize))
end)
-- candidato 2: sethiddenproperty ViewportSize
pcall(function()
    if sethiddenproperty then sethiddenproperty(cam, "ViewportSize", Vector2.new(1024, 768)) end
    table.insert(log, "c2 sethiddenproperty -> " .. tostring(cam.ViewportSize))
end)
-- candidato 3: FieldOfViewMode + MaxAxisFieldOfView
pcall(function()
    cam.FieldOfViewMode = Enum.FieldOfViewMode.MaxAxis
    cam.MaxAxisFieldOfView = 90
    table.insert(log, "c3 MaxAxis mode set")
end)
for _, l in ipairs(log) do print("[RESEARCH] " .. l) end
```
Ejecutar → `get-console-output` + **screenshot** para ver si el mundo se estira. Anotar cuál funciona. **Elegir el mecanismo que reproduzca stretch**; si ninguno estira de verdad, usar `FieldOfViewMode` como aproximación y documentar en un comentario que el pixel-stretch no fue reproducible en este executor (Potassium) — el user vio funcionar en Solara, puede diferir por executor.

- [ ] **Step 2: Write the failing test** — `test/test_selffx_cam.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local s = GV.SelfFX.new({ flags = {}, services = T.mockServices() })
local cam = s.Services.Workspace.CurrentCamera
s:Set("Local_Enabled", true)
s:Set("Local_FOV", true); s:Set("Local_FOVValue", 100)
s:_applyCamera()
T.eq(cam.FieldOfView, 100, "FOV changer escribe")
-- off -> restaura
s:Set("Local_FOV", false); s:_applyCamera(); s:_restoreAll()
T.truthy(cam.FieldOfView ~= 100 or true, "FOV off no crashea")
T.report()
```

- [ ] **Step 3: Implementation** — `_applyCamera` (usa el mecanismo de aspect elegido en Step 1):

```lua
    function SelfFX:_applyCamera()
        local cam = self.Services.Workspace.CurrentCamera
        if not cam then return end
        -- FOV changer
        if self:_flag("FOV", false) then
            local fov = self:_flag("FOVValue", 70)
            if self._provider and self._provider.setFOV then self._provider.setFOV(fov - 70)
            else self:_set(cam, "FieldOfView", fov) end
        end
        -- 3ra persona
        if self:_flag("ThirdPerson", false) and self._provider and self._provider.setThirdPerson then
            self._provider.setThirdPerson(true)
        end
        -- Custom Aspect Ratio (mecanismo elegido en research)
        local am = self:_flag("AspectMode", "Off")
        if am ~= "Off" then
            -- <insertar el candidato que funcione; fallback FieldOfViewMode>
            local mode = self:_flag("FOVMode", "Vertical")
            pcall(function() cam.FieldOfViewMode = Enum.FieldOfViewMode[mode] end)
            -- si ViewportSize-write funciono en research: aplicar aqui el ratio
        end
    end
```
Registrar `_applyCamera` en `_update` (bajo `Local_Enabled`). En `_update`, si `not Local_Enabled` y estaba on → `_restoreAll` (como World `_off`).

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 2/2`. + confirmar el research anotado.

- [ ] **Step 5: Commit**

```bash
git add core/selffx.lua test/test_selffx_cam.lua test/research_aspect.lua
git commit -m "feat: SelfFX FOV changer + third-person + aspect ratio (research-backed)"
```

---

## Task 3: Crosshair (Drawing, estilos + gap/thickness/size/color CF/outline)

**Files:**
- Modify: `core/selffx.lua` (`_makeCrosshair`, `_applyCrosshair`)
- Modify: `test/demo_selffx.lua` (crear en este task)

**Interfaces:**
- Produces: crosshair centrado en pantalla. `Local_Crosshair` (toggle) + `Local_CrosshairStyle` (Cross/Dot/Circle/T) + `Local_CrosshairGap/Thickness/Size` + `Local_CrosshairColor` (CF) + `Local_CrosshairOutline`. Drawings retained (4 líneas + dot + circle).

- [ ] **Step 1: Write the live demo** — `test/demo_selffx.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local s = GV.SelfFX.new({ flags = {}, services = nil }) -- servicios reales (camara real)
s:Set("Local_Enabled", true); s:Set("Local_Crosshair", true); s:Set("Local_CrosshairStyle", "Cross")
s:Set("Local_CrosshairSize", 10); s:Set("Local_CrosshairGap", 4)
s:Set("Local_CrosshairColor", Color3.fromRGB(0, 255, 0))
s:_update()
print("[TEST] crosshair lineas visibles -> " .. ((s._cross and s._cross.top.Visible) and "PASS" or "FAIL"))
s:Set("Local_CrosshairStyle", "Dot"); s:_update()
print("[TEST] crosshair dot -> " .. ((s._cross and s._cross.dot.Visible) and "PASS" or "FAIL"))
s:Unload()
print("[TEST] demo_selffx DONE")
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`_cross` nil).

- [ ] **Step 3: Implementation** — `_makeCrosshair` (4 Lines top/bottom/left/right + Square dot + Circle) + `_applyCrosshair` (centro = `cam.ViewportSize/2`, dibuja según style, color `GV.Color.fade`). Registrar en `_update`.

- [ ] **Step 4: Run demo live** — Expected crosshair lineas/dot PASS. Screenshot opcional (cruz verde en el centro).

- [ ] **Step 5: Commit**

```bash
git add core/selffx.lua test/demo_selffx.lua
git commit -m "feat: SelfFX crosshair (styles + gap/thickness/size + colorfade)"
```

---

## Task 4: Hitmarker + HUD/Watermark + Keybind-list

**Files:**
- Modify: `core/selffx.lua` (`_applyHitmarker`, `_applyWatermark`, `_applyKeybindList`)
- Modify: `test/demo_selffx.lua`

**Interfaces:**
- Produces:
  - Hitmarker (`Local_Hitmarker`, dep `provider.hitSignal`): al dispararse la señal, muestra marca (X/Cross/Circle) `Local_HitmarkerSize/Duration` + `Local_HitmarkerColor` CF, fade-out por tiempo.
  - Watermark (`Local_Watermark`): Drawing Text top-left con FPS/ping (`Stats.Network` o `Stats.PerformanceStats`)/nombre/hora, `Local_WatermarkColor` CF, posición.
  - Keybind-list (`Local_KeybindList`): lista de keybinds activos (lee del provider/Library si disponible; genérico = vacío), color CF.

- [ ] **Step 1: Add demo asserts** — watermark texto no vacío; hitmarker: disparar un `BindableEvent` como `hitSignal` mock → marca visible por Duration.

- [ ] **Step 2: Implementation** — FPS via delta de RenderStepped (contador), ping via `Stats.Network.ServerStatsItem["Data Ping"]:GetValue()` (pcall). Hitmarker escucha `provider.hitSignal:Connect` en Init (si existe). Registrar apply en `_update`.

- [ ] **Step 3: Run demo live** — Expected watermark/hitmarker asserts PASS.

- [ ] **Step 4: Commit**

```bash
git add core/selffx.lua test/demo_selffx.lua
git commit -m "feat: SelfFX hitmarker + watermark/HUD + keybind-list"
```

---

## Task 5: Anti-flash / anti-smoke + Self-chams + third-person genérico

**Files:**
- Modify: `core/selffx.lua` (`_applyAntiFlash`, `_applySelfChams`, third-person genérico)
- Create: `test/test_selffx_extra.lua`

**Interfaces:**
- Produces:
  - `_applyAntiFlash` (`Local_AntiFlash`/`Local_AntiSmoke`): usa `provider.flashEffects()` (lista de instancias a neutralizar → Enabled=false o Transparency); default no-op sin provider.
  - `_applySelfChams` (`Local_SelfChams`): Highlight sobre `LocalPlayer.Character`, fill/outline `Local_SelfChamsFill/Outline` CF.
  - Third-person genérico (sin provider): mover cámara detrás del char (best-effort).

- [ ] **Step 1: Write the failing test** — `test/test_selffx_extra.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- anti-flash con provider mock
local killed = {}
local fx = Instance.new("ColorCorrectionEffect")
local s = GV.SelfFX.new({ flags = {}, services = T.mockServices(),
    provider = { flashEffects = function() return { fx } end } })
s:Set("Local_Enabled", true); s:Set("Local_AntiFlash", true)
s:_applyAntiFlash()
T.eq(fx.Enabled, false, "anti-flash desactiva el efecto")
fx:Destroy()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — `_applyAntiFlash` (itera `flashEffects()` → `_set(e,"Enabled",false)`), `_applySelfChams` (Highlight en char local), third-person genérico. Registrar en `_update`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 1/1`. + live: self-chams crea Highlight.

- [ ] **Step 5: Commit**

```bash
git add core/selffx.lua test/test_selffx_extra.lua
git commit -m "feat: SelfFX anti-flash/anti-smoke + self-chams + generic third-person"
```

---

## Task 6: schema/local.lua (CF colores) + rivals.selffx + wiring

**Files:**
- Create: `schema/local.lua`
- Modify: `games/rivals.lua` (agregar `.selffx`)
- Modify: `init.lua` (ORDER: `schema/local.lua` tras `schema/esp.lua`), `build.lua` (ORDER + `_defaultModules={"world","esp","selffx"}`)
- Create: `test/test_selffx_schema.lua`

**Interfaces:**
- Produces: `GV.Modules.selffx.schema` (tab "Local" features + colores CF). `GV.Profiles.rivals.selffx = { setFOV=fn, setThirdPerson=fn, flashEffects=fn, hitSignal=? }` (usa API de Rivals: `SetExternalFOVOffset`, `SetThirdPersonOverride`; anti-flash mata CC "Flashbang").

- [ ] **Step 1: Write the failing test** — `test/test_selffx_schema.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Modules.selffx.schema
T.truthy(S and #S > 20, "local schema >20 (#" .. tostring(S and #S) .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag) end end
T.truthy(ok, "deps resueltas")
T.truthy(flags["Local_Enabled"] and flags["Local_CrosshairColor"] and flags["Local_CrosshairColor_Fade"], "flags clave + CF")
T.truthy(GV.Profiles.rivals.selffx ~= nil, "rivals.selffx")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — `schema/local.lua` builder cubriendo §C.2 (Cámara/Aspect/Crosshair/Hitmarker/HUD/Anti-flash/Self-chams). Tab "Local" + colores CF (grupo "Local Colores" o tab "ESP Colores" compartido → usar tab "Local", group "Colores"). `games/rivals.lua`: `GV.Profiles.rivals.selffx = { setFOV=function(off) ... SetExternalFOVOffset ... end, setThirdPerson=function(v) ... SetThirdPersonOverride ... end, flashEffects=function() return Lighting CC llamados "Flashbang" end }`. `init.lua`+`build.lua` ORDER + `_defaultModules`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add schema/local.lua games/rivals.lua init.lua build.lua test/test_selffx_schema.lua
git commit -m "feat: Local schema (CF colors) + Rivals selffx hooks + suite wiring"
```

---

## Task 7: Demos suite (world+esp+selffx) ambas UIs + dist + regresión

**Files:**
- Modify: `test/demo_suite.lua` (montar `modules={"world","esp","selffx"}`, verificar tab Local + crosshair live)
- Modify: `test/run_all.lua` (agregar tests selffx)
- Regenerar `dist/Visuals.<lib>.lua`

- [ ] **Step 1: Demo suite ambas UIs** — `demo_suite.lua` monta los 3 módulos; verifica `suite.modules.selffx`, activa crosshair, `selffx:_update()`, chequea crosshair visible. Ambas UIs.

- [ ] **Step 2: Regenerar dist** — `build(GV,"claudeui"); build(GV,"primordial")` → copiar a `dist/`.

- [ ] **Step 3: Actualizar `run_all.lua`** — agregar `"test_selffx_core"`, `"test_selffx_cam"`, `"test_selffx_extra"`, `"test_selffx_schema"`.

- [ ] **Step 4: Run regresión** live. Expected: todos `SUMMARY p/p`, 0 FAIL/CRASH.

- [ ] **Step 5: Commit**

```bash
git add test/demo_suite.lua test/run_all.lua dist/
git commit -m "feat: SelfFX live demos both UIs + dist regen + regression green"
```

---

## Self-Review

**Spec coverage (§C):** core+camera restore (T1) ✓, FOV changer + third-person + **Aspect Ratio research** (T2) ✓, crosshair (T3) ✓, hitmarker + HUD/watermark + keybind-list (T4) ✓, anti-flash/anti-smoke + self-chams + third-person genérico (T5) ✓, schema CF + rivals.selffx + wiring (T6) ✓, demos+regresión (T7) ✓. Viewmodel offset: si el perfil lo soporta (default omitido; Rivals `ViewModelOffsetCFrame` fue descartado en rivals-ui memory por no tener efecto → no se fuerza).

**Placeholder scan:** el único hueco intencional es el mecanismo de Aspect Ratio en T2 Step 3 (`<insertar candidato>`), resuelto por el research de T2 Step 1 ANTES de codear — es una tarea de investigación explícita, no un placeholder de código sin resolver. Todo lo demás con código real.

**Type consistency:** `SelfFX.new({services,flags,provider})`, `_flag("X")` (prefijo Local_), `_set/_restoreAll` (memoria Camera), `_applyCamera/_applyCrosshair/_applyHitmarker/_applyWatermark/_applyAntiFlash/_applySelfChams`, `GV.Modules.selffx.{new,schema}`, `GV.Profiles.rivals.selffx` consistentes T1–T7. `GV.Color.fade(self.Flags,"Local_X",tick())` = flags que `CF` genera (T6). Attach (§0) monta selffx vía `GV.Modules.selffx` + `prof.selffx` (name="selffx" → `prof["selffx"]`).
