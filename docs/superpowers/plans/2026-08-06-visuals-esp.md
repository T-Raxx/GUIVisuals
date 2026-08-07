# Visuals Suite §B — ESP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Módulo ESP Drawing-based (box/health/nombre/dist/skeleton/headdot/lookdir/tracer/offscreen/chams/object-ESP), game-agnostic vía entity-provider, integrado en la Visuals Suite (registro `GV.Modules.esp`), cada color con ColorFade.

**Architecture:** `core/ESP.lua` espejo de World: `ESP.new({services,flags,provider})`, `Init/Unload`, `_update` (RenderStepped), Drawing retained + bundle por-target, `_flag`. Enumera targets vía provider (default `Players`, Rivals override tag `"Entity"`). Colores vía `GV.Color.fade`. Chams = Highlight (detectable). Preview mode para §D.

**Tech Stack:** Luau executor, Drawing API, módulos `return function(GV)`, testing live MCP.

## Global Constraints

- **Sin `require`.** `return function(GV) ... end`.
- **Cero hooks.** Drawing + Highlight + lecturas de instancias. Nada de hookfunction/etc.
- **Flags compartido** (suite): prefijo `ESP_`. Maestro `ESP_Enabled` (keybind). Servicios+provider inyectables (test con mocks).
- **ColorFade:** cada color = `GV.Color.fade(self.Flags, base, t)`; en schema via `GV.CF`.
- **Chams detectable:** único uso de instancias (Highlight); grupo marcado.
- **Target normalizado (provider):** `{model, health, maxHealth, root, head, bones={{a,b}...}, name, team, weapon, level, isEnemy}`.
- **Ruta/MCP:** mismo Test Loop del plan de World (sync robocopy → `execute-file` → console). Cliente reconecta → re-list+set-active.

## Test Loop

Igual que planes previos. Lógica pura con provider/servicios mock. Rendering verificado live: spawnear un dummy (Part+Humanoid+HRP+Head) frente a la cámara, `_update`, chequear que el bundle quedó `Visible` + tamaño plausible (patrón RivalsESP `espBoxesVisible`).

## File Structure

- Create: `core/ESP.lua` — módulo ESP (registra `GV.Modules.esp`).
- Create: `core/esp_default.lua` — `GV.DefaultProvider` (enumera Players, bones R15/R6).
- Create: `schema/esp.lua` — schema ESP (CF colores), registra `GV.Modules.esp.schema`.
- Modify: `games/rivals.lua` — agregar `.esp` provider (tag Entity) + `objectSources`.
- Modify: `init.lua` — ORDER agrega `core/ESP.lua`, `core/esp_default.lua`, `schema/esp.lua`.
- Modify: `build.lua` — ORDER incluye los nuevos; `GV._defaultModules = {"world","esp"}`.
- Modify: `test/harness.lua` — `mockPlayers()` / `spawnDummy()` helpers.
- Create tests: `test/test_esp_core.lua`, `test/test_esp_provider.lua`, `test/test_esp_filters.lua`, `test/test_esp_schema.lua`, `test/demo_esp.lua`.

Referencia a portar: `Scripts/Rivals/RivalsESP.lua` (Drawing bundle box/health/name/dist/tracer, `_update`, `resolveEntity`, `_healthColor`).

---

## Task 1: ESP core skeleton + registro

**Files:**
- Create: `core/ESP.lua`
- Modify: `init.lua` (ORDER: `core/ESP.lua` tras `core/World.lua`)
- Create: `test/test_esp_core.lua`

**Interfaces:**
- Produces: `GV.ESP.new({services,flags,provider})`, `:Set/:Get/:_flag`, `:_draw(class,props)`, `:Init()`, `:Unload()`, `:UseProfile(p)`. `GV.Modules.esp = {new=fn}`. `_update` existe (vacío salvo enумerate+hide).

