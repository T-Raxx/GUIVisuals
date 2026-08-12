return function(GV)
    local C = Color3.fromRGB
    local S = {}
    local function add(r) table.insert(S, r) end
    local function color(toggle, base, text, group, side, default, default2)
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = "Aura", group = group, side = side,
            default = default, default2 = default2 })
    end
    local TAB = "Aura"

    -- Master de la categoria "Aura" (15 auras: 6 procedurales + 9 rbxassetid).
    add{ tab = TAB, group = "General", side = "Left", flag = "Aura_Enabled", type = "toggle",
        text = "Enable Aura", default = false, keybind = true, master = true }

    -- Particula(s): multiselect, mismas 15 opciones y mismo orden que el dropdown de juju
    -- (jujudotlol.lua L19684). "+ custom .rbxm/.rbmx" de juju (isfile/getcustomasset, L20219-20280)
    -- queda deliberadamente fuera de esta pasada (opcional per brief) — las 15 built-in cubren el
    -- feature.
    add{ tab = TAB, group = "General", side = "Left", flag = "Aura_Particles", type = "dropdown",
        text = "Particle", values = {
            "starlight", "heavenly", "ribbon", "lightning", "sakura", "angel", "wind", "flow", "star",
            "angel wing", "blue heat", "heal aura", "ambient", "nimb", "tornado",
        }, multi = true, default = { "angel" }, dependsOn = "Aura_Enabled" }

    -- Color (pinned a Aura_Enabled via CF, patron Hitmarker/SelfChams). Default = juju rgb(133,220,255).
    color("Aura_Enabled", "Aura_Color", "Color", "General", "Left", C(133, 220, 255))
    -- juju tambien expone un slider de transparencia junto al colorpicker (default 0.2,
    -- jujudotlol.lua L19683) pero su propio color-apply handler (L20287-20330) nunca lo lee —
    -- se replica el flag por paridad de menu, sin inventar un mecanismo de aplicacion que el
    -- original tampoco tiene.
    add{ tab = TAB, group = "General", side = "Left", flag = "Aura_ColorTransparency", type = "slider",
        text = "Color transp. (paridad juju, sin uso)", min = 0, max = 1, default = 0.2, decimals = 2,
        dependsOn = "Aura_Enabled" }

    GV.Modules = GV.Modules or {}
    GV.Modules.aura = GV.Modules.aura or {}
    GV.Modules.aura.schema = S
end
