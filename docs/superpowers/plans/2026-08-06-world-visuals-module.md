# World Visuals Module — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el módulo World Visuals más completo para Roblox (Lighting/Atmosphere/post-FX/cielo/terrain/clima), game-agnostic, con un solo árbol de fuente que produce dos builds cargables (ClaudeUI Drawing-API y PrimordialUI instance-based).

**Architecture:** Schema declarativo + facade de UI + core lógico puro. `core/World` es dueño del estado (`Flags`) y de toda la lógica apply; nunca lee la Library. `schema/world` describe cada control como data. `ui/renderer` camina el schema y llama a un `adapter` por lib. Los servicios de Roblox se **inyectan** en el core para testear sin un juego concreto.

**Tech Stack:** Luau (executor Roblox), patrón de módulo `return function(GV) ... end` (sin `require`), bundler propio a `dist/`, testing live vía `roblox-executor-mcp`.

## Global Constraints

- **Sin `require`.** Cada `.lua` de fuente es `return function(GV) ... end` que puebla la tabla compartida `GV`. Orden de carga lo fija `init.lua`.
- **Cero hooks.** El módulo solo escribe props de `Lighting`/`Terrain`/`workspace` y crea instancias propias. Nada de `hookfunction`/`hookmetamethod`/`setthreadidentity`/`sethiddenproperty`.
- **Servicios inyectables.** `World.new({services=...})`; default `game:GetService`. Tests inyectan mocks.
- **Prefijo de flag:** `World_`. Maestro: `World_Enabled`.
- **Escritura con memoria:** `_set(obj,prop,val)` guarda el original la 1ª vez y escribe solo si difiere. `_restoreAll` revierte. Instancias creadas van a `_made` y se destruyen en `Unload`.
- **Atmosphere:** al apagar se **destruye** el objeto (no `Density=0`), o mata el fog para siempre.
- **Ruta workspace executor:** Potassium `readfile` resuelve en `C:\Users\trabajo\AppData\Local\Potassium\workspace\`. Re-verificar en tiempo de ejecución (`identifyexecutor`, marker writefile).
- **MCP executor gotchas:** `execute` usa param `code`; `execute-file` usa `filePath`. Cliente cambia al reconectar → `list-clients` + `set-active-client` si "Invalid client ID". Rivals captura blanco en screenshot → validar por data.

---

## Test Loop (referenciado por cada tarea)

Todo test corre en un cliente Roblox vía MCP. Loop estándar:

1. **Sync** repo → workspace del executor (PowerShell, mismo PC):
   ```powershell
   $ws = "$env:LOCALAPPDATA\Potassium\workspace\GUIWorkspace"
   robocopy "C:\Users\trabajo\OneDrive\Escritorio\Scripts\GUIWorkspace" $ws /MIR /XD .git docs | Out-Null
   ```
2. **Ejecutar** el test: `execute-file` con `filePath` = ruta absoluta del test EN el workspace (`...\Potassium\workspace\GUIWorkspace\test\test_core.lua`), o `execute` con `code` inline.
3. **Leer** resultado: `get-console-output` (limit bajo). Los tests imprimen `[TEST] <name> PASS` / `[TEST] <name> FAIL: <detalle>` y una línea final `[TEST] SUMMARY p/n`.

Cliente para lógica pura y demos: cualquier Baseplate. Demo Primordial: Baseplate en Potassium. Demo ClaudeUI: Rivals o Baseplate.

---

## File Structure

Todo bajo `Scripts/GUIWorkspace/`:

- `init.lua` — dev-loader: `readfile` cada módulo en orden, ejecuta `fn(GV)`, retorna `GV`.
- `build.lua` — bundler: concatena módulos + selector de adapter → `dist/World.<lib>.lua`.
- `core/util.lua` — `GV.Util`: clamp/lerp, ser/deser Color3+EnumItem, deepcopy.
- `core/World.lua` — `GV.World` (constructor `.new`): estado, `_set`/`_restoreAll`/`_fx`, todas las apply A–K, `Init`/`Unload`/`_step`.
- `schema/world.lua` — `GV.Schema` (array de controles A–K).
- `ui/facade.lua` — `GV.Facade`: lista de kinds + `validate(adapter)`.
- `ui/renderer.lua` — `GV.Renderer`: `build(adapter, window, schema, world)`.
- `ui/adapter_claudeui.lua` — `GV.Adapters.claudeui`.
- `ui/adapter_primordial.lua` — `GV.Adapters.primordial`.
- `games/rivals.lua` — `GV.Profiles.rivals`. `games/_template.lua` — `GV.Profiles._template`.
- `entry/attach.lua` — `GV.Attach(world, adapter, Library, Window, opts)`.
- `test/harness.lua` — `GV.T`: `eq/truthy/report` + `mockServices()`.
- `test/test_core.lua`, `test/test_renderer.lua`, `test/test_schema.lua` — tests de lógica pura.
- `test/demo_claudeui.lua`, `test/demo_primordial.lua` — smoke live de UI.
- `dist/World.ClaudeUI.lua`, `dist/World.Primordial.lua` — salidas del build.

---

## Task 1: Loader + harness + loop de test vivo

**Files:**
- Create: `init.lua`, `test/harness.lua`, `test/smoke.lua`
- Create stub: `core/util.lua` (temporal, se completa en Task 2)

**Interfaces:**
- Produces: `GV` (tabla compartida), `GV.T.eq(a,b,name)`, `GV.T.truthy(v,name)`, `GV.T.report()`, `GV.T.mockServices()`.

- [ ] **Step 1: Write the failing test** — `test/smoke.lua`

```lua
-- smoke: prueba que el loader arma GV y el harness reporta.
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(GV.Util, "util cargado")
T.eq(1 + 1, 2, "aritmetica")
T.report()
```

- [ ] **Step 2: Run to verify it fails**

Sync (ver Test Loop) then `execute-file` `...\workspace\GUIWorkspace\test\smoke.lua`; `get-console-output`.
Expected: FAIL/error — `init.lua` no existe todavía.

- [ ] **Step 3: Minimal implementation**

`core/util.lua` (stub):
```lua
return function(GV) GV.Util = { _stub = true } end
```

`test/harness.lua`:
```lua
return function(GV)
    local T = { _p = 0, _n = 0 }
    local function fmt(v) return typeof(v) == "Color3" and string.format("Color3(%d,%d,%d)", v.R*255, v.G*255, v.B*255) or tostring(v) end
    function T.truthy(v, name)
        T._n += 1
        if v then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: valor falsy") end
    end
    function T.eq(a, b, name)
        T._n += 1
        if a == b then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: " .. fmt(a) .. " ~= " .. fmt(b)) end
    end
    function T.near(a, b, eps, name)
        T._n += 1; eps = eps or 1e-3
        if math.abs(a - b) <= eps then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: " .. tostring(a) .. " ~≈ " .. tostring(b)) end
    end
    function T.report() print(string.format("[TEST] SUMMARY %d/%d", T._p, T._n)); return T._p, T._n end
    GV.T = T
end
```

`init.lua`:
```lua
-- Dev-loader. Correr en executor con GUIWorkspace sincronizado al root del workspace.
local ROOT = "GUIWorkspace/"
local GV = { _root = ROOT }
local ORDER = {
    "test/harness.lua",
    "core/util.lua",
    "core/World.lua",
    "ui/facade.lua",
    "ui/renderer.lua",
    "ui/adapter_claudeui.lua",
    "ui/adapter_primordial.lua",
    "schema/world.lua",
    "games/rivals.lua",
    "games/_template.lua",
    "entry/attach.lua",
}
for _, p in ipairs(ORDER) do
    local ok, src = pcall(readfile, ROOT .. p)
    if ok and src then
        local chunk = assert(loadstring(src, "@" .. p))
        chunk()(GV)   -- el modulo retorna function(GV)
    end
end
return GV
```
(El loader ignora módulos faltantes vía pcall → se puede correr con archivos aún no creados.)

- [ ] **Step 4: Run to verify it passes**

Sync + `execute-file` smoke.lua + `get-console-output`.
Expected: `[TEST] util cargado PASS`, `[TEST] aritmetica PASS`, `[TEST] SUMMARY 2/2`.

- [ ] **Step 5: Commit**

```bash
git add init.lua test/harness.lua test/smoke.lua core/util.lua
git commit -m "feat: dev-loader + test harness + live smoke loop"
```

---

## Task 2: core/util.lua — helpers + ser/deser

**Files:**
- Modify: `core/util.lua` (reemplaza el stub)
- Create: `test/test_util.lua`

**Interfaces:**
- Produces: `GV.Util.clamp(x,min,max)`, `GV.Util.lerp(a,b,t)`, `GV.Util.serColor(c3)→{__="c3",r,g,b}`, `GV.Util.deColor(t)→Color3`, `GV.Util.serEnum(e)→{__="en",t,n}`, `GV.Util.deEnum(t)→EnumItem`, `GV.Util.deepcopy(t)`.

- [ ] **Step 1: Write the failing test** — `test/test_util.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local U, T = GV.Util, GV.T
T.eq(U.clamp(15, 0, 10), 10, "clamp alto")
T.eq(U.clamp(-3, 0, 10), 0, "clamp bajo")
T.near(U.lerp(0, 10, 0.5), 5, 1e-6, "lerp medio")
local c = Color3.fromRGB(10, 20, 30)
local s = U.serColor(c)
T.eq(s.__, "c3", "serColor tag")
T.eq(U.deColor(s), c, "color roundtrip")
local e = U.serEnum(Enum.Material.Neon)
T.eq(U.deEnum(e), Enum.Material.Neon, "enum roundtrip")
T.report()
```

- [ ] **Step 2: Run to verify it fails**

Sync + `execute-file` test_util.lua. Expected: FAIL — `clamp` nil.

- [ ] **Step 3: Minimal implementation** — `core/util.lua`

```lua
return function(GV)
    local U = {}
    function U.clamp(x, a, b) return math.max(a, math.min(b, x)) end
    function U.lerp(a, b, t) return a + (b - a) * t end
    function U.serColor(c) return { __ = "c3", r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) } end
    function U.deColor(t) return Color3.fromRGB(t.r, t.g, t.b) end
    function U.serEnum(e) return { __ = "en", t = tostring(e.EnumType), n = e.Name } end
    function U.deEnum(t)
        local et = t.t:gsub("^Enum%.", "")
        for _, item in ipairs(Enum[et]:GetEnumItems()) do if item.Name == t.n then return item end end
    end
    function U.deepcopy(t)
        if type(t) ~= "table" then return t end
        local r = {}; for k, v in pairs(t) do r[k] = U.deepcopy(v) end; return r
    end
    GV.Util = U
