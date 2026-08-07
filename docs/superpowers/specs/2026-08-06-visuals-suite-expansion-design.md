# Visuals Suite Expansion — Design Spec (ColorFade + ESP + Local/Self + Preview)

**Fecha:** 2026-08-06
**Estado:** aprobado (diseño), pendiente review de spec
**Ubicación:** `Scripts/GUIWorkspace/`
**Precede:** [World Visuals module](2026-08-06-world-visuals-module-design.md) (implementado, merged)

---

## 0. Evolución: World module → Visuals Suite

Hoy `entry/attach.lua` monta solo World. Se generaliza a un **registro de módulos** para que World, ESP y Local/Self convivan bajo un mismo menú y un mismo dist por lib.

- **`GV.Modules[name] = { new = fn, schema = tbl }`** — cada módulo se auto-registra (World, ESP, Local).
- **`GV.Attach(Library, Window, opts)`** — `opts.modules` (default `{"world","esp","local"}`), `opts.profile`, `opts.services`. Itera módulos: construye el schema de cada uno en el Window (cada módulo aporta su(s) tab(s)), aplica perfil, `Init`. Devuelve un **handle de suite** `{ modules = {world=,esp=,local=}, Unload = fn }`.
- **Un dist por lib**: `dist/Visuals.ClaudeUI.lua` y `dist/Visuals.Primordial.lua` (World deja de tener dist propio; pasa a ser un módulo). El bundler concatena core+util+color+World+ESP+Local+facade+renderer+adapter+schemas+profiles+attach.
- **Cero cambios** en `facade.lua`, `renderer.lua`, `adapter_*`. La infra schema+facade se reusa tal cual.
- Compat: `World:Attach` viejo se mantiene como alias que llama `Attach` con `modules={"world"}`.

## A. ColorFade infra (foundational — la consume todo)

Requisito: **cada elemento coloreado** tiene 1 colorpicker default (siempre visible) + un fade opcional (2º colorpicker + toggle). Aplica a ESP, Local **y retrofit de World**.

### A.1 Core `core/color.lua` → `GV.Color`
- `Color.fade(flags, base, t)` → si `flags[base.."_Fade"]` es true: `c1:Lerp(c2, (math.sin(t * speed * 2π) + 1) / 2)` donde `c1=flags[base]`, `c2=flags[base.."_2"]`, `speed=flags["Suite_FadeSpeed"] or 1`; si no: `c1`. `t` = `tick()` (o el time del step).
- **Guarda:** si `typeof(c1) ~= "Color3"` (flag no sembrada) → devuelve blanco `Color3.new(1,1,1)` (nunca Lerp sobre nil). Igual para `c2` en modo fade (si falta, no fade).
- `Color.solid(flags, base)` → `flags[base]` con la misma guarda (para elementos sin fade).

### A.2 Schema helper `CF{...}` (en `schema/_helpers.lua` → `GV.SchemaHelpers.CF`)
Expande una spec de color a **3 filas**:
```lua
CF{ base="ESP_BoxColor", text="Box", tab="ESP", group="Colores", side="Left",
    default=C(235,235,240), default2=C(96,130,255), dependsOn="ESP_Box" }
-- ->
{ ..., flag="ESP_BoxColor",       type="colorpicker", text="Box",        default=C1, dependsOn="ESP_Box" }
{ ..., flag="ESP_BoxColor_Fade",  type="toggle",      text="Box fade",   default=false, dependsOn="ESP_Box" }
{ ..., flag="ESP_BoxColor_2",     type="colorpicker", text="Box color 2", default=C2, dependsOn="ESP_BoxColor_Fade" }
```
Los schemas construyen sus filas de color con `CF(...)` en vez de una fila colorpicker suelta.

### A.3 Global
- `Suite_FadeSpeed` (slider 0.1–5, default 1) en un grupo **"Suite"** dentro del tab del primer módulo montado (World → grupo "Suite" side Left, tab "Mundo"). Un solo speed para todos los fades. Se siembra vía una fila de schema propia en `schema/_helpers.lua` que `Attach` inyecta una vez.

