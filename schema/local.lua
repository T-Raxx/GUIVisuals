return function(GV)
    local C = Color3.fromRGB
    local S = {}
    local function add(r) table.insert(S, r) end
    local function addCF(spec) spec.default2 = spec.default2 or C(96, 130, 255); GV.pushCF(S, spec) end
    local TAB, TC = "Local", "Local Colores"

    -- ===== Tab Local =====
    -- Camara (Left)
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_Enabled", type = "toggle", text = "Enable Local", default = false, keybind = true, master = true }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_FOV", type = "toggle", text = "FOV changer", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_FOVValue", type = "slider", text = "FOV", min = 40, max = 120, default = 70, dependsOn = "Local_FOV" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_ThirdPerson", type = "toggle", text = "3ra persona", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_ThirdPersonDistance", type = "slider", text = "3ra persona distancia", min = 5, max = 30, default = 12, dependsOn = "Local_ThirdPerson" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_AspectMode", type = "dropdown", text = "Aspect (FieldOfViewMode)", values = { "Off", "Vertical", "Diagonal", "MaxAxis" }, default = "Off", dependsOn = "Local_Enabled", tooltip = "Stretch pixel-real requiere executor que permita escribir ViewportSize" }
    add{ tab = TAB, group = "Camara", side = "Left", flag = "Local_MaxAxisFOV", type = "slider", text = "MaxAxis FOV", min = 40, max = 120, default = 90, dependsOn = "Local_AspectMode" }
    -- Crosshair (Left)
    add{ tab = TAB, group = "Crosshair", side = "Left", flag = "Local_Crosshair", type = "toggle", text = "Crosshair", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Crosshair", side = "Left", flag = "Local_CrosshairStyle", type = "dropdown", text = "Estilo", values = { "Cross", "Dot", "Circle", "T" }, default = "Cross", dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Left", flag = "Local_CrosshairSize", type = "slider", text = "Tamano", min = 2, max = 40, default = 10, dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Left", flag = "Local_CrosshairGap", type = "slider", text = "Gap", min = 0, max = 20, default = 4, dependsOn = "Local_Crosshair" }
    add{ tab = TAB, group = "Crosshair", side = "Left", flag = "Local_CrosshairThickness", type = "slider", text = "Grosor", min = 1, max = 6, default = 1, dependsOn = "Local_Crosshair" }
    -- Hitmarker (Right)
    add{ tab = TAB, group = "Hitmarker", side = "Right", flag = "Local_Hitmarker", type = "toggle", text = "Hitmarker (necesita hitSignal del perfil)", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Hitmarker", side = "Right", flag = "Local_HitmarkerSize", type = "slider", text = "Tamano", min = 2, max = 30, default = 8, dependsOn = "Local_Hitmarker" }
    add{ tab = TAB, group = "Hitmarker", side = "Right", flag = "Local_HitmarkerGap", type = "slider", text = "Gap", min = 0, max = 20, default = 4, dependsOn = "Local_Hitmarker" }
    add{ tab = TAB, group = "Hitmarker", side = "Right", flag = "Local_HitmarkerDuration", type = "slider", text = "Duracion", min = 0.05, max = 1, default = 0.3, decimals = 2, dependsOn = "Local_Hitmarker" }
    -- HUD (Right)
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_Watermark", type = "toggle", text = "Watermark", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Title", type = "toggle", text = "  titulo", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_FPS", type = "toggle", text = "  FPS", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Ping", type = "toggle", text = "  ping", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Name", type = "toggle", text = "  nombre", default = true, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WM_Time", type = "toggle", text = "  hora", default = false, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WatermarkX", type = "slider", text = "Watermark X", min = 0, max = 2000, default = 10, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_WatermarkY", type = "slider", text = "Watermark Y", min = 0, max = 1200, default = 8, dependsOn = "Local_Watermark" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindList", type = "toggle", text = "Lista de keybinds", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindX", type = "slider", text = "Keybinds X", min = 0, max = 2000, default = 10, dependsOn = "Local_KeybindList" }
    add{ tab = TAB, group = "HUD", side = "Right", flag = "Local_KeybindY", type = "slider", text = "Keybinds Y", min = 0, max = 1200, default = 120, dependsOn = "Local_KeybindList" }
    -- Extras (Right)
    add{ tab = TAB, group = "Extras", side = "Right", flag = "Local_AntiFlash", type = "toggle", text = "Anti-flash", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Extras", side = "Right", flag = "Local_AntiSmoke", type = "toggle", text = "Anti-humo (necesita perfil)", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Extras", side = "Right", flag = "Local_SelfChams", type = "toggle", text = "Self-chams (Highlight, detectable)", default = false, dependsOn = "Local_Enabled" }
    add{ tab = TAB, group = "Extras", side = "Right", flag = "Local_SelfChamsFillTransparency", type = "slider", text = "Self-chams transp", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = "Local_SelfChams" }

    -- ===== Tab Local Colores (CF) =====
    addCF{ base = "Local_CrosshairColor", text = "Crosshair", tab = TC, group = "Colores", side = "Left", default = C(0, 255, 120), dependsOn = "Local_Crosshair" }
    addCF{ base = "Local_HitmarkerColor", text = "Hitmarker", tab = TC, group = "Colores", side = "Left", default = C(255, 255, 255), dependsOn = "Local_Hitmarker" }
    addCF{ base = "Local_WatermarkColor", text = "Watermark", tab = TC, group = "Colores", side = "Left", default = C(235, 235, 240), dependsOn = "Local_Watermark" }
    addCF{ base = "Local_KeybindColor", text = "Keybinds", tab = TC, group = "Colores", side = "Right", default = C(235, 235, 240), dependsOn = "Local_KeybindList" }
    addCF{ base = "Local_SelfChamsFill", text = "Self-chams fill", tab = TC, group = "Colores", side = "Right", default = C(0, 200, 255), dependsOn = "Local_SelfChams" }
    addCF{ base = "Local_SelfChamsOutline", text = "Self-chams outline", tab = TC, group = "Colores", side = "Right", default = C(180, 240, 255), dependsOn = "Local_SelfChams" }

    GV.Modules = GV.Modules or {}
    GV.Modules.selffx = GV.Modules.selffx or {}
    GV.Modules.selffx.schema = S
end
