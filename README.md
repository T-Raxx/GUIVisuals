# Visuals Suite

Módulo de **visuals game-agnostic** para Roblox, reutilizable como base para futuros scripts. Un solo árbol de fuente → 2 builds cargables: **ClaudeUI** (Drawing API, 0 instancias, HvH-safe) y **PrimordialUI** (instance-based).

Módulos: **World** (lighting/fog/atmosphere/post-FX/cielo/terrain/clima) · **ESP** (box/health/skeleton/headdot/tracer/offscreen/chams/object) · **Local/Self** (FOV/aspect/crosshair/hitmarker/HUD/keybind-list/anti-flash/self-chams) · **Preview** (viewport del char, solo PrimordialUI). Cada color tiene **ColorFade** (1 colorpicker + fade opcional a un 2º color).

## Probar (loadstring)

**ClaudeUI** (Drawing, 0 instancias — menú = RightShift):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/Loader.ClaudeUI.lua"))()
```

**PrimordialUI** (instance-based — incluye Preview):
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/Loader.Primordial.lua"))()
```

Unload: `getgenv().Visuals.suite:Unload()`  (y `getgenv().Visuals.lib:Unload()` para la UI).

## Orden de contenidos de la UI

Ambas UIs renderizan el **mismo schema** (mismos tabs/grupos/orden). Un flag compartido con prefijos `World_ / ESP_ / Local_ / Suite_`.

- **Mundo**: `Suite` (Velocidad fade, Preview) · `Lighting` · `Tiempo / Sol` · `Visibilidad` (izq) — `Fog` · `Atmosphere` · `Post-FX` (der)
- **Cielo & Clima**: `Cielo` · `Nubes` (izq) — `Terrain / Agua` · `Clima` · `Presets` (der)
- **ESP**: `General` · `Extras` (izq) — `Chams (detectable)` · `Color / Visibilidad` · `Filtros` · `Object ESP` · `Prefs` (der)
- **ESP Colores**: `Colores` · `Chams` · `Visibilidad`
- **Local**: `Camara` · `Crosshair` (izq) — `Hitmarker` · `HUD` · `Extras` (der)
- **Local Colores**: `Colores`

## Usar como base para un script nuevo

```lua
-- Cargá la UI lib que prefieras, creá el Window, y montá la suite:
local suite = Visuals.Attach(Library, Window, {
    modules = { "world", "esp", "selffx" },  -- cuáles montar (default: los 3)
    profile = nil,                            -- nil = genérico (game-agnostic)
})
-- suite.flags = tabla de flags compartida;  suite:Unload()
```

- **Sin `profile`** = 100% genérico: ESP enumera `Players` (bones R15/R6), SelfFX usa `Camera.FieldOfView`/crosshair/HUD genéricos, World escribe `Lighting`.
- **Con perfil de juego** (`games/<juego>.lua`) agregás lo específico: entity-provider del ESP, hooks de SelfFX (setFOV/setThirdPerson/flashEffects/hitSignal/keybinds), texturas, etc. **`games/_template.lua` = contrato base para copiar.** `games/rivals.lua` = ejemplo.

## Arquitectura

`core/{util,color,World,ESP,esp_default,selffx}` (lógica pura, servicios inyectables) · `schema/{_helpers,world,esp,local}` (data, 1 fila por control, CF para colores) · `ui/{facade,renderer,preview,adapter_claudeui,adapter_primordial}` · `games/{rivals,_template}` · `entry/attach.lua` · `build.lua` (bundler → `dist/Visuals.<lib>.lua`) · `init.lua` (dev-loader).

Convención de módulo: cada `.lua` es `return function(GV) ... end` (sin `require`). Testing: TDD vía executor (`test/`, `test/run_all.lua`).

Specs y planes en `docs/superpowers/`.