### A.4 Retrofit World
Reemplazar las ~10 filas colorpicker de `schema/world.lua` por `CF(...)`: `World_Ambient`, `World_OutdoorAmbient`, `World_FogColor`, `World_AtmColor`, `World_AtmDecay`, `World_TintColor`, `World_CloudColor`, `World_WeatherColor`, `World_WaterColor`, `World_ColorShiftTop`, `World_ColorShiftBottom`. Las apply de `core/World.lua` que leen esos colores pasan a `GV.Color.fade(self.Flags, "World_X", t)`. Sin cambios en adapters.

## B. ESP (`core/ESP.lua`)

Drawing-based, RenderStepped, retained. Estructura espejo de World. **Cero hooks.** Todo color vía `Color.fade`. 0 instancias salvo chams (Highlight, opt-in detectable).

### B.1 Core
- `ESP.new({services, provider})` → instancia. `Init/Unload`, `_update` (RenderStepped), `_draw(class,props)` (Drawing.new retained, va a `_drawings`), bundle por-target (`_make`), `_hide`/reuse, `_flag`.
- Usa `Color.fade(self.Flags, base, t)` para cada color.
- Servicios inyectables (Players/RunService/Workspace/CollectionService) para testear con mocks.

### B.2 Entity-provider (contrato del perfil)
`provider.getTargets()` → lista de **Target normalizado**:
```lua
{ model=Instance, health=n, maxHealth=n, root=BasePart, head=BasePart,
  bones={ {a="Head",b="UpperTorso"}, ... },  -- pares para skeleton (R15/R6)
  name=str, team=any|nil, weapon=str|nil, level=n|nil, isEnemy=bool }
```
- **Default provider** (`core/esp_default.lua`, game-agnostic): enumera `Players:GetPlayers()`, resuelve Humanoid/HRP/Head, boneMap R15 y R6 estándar, `team=Player.Team`, `name=Player.Name`, `isEnemy = TeamCheck and team~=localTeam`. Corre en cualquier juego.
- **Rivals** override (`games/rivals.lua` → `esp` field): tag `"Entity"` (fighters+dummies), FFA (isEnemy=true salvo dummies), arma vía `FighterController._player_to_fighter`, filtro por arena `EnvironmentID`, nivel. `objectSources` (abajo).

### B.3 Object ESP (perfil-driven)
`provider.objectSources` = lista de `{ tag|classFilter, name, color, maxDistance }`. El core enumera esas instancias y dibuja box+name+dist (sin health/skeleton). Rivals: granadas, trampas, loot.

### B.4 Features (inventario completo — todos confirmados)
Prefijo `ESP_`. Maestro `ESP_Enabled` (keybind). Cada color = `CF`.

**Box** — `ESP_Box` (toggle) + `ESP_BoxStyle` (dropdown: 2D/3D/Corner/Filled) + `ESP_BoxColor` (CF) + `ESP_BoxOutline` (toggle) + `ESP_BoxThickness` (slider).
**Health** — `ESP_Health` (toggle) + `ESP_HealthStyle` (dropdown: Barra/Texto/Número/Barra+Texto) + `ESP_HealthColor` (CF; gradiente por vida si off) + posición (izq/der/top).
**Info** — `ESP_Name` (+ `ESP_NameColor` CF, `ESP_NamePos` custom), `ESP_Distance` (+color CF, pos), `ESP_Team` (+color), `ESP_Level`, `ESP_Weapon`. Cada label con **posición custom** (dropdown anchor: Top/Bottom/Left/Right + offset).
**Tracer** — `ESP_Tracer` (toggle) + `ESP_TracerFrom` (dropdown: Bottom/Center/Top/Mouse) + `ESP_TracerColor` (CF) + thickness.
**Skeleton** — `ESP_Skeleton` (toggle) + `ESP_SkeletonColor` (CF) + thickness. Usa `bones` del provider.
**Head** — `ESP_HeadDot` (círculo, +color CF, radio), `ESP_LookDir` (línea dirección de mira, +color CF, largo).
**Chams** — `ESP_Chams` (toggle, ⚠️ **detectable — usa Highlight**, grupo aparte marcado) + `ESP_ChamsFill` (CF), `ESP_ChamsOutline` (CF), `ESP_ChamsFillTransparency`, `ESP_ChamsDepthMode` (AlwaysOnTop/Occluded).
**Off-screen** — `ESP_OffScreen` (flechas, +color CF, radio, tamaño).
**Color/Visibilidad** — `ESP_ColorMode` (dropdown: Fijo/Team/Visibilidad/Distancia) + `ESP_VisibleCheck` (raycast LOS) + `ESP_VisibleColor`/`ESP_HiddenColor` (CF) cuando mode=Visibilidad.
**Filtros** — `ESP_MaxDistance`, `ESP_PlayersOnly`, `ESP_TeamCheck`, `ESP_DeadCheck` (ocultar muertos), `ESP_ArenaOnly` (profile), `ESP_MaxTargets` (perf).
**Object ESP** — `ESP_Objects` (toggle master) + toggles por fuente declarada.
**Prefs** — `ESP_Font`, `ESP_TextSize`, `ESP_Thickness` global.