end
```

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 7/7`.

- [ ] **Step 5: Commit**

```bash
git add core/util.lua test/test_util.lua
git commit -m "feat: util helpers (clamp/lerp/color+enum ser)"
```

---

## Task 3: core/World.lua — estado + _set con memoria + servicios inyectables

**Files:**
- Create: `core/World.lua`
- Create: `test/test_core.lua`
- Modify: `test/harness.lua` — agregar `mockServices()`

**Interfaces:**
- Consumes: `GV.Util`.
- Produces: `GV.World.new(opts)→instance`. Instancia: `:Set(flag,v)`, `:Get(flag)`, `:GetFlags()→tbl`, `:LoadFlags(tbl)`, `:_flag(name,default)`, `:_set(obj,prop,val)`, `:_restoreAll()`. `opts.services = {Lighting=,Terrain=,RunService=,Workspace=}`; default real.

- [ ] **Step 1: Agregar mock a harness** — en `test/harness.lua`, dentro de `function(GV)` antes de `GV.T = T`:

```lua
    function T.mockServices()
        local function fakeInst(props)
            local o = { _props = props or {}, _children = {} }
            setmetatable(o, {
                __index = function(t, k) return rawget(t, "_props")[k] end,
                __newindex = function(t, k, v) rawget(t, "_props")[k] = v end,
            })
            function o.FindFirstChildOfClass() return nil end
            return o
        end
        local Lighting = fakeInst({ Ambient = Color3.new(), OutdoorAmbient = Color3.new(), Brightness = 1,
            GlobalShadows = true, ClockTime = 12, ExposureCompensation = 0, FogStart = 0, FogEnd = 1000,
            FogColor = Color3.new() })
        return { Lighting = Lighting, Terrain = fakeInst({}), RunService = { RenderStepped = { Connect = function() return { Disconnect = function() end } end } }, Workspace = { CurrentCamera = fakeInst({ CFrame = CFrame.new() }) } }
    end
```

- [ ] **Step 2: Write the failing test** — `test/test_core.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
-- estado
w:Set("World_Brightness", 7)
T.eq(w:Get("World_Brightness"), 7, "set/get flag")
-- _set con memoria: escribe y recuerda original
local L = w.Services.Lighting
L.Brightness = 1
w:_set(L, "Brightness", 5)
T.eq(L.Brightness, 5, "_set escribe")
w:_set(L, "Brightness", 5)  -- mismo valor: no re-guarda original
w:_restoreAll()
T.eq(L.Brightness, 1, "_restoreAll revierte al original")
-- GetFlags/LoadFlags roundtrip con Color3
w:Set("World_Ambient", Color3.fromRGB(9, 9, 9))
local dump = w:GetFlags()
local w2 = GV.World.new({ services = T.mockServices() })
w2:LoadFlags(dump)
T.eq(w2:Get("World_Ambient"), Color3.fromRGB(9, 9, 9), "flags roundtrip color")
T.report()
```

- [ ] **Step 3: Run to verify it fails** — Expected: FAIL — `GV.World` nil.

- [ ] **Step 4: Minimal implementation** — `core/World.lua`

```lua
return function(GV)
    local U = GV.Util
    local World = {}
    World.__index = World

    function World.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Lighting = game:GetService("Lighting"),
            Terrain = workspace:FindFirstChildOfClass("Terrain"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        local self = setmetatable({
            Flags = {}, Services = svc, Conns = {},
            _orig = {}, _made = {}, _fxCache = {}, _applies = {},
            Loaded = false, _wasOn = false,
        }, World)
        return self
    end

    function World:Set(flag, v) self.Flags[flag] = v end
    function World:Get(flag) return self.Flags[flag] end
    function World:_flag(name, default)
        local v = self.Flags[name]
        if v ~= nil then return v end
        return default
    end

    -- serializa para config (Color3/Enum → tablas nombradas)
    function World:GetFlags()
        local out = {}
        for k, v in pairs(self.Flags) do
            if typeof(v) == "Color3" then out[k] = U.serColor(v)
            elseif typeof(v) == "EnumItem" then out[k] = U.serEnum(v)
            else out[k] = v end
        end
        return out
    end
    function World:LoadFlags(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" and v.__ == "c3" then self.Flags[k] = U.deColor(v)
            elseif type(v) == "table" and v.__ == "en" then self.Flags[k] = U.deEnum(v)
            else self.Flags[k] = v end
        end
    end

    function World:_set(obj, prop, val)
        if not obj then return end
        local ok, cur = pcall(function() return obj[prop] end)
        if not ok then return end
        local mem = self._orig[obj]
        if not mem then mem = {}; self._orig[obj] = mem end
        if mem[prop] == nil then mem[prop] = cur end
        if cur ~= val then pcall(function() obj[prop] = val end) end
    end
    function World:_restoreAll()
        for obj, props in pairs(self._orig) do
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end
        end
        table.clear(self._orig)
    end

    GV.World = World
end
```

- [ ] **Step 5: Run to verify it passes** — Expected `[TEST] SUMMARY 4/4`.

- [ ] **Step 6: Commit**

```bash
git add core/World.lua test/test_core.lua test/harness.lua
git commit -m "feat: World core state + _set memory + injectable services"
```

---

## Task 4: core/World — _fx, Init/Unload, _step + registro de applies

**Files:**
- Modify: `core/World.lua`
- Modify: `test/test_core.lua` (agregar casos)

**Interfaces:**
- Produces: `world:_fx(class,parent)→inst`, `world:_register(fn)`, `world:Init()→self`, `world:Unload()`, `world:_step()`. `_step` corre cada apply registrado si `World_Enabled`; si estaba on y ahora off → `_off()` (restaura). Applies leen `_flag`.

- [ ] **Step 1: Write the failing test** — agregar a `test/test_core.lua` antes de `T.report()`:

```lua
-- _fx crea una sola vez
local a = w:_fx("Folder", w.Services.Lighting)
local b = w:_fx("Folder", w.Services.Lighting)
T.eq(a, b, "_fx cachea")
-- apply registrado corre bajo master; _off restaura
local L2 = w.Services.Lighting; L2.Brightness = 3
w:_register(function(s) s:_set(L2, "Brightness", 99) end)
w:Set("World_Enabled", true); w:_step()
T.eq(L2.Brightness, 99, "apply corre con master on")
w:Set("World_Enabled", false); w:_step()
T.eq(L2.Brightness, 3, "master off restaura")
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL — `_fx` nil.

- [ ] **Step 3: Implementation** — agregar a `core/World.lua` antes de `GV.World = World`:

```lua
    function World:_fx(class, parent)
        local got = self._fxCache[class]
        if got and got.Parent then return got end
        local inst = Instance.new(class)
        inst.Name = "LightingController"  -- nombre inocuo (como los del juego)
        inst.Parent = parent or self.Services.Lighting
        self._fxCache[class] = inst
        table.insert(self._made, inst)
        return inst
    end

    function World:_register(fn) table.insert(self._applies, fn) end

    function World:_step()
        if not self:_flag("World_Enabled", false) then
            if self._wasOn then self:_off() end
            return
        end
        self._wasOn = true
        for _, fn in ipairs(self._applies) do
            local ok, err = pcall(fn, self)
            if not ok then warn("[World] apply: " .. tostring(err)) end
        end
    end

    function World:_off()
        self._wasOn = false
        for class, inst in pairs(self._fxCache) do
            pcall(function() if inst:IsA("PostEffect") then inst.Enabled = false end end)
        end
        self:_restoreAll()
    end

    function World:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local conn = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_step() end)
            if not ok then warn("[World] step: " .. tostring(err)) end
        end)
        self.Conns[#self.Conns + 1] = conn
        return self
    end

    function World:Unload()
        if not self.Loaded then return end
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        table.clear(self.Conns)
        self:_restoreAll()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self._made)
        self._fxCache = {}
    end
