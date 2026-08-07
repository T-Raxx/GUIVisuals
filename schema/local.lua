return function(GV)
    local C = Color3.fromRGB
    local ACC = C(96, 130, 255)
    local S = {}
    local function add(r) table.insert(S, r) end
    local function color(toggle, base, text, group, side, default, default2)
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = "Local", group = group, side = side,
            default = default, default2 = default2 or ACC })
    end
    local TAB = "Local"

    -- Layout de 3 columnas (grupos chicos): col1=Camara+Extras, col2=Crosshair+Hitmarker, col3=HUD.
    -- side "Mid" activa el 3er panel de fondo. En ClaudeUI (2 cajas) "Mid" cae a la izquierda.

    -- Camara (col 1 / Left)
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_Enabled", type = "toggle", text = "Enable Local", default = false, keybind = true, master = true }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_FOV", type = "toggle", text = "FOV changer", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_FOVValue", type = "slider", text = "FOV", min = 40, max = 120, default = 70, dependsOn = "Local_FOV" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_ThirdPerson", type = "toggle", text = "3ra persona", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_ThirdPersonDistance", type = "slider", text = "3ra persona distancia", min = 5, max = 30, default = 12, dependsOn = "Local_ThirdPerson" }
    -- Custom Aspect Ratio: stretch por matriz CFrame (funciona en cualquier executor)
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_Aspect", type = "toggle", text = "Aspect ratio (stretch)", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_AspectH", type = "slider", text = "Horizontal", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = "Local_Aspect" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_AspectV", type = "slider", text = "Vertical", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = "Local_Aspect" }

    -- Extras (col 1 / Left)
    add{ tab = TAB, group = "Extras", side = "Left", flag = "Local_AntiFlash", type = "toggle", text = "Anti-flash", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "Local_AntiSmoke", type = "toggle", text = "Anti-humo (necesita perfil)", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Extras", side = "Left", flag = "Local_SelfChams", type = "toggle", text = "Self-chams (Highlight, detectable)", default = false, dependsOn = "Local_Enabled" }
    color("Local_SelfChams", "Local_SelfChamsFill", "Self-chams fill", "Extras", "Left", C(0, 200, 255))
    color("Local_SelfChams", "Local_SelfChamsOutline", "Self-chams outline", "Extras", "Left", C(180, 240, 255))
    add{ tab = TAB, group = "Extras", side = "Left", flag = "Local_SelfChamsFillTransparency", type = "slider", text = "Self-chams transp", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = "Local_SelfChams" }

    -- Crosshair (col 2 / Mid)
    add{ tab = TAB, group = "Crosshair", side = "Mid", flag = "Local_Crosshair", type = "toggle", text = "Crosshair", default = false, dependsOn = "Local_Enabled" }
    color("Local_Crosshair", "Local_CrosshairColor", "Crosshair color", "Crosshair", "Mid", C(0, 255, 120))
    add{ tab = TAB, group = "Crosshair", side = "Mid", flag = "Local_CrosshairStyle", type = "dropdown", text = "Estilo", values = { "Cross", "Dot", "Circle", "T" }, default = "Cross", dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Mid", flag = "Local_CrosshairSize", type = "slider", text = "Tamano", min = 2, max = 40, default = 10, dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Mid", flag = "Local_CrosshairGap", type = "slider", text = "Gap", min = 0, max = 20, default = 4, dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Mid", flag = "Local_CrosshairThickness", type = "slider", text = "Grosor", min = 1, max = 6, default = 1, dependsOn = "Local_Crosshair" }

    -- Hitmarker (col 2 / Mid)
    add{ tab = TAB, group = "Hitmarker", side = "Mid", flag = "Local_Hitmarker", type = "toggle", text = "Hitmarker (necesita hitSignal del perfil)", default = false, dependsOn = "Local_Enabled" }
    color("Local_Hitmarker", "Local_HitmarkerColor", "Hitmarker color", "Hitmarker", "Mid", C(255, 255, 255))
    add{ tab = TAB, group = "Hitmarker", side = "Mid", flag = "Local_HitmarkerSize", type = "slider", text = "Tamano", min = 2, max = 30, default = 8, dependsOn = "Local_Hitmarker" }
    add{ tab = TAB, group = "Hitmarker", side = "Mid", flag = "Local_HitmarkerGap", type = "slider", text = "Gap", min = 0, max = 20, default = 4, dependsOn = "Local_Hitmarker" }
    add{ tab = TAB, group = "Hitmarker", side = "Mid", flag = "Local_HitmarkerDuration", type = "slider", text = "Duracion", min = 0.05, max = 1, default = 0.3, decimals = 2, dependsOn = "Local_Hitmarker" }

    -- HUD (col 3 / Right)
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_Watermark", type = "toggle", text = "Watermark", default = false, dependsOn = "Local_Enabled" }
    color("Local_Watermark", "Local_WatermarkColor", "Watermark color", "HUD", "Right", C(235, 235, 240))
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_FPS", type = "toggle", text = "  FPS", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Ping", type = "toggle", text = "  ping", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Name", type = "toggle", text = "  nombre", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Time", type = "toggle", text = "  hora", default = false, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WatermarkX", type = "slider", text = "Watermark X", min = 0, max = 2000, default = 10, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WatermarkY", type = "slider", text = "Watermark Y", min = 0, max = 1200, default = 8, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindList", type = "toggle", text = "Lista de keybinds", default = false, dependsOn = "Local_Enabled" }
    color("Local_KeybindList", "Local_KeybindColor", "Keybinds color", "HUD", "Right", C(235, 235, 240))
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindX", type = "slider", text = "Keybinds X", min = 0, max = 2000, default = 10, dependsOn = "Local_KeybindList" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindY", type = "slider", text = "Keybinds Y", min = 0, max = 1200, default = 120, dependsOn = "Local_KeybindList" }

    GV.Modules = GV.Modules or {}
    GV.Modules.selffx = GV.Modules.selffx or {}
    GV.Modules.selffx.schema = S
end
