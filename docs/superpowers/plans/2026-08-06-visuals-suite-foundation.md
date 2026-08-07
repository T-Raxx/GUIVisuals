# Visuals Suite Foundation (§0 Suite + §A ColorFade) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolucionar el World module a una **Visuals Suite** multi-módulo (registro + Attach que monta varios módulos sobre un flags compartido, 1 dist por lib) y agregar la infra **ColorFade** (cada color = 1 cp default + fade opcional 2º cp), retrofit a los colores de World.

**Architecture:** Módulos se auto-registran en `GV.Modules[name]={new,schema}`. `GV.Attach` crea UN flags compartido, instancia cada módulo con ese flags, concatena schemas, renderiza una vez, `Init` cada uno. ColorFade = helper de schema `CF` (expande a 3 filas) + `GV.Color.fade(flags,base,t)`. Es la fundación de ESP/Local/Preview (planes aparte).

**Tech Stack:** Luau executor, módulos `return function(GV)`, bundler a `dist/Visuals.<lib>.lua`, testing live vía `roblox-executor-mcp`.

## Global Constraints

- **Sin `require`.** Cada `.lua` = `return function(GV) ... end`.
- **Cero hooks.** Solo props de Lighting/Terrain + instancias propias.
- **Flags compartido:** un solo table para toda la suite; prefijos (`World_`/`ESP_`/`Local_`/`Suite_`) namespacian. `module.new({flags=shared})`.
- **ColorFade:** por color base `X` → flags `X` (cp), `X_Fade` (toggle), `X_2` (cp2). `Suite_FadeSpeed` global (0.1–5, default 1).
- **`Color.fade` guarda:** si `flags[X]` no es Color3 → devuelve blanco (nunca Lerp sobre nil).
- **Backward-compat:** mantener `GV.World` y `GV.Schema` como alias para no romper tests existentes.
- **Ruta workspace / MCP:** ver el plan de World (`2026-08-06-world-visuals-module.md`) — mismo Test Loop (sync robocopy → `execute-file` → `get-console-output`). Cliente reconecta con ID nuevo → re-list+set-active.

## Test Loop

Idéntico al plan de World. Sync `robocopy Escritorio\Scripts\GUIWorkspace $ws\GUIWorkspace /MIR /XD .git docs`, `execute-file` el test en `...\Potassium\workspace\GUIWorkspace\test\<t>.lua`, leer `[TEST] ... PASS/FAIL` + `SUMMARY`.

## File Structure

- Modify: `core/World.lua` — `new` acepta `opts.flags`; registrar en `GV.Modules.world`.
- Create: `core/color.lua` — `GV.Color.fade/solid`.
- Create: `schema/_helpers.lua` — `GV.CF`, `GV.pushCF`, `GV.SchemaHelpers.suiteRows`.
- Modify: `schema/world.lua` — builder + `CF` para colores + registrar `GV.Modules.world.schema`.
- Rewrite: `entry/attach.lua` — `GV.Attach` multi-módulo sobre flags compartido + suite handle.
- Modify: `init.lua` — ORDER agrega `core/color.lua` y `schema/_helpers.lua`.
- Modify: `build.lua` — ORDER + dist name `Visuals.<lib>.lua`.
- Modify: `test/test_build.lua` — nuevo dist name + suite mount.
- Create tests: `test/test_color.lua`, `test/test_helpers.lua`, `test/test_suite.lua`, `test/test_world_fade.lua`.

---

## Task 1: Flags inyectable + registro de módulo (World)

**Files:**
- Modify: `core/World.lua` (`new` + registro al final)
- Create: `test/test_suite.lua`

**Interfaces:**
- Consumes: `GV.World`.
- Produces: `World.new({flags=tbl})` usa el flags dado (compartido); default `{}`. `GV.Modules.world = { new=fn }`.

