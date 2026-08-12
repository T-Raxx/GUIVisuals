return function(GV)
    local S = {}
    local function add(r) table.insert(S, r) end
    local TAB = "Aura"

    -- Master de la categoria "Aura" (15 auras: 6 procedurales + 9 rbxassetid). Filas de
    -- seleccion/color/opciones se agregan en Task 2.
    add{ tab = TAB, group = "General", side = "Left", flag = "Aura_Enabled", type = "toggle",
        text = "Enable Aura", default = false, keybind = true, master = true }

    GV.Modules = GV.Modules or {}
    GV.Modules.aura = GV.Modules.aura or {}
    GV.Modules.aura.schema = S
end
