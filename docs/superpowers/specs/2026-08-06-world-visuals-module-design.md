# World Visuals Module — Design Spec

**Fecha:** 2026-08-06
**Estado:** aprobado (diseño), pendiente review de spec por el usuario
**Ubicación:** `Scripts/GUIWorkspace/`

---

## 1. Objetivo

Construir el módulo de **World Visuals** más completo para Roblox: manipulación clientside de `Lighting`, `Atmosphere`, post-efectos, cielo/nubes, terrain/agua y clima local. Requisitos:

- **Game-agnostic:** corre en cualquier juego Roblox. Lo específico de un juego (Rivals) vive en un perfil aparte.
- **Dual-UI:** un solo árbol de fuente produce dos builds cargables — uno para **ClaudeUI** (lib Drawing-API, retained, 0 instancias, en `Scripts/Rivals/RivalsUI.lua`, repo `T-Raxx/ClaudeUI`) y otro para **PrimordialUI** (lib instance-based, en `Escritorio/PrimordialUI/`, repo `T-Raxx/PrimordialUI`).
- **Base reutilizable:** primer módulo de una suite de visuals (World → ESP → Local en fases futuras). La arquitectura debe escalar.
- **Cero hooks:** solo escribe propiedades de `Lighting`/`Terrain` y crea efectos propios. Nada detectable por scan de árbol si el módulo no está cargado.

Sub-proyecto 1 de la suite completa de visuals. ESP y Local visuals son specs separados posteriores.

## 2. Decisión de arquitectura: Schema + Facade

Elegida sobre (a) core + 2 BuildUI a mano y (b) 2 forks por workspace. Razón: única que hace barato mantener "completo al detalle, en 2 UIs, reutilizable" — la UI no se escribe dos veces; agregar un feature = 1 fila de schema + 1 rama de apply; el schema **es** el checklist exhaustivo.

Viabilidad verificada: ambas libs comparten el set de widgets Toggle/Slider/Dropdown/ColorPicker/Label + dependencias. Solo difiere la estructura de contenedores, que absorbe el adapter.

## 3. Capas y contratos

### `core/World.lua` — lógica pura
- Dueña de `World.Flags` (única fuente de verdad del estado). **No lee la Library nunca**; la UI es solo dispositivo de entrada.
- API: `World:Set(flag,v)`, `World:Get(flag)`, `World:GetFlags()`, `World:LoadFlags(tbl)`, `World:Init()`, `World:Unload()`, `World:UseProfile(profileTbl)`.
- Contiene todas las funciones apply A–K (§6).
- Reusa patrones probados de `RivalsVisuals.lua` (build 0.7):
  - `_set(obj,prop,val)` — **escritura con memoria**: guarda el original la primera vez, escribe solo si difiere. Le gana al `LightingController` del juego (que re-aplica por evento, no por frame) sin pelear cada frame.
  - `_restoreAll()` — devuelve todo lo tocado a su valor original.
  - `_fx(class,parent)` — crea (una vez) un efecto propio, nombrado como los del juego para no cantar en scan.
  - `_wxRig()` — part+emitter de clima anclado sobre la cámara.

### `core/util.lua` — helpers compartidos
- Ser/deser Color3 y EnumItem para config (gotcha `JSONEncode` con userdata/keys mixtas).
- Clamp, lerp, color helpers. Compartido con módulos futuros (ESP/Local).

### `schema/world.lua` — declarativo (el checklist exhaustivo)
Array ordenado. Cada fila:
```lua
{ tab="Mundo", group="Lighting", side="Left",
  flag="World_Fullbright", type="toggle", text="Fullbright",
  default=false, dependsOn="World_Enabled", tooltip="..." }
```
Campos por tipo: `min/max/decimals/suffix` (slider), `values/multi/searchable` (dropdown), `header` (label), `master=true` (toggle maestro). Orden del array = orden de render.

### `ui/facade.lua` — contrato neutral + validador
Interfaz que todo adapter implementa:
```
Tab(window, name, icon)                -> tabHandle
Group(tabHandle, name, side)           -> groupHandle
Widget(groupHandle, kind, flag, opts, parentHandle) -> widgetHandle
Depend(widgetHandle, flag, value)      -> void
```
`kind` ∈ {toggle, slider, dropdown, colorpicker, label}. Un validador asegura que el adapter tenga los 4 métodos antes de renderizar.