- [ ] **Step 1: Write the failing test** — `test/test_suite.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- flags compartido
local shared = {}
local w = GV.World.new({ services = T.mockServices(), flags = shared })
w:Set("World_Brightness", 5)
T.eq(shared.World_Brightness, 5, "escribe al flags compartido")
-- registro de modulo
T.truthy(GV.Modules and GV.Modules.world and type(GV.Modules.world.new) == "function", "world registrado")
local w2 = GV.Modules.world.new({ services = T.mockServices(), flags = shared })
T.eq(w2.Flags, shared, "modulo usa flags compartido")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`new` ignora `flags`; `GV.Modules` nil).

- [ ] **Step 3: Implementation** — en `core/World.lua`:

En `World.new`, cambiar la línea `Flags = {},` por:
```lua
            Flags = opts.flags or {},
```
Al final del archivo, antes de `end` (después de `GV.World = World`):
```lua
    GV.Modules = GV.Modules or {}
    GV.Modules.world = GV.Modules.world or {}
    GV.Modules.world.new = function(o) return World.new(o) end
```

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 3/3`.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_suite.lua
git commit -m "feat: World flags injection + module registry"
```

---

## Task 2: core/color.lua — ColorFade

**Files:**
- Create: `core/color.lua`, `test/test_color.lua`
- Modify: `init.lua` (ORDER)

**Interfaces:**
- Produces: `GV.Color.solid(flags,base)→Color3`, `GV.Color.fade(flags,base,t)→Color3`. Fade usa `flags[base]`, `flags[base.."_Fade"]`, `flags[base.."_2"]`, `flags.Suite_FadeSpeed`. Guarda no-Color3 → blanco.

- [ ] **Step 1: Write the failing test** — `test/test_color.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local Cc = GV.Color
local flags = { X = Color3.fromRGB(255,0,0), X_2 = Color3.fromRGB(0,0,255), Suite_FadeSpeed = 1 }
-- fade off -> c1 solido
T.eq(Cc.fade(flags, "X", 0), Color3.fromRGB(255,0,0), "fade off = c1")
-- fade on -> a t donde sin=0 (t=0) -> lerp 0.5 -> mezcla
flags.X_Fade = true
local mid = Cc.fade(flags, "X", 0)   -- sin(0)=0 -> a=0.5
T.near(mid.B, 0.5, 0.02, "fade on mezcla azul ~0.5")
-- guarda: flag no seteada -> blanco
T.eq(Cc.fade({}, "Nope", 0), Color3.new(1,1,1), "guarda nil -> blanco")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.Color` nil).

- [ ] **Step 3: Implementation** — `core/color.lua`

```lua
return function(GV)
    local Color = {}
    local WHITE = Color3.new(1, 1, 1)
    function Color.solid(flags, base)
        local c = flags[base]
        return typeof(c) == "Color3" and c or WHITE
    end
    function Color.fade(flags, base, t)
        local c1 = flags[base]
        if typeof(c1) ~= "Color3" then return WHITE end
        if not flags[base .. "_Fade"] then return c1 end
        local c2 = flags[base .. "_2"]
        if typeof(c2) ~= "Color3" then return c1 end
        local speed = flags["Suite_FadeSpeed"] or 1
        local a = (math.sin((t or tick()) * speed * math.pi * 2) + 1) / 2
        return c1:Lerp(c2, a)
    end
    GV.Color = Color
end
```
En `init.lua`, agregar `"core/color.lua"` al ORDER justo después de `"core/util.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 3/3`.

- [ ] **Step 5: Commit**

```bash
git add core/color.lua test/test_color.lua init.lua
git commit -m "feat: ColorFade core (Color.fade/solid + nil guard)"
```

---

## Task 3: schema/_helpers.lua — CF + suiteRows

**Files:**
- Create: `schema/_helpers.lua`, `test/test_helpers.lua`
- Modify: `init.lua` (ORDER — antes de `schema/world.lua`)

**Interfaces:**
- Produces: `GV.CF(spec)→{3 rows}`, `GV.pushCF(arr,spec)`, `GV.SchemaHelpers.suiteRows()→{fadeSpeed row}`. `spec = {base,text,tab,group,side,default,default2,dependsOn}`.