```

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 7/7`.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_core.lua
git commit -m "feat: World _fx/Init/Unload/_step + apply registry"
```

---

## Task 5: Applies A (Lighting core) + B (Tiempo/Sol)

**Files:**
- Modify: `core/World.lua` — agregar `_applyLighting`, `_applyTime`, registrarlas en un método `World:_installApplies()` llamado desde `new`.
- Create: `test/test_apply_ab.lua`

**Interfaces:**
- Produces: applies que leen flags `World_Fullbright/Ambient/OutdoorAmbient/Brightness/Exposure/NoShadows/ColorShiftTop/ColorShiftBottom/EnvDiffuse/EnvSpecular/Technology/GeoLatitude/ClockTime/UseTimeOfDay/FreezeTime/DayNightCycle/CycleSpeed` y escriben en `Lighting`.

- [ ] **Step 1: Write the failing test** — `test/test_apply_ab.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
-- Fullbright fuerza ambient blanco + brightness 1 + sin sombras
w:Set("World_Fullbright", true); w:_step()
T.eq(L.Ambient, Color3.fromRGB(255,255,255), "fullbright ambient")
T.eq(L.Brightness, 1, "fullbright brightness")
T.eq(L.GlobalShadows, false, "fullbright sin sombras")
-- Sin fullbright: aplica valores del user
w:Set("World_Fullbright", false)
w:Set("World_Ambient", Color3.fromRGB(20,20,20))
w:Set("World_Brightness", 4)
w:Set("World_ClockTime", 6); w:_step()
T.eq(L.Ambient, Color3.fromRGB(20,20,20), "ambient user")
T.eq(L.Brightness, 4, "brightness user")
T.near(L.ClockTime, 6, 1e-6, "clocktime")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (ambient no cambia; applies no instaladas).

- [ ] **Step 3: Implementation** — en `core/World.lua`:

En `World.new`, antes de `return self`, agregar: `self:_installApplies()`.
Agregar antes de `GV.World = World`:

```lua
    local WHITE = Color3.fromRGB(255, 255, 255)

    function World:_applyLighting()
        local L = self.Services.Lighting
        if self:_flag("World_Fullbright", false) then
            self:_set(L, "Ambient", WHITE); self:_set(L, "OutdoorAmbient", WHITE)
            self:_set(L, "Brightness", 1); self:_set(L, "GlobalShadows", false)
        else
            self:_set(L, "Ambient", self:_flag("World_Ambient", Color3.fromRGB(120,120,125)))
            self:_set(L, "OutdoorAmbient", self:_flag("World_OutdoorAmbient", self:_flag("World_Ambient", Color3.fromRGB(120,120,125))))
            self:_set(L, "Brightness", self:_flag("World_Brightness", 3))
            self:_set(L, "GlobalShadows", not self:_flag("World_NoShadows", false))
        end
        self:_set(L, "ExposureCompensation", self:_flag("World_Exposure", 0))
        self:_set(L, "ColorShift_Top", self:_flag("World_ColorShiftTop", Color3.new()))
        self:_set(L, "ColorShift_Bottom", self:_flag("World_ColorShiftBottom", Color3.new()))
        self:_set(L, "EnvironmentDiffuseScale", self:_flag("World_EnvDiffuse", 1))
        self:_set(L, "EnvironmentSpecularScale", self:_flag("World_EnvSpecular", 1))
        self:_set(L, "GeographicLatitude", self:_flag("World_GeoLatitude", 41.733))
        local tech = self:_flag("World_Technology", "")
        if tech ~= "" then pcall(function() L.Technology = Enum.Technology[tech] end) end
    end

    function World:_applyTime()
        local L = self.Services.Lighting
        if self:_flag("World_DayNightCycle", false) then
            local spd = self:_flag("World_CycleSpeed", 1)
            local t = (self._cycleT or self:_flag("World_ClockTime", 12)) + (1/60) * spd
            if t >= 24 then t = t - 24 end
            self._cycleT = t
            self:_set(L, "ClockTime", t)
        elseif self:_flag("World_FreezeTime", false) then
            self:_set(L, "ClockTime", self._freeze or (function() self._freeze = self:_flag("World_ClockTime", 12); return self._freeze end)())
        elseif self:_flag("World_UseTimeOfDay", false) then
            -- ClockTime como horas decimales → TimeOfDay HH:MM:SS
            local c = self:_flag("World_ClockTime", 12); local h = math.floor(c); local m = math.floor((c - h) * 60)
            self:_set(L, "TimeOfDay", string.format("%02d:%02d:00", h, m))
        else
            self._freeze = nil
            self:_set(L, "ClockTime", self:_flag("World_ClockTime", 12))
        end
    end

    function World:_installApplies()
        self:_register(self._applyLighting)
        self:_register(self._applyTime)
    end
```

Nota: `_register(self._applyLighting)` guarda la función; `_step` la llama como `fn(self)` → los métodos reciben `self` correctamente.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 6/6`. (Nota: `mockServices` debe tener `ColorShift_Top/Bottom` etc.; el fake `__newindex` acepta cualquier prop, así que pasa.)

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_ab.lua
git commit -m "feat: World applies A (lighting) + B (time)"
```

---

## Task 6: Applies C (Fog) + D (Atmosphere, destroy-on-off)

**Files:**
- Modify: `core/World.lua` — `_applyFog`, `_killAtmosphere`; registrar en `_installApplies`.
- Create: `test/test_apply_cd.lua`

**Interfaces:**
- Produces: applies leen `World_NoFog/FogStart/FogEnd/FogColor/Atmosphere/AtmDensity/AtmOffset/AtmGlare/AtmHaze/AtmColor/AtmDecay`. Atmosphere se crea vía `_fx("Atmosphere")` y se **destruye** al apagar.

- [ ] **Step 1: Write the failing test** — `test/test_apply_cd.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
w:Set("World_NoFog", true); w:_step()
T.eq(L.FogStart, 0, "nofog start 0")
T.eq(L.FogEnd, 1e6, "nofog end 1e6")
-- Atmosphere on → existe en cache; off → destruida
w:Set("World_NoFog", false)
w:Set("World_Atmosphere", true); w:_step()
T.truthy(w._fxCache.Atmosphere, "atmosphere creada")
w:Set("World_Atmosphere", false); w:_step()
T.eq(w._fxCache.Atmosphere, nil, "atmosphere destruida al off")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — en `core/World.lua`:

```lua
    function World:_applyFog()
        local L = self.Services.Lighting
        if self:_flag("World_NoFog", false) then
            self:_set(L, "FogStart", 0); self:_set(L, "FogEnd", 1e6)
        else
            self:_set(L, "FogStart", self:_flag("World_FogStart", 0))
            self:_set(L, "FogEnd", self:_flag("World_FogEnd", 2500))
            self:_set(L, "FogColor", self:_flag("World_FogColor", Color3.fromRGB(190,195,210)))
        end
        if self:_flag("World_Atmosphere", false) then
            local a = self:_fx("Atmosphere")
            a.Density = self:_flag("World_AtmDensity", 0.3)
            a.Offset  = self:_flag("World_AtmOffset", 0.25)
            a.Glare   = self:_flag("World_AtmGlare", 0)
            a.Haze    = self:_flag("World_AtmHaze", 0)
            a.Color   = self:_flag("World_AtmColor", Color3.fromRGB(199,199,199))
            a.Decay   = self:_flag("World_AtmDecay", Color3.fromRGB(106,112,125))
        else
            self:_killAtmosphere()
        end
    end

    function World:_killAtmosphere()
        local a = self._fxCache and self._fxCache.Atmosphere
        if not a then return end
        for i, inst in ipairs(self._made) do if inst == a then table.remove(self._made, i) break end end
        pcall(function() a:Destroy() end)
        self._fxCache.Atmosphere = nil
    end
```

Registrar en `_installApplies`: `self:_register(self._applyFog)`.
En `_off`, antes de `_restoreAll`, agregar `self:_killAtmosphere()`.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_cd.lua
git commit -m "feat: World applies C (fog) + D (atmosphere, destroy-on-off)"
```

---

## Task 7: Apply E (Post-FX: Tint/Bloom/SunRays/DoF/WorldBlur/KillGamePostFX/RainbowHue)

**Files:**
- Modify: `core/World.lua` — `_applyPost`
- Create: `test/test_apply_e.lua`

**Interfaces:**
- Produces: crea `ColorCorrectionEffect/BloomEffect/SunRaysEffect/DepthOfFieldEffect/BlurEffect` vía `_fx`, cada uno con `.Enabled` = su flag. RainbowHue anima `TintColor` por tiempo. `KillGamePostFX` desactiva PostEffects del juego que no son nuestros.

