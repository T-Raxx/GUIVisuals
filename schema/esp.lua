return function(GV)
    local C = Color3.fromRGB
    local ACC = C(96, 130, 255)
    local S = {}
    local function add(r) table.insert(S, r) end
    -- color pegado a un toggle de feature (aparece sobre el toggle). `toggle`=flag del toggle, `base`=flag del color.
    local function color(toggle, base, text, group, side, default, default2)
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = "ESP", group = group, side = side,
            default = default, default2 = default2 or ACC })
    end
    local TAB = "ESP"

    -- General (Left)
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_Enabled", type = "toggle", text = "Enable ESP", default = false, keybind = true, master = true }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_Box", type = "toggle", text = "Box", default = true, dependsOn = "ESP_Enabled" }
    color("ESP_Box", "ESP_BoxColor", "Box color", "General", "Left", C(235, 235, 240))
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_BoxFilled", type = "toggle", text = "Box relleno", default = false, dependsOn = "ESP_Box" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_BoxFillAlpha", type = "slider", text = "Relleno alpha", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = "ESP_BoxFilled" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_BoxOutline", type = "toggle", text = "Box contorno", default = true, dependsOn = "ESP_Box" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_BoxThickness", type = "slider", text = "Box grosor", min = 1, max = 5, default = 1, dependsOn = "ESP_Box" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_Name", type = "toggle", text = "Nombre", default = true, dependsOn = "ESP_Enabled" }
    color("ESP_Name", "ESP_NameColor", "Nombre color", "General", "Left", C(235, 235, 240))
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_Distance", type = "toggle", text = "Distancia", default = true, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_Health", type = "toggle", text = "Vida", default = true, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "General", side = "Left", flag = "ESP_HealthStyle", type = "dropdown", text = "Vida estilo", values = { "Barra", "Numero", "Barra+Numero" }, default = "Barra", dependsOn = "ESP_Health" }

    -- Extras (Left)
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_Skeleton", type = "toggle", text = "Esqueleto", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_Skeleton", "ESP_SkeletonColor", "Esqueleto color", "Extras", "Left", C(200, 200, 210))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_HeadDot", type = "toggle", text = "Head dot", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_HeadDot", "ESP_HeadDotColor", "Head dot color", "Extras", "Left", C(255, 80, 80))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_HeadDotRadius", type = "slider", text = "Head dot radio", min = 1, max = 12, default = 3, dependsOn = "ESP_HeadDot" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_LookDir", type = "toggle", text = "Direccion de mira", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_LookDir", "ESP_LookDirColor", "Mira color", "Extras", "Left", C(255, 255, 120))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_LookLength", type = "slider", text = "Mira largo", min = 1, max = 10, default = 2, decimals = 1, dependsOn = "ESP_LookDir" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_Tracer", type = "toggle", text = "Tracer", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_Tracer", "ESP_TracerColor", "Tracer color", "Extras", "Left", C(96, 130, 255))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_TracerFrom", type = "dropdown", text = "Tracer origen", values = { "Bottom", "Center", "Top", "Mouse" }, default = "Bottom", dependsOn = "ESP_Tracer" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_OffScreen", type = "toggle", text = "Flechas off-screen", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_OffScreen", "ESP_OffScreenColor", "Off-screen color", "Extras", "Left", C(255, 170, 60))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_OffScreenRadius", type = "slider", text = "Off-screen radio", min = 50, max = 400, default = 200, dependsOn = "ESP_OffScreen" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "ESP_OffScreenSize", type = "slider", text = "Off-screen tamano", min = 6, max = 40, default = 16, dependsOn = "ESP_OffScreen" }

    -- Chams (Right, detectable)
    add{ tab = TAB, group = "Chams (detectable)", side = "Right", type = "label", text = "Chams usa Highlight = INSTANCIA detectable" }
    add{ tab = TAB, group = "Chams (detectable)", side = "Right", flag = "ESP_Chams", type = "toggle", text = "Chams", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_Chams", "ESP_ChamsFill", "Chams fill", "Chams (detectable)", "Right", C(120, 60, 200))
    color("ESP_Chams", "ESP_ChamsOutline", "Chams outline", "Chams (detectable)", "Right", C(200, 160, 255))
    add{ tab = TAB, group = "Chams (detectable)", side = "Right", flag = "ESP_ChamsDepthMode", type = "dropdown", text = "Depth", values = { "AlwaysOnTop", "Occluded" }, default = "AlwaysOnTop", dependsOn = "ESP_Chams" }
    add{ tab = TAB, group = "Chams (detectable)", side = "Right", flag = "ESP_ChamsFillTransparency", type = "slider", text = "Fill transp", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = "ESP_Chams" }
    add{ tab = TAB, group = "Chams (detectable)", side = "Right", flag = "ESP_ChamsOutlineTransparency", type = "slider", text = "Outline transp", min = 0, max = 1, default = 0, decimals = 2, dependsOn = "ESP_Chams" }

    -- Color / Visibilidad (Right)
    add{ tab = TAB, group = "Color / Visibilidad", side = "Right", flag = "ESP_ColorMode", type = "dropdown", text = "Modo de color", values = { "Fijo", "Team", "Visibilidad", "Distancia" }, default = "Fijo", dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Color / Visibilidad", side = "Right", flag = "ESP_VisibleCheck", type = "toggle", text = "Chequeo de visibilidad (raycast)", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_VisibleCheck", "ESP_VisibleColor", "Visible color", "Color / Visibilidad", "Right", C(64, 200, 96))
    color("ESP_VisibleCheck", "ESP_HiddenColor", "Oculto color", "Color / Visibilidad", "Right", C(235, 64, 52))

    -- Filtros (Right)
    add{ tab = TAB, group = "Filtros", side = "Right", flag = "ESP_MaxDistance", type = "slider", text = "Distancia max (0=sin limite)", min = 0, max = 5000, default = 1200, suffix = "st", dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Filtros", side = "Right", flag = "ESP_PlayersOnly", type = "toggle", text = "Solo jugadores", default = false, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Filtros", side = "Right", flag = "ESP_TeamCheck", type = "toggle", text = "Team check", default = false, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Filtros", side = "Right", flag = "ESP_DeadCheck", type = "toggle", text = "Ocultar muertos", default = true, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Filtros", side = "Right", flag = "ESP_MaxTargets", type = "slider", text = "Targets max", min = 1, max = 100, default = 50, dependsOn = "ESP_Enabled" }

    -- Object ESP + Prefs (Right)
    add{ tab = TAB, group = "Object ESP", side = "Right", flag = "ESP_Objects", type = "toggle", text = "Object ESP (perfil)", default = false, dependsOn = "ESP_Enabled" }
    color("ESP_Objects", "ESP_ObjectColor", "Objetos color", "Object ESP", "Right", C(255, 220, 90))
    add{ tab = TAB, group = "Prefs", side = "Right", flag = "ESP_Font", type = "slider", text = "Fuente", min = 0, max = 3, default = 2, dependsOn = "ESP_Enabled" }
    add{ tab = TAB, group = "Prefs", side = "Right", flag = "ESP_TextSize", type = "slider", text = "Texto tamano", min = 8, max = 24, default = 13, dependsOn = "ESP_Enabled" }

    GV.Modules = GV.Modules or {}
    GV.Modules.esp = GV.Modules.esp or {}
    GV.Modules.esp.schema = S
end