- [ ] **Step 1: Write the failing test** — `test/test_helpers.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local rows = GV.CF({ base = "ESP_Box", text = "Box", tab = "ESP", group = "C", side = "Left",
    default = Color3.fromRGB(1,2,3), default2 = Color3.fromRGB(4,5,6), dependsOn = "ESP_En" })
T.eq(#rows, 3, "CF expande a 3 filas")
T.eq(rows[1].flag, "ESP_Box", "fila1 cp base")
T.eq(rows[2].flag, "ESP_Box_Fade", "fila2 fade toggle")
T.eq(rows[2].type, "toggle", "fila2 es toggle")
T.eq(rows[3].flag, "ESP_Box_2", "fila3 cp2")
T.eq(rows[3].dependsOn, "ESP_Box_Fade", "cp2 dep del fade")
T.eq(rows[1].tab, "ESP", "hereda tab")
local sr = GV.SchemaHelpers.suiteRows()
T.eq(sr[1].flag, "Suite_FadeSpeed", "suiteRows tiene fade speed")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.CF` nil).

- [ ] **Step 3: Implementation** — `schema/_helpers.lua`

```lua
return function(GV)
    local H = {}
    function H.CF(spec)
        local base = spec.base
        local function row(t)
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side
            return t
        end
        return {
            row{ flag = base, type = "colorpicker", text = spec.text, default = spec.default, dependsOn = spec.dependsOn },
            row{ flag = base .. "_Fade", type = "toggle", text = (spec.text or "") .. " fade", default = false, dependsOn = spec.dependsOn },
            row{ flag = base .. "_2", type = "colorpicker", text = (spec.text or "") .. " color 2", default = spec.default2 or spec.default, dependsOn = base .. "_Fade" },
        }
    end
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end
    function H.suiteRows()
        return {
            { tab = "Mundo", group = "Suite", side = "Left", flag = "Suite_FadeSpeed", type = "slider",
                text = "Velocidad fade", min = 0.1, max = 5, default = 1, decimals = 2 },
        }
    end
    GV.SchemaHelpers = H
    GV.CF = H.CF
    GV.pushCF = H.pushCF
end
```
En `init.lua`, agregar `"schema/_helpers.lua"` al ORDER **antes** de `"schema/world.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 7/7`.

- [ ] **Step 5: Commit**

```bash
git add schema/_helpers.lua test/test_helpers.lua init.lua
git commit -m "feat: schema CF helper + suiteRows (fade speed)"
```

---

## Task 4: Retrofit schema/world.lua (builder + CF colores) + registro

**Files:**
- Rewrite: `schema/world.lua`
- Modify: `test/test_schema.lua` (contar flags nuevos)

**Interfaces:**
- Produces: `GV.Schema` (alias) + `GV.Modules.world.schema`. Colores como CF (3 flags c/u).

