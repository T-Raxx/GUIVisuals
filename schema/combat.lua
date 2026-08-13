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

    -- Task 5 -- Damage Numbers (juju menu L13314-13321: "damage_number"). NO se porta
    -- "damage_number_show_ragebot_data" (LiP no tiene string de razon de resolver -- ver nota de
    -- adaptacion en core/combat.lua); el texto es siempre el valor numerico de damage.
    add{ tab = TAB, group = "Damage Numbers", side = "Left", flag = "Combat_Damage", type = "toggle",
        text = "Damage numbers", default = false, dependsOn = "Combat_Enabled" }
    -- valores del dropdown son strings numericos (mismo criterio que TracerType/TracerStyle) --
    -- core/combat.lua hace tonumber() al asignarlos a Drawing.Text.Font.
    add{ tab = TAB, group = "Damage Numbers", side = "Left", flag = "Combat_DamageFont", type = "dropdown",
        text = "Font", values = { "0", "1", "2", "3" }, default = "2", dependsOn = "Combat_Damage" }
    add{ tab = TAB, group = "Damage Numbers", side = "Left", flag = "Combat_DamageLifetime", type = "slider",
        text = "Lifetime", min = 0.7, max = 2, default = 0.7, decimals = 1, dependsOn = "Combat_Damage" }
    GV.pushCF(S, { toggle = "Combat_Damage", base = "Combat_DamageColor", text = "Damage color",
        tab = TAB, group = "Damage Numbers", side = "Left", default = C(255, 255, 255) })
    GV.pushCF(S, { toggle = "Combat_Damage", base = "Combat_DamageLethal", text = "Damage lethal color",
        tab = TAB, group = "Damage Numbers", side = "Left", default = C(255, 55, 55) })
    GV.pushCF(S, { toggle = "Combat_Damage", base = "Combat_DamageOutline", text = "Damage outline",
        tab = TAB, group = "Damage Numbers", side = "Left", default = C(15, 15, 15) })

    -- Task 6 -- Target Ring (juju menu L20392-20395: "3d_target_circle" + color/gradient
    -- color colorpickers; thickness=2/ZIndex=10/speed=4 son constantes hardcoded en
    -- do_target_circle -- juju L22690-22764 -- sin fila de menu propia ahi, expuestas acá como
    -- sliders con esos mismos valores de default per el brief). CONTINUO, no event-based: ver
    -- nota en core/combat.lua Combat:_updateRing -- corre cada frame gateado por su propio
    -- toggle, no por un onShot/onHit.
    add{ tab = TAB, group = "Target Ring", side = "Left", flag = "Combat_Ring", type = "toggle",
        text = "Target ring", default = false, dependsOn = "Combat_Enabled" }
    GV.pushCF(S, { toggle = "Combat_Ring", base = "Combat_RingColor", text = "Ring color",
        tab = TAB, group = "Target Ring", side = "Left", default = C(255, 184, 243) })
    GV.pushCF(S, { toggle = "Combat_Ring", base = "Combat_RingGradient", text = "Ring gradient",
        tab = TAB, group = "Target Ring", side = "Left", default = C(255, 255, 255) })
    add{ tab = TAB, group = "Target Ring", side = "Left", flag = "Combat_RingThickness", type = "slider",
        text = "Thickness", min = 0, max = 4, default = 2, decimals = 0, dependsOn = "Combat_Ring" }
    add{ tab = TAB, group = "Target Ring", side = "Left", flag = "Combat_RingSpeed", type = "slider",
        text = "Spin speed", min = 0.5, max = 8, default = 4, decimals = 1, dependsOn = "Combat_Ring" }

    GV.Modules = GV.Modules or {}
    GV.Modules.combat = GV.Modules.combat or {}
    GV.Modules.combat.schema = S
end