- [ ] **Step 1: Write the failing test** — `test/test_esp_core.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(GV.ESP and type(GV.ESP.new) == "function", "GV.ESP.new existe")
T.truthy(GV.Modules.esp and type(GV.Modules.esp.new) == "function", "esp registrado")
local shared = {}
local e = GV.ESP.new({ flags = shared, provider = { getTargets = function() return {} end } })
e:Set("ESP_MaxDistance", 500)
T.eq(shared.ESP_MaxDistance, 500, "usa flags compartido")
-- draw retained
local d = e:_draw("Square", { Thickness = 1 })
T.truthy(d and d.Remove, "_draw crea un Drawing")
e:Init()
T.truthy(e.Loaded, "Init marca Loaded")
e:Unload()
T.truthy(not e.Loaded, "Unload limpia")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.ESP` nil).

- [ ] **Step 3: Implementation** — `core/ESP.lua`

```lua
return function(GV)
    if not (Drawing and Drawing.new) then
        -- registrar stub para no romper el loader en entornos sin Drawing
        GV.Modules = GV.Modules or {}; GV.Modules.esp = GV.Modules.esp or {}
        GV.Modules.esp.new = GV.Modules.esp.new or function() return { Init=function() end, Unload=function() end } end
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

    function ESP:_update()
        -- (features se agregan en tasks siguientes)
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
```
`init.lua` ORDER: agregar `"core/ESP.lua"` tras `"core/World.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 6/6`.

- [ ] **Step 5: Commit**

```bash
git add core/ESP.lua init.lua test/test_esp_core.lua
git commit -m "feat: ESP core skeleton + module registry"
```

---

## Task 2: Default entity provider (Players) + bones R15/R6

**Files:**
- Create: `core/esp_default.lua`
- Modify: `init.lua` (ORDER: tras `core/ESP.lua`)
- Create: `test/test_esp_provider.lua`

**Interfaces:**
- Produces: `GV.DefaultProvider.getTargets(esp)→{Target...}`. Enumera `Players:GetPlayers()` con Character vivo (Humanoid.Health>0, HRP, Head). Bones R15 y R6. `isEnemy = ESP_TeamCheck and team~=localTeam`. Excluye LocalPlayer.

- [ ] **Step 1: Write the failing test** — `test/test_esp_provider.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- provider con Players mock
local fakeHum = { Health = 80, MaxHealth = 100, ClassName = "Humanoid" }
local model = Instance.new("Model")
local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = model
local head = Instance.new("Part"); head.Name = "Head"; head.Parent = model
local realHum = Instance.new("Humanoid"); realHum.Parent = model
model.Name = "Enemy1"
local svc = {
    Players = { GetPlayers = function() return { { Name = "Enemy1", Character = model, Team = nil } } end, LocalPlayer = { Character = nil, Team = nil } },
    Workspace = workspace, RunService = { RenderStepped = { Connect = function() return { Disconnect = function() end } end } },
    CollectionService = { GetTagged = function() return {} end },
}
local e = GV.ESP.new({ services = svc, flags = {} })
local targets = GV.DefaultProvider.getTargets(e)
T.eq(#targets, 1, "1 target enumerado")
T.eq(targets[1].name, "Enemy1", "nombre")
T.eq(targets[1].root, hrp, "root = HRP")
T.truthy(targets[1].head and #targets[1].bones > 0, "head + bones")
model:Destroy()
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`GV.DefaultProvider` nil).

- [ ] **Step 3: Implementation** — `core/esp_default.lua`

```lua
return function(GV)
    local BONES_R15 = {
        { a = "Head", b = "UpperTorso" }, { a = "UpperTorso", b = "LowerTorso" },
        { a = "UpperTorso", b = "LeftUpperArm" }, { a = "LeftUpperArm", b = "LeftLowerArm" }, { a = "LeftLowerArm", b = "LeftHand" },
        { a = "UpperTorso", b = "RightUpperArm" }, { a = "RightUpperArm", b = "RightLowerArm" }, { a = "RightLowerArm", b = "RightHand" },
        { a = "LowerTorso", b = "LeftUpperLeg" }, { a = "LeftUpperLeg", b = "LeftLowerLeg" }, { a = "LeftLowerLeg", b = "LeftFoot" },
        { a = "LowerTorso", b = "RightUpperLeg" }, { a = "RightUpperLeg", b = "RightLowerLeg" }, { a = "RightLowerLeg", b = "RightFoot" },
    }
    local BONES_R6 = {
        { a = "Head", b = "Torso" }, { a = "Torso", b = "Left Arm" }, { a = "Torso", b = "Right Arm" },
        { a = "Torso", b = "Left Leg" }, { a = "Torso", b = "Right Leg" },
    }
    local function bonesFor(model)
        return model:FindFirstChild("UpperTorso") and BONES_R15 or BONES_R6
    end
    GV.DefaultProvider = {
        getTargets = function(esp)
            local svc = esp.Services
            local out = {}
            local lp = svc.Players.LocalPlayer
            local localTeam = lp and lp.Team
            local teamCheck = esp:_flag("TeamCheck", false)
            for _, p in ipairs(svc.Players:GetPlayers()) do
                local char = p.Character
                if char and char ~= (lp and lp.Character) then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    if hum and root and head and hum.Health > 0 then
                        table.insert(out, {
                            model = char, health = hum.Health, maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),
                            root = root, head = head, bones = bonesFor(char), name = p.Name, team = p.Team,
                            weapon = nil, level = nil,
                            isEnemy = (not teamCheck) or (p.Team ~= localTeam),
                        })
                    end
                end
            end
            return out
        end,
    }
