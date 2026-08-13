return function(GV)
    local C = Color3.fromRGB
    local S = {}
    local function add(r) table.insert(S, r) end
    local function color(toggle, base, text, group, side, default, default2)
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = "Local", group = group, side = side,
            default = default, default2 = default2 })
    end
    -- Task 10 (UI rebalance): Aura deja de ser tab standalone y pasa a vivir dentro del tab
    -- "Local" (SelfFX) -- aura = self-cosmetic = local, y asi el usuario no tiene que saltar de
    -- categoria para prender su propia aura junto al resto de cosmeticos propios (self-chams,
    -- crosshair, watermark, etc). Cambio 100% de layout (tab/group/side); flags/defaults/
    -- dependsOn/master/keybind intactos. Para que el renderer (ui/renderer.lua) fusione estas
    -- filas con las de schema/local.lua en UNA sola seccion "Local" (en vez de crear una segunda
    -- seccion duplicada) las filas de ambos modulos deben quedar CONTIGUAS en el array de schema
    -- concatenado -- eso depende del orden del `modules = {...}` en LifeInPrisonPrimordial/
    -- main.lua (selffx inmediatamente antes de aura, sin combat en el medio; ver commit companero
    -- en LiP). Layout de 3 columnas existente en schema/local.lua: Left=Camara+Extras 18 filas,
    -- Mid=Crosshair+Hitmarker 15 filas, Right=HUD 16 filas -- "Mid" es la columna mas liviana,
    -- Aura (6 filas) entra ahi.
    local TAB = "Local"

    -- Master de la categoria "Aura" (15 auras: 6 procedurales + 9 rbxassetid).
    add{ tab = TAB, group = "Aura", side = "Mid", flag = "Aura_Enabled", type = "toggle",
        text = "Enable Aura", default = false, keybind = true, master = true }

    -- Particula(s): multiselect, mismas 15 opciones y mismo orden que el dropdown de juju
    -- (jujudotlol.lua L19684). "+ custom .rbxm/.rbmx" de juju (isfile/getcustomasset, L20219-20280)
    -- queda deliberadamente fuera de esta pasada (opcional per brief) — las 15 built-in cubren el
    -- feature.
    add{ tab = TAB, group = "Aura", side = "Mid", flag = "Aura_Particles", type = "dropdown",
        text = "Particle", values = {
            "starlight", "heavenly", "ribbon", "lightning", "sakura", "angel", "wind", "flow", "star",
            "angel wing", "blue heat", "heal aura", "ambient", "nimb", "tornado",
        }, multi = true, default = { "angel" }, dependsOn = "Aura_Enabled" }

    -- Color (pinned a Aura_Enabled via CF, patron Hitmarker/SelfChams). Default = juju rgb(133,220,255).
    color("Aura_Enabled", "Aura_Color", "Color", "Aura", "Mid", C(133, 220, 255))
    -- juju tambien expone un slider de transparencia junto al colorpicker (default 0.2,
    -- jujudotlol.lua L19683) pero su propio color-apply handler (L20287-20330) nunca lo lee —
    -- se replica el flag por paridad de menu, sin inventar un mecanismo de aplicacion que el
    -- original tampoco tiene.
    add{ tab = TAB, group = "Aura", side = "Mid", flag = "Aura_ColorTransparency", type = "slider",
        text = "Color transp. (paridad juju, sin uso)", min = 0, max = 1, default = 0.2, decimals = 2,
        dependsOn = "Aura_Enabled" }

    GV.Modules = GV.Modules or {}
    GV.Modules.aura = GV.Modules.aura or {}
    GV.Modules.aura.schema = S
end
