return function(GV)
    local S = {}
    local function add(r) table.insert(S, r) end
    local TAB = "Combat"

    -- Master de la categoria "Combat" (Tracers/Hitmarker/Damage Numbers/Target Ring/Hit
    -- Particles/Hit Chams). Filas por feature se agregan en Tasks 3-8.
    add{ tab = TAB, group = "General", side = "Left", flag = "Combat_Enabled", type = "toggle",
        text = "Enable Combat VFX", default = false, keybind = true, master = true }

    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.schema = S
end
