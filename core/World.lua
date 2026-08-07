return function(GV)
    local U = GV.Util
    local World = {}
    World.__index = World

    function World.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Lighting = game:GetService("Lighting"),
            Terrain = workspace:FindFirstChildOfClass("Terrain"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        local self = setmetatable({
            Flags = {}, Services = svc, Conns = {},
            _orig = {}, _made = {}, _fxCache = {}, _applies = {},
            Loaded = false, _wasOn = false,
        }, World)
        self:_installApplies()
        return self
    end

    function World:Set(flag, v) self.Flags[flag] = v end
    function World:Get(flag) return self.Flags[flag] end
    function World:_flag(name, default)
        local v = self.Flags[name]
        if v ~= nil then return v end
        return default
    end

    -- serializa para config (Color3/Enum -> tablas nombradas)
    function World:GetFlags()
        local out = {}
        for k, v in pairs(self.Flags) do
            if typeof(v) == "Color3" then out[k] = U.serColor(v)
            elseif typeof(v) == "EnumItem" then out[k] = U.serEnum(v)
            else out[k] = v end
        end
        return out
    end
    function World:LoadFlags(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" and v.__ == "c3" then self.Flags[k] = U.deColor(v)
            elseif type(v) == "table" and v.__ == "en" then self.Flags[k] = U.deEnum(v)
            else self.Flags[k] = v end
        end
    end

    function World:_set(obj, prop, val)
        if not obj then return end
        local ok, cur = pcall(function() return obj[prop] end)
        if not ok then return end
        local mem = self._orig[obj]
        if not mem then mem = {}; self._orig[obj] = mem end
        if mem[prop] == nil then mem[prop] = cur end
        if cur ~= val then pcall(function() obj[prop] = val end) end
    end
    function World:_restoreAll()
        for obj, props in pairs(self._orig) do
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end
        end
        table.clear(self._orig)
    end

    -- crear (una vez) un efecto propio, nombrado como los del juego para no cantar en scan
    function World:_fx(class, parent)
        local got = self._fxCache[class]
        if got then
            -- reusar el cache; si el juego lo despareento, re-attach (Parent==nil)
            if not got.Parent then pcall(function() got.Parent = parent or self.Services.Lighting end) end
            return got
        end
        local inst = Instance.new(class)
        inst.Name = "LightingController"
        pcall(function() inst.Parent = parent or self.Services.Lighting end)
        self._fxCache[class] = inst
        table.insert(self._made, inst)
        return inst
    end

    function World:_register(fn) table.insert(self._applies, fn) end

    function World:_step()
        if not self:_flag("World_Enabled", false) then
            if self._wasOn then self:_off() end
            return
        end
        self._wasOn = true
        for _, fn in ipairs(self._applies) do
            local ok, err = pcall(fn, self)
            if not ok then warn("[World] apply: " .. tostring(err)) end
        end
    end

    function World:_off()
        self._wasOn = false
        for _, inst in pairs(self._fxCache) do
            pcall(function() if inst:IsA("PostEffect") then inst.Enabled = false end end)
        end
        self:_killAtmosphere() -- destruir, no Density=0: si queda, mata el fog
        self:_restoreAll()
    end

    function World:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local conn = self.Services.RunService.RenderStepped:Connect(function()
            local ok, err = pcall(function() self:_step() end)
            if not ok then warn("[World] step: " .. tostring(err)) end
        end)
        self.Conns[#self.Conns + 1] = conn
        return self
    end

    function World:Unload()
        if not self.Loaded then return end
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        table.clear(self.Conns)
        self:_restoreAll()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self._made)
        self._fxCache = {}
    end

    ------------------------------------------------------------------ APPLIES
    local WHITE = Color3.fromRGB(255, 255, 255)

    -- A. Lighting core
    function World:_applyLighting()
        local L = self.Services.Lighting
        if self:_flag("World_Fullbright", false) then
            self:_set(L, "Ambient", WHITE); self:_set(L, "OutdoorAmbient", WHITE)
            self:_set(L, "Brightness", 1); self:_set(L, "GlobalShadows", false)
        else
            local amb = self:_flag("World_Ambient", Color3.fromRGB(120, 120, 125))
            self:_set(L, "Ambient", amb)
            self:_set(L, "OutdoorAmbient", self:_flag("World_OutdoorAmbient", amb))
            self:_set(L, "Brightness", self:_flag("World_Brightness", 3))
            self:_set(L, "GlobalShadows", not self:_flag("World_NoShadows", false))
        end
        self:_set(L, "ExposureCompensation", self:_flag("World_Exposure", 0))
        self:_set(L, "ColorShift_Top", self:_flag("World_ColorShiftTop", Color3.new()))
        self:_set(L, "ColorShift_Bottom", self:_flag("World_ColorShiftBottom", Color3.new()))
        self:_set(L, "EnvironmentDiffuseScale", self:_flag("World_EnvDiffuse", 1))
        self:_set(L, "EnvironmentSpecularScale", self:_flag("World_EnvSpecular", 1))
        self:_set(L, "GeographicLatitude", self:_flag("World_GeoLatitude", 41.733))
        local tech = self:_flag("World_Technology", "")
        if tech ~= "" then pcall(function() L.Technology = Enum.Technology[tech] end) end
    end

    -- B. Tiempo / sol
    function World:_applyTime()
        local L = self.Services.Lighting
        if self:_flag("World_DayNightCycle", false) then
            local spd = self:_flag("World_CycleSpeed", 1)
            local t = (self._cycleT or self:_flag("World_ClockTime", 12)) + (1 / 60) * spd
            if t >= 24 then t = t - 24 end
            self._cycleT = t
            self:_set(L, "ClockTime", t)
        elseif self:_flag("World_FreezeTime", false) then
            if not self._freeze then self._freeze = self:_flag("World_ClockTime", 12) end
            self:_set(L, "ClockTime", self._freeze)
        elseif self:_flag("World_UseTimeOfDay", false) then
            local c = self:_flag("World_ClockTime", 12); local h = math.floor(c); local m = math.floor((c - h) * 60)
            self:_set(L, "TimeOfDay", string.format("%02d:%02d:00", h, m))
        else
            self._freeze = nil
            self:_set(L, "ClockTime", self:_flag("World_ClockTime", 12))
        end
    end

    -- C. Fog  +  D. Atmosphere (destroy-on-off)
    function World:_applyFog()
        local L = self.Services.Lighting
        if self:_flag("World_NoFog", false) then
            self:_set(L, "FogStart", 0); self:_set(L, "FogEnd", 1e6)
        else
            self:_set(L, "FogStart", self:_flag("World_FogStart", 0))
            self:_set(L, "FogEnd", self:_flag("World_FogEnd", 2500))
            self:_set(L, "FogColor", self:_flag("World_FogColor", Color3.fromRGB(190, 195, 210)))
        end
        if self:_flag("World_Atmosphere", false) then
            local a = self:_fx("Atmosphere")
            a.Density = self:_flag("World_AtmDensity", 0.3)
            a.Offset  = self:_flag("World_AtmOffset", 0.25)
            a.Glare   = self:_flag("World_AtmGlare", 0)
            a.Haze    = self:_flag("World_AtmHaze", 0)
            a.Color   = self:_flag("World_AtmColor", Color3.fromRGB(199, 199, 199))
            a.Decay   = self:_flag("World_AtmDecay", Color3.fromRGB(106, 112, 125))
        else
            self:_killAtmosphere()
        end
    end

    function World:_killAtmosphere()
        local a = self._fxCache and self._fxCache.Atmosphere
        if not a then return end
        for i, inst in ipairs(self._made) do if inst == a then table.remove(self._made, i) break end end
        pcall(function() a:Destroy() end)
        self._fxCache.Atmosphere = nil
    end

    -- E. Post-FX
    function World:_applyPost()
        local cc = self:_fx("ColorCorrectionEffect")
        cc.Enabled = self:_flag("World_Tint", false)
        if cc.Enabled then
            cc.Brightness = self:_flag("World_TintBrightness", 0)
            cc.Contrast   = self:_flag("World_TintContrast", 0)
            cc.Saturation = self:_flag("World_TintSaturation", 0)
            if self:_flag("World_RainbowHue", false) then
                local t = (tick() * self:_flag("World_RainbowSpeed", 1)) % 1
                cc.TintColor = Color3.fromHSV(t, 0.5, 1)
            else
                cc.TintColor = self:_flag("World_TintColor", WHITE)
            end
        end
        local bm = self:_fx("BloomEffect")
        bm.Enabled = self:_flag("World_Bloom", false)
        if bm.Enabled then
            bm.Intensity = self:_flag("World_BloomIntensity", 0.4)
            bm.Size = self:_flag("World_BloomSize", 24)
            bm.Threshold = self:_flag("World_BloomThreshold", 0.95)
        end
        local sr = self:_fx("SunRaysEffect")
        sr.Enabled = self:_flag("World_SunRays", false)
        if sr.Enabled then
            sr.Intensity = self:_flag("World_SunRaysIntensity", 0.05)
            sr.Spread = self:_flag("World_SunRaysSpread", 0.5)
        end
        local df = self:_fx("DepthOfFieldEffect")
        df.Enabled = self:_flag("World_DoF", false)
        if df.Enabled then
            df.FocusDistance = self:_flag("World_DoFFocus", 25)
            df.InFocusRadius = self:_flag("World_DoFRadius", 10)
            df.NearIntensity = self:_flag("World_DoFNear", 0)
            df.FarIntensity  = self:_flag("World_DoFFar", 0.75)
        end
        local bu = self:_fx("BlurEffect")
        bu.Enabled = self:_flag("World_WorldBlur", false)
        if bu.Enabled then bu.Size = self:_flag("World_WorldBlurSize", 12) end
        if self:_flag("World_KillGamePostFX", false) then
            local ok, kids = pcall(function() return self.Services.Lighting:GetChildren() end)
            if ok and kids then
                for _, e in ipairs(kids) do
                    if e:IsA("PostEffect") and not table.find(self._made, e) then
                        self:_set(e, "Enabled", false)
                    end
                end
            end
        end
    end

    -- F. Cielo / celestial  +  G. Nubes (Terrain.Clouds)
    function World:_applySky()
        local L = self.Services.Lighting
        local sky = L:FindFirstChildOfClass("Sky")
        if sky then
            local off = self:_flag("World_NoSky", false)
            self:_set(sky, "CelestialBodiesShown", not off)
            self:_set(sky, "StarCount", off and 0 or self:_flag("World_StarCount", 3000))
            if self:_flag("World_CustomSkybox", false) then
                local faces = { Up = "SkyboxUp", Dn = "SkyboxDn", Lf = "SkyboxLf", Rt = "SkyboxRt", Bk = "SkyboxBk", Ft = "SkyboxFt" }
                for face, prop in pairs(faces) do
                    local v = self:_flag("World_Skybox_" .. face, "")
                    if v ~= "" then self:_set(sky, prop, v) end
                end
                local sun = self:_flag("World_SunTextureId", ""); if sun ~= "" then self:_set(sky, "SunTextureId", sun) end
                local moon = self:_flag("World_MoonTextureId", ""); if moon ~= "" then self:_set(sky, "MoonTextureId", moon) end
                self:_set(sky, "SunAngularSize", self:_flag("World_SunAngularSize", 21))
                self:_set(sky, "MoonAngularSize", self:_flag("World_MoonAngularSize", 11))
            end
        end
        local Terrain = self.Services.Terrain
        if not Terrain or not Terrain.FindFirstChildOfClass then return end
        if not self:_flag("World_Clouds", false) then return end
        local clouds = Terrain:FindFirstChildOfClass("Clouds") or self:_fx("Clouds", Terrain)
        self:_set(clouds, "Enabled", not self:_flag("World_NoClouds", false))
        self:_set(clouds, "Cover", self:_flag("World_CloudCover", 0.5))
        self:_set(clouds, "Density", self:_flag("World_CloudDensity", 0.7))
        self:_set(clouds, "Color", self:_flag("World_CloudColor", WHITE))
    end

    function World:_installApplies()
        self:_register(self._applyLighting)
        self:_register(self._applyTime)
        self:_register(self._applyFog)
        self:_register(self._applyPost)
        self:_register(self._applySky)
    end

    GV.World = World
end