- [ ] **Step 1: Write the failing test** — reemplazar `test/test_schema.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Schema
T.truthy(#S > 90, "schema >90 filas (#" .. #S .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do
    if not (r.tab and r.group and r.type) then ok = false end
    if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end
end
T.truthy(ok, "filas validas + deps resueltas")
-- CF genero los flags de fade para Ambient
T.truthy(flags["World_Ambient"] and flags["World_Ambient_Fade"] and flags["World_Ambient_2"], "Ambient tiene CF (base/fade/2)")
T.truthy(GV.Modules.world.schema == S, "registrado en Modules.world.schema")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (no hay `World_Ambient_Fade`).

- [ ] **Step 3: Implementation** — reescribir `schema/world.lua` como builder. Los toggles/sliders quedan como `add{...}`; los colores pasan a `addCF{...}`. Patrón:

```lua
return function(GV)
    local C = Color3.fromRGB
    local S = {}
    local function add(r) table.insert(S, r) end
    local function addCF(spec) GV.pushCF(S, spec) end

    -- A. Lighting (toggles/sliders igual que antes)
    add{ tab="Mundo", group="Lighting", side="Left", flag="World_Enabled", type="toggle", text="Enable visuales", default=false, keybind=true, master=true }
    add{ tab="Mundo", group="Lighting", side="Left", flag="World_Fullbright", type="toggle", text="Fullbright", default=false, dependsOn="World_Enabled" }
    add{ tab="Mundo", group="Lighting", side="Left", flag="World_NoShadows", type="toggle", text="Sin sombras", default=false, dependsOn="World_Enabled" }
    addCF{ base="World_Ambient", text="Ambient", tab="Mundo", group="Lighting", side="Left", default=C(120,120,125), default2=C(96,130,255), dependsOn="World_Enabled" }
    addCF{ base="World_OutdoorAmbient", text="Outdoor ambient", tab="Mundo", group="Lighting", side="Left", default=C(120,120,125), default2=C(96,130,255), dependsOn="World_Enabled" }
    add{ tab="Mundo", group="Lighting", side="Left", flag="World_Brightness", type="slider", text="Brillo", min=0, max=10, default=3, decimals=1, dependsOn="World_Enabled" }
    -- ... (resto de sliders A igual que el schema actual)
    addCF{ base="World_ColorShiftTop", text="ColorShift Top", tab="Mundo", group="Lighting", side="Left", default=C(0,0,0), dependsOn="World_Enabled" }
    addCF{ base="World_ColorShiftBottom", text="ColorShift Bottom", tab="Mundo", group="Lighting", side="Left", default=C(0,0,0), dependsOn="World_Enabled" }
    -- ... Technology, GeoLatitude, tiempo B (igual)
    -- C. Fog: NoFog/FogStart/FogEnd add{}, FogColor -> addCF
    addCF{ base="World_FogColor", text="Color fog", tab="Mundo", group="Fog", side="Right", default=C(190,195,210), dependsOn="World_Enabled" }
    -- D. Atmosphere: toggle+sliders add{}, AtmColor/AtmDecay -> addCF (dependsOn="World_Atmosphere")
    -- E. Post-FX: TintColor -> addCF (dependsOn="World_Tint")
    -- F/G: CloudColor -> addCF (dependsOn="World_Clouds")
    -- H: WaterColor -> addCF (dependsOn="World_WaterEnable")
    -- I: WeatherColor -> addCF (dependsOn="World_Weather")
    -- ... (todas las filas no-color del schema actual se copian tal cual con add{})

    GV.Schema = S
    GV.Modules = GV.Modules or {}
    GV.Modules.world = GV.Modules.world or {}
    GV.Modules.world.schema = S
end
```

**Lista exacta de colores a convertir a `addCF`** (11): `World_Ambient`, `World_OutdoorAmbient`, `World_ColorShiftTop`, `World_ColorShiftBottom`, `World_FogColor`, `World_AtmColor`, `World_AtmDecay`, `World_TintColor`, `World_CloudColor`, `World_WaterColor`, `World_WeatherColor`. Cada uno con su `dependsOn` actual (ver schema vigente) y `default` actual; `default2` sugerido = accent `C(96,130,255)` (o el que quede lindo). **Todas las demás filas** (toggles/sliders/dropdowns/textbox) se copian idénticas del schema actual con `add{...}`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`, `#S` ~117 (95 + 11 colores × 2 filas extra = 95+22... contar: cada CF agrega 2 filas vs 1 → +22 → ~117).

- [ ] **Step 5: Commit**

```bash
git add schema/world.lua test/test_schema.lua
git commit -m "feat: retrofit World schema to CF colors + module registry"
```

---

## Task 5: Retrofit World applies (colores vía Color.fade)

**Files:**
- Modify: `core/World.lua` (`_applyLighting/_applyFog/_applyPost/_applySky/_applyWater/_applyWeather`)
- Create: `test/test_world_fade.lua`

**Interfaces:**
- Produces: cada apply lee color con `GV.Color.fade(self.Flags, base, tick())` en vez de `self:_flag(base, default)`.