end
```
`init.lua` ORDER: `"core/esp_default.lua"` tras `"core/ESP.lua"`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add core/esp_default.lua init.lua test/test_esp_provider.lua
git commit -m "feat: ESP default provider (Players enumeration + R15/R6 bones)"
```

---

## Task 3: Render bundle — box + outline + healthbar + name + distance + tracer

**Files:**
- Modify: `core/ESP.lua` (`_make`, `_update`, `_healthColor`, `_hide`)
- Modify: `test/harness.lua` — `spawnDummy(pos)` helper
- Create: `test/demo_esp.lua` (live)

**Interfaces:**
- Produces: por-target bundle `{box,boxOl,name,dist,hpBg,hpBar,tracer}`. `_update` proyecta con `Workspace.CurrentCamera:WorldToViewportPoint`, dibuja según flags `ESP_Box/Name/Health/Distance/Tracer/MaxDistance`, colores vía `GV.Color.fade`. Health styles (`ESP_HealthStyle`: Barra/Texto/Número/Barra+Texto).

**Nota:** portar `RivalsESP.lua:_make/_update/_healthColor/hide` (líneas 73-214) con: flags `ESP_*` vía `self:_flag`, colores vía `GV.Color.fade(self.Flags,"ESP_BoxColor",tick())` etc, targets vía `self:_provget()` (Target normalizado, ya trae `root/head/health/maxHealth/name`), health text/número agregado.

- [ ] **Step 1: Add `spawnDummy` to harness** — en `test/harness.lua` antes de `GV.T = T`:

```lua
    function T.spawnDummy(cf)
        local m = Instance.new("Model"); m.Name = "ESPDummy"
        local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2,2,1); hrp.Anchored = true; hrp.CanCollide = false; hrp.CFrame = cf or CFrame.new(0,5,-15); hrp.Parent = m
        local head = Instance.new("Part"); head.Name = "Head"; head.Size = Vector3.new(1,1,1); head.Anchored = true; head.CanCollide = false; head.CFrame = hrp.CFrame * CFrame.new(0,2.5,0); head.Parent = m
        local hum = Instance.new("Humanoid"); hum.Parent = m
        m.Parent = workspace
        return m
    end
```

- [ ] **Step 2: Write the live demo** — `test/demo_esp.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local cam = workspace.CurrentCamera
local dummy = T.spawnDummy(cam.CFrame * CFrame.new(0, 0, -18))  -- 18 studs al frente
-- provider que devuelve el dummy
local prov = { getTargets = function(esp)
    local hum = dummy:FindFirstChildOfClass("Humanoid")
    return { { model = dummy, health = 60, maxHealth = 100, root = dummy.HumanoidRootPart, head = dummy.Head,
        bones = {}, name = "Dummy", team = nil, isEnemy = true } }
end }
local e = GV.ESP.new({ provider = prov, flags = {} })
e:Set("ESP_Enabled", true); e:Set("ESP_Box", true); e:Set("ESP_Health", true); e:Set("ESP_Name", true); e:Set("ESP_Distance", true)
e:Init()
task.wait(0.4)
local b = e.Objects[dummy]
print("[TEST] bundle creado -> " .. ((b and b.box.Visible) and "PASS" or "FAIL"))
print("[TEST] box size Y>0 -> " .. ((b and b.box.Size.Y > 0) and "PASS" or "FAIL"))
e:Unload(); dummy:Destroy()
print("[TEST] demo_esp DONE")
```