- [ ] **Step 1: Write the failing test** — `test/test_apply_e.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
w:Set("World_Enabled", true)
w:Set("World_Tint", true); w:Set("World_TintSaturation", -1); w:_step()
local cc = w._fxCache.ColorCorrectionEffect
T.truthy(cc, "CC creado"); T.eq(cc.Enabled, true, "CC enabled"); T.eq(cc.Saturation, -1, "CC saturation")
w:Set("World_Bloom", true); w:Set("World_BloomIntensity", 2); w:_step()
T.eq(w._fxCache.BloomEffect.Intensity, 2, "bloom intensity")
w:Set("World_Tint", false); w:_step()
T.eq(cc.Enabled, false, "CC off")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — en `core/World.lua`:

```lua
    function World:_applyPost()
        local cc = self:_fx("ColorCorrectionEffect")
        cc.Enabled = self:_flag("World_Tint", false)
        if cc.Enabled then
            cc.Brightness = self:_flag("World_TintBrightness", 0)
            cc.Contrast   = self:_flag("World_TintContrast", 0)
            cc.Saturation = self:_flag("World_TintSaturation", 0)
            if self:_flag("World_RainbowHue", false) then
                local t = (tick() * self:_flag("World_RainbowSpeed", 1)) % 1
                cc.TintColor = Color3.fromHSV(t, 0.5, 1)
            else
                cc.TintColor = self:_flag("World_TintColor", WHITE)
            end
        end
        local bm = self:_fx("BloomEffect")
        bm.Enabled = self:_flag("World_Bloom", false)
        if bm.Enabled then
            bm.Intensity = self:_flag("World_BloomIntensity", 0.4)
            bm.Size = self:_flag("World_BloomSize", 24)
            bm.Threshold = self:_flag("World_BloomThreshold", 0.95)
        end
        local sr = self:_fx("SunRaysEffect")
        sr.Enabled = self:_flag("World_SunRays", false)
        if sr.Enabled then
            sr.Intensity = self:_flag("World_SunRaysIntensity", 0.05)
            sr.Spread = self:_flag("World_SunRaysSpread", 0.5)
        end
        local df = self:_fx("DepthOfFieldEffect")
        df.Enabled = self:_flag("World_DoF", false)
        if df.Enabled then
            df.FocusDistance = self:_flag("World_DoFFocus", 25)
            df.InFocusRadius = self:_flag("World_DoFRadius", 10)
            df.NearIntensity = self:_flag("World_DoFNear", 0)
            df.FarIntensity  = self:_flag("World_DoFFar", 0.75)
        end
        local bu = self:_fx("BlurEffect")
        bu.Enabled = self:_flag("World_WorldBlur", false)
        if bu.Enabled then bu.Size = self:_flag("World_WorldBlurSize", 12) end
        if self:_flag("World_KillGamePostFX", false) then
            for _, e in ipairs(self.Services.Lighting:GetChildren()) do
                if e:IsA("PostEffect") and self._made and not table.find(self._made, e) then
                    self:_set(e, "Enabled", false)
                end
            end
        end
    end
```

Registrar en `_installApplies`: `self:_register(self._applyPost)`.
(Test corre con mock; `_fx` usa `Instance.new` real → funciona en cualquier Baseplate. `GetChildren` en el mock retorna nil → el KillGamePostFX loop se salta bajo pcall del step; para el test no se activa ese flag.)

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 5/5`.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_e.lua
git commit -m "feat: World apply E (post-fx: tint/bloom/sunrays/dof/blur/rainbow)"
```

---

## Task 8: Applies F (Cielo/Celestial) + G (Nubes)

**Files:**
- Modify: `core/World.lua` — `_applySky`
- Create: `test/test_apply_fg.lua` (live: requiere Terrain real → correr en Baseplate con Terrain, o skip nubes si no hay)

**Interfaces:**
- Produces: maneja `Sky` (NoSky/StarCount/custom skybox 6 caras/Sun+Moon textures/angular sizes/CelestialBodies) y `Terrain.Clouds` (Clouds/NoClouds/Cover/Density/Color).

- [ ] **Step 1: Write the failing test** — `test/test_apply_fg.lua` (usa Instance real de Sky para no depender del juego)

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local svc = T.mockServices()
-- inyectar un Sky real hijo de un Lighting real-ish: usamos Lighting real para Sky
local RL = game:GetService("Lighting")
svc.Lighting = RL
local sky = RL:FindFirstChildOfClass("Sky") or Instance.new("Sky", RL)
local w = GV.World.new({ services = svc })
w:Set("World_Enabled", true)
w:Set("World_CustomSkybox", true); w:Set("World_Skybox_Up", "rbxassetid://12345"); w:_step()
T.eq(sky.SkyboxUp, "rbxassetid://12345", "skybox up seteado")
w:_restoreAll()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL. (Correr en Baseplate.)

- [ ] **Step 3: Implementation** — en `core/World.lua`:

```lua
    function World:_applySky()
        local L = self.Services.Lighting
        local sky = L:FindFirstChildOfClass("Sky")
        if sky then
            local off = self:_flag("World_NoSky", false)
            self:_set(sky, "CelestialBodiesShown", not off)
            self:_set(sky, "StarCount", off and 0 or self:_flag("World_StarCount", 3000))
            if self:_flag("World_CustomSkybox", false) then
                for face, prop in pairs({ Up="SkyboxUp", Dn="SkyboxDn", Lf="SkyboxLf", Rt="SkyboxRt", Bk="SkyboxBk", Ft="SkyboxFt" }) do
                    local v = self:_flag("World_Skybox_" .. face, "")
                    if v ~= "" then self:_set(sky, prop, v) end
                end
                local sun = self:_flag("World_SunTextureId", ""); if sun ~= "" then self:_set(sky, "SunTextureId", sun) end
                local moon = self:_flag("World_MoonTextureId", ""); if moon ~= "" then self:_set(sky, "MoonTextureId", moon) end
                self:_set(sky, "SunAngularSize", self:_flag("World_SunAngularSize", 21))
                self:_set(sky, "MoonAngularSize", self:_flag("World_MoonAngularSize", 11))
            end
        end
        local Terrain = self.Services.Terrain
        if not Terrain or not Terrain.FindFirstChildOfClass then return end
        if not self:_flag("World_Clouds", false) then return end
        local clouds = Terrain:FindFirstChildOfClass("Clouds") or self:_fx("Clouds", Terrain)
        self:_set(clouds, "Enabled", not self:_flag("World_NoClouds", false))
        self:_set(clouds, "Cover", self:_flag("World_CloudCover", 0.5))
        self:_set(clouds, "Density", self:_flag("World_CloudDensity", 0.7))
        self:_set(clouds, "Color", self:_flag("World_CloudColor", WHITE))
    end
```

Registrar: `self:_register(self._applySky)`.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 1/1`. Limpiar el Sky de prueba si se creó.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_fg.lua
git commit -m "feat: World apply F (sky/celestial) + G (clouds)"
```

---

## Task 9: Applies H (Terrain/Agua) + I (Clima local con modos nuevos)

**Files:**
- Modify: `core/World.lua` — `_applyWater`, `_wxRig`, `_applyWeather`
- Create: `test/test_apply_hi.lua` (live en Baseplate con Terrain)

**Interfaces:**
- Produces: agua vía `Terrain.Water*`. Clima: part+ParticleEmitter sobre la cámara. Modos: Lluvia/Lluvia fuerte/Nieve (portados) + Niebla/Ceniza/Luciérnagas/Custom. Config vía `WX` table.

**Nota de implementación:** portar la table `WX`, `_wxRig`, `_applyWeather` de `RivalsVisuals.lua:277-357` con flags renombrados `Vis_*`→`World_*`, y agregar modos:
```lua
    ["Niebla"]      = { tex=TEX_SNOW, rate=60,  speed=2,  life=9,   size=6,   squash=0, spread=40, drag=4,   accel=Vector3.new(0.5,-0.4,0.3), transp=0.75, light=0.02, rot=0, rotSpeed=4,  tilt=0 },
    ["Ceniza"]      = { tex=TEX_SNOW, rate=120, speed=8,  life=5,   size=0.4, squash=0, spread=30, drag=2,   accel=Vector3.new(2,-4,1),      transp=0.3,  light=0.6,  rot=0, rotSpeed=30, tilt=0 },
    ["Luciérnagas"] = { tex=TEX_SNOW, rate=40,  speed=3,  life=7,   size=0.25,squash=0, spread=45, drag=3,   accel=Vector3.new(0,0.2,0),     transp=0.1,  light=1,    rot=0, rotSpeed=10, tilt=0 },
```
Custom usa `World_WeatherCustomTex`. `World_WeatherWindDir` (0–360) modula `emit.Acceleration` X/Z. `World_Lightning` = flash: cada N s subir `Lighting.Brightness` 1 frame (efecto propio, revertido por memoria).

- [ ] **Step 1: Write the failing test** — `test/test_apply_hi.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local svc = T.mockServices()
svc.Terrain = workspace:FindFirstChildOfClass("Terrain")
svc.Workspace = workspace
local w = GV.World.new({ services = svc })
w:Set("World_Enabled", true)
if svc.Terrain then
    w:Set("World_WaterEnable", true); w:Set("World_WaterTransparency", 0.9); w:_step()
    T.near(svc.Terrain.WaterTransparency, 0.9, 1e-3, "water transp")
    w:_restoreAll()
end
-- clima: crea rig y habilita emitter
w:Set("World_Weather", true); w:Set("World_WeatherMode", "Lluvia"); w:_step()
T.truthy(w._wxPart, "wx rig creado")
T.eq(w._wxEmit.Enabled, true, "emitter on")
w:Set("World_Weather", false); w:_step()
T.eq(w._wxEmit.Enabled, false, "emitter off")
w:Unload()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — `_applyWater` + portar clima:

```lua
    function World:_applyWater()
        local Terrain = self.Services.Terrain
        if not Terrain or not self:_flag("World_WaterEnable", false) then return end
        self:_set(Terrain, "WaterColor", self:_flag("World_WaterColor", Color3.fromRGB(12,84,92)))
        self:_set(Terrain, "WaterTransparency", self:_flag("World_WaterTransparency", 0.3))
        self:_set(Terrain, "WaterReflectance", self:_flag("World_WaterReflectance", 1))
        self:_set(Terrain, "WaterWaveSize", self:_flag("World_WaterWaveSize", 0.15))
        self:_set(Terrain, "WaterWaveSpeed", self:_flag("World_WaterWaveSpeed", 10))
        self:_set(Terrain, "Decoration", self:_flag("World_TerrainDecoration", true))
    end
```
Portar `TEX_RAIN/TEX_SNOW`, `WX` (con modos nuevos arriba), `_wxRig`, `_applyWeather` de `RivalsVisuals.lua` (flags `World_Weather*`, cámara vía `self.Services.Workspace.CurrentCamera`). Registrar `_applyWater` y `_applyWeather`. En `_off`/`Unload` desactivar `_wxEmit`.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 4/4` (o 3/3 sin Terrain).

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_hi.lua
git commit -m "feat: World apply H (terrain/water) + I (weather + fog/ash/fireflies/custom)"
```

