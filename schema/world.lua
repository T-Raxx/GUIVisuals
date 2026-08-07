return function(GV)
    local C = Color3.fromRGB
    local ACC = C(96, 130, 255) -- default2 sugerido para fades
    local S = {}
    local function add(r) table.insert(S, r) end
    local function addCF(spec)
        spec.default2 = spec.default2 or ACC
        GV.pushCF(S, spec)
    end

    -- ================= Tab "Mundo" =================
    -- A. Lighting
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_Enabled", type = "toggle", text = "Enable visuales", default = false, keybind = true, master = true }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_Fullbright", type = "toggle", text = "Fullbright", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_NoShadows", type = "toggle", text = "Sin sombras", default = false, dependsOn = "World_Enabled" }
    addCF{ base = "World_Ambient", text = "Ambient", tab = "Mundo", group = "Lighting", side = "Left", default = C(120, 120, 125), dependsOn = "World_Enabled" }
    addCF{ base = "World_OutdoorAmbient", text = "Outdoor ambient", tab = "Mundo", group = "Lighting", side = "Left", default = C(120, 120, 125), dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_Brightness", type = "slider", text = "Brillo", min = 0, max = 10, default = 3, decimals = 1, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_Exposure", type = "slider", text = "Exposicion", min = -3, max = 3, default = 0, decimals = 2, dependsOn = "World_Enabled" }
    addCF{ base = "World_ColorShiftTop", text = "ColorShift Top", tab = "Mundo", group = "Lighting", side = "Left", default = C(0, 0, 0), dependsOn = "World_Enabled" }
    addCF{ base = "World_ColorShiftBottom", text = "ColorShift Bottom", tab = "Mundo", group = "Lighting", side = "Left", default = C(0, 0, 0), dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_EnvDiffuse", type = "slider", text = "Env diffuse", min = 0, max = 5, default = 1, decimals = 2, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_EnvSpecular", type = "slider", text = "Env specular", min = 0, max = 5, default = 1, decimals = 2, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_Technology", type = "dropdown", text = "Technology", values = { "", "Voxel", "ShadowMap", "Future", "Legacy" }, default = "", dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Lighting", side = "Left", flag = "World_GeoLatitude", type = "slider", text = "Latitud geo", min = -90, max = 90, default = 41.7, decimals = 1, dependsOn = "World_Enabled" }
    -- B. Tiempo / Sol
    add{ tab = "Mundo", group = "Tiempo / Sol", side = "Left", flag = "World_ClockTime", type = "slider", text = "Hora del dia", min = 0, max = 24, default = 12, decimals = 1, suffix = "h", dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Tiempo / Sol", side = "Left", flag = "World_UseTimeOfDay", type = "toggle", text = "Usar TimeOfDay", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Tiempo / Sol", side = "Left", flag = "World_FreezeTime", type = "toggle", text = "Congelar tiempo", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Tiempo / Sol", side = "Left", flag = "World_DayNightCycle", type = "toggle", text = "Ciclo dia/noche", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Tiempo / Sol", side = "Left", flag = "World_CycleSpeed", type = "slider", text = "Velocidad ciclo", min = 0.1, max = 10, default = 1, decimals = 2, suffix = "x", dependsOn = "World_DayNightCycle" }
    -- C. Fog
    add{ tab = "Mundo", group = "Fog", side = "Right", flag = "World_NoFog", type = "toggle", text = "Sin fog", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Fog", side = "Right", flag = "World_FogStart", type = "slider", text = "Fog inicio", min = 0, max = 2000, default = 0, suffix = "st", dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Fog", side = "Right", flag = "World_FogEnd", type = "slider", text = "Fog fin", min = 100, max = 10000, default = 2500, suffix = "st", dependsOn = "World_Enabled" }
    addCF{ base = "World_FogColor", text = "Color fog", tab = "Mundo", group = "Fog", side = "Right", default = C(190, 195, 210), dependsOn = "World_Enabled" }
    -- D. Atmosphere
    add{ tab = "Mundo", group = "Atmosphere", side = "Right", flag = "World_Atmosphere", type = "toggle", text = "Atmosfera (reemplaza fog)", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Atmosphere", side = "Right", flag = "World_AtmDensity", type = "slider", text = "Densidad", min = 0, max = 1, default = 0.3, decimals = 3, dependsOn = "World_Atmosphere" }
    add{ tab = "Mundo", group = "Atmosphere", side = "Right", flag = "World_AtmOffset", type = "slider", text = "Offset", min = 0, max = 1, default = 0.25, decimals = 2, dependsOn = "World_Atmosphere" }
    add{ tab = "Mundo", group = "Atmosphere", side = "Right", flag = "World_AtmGlare", type = "slider", text = "Glare", min = 0, max = 10, default = 0, decimals = 1, dependsOn = "World_Atmosphere" }
    add{ tab = "Mundo", group = "Atmosphere", side = "Right", flag = "World_AtmHaze", type = "slider", text = "Haze", min = 0, max = 10, default = 0, decimals = 1, dependsOn = "World_Atmosphere" }
    addCF{ base = "World_AtmColor", text = "Color", tab = "Mundo", group = "Atmosphere", side = "Right", default = C(199, 199, 199), dependsOn = "World_Atmosphere" }
    addCF{ base = "World_AtmDecay", text = "Decay", tab = "Mundo", group = "Atmosphere", side = "Right", default = C(106, 112, 125), dependsOn = "World_Atmosphere" }
    -- E. Post-FX
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_Tint", type = "toggle", text = "Tinte (ColorCorrection)", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_TintBrightness", type = "slider", text = "Brillo", min = -1, max = 1, default = 0, decimals = 2, dependsOn = "World_Tint" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_TintContrast", type = "slider", text = "Contraste", min = -1, max = 1, default = 0, decimals = 2, dependsOn = "World_Tint" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_TintSaturation", type = "slider", text = "Saturacion", min = -1, max = 3, default = 0, decimals = 2, dependsOn = "World_Tint" }
    addCF{ base = "World_TintColor", text = "Color tinte", tab = "Mundo", group = "Post-FX", side = "Right", default = C(255, 255, 255), dependsOn = "World_Tint" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_RainbowHue", type = "toggle", text = "Rainbow hue", default = false, dependsOn = "World_Tint" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_RainbowSpeed", type = "slider", text = "Rainbow vel", min = 0.05, max = 5, default = 1, decimals = 2, dependsOn = "World_RainbowHue" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_Bloom", type = "toggle", text = "Bloom", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_BloomIntensity", type = "slider", text = "Intensidad", min = 0, max = 5, default = 0.4, decimals = 2, dependsOn = "World_Bloom" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_BloomSize", type = "slider", text = "Tamano", min = 0, max = 56, default = 24, dependsOn = "World_Bloom" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_BloomThreshold", type = "slider", text = "Umbral", min = 0, max = 3, default = 0.95, decimals = 2, dependsOn = "World_Bloom" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_SunRays", type = "toggle", text = "Rayos de sol", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_SunRaysIntensity", type = "slider", text = "Intensidad", min = 0, max = 1, default = 0.05, decimals = 3, dependsOn = "World_SunRays" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_SunRaysSpread", type = "slider", text = "Dispersion", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = "World_SunRays" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_DoF", type = "toggle", text = "Depth of Field", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_DoFFocus", type = "slider", text = "Foco", min = 0, max = 500, default = 25, dependsOn = "World_DoF" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_DoFRadius", type = "slider", text = "Radio foco", min = 0, max = 100, default = 10, dependsOn = "World_DoF" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_DoFNear", type = "slider", text = "Near", min = 0, max = 1, default = 0, decimals = 2, dependsOn = "World_DoF" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_DoFFar", type = "slider", text = "Far", min = 0, max = 1, default = 0.75, decimals = 2, dependsOn = "World_DoF" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_WorldBlur", type = "toggle", text = "Blur mundo", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_WorldBlurSize", type = "slider", text = "Fuerza", min = 0, max = 40, default = 12, dependsOn = "World_WorldBlur" }
    add{ tab = "Mundo", group = "Post-FX", side = "Right", flag = "World_KillGamePostFX", type = "toggle", text = "Matar post-FX del juego", default = false, dependsOn = "World_Enabled" }
    -- J. Visibilidad
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_Advanced", type = "toggle", text = "Avanzado (agresivo)", default = false, dependsOn = "World_Enabled", tooltip = "Toca el mapa; usar con criterio" }
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_KillParticles", type = "toggle", text = "Matar particulas del mapa", default = false, dependsOn = "World_Advanced" }
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_ForceSmoothPlastic", type = "toggle", text = "Forzar SmoothPlastic", default = false, dependsOn = "World_Advanced" }
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_MapTransparent", type = "toggle", text = "Mapa transparente", default = false, dependsOn = "World_Advanced" }
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_MapTransparentAmount", type = "slider", text = "Transparencia", min = 0, max = 1, default = 0.6, decimals = 2, dependsOn = "World_MapTransparent" }
    add{ tab = "Mundo", group = "Visibilidad", side = "Left", flag = "World_NoTextures", type = "toggle", text = "Sin texturas/decals", default = false, dependsOn = "World_Advanced" }
    -- ================= Tab "Cielo & Clima" =================
    -- F. Cielo
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_NoSky", type = "toggle", text = "Sin cuerpos celestes", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_StarCount", type = "slider", text = "Estrellas", min = 0, max = 5000, default = 3000, dependsOn = "World_Enabled" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_CustomSkybox", type = "toggle", text = "Skybox custom", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Up", type = "textbox", text = "Up", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Dn", type = "textbox", text = "Down", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Lf", type = "textbox", text = "Left", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Rt", type = "textbox", text = "Right", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Bk", type = "textbox", text = "Back", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_Skybox_Ft", type = "textbox", text = "Front", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_SunTextureId", type = "textbox", text = "Sol textura", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_MoonTextureId", type = "textbox", text = "Luna textura", placeholder = "rbxassetid://", default = "", dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_SunAngularSize", type = "slider", text = "Sol tamano", min = 0, max = 90, default = 21, dependsOn = "World_CustomSkybox" }
    add{ tab = "Cielo & Clima", group = "Cielo", side = "Left", flag = "World_MoonAngularSize", type = "slider", text = "Luna tamano", min = 0, max = 90, default = 11, dependsOn = "World_CustomSkybox" }
    -- G. Nubes
    add{ tab = "Cielo & Clima", group = "Nubes", side = "Left", flag = "World_Clouds", type = "toggle", text = "Nubes custom", default = false, dependsOn = "World_Enabled" }
    add{ tab = "Cielo & Clima", group = "Nubes", side = "Left", flag = "World_NoClouds", type = "toggle", text = "Sin nubes", default = false, dependsOn = "World_Clouds" }
    add{ tab = "Cielo & Clima", group = "Nubes", side = "Left", flag = "World_CloudCover", type = "slider", text = "Cobertura", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = "World_Clouds" }
    add{ tab = "Cielo & Clima", group = "Nubes", side = "Left", flag = "World_CloudDensity", type = "slider", text = "Densidad", min = 0, max = 1, default = 0.7, decimals = 2, dependsOn = "World_Clouds" }
    addCF{ base = "World_CloudColor", text = "Color nubes", tab = "Cielo & Clima", group = "Nubes", side = "Left", default = C(255, 255, 255), dependsOn = "World_Clouds" }
    -- H. Terrain / Agua
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_WaterEnable", type = "toggle", text = "Editar agua", default = false, dependsOn = "World_Enabled" }
    addCF{ base = "World_WaterColor", text = "Color agua", tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", default = C(12, 84, 92), dependsOn = "World_WaterEnable" }
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_WaterTransparency", type = "slider", text = "Transparencia", min = 0, max = 1, default = 0.3, decimals = 2, dependsOn = "World_WaterEnable" }
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_WaterReflectance", type = "slider", text = "Reflectancia", min = 0, max = 1, default = 1, decimals = 2, dependsOn = "World_WaterEnable" }
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_WaterWaveSize", type = "slider", text = "Olas tamano", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = "World_WaterEnable" }
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_WaterWaveSpeed", type = "slider", text = "Olas velocidad", min = 0, max = 20, default = 10, decimals = 1, dependsOn = "World_WaterEnable" }
    add{ tab = "Cielo & Clima", group = "Terrain / Agua", side = "Right", flag = "World_TerrainDecoration", type = "toggle", text = "Decoracion terrain", default = true, dependsOn = "World_WaterEnable" }
    -- I. Clima
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_Weather", type = "toggle", text = "Clima", default = false, keybind = true, dependsOn = "World_Enabled" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherMode", type = "dropdown", text = "Tipo", values = { "Lluvia", "Lluvia fuerte", "Nieve", "Niebla", "Ceniza", "Luciérnagas", "Custom" }, default = "Lluvia", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherCustomTex", type = "textbox", text = "Textura custom", placeholder = "rbxassetid://", default = "", dependsOn = "World_Weather" }
    addCF{ base = "World_WeatherColor", text = "Color", tab = "Cielo & Clima", group = "Clima", side = "Right", default = C(220, 230, 255), dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherTransparency", type = "slider", text = "Transparencia", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherGlow", type = "slider", text = "Brillo propio", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherDensity", type = "slider", text = "Densidad", min = 0.1, max = 4, default = 1, decimals = 2, suffix = "x", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherSpeed", type = "slider", text = "Velocidad", min = 0.1, max = 3, default = 1, decimals = 2, suffix = "x", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherSize", type = "slider", text = "Tamano", min = 0.2, max = 4, default = 1, decimals = 2, suffix = "x", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherArea", type = "slider", text = "Area", min = 30, max = 200, default = 90, suffix = "st", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_WeatherWindDir", type = "slider", text = "Viento (dir)", min = 0, max = 360, default = 0, suffix = "deg", dependsOn = "World_Weather" }
    add{ tab = "Cielo & Clima", group = "Clima", side = "Right", flag = "World_Lightning", type = "toggle", text = "Relampagos", default = false, dependsOn = "World_Weather" }
    -- K. Presets
    add{ tab = "Cielo & Clima", group = "Presets", side = "Right", flag = "World_PresetSelect", type = "dropdown", text = "Preset", values = { "Competitivo", "Cinematográfico", "Día", "Noche", "Atardecer", "Niebla" }, default = "Competitivo", dependsOn = "World_Enabled" }

    GV.Schema = S
    GV.Modules = GV.Modules or {}
    GV.Modules.world = GV.Modules.world or {}
    GV.Modules.world.schema = S
end