- [ ] **Step 3: Implementation** — en `core/ESP.lua`, agregar `_make/_hide/_healthColor/_update` (port de RivalsESP con Target normalizado + Color.fade + health styles). Reemplazar el `_update` vacío. (Ver RivalsESP.lua para la geometría base; usar `self:_provget()` como fuente de targets; `head`/`root` vienen del Target.)

- [ ] **Step 4: Run demo live** — sync + `execute-file` demo_esp.lua. Expected: `bundle creado PASS`, `box size Y>0 PASS`. Screenshot Baseplate opcional (box visible sobre el dummy). Iterar hasta limpio.

- [ ] **Step 5: Commit**

```bash
git add core/ESP.lua test/harness.lua test/demo_esp.lua
git commit -m "feat: ESP render bundle (box/outline/healthbar/name/dist/tracer)"
```

---

## Task 4: Skeleton + headdot + look-direction + off-screen arrows

**Files:**
- Modify: `core/ESP.lua` (extender `_make` + `_update`)
- Modify: `test/demo_esp.lua` (asserts nuevos)

**Interfaces:**
- Produces: skeleton (líneas por `bones` del Target, `ESP_Skeleton`+color), headdot (círculo sobre head, `ESP_HeadDot`), lookdir (línea desde head hacia `head.CFrame.LookVector`, `ESP_LookDir`), off-screen arrows (cuando el target está fuera de pantalla: flecha en el borde apuntando, `ESP_OffScreen`). Colores vía `GV.Color.fade`.

- [ ] **Step 1: Add asserts** al `demo_esp.lua` (bones no vacío para skeleton): pasar `bones` R15 reales del provider del dummy o un par simple; assert `b.skeleton` líneas visibles. Off-screen: mover cámara mirando al revés → assert arrow visible.

- [ ] **Step 2: Implementation** — extender `_make` (agregar `skeleton={}` lazy por-hueso, `headdot` Circle, `look` Line, `arrow` Triangle/Line) y `_update` (dibujar skeleton con `WorldToViewportPoint` de cada parte del par; headdot en head proyectado; look = head→head+LookVector*2; arrow cuando `onScreen==false` → dirección desde centro pantalla al punto proyectado clampeado al borde).

- [ ] **Step 3: Run demo live** — Expected asserts skeleton/headdot/offscreen PASS.

- [ ] **Step 4: Commit**

```bash
git add core/ESP.lua test/demo_esp.lua
git commit -m "feat: ESP skeleton + headdot + look-dir + off-screen arrows"
```

---

## Task 5: Chams (Highlight) + color modes + visibility raycast + filtros

**Files:**
- Modify: `core/ESP.lua` (`_chams`, `_colorFor`, `_visible`, filtros en `_update`)
- Create: `test/test_esp_filters.lua`

**Interfaces:**
- Produces: `ESP_Chams` (Highlight por-target en `self.Highlights[model]`, `FillColor/OutlineColor` vía Color.fade, `DepthMode` por `ESP_ChamsDepthMode`, `FillTransparency`), `_colorFor(target, base)` (mode Fijo/Team/Visibilidad/Distancia → color), `_visible(root)` (raycast cámara→root, ignora char local), filtros `MaxDistance/PlayersOnly/TeamCheck/DeadCheck/MaxTargets`.