### `ui/adapter_claudeui.lua`
- Tab → `Window:AddTab(name)`
- Group(Left) → `Tab:AddLeftGroupbox(name)`; (Right) → `AddRightGroupbox`
- Widget → `groupHandle:AddToggle/AddSlider/AddDropdown/AddColorPicker/AddLabel(flag, opts)`
- Dependencia: nesting nativo → si viene `parentHandle`, usa `parentHandle:AddX(...)` en vez de `groupHandle:AddX(...)`. `Depend` es no-op (ya se nesteó al crear).

### `ui/adapter_primordial.lua`
- Tab → `Window:AddCategory(name, icon)` + un `AddSection(name)` interno
- Group(Left) → `Section:AddPanel(name,{Column=1})`; (Right) → `{Column=2}`
- Widget → `panel:AddToggle/AddSlider/...(flag, opts)`
- Dependencia: `Depend(widget, flag, val)` → `widget:DependsOn(flag, val)`

### `ui/renderer.lua`
`renderer.build(adapter, window, schema, core)`:
1. Itera schema en orden; mantiene tab/group actuales; crea vía adapter.
2. Por control: siembra `default` en `core.Flags` si no está; setea `opts.Default = core:Get(flag)`; `opts.Callback = function(v) core:Set(flag,v) end`.
3. Mapa `flag→handle` para resolver `dependsOn` (parentHandle en ClaudeUI, `Depend` en Primordial).
4. Devuelve handles para unload.

### `games/rivals.lua` — perfil
Texture ids (lluvia/nieve: `rbxassetid://13911374915` streaks, `rbxassetid://15414665346` dots), defaults override, filtro de parts para bloque J (excluir skybox/char propio), controles Rivals-only, awareness del `LightingController` (el `_set` con memoria ya lo maneja genérico; el perfil solo ajusta defaults/texturas). `games/_template.lua` = perfil en blanco.

### `entry/attach.lua` — glue
```lua
World:Attach(Library, Window, { profile = "rivals" })
```
Elige adapter (horneado en el dist), aplica perfil, corre renderer sobre el Window, `Init`. Devuelve handle para unload. Uso desde el host:
```lua
local World = loadstring(game:HttpGet(".../World.ClaudeUI.lua"))()
local w = World:Attach(Library, Window, { profile = "rivals" })
-- ...
w:Unload()
```

### `init.lua` / `build.lua` — dev-loader + bundler
Patrón probado de PrimordialUI: cada módulo es `return function(ctx) ... end` mutando tabla compartida, **nunca `require`**. `init.lua` los carga vía `readfile` desde el workspace del executor (dev/test). `build.lua` (corre en executor) concatena a `dist/World.<lib>.lua`, con un flag que selecciona el adapter (ClaudeUI vs Primordial). Dos salidas.

**Gotcha executor:** `readfile` de Potassium resuelve en `AppData\Local\Potassium\workspace\`, NO en el repo de Escritorio. Antes de cada test hay que sync repo→workspace.

## 4. Data flow

```
widget cambia -> adapter Callback -> World:Set(flag,v)
   -> proximo RenderStepped _step -> _flag lee World.Flags
   -> _set(Lighting, prop, val)  (escribe solo si difiere)
   -> visible