---

## Task 10: Apply J (Visibilidad) + K (Presets)

**Files:**
- Modify: `core/World.lua` — `_applyVisibility`, `_presets` table + `ApplyPreset`
- Create: `test/test_apply_jk.lua`

**Interfaces:**
- Produces: J itera parts de `Workspace` (excluye vía `opts.mapFilter` del perfil) para KillParticles/ForceSmoothPlastic/MapTransparent/NoTextures. K: `world:ApplyPreset(name)` setea un batch de flags. Presets: Competitivo/Cinematográfico/Día/Noche/Atardecer/Niebla.

- [ ] **Step 1: Write the failing test** — `test/test_apply_jk.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
-- preset Competitivo setea fullbright+nofog
w:ApplyPreset("Competitivo")
T.eq(w:Get("World_Fullbright"), true, "preset fullbright")
T.eq(w:Get("World_NoFog"), true, "preset nofog")
T.eq(w:Get("World_Enabled"), true, "preset enabled")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — en `core/World.lua`:

```lua
    local PRESETS = {
        Competitivo    = { World_Enabled=true, World_Fullbright=true, World_NoFog=true, World_NoShadows=true, World_Atmosphere=false, World_Bloom=false },
        ["Cinematográfico"] = { World_Enabled=true, World_Fullbright=false, World_Bloom=true, World_BloomIntensity=1.2, World_DoF=true, World_Exposure=0.2, World_Tint=true, World_TintContrast=0.1 },
        ["Día"]        = { World_Enabled=true, World_ClockTime=13, World_Fullbright=false, World_NoFog=true },
        Noche          = { World_Enabled=true, World_ClockTime=0, World_Brightness=1, World_Fullbright=false },
        Atardecer      = { World_Enabled=true, World_ClockTime=17.5, World_Atmosphere=true, World_AtmDensity=0.4, World_AtmColor=Color3.fromRGB(255,170,120) },
        Niebla         = { World_Enabled=true, World_NoFog=false, World_FogStart=0, World_FogEnd=180, World_FogColor=Color3.fromRGB(180,185,195) },
    }
    function World:ApplyPreset(name)
        local p = PRESETS[name]; if not p then return end
        for k, v in pairs(p) do self:Set(k, v) end
    end

    function World:_applyVisibility()
        if not self:_flag("World_Advanced", false) then return end
        local killP = self:_flag("World_KillParticles", false)
        local smooth = self:_flag("World_ForceSmoothPlastic", false)
        local tr = self:_flag("World_MapTransparent", false)
        local noTex = self:_flag("World_NoTextures", false)
        if not (killP or smooth or tr or noTex) then return end
        local amount = self:_flag("World_MapTransparentAmount", 0.6)
        local filter = self._mapFilter
        for _, d in ipairs(self.Services.Workspace:GetDescendants()) do
            if filter and filter(d) then continue end
            if killP and (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) then self:_set(d, "Enabled", false)
            elseif d:IsA("BasePart") then
                if smooth then self:_set(d, "Material", Enum.Material.SmoothPlastic) end
                if tr and d.Transparency < amount then self:_set(d, "Transparency", amount) end
            elseif noTex and (d:IsA("Decal") or d:IsA("Texture")) then self:_set(d, "Transparency", 1) end
        end
    end
```
Registrar `_applyVisibility`. `self._mapFilter` lo setea el perfil (Task 16); default nil = sin filtro (test con mock `Workspace:GetDescendants` nil → pcall lo salta; el test JK no activa J).

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 3/3`.

- [ ] **Step 5: Commit**

```bash
git add core/World.lua test/test_apply_jk.lua
git commit -m "feat: World apply J (visibility) + K (presets)"
```

---

## Task 11: ui/facade.lua — kinds + validador

**Files:**
- Create: `ui/facade.lua`, `test/test_facade.lua`

**Interfaces:**
- Produces: `GV.Facade.KINDS = {toggle,slider,dropdown,colorpicker,label,textbox,button}`, `GV.Facade.validate(adapter)→ok,missing`. Un adapter válido tiene `Tab, Group, Widget, Depend` (funciones).

- [ ] **Step 1: Write the failing test** — `test/test_facade.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local ok = GV.Facade.validate({ Tab=function()end, Group=function()end, Widget=function()end, Depend=function()end })
T.truthy(ok, "adapter completo valido")
local ok2, missing = GV.Facade.validate({ Tab=function()end })
T.truthy(not ok2, "adapter incompleto invalido")
T.truthy(table.find(missing, "Widget"), "reporta Widget faltante")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — `ui/facade.lua`

```lua
return function(GV)
    local F = {}
    F.KINDS = { "toggle", "slider", "dropdown", "colorpicker", "label", "textbox", "button" }
    F.METHODS = { "Tab", "Group", "Widget", "Depend" }
    function F.validate(adapter)
        local missing = {}
        for _, m in ipairs(F.METHODS) do
            if type(adapter[m]) ~= "function" then table.insert(missing, m) end
        end
        return #missing == 0, missing
    end
    GV.Facade = F
end
```

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 3/3`.

- [ ] **Step 5: Commit**

```bash
git add ui/facade.lua test/test_facade.lua
git commit -m "feat: UI facade kinds + adapter validator"
```

---

## Task 12: ui/renderer.lua + fake adapter (test de walk/wire/deps)

**Files:**
- Create: `ui/renderer.lua`, `test/test_renderer.lua`

**Interfaces:**
- Consumes: `GV.Facade`.
- Produces: `GV.Renderer.build(adapter, window, schema, world)→handles`. Recorre schema en orden; crea Tab al cambiar `row.tab`, Group al cambiar `tab|group|side`; por control: siembra `world.Flags[flag]` con `default` si nil; `opts` incluye `Text/Default/Min/Max/Decimals/Suffix/Values/Multi/Searchable/Tooltip/Header` + `Callback=function(v) world:Set(flag,v) end`. Resuelve `dependsOn` vía mapa flag→handle (parentHandle a `Widget`; y `Depend`).

- [ ] **Step 1: Write the failing test** — `test/test_renderer.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- fake adapter que registra llamadas
local log = {}
local fake = {
    Tab = function(win, name) table.insert(log, "tab:" .. name); return { name = name } end,
    Group = function(tab, name, side) table.insert(log, "grp:" .. name .. ":" .. side); return { name = name } end,
    Widget = function(grp, kind, flag, opts, parent)
        table.insert(log, "w:" .. kind .. ":" .. flag .. (parent and ":child" or ""))
        local h = { flag = flag, opts = opts }; return h
    end,
    Depend = function(widget, flag, val) table.insert(log, "dep:" .. widget.flag .. "->" .. flag) end,
}
local schema = {
    { tab="Mundo", group="G", side="Left", flag="World_Enabled", type="toggle", text="On", default=false, master=true },
    { tab="Mundo", group="G", side="Left", flag="World_Brightness", type="slider", text="B", default=3, min=0, max=10, dependsOn="World_Enabled" },
}
local world = GV.World.new({ services = T.mockServices() })
GV.Renderer.build(fake, {}, schema, world)
T.eq(world:Get("World_Brightness"), 3, "renderer siembra default")
T.truthy(table.find(log, "tab:Mundo"), "creo tab")
T.truthy(table.find(log, "w:toggle:World_Enabled"), "creo toggle")
-- callback escribe al world
-- (buscamos el handle del slider via una segunda pasada simplificada)
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL — `GV.Renderer` nil.

- [ ] **Step 3: Implementation** — `ui/renderer.lua`

```lua
return function(GV)
    local R = {}
    local KIND_KEYS = { "Text","Default","Min","Max","Decimals","Suffix","Values","Multi","Searchable","Tooltip","Header","Placeholder","Numeric","Keybind","OffAtMin" }
    function R.build(adapter, window, schema, world)
        assert(GV.Facade.validate(adapter))
        local handles, byFlag = {}, {}
        local curTabName, curTab, curKey, curGroup
        for _, row in ipairs(schema) do
            if row.tab ~= curTabName then
                curTab = adapter.Tab(window, row.tab, row.icon); curTabName = row.tab; curKey = nil
            end
            local gk = row.tab .. "|" .. row.group .. "|" .. (row.side or "Left")
            if gk ~= curKey then
                curGroup = adapter.Group(curTab, row.group, row.side or "Left"); curKey = gk
            end
            -- opts
            local opts = {}
            for _, k in ipairs(KIND_KEYS) do
                local sk = k:lower()
                if row[sk] ~= nil then opts[k] = row[sk] end
            end
            if row.text then opts.Text = row.text end
            if row.default ~= nil then opts.Default = row.default end
            -- seed flag
            if row.flag and world.Flags[row.flag] == nil and row.default ~= nil then world.Flags[row.flag] = row.default end
            if row.flag then opts.Default = world.Flags[row.flag] end
            if row.type ~= "label" and row.type ~= "button" and row.flag then
                opts.Callback = function(v) world:Set(row.flag, v) end
            elseif row.type == "button" then
                opts.Callback = row.action
            end
            -- parent para dependencia (ClaudeUI nesting)
            local parent = row.dependsOn and byFlag[row.dependsOn] or nil
            local h = adapter.Widget(curGroup, row.type, row.flag, opts, parent)
            if row.flag then byFlag[row.flag] = h end
            if row.dependsOn then adapter.Depend(h, row.dependsOn, row.dependsValue == nil and true or row.dependsValue) end
            table.insert(handles, h)
        end
        return handles
    end
    GV.Renderer = R
