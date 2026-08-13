return function(GV)
    local C = Color3.fromRGB
    local S = {}
    local function add(r) table.insert(S, r) end
    local TAB = "Combat"

    -- Master de la categoria "Combat" (Tracers/Hitmarker/Damage Numbers/Target Ring/Hit
    -- Particles/Hit Chams). Filas por feature se agregan en Tasks 3-8.
    add{ tab = TAB, group = "General", side = "Left", flag = "Combat_Enabled", type = "toggle",
        text = "Enable Combat VFX", default = false, keybind = true, master = true }

    -- Task 3 -- Hit Tracers (juju menu L13276-13303, port de "local/player bullet tracers").
    -- LiP no distingue tracer propio vs de otros jugadores (onShot no trae esa granularidad para
    -- terceros todavia) -> 1 sola fila de flags (equivalente a los "local_bullet_tracers_*" de
    -- juju), aplicada a cualquier onShot independientemente de isLocal.
    add{ tab = TAB, group = "Tracers", side = "Left", flag = "Combat_Tracer", type = "toggle",
        text = "Hit tracers", default = false, dependsOn = "Combat_Enabled" }
    add{ tab = TAB, group = "Tracers", side = "Left", flag = "Combat_TracerType", type = "dropdown",
        text = "Type", values = { "line", "beam" }, default = "beam", dependsOn = "Combat_Tracer" }
    add{ tab = TAB, group = "Tracers", side = "Left", flag = "Combat_TracerStyle", type = "dropdown",
        text = "Style (beam)", values = { "laser", "light", "flow" }, default = "laser", dependsOn = "Combat_Tracer" }
    GV.pushCF(S, { toggle = "Combat_Tracer", base = "Combat_TracerColor", text = "Tracer color",
        tab = TAB, group = "Tracers", side = "Left", default = C(133, 220, 255) })
    GV.pushCF(S, { toggle = "Combat_Tracer", base = "Combat_TracerOutline", text = "Tracer outline (line)",
        tab = TAB, group = "Tracers", side = "Left", default = C(15, 15, 15) })
    GV.pushCF(S, { toggle = "Combat_Tracer", base = "Combat_TracerGradient", text = "Tracer gradient (beam)",
        tab = TAB, group = "Tracers", side = "Left", default = C(241, 133, 255) })
    add{ tab = TAB, group = "Tracers", side = "Left", flag = "Combat_TracerLifetime", type = "slider",
        text = "Lifetime", min = 0.1, max = 1.5, default = 0.8, decimals = 1, dependsOn = "Combat_Tracer" }

    -- Task 4 -- Hitmarker 3D + 2D (juju menu L13322-13335: "d3_hit_marker"/"d2_hit_marker").
    -- juju duplica lifetime/thickness/color/lethal/outline por marker (3D y 2D); acá se comparte
    -- 1 solo set (brief lo permite explicitamente) -- ambos toggles cuelgan de Combat_Enabled, y
    -- los colorpickers compartidos tambien (no de un solo toggle de marker, porque cualquiera de
    -- los dos -- 3D o 2D -- los consume).
    add{ tab = TAB, group = "Hitmarker", side = "Left", flag = "Combat_Marker3D", type = "toggle",
        text = "3D hit marker", default = false, dependsOn = "Combat_Enabled" }
    add{ tab = TAB, group = "Hitmarker", side = "Left", flag = "Combat_Marker2D", type = "toggle",
        text = "2D hit marker", default = false, dependsOn = "Combat_Enabled" }
    add{ tab = TAB, group = "Hitmarker", side = "Left", flag = "Combat_MarkerLifetime", type = "slider",
        text = "Lifetime", min = 0.1, max = 2, default = 0.7, decimals = 1, dependsOn = "Combat_Enabled" }
    add{ tab = TAB, group = "Hitmarker", side = "Left", flag = "Combat_MarkerThickness", type = "slider",
        text = "Thickness", min = 0, max = 4, default = 2, decimals = 0, dependsOn = "Combat_Enabled" }
    GV.pushCF(S, { toggle = "Combat_Enabled", base = "Combat_MarkerColor", text = "Marker color",
        tab = TAB, group = "Hitmarker", side = "Left", default = C(133, 220, 255) })
    GV.pushCF(S, { toggle = "Combat_Enabled", base = "Combat_MarkerLethal", text = "Marker lethal color",
        tab = TAB, group = "Hitmarker", side = "Left", default = C(255, 0, 0) })
    GV.pushCF(S, { toggle = "Combat_Enabled", base = "Combat_MarkerOutline", text = "Marker outline",
        tab = TAB, group = "Hitmarker", side = "Left", default = C(15, 15, 15) })

    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.schema = S
end