- [ ] **Step 1: Write the failing test** — `test/test_world_fade.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
-- fade OFF: color = c1 (regresion)
w:Set("World_Ambient", Color3.fromRGB(20,20,20))
w:_step()
T.eq(L.Ambient, Color3.fromRGB(20,20,20), "fade off = c1 (regresion)")
-- fade ON: color oscila -> difiere de c1 en algun t
w:Set("World_Ambient_2", Color3.fromRGB(200,200,200))
w:Set("World_Ambient_Fade", true)
w:Set("Suite_FadeSpeed", 1)
-- forzar un t donde sin!=0 llamando _applyLighting con distintos tick no es control directo;
-- en su lugar chequeamos que fade produce un color != c1 puro en al menos una muestra
local diff = false
for i = 1, 8 do w:_applyLighting(); if L.Ambient ~= Color3.fromRGB(20,20,20) then diff = true break end; task.wait(0.03) end
T.truthy(diff, "fade on cambia el color en el tiempo")
w:_restoreAll()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (applies aún usan `_flag`, fade ignorado).

- [ ] **Step 3: Implementation** — en `core/World.lua`, reemplazar cada lectura de color. Ejemplos:

`_applyLighting`:
```lua
        else
            local amb = GV.Color.fade(self.Flags, "World_Ambient", tick())
            self:_set(L, "Ambient", amb)
            self:_set(L, "OutdoorAmbient", self.Flags["World_OutdoorAmbient"] ~= nil and GV.Color.fade(self.Flags, "World_OutdoorAmbient", tick()) or amb)
            ...
        end
        self:_set(L, "ColorShift_Top", GV.Color.fade(self.Flags, "World_ColorShiftTop", tick()))
        self:_set(L, "ColorShift_Bottom", GV.Color.fade(self.Flags, "World_ColorShiftBottom", tick()))
```
`_applyFog`: `FogColor` → `GV.Color.fade(self.Flags, "World_FogColor", tick())`.
`_applyFog` atmosphere: `a.Color = GV.Color.fade(self.Flags,"World_AtmColor",tick())`, `a.Decay = GV.Color.fade(self.Flags,"World_AtmDecay",tick())`.
`_applyPost`: `cc.TintColor = GV.Color.fade(self.Flags,"World_TintColor",tick())` (mantener el RainbowHue como está — es otro efecto; el fade nuevo aplica cuando RainbowHue off).
`_applySky`: `CloudColor` → fade.
`_applyWater`: `WaterColor` → fade.
`_applyWeather`: `emit.Color = ColorSequence.new(GV.Color.fade(self.Flags,"World_WeatherColor",tick()))`.

Nota: `GV` está en scope (todo `core/World.lua` es `return function(GV)`).

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 2/2`. Re-correr `test_apply_ab.lua` → sigue verde (fade off = c1).

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_world_fade.lua
git commit -m "feat: World applies read colors via Color.fade (fade-off = regression-safe)"
```

---

## Task 6: Attach multi-módulo sobre flags compartido

**Files:**
- Rewrite: `entry/attach.lua`
- Modify: `test/test_build.lua` (usar suite)

**Interfaces:**
- Consumes: `GV.Modules`, `GV.Renderer`, `GV.Adapters`, `GV.SchemaHelpers`, `GV.Profiles`.
- Produces: `GV.Attach(Library, Window, opts)→suite`. `opts.modules` (default `GV._defaultModules or {"world"}`), `opts.profile`, `opts.services`. `suite = {modules={name=inst}, flags, Unload}`. Un flags compartido; render una vez.

- [ ] **Step 1: Write the failing test** — reemplazar el cuerpo de `test/test_build.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(type(GV.Attach) == "function", "Attach expuesto")
-- fake adapter para montar sin UI real
local fake = { Tab=function(_,n) return {n=n} end, Group=function(_,n) return {n=n} end,
    Widget=function() return {} end, Depend=function() end }