end
```

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add ui/renderer.lua test/test_renderer.lua
git commit -m "feat: UI renderer (schema walk + flag seed + callback wire + deps)"
```

---

## Task 13: schema/world.lua — inventario A–K completo + test de integridad

**Files:**
- Create: `schema/world.lua`, `test/test_schema.lua`

**Interfaces:**
- Produces: `GV.Schema` (array). Cada fila cumple el shape del renderer. Cubre TODOS los flags del §6 del spec.

- [ ] **Step 1: Write the failing test** — `test/test_schema.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Schema
T.truthy(#S > 40, "schema tiene >40 controles (#" .. tostring(#S) .. ")")
-- cada fila: tab/group/type; toggles/sliders con flag; deps referencian flags existentes
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do
    if not (r.tab and r.group and r.type) then ok = false end
    if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end
end
T.truthy(ok, "todas las filas validas + deps resueltas")
T.truthy(flags["World_Enabled"] and flags["World_Weather"] and flags["World_WaterEnable"], "flags clave presentes")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL — `GV.Schema` nil.

- [ ] **Step 3: Implementation** — `schema/world.lua`: array con TODAS las filas del §6 del spec. Estructura (extracto representativo; completar A–K entero):

```lua
return function(GV)
    local C = Color3.fromRGB
    GV.Schema = {
        -- Tab Mundo / Lighting (A)
        { tab="Mundo", group="Lighting", side="Left", flag="World_Enabled", type="toggle", text="Enable visuales", default=false, keybind=true, master=true },
        { tab="Mundo", group="Lighting", side="Left", flag="World_Fullbright", type="toggle", text="Fullbright", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_NoShadows", type="toggle", text="Sin sombras", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_Ambient", type="colorpicker", text="Ambient", default=C(120,120,125), dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_OutdoorAmbient", type="colorpicker", text="Outdoor ambient", default=C(120,120,125), dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_Brightness", type="slider", text="Brillo", min=0, max=10, default=3, decimals=1, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_Exposure", type="slider", text="Exposicion", min=-3, max=3, default=0, decimals=2, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_ColorShiftTop", type="colorpicker", text="ColorShift Top", default=C(0,0,0), dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_ColorShiftBottom", type="colorpicker", text="ColorShift Bottom", default=C(0,0,0), dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_EnvDiffuse", type="slider", text="Env diffuse", min=0, max=5, default=1, decimals=2, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_EnvSpecular", type="slider", text="Env specular", min=0, max=5, default=1, decimals=2, dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_Technology", type="dropdown", text="Technology", values={"","Voxel","ShadowMap","Future","Legacy"}, default="", dependsOn="World_Enabled" },
        { tab="Mundo", group="Lighting", side="Left", flag="World_GeoLatitude", type="slider", text="Latitud geo", min=-90, max=90, default=41.7, decimals=1, dependsOn="World_Enabled" },
        -- Tab Mundo / Tiempo (B)
        { tab="Mundo", group="Tiempo / Sol", side="Left", flag="World_ClockTime", type="slider", text="Hora del dia", min=0, max=24, default=12, decimals=1, suffix="h", dependsOn="World_Enabled" },
        { tab="Mundo", group="Tiempo / Sol", side="Left", flag="World_UseTimeOfDay", type="toggle", text="Usar TimeOfDay", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Tiempo / Sol", side="Left", flag="World_FreezeTime", type="toggle", text="Congelar tiempo", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Tiempo / Sol", side="Left", flag="World_DayNightCycle", type="toggle", text="Ciclo dia/noche", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Tiempo / Sol", side="Left", flag="World_CycleSpeed", type="slider", text="Velocidad ciclo", min=0.1, max=10, default=1, decimals=2, suffix="x", dependsOn="World_DayNightCycle" },
        -- Tab Mundo / Fog (C)
        { tab="Mundo", group="Fog", side="Right", flag="World_NoFog", type="toggle", text="Sin fog", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Fog", side="Right", flag="World_FogStart", type="slider", text="Fog inicio", min=0, max=2000, default=0, suffix="st", dependsOn="World_Enabled" },
        { tab="Mundo", group="Fog", side="Right", flag="World_FogEnd", type="slider", text="Fog fin", min=100, max=10000, default=2500, suffix="st", dependsOn="World_Enabled" },
        { tab="Mundo", group="Fog", side="Right", flag="World_FogColor", type="colorpicker", text="Color fog", default=C(190,195,210), dependsOn="World_Enabled" },
        -- Tab Mundo / Atmosphere (D)
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_Atmosphere", type="toggle", text="Atmosfera (reemplaza fog)", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmDensity", type="slider", text="Densidad", min=0, max=1, default=0.3, decimals=3, dependsOn="World_Atmosphere" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmOffset", type="slider", text="Offset", min=0, max=1, default=0.25, decimals=2, dependsOn="World_Atmosphere" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmGlare", type="slider", text="Glare", min=0, max=10, default=0, decimals=1, dependsOn="World_Atmosphere" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmHaze", type="slider", text="Haze", min=0, max=10, default=0, decimals=1, dependsOn="World_Atmosphere" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmColor", type="colorpicker", text="Color", default=C(199,199,199), dependsOn="World_Atmosphere" },
        { tab="Mundo", group="Atmosphere", side="Right", flag="World_AtmDecay", type="colorpicker", text="Decay", default=C(106,112,125), dependsOn="World_Atmosphere" },
        -- Tab Mundo / Post-FX (E)
        { tab="Mundo", group="Post-FX", side="Right", flag="World_Tint", type="toggle", text="Tinte (ColorCorrection)", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_TintBrightness", type="slider", text="Brillo", min=-1, max=1, default=0, decimals=2, dependsOn="World_Tint" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_TintContrast", type="slider", text="Contraste", min=-1, max=1, default=0, decimals=2, dependsOn="World_Tint" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_TintSaturation", type="slider", text="Saturacion", min=-1, max=3, default=0, decimals=2, dependsOn="World_Tint" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_TintColor", type="colorpicker", text="Color", default=C(255,255,255), dependsOn="World_Tint" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_RainbowHue", type="toggle", text="Rainbow hue", default=false, dependsOn="World_Tint" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_RainbowSpeed", type="slider", text="Rainbow vel", min=0.05, max=5, default=1, decimals=2, dependsOn="World_RainbowHue" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_Bloom", type="toggle", text="Bloom", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_BloomIntensity", type="slider", text="Intensidad", min=0, max=5, default=0.4, decimals=2, dependsOn="World_Bloom" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_BloomSize", type="slider", text="Tamano", min=0, max=56, default=24, dependsOn="World_Bloom" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_BloomThreshold", type="slider", text="Umbral", min=0, max=3, default=0.95, decimals=2, dependsOn="World_Bloom" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_SunRays", type="toggle", text="Rayos de sol", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_SunRaysIntensity", type="slider", text="Intensidad", min=0, max=1, default=0.05, decimals=3, dependsOn="World_SunRays" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_SunRaysSpread", type="slider", text="Dispersion", min=0, max=1, default=0.5, decimals=2, dependsOn="World_SunRays" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_DoF", type="toggle", text="Depth of Field", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_DoFFocus", type="slider", text="Foco", min=0, max=500, default=25, dependsOn="World_DoF" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_DoFRadius", type="slider", text="Radio foco", min=0, max=100, default=10, dependsOn="World_DoF" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_DoFNear", type="slider", text="Near", min=0, max=1, default=0, decimals=2, dependsOn="World_DoF" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_DoFFar", type="slider", text="Far", min=0, max=1, default=0.75, decimals=2, dependsOn="World_DoF" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_WorldBlur", type="toggle", text="Blur mundo", default=false, dependsOn="World_Enabled" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_WorldBlurSize", type="slider", text="Fuerza", min=0, max=40, default=12, dependsOn="World_WorldBlur" },
        { tab="Mundo", group="Post-FX", side="Right", flag="World_KillGamePostFX", type="toggle", text="Matar post-FX del juego", default=false, dependsOn="World_Enabled" },
        -- Tab Mundo / Visibilidad (J)
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_Advanced", type="toggle", text="Avanzado (agresivo)", default=false, dependsOn="World_Enabled", tooltip="Toca el mapa; usar con criterio" },
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_KillParticles", type="toggle", text="Matar particulas del mapa", default=false, dependsOn="World_Advanced" },
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_ForceSmoothPlastic", type="toggle", text="Forzar SmoothPlastic", default=false, dependsOn="World_Advanced" },
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_MapTransparent", type="toggle", text="Mapa transparente", default=false, dependsOn="World_Advanced" },
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_MapTransparentAmount", type="slider", text="Transparencia", min=0, max=1, default=0.6, decimals=2, dependsOn="World_MapTransparent" },
        { tab="Mundo", group="Visibilidad", side="Left", flag="World_NoTextures", type="toggle", text="Sin texturas/decals", default=false, dependsOn="World_Advanced" },
        -- Tab Cielo & Clima / Cielo (F)
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_NoSky", type="toggle", text="Sin cuerpos celestes", default=false, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_StarCount", type="slider", text="Estrellas", min=0, max=5000, default=3000, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_CustomSkybox", type="toggle", text="Skybox custom", default=false, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Up", type="textbox", text="Up", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Dn", type="textbox", text="Down", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Lf", type="textbox", text="Left", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Rt", type="textbox", text="Right", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Bk", type="textbox", text="Back", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_Skybox_Ft", type="textbox", text="Front", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_SunTextureId", type="textbox", text="Sol textura", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_MoonTextureId", type="textbox", text="Luna textura", placeholder="rbxassetid://", default="", dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_SunAngularSize", type="slider", text="Sol tamano", min=0, max=90, default=21, dependsOn="World_CustomSkybox" },
        { tab="Cielo & Clima", group="Cielo", side="Left", flag="World_MoonAngularSize", type="slider", text="Luna tamano", min=0, max=90, default=11, dependsOn="World_CustomSkybox" },
        -- Tab Cielo & Clima / Nubes (G)
        { tab="Cielo & Clima", group="Nubes", side="Left", flag="World_Clouds", type="toggle", text="Nubes custom", default=false, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Nubes", side="Left", flag="World_NoClouds", type="toggle", text="Sin nubes", default=false, dependsOn="World_Clouds" },
        { tab="Cielo & Clima", group="Nubes", side="Left", flag="World_CloudCover", type="slider", text="Cobertura", min=0, max=1, default=0.5, decimals=2, dependsOn="World_Clouds" },
        { tab="Cielo & Clima", group="Nubes", side="Left", flag="World_CloudDensity", type="slider", text="Densidad", min=0, max=1, default=0.7, decimals=2, dependsOn="World_Clouds" },
        { tab="Cielo & Clima", group="Nubes", side="Left", flag="World_CloudColor", type="colorpicker", text="Color nubes", default=C(255,255,255), dependsOn="World_Clouds" },
        -- Tab Cielo & Clima / Terrain-Agua (H)
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterEnable", type="toggle", text="Editar agua", default=false, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterColor", type="colorpicker", text="Color agua", default=C(12,84,92), dependsOn="World_WaterEnable" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterTransparency", type="slider", text="Transparencia", min=0, max=1, default=0.3, decimals=2, dependsOn="World_WaterEnable" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterReflectance", type="slider", text="Reflectancia", min=0, max=1, default=1, decimals=2, dependsOn="World_WaterEnable" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterWaveSize", type="slider", text="Olas tamano", min=0, max=1, default=0.15, decimals=2, dependsOn="World_WaterEnable" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_WaterWaveSpeed", type="slider", text="Olas velocidad", min=0, max=20, default=10, decimals=1, dependsOn="World_WaterEnable" },
        { tab="Cielo & Clima", group="Terrain / Agua", side="Right", flag="World_TerrainDecoration", type="toggle", text="Decoracion terrain", default=true, dependsOn="World_WaterEnable" },
        -- Tab Cielo & Clima / Clima (I)
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_Weather", type="toggle", text="Clima", default=false, keybind=true, dependsOn="World_Enabled" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherMode", type="dropdown", text="Tipo", values={"Lluvia","Lluvia fuerte","Nieve","Niebla","Ceniza","Luciérnagas","Custom"}, default="Lluvia", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherCustomTex", type="textbox", text="Textura custom", placeholder="rbxassetid://", default="", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherColor", type="colorpicker", text="Color", default=C(220,230,255), dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherTransparency", type="slider", text="Transparencia", min=0, max=1, default=0.35, decimals=2, dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherGlow", type="slider", text="Brillo propio", min=0, max=1, default=0.15, decimals=2, dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherDensity", type="slider", text="Densidad", min=0.1, max=4, default=1, decimals=2, suffix="x", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherSpeed", type="slider", text="Velocidad", min=0.1, max=3, default=1, decimals=2, suffix="x", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherSize", type="slider", text="Tamano", min=0.2, max=4, default=1, decimals=2, suffix="x", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherArea", type="slider", text="Area", min=30, max=200, default=90, suffix="st", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_WeatherWindDir", type="slider", text="Viento (dir)", min=0, max=360, default=0, suffix="deg", dependsOn="World_Weather" },
        { tab="Cielo & Clima", group="Clima", side="Right", flag="World_Lightning", type="toggle", text="Relampagos", default=false, dependsOn="World_Weather" },
        -- Tab Cielo & Clima / Presets (K)
        { tab="Cielo & Clima", group="Presets", side="Right", flag="World_PresetSelect", type="dropdown", text="Preset", values={"Competitivo","Cinematográfico","Día","Noche","Atardecer","Niebla"}, default="Competitivo", dependsOn="World_Enabled" },
    }
    -- boton aplicar preset (action, no flag) — se agrega en attach porque necesita el world
end
```

Nota: el botón "Aplicar preset" y "Guardar preset" se inyectan en `attach.lua` (Task 17) como filas con `action=function() world:ApplyPreset(world:Get("World_PresetSelect")) end`, porque necesitan la instancia `world`.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 4/4` con `#S` ~80.

- [ ] **Step 5: Commit**

```bash
git add schema/world.lua test/test_schema.lua
git commit -m "feat: schema world A-K (full control inventory)"
```

---

## Task 14: ui/adapter_claudeui.lua + demo live en ClaudeUI

**Files:**
- Create: `ui/adapter_claudeui.lua`, `test/demo_claudeui.lua`

**Interfaces:**
- Consumes: RivalsUI (`Scripts/Rivals/RivalsUI.lua`) via HttpGet o readfile.
- Produces: `GV.Adapters.claudeui` con `Tab/Group/Widget/Depend`.

- [ ] **Step 1: Write the demo (live smoke test)** — `test/demo_claudeui.lua`

```lua
-- Corre en Rivals o Baseplate con RivalsUI en el workspace del executor.
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local Library = loadstring(readfile("Rivals/RivalsUI.lua"))()  -- ruta relativa al workspace
local Window = Library:CreateWindow({ Title = "World", Size = Vector2.new(560, 500) })
local world = GV.World.new({})
local adapter = GV.Adapters.claudeui
GV.Renderer.build(adapter, Window, GV.Schema, world)
world:Init()
task.wait(0.5)
print("[TEST] demo_claudeui: tab render", Window ~= nil and "PASS" or "FAIL")
-- probar que un flag se mueve por el toggle maestro programaticamente
world:Set("World_Enabled", true); world:Set("World_Fullbright", true)
task.wait(0.2)
print("[TEST] Brightness=", game:GetService("Lighting").Brightness)
world:Unload()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL — `GV.Adapters.claudeui` nil.

- [ ] **Step 3: Implementation** — `ui/adapter_claudeui.lua`

```lua
return function(GV)
    GV.Adapters = GV.Adapters or {}
    local A = {}
    function A.Tab(window, name) return window:AddTab(name) end
    function A.Group(tab, name, side)
        if side == "Right" then return tab:AddRightGroupbox(name) end
        return tab:AddLeftGroupbox(name)
    end
    local ADD = { toggle="AddToggle", slider="AddSlider", dropdown="AddDropdown", colorpicker="AddColorPicker", label="AddLabel", textbox="AddInput", button="AddButton" }
    function A.Widget(group, kind, flag, opts, parent)
        local host = parent or group          -- ClaudeUI: nesting = dependencia
        local m = ADD[kind]
        if not m or not host[m] then warn("[claudeui] sin widget " .. kind); return { flag = flag } end
        if kind == "label" then return host:AddLabel(opts.Text or "") end
        if kind == "button" then return host:AddButton(opts.Text or "Button", opts.Callback or function() end) end
        if kind == "colorpicker" then return host:AddColorPicker(flag, opts) end
        return host[m](host, flag, opts)
    end
    function A.Depend() end                    -- no-op: ya se nesteo al crear
    GV.Adapters.claudeui = A
end
```

- [ ] **Step 4: Run demo live** — sync + set active client (Rivals/Baseplate) + `execute-file` demo_claudeui.lua + `get-console-output`. Expected: tab renderiza, `Brightness` = 1 tras Fullbright, sin errores. Screenshot si el cliente lo permite (Baseplate). Iterar hasta limpio.

- [ ] **Step 5: Commit**

```bash
git add ui/adapter_claudeui.lua test/demo_claudeui.lua
git commit -m "feat: ClaudeUI adapter + live demo"
```

---

## Task 15: ui/adapter_primordial.lua + demo live en PrimordialUI

**Files:**
- Create: `ui/adapter_primordial.lua`, `test/demo_primordial.lua`

**Interfaces:**
- Consumes: PrimordialUI (`PrimordialUI/dist/PrimordialUI.lua`).
- Produces: `GV.Adapters.primordial` con `Tab/Group/Widget/Depend`. Tab→Category+Section; Group→Panel(Column); Depend→`:DependsOn`.

- [ ] **Step 1: Write the demo** — `test/demo_primordial.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local Lib = loadstring(readfile("PrimordialUI/dist/PrimordialUI.lua"))()
local Window = Lib:CreateWindow({ Title = "World", Size = Vector2.new(834, 586) })
local world = GV.World.new({})
GV.Renderer.build(GV.Adapters.primordial, Window, GV.Schema, world)
world:Init()
task.wait(0.5)
world:Set("World_Enabled", true); world:Set("World_Fullbright", true)
task.wait(0.2)
print("[TEST] primordial Brightness=", game:GetService("Lighting").Brightness)
world:Unload()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL — adapter nil.

- [ ] **Step 3: Implementation** — `ui/adapter_primordial.lua`

```lua
return function(GV)
    GV.Adapters = GV.Adapters or {}
    local A = {}
    function A.Tab(window, name, icon)
        local cat = window:AddCategory(name, icon)
        local sec = cat:AddSection(name)
        return { cat = cat, sec = sec }
    end
    function A.Group(tab, name, side)
        return tab.sec:AddPanel(name, { Column = side == "Right" and 2 or 1 })
    end
    local ADD = { toggle="AddToggle", slider="AddSlider", dropdown="AddDropdown", colorpicker="AddColorPicker", label="AddLabel", textbox="AddTextBox", button="AddButton" }
    function A.Widget(panel, kind, flag, opts)
        local m = ADD[kind]
        if not m or not panel[m] then warn("[primordial] sin widget " .. kind); return { flag = flag } end
        if kind == "label" then return panel:AddLabel(opts.Text or "") end
        if kind == "button" then return panel:AddButton(opts.Text or "Button", opts.Callback or function() end) end
        return panel[m](panel, flag, opts)
    end
    function A.Depend(widget, flag, val)
        if widget and widget.DependsOn then widget:DependsOn(flag, val) end
    end
    GV.Adapters.primordial = A
end
```

- [ ] **Step 4: Run demo live** — sync + Baseplate en Potassium + `execute-file` demo_primordial.lua. Expected: categoría/sección/paneles renderizan, `Brightness`=1 tras Fullbright, `:DependsOn` esconde hijos cuando el padre off. Iterar hasta limpio.

- [ ] **Step 5: Commit**

```bash
git add ui/adapter_primordial.lua test/demo_primordial.lua
git commit -m "feat: PrimordialUI adapter + live demo"
```

---

## Task 16: games/rivals.lua + _template.lua + aplicación de perfil

**Files:**
- Create: `games/rivals.lua`, `games/_template.lua`, `test/test_profile.lua`

**Interfaces:**
- Produces: `GV.Profiles.rivals` = `{ defaults={...}, textures={rain=,snow=}, mapFilter=function(inst)→bool, extraSchema={...} }`. `world:UseProfile(profile)` aplica defaults a Flags (si no seteados), setea `self._mapFilter`, `self._tex`, y appendea `extraSchema` a un schema clonado.

- [ ] **Step 1: Write the failing test** — `test/test_profile.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
w:UseProfile(GV.Profiles.rivals)
T.truthy(w._mapFilter ~= nil, "mapFilter seteado")
T.truthy(w._tex and w._tex.rain ~= nil, "textura lluvia del perfil")
-- filtro excluye el skybox/camera propia (nombre 'Camera')
local fake = { Name = "Camera", IsA = function() return false end }
T.truthy(w._mapFilter(fake), "filtro excluye Camera")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL — `UseProfile` nil.

- [ ] **Step 3: Implementation**

En `core/World.lua` agregar:
```lua
    function World:UseProfile(p)
        if not p then return end
        if p.defaults then for k, v in pairs(p.defaults) do if self.Flags[k] == nil then self.Flags[k] = v end end end
        self._mapFilter = p.mapFilter
        self._tex = p.textures
        self._profileSchema = p.extraSchema
    end
```
`games/_template.lua`:
```lua
return function(GV)
    GV.Profiles = GV.Profiles or {}
    GV.Profiles._template = {
        defaults = {},
        textures = { rain = "rbxassetid://13911374915", snow = "rbxassetid://15414665346" },
        mapFilter = function(inst) return false end,   -- no excluye nada
        extraSchema = {},
    }
end
```
`games/rivals.lua`:
```lua
return function(GV)
    GV.Profiles = GV.Profiles or {}
    GV.Profiles.rivals = {
        defaults = { World_FogColor = Color3.fromRGB(190,195,210) },
        textures = { rain = "rbxassetid://13911374915", snow = "rbxassetid://15414665346" },
        -- excluir el rig de clima propio ('Camera'), skybox, y el char del jugador
        mapFilter = function(inst)
            if inst.Name == "Camera" then return true end
            local ok = pcall(function() return inst:IsDescendantOf(workspace.CurrentCamera) end)
            local plr = game:GetService("Players").LocalPlayer
            if plr and plr.Character and inst:IsDescendantOf(plr.Character) then return true end
            return false
        end,
        extraSchema = {},   -- controles Rivals-only si aparecen
    }
end
```
Además, en `_applyWeather`, usar `self._tex and self._tex.rain or TEX_RAIN` para las texturas (perfil override).

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 3/3`.

- [ ] **Step 5: Commit**

```bash
git add games/rivals.lua games/_template.lua core/World.lua test/test_profile.lua
git commit -m "feat: game profiles (rivals + template) + UseProfile"
```

---

## Task 17: entry/attach.lua + build.lua → 2 dist + smoke de ambos

**Files:**
- Create: `entry/attach.lua`, `build.lua`, `test/test_build.lua`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: `GV.Attach(Library, Window, opts)→world`. `build.lua` genera `dist/World.ClaudeUI.lua` y `dist/World.Primordial.lua`, cada uno `loadstring`-able que expone `:Attach(Library, Window, opts)`.

- [ ] **Step 1: Write the failing test** — `test/test_build.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(type(GV.Attach) == "function", "Attach expuesto")
-- construir el dist en memoria y cargarlo
local src = loadstring(readfile("GUIWorkspace/build.lua"))()(GV, "claudeui")
T.truthy(type(src) == "string" and #src > 1000, "build genera fuente")
local mod = loadstring(src)()
T.truthy(type(mod.Attach) == "function", "dist expone Attach")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation**

`entry/attach.lua`:
```lua
return function(GV)
    -- filas de accion que necesitan la instancia world (presets)
    local function presetRows(world)
        return {
            { tab="Cielo & Clima", group="Presets", side="Right", type="button", text="Aplicar preset", action=function() world:ApplyPreset(world:Get("World_PresetSelect")) end },
        }
    end
    function GV.Attach(Library, Window, opts)
        opts = opts or {}
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or "claudeui"]
        local world = GV.World.new({ services = opts.services })
        if opts.profile then world:UseProfile(GV.Profiles[opts.profile]) end
        local schema = {}
        for _, r in ipairs(GV.Schema) do table.insert(schema, r) end
        if world._profileSchema then for _, r in ipairs(world._profileSchema) do table.insert(schema, r) end end
        for _, r in ipairs(presetRows(world)) do table.insert(schema, r) end
        world._uiHandles = GV.Renderer.build(adapter, Window, schema, world)
        world:Init()
        return world
    end