- [ ] **Step 1: Write the failing test** — `test/test_esp_filters.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local e = GV.ESP.new({ flags = {} })
-- color mode Team: enemigo rojo / aliado verde (via _colorFor)
e:Set("ESP_ColorMode", "Team")
e:Set("ESP_BoxColor", Color3.fromRGB(255,255,255))
local cEnemy = e:_colorFor({ isEnemy = true }, "ESP_BoxColor")
local cAlly  = e:_colorFor({ isEnemy = false }, "ESP_BoxColor")
T.truthy(cEnemy ~= cAlly, "team mode: enemigo != aliado")
-- filtro dead
e:Set("ESP_DeadCheck", true)
T.truthy(e:_passFilters({ health = 0, root = nil }) == false, "dead filtrado")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL (`_colorFor` nil).

- [ ] **Step 3: Implementation** — agregar a `core/ESP.lua`:
```lua
    local TEAM_ENEMY, TEAM_ALLY = Color3.fromRGB(235,64,52), Color3.fromRGB(64,200,96)
    function ESP:_colorFor(target, base)
        local mode = self:_flag("ColorMode", "Fijo")
        if mode == "Team" then return target.isEnemy and TEAM_ENEMY or TEAM_ALLY end
        if mode == "Visibilidad" then
            return target._visible and GV.Color.fade(self.Flags, "ESP_VisibleColor", tick()) or GV.Color.fade(self.Flags, "ESP_HiddenColor", tick())
        end
        -- Fijo / Distancia -> el color base con fade
        return GV.Color.fade(self.Flags, base, tick())
    end
    function ESP:_passFilters(t)
        if self:_flag("DeadCheck", false) and (t.health or 0) <= 0 then return false end
        return true
    end
    -- _chams(target): crea/actualiza Highlight en self.Highlights[model]; _visible(root): raycast LOS
```
`_chams` y `_visible` completos (Highlight fill/outline Color.fade; raycast con `RaycastParams` ignorando char local). Integrar filtros `MaxDistance/PlayersOnly/MaxTargets` en `_update` (contar hasta `ESP_MaxTargets`).

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 2/2`. Demo live: activar Chams sobre el dummy → `e.Highlights[dummy]` existe.

- [ ] **Step 5: Commit**

```bash
git add core/ESP.lua test/test_esp_filters.lua
git commit -m "feat: ESP chams (Highlight) + color modes + visibility + filters"
```

---

## Task 6: Object ESP + preview mode

**Files:**
- Modify: `core/ESP.lua` (`_updateObjects`, `RenderPreview`)
- Modify: `test/demo_esp.lua`

**Interfaces:**
- Produces: `_updateObjects()` (enumera `self._objectSources` = `{{tag|classFilter,name,color,maxDistance}}` → box+name+dist), `ESP:RenderPreview(viewportCam, model)` (dibuja box/skeleton de UN modelo con cámara de ViewportFrame — para §D).

- [ ] **Step 1: Add demo assert** — object ESP con un source tag de prueba; preview con la cámara real como stand-in → `RenderPreview` no crashea y dibuja.

- [ ] **Step 2: Implementation** — `_updateObjects` (por source: `CollectionService:GetTagged(tag)` o scan por clase; box+name+dist reusando `_draw`); `RenderPreview(cam, model)` (proyección con `cam:WorldToViewportPoint`, box+skeleton del model; usado por el preview de §D).

- [ ] **Step 3: Run demo live** — Expected object/preview asserts PASS, sin crash.

- [ ] **Step 4: Commit**

```bash
git add core/ESP.lua test/demo_esp.lua
git commit -m "feat: ESP object ESP + preview render mode"
```

---

## Task 7: schema/esp.lua (CF colores) + Rivals provider + wiring suite

**Files:**
- Create: `schema/esp.lua`
- Modify: `games/rivals.lua` (agregar `.esp`)
- Modify: `init.lua` (ORDER: `schema/esp.lua` tras `schema/world.lua`), `build.lua` (ORDER + `GV._defaultModules={"world","esp"}`)
- Create: `test/test_esp_schema.lua`

**Interfaces:**
- Produces: `GV.Modules.esp.schema` con tabs "ESP" + "ESP Colores". Cada color = `GV.CF`. `GV.Profiles.rivals.esp = { provider = {getTargets=...tag Entity...}, objectSources = {...} }`.

- [ ] **Step 1: Write the failing test** — `test/test_esp_schema.lua`

```lua
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Modules.esp.schema
T.truthy(S and #S > 30, "esp schema >30 (#" .. tostring(S and #S) .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag) end end
T.truthy(ok, "deps resueltas")
T.truthy(flags["ESP_Enabled"] and flags["ESP_BoxColor"] and flags["ESP_BoxColor_Fade"], "flags clave + CF")
T.truthy(GV.Profiles.rivals.esp and GV.Profiles.rivals.esp.provider, "rivals.esp provider")
T.report()
```