GV.Adapters.__fake = fake
local suite = GV.Attach(nil, {}, { adapter = "__fake", modules = { "world" }, services = GV.T.mockServices() })
T.truthy(suite.modules.world, "suite monto world")
T.truthy(suite.flags.World_Brightness == 3, "flags compartido sembrado (Brightness 3)")
T.truthy(suite.flags.Suite_FadeSpeed == 1, "Suite_FadeSpeed sembrado")
suite:Unload()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (Attach viejo mono-módulo).

- [ ] **Step 3: Implementation** — reescribir `entry/attach.lua`

```lua
return function(GV)
    local function presetRows(bag)
        return {
            { tab = "Cielo & Clima", group = "Presets", side = "Right", type = "button", text = "Aplicar preset",
                action = function()
                    local w = bag.__suite and bag.__suite.modules.world
                    if w then w:ApplyPreset(w:Get("World_PresetSelect")) end
                end },
        }
    end

    function GV.Attach(Library, Window, opts)
        opts = opts or {}
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or "claudeui"]
        assert(adapter, "adapter no encontrado")
        local names = opts.modules or GV._defaultModules or { "world" }
        local flags = opts.flags or {}
        local bag = { Flags = flags }
        function bag:Set(k, v) self.Flags[k] = v end
        function bag:Get(k) return self.Flags[k] end
        local suite = { modules = {}, flags = flags }
        function suite:Unload()
            for _, m in pairs(self.modules) do pcall(function() m:Unload() end) end
        end
        bag.__suite = suite

        local schema = {}
        for _, r in ipairs(GV.SchemaHelpers.suiteRows()) do table.insert(schema, r) end
        for _, name in ipairs(names) do
            local def = GV.Modules[name]
            if def then
                local inst = def.new({ services = opts.services, flags = flags })
                if opts.profile and inst.UseProfile then
                    local prof = GV.Profiles[opts.profile]
                    inst:UseProfile(prof and (prof[name] or prof) or nil)
                end
                suite.modules[name] = inst
                for _, r in ipairs(def.schema or {}) do table.insert(schema, r) end
            end
        end
        if suite.modules.world then
            for _, r in ipairs(presetRows(bag)) do table.insert(schema, r) end
        end
        GV.Renderer.build(adapter, Window, schema, bag)
        for _, inst in pairs(suite.modules) do inst:Init() end
        return suite
    end
end
```

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add entry/attach.lua test/test_build.lua
git commit -m "feat: multi-module Attach over shared flags + suite handle"
```

---

## Task 7: Bundler → dist/Visuals.<lib>.lua + smoke live ambas UIs

**Files:**
- Modify: `build.lua` (ORDER + dist name)
- Create: `test/demo_suite.lua`

**Interfaces:**
- Produces: `dist/Visuals.ClaudeUI.lua` + `dist/Visuals.Primordial.lua` self-contained; `.Attach(Lib,Window,opts)` monta la suite (world) con ColorFade.

- [ ] **Step 1: Update `build.lua`** — en el ORDER agregar `"core/color.lua"` (tras util) y `"schema/_helpers.lua"` (antes de schema/world); cambiar el dist name:

```lua
    local ORDER = {
        "core/util.lua", "core/color.lua", "core/World.lua", "ui/facade.lua", "ui/renderer.lua",
        target == "primordial" and "ui/adapter_primordial.lua" or "ui/adapter_claudeui.lua",
        "schema/_helpers.lua", "schema/world.lua", "games/rivals.lua", "games/_template.lua", "entry/attach.lua",
    }
    ...
    local name = target == "primordial" and "Visuals.Primordial.lua" or "Visuals.ClaudeUI.lua"