### B.5 Schema `schema/esp.lua`
Tabs "ESP" (features) + "ESP Colores" (todos los `CF`). Colores agrupados aparte para no saturar. Chams en grupo "Chams (detectable)".

### B.6 Preview mode (para SP-D)
`ESP:RenderPreview(viewportCamera, model)` — dibuja box/skeleton/headdot de UN modelo usando una cámara de ViewportFrame en vez de la del mundo. Reusa la proyección con cámara inyectada.

## C. Local/Self (`core/Local.lua`)

Mezcla de writes de cámara + overlays Drawing. **Cero hooks.** Todo color vía `Color.fade`.

### C.1 Perfil hooks
`provider.selffx = { setThirdPerson(bool), setFOV(offset), viewmodel(tbl), flashEffects()->list, hitSignal->RBXScriptSignal|nil }`. Defaults genéricos: FOV vía `Camera.FieldOfView`; 3ra persona genérica (mover cámara); crosshair/watermark/keybind-list/hitmarker-render 100% genéricos; hitmarker **trigger** necesita `hitSignal` (default nil → hitmarker off). Rivals: `SetExternalFOVOffset`, `SetThirdPersonOverride`, anti-flash (mata CC "Flashbang").

### C.2 Features (inventario)
Prefijo `Local_`. Maestro `Local_Enabled`.

**Cámara** — `Local_FOV` (toggle) + `Local_FOVValue` (slider 40–120) [**FOV changer**]. `Local_ThirdPerson` (toggle) + distancia. `Local_ViewmodelOffset` (X/Y/Z, si el perfil lo soporta).
**Custom Aspect Ratio** — `Local_AspectMode` (dropdown: Off/Vertical/Diagonal/MaxAxis → `Camera.FieldOfViewMode`) + `Local_AspectFOV` (slider, se combina con MaxAxis). ⚠️ **Nota técnica:** Roblox NO permite stretch real del framebuffer sin render-hooks (prohibidos por el diseño no-hooks). Esto aproxima el efecto de aspect cambiando cómo el FOV mapea al eje. El stretch pixel-perfect NO es alcanzable client-side sin hooks. Documentado como limitación.
**Crosshair** (Drawing) — `Local_Crosshair` (toggle) + `Local_CrosshairStyle` (Cross/Dot/Circle/T) + gap/thickness/size + `Local_CrosshairColor` (CF) + outline.
**Hitmarker** (Drawing, dep `hitSignal`) — `Local_Hitmarker` (toggle) + style (X/Cross/Circle) + size/duration + `Local_HitmarkerColor` (CF) + sonido opt.
**HUD / Watermark** (Drawing) — `Local_Watermark` (toggle) + contenido (FPS/ping/nombre/hora) + `Local_WatermarkColor` (CF) + posición custom + `Local_KeybindList` (toggle, lista de keybinds activos) + color CF + posición.
**Anti-flash / anti-smoke** (profile) — `Local_AntiFlash`, `Local_AntiSmoke` (usan `flashEffects()` del perfil; default no-op si el perfil no los provee).
**Self-chams** — `Local_SelfChams` (Highlight sobre el char propio, detectable) + fill/outline CF.