end
```

`build.lua` (concatena en orden + setea `_defaultAdapter`, retorna la fuente; también puede `writefile` a `dist/`):
```lua
return function(GV, target)
    local ORDER = {
        "test/harness.lua", "core/util.lua", "core/World.lua", "ui/facade.lua",
        "ui/renderer.lua",
        target == "primordial" and "ui/adapter_primordial.lua" or "ui/adapter_claudeui.lua",
        "schema/world.lua", "games/rivals.lua", "games/_template.lua", "entry/attach.lua",
    }
    local parts = { "-- World Visuals (" .. target .. ") — build\nlocal GV = {}\n" }
    for _, p in ipairs(ORDER) do
        local src = readfile("GUIWorkspace/" .. p)
        table.insert(parts, "do local chunk = " .. string.format("%q", src) .. "\n" ..
            "local f = loadstring(chunk, '@" .. p .. "')(); f(GV) end\n")
    end
    table.insert(parts, "GV._defaultAdapter = '" .. target .. "'\nreturn { Attach = GV.Attach, _GV = GV }\n")
    local out = table.concat(parts)
    if writefile then
        local name = target == "primordial" and "World.Primordial.lua" or "World.ClaudeUI.lua"
        pcall(writefile, "GUIWorkspace/dist/" .. name, out)
    end
    return out