- [ ] **Step 2: Run to verify it fails** — Expected FAIL.

- [ ] **Step 3: Implementation** — `schema/esp.lua`: builder (add/addCF) cubriendo el inventario §B.4 del spec (Box/Health/Info/Tracer/Skeleton/Head/Chams/OffScreen/Color/Filtros/Object/Prefs). Tabs "ESP" (features) + "ESP Colores" (los `CF`). Registrar `GV.Modules.esp.schema`. En `games/rivals.lua` agregar `GV.Profiles.rivals.esp = { provider = { getTargets = function(esp) ...CollectionService:GetTagged("Entity")..., dummies FFA... end }, objectSources = { {tag="Grenade",name="Granada",...}, {tag="Trap",name="Trampa",...} } }`. `init.lua`+`build.lua` ORDER + `_defaultModules`.

- [ ] **Step 4: Run to verify it passes** — Expected `SUMMARY 4/4`.

- [ ] **Step 5: Commit**

```bash
git add schema/esp.lua games/rivals.lua init.lua build.lua test/test_esp_schema.lua
git commit -m "feat: ESP schema (CF colors) + Rivals provider + suite wiring"
```

---

## Task 8: Demos suite (world+esp) ambas UIs + regenerar dist + regresión

**Files:**
- Modify: `test/demo_suite.lua` (montar `modules={"world","esp"}`, verificar tab ESP + provider default enumera)
- Modify: `test/run_all.lua` (agregar tests ESP)
- Regenerar `dist/Visuals.<lib>.lua`

- [ ] **Step 1: Demo suite ambas UIs** — `demo_suite.lua` monta `{"world","esp"}` en ClaudeUI y Primordial; verifica que el tab "ESP" renderiza (widget count sube) y que con `ESP_Enabled` + provider default se crea al menos 1 bundle si hay otro player/dummy. (Spawnear dummy + provider default lo toma.)

- [ ] **Step 2: Regenerar dist** — `build(GV,"claudeui"); build(GV,"primordial")` → copiar a `dist/`.

- [ ] **Step 3: Actualizar `run_all.lua`** — agregar `"test_esp_core"`, `"test_esp_provider"`, `"test_esp_filters"`, `"test_esp_schema"`.

- [ ] **Step 4: Run regresión** live. Expected: todos `SUMMARY p/p`, 0 FAIL/CRASH. Demos ambas UIs limpias.

- [ ] **Step 5: Commit**

```bash
git add test/demo_suite.lua test/run_all.lua dist/
git commit -m "feat: ESP live demos both UIs + dist regen + regression green"
```

---

## Self-Review

**Spec coverage (§B):** core Drawing (T1) ✓, entity-provider default+Target shape (T2) ✓, box/health/name/dist/tracer (T3) ✓, skeleton/headdot/lookdir/offscreen (T4) ✓, chams Highlight + color modes + visibility + filtros (T5) ✓, object ESP + preview mode (T6) ✓, schema CF + Rivals provider + wiring (T7) ✓, demos+regresión (T8) ✓. Health styles (barra/texto/número) en T3. `ESP_MaxTargets` perf en T5.

**Placeholder scan:** los "port de RivalsESP" (T3/T4) referencian el archivo fuente concreto (`Scripts/Rivals/RivalsESP.lua` líneas citadas) + las adiciones específicas (Target normalizado, Color.fade, health styles) — no es placeholder, es reuso dirigido. Inventario schema T7 referencia §B.4 del spec (lista cerrada).

**Type consistency:** `ESP.new({services,flags,provider})`, `_flag("X")` (prefijo ESP_), `_provget()→Targets`, `Target{model,health,maxHealth,root,head,bones,name,team,weapon,level,isEnemy}` consistente entre provider (T2) y render (T3-T6). `GV.Modules.esp.{new,schema}`, `GV.DefaultProvider.getTargets`, `_colorFor/_passFilters/_chams/RenderPreview` consistentes. `GV.Color.fade(self.Flags, "ESP_X", tick())` = mismos flags que `CF` genera (T7). Attach (§0) monta esp vía `GV.Modules.esp` + `prof.esp`.