### C.3 Schema `schema/local.lua`
Tabs "Local" (features) + colores en "ESP Colores" compartido o "Local Colores".

## D. Preview viewport (UI-lib feature, ambas libs)

Pane que muestra el **modelo del char local** (clon) sobre **fondo matrix oscuro**, con world lighting + chams + un box/skeleton ESP representativo aplicados en vivo → el user ve el colorfade moverse y prueba los visuales sin salir del menú.

### D.1 Modelo y fondo
- Modelo: clon del `LocalPlayer.Character` (fuerza `Archivable`, limpia scripts). Si no hay char (no spawneado) → placeholder vacío + label "spawnea para preview".
- Fondo **matrix**: panel negro + lluvia de código verde sutil animada (columnas de caracteres cayendo, low-alpha). En Primordial = frame con TextLabels animados; en ClaudeUI = Drawing Text dentro del ViewportFrame area o textura.

### D.2 PrimordialUI
Ya tiene `Widgets/Viewport.lua` (`AddViewport`, `:SetModel`, auto-encuadre, auto-rota). Extender: `:SetPreviewModel(char)`, aplicar Highlight chams (fade) al modelo, fondo matrix, y overlay ESP box/skeleton (Drawing sobre el viewport o líneas en el ViewportFrame).

### D.3 ClaudeUI/RivalsUI
Necesita un **`ViewportFrame` en `gethui()`** (⚠️ **1 instancia** — desviación del "0 instancias"; **solo existe con el menú abierto**, es el panel de preview, no ESP → aceptable). Reusa el patrón showcase 3D existente (RivalsUI ViewportFrame). `Library:AddPreview(pane)` monta el ViewportFrame + cámara + modelo + fondo. ESP overlay vía `ESP:RenderPreview(viewportCam, model)`.

### D.4 Aplicación en vivo
El preview lee los mismos `Flags` → chams/box/skeleton usan `Color.fade` con el mismo `Suite_FadeSpeed` → el user ve exactamente el resultado. World lighting se aplica al `ViewportFrame` (tiene su propio `Lighting`? No — ViewportFrame usa `Ambient/LightColor/LightDirection` propios → se mapean los flags relevantes).

## Testing (TDD vía MCP, igual que World)

Cliente vivo (Baseplate Potassium). Servicios/provider mockeados para lógica pura.
- **Color.fade**: fade on → color oscila entre c1/c2 en el tiempo; off → c1 sólido.
- **ESP**: provider mock (2 targets fake con root/head/bones) → box proyectada, healthbar frac, skeleton usa bones, filtros (maxdist/dead), off-screen arrow cuando Z<0. Chams crea/limpia Highlight.
- **Local**: crosshair Drawing render, FOV write a Camera mock, AspectMode setea FieldOfViewMode, watermark texto.
- **Preview**: monta ViewportFrame + modelo clon, aplica chams.
- **World retrofit**: re-correr toda la regresión World con colores vía `Color.fade` (fade off → mismo comportamiento que antes).
- Demos live en ambas UIs: suite completa (World+ESP+Local tabs) monta, provider default enumera players, preview renderiza.

## Orden de implementación (fases)

1. **§0 Suite** — module registry + `Attach` generalizado + bundler `Visuals.<lib>.lua`. Migrar World a módulo. Regresión World verde.
2. **§A ColorFade** — `core/color.lua`, `CF` helper, `Suite_FadeSpeed`. Retrofit World colors. Regresión verde (fade off = igual).
3. **§B ESP** — core + default provider + features + schema + chams. Rivals provider. Demos ambas UIs.
4. **§C Local** — core + hooks + features (incl FOV changer + Aspect Ratio) + schema. Demos.
5. **§D Preview** — Primordial viewport ext + ClaudeUI ViewportFrame + matrix bg + ESP preview mode. Demos.

## Fuera de alcance

- Aimbot/triggerbot/rage (combate) — no es visuals.
- True aspect-ratio pixel-stretch (requiere render-hooks, prohibidos).
- Config UI del host (el suite expone `GetFlags/LoadFlags` por módulo).
- Radar/minimap — posible fase futura, no ahora.