```
(Opcional: setear `GV._defaultModules = {"world"}` en el footer del bundle, o dejar el default en Attach.)

- [ ] **Step 2: Write demo** — `test/demo_suite.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local build = loadstring(readfile("GUIWorkspace/build.lua"))()
build(GV, "claudeui"); build(GV, "primordial")
print("[TEST] dist visuals: claudeui=" .. tostring(isfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua")) .. " primordial=" .. tostring(isfile("GUIWorkspace/dist/Visuals.Primordial.lua")))
-- montar claudeui + verificar fade anima Ambient
local Mod = loadstring(readfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua"))()
local Lib = loadstring(readfile("Rivals/RivalsUI.lua"))()
local Win = Lib:CreateWindow({ Title = "Visuals", Size = Vector2.new(560, 500) })
local suite = Mod.Attach(Lib, Win, { profile = "rivals" })
suite.flags.World_Enabled = true
suite.flags.World_Ambient = Color3.fromRGB(255,0,0)
suite.flags.World_Ambient_2 = Color3.fromRGB(0,0,255)
suite.flags.World_Ambient_Fade = true
task.wait(0.5)
local a1 = game:GetService("Lighting").Ambient
task.wait(0.4)
local a2 = game:GetService("Lighting").Ambient
print("[TEST] fade anima Ambient -> " .. ((a1 ~= a2) and "PASS" or "FAIL"))
suite:Unload(); Lib:Unload()
print("[TEST] demo_suite DONE")
```

- [ ] **Step 3: Run demo live** — sync (+ Rivals/PrimordialUI ya sincronizados). `execute-file` demo_suite.lua. Expected: ambos dist existen, `fade anima Ambient PASS`, unload limpio. Iterar hasta limpio.

- [ ] **Step 4: Copiar dist al repo**

```bash
WS="$LOCALAPPDATA/Potassium/workspace/GUIWorkspace"
cp "$WS/dist/Visuals.ClaudeUI.lua" "$WS/dist/Visuals.Primordial.lua" dist/
# (opcional) git rm dist/World.ClaudeUI.lua dist/World.Primordial.lua  # supersedidos
```

- [ ] **Step 5: Commit**

```bash
git add build.lua test/demo_suite.lua dist/
git commit -m "feat: bundler -> Visuals.<lib>.lua suite dist + live fade demo"
```

---

## Task 8: Regresión completa + runner

**Files:**
- Modify: `test/run_all.lua` (agregar los tests nuevos)

- [ ] **Step 1: Agregar** a la lista de `files` en `test/run_all.lua`: `"test_suite"`, `"test_color"`, `"test_helpers"`, `"test_world_fade"`. (test_schema/test_build ya están.)

- [ ] **Step 2: Run** `run_all.lua` live. Expected: todos los archivos `SUMMARY p/p` (p==n), 0 FAIL/CRASH. Verificar que los tests de World viejos (`test_apply_*`) siguen verdes (fade-off = regresión).

- [ ] **Step 3: Commit**

```bash
git add test/run_all.lua
git commit -m "test: regression runner covers suite + colorfade"
```

---

## Self-Review

**Spec coverage:** §0 suite (module registry T1, multi-module Attach T6, dist Visuals T7) ✓. §A ColorFade (Color.fade T2, CF helper T3, Suite_FadeSpeed T3/T6, retrofit World schema T4 + applies T5) ✓. Testing (cada task + regresión T8) ✓. Fases B/C/D = planes aparte (fuera de este plan, por diseño).

**Placeholder scan:** sin TBD/TODO. El único punto "copiar filas idénticas del schema actual" en T4 es explícito con la lista exacta de 11 colores a convertir y la instrucción de copiar el resto tal cual (el schema vigente es la fuente).

**Type consistency:** `World.new({flags})`, `GV.Modules.world.{new,schema}`, `GV.Color.fade(flags,base,t)`, `GV.CF(spec)→3 rows`, `GV.Attach(...)→suite{modules,flags,Unload}`, `bag{Flags,Set,Get}` consistentes entre T1–T8. `Color.fade` lee `base`/`base_Fade`/`base_2`/`Suite_FadeSpeed` = mismos flags que `CF` genera (T3) y que el retrofit siembra (T4). El renderer recibe `bag` (tiene `:Set` y `.Flags`) igual que antes recibía `world`.