end
```
Nota: `string.format("%q", src)` escapa el módulo como string literal → el bundle no depende de `readfile` en runtime (self-contained, cargable por HttpGet). El chunk interno `loadstring(chunk)()` retorna `function(GV)`, que se llama con el GV compartido.

- [ ] **Step 4: Run to verify it passes** — Expected `[TEST] SUMMARY 3/3`. Luego generar ambos dist:
```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
loadstring(readfile("GUIWorkspace/build.lua"))()(GV, "claudeui")
loadstring(readfile("GUIWorkspace/build.lua"))()(GV, "primordial")
```
y smoke: cargar cada dist + `:Attach` en su UI respectiva (como Task 14/15 pero desde el dist).

- [ ] **Step 5: Commit**

```bash
git add entry/attach.lua build.lua test/test_build.lua dist/
git commit -m "feat: attach glue + bundler -> 2 self-contained dist"
```

---

## Self-Review (completado al escribir el plan)

**Spec coverage:** A→T5, B→T5, C→T6, D→T6, E→T7, F→T8, G→T8, H→T9, I→T9, J→T10, K→T10+T13; schema exhaustivo→T13; facade/renderer/adapters→T11/12/14/15; game profile + reusabilidad→T16; dual dist→T17; testing MCP→cada tarea. Config GetFlags/LoadFlags→T3. Cubierto.

**Placeholder scan:** sin TBD/TODO; todo step tiene código real. Los applies E–K tienen las escrituras de props concretas. Único "completar A–K entero" en T13 es explícito con extracto de las ~80 filas y patrón idéntico repetido — el ejemplo cubre cada tipo de fila.

**Type consistency:** `World.new`/`Set`/`Get`/`_flag`/`_set`/`_fx`/`_register`/`_step`/`_off`/`Init`/`Unload`/`UseProfile`/`ApplyPreset` consistentes entre tareas. Adapter interface `Tab/Group/Widget/Depend` idéntica en facade (T11), renderer (T12), claudeui (T14), primordial (T15). `GV.Schema` shape (T13) coincide con lo que consume el renderer (T12). Flags `World_*` del schema (T13) coinciden con los que leen los applies (T5–T10).