toggle-off / unload -> _restoreAll -> valores originales
```

Config del host persiste vía `World:GetFlags()` / `World:LoadFlags(tbl)`. `World_Enabled` maestro gatea todo el step (excepto FX de menú, que no aplican a World).

## 5. Manejo de errores

- `_step` envuelto en pcall (warn, no crash).
- `_set`/`_fx` con pcall — props de `Lighting`/`Terrain` pueden faltar según el juego (ej. sin `Clouds` si no hay Terrain).
- Restore garantizado: memoria `_orig` + lista `_made` (instancias creadas se destruyen en Unload).
- Renderer valida el facade del adapter antes de construir; tipo de widget no soportado por una lib → warn + skip (degradación suave).
- **Atmosphere:** su sola presencia anula `FogStart/FogEnd/FogColor`. `Density=0` no alcanza → se **destruye** el objeto al apagar, no se pone en 0 (bug histórico "fog no funciona").

## 6. Inventario exhaustivo A–K (contenido de `schema/world.lua`)

Prefijo de flag: `World_`. Maestro: `World_Enabled` (keybind). ✓ = ya existe en RivalsVisuals; ✚ = nuevo.

### Tab "Mundo"

**A. Lighting core** — grupo Left "Lighting"
| flag | tipo | rango/default | | 
|---|---|---|---|
| World_Enabled | toggle | false, keybind, master | ✓ |
| World_Fullbright | toggle | false | ✓ |
| World_NoShadows | toggle | false | ✓ |
| World_Ambient | colorpicker | 120,120,125 | ✓ |
| World_OutdoorAmbient | colorpicker | 120,120,125 | ✚ (hoy espejo de Ambient) |
| World_Brightness | slider | 0–10, 3 | ✓ |
| World_Exposure | slider | -3–3, 0 | ✓ |
| World_ColorShiftTop | colorpicker | 0,0,0 | ✚ |
| World_ColorShiftBottom | colorpicker | 0,0,0 | ✚ |
| World_EnvDiffuse | slider | 0–5, 1 | ✚ |
| World_EnvSpecular | slider | 0–5, 1 | ✚ |
| World_Technology | dropdown | Voxel/ShadowMap/Future/Legacy | ✚ |
| World_GeoLatitude | slider | -90–90, 41.7 | ✚ |

**B. Tiempo / Sol** — grupo Left "Tiempo / Sol"
| World_ClockTime | slider | 0–24, 12, "h" | ✓ |
| World_UseTimeOfDay | toggle | false | ✚ |
| World_FreezeTime | toggle | false | ✚ |
| World_DayNightCycle | toggle | false | ✚ |
| World_CycleSpeed | slider | 0.1–10, 1, "x", dep DayNightCycle | ✚ |
| World_Preset (Día/Noche/Atardecer) | dropdown+button | ✚ |

**C. Fog** — grupo Right "Fog"
| World_NoFog | toggle | false | ✓ |
| World_FogStart | slider | 0–2000, 0, "st" | ✓ |
| World_FogEnd | slider | 100–10000, 2500, "st" | ✓ |
| World_FogColor | colorpicker | 190,195,210 | ✓ |

**D. Atmosphere** — grupo Right "Atmosphere"
| World_Atmosphere | toggle | false | ✓ |
| World_AtmDensity | slider | 0–1, 0.3, dep | ✓ |
| World_AtmOffset | slider | 0–1, 0.25, dep | ✓ |
| World_AtmGlare | slider | 0–10, 0, dep | ✓ |
| World_AtmHaze | slider | 0–10, 0, dep | ✓ |
| World_AtmColor | colorpicker | 199,199,199, dep | ✓ |
| World_AtmDecay | colorpicker | 106,112,125, dep | ✓ |

**E. Post-FX** — grupo Right "Post-FX"
| World_Tint | toggle | false | ✓ |
| World_TintBrightness/Contrast/Saturation | slider | dep | ✓ |
| World_TintColor | colorpicker | dep | ✓ |
| World_Bloom | toggle + Intensity/Size/Threshold | ✓ |
| World_SunRays | toggle + Intensity/Spread | ✓ |
| World_DoF | toggle + FocusDistance/InFocusRadius/NearIntensity/FarIntensity | ✚ |
| World_WorldBlur | toggle + Size | ✚ |
| World_KillGamePostFX | toggle (limpia CC/Blur/Bloom que mete el juego) | ✚ |
| World_RainbowHue | toggle + Speed (anima hue de ambient/tint) | ✚ |

**J. Visibilidad (agresivo)** — grupo Left "Visibilidad", tras toggle World_Advanced
| World_KillParticles | toggle (mata todos los ParticleEmitter/Beam del mapa — anti-flash global) | ✚ |
| World_ForceSmoothPlastic | toggle (Material SmoothPlastic — low-detail/perf) | ✚ |
| World_MapTransparent | toggle + amount (x-ray por transparencia; usa filtro del perfil) | ✚ |
| World_NoTextures | toggle (limpia Texture/Decal de parts) | ✚ |

### Tab "Cielo & Clima"

**F. Cielo / Celestial** — grupo Left "Cielo"
| World_NoSky | toggle | false | ✓ |
| World_StarCount | slider | 0–5000, 3000 | ✓ (hoy binario) |
| World_CustomSkybox | toggle | false | ✚ |
| World_Skybox_Up/Dn/Lf/Rt/Bk/Ft | textbox (assetId) | dep CustomSkybox | ✚ |
| World_SunTextureId / MoonTextureId | textbox | dep | ✚ |
| World_SunAngularSize / MoonAngularSize | slider | dep | ✚ |

**G. Nubes (Terrain.Clouds)** — grupo Left "Nubes"
| World_Clouds | toggle | false | ✓ |
| World_NoClouds | toggle | dep | ✓ |
| World_CloudCover | slider | 0–1, 0.5, dep | ✓ |
| World_CloudDensity | slider | 0–1, 0.7, dep | ✓ |
| World_CloudColor | colorpicker | 255,255,255, dep | ✓ |

**H. Terrain / Agua** — grupo Right "Terrain / Agua"
| World_WaterEnable | toggle | false | ✚ |
| World_WaterColor | colorpicker | dep | ✚ |
| World_WaterTransparency | slider | 0–1, dep | ✚ |
| World_WaterReflectance | slider | 0–1, dep | ✚ |
| World_WaterWaveSize | slider | 0–1, dep | ✚ |
| World_WaterWaveSpeed | slider | 0–20, dep | ✚ |
| World_TerrainDecoration | toggle | ✚ |

**I. Clima local** — grupo Right "Clima"
| World_Weather | toggle | false, keybind | ✓ |
| World_WeatherMode | dropdown | Lluvia/Lluvia fuerte/Nieve **/Niebla/Ceniza/Luciérnagas/Custom** | ✓+✚ |
| World_WeatherColor/Transparency/Glow/Density/Speed/Size/Area | slider/cp | dep | ✓ |
| World_WeatherCustomTex | textbox (assetId, dep Mode=Custom) | ✚ |
| World_WeatherWindDir | slider (0–360) | ✚ |
| World_Lightning | toggle (flash de relámpago sincronizado, dep) | ✚ |

**K. Presets** — grupo Right "Presets"
| World_PresetSelect | dropdown | Competitivo/Cinematográfico/Día/Noche/Atardecer/Niebla | ✚ |
| aplicar | button | ✚ |
| guardar preset propio | button + textbox | ✚ |

## 7. Testing (MCP live)

Por cada función apply: `roblox-executor-mcp` → set flag → step → leer de vuelta la prop (`World_Fullbright` → `Lighting.Brightness==1` y `Ambient==255,255,255`). `test/demo_claudeui.lua` (RivalsUI en Rivals/Baseplate) y `test/demo_primordial.lua` (PrimordialUI en Potassium workspace). Verificar: carga limpia, tab renderiza en ambas UIs, cada control mueve su prop, `_restoreAll` en unload deja todo como estaba. Screenshot en Baseplate (Rivals captura blanco por render protegido → validar por data).

## 8. Fuera de alcance (fases futuras)

- Módulo **ESP** (player/entity/object): box/healthbar/skeleton/chams/tracers/off-screen — spec propio.
- Módulo **Local/Self**: viewmodel, FOV, 3ra persona, anti-flash local, crosshair, HUD — spec propio.
- Config UI del host (save/load con nombre) — el módulo expone `GetFlags/LoadFlags`; la persistencia la maneja el script host.

## 9. Orden de implementación (para el plan)

1. Andamiaje: dirs, `init.lua`, `build.lua`, `facade.lua` + validador, esqueleto `core/World.lua` (Flags/Set/Get/Init/Unload + `_set`/`_restoreAll`/`_fx`).
2. `schema/world.lua` con A–D (core lighting + fog + atmosphere) — el subconjunto más probado.
3. `renderer.lua` + `adapter_claudeui.lua`; demo ClaudeUI live; verificar A–D.
4. `adapter_primordial.lua`; demo Primordial live; verificar A–D en la 2da UI.
5. Resto del schema E–K + ramas apply, incrementales, cada una verificada live.
6. `games/rivals.lua` perfil + bloque J con filtro.
7. `build.lua` → 2 dist; smoke test de ambos dist cargados por HttpGet.
