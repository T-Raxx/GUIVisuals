-- World Visuals (primordial) — build autogenerado
local GV = {}
do local chunk = "return function(GV)\r\
    local U = {}\r\
    function U.clamp(x, a, b) return math.max(a, math.min(b, x)) end\r\
    function U.lerp(a, b, t) return a + (b - a) * t end\r\
    function U.serColor(c)\r\
        return { __ = \"c3\", r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) }\r\
    end\r\
    function U.deColor(t) return Color3.fromRGB(t.r, t.g, t.b) end\r\
    function U.serEnum(e) return { __ = \"en\", t = tostring(e.EnumType), n = e.Name } end\r\
    function U.deEnum(t)\r\
        local et = t.t:gsub(\"^Enum%.\", \"\")\r\
        for _, item in ipairs(Enum[et]:GetEnumItems()) do\r\
            if item.Name == t.n then return item end\r\
        end\r\
    end\r\
    function U.deepcopy(t)\r\
        if type(t) ~= \"table\" then return t end\r\
        local r = {}; for k, v in pairs(t) do r[k] = U.deepcopy(v) end; return r\r\
    end\r\
    GV.Util = U\r\
end\r\
"
local f = loadstring(chunk, '@core/util.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local Color = {}\r\
    local WHITE = Color3.new(1, 1, 1)\r\
    function Color.solid(flags, base)\r\
        local c = flags[base]\r\
        return typeof(c) == \"Color3\" and c or WHITE\r\
    end\r\
    function Color.fade(flags, base, t)\r\
        local c1 = flags[base]\r\
        if typeof(c1) ~= \"Color3\" then return WHITE end\r\
        if not flags[base .. \"_Fade\"] then return c1 end\r\
        t = t or tick()\r\
        local speed = flags[\"Suite_FadeSpeed\"] or 1\r\
        local mode = flags[\"Suite_FadeMode\"] or \"Onda\"\r\
        if mode == \"Rainbow\" then\r\
            local _, s, v = Color3.toHSV(c1)\r\
            return Color3.fromHSV((t * speed * 0.2) % 1, math.max(s, 0.55), math.max(v, 0.7))\r\
        end\r\
        local c2 = flags[base .. \"_2\"]\r\
        if typeof(c2) ~= \"Color3\" then return c1 end\r\
        if mode == \"Pulso\" then\r\
            return c1:Lerp(c2, math.abs(math.sin(t * speed * math.pi)))\r\
        end\r\
        -- Onda (default): oscila suave c1<->c2\r\
        return c1:Lerp(c2, (math.sin(t * speed * math.pi * 2) + 1) / 2)\r\
    end\r\
    GV.Color = Color\r\
end\r\
"
local f = loadstring(chunk, '@core/color.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local U = GV.Util\r\
    local World = {}\r\
    World.__index = World\r\
\r\
    function World.new(opts)\r\
        opts = opts or {}\r\
        local svc = opts.services or {\r\
            Lighting = game:GetService(\"Lighting\"),\r\
            Terrain = workspace:FindFirstChildOfClass(\"Terrain\"),\r\
            RunService = game:GetService(\"RunService\"),\r\
            Workspace = workspace,\r\
        }\r\
        local self = setmetatable({\r\
            Flags = opts.flags or {}, Services = svc, Conns = {},\r\
            _orig = {}, _made = {}, _fxCache = {}, _applies = {},\r\
            Loaded = false, _wasOn = false,\r\
        }, World)\r\
        self:_installApplies()\r\
        return self\r\
    end\r\
\r\
    function World:Set(flag, v) self.Flags[flag] = v end\r\
    function World:Get(flag) return self.Flags[flag] end\r\
    function World:_flag(name, default)\r\
        local v = self.Flags[name]\r\
        if v ~= nil then return v end\r\
        return default\r\
    end\r\
\r\
    -- serializa para config (Color3/Enum -> tablas nombradas)\r\
    function World:GetFlags()\r\
        local out = {}\r\
        for k, v in pairs(self.Flags) do\r\
            if typeof(v) == \"Color3\" then out[k] = U.serColor(v)\r\
            elseif typeof(v) == \"EnumItem\" then out[k] = U.serEnum(v)\r\
            else out[k] = v end\r\
        end\r\
        return out\r\
    end\r\
    function World:LoadFlags(tbl)\r\
        for k, v in pairs(tbl) do\r\
            if type(v) == \"table\" and v.__ == \"c3\" then self.Flags[k] = U.deColor(v)\r\
            elseif type(v) == \"table\" and v.__ == \"en\" then self.Flags[k] = U.deEnum(v)\r\
            else self.Flags[k] = v end\r\
        end\r\
    end\r\
\r\
    -- perfil de juego: defaults, texturas, filtro de parts (bloque J), schema extra\r\
    function World:UseProfile(p)\r\
        if not p then return end\r\
        if p.defaults then\r\
            for k, v in pairs(p.defaults) do if self.Flags[k] == nil then self.Flags[k] = v end end\r\
        end\r\
        self._mapFilter = p.mapFilter\r\
        self._tex = p.textures\r\
        self._profileSchema = p.extraSchema\r\
    end\r\
\r\
    function World:_set(obj, prop, val)\r\
        if not obj then return end\r\
        local ok, cur = pcall(function() return obj[prop] end)\r\
        if not ok then return end\r\
        local mem = self._orig[obj]\r\
        if not mem then mem = {}; self._orig[obj] = mem end\r\
        if mem[prop] == nil then mem[prop] = cur end\r\
        if cur ~= val then pcall(function() obj[prop] = val end) end\r\
    end\r\
    function World:_restoreAll()\r\
        for obj, props in pairs(self._orig) do\r\
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end\r\
        end\r\
        table.clear(self._orig)\r\
    end\r\
\r\
    -- crear (una vez) un efecto propio, nombrado como los del juego para no cantar en scan\r\
    function World:_fx(class, parent)\r\
        local got = self._fxCache[class]\r\
        if got then\r\
            -- reusar el cache; si el juego lo despareento, re-attach (Parent==nil)\r\
            if not got.Parent then pcall(function() got.Parent = parent or self.Services.Lighting end) end\r\
            return got\r\
        end\r\
        local inst = Instance.new(class)\r\
        inst.Name = \"LightingController\"\r\
        pcall(function() inst.Parent = parent or self.Services.Lighting end)\r\
        self._fxCache[class] = inst\r\
        table.insert(self._made, inst)\r\
        return inst\r\
    end\r\
\r\
    function World:_register(fn) table.insert(self._applies, fn) end\r\
\r\
    function World:_step()\r\
        if not self:_flag(\"World_Enabled\", false) then\r\
            if self._wasOn then self:_off() end\r\
            return\r\
        end\r\
        self._wasOn = true\r\
        for _, fn in ipairs(self._applies) do\r\
            local ok, err = pcall(fn, self)\r\
            if not ok then warn(\"[World] apply: \" .. tostring(err)) end\r\
        end\r\
    end\r\
\r\
    function World:_off()\r\
        self._wasOn = false\r\
        if self._wxEmit then self._wxEmit.Enabled = false end\r\
        self._lastWx = nil\r\
        for _, inst in pairs(self._fxCache) do\r\
            pcall(function() if inst:IsA(\"PostEffect\") then inst.Enabled = false end end)\r\
        end\r\
        self:_killAtmosphere() -- destruir, no Density=0: si queda, mata el fog\r\
        self:_restoreVis()\r\
        self:_restoreAll()\r\
    end\r\
\r\
    function World:Init()\r\
        if self.Loaded then return self end\r\
        self.Loaded = true\r\
        local conn = self.Services.RunService.RenderStepped:Connect(function()\r\
            local ok, err = pcall(function() self:_step() end)\r\
            if not ok then warn(\"[World] step: \" .. tostring(err)) end\r\
        end)\r\
        self.Conns[#self.Conns + 1] = conn\r\
        return self\r\
    end\r\
\r\
    function World:Unload()\r\
        if not self.Loaded then return end\r\
        self.Loaded = false\r\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\r\
        table.clear(self.Conns)\r\
        self:_restoreAll()\r\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
        table.clear(self._made)\r\
        self._fxCache = {}\r\
    end\r\
\r\
    ------------------------------------------------------------------ APPLIES\r\
    local WHITE = Color3.fromRGB(255, 255, 255)\r\
\r\
    -- A. Lighting core\r\
    function World:_applyLighting()\r\
        local L = self.Services.Lighting\r\
        if self:_flag(\"World_Fullbright\", false) then\r\
            self:_set(L, \"Ambient\", WHITE); self:_set(L, \"OutdoorAmbient\", WHITE)\r\
            self:_set(L, \"Brightness\", 1); self:_set(L, \"GlobalShadows\", false)\r\
        else\r\
            if self:_flag(\"World_Ambient\", false) then\r\
                local amb = GV.Color.fade(self.Flags, \"World_AmbientColor\", tick())\r\
                self:_set(L, \"Ambient\", amb); self:_set(L, \"OutdoorAmbient\", amb)\r\
            end\r\
            self:_set(L, \"Brightness\", self:_flag(\"World_Brightness\", 3))\r\
            self:_set(L, \"GlobalShadows\", not self:_flag(\"World_NoShadows\", false))\r\
        end\r\
        self:_set(L, \"ExposureCompensation\", self:_flag(\"World_Exposure\", 0))\r\
        if self:_flag(\"World_ColorShift\", false) then\r\
            self:_set(L, \"ColorShift_Top\", GV.Color.fade(self.Flags, \"World_ColorShiftTopColor\", tick()))\r\
            self:_set(L, \"ColorShift_Bottom\", GV.Color.fade(self.Flags, \"World_ColorShiftBottomColor\", tick()))\r\
        end\r\
        self:_set(L, \"EnvironmentDiffuseScale\", self:_flag(\"World_EnvDiffuse\", 1))\r\
        self:_set(L, \"EnvironmentSpecularScale\", self:_flag(\"World_EnvSpecular\", 1))\r\
        self:_set(L, \"GeographicLatitude\", self:_flag(\"World_GeoLatitude\", 41.733))\r\
        local tech = self:_flag(\"World_Technology\", \"\")\r\
        if tech ~= \"\" then pcall(function() L.Technology = Enum.Technology[tech] end) end\r\
    end\r\
\r\
    -- B. Tiempo / sol\r\
    function World:_applyTime()\r\
        local L = self.Services.Lighting\r\
        if self:_flag(\"World_DayNightCycle\", false) then\r\
            local spd = self:_flag(\"World_CycleSpeed\", 1)\r\
            local t = (self._cycleT or self:_flag(\"World_ClockTime\", 12)) + (1 / 60) * spd\r\
            if t >= 24 then t = t - 24 end\r\
            self._cycleT = t\r\
            self:_set(L, \"ClockTime\", t)\r\
        elseif self:_flag(\"World_FreezeTime\", false) then\r\
            if not self._freeze then self._freeze = self:_flag(\"World_ClockTime\", 12) end\r\
            self:_set(L, \"ClockTime\", self._freeze)\r\
        elseif self:_flag(\"World_UseTimeOfDay\", false) then\r\
            local c = self:_flag(\"World_ClockTime\", 12); local h = math.floor(c); local m = math.floor((c - h) * 60)\r\
            self:_set(L, \"TimeOfDay\", string.format(\"%02d:%02d:00\", h, m))\r\
        else\r\
            self._freeze = nil\r\
            self:_set(L, \"ClockTime\", self:_flag(\"World_ClockTime\", 12))\r\
        end\r\
    end\r\
\r\
    -- C. Fog  +  D. Atmosphere (destroy-on-off)\r\
    function World:_applyFog()\r\
        local L = self.Services.Lighting\r\
        if self:_flag(\"World_NoFog\", false) then\r\
            self:_set(L, \"FogStart\", 0); self:_set(L, \"FogEnd\", 1e6)\r\
        else\r\
            self:_set(L, \"FogStart\", self:_flag(\"World_FogStart\", 0))\r\
            self:_set(L, \"FogEnd\", self:_flag(\"World_FogEnd\", 2500))\r\
            if self:_flag(\"World_FogTint\", false) then\r\
                self:_set(L, \"FogColor\", GV.Color.fade(self.Flags, \"World_FogColor\", tick()))\r\
            end\r\
        end\r\
        if self:_flag(\"World_Atmosphere\", false) then\r\
            local a = self:_fx(\"Atmosphere\")\r\
            a.Density = self:_flag(\"World_AtmDensity\", 0.3)\r\
            a.Offset  = self:_flag(\"World_AtmOffset\", 0.25)\r\
            a.Glare   = self:_flag(\"World_AtmGlare\", 0)\r\
            a.Haze    = self:_flag(\"World_AtmHaze\", 0)\r\
            a.Color   = GV.Color.fade(self.Flags, \"World_AtmColor\", tick())\r\
            a.Decay   = GV.Color.fade(self.Flags, \"World_AtmDecay\", tick())\r\
        else\r\
            self:_killAtmosphere()\r\
        end\r\
    end\r\
\r\
    function World:_killAtmosphere()\r\
        local a = self._fxCache and self._fxCache.Atmosphere\r\
        if not a then return end\r\
        for i, inst in ipairs(self._made) do if inst == a then table.remove(self._made, i) break end end\r\
        pcall(function() a:Destroy() end)\r\
        self._fxCache.Atmosphere = nil\r\
    end\r\
\r\
    -- E. Post-FX\r\
    function World:_applyPost()\r\
        local cc = self:_fx(\"ColorCorrectionEffect\")\r\
        cc.Enabled = self:_flag(\"World_Tint\", false)\r\
        if cc.Enabled then\r\
            cc.Brightness = self:_flag(\"World_TintBrightness\", 0)\r\
            cc.Contrast   = self:_flag(\"World_TintContrast\", 0)\r\
            cc.Saturation = self:_flag(\"World_TintSaturation\", 0)\r\
            if self:_flag(\"World_RainbowHue\", false) then\r\
                local t = (tick() * self:_flag(\"World_RainbowSpeed\", 1)) % 1\r\
                cc.TintColor = Color3.fromHSV(t, 0.5, 1)\r\
            else\r\
                cc.TintColor = GV.Color.fade(self.Flags, \"World_TintColor\", tick())\r\
            end\r\
        end\r\
        local bm = self:_fx(\"BloomEffect\")\r\
        bm.Enabled = self:_flag(\"World_Bloom\", false)\r\
        if bm.Enabled then\r\
            bm.Intensity = self:_flag(\"World_BloomIntensity\", 0.4)\r\
            bm.Size = self:_flag(\"World_BloomSize\", 24)\r\
            bm.Threshold = self:_flag(\"World_BloomThreshold\", 0.95)\r\
        end\r\
        local sr = self:_fx(\"SunRaysEffect\")\r\
        sr.Enabled = self:_flag(\"World_SunRays\", false)\r\
        if sr.Enabled then\r\
            sr.Intensity = self:_flag(\"World_SunRaysIntensity\", 0.05)\r\
            sr.Spread = self:_flag(\"World_SunRaysSpread\", 0.5)\r\
        end\r\
        local df = self:_fx(\"DepthOfFieldEffect\")\r\
        df.Enabled = self:_flag(\"World_DoF\", false)\r\
        if df.Enabled then\r\
            df.FocusDistance = self:_flag(\"World_DoFFocus\", 25)\r\
            df.InFocusRadius = self:_flag(\"World_DoFRadius\", 10)\r\
            df.NearIntensity = self:_flag(\"World_DoFNear\", 0)\r\
            df.FarIntensity  = self:_flag(\"World_DoFFar\", 0.75)\r\
        end\r\
        local bu = self:_fx(\"BlurEffect\")\r\
        bu.Enabled = self:_flag(\"World_WorldBlur\", false)\r\
        if bu.Enabled then bu.Size = self:_flag(\"World_WorldBlurSize\", 12) end\r\
        if self:_flag(\"World_KillGamePostFX\", false) then\r\
            local ok, kids = pcall(function() return self.Services.Lighting:GetChildren() end)\r\
            if ok and kids then\r\
                for _, e in ipairs(kids) do\r\
                    if e:IsA(\"PostEffect\") and not table.find(self._made, e) then\r\
                        self:_set(e, \"Enabled\", false)\r\
                    end\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    -- F. Cielo / celestial  +  G. Nubes (Terrain.Clouds)\r\
    function World:_applySky()\r\
        local L = self.Services.Lighting\r\
        local sky = L:FindFirstChildOfClass(\"Sky\")\r\
        if sky then\r\
            local off = self:_flag(\"World_NoSky\", false)\r\
            self:_set(sky, \"CelestialBodiesShown\", not off)\r\
            self:_set(sky, \"StarCount\", off and 0 or self:_flag(\"World_StarCount\", 3000))\r\
            if self:_flag(\"World_CustomSkybox\", false) then\r\
                local faces = { Up = \"SkyboxUp\", Dn = \"SkyboxDn\", Lf = \"SkyboxLf\", Rt = \"SkyboxRt\", Bk = \"SkyboxBk\", Ft = \"SkyboxFt\" }\r\
                for face, prop in pairs(faces) do\r\
                    local v = self:_flag(\"World_Skybox_\" .. face, \"\")\r\
                    if v ~= \"\" then self:_set(sky, prop, v) end\r\
                end\r\
                local sun = self:_flag(\"World_SunTextureId\", \"\"); if sun ~= \"\" then self:_set(sky, \"SunTextureId\", sun) end\r\
                local moon = self:_flag(\"World_MoonTextureId\", \"\"); if moon ~= \"\" then self:_set(sky, \"MoonTextureId\", moon) end\r\
                self:_set(sky, \"SunAngularSize\", self:_flag(\"World_SunAngularSize\", 21))\r\
                self:_set(sky, \"MoonAngularSize\", self:_flag(\"World_MoonAngularSize\", 11))\r\
            end\r\
        end\r\
        local Terrain = self.Services.Terrain\r\
        if not Terrain or not Terrain.FindFirstChildOfClass then return end\r\
        if not self:_flag(\"World_Clouds\", false) then return end\r\
        local clouds = Terrain:FindFirstChildOfClass(\"Clouds\") or self:_fx(\"Clouds\", Terrain)\r\
        self:_set(clouds, \"Enabled\", not self:_flag(\"World_NoClouds\", false))\r\
        self:_set(clouds, \"Cover\", self:_flag(\"World_CloudCover\", 0.5))\r\
        self:_set(clouds, \"Density\", self:_flag(\"World_CloudDensity\", 0.7))\r\
        self:_set(clouds, \"Color\", GV.Color.fade(self.Flags, \"World_CloudColor\", tick()))\r\
    end\r\
\r\
    -- H. Terrain / agua\r\
    function World:_applyWater()\r\
        local Terrain = self.Services.Terrain\r\
        if not Terrain or not self:_flag(\"World_WaterEnable\", false) then return end\r\
        self:_set(Terrain, \"WaterColor\", GV.Color.fade(self.Flags, \"World_WaterColor\", tick()))\r\
        self:_set(Terrain, \"WaterTransparency\", self:_flag(\"World_WaterTransparency\", 0.3))\r\
        self:_set(Terrain, \"WaterReflectance\", self:_flag(\"World_WaterReflectance\", 1))\r\
        self:_set(Terrain, \"WaterWaveSize\", self:_flag(\"World_WaterWaveSize\", 0.15))\r\
        self:_set(Terrain, \"WaterWaveSpeed\", self:_flag(\"World_WaterWaveSpeed\", 10))\r\
        self:_set(Terrain, \"Decoration\", self:_flag(\"World_TerrainDecoration\", true))\r\
    end\r\
\r\
    -- I. Clima local (particulas sobre la camara). Texturas del cliente (no dependen de red).\r\
    local TEX_RAIN = \"rbxassetid://13911374915\" -- streaks\r\
    local TEX_SNOW = \"rbxassetid://15414665346\" -- dots\r\
    local WX = {\r\
        [\"Lluvia\"]        = { tex = TEX_RAIN, rate = 400,  speed = 105, life = 1.0,  size = 0.9,  squash = 6, spread = 1.5, drag = 0,   accel = Vector3.new(0, -35, 0),    transp = 0.45, light = 0.15, rot = 0,  rotSpeed = 0 },\r\
        [\"Lluvia fuerte\"] = { tex = TEX_RAIN, rate = 1400, speed = 150, life = 0.85, size = 1.15, squash = 9, spread = 2.5, drag = 0,   accel = Vector3.new(-14, -70, 0),  transp = 0.3,  light = 0.2,  rot = -9, rotSpeed = 0 },\r\
        [\"Nieve\"]         = { tex = TEX_SNOW, rate = 190,  speed = 6,   life = 6.5,  size = 0.28, squash = 0, spread = 26,  drag = 2.8, accel = Vector3.new(1.2, -2.4, 0.7), transp = 0.25, light = 0.05, rot = 0, rotSpeed = 22 },\r\
        [\"Niebla\"]        = { tex = TEX_SNOW, rate = 60,   speed = 2,   life = 9,    size = 6,    squash = 0, spread = 40,  drag = 4,   accel = Vector3.new(0.5, -0.4, 0.3), transp = 0.75, light = 0.02, rot = 0, rotSpeed = 4 },\r\
        [\"Ceniza\"]        = { tex = TEX_SNOW, rate = 120,  speed = 8,   life = 5,    size = 0.4,  squash = 0, spread = 30,  drag = 2,   accel = Vector3.new(2, -4, 1),      transp = 0.3,  light = 0.6,  rot = 0, rotSpeed = 30 },\r\
        [\"Luciérnagas\"]   = { tex = TEX_SNOW, rate = 40,   speed = 3,   life = 7,    size = 0.25, squash = 0, spread = 45,  drag = 3,   accel = Vector3.new(0, 0.2, 0),     transp = 0.1,  light = 1,    rot = 0, rotSpeed = 10 },\r\
        [\"Custom\"]        = { tex = TEX_SNOW, rate = 300,  speed = 20,  life = 4,    size = 1,    squash = 0, spread = 20,  drag = 1,   accel = Vector3.new(0, -10, 0),     transp = 0.3,  light = 0.3,  rot = 0, rotSpeed = 8 },\r\
    }\r\
\r\
    function World:_wxRig()\r\
        if self._wxPart and self._wxPart.Parent then return self._wxPart, self._wxEmit end\r\
        local p = Instance.new(\"Part\")\r\
        p.Name = \"Camera\"\r\
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false\r\
        p.Transparency = 1; p.Size = Vector3.new(1, 1, 1)\r\
        p.Parent = workspace\r\
        local e = Instance.new(\"ParticleEmitter\")\r\
        e.Enabled = false\r\
        e.EmissionDirection = Enum.NormalId.Bottom\r\
        e.LockedToPart = false\r\
        e.Parent = p\r\
        self._wxPart, self._wxEmit = p, e\r\
        table.insert(self._made, p)\r\
        return p, e\r\
    end\r\
\r\
    function World:_applyWeather()\r\
        if not self:_flag(\"World_Weather\", false) then\r\
            if self._wxEmit then self._wxEmit.Enabled = false end\r\
            self._lastWx = nil\r\
            return\r\
        end\r\
        local mode = self:_flag(\"World_WeatherMode\", \"Lluvia\")\r\
        local cfg = WX[mode]; if not cfg then return end\r\
        local part, emit = self:_wxRig()\r\
        local cam = self.Services.Workspace and self.Services.Workspace.CurrentCamera\r\
        if not cam then return end\r\
        local area = self:_flag(\"World_WeatherArea\", 90)\r\
        part.Size = Vector3.new(area, 1, area)\r\
        part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 28, 0))\r\
\r\
        if self._lastWx ~= mode then\r\
            self._lastWx = mode\r\
            local tex = cfg.tex\r\
            if mode == \"Custom\" then\r\
                local ct = self:_flag(\"World_WeatherCustomTex\", \"\")\r\
                if ct ~= \"\" then tex = ct end\r\
            elseif self._tex then\r\
                if cfg.tex == TEX_RAIN and self._tex.rain then tex = self._tex.rain\r\
                elseif cfg.tex == TEX_SNOW and self._tex.snow then tex = self._tex.snow end\r\
            end\r\
            emit.Texture = tex\r\
            emit.Drag = cfg.drag\r\
            emit.Squash = NumberSequence.new(cfg.squash)\r\
            emit.SpreadAngle = Vector2.new(cfg.spread, cfg.spread)\r\
            emit.Rotation = NumberRange.new(cfg.rot)\r\
            emit.RotSpeed = NumberRange.new(-cfg.rotSpeed, cfg.rotSpeed)\r\
            emit.ZOffset = 0\r\
            emit.EmissionDirection = Enum.NormalId.Bottom\r\
        end\r\
        local dens = self:_flag(\"World_WeatherDensity\", 1)\r\
        local spd  = self:_flag(\"World_WeatherSpeed\", 1)\r\
        local sz   = self:_flag(\"World_WeatherSize\", 1)\r\
        -- viento: rota la componente horizontal de la aceleracion\r\
        local wind = math.rad(self:_flag(\"World_WeatherWindDir\", 0))\r\
        local accel = cfg.accel * spd\r\
        if wind ~= 0 then\r\
            local mag = math.abs(accel.X) + 6\r\
            accel = Vector3.new(math.sin(wind) * mag, accel.Y, math.cos(wind) * mag)\r\
        end\r\
        emit.Rate = cfg.rate * dens\r\
        emit.Lifetime = NumberRange.new(cfg.life * 0.85, cfg.life)\r\
        emit.Speed = NumberRange.new(cfg.speed * spd * 0.9, cfg.speed * spd)\r\
        emit.Acceleration = accel\r\
        emit.Size = NumberSequence.new(cfg.size * sz)\r\
        emit.Color = ColorSequence.new(GV.Color.fade(self.Flags, \"World_WeatherColor\", tick()))\r\
        emit.LightEmission = self:_flag(\"World_WeatherGlow\", cfg.light)\r\
        emit.Transparency = NumberSequence.new(self:_flag(\"World_WeatherTransparency\", cfg.transp))\r\
        emit.Enabled = true\r\
        -- relampago: flash breve periodico (cosmetico, best-effort)\r\
        if self:_flag(\"World_Lightning\", false) then\r\
            local now = tick()\r\
            if not self._lightNext or now >= self._lightNext then\r\
                self._lightNext = now + 3 + math.random() * 5\r\
                pcall(function() self.Services.Lighting.Brightness = self:_flag(\"World_Brightness\", 3) + 6 end)\r\
            end\r\
        end\r\
    end\r\
\r\
    -- J. Visibilidad (agresivo). Memoria PROPIA (self._visOrig) que revierte por-feature al apagar\r\
    -- el toggle (no solo al apagar el master). Gateado tras World_Advanced + mapFilter del perfil.\r\
    function World:_visRemember(obj, prop)\r\
        local m = self._visOrig[obj]; if not m then m = {}; self._visOrig[obj] = m end\r\
        if m[prop] == nil then local ok, cur = pcall(function() return obj[prop] end); if ok then m[prop] = cur end end\r\
    end\r\
    function World:_visRestore(obj, prop)\r\
        local m = self._visOrig[obj]\r\
        if m and m[prop] ~= nil then pcall(function() obj[prop] = m[prop] end); m[prop] = nil end\r\
    end\r\
    function World:_restoreVis()\r\
        for obj, props in pairs(self._visOrig or {}) do\r\
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end\r\
        end\r\
        self._visOrig = {}\r\
    end\r\
\r\
    function World:_applyVisibility()\r\
        self._visOrig = self._visOrig or {}\r\
        local adv = self:_flag(\"World_Advanced\", false)\r\
        local killP  = adv and self:_flag(\"World_KillParticles\", false)\r\
        local smooth = adv and self:_flag(\"World_ForceSmoothPlastic\", false)\r\
        local tr     = adv and self:_flag(\"World_MapTransparent\", false)\r\
        local noTex  = adv and self:_flag(\"World_NoTextures\", false)\r\
        if not (killP or smooth or tr or noTex) then\r\
            if next(self._visOrig) then self:_restoreVis() end -- todo apagado -> revertir\r\
            return\r\
        end\r\
        local amount = self:_flag(\"World_MapTransparentAmount\", 0.6)\r\
        local filter = self._mapFilter\r\
        local ok, list = pcall(function() return self.Services.Workspace:GetDescendants() end)\r\
        if not ok or not list then return end\r\
        for _, d in ipairs(list) do\r\
            if not (filter and filter(d)) then\r\
                if d:IsA(\"ParticleEmitter\") or d:IsA(\"Beam\") or d:IsA(\"Trail\") then\r\
                    if killP then self:_visRemember(d, \"Enabled\"); if d.Enabled then d.Enabled = false end\r\
                    else self:_visRestore(d, \"Enabled\") end\r\
                elseif d:IsA(\"BasePart\") then\r\
                    if smooth then self:_visRemember(d, \"Material\"); if d.Material ~= Enum.Material.SmoothPlastic then d.Material = Enum.Material.SmoothPlastic end\r\
                    else self:_visRestore(d, \"Material\") end\r\
                    if tr then self:_visRemember(d, \"Transparency\"); if d.Transparency < amount then d.Transparency = amount end\r\
                    else self:_visRestore(d, \"Transparency\") end\r\
                elseif d:IsA(\"Decal\") or d:IsA(\"Texture\") then\r\
                    if noTex then self:_visRemember(d, \"Transparency\"); if d.Transparency < 1 then d.Transparency = 1 end\r\
                    else self:_visRestore(d, \"Transparency\") end\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    -- K. Presets: batch de flags\r\
    local PRESETS = {\r\
        Competitivo         = { World_Enabled = true, World_Fullbright = true, World_NoFog = true, World_NoShadows = true, World_Atmosphere = false, World_Bloom = false },\r\
        [\"Cinematográfico\"] = { World_Enabled = true, World_Fullbright = false, World_Bloom = true, World_BloomIntensity = 1.2, World_DoF = true, World_Exposure = 0.2, World_Tint = true, World_TintContrast = 0.1 },\r\
        [\"Día\"]             = { World_Enabled = true, World_ClockTime = 13, World_Fullbright = false, World_NoFog = true },\r\
        Noche               = { World_Enabled = true, World_ClockTime = 0, World_Brightness = 1, World_Fullbright = false },\r\
        Atardecer           = { World_Enabled = true, World_ClockTime = 17.5, World_Atmosphere = true, World_AtmDensity = 0.4, World_AtmColor = Color3.fromRGB(255, 170, 120) },\r\
        Niebla              = { World_Enabled = true, World_NoFog = false, World_FogStart = 0, World_FogEnd = 180, World_FogTint = true, World_FogColor = Color3.fromRGB(180, 185, 195) },\r\
    }\r\
    function World:ApplyPreset(name)\r\
        local p = PRESETS[name]; if not p then return end\r\
        for k, v in pairs(p) do self:Set(k, v) end\r\
    end\r\
\r\
    function World:_installApplies()\r\
        self:_register(self._applyLighting)\r\
        self:_register(self._applyTime)\r\
        self:_register(self._applyFog)\r\
        self:_register(self._applyPost)\r\
        self:_register(self._applySky)\r\
        self:_register(self._applyWater)\r\
        self:_register(self._applyWeather)\r\
        self:_register(self._applyVisibility)\r\
    end\r\
\r\
    GV.World = World\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.world = GV.Modules.world or {}\r\
    GV.Modules.world.new = function(o) return World.new(o) end\r\
end\r\
"
local f = loadstring(chunk, '@core/World.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    if not (Drawing and Drawing.new) then\r\
        GV.Modules = GV.Modules or {}; GV.Modules.esp = GV.Modules.esp or {}\r\
        GV.Modules.esp.new = GV.Modules.esp.new or function() return { Init = function() end, Unload = function() end } end\r\
        return\r\
    end\r\
    local ESP = {}\r\
    ESP.__index = ESP\r\
\r\
    function ESP.new(opts)\r\
        opts = opts or {}\r\
        local svc = opts.services or {\r\
            Players = game:GetService(\"Players\"),\r\
            RunService = game:GetService(\"RunService\"),\r\
            Workspace = workspace,\r\
            CollectionService = game:GetService(\"CollectionService\"),\r\
        }\r\
        return setmetatable({\r\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\r\
            Conns = {}, Drawings = {}, Objects = {}, Highlights = {}, Loaded = false,\r\
        }, ESP)\r\
    end\r\
\r\
    function ESP:Set(k, v) self.Flags[k] = v end\r\
    function ESP:Get(k) return self.Flags[k] end\r\
    function ESP:_flag(k, d)\r\
        local v = self.Flags[\"ESP_\" .. k]; if v ~= nil then return v end; return d\r\
    end\r\
    function ESP:UseProfile(p)\r\
        if not p then return end\r\
        if p.provider then self._provider = p.provider end\r\
        if p.objectSources then self._objectSources = p.objectSources end\r\
    end\r\
\r\
    function ESP:_draw(class, props)\r\
        local o = Drawing.new(class)\r\
        o.Visible = false\r\
        if props then for k, v in pairs(props) do o[k] = v end end\r\
        table.insert(self.Drawings, o)\r\
        return o\r\
    end\r\
\r\
    function ESP:_provget()\r\
        local p = self._provider or GV.DefaultProvider\r\
        if not p then return {} end\r\
        local ok, list = pcall(p.getTargets, self)\r\
        return (ok and list) or {}\r\
    end\r\
\r\
    local BLACK = Color3.new(0, 0, 0)\r\
    local function hideBundle(b)\r\
        for k, o in pairs(b) do\r\
            if k == \"skel\" then for _, l in ipairs(o) do pcall(function() l.Visible = false end) end\r\
            else pcall(function() o.Visible = false end) end\r\
        end\r\
    end\r\
\r\
    function ESP:_make()\r\
        return {\r\
            box     = self:_draw(\"Square\", { Filled = false, Thickness = 1 }),\r\
            boxOl   = self:_draw(\"Square\", { Filled = false, Thickness = 3, Color = BLACK }),\r\
            name    = self:_draw(\"Text\", { Center = true, Outline = true }),\r\
            dist    = self:_draw(\"Text\", { Center = true, Outline = true }),\r\
            hpBg    = self:_draw(\"Square\", { Filled = true, Color = BLACK }),\r\
            hpBar   = self:_draw(\"Square\", { Filled = true }),\r\
            hpText  = self:_draw(\"Text\", { Center = false, Outline = true }),\r\
            tracer  = self:_draw(\"Line\", { Thickness = 1 }),\r\
            headdot = self:_draw(\"Circle\", { Filled = true, NumSides = 16 }),\r\
            look    = self:_draw(\"Line\", { Thickness = 1 }),\r\
            arrow   = self:_draw(\"Triangle\", { Filled = true }),\r\
            skel    = {},\r\
        }\r\
    end\r\
\r\
    function ESP:_drawArrow(b, tg, cam, t, vp)\r\
        local center = Vector2.new(vp.X / 2, vp.Y / 2)\r\
        local sp = cam:WorldToViewportPoint(tg.root.Position)\r\
        local dir\r\
        if sp.Z > 0 then dir = Vector2.new(sp.X, sp.Y) - center\r\
        else dir = center - Vector2.new(sp.X, sp.Y) end\r\
        if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end\r\
        dir = dir.Unit\r\
        local radius = self:_flag(\"OffScreenRadius\", 200)\r\
        local size = self:_flag(\"OffScreenSize\", 16)\r\
        local perp = Vector2.new(-dir.Y, dir.X)\r\
        local tip = center + dir * radius\r\
        b.arrow.Visible = true\r\
        b.arrow.PointA = tip\r\
        b.arrow.PointB = tip - dir * size + perp * (size * 0.6)\r\
        b.arrow.PointC = tip - dir * size - perp * (size * 0.6)\r\
        b.arrow.Color = self:_col(tg, \"ESP_OffScreenColor\", t)\r\
        b.arrow.ZIndex = 5\r\
    end\r\
\r\
    function ESP:_drawExtras(b, tg, cam, t)\r\
        -- skeleton\r\
        local showSkel = self:_flag(\"Skeleton\", false)\r\
        local bones = tg.bones or {}\r\
        for i, bone in ipairs(bones) do\r\
            local l = b.skel[i]\r\
            if not l then l = self:_draw(\"Line\", { Thickness = 1 }); b.skel[i] = l end\r\
            local pa = tg.model:FindFirstChild(bone.a)\r\
            local pb = tg.model:FindFirstChild(bone.b)\r\
            if showSkel and pa and pb then\r\
                local va = cam:WorldToViewportPoint(pa.Position)\r\
                local vb = cam:WorldToViewportPoint(pb.Position)\r\
                if va.Z > 0 and vb.Z > 0 then\r\
                    l.Visible = true\r\
                    l.From = Vector2.new(va.X, va.Y); l.To = Vector2.new(vb.X, vb.Y)\r\
                    l.Color = self:_col(tg, \"ESP_SkeletonColor\", t); l.ZIndex = 2\r\
                else l.Visible = false end\r\
            else l.Visible = false end\r\
        end\r\
        for i = #bones + 1, #b.skel do b.skel[i].Visible = false end\r\
        -- headdot\r\
        local showDot = self:_flag(\"HeadDot\", false)\r\
        b.headdot.Visible = showDot\r\
        if showDot then\r\
            local hv = cam:WorldToViewportPoint(tg.head.Position)\r\
            if hv.Z > 0 then\r\
                b.headdot.Position = Vector2.new(hv.X, hv.Y)\r\
                b.headdot.Radius = self:_flag(\"HeadDotRadius\", 3)\r\
                b.headdot.Color = self:_col(tg, \"ESP_HeadDotColor\", t)\r\
                b.headdot.ZIndex = 4\r\
            else b.headdot.Visible = false end\r\
        end\r\
        -- look direction\r\
        local showLook = self:_flag(\"LookDir\", false)\r\
        b.look.Visible = showLook\r\
        if showLook then\r\
            local hp = tg.head.Position\r\
            local a = cam:WorldToViewportPoint(hp)\r\
            local c = cam:WorldToViewportPoint(hp + tg.head.CFrame.LookVector * self:_flag(\"LookLength\", 2))\r\
            if a.Z > 0 and c.Z > 0 then\r\
                b.look.From = Vector2.new(a.X, a.Y); b.look.To = Vector2.new(c.X, c.Y)\r\
                b.look.Color = self:_col(tg, \"ESP_LookDirColor\", t); b.look.ZIndex = 3\r\
            else b.look.Visible = false end\r\
        end\r\
    end\r\
\r\
    function ESP:_healthColor(frac)\r\
        return Color3.fromRGB(math.floor(220 * (1 - frac)) + 20, math.floor(200 * frac) + 20, 40)\r\
    end\r\
\r\
    -- color de un target para un flag base, segun ColorMode\r\
    local TEAM_ENEMY, TEAM_ALLY = Color3.fromRGB(235, 64, 52), Color3.fromRGB(64, 200, 96)\r\
    local GREY = Color3.fromRGB(90, 90, 90)\r\
    function ESP:_col(tg, base, t)\r\
        local mode = self:_flag(\"ColorMode\", \"Fijo\")\r\
        if mode == \"Team\" then return tg.isEnemy and TEAM_ENEMY or TEAM_ALLY end\r\
        if mode == \"Visibilidad\" then\r\
            return tg._visible and GV.Color.fade(self.Flags, \"ESP_VisibleColor\", t)\r\
                or GV.Color.fade(self.Flags, \"ESP_HiddenColor\", t)\r\
        end\r\
        if mode == \"Distancia\" then\r\
            local frac = math.clamp((tg._dist or 0) / self:_flag(\"MaxDistance\", 1200), 0, 1)\r\
            return GV.Color.fade(self.Flags, base, t):Lerp(GREY, frac)\r\
        end\r\
        return GV.Color.fade(self.Flags, base, t)\r\
    end\r\
\r\
    -- raycast LOS camara->root (ignora camara + char local)\r\
    function ESP:_visible(root)\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        if not cam or not root then return true end\r\
        local origin = cam.CFrame.Position\r\
        local params = RaycastParams.new()\r\
        params.FilterType = Enum.RaycastFilterType.Exclude\r\
        local ignore = { cam }\r\
        local lp = self.Services.Players and self.Services.Players.LocalPlayer\r\
        if lp and lp.Character then table.insert(ignore, lp.Character) end\r\
        params.FilterDescendantsInstances = ignore\r\
        local res = self.Services.Workspace:Raycast(origin, root.Position - origin, params)\r\
        if not res then return true end\r\
        return res.Instance and root.Parent and res.Instance:IsDescendantOf(root.Parent) or false\r\
    end\r\
\r\
    -- chams via Highlight (detectable). Uno por modelo en self.Highlights.\r\
    function ESP:_chams(tg, t)\r\
        if not self:_flag(\"Chams\", false) then\r\
            local h = self.Highlights[tg.model]; if h then h.Enabled = false end\r\
            return\r\
        end\r\
        local h = self.Highlights[tg.model]\r\
        if not h or not h.Parent then\r\
            h = Instance.new(\"Highlight\")\r\
            h.Name = \"LC\"\r\
            h.Adornee = tg.model\r\
            h.Parent = self.Services.Workspace.CurrentCamera\r\
            self.Highlights[tg.model] = h\r\
        end\r\
        h.Enabled = true\r\
        h.FillColor = GV.Color.fade(self.Flags, \"ESP_ChamsFill\", t)\r\
        h.OutlineColor = GV.Color.fade(self.Flags, \"ESP_ChamsOutline\", t)\r\
        h.FillTransparency = self:_flag(\"ChamsFillTransparency\", 0.5)\r\
        h.OutlineTransparency = self:_flag(\"ChamsOutlineTransparency\", 0)\r\
        h.DepthMode = (self:_flag(\"ChamsDepthMode\", \"AlwaysOnTop\") == \"Occluded\")\r\
            and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop\r\
    end\r\
\r\
    function ESP:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)\r\
        local topV = cam:WorldToViewportPoint(tg.head.Position + Vector3.new(0, 0.6, 0))\r\
        local botV = cam:WorldToViewportPoint(tg.root.Position - Vector3.new(0, 3.0, 0))\r\
        local onScreen = topV.Z > 0 and topV.X >= 0 and topV.X <= vp.X and topV.Y >= 0 and topV.Y <= vp.Y\r\
        b.arrow.Visible = false\r\
        if not onScreen then\r\
            -- ocultar el bundle on-screen; flecha off-screen si aplica\r\
            for _, k in ipairs({ \"box\", \"boxOl\", \"name\", \"dist\", \"hpBg\", \"hpBar\", \"hpText\", \"tracer\", \"headdot\", \"look\" }) do\r\
                b[k].Visible = false\r\
            end\r\
            for _, l in ipairs(b.skel) do l.Visible = false end\r\
            if self:_flag(\"OffScreen\", false) then self:_drawArrow(b, tg, cam, t, vp) end\r\
            return\r\
        end\r\
        local top = Vector2.new(topV.X, topV.Y)\r\
        local bot = Vector2.new(botV.X, botV.Y)\r\
        local h = math.abs(bot.Y - top.Y)\r\
        local w = h * 0.62\r\
        local x = top.X - w / 2\r\
        local y = top.Y\r\
\r\
        local showBox   = self:_flag(\"Box\", true)\r\
        local showName  = self:_flag(\"Name\", true)\r\
        local showHp    = self:_flag(\"Health\", true)\r\
        local showDist  = self:_flag(\"Distance\", true)\r\
        local showTrace = self:_flag(\"Tracer\", false)\r\
        local hpStyle   = self:_flag(\"HealthStyle\", \"Barra\")\r\
        local showBar   = hpStyle == \"Barra\" or hpStyle == \"Barra+Numero\"\r\
        local showNum   = hpStyle == \"Numero\" or hpStyle == \"Barra+Numero\"\r\
\r\
        -- box\r\
        b.box.Visible = showBox\r\
        b.boxOl.Visible = showBox and self:_flag(\"BoxOutline\", true)\r\
        if showBox then\r\
            b.box.Color = self:_col(tg, \"ESP_BoxColor\", t)\r\
            local filled = self:_flag(\"BoxFilled\", false)\r\
            b.box.Filled = filled\r\
            -- Drawing.Transparency: 1=opaco, 0=invisible -> alpha del relleno\r\
            b.box.Transparency = filled and self:_flag(\"BoxFillAlpha\", 0.35) or 1\r\
            b.box.Thickness = self:_flag(\"BoxThickness\", 1)\r\
            b.box.Size = Vector2.new(w, h); b.box.Position = Vector2.new(x, y); b.box.ZIndex = 2\r\
            b.boxOl.Size = b.box.Size; b.boxOl.Position = b.box.Position; b.boxOl.ZIndex = 1\r\
        end\r\
\r\
        -- health\r\
        local frac = math.clamp((tg.health or 0) / (tg.maxHealth and tg.maxHealth > 0 and tg.maxHealth or 100), 0, 1)\r\
        b.hpBg.Visible = showHp and showBar\r\
        b.hpBar.Visible = showHp and showBar\r\
        b.hpText.Visible = showHp and showNum\r\
        if showHp and showBar then\r\
            local bx = x - 5\r\
            b.hpBg.Position = Vector2.new(bx, y - 1); b.hpBg.Size = Vector2.new(3, h + 2); b.hpBg.ZIndex = 2\r\
            local bh = h * frac\r\
            b.hpBar.Position = Vector2.new(bx, y + (h - bh)); b.hpBar.Size = Vector2.new(3, bh)\r\
            b.hpBar.Color = self:_healthColor(frac); b.hpBar.ZIndex = 3\r\
        end\r\
        if showHp and showNum then\r\
            b.hpText.Text = tostring(math.floor(tg.health or 0))\r\
            b.hpText.Font = font; b.hpText.Size = textSize; b.hpText.Color = self:_healthColor(frac)\r\
            b.hpText.Position = Vector2.new(x + w + 3, y); b.hpText.ZIndex = 4\r\
        end\r\
\r\
        -- name\r\
        b.name.Visible = showName\r\
        if showName then\r\
            b.name.Text = tg.name or \"?\"\r\
            b.name.Font = font; b.name.Size = textSize; b.name.Color = self:_col(tg, \"ESP_NameColor\", t)\r\
            b.name.Position = Vector2.new(top.X, y - textSize - 2); b.name.ZIndex = 4\r\
        end\r\
\r\
        -- distance\r\
        b.dist.Visible = showDist\r\
        if showDist then\r\
            b.dist.Text = math.floor(dist) .. \"m\"\r\
            b.dist.Font = font; b.dist.Size = textSize; b.dist.Color = Color3.fromRGB(180, 180, 185)\r\
            b.dist.Position = Vector2.new(top.X, bot.Y + 2); b.dist.ZIndex = 4\r\
        end\r\
\r\
        -- tracer\r\
        b.tracer.Visible = showTrace\r\
        if showTrace then\r\
            local from = self:_flag(\"TracerFrom\", \"Bottom\")\r\
            local fx, fy = vp.X / 2, vp.Y\r\
            if from == \"Center\" then fy = vp.Y / 2 elseif from == \"Top\" then fy = 0\r\
            elseif from == \"Mouse\" then local m = self.Services.Workspace.CurrentCamera; fx, fy = vp.X / 2, vp.Y / 2 end\r\
            b.tracer.From = Vector2.new(fx, fy)\r\
            b.tracer.To = Vector2.new(top.X, bot.Y)\r\
            b.tracer.Color = self:_col(tg, \"ESP_TracerColor\", t)\r\
            b.tracer.ZIndex = 1\r\
        end\r\
\r\
        self:_drawExtras(b, tg, cam, t)\r\
    end\r\
\r\
    function ESP:_update()\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        if not cam then return end\r\
        local enabled = self:_flag(\"Enabled\", false)\r\
        local targets = enabled and self:_provget() or {}\r\
        local origin = cam.CFrame.Position\r\
        local vp = cam.ViewportSize\r\
        local font = self:_flag(\"Font\", 2)\r\
        local textSize = self:_flag(\"TextSize\", 13)\r\
        local maxDist = self:_flag(\"MaxDistance\", 1200)\r\
        if maxDist <= 0 then maxDist = math.huge end -- 0 = sin limite de distancia\r\
        local maxTargets = self:_flag(\"MaxTargets\", 50)\r\
        local t = tick()\r\
        local live, count = {}, 0\r\
        for _, tg in ipairs(targets) do\r\
            if tg.root and tg.head and count < maxTargets and self:_passFilters(tg) then\r\
                local dist = (tg.root.Position - origin).Magnitude\r\
                if dist <= maxDist then\r\
                    count += 1\r\
                    live[tg.model] = true\r\
                    tg._dist = dist\r\
                    if self:_flag(\"VisibleCheck\", false) or self:_flag(\"ColorMode\", \"Fijo\") == \"Visibilidad\" then\r\
                        tg._visible = self:_visible(tg.root)\r\
                    else\r\
                        tg._visible = true\r\
                    end\r\
                    local b = self.Objects[tg.model] or self:_make()\r\
                    self.Objects[tg.model] = b\r\
                    self:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)\r\
                    self:_chams(tg, t)\r\
                end\r\
            end\r\
        end\r\
        for model, b in pairs(self.Objects) do\r\
            if not live[model] then\r\
                hideBundle(b)\r\
                local h = self.Highlights[model]; if h then h.Enabled = false end\r\
                if not (model and model.Parent) then self.Objects[model] = nil end\r\
            end\r\
        end\r\
        self:_updateObjects()\r\
    end\r\
\r\
    function ESP:_passFilters(tg)\r\
        if self:_flag(\"DeadCheck\", false) and (tg.health or 0) <= 0 then return false end\r\
        if self:_flag(\"PlayersOnly\", false) and tg.isPlayer == false then return false end\r\
        return true\r\
    end\r\
\r\
    -- Object ESP: fuentes declaradas por el perfil (tag o clase) -> box+name+dist\r\
    function ESP:_updateObjects()\r\
        self._objBundles = self._objBundles or {}\r\
        local live = {}\r\
        if self:_flag(\"Objects\", false) and self._objectSources then\r\
            local cam = self.Services.Workspace.CurrentCamera\r\
            if cam then\r\
                local origin, vp, t = cam.CFrame.Position, cam.ViewportSize, tick()\r\
                for _, src in ipairs(self._objectSources) do\r\
                    if self:_flag(\"Obj_\" .. (src.key or src.name), true) then\r\
                        local insts = {}\r\
                        if src.tag then insts = self.Services.CollectionService:GetTagged(src.tag)\r\
                        elseif src.classFilter then\r\
                            for _, d in ipairs(self.Services.Workspace:GetDescendants()) do\r\
                                if d:IsA(src.classFilter) then table.insert(insts, d) end\r\
                            end\r\
                        end\r\
                        for _, inst in ipairs(insts) do\r\
                            local part = inst:IsA(\"BasePart\") and inst or inst:FindFirstChildWhichIsA(\"BasePart\")\r\
                            if part then\r\
                                local dist = (part.Position - origin).Magnitude\r\
                                if dist <= (src.maxDistance or self:_flag(\"MaxDistance\", 1200)) then\r\
                                    live[inst] = true\r\
                                    local ob = self._objBundles[inst]\r\
                                    if not ob then\r\
                                        ob = { box = self:_draw(\"Square\", { Filled = false, Thickness = 1 }),\r\
                                            name = self:_draw(\"Text\", { Center = true, Outline = true }),\r\
                                            dist = self:_draw(\"Text\", { Center = true, Outline = true }) }\r\
                                        self._objBundles[inst] = ob\r\
                                    end\r\
                                    local v = cam:WorldToViewportPoint(part.Position)\r\
                                    if v.Z > 0 then\r\
                                        local col = src.color or GV.Color.fade(self.Flags, \"ESP_ObjectColor\", t)\r\
                                        local ts = self:_flag(\"TextSize\", 13)\r\
                                        ob.box.Visible = true; ob.box.Color = col; ob.box.Size = Vector2.new(14, 14); ob.box.Position = Vector2.new(v.X - 7, v.Y - 7)\r\
                                        ob.name.Visible = true; ob.name.Text = src.name; ob.name.Color = col; ob.name.Size = ts; ob.name.Position = Vector2.new(v.X, v.Y - 18)\r\
                                        ob.dist.Visible = true; ob.dist.Text = math.floor(dist) .. \"m\"; ob.dist.Color = col; ob.dist.Size = ts; ob.dist.Position = Vector2.new(v.X, v.Y + 10)\r\
                                    else\r\
                                        for _, o in pairs(ob) do o.Visible = false end\r\
                                    end\r\
                                end\r\
                            end\r\
                        end\r\
                    end\r\
                end\r\
            end\r\
        end\r\
        for inst, ob in pairs(self._objBundles) do\r\
            if not live[inst] then\r\
                for _, o in pairs(ob) do pcall(function() o.Visible = false end) end\r\
                if not (inst and inst.Parent) then self._objBundles[inst] = nil end\r\
            end\r\
        end\r\
    end\r\
\r\
    -- Preview mode: dibuja box+skeleton de UN modelo con una camara de ViewportFrame (para §D)\r\
    function ESP:RenderPreview(cam, model)\r\
        if not (cam and model) then return end\r\
        self._preview = self._preview or { box = self:_draw(\"Square\", { Filled = false, Thickness = 1 }), skel = {} }\r\
        local root = model:FindFirstChild(\"HumanoidRootPart\") or model:FindFirstChildWhichIsA(\"BasePart\")\r\
        local head = model:FindFirstChild(\"Head\") or root\r\
        if not root then return end\r\
        local t = tick()\r\
        local topV = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))\r\
        local botV = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))\r\
        if topV.Z > 0 then\r\
            local h = math.abs(botV.Y - topV.Y); local w = h * 0.62\r\
            self._preview.box.Visible = true\r\
            self._preview.box.Color = GV.Color.fade(self.Flags, \"ESP_BoxColor\", t)\r\
            self._preview.box.Size = Vector2.new(w, h)\r\
            self._preview.box.Position = Vector2.new(topV.X - w / 2, topV.Y)\r\
        else\r\
            self._preview.box.Visible = false\r\
        end\r\
    end\r\
\r\
    function ESP:Init()\r\
        if self.Loaded then return self end\r\
        self.Loaded = true\r\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\r\
            local ok, err = pcall(function() self:_update() end)\r\
            if not ok then warn(\"[ESP] \" .. tostring(err)) end\r\
        end)\r\
        return self\r\
    end\r\
\r\
    function ESP:Unload()\r\
        self.Loaded = false\r\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\r\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\r\
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end\r\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Objects); table.clear(self.Highlights)\r\
    end\r\
\r\
    GV.ESP = ESP\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.esp = GV.Modules.esp or {}\r\
    GV.Modules.esp.new = function(o) return ESP.new(o) end\r\
end\r\
"
local f = loadstring(chunk, '@core/ESP.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local BONES_R15 = {\r\
        { a = \"Head\", b = \"UpperTorso\" }, { a = \"UpperTorso\", b = \"LowerTorso\" },\r\
        { a = \"UpperTorso\", b = \"LeftUpperArm\" }, { a = \"LeftUpperArm\", b = \"LeftLowerArm\" }, { a = \"LeftLowerArm\", b = \"LeftHand\" },\r\
        { a = \"UpperTorso\", b = \"RightUpperArm\" }, { a = \"RightUpperArm\", b = \"RightLowerArm\" }, { a = \"RightLowerArm\", b = \"RightHand\" },\r\
        { a = \"LowerTorso\", b = \"LeftUpperLeg\" }, { a = \"LeftUpperLeg\", b = \"LeftLowerLeg\" }, { a = \"LeftLowerLeg\", b = \"LeftFoot\" },\r\
        { a = \"LowerTorso\", b = \"RightUpperLeg\" }, { a = \"RightUpperLeg\", b = \"RightLowerLeg\" }, { a = \"RightLowerLeg\", b = \"RightFoot\" },\r\
    }\r\
    local BONES_R6 = {\r\
        { a = \"Head\", b = \"Torso\" }, { a = \"Torso\", b = \"Left Arm\" }, { a = \"Torso\", b = \"Right Arm\" },\r\
        { a = \"Torso\", b = \"Left Leg\" }, { a = \"Torso\", b = \"Right Leg\" },\r\
    }\r\
    local function bonesFor(model)\r\
        return model:FindFirstChild(\"UpperTorso\") and BONES_R15 or BONES_R6\r\
    end\r\
    GV.DefaultProvider = {\r\
        getTargets = function(esp)\r\
            local svc = esp.Services\r\
            local out = {}\r\
            local lp = svc.Players.LocalPlayer\r\
            local localChar = lp and lp.Character\r\
            local localTeam = lp and lp.Team\r\
            local teamCheck = esp:_flag(\"TeamCheck\", false)\r\
            for _, p in ipairs(svc.Players:GetPlayers()) do\r\
                local char = p.Character\r\
                if char and char ~= localChar then\r\
                    local hum = char:FindFirstChildOfClass(\"Humanoid\")\r\
                    local root = char:FindFirstChild(\"HumanoidRootPart\")\r\
                    local head = char:FindFirstChild(\"Head\")\r\
                    if hum and root and head and hum.Health > 0 then\r\
                        table.insert(out, {\r\
                            model = char, health = hum.Health,\r\
                            maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),\r\
                            root = root, head = head, bones = bonesFor(char), name = p.Name, team = p.Team,\r\
                            weapon = nil, level = nil,\r\
                            isEnemy = (not teamCheck) or (p.Team ~= localTeam),\r\
                        })\r\
                    end\r\
                end\r\
            end\r\
            return out\r\
        end,\r\
    }\r\
end\r\
"
local f = loadstring(chunk, '@core/esp_default.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local SelfFX = {}\r\
    SelfFX.__index = SelfFX\r\
\r\
    function SelfFX.new(opts)\r\
        opts = opts or {}\r\
        local svc = opts.services or {\r\
            Players = game:GetService(\"Players\"),\r\
            RunService = game:GetService(\"RunService\"),\r\
            UserInputService = game:GetService(\"UserInputService\"),\r\
            Workspace = workspace,\r\
            Stats = game:FindService(\"Stats\"),\r\
        }\r\
        return setmetatable({\r\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\r\
            Conns = {}, Drawings = {}, _orig = {}, _made = {}, Highlights = {}, Loaded = false,\r\
        }, SelfFX)\r\
    end\r\
\r\
    function SelfFX:Set(k, v) self.Flags[k] = v end\r\
    function SelfFX:Get(k) return self.Flags[k] end\r\
    function SelfFX:_flag(k, d)\r\
        local v = self.Flags[\"Local_\" .. k]; if v ~= nil then return v end; return d\r\
    end\r\
    function SelfFX:UseProfile(p) if p then self._provider = p end end\r\
\r\
    function SelfFX:_draw(class, props)\r\
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end\r\
        local o = Drawing.new(class); o.Visible = false\r\
        if props then for k, v in pairs(props) do o[k] = v end end\r\
        table.insert(self.Drawings, o); return o\r\
    end\r\
\r\
    -- escritura con memoria (restaura en Unload/off)\r\
    function SelfFX:_set(obj, prop, val)\r\
        if not obj then return end\r\
        local ok, cur = pcall(function() return obj[prop] end)\r\
        if not ok then return end\r\
        local mem = self._orig[obj]; if not mem then mem = {}; self._orig[obj] = mem end\r\
        if mem[prop] == nil then mem[prop] = cur end\r\
        if cur ~= val then pcall(function() obj[prop] = val end) end\r\
    end\r\
    function SelfFX:_restoreAll()\r\
        for obj, props in pairs(self._orig) do\r\
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end\r\
        end\r\
        table.clear(self._orig)\r\
    end\r\
\r\
    -- Camara: FOV changer + 3ra persona + Custom Aspect Ratio.\r\
    -- NOTA aspect: en Potassium ViewportSize es read-only duro (setscriptable/sethiddenproperty\r\
    -- no lo escriben) -> stretch pixel-real NO reproducible sin render-hooks. Mecanismo entregable:\r\
    -- FieldOfViewMode (Vertical/Diagonal/MaxAxis) + MaxAxisFieldOfView, que altera el mapeo FOV<->aspecto.\r\
    -- restaura una prop guardada (revierte por-feature al apagar el toggle, sin esperar al master)\r\
    function SelfFX:_restoreOne(obj, prop)\r\
        local m = self._orig[obj]\r\
        if m and m[prop] ~= nil then pcall(function() obj[prop] = m[prop] end); m[prop] = nil end\r\
    end\r\
\r\
    function SelfFX:_applyCamera()\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        if not cam then return end\r\
        -- FOV changer (cleanup al apagar)\r\
        if self:_flag(\"FOV\", false) then\r\
            local fov = self:_flag(\"FOVValue\", 70)\r\
            if self._provider and self._provider.setFOV then self._provider.setFOV(fov - 70)\r\
            else self:_set(cam, \"FieldOfView\", fov) end\r\
        else\r\
            if self._provider and self._provider.setFOV then self._provider.setFOV(0)\r\
            else self:_restoreOne(cam, \"FieldOfView\") end\r\
        end\r\
        -- 3ra persona (cleanup al apagar)\r\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\r\
        if self:_flag(\"ThirdPerson\", false) then\r\
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(true)\r\
            else self:_thirdPersonGeneric() end\r\
        else\r\
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(false)\r\
            elseif plr then self:_restoreOne(plr, \"CameraMode\"); self:_restoreOne(plr, \"CameraMaxZoomDistance\") end\r\
        end\r\
    end\r\
\r\
    -- Custom Aspect Ratio: stretch por matriz CFrame no-ortonormal (escala Right/Up de la camara).\r\
    -- Funciona en CUALQUIER executor (no depende de ViewportSize). Se aplica DESPUES de la camara\r\
    -- (BindToRenderStep Camera+1); reconstruye desde los vectores actuales cada frame -> NO compone.\r\
    function SelfFX:_applyAspect()\r\
        if not (self:_flag(\"Enabled\", false) and self:_flag(\"Aspect\", false)) then return end\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        if not cam then return end\r\
        local sx, sy = self:_flag(\"AspectH\", 1), self:_flag(\"AspectV\", 1)\r\
        if sx == 1 and sy == 1 then return end\r\
        -- post-multiplicar por una matriz de escala en espacio LOCAL de la camara (escala Right/Up).\r\
        -- Corre en Camera+1 (cf ya ortonormal este frame) -> NO compone y es estable en cualquier pitch.\r\
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, sx, 0, 0, 0, sy, 0, 0, 0, 1)\r\
    end\r\
\r\
    -- 3ra persona genérica (best-effort): habilita zoom-out (restaurado en unload).\r\
    function SelfFX:_thirdPersonGeneric()\r\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\r\
        if not plr then return end\r\
        pcall(function() self:_set(plr, \"CameraMode\", Enum.CameraMode.Classic) end)\r\
        self:_set(plr, \"CameraMaxZoomDistance\", self:_flag(\"ThirdPersonDistance\", 12))\r\
    end\r\
\r\
    -- fallback genérico (game-agnostic): CC/Blur en Lighting con nombre flash/blind\r\
    function SelfFX:_genericFlashEffects()\r\
        local out = {}\r\
        local L = self.Services.Workspace and game:GetService(\"Lighting\")\r\
        if not L then return out end\r\
        for _, e in ipairs(L:GetChildren()) do\r\
            if (e:IsA(\"ColorCorrectionEffect\") or e:IsA(\"BlurEffect\")) then\r\
                local n = string.lower(e.Name)\r\
                if n:find(\"flash\") or n:find(\"blind\") then table.insert(out, e) end\r\
            end\r\
        end\r\
        return out\r\
    end\r\
\r\
    -- Anti-flash / anti-smoke. Usa hooks del perfil si existen; si no, fallback genérico.\r\
    function SelfFX:_applyAntiFlash()\r\
        if self:_flag(\"AntiFlash\", false) then\r\
            local list\r\
            if self._provider and self._provider.flashEffects then\r\
                local ok, r = pcall(self._provider.flashEffects); list = ok and r or nil\r\
            else\r\
                list = self:_genericFlashEffects()\r\
            end\r\
            if list then for _, e in ipairs(list) do self:_set(e, \"Enabled\", false) end end\r\
        end\r\
        if self:_flag(\"AntiSmoke\", false) and self._provider and self._provider.smokeEffects then\r\
            local ok, list = pcall(self._provider.smokeEffects)\r\
            if ok and list then for _, e in ipairs(list) do self:_set(e, \"Enabled\", false) end end\r\
        end\r\
    end\r\
\r\
    -- Self-chams (Highlight sobre el char propio, detectable)\r\
    function SelfFX:_applySelfChams(t)\r\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\r\
        local char = plr and plr.Character\r\
        if not self:_flag(\"SelfChams\", false) or not char then\r\
            local h = self.Highlights[\"self\"]; if h then h.Enabled = false end\r\
            return\r\
        end\r\
        local h = self.Highlights[\"self\"]\r\
        if not h or not h.Parent then\r\
            h = Instance.new(\"Highlight\"); h.Name = \"LC\"; h.Parent = self.Services.Workspace.CurrentCamera\r\
            self.Highlights[\"self\"] = h\r\
        end\r\
        h.Adornee = char; h.Enabled = true\r\
        h.FillColor = GV.Color.fade(self.Flags, \"Local_SelfChamsFill\", t)\r\
        h.OutlineColor = GV.Color.fade(self.Flags, \"Local_SelfChamsOutline\", t)\r\
        h.FillTransparency = self:_flag(\"SelfChamsFillTransparency\", 0.5)\r\
    end\r\
\r\
    -- Crosshair (Drawing centrado en pantalla)\r\
    function SelfFX:_makeCrosshair()\r\
        if self._cross then return self._cross end\r\
        self._cross = {\r\
            top = self:_draw(\"Line\", { Thickness = 1 }),\r\
            bottom = self:_draw(\"Line\", { Thickness = 1 }),\r\
            left = self:_draw(\"Line\", { Thickness = 1 }),\r\
            right = self:_draw(\"Line\", { Thickness = 1 }),\r\
            dot = self:_draw(\"Square\", { Filled = true }),\r\
            circle = self:_draw(\"Circle\", { Filled = false, NumSides = 32 }),\r\
        }\r\
        return self._cross\r\
    end\r\
\r\
    function SelfFX:_applyCrosshair(t)\r\
        local c = self:_makeCrosshair()\r\
        for _, o in pairs(c) do o.Visible = false end\r\
        if not self:_flag(\"Crosshair\", false) then return end\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        if not cam then return end\r\
        local vp = cam.ViewportSize\r\
        local cx, cy = vp.X / 2, vp.Y / 2\r\
        local col = GV.Color.fade(self.Flags, \"Local_CrosshairColor\", t)\r\
        local style = self:_flag(\"CrosshairStyle\", \"Cross\")\r\
        local gap = self:_flag(\"CrosshairGap\", 4)\r\
        local size = self:_flag(\"CrosshairSize\", 10)\r\
        local th = self:_flag(\"CrosshairThickness\", 1)\r\
        local function line(o, fx, fy, tx, ty)\r\
            o.Visible = true; o.From = Vector2.new(fx, fy); o.To = Vector2.new(tx, ty); o.Color = col; o.Thickness = th; o.ZIndex = 10\r\
        end\r\
        if style == \"Cross\" or style == \"T\" then\r\
            line(c.left, cx - gap - size, cy, cx - gap, cy)\r\
            line(c.right, cx + gap, cy, cx + gap + size, cy)\r\
            line(c.bottom, cx, cy + gap, cx, cy + gap + size)\r\
            if style == \"Cross\" then line(c.top, cx, cy - gap - size, cx, cy - gap) end\r\
        elseif style == \"Dot\" then\r\
            local d = math.max(2, size / 3)\r\
            c.dot.Visible = true; c.dot.Size = Vector2.new(d, d); c.dot.Position = Vector2.new(cx - d / 2, cy - d / 2); c.dot.Color = col; c.dot.ZIndex = 10\r\
        elseif style == \"Circle\" then\r\
            c.circle.Visible = true; c.circle.Position = Vector2.new(cx, cy); c.circle.Radius = size; c.circle.Color = col; c.circle.Thickness = th; c.circle.ZIndex = 10\r\
        end\r\
    end\r\
\r\
    -- HUD: watermark + hitmarker + keybind-list\r\
    function SelfFX:_makeHUD()\r\
        if self._hud then return self._hud end\r\
        self._hud = {\r\
            wm = self:_draw(\"Text\", { Outline = true, Size = 14, Font = 2 }),\r\
            kb = {},\r\
            hit = { self:_draw(\"Line\", { Thickness = 2 }), self:_draw(\"Line\", { Thickness = 2 }),\r\
                self:_draw(\"Line\", { Thickness = 2 }), self:_draw(\"Line\", { Thickness = 2 }) },\r\
        }\r\
        return self._hud\r\
    end\r\
\r\
    function SelfFX:_applyWatermark(t)\r\
        local hud = self:_makeHUD()\r\
        hud.wm.Visible = self:_flag(\"Watermark\", false)\r\
        if not hud.wm.Visible then return end\r\
        local parts = {}\r\
        if self:_flag(\"WM_Title\", true) then table.insert(parts, \"Visuals\") end\r\
        if self:_flag(\"WM_FPS\", true) then table.insert(parts, (self._fps or 0) .. \" fps\") end\r\
        if self:_flag(\"WM_Ping\", true) then\r\
            local ok, p = pcall(function() return math.floor(self.Services.Stats.Network.ServerStatsItem[\"Data Ping\"]:GetValue()) end)\r\
            if ok then table.insert(parts, p .. \" ms\") end\r\
        end\r\
        if self:_flag(\"WM_Name\", true) then\r\
            local ok, n = pcall(function() return self.Services.Players.LocalPlayer.Name end)\r\
            if ok and n then table.insert(parts, n) end\r\
        end\r\
        if self:_flag(\"WM_Time\", false) then\r\
            local ok, ts = pcall(function() return os.date(\"%H:%M:%S\") end); if ok then table.insert(parts, ts) end\r\
        end\r\
        if #parts == 0 then parts[1] = \"Visuals\" end\r\
        hud.wm.Text = table.concat(parts, \" | \")\r\
        hud.wm.Color = GV.Color.fade(self.Flags, \"Local_WatermarkColor\", t)\r\
        hud.wm.Position = Vector2.new(self:_flag(\"WatermarkX\", 10), self:_flag(\"WatermarkY\", 8))\r\
        hud.wm.ZIndex = 10\r\
    end\r\
\r\
    function SelfFX:_applyHitmarker(t)\r\
        local hud = self:_makeHUD()\r\
        local active = self:_flag(\"Hitmarker\", false) and self._hitUntil and tick() < self._hitUntil\r\
        for _, l in ipairs(hud.hit) do l.Visible = active end\r\
        if not active then return end\r\
        local cam = self.Services.Workspace.CurrentCamera; if not cam then return end\r\
        local vp = cam.ViewportSize; local cx, cy = vp.X / 2, vp.Y / 2\r\
        local gap = self:_flag(\"HitmarkerGap\", 4); local size = self:_flag(\"HitmarkerSize\", 8)\r\
        local col = GV.Color.fade(self.Flags, \"Local_HitmarkerColor\", t)\r\
        local segs = {\r\
            { cx - gap - size, cy - gap - size, cx - gap, cy - gap },\r\
            { cx + gap, cy - gap, cx + gap + size, cy - gap - size },\r\
            { cx - gap - size, cy + gap + size, cx - gap, cy + gap },\r\
            { cx + gap, cy + gap, cx + gap + size, cy + gap + size },\r\
        }\r\
        for i, l in ipairs(hud.hit) do\r\
            local s = segs[i]; l.From = Vector2.new(s[1], s[2]); l.To = Vector2.new(s[3], s[4]); l.Color = col; l.ZIndex = 11\r\
        end\r\
    end\r\
\r\
    function SelfFX:_applyKeybindList(t)\r\
        local hud = self:_makeHUD()\r\
        for _, l in ipairs(hud.kb) do l.Visible = false end\r\
        if hud.kb[0] then hud.kb[0].Visible = false end\r\
        if not self:_flag(\"KeybindList\", false) then return end\r\
        -- fuente: provider.keybinds() > self._keybindList (features con keybind del schema)\r\
        local list\r\
        if self._provider and self._provider.keybinds then local ok, r = pcall(self._provider.keybinds); list = ok and r or nil end\r\
        list = list or self._keybindList or {}\r\
        local col = GV.Color.fade(self.Flags, \"Local_KeybindColor\", t)\r\
        local x, y = self:_flag(\"KeybindX\", 10), self:_flag(\"KeybindY\", 120)\r\
        local header = hud.kb[0]\r\
        if not header then header = self:_draw(\"Text\", { Outline = true, Size = 13, Font = 3 }); hud.kb[0] = header end\r\
        header.Visible = true; header.Text = \"[ keybinds ]\"; header.Color = col; header.Position = Vector2.new(x, y); header.ZIndex = 10\r\
        for i, kb in ipairs(list) do\r\
            local o = hud.kb[i]\r\
            if not o then o = self:_draw(\"Text\", { Outline = true, Size = 13, Font = 2 }); hud.kb[i] = o end\r\
            o.Visible = true\r\
            o.Text = tostring(kb.name or \"?\") .. (kb.key and (\" [\" .. tostring(kb.key) .. \"]\") or \"\")\r\
            o.Color = col; o.Position = Vector2.new(x, y + i * 15); o.ZIndex = 10\r\
        end\r\
    end\r\
\r\
    function SelfFX:_off()\r\
        self._wasOn = false\r\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false end) end\r\
        for _, h in pairs(self.Highlights) do pcall(function() h.Enabled = false end) end\r\
        self:_restoreAll()\r\
    end\r\
\r\
    function SelfFX:_update()\r\
        if not self:_flag(\"Enabled\", false) then\r\
            if self._wasOn then self:_off() end\r\
            return\r\
        end\r\
        self._wasOn = true\r\
        local now = tick()\r\
        if self._lastT then self._fps = math.floor(1 / math.max(1e-3, now - self._lastT) + 0.5) end\r\
        self._lastT = now\r\
        self:_applyCamera()\r\
        self:_applyCrosshair(now)\r\
        self:_applyWatermark(now)\r\
        self:_applyHitmarker(now)\r\
        self:_applyKeybindList(now)\r\
        self:_applyAntiFlash()\r\
        self:_applySelfChams(now)\r\
    end\r\
\r\
    function SelfFX:Init()\r\
        if self.Loaded then return self end\r\
        self.Loaded = true\r\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\r\
            local ok, err = pcall(function() self:_update() end)\r\
            if not ok then warn(\"[SelfFX] \" .. tostring(err)) end\r\
        end)\r\
        if self._provider and self._provider.hitSignal then\r\
            local ok, conn = pcall(function()\r\
                return self._provider.hitSignal:Connect(function()\r\
                    self._hitUntil = tick() + self:_flag(\"HitmarkerDuration\", 0.3)\r\
                end)\r\
            end)\r\
            if ok and conn then self.Conns[#self.Conns + 1] = conn end\r\
        end\r\
        -- aspect ratio: correr DESPUES de la camara (Camera+1) para que el stretch pegue\r\
        local RS = self.Services.RunService\r\
        if RS.BindToRenderStep then\r\
            local ok = pcall(function()\r\
                RS:BindToRenderStep(\"VisualsAspect\", Enum.RenderPriority.Camera.Value + 1, function()\r\
                    if self.Loaded then local o, e = pcall(function() self:_applyAspect() end); if not o then warn(\"[SelfFX aspect] \" .. tostring(e)) end end\r\
                end)\r\
            end)\r\
            self._aspectBound = ok\r\
        end\r\
        return self\r\
    end\r\
\r\
    function SelfFX:Unload()\r\
        self.Loaded = false\r\
        if self._aspectBound then pcall(function() self.Services.RunService:UnbindFromRenderStep(\"VisualsAspect\") end); self._aspectBound = false end\r\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\r\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\r\
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end\r\
        self:_restoreAll()\r\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Highlights); table.clear(self._made)\r\
    end\r\
\r\
    GV.SelfFX = SelfFX\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.selffx = GV.Modules.selffx or {}\r\
    GV.Modules.selffx.new = function(o) return SelfFX.new(o) end\r\
end\r\
"
local f = loadstring(chunk, '@core/selffx.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local F = {}\r\
    F.KINDS = { \"toggle\", \"slider\", \"dropdown\", \"colorpicker\", \"label\", \"textbox\", \"button\" }\r\
    F.METHODS = { \"Tab\", \"Group\", \"Widget\", \"Depend\" }\r\
    function F.validate(adapter)\r\
        local missing = {}\r\
        for _, m in ipairs(F.METHODS) do\r\
            if type(adapter[m]) ~= \"function\" then table.insert(missing, m) end\r\
        end\r\
        return #missing == 0, missing\r\
    end\r\
    GV.Facade = F\r\
end\r\
"
local f = loadstring(chunk, '@ui/facade.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local R = {}\r\
    local KIND_KEYS = { \"Text\", \"Default\", \"Min\", \"Max\", \"Decimals\", \"Suffix\", \"Values\", \"Multi\",\r\
        \"Searchable\", \"Tooltip\", \"Header\", \"Placeholder\", \"Numeric\", \"Keybind\", \"OffAtMin\" }\r\
\r\
    function R.build(adapter, window, schema, world)\r\
        assert(GV.Facade.validate(adapter))\r\
        local handles, byFlag = {}, {}\r\
        local curTabName, curTab, curKey, curGroup\r\
        for _, row in ipairs(schema) do\r\
            if row.tab ~= curTabName then\r\
                curTab = adapter.Tab(window, row.tab, row.icon); curTabName = row.tab; curKey = nil\r\
            end\r\
            local gk = row.tab .. \"|\" .. row.group .. \"|\" .. (row.side or \"Left\")\r\
            if gk ~= curKey then\r\
                curGroup = adapter.Group(curTab, row.group, row.side or \"Left\"); curKey = gk\r\
            end\r\
            -- opts desde la fila\r\
            local opts = {}\r\
            for _, k in ipairs(KIND_KEYS) do\r\
                local sk = k:lower()\r\
                if row[sk] ~= nil then opts[k] = row[sk] end\r\
            end\r\
            if row.text then opts.Text = row.text end\r\
            -- seed del flag + default\r\
            if row.flag and world.Flags[row.flag] == nil and row.default ~= nil then\r\
                world.Flags[row.flag] = row.default\r\
            end\r\
            if row.flag then opts.Default = world.Flags[row.flag] end\r\
            if row.type ~= \"label\" and row.type ~= \"button\" and row.flag then\r\
                opts.Callback = function(v) world:Set(row.flag, v) end\r\
            elseif row.type == \"button\" then\r\
                if row.presetAction then\r\
                    opts.Callback = function()\r\
                        local suite = world.__suite\r\
                        local w = suite and suite.modules and suite.modules.world\r\
                        if w then w:ApplyPreset(w:Get(\"World_PresetSelect\")) end\r\
                    end\r\
                else\r\
                    opts.Callback = row.action\r\
                end\r\
            end\r\
            -- crear widget\r\
            local h\r\
            if row.attach then\r\
                -- colorpicker pegado a un toggle ya creado (patron Hitmarker)\r\
                local tgl = byFlag[row.attach]\r\
                h = adapter.AttachColor and adapter.AttachColor(tgl, row.flag, opts) or { flag = row.flag }\r\
            else\r\
                local parent = row.dependsOn and byFlag[row.dependsOn] or nil\r\
                h = adapter.Widget(curGroup, row.type, row.flag, opts, parent)\r\
                if row.dependsOn then\r\
                    adapter.Depend(h, row.dependsOn, row.dependsValue == nil and true or row.dependsValue)\r\
                end\r\
            end\r\
            if row.flag then byFlag[row.flag] = h end\r\
            table.insert(handles, h)\r\
        end\r\
        return handles\r\
    end\r\
    GV.Renderer = R\r\
end\r\
"
local f = loadstring(chunk, '@ui/renderer.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local Preview = {}\r\
    local RunService = game:GetService(\"RunService\")\r\
    local Players = game:GetService(\"Players\")\r\
    local UIS = game:GetService(\"UserInputService\")\r\
\r\
    local function huiParent()\r\
        local ok, g = pcall(function() return gethui and gethui() end)\r\
        if ok and g then return g end\r\
        return game:GetService(\"CoreGui\")\r\
    end\r\
\r\
    function Preview.mount(suite, opts)\r\
        opts = opts or {}\r\
        local flags = suite.flags\r\
        local self = { suite = suite, _made = {}, _conns = {} }\r\
\r\
        -- limpiar previews huérfanos (mounts previos que quedaron sin unload por reconexion)\r\
        pcall(function()\r\
            for _, g in ipairs(huiParent():GetChildren()) do\r\
                if g:IsA(\"ScreenGui\") and g.Name:sub(1, 6) == \"PUIpv_\" then g:Destroy() end\r\
            end\r\
        end)\r\
        local gui = Instance.new(\"ScreenGui\")\r\
        gui.Name = \"PUIpv_\" .. tostring(math.random(1e5, 9e5))\r\
        gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling\r\
        gui.Parent = huiParent(); table.insert(self._made, gui)\r\
\r\
        local root = Instance.new(\"Frame\")\r\
        root.Size = UDim2.fromOffset(260, 320)\r\
        root.AnchorPoint = Vector2.new(1, 0.5)\r\
        root.Position = UDim2.new(1, -12, 0.5, 0)\r\
        root.BackgroundColor3 = Color3.fromRGB(18, 20, 26); root.BorderSizePixel = 0; root.Parent = gui\r\
        Instance.new(\"UICorner\", root).CornerRadius = UDim.new(0, 8)\r\
        local st = Instance.new(\"UIStroke\", root); st.Color = Color3.fromRGB(8, 8, 10); st.Thickness = 1\r\
        self.Root = root\r\
\r\
        local header = Instance.new(\"Frame\"); header.Size = UDim2.new(1, 0, 0, 26)\r\
        header.BackgroundColor3 = Color3.fromRGB(30, 30, 36); header.BorderSizePixel = 0; header.Parent = root\r\
        Instance.new(\"UICorner\", header).CornerRadius = UDim.new(0, 8)\r\
        local title = Instance.new(\"TextLabel\"); title.BackgroundTransparency = 1\r\
        title.Size = UDim2.new(1, -10, 1, 0); title.Position = UDim2.fromOffset(8, 0)\r\
        title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.TextColor3 = Color3.fromRGB(202, 151, 161)\r\
        title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = \"Preview\"; title.Parent = header\r\
\r\
        local dragging, sPos, sMouse\r\
        header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; sPos = root.Position; sMouse = UIS:GetMouseLocation() end end)\r\
        header.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)\r\
        table.insert(self._conns, UIS.InputChanged:Connect(function(i)\r\
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then\r\
                local d = UIS:GetMouseLocation() - sMouse\r\
                root.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)\r\
            end\r\
        end))\r\
\r\
        -- ViewportFrame estilo BLUEPRINT: fondo negro, grid gris 3D detras (en el WorldModel).\r\
        local vf = Instance.new(\"ViewportFrame\")\r\
        vf.Position = UDim2.fromOffset(8, 32); vf.Size = UDim2.new(1, -16, 1, -40)\r\
        vf.BackgroundColor3 = Color3.fromRGB(4, 6, 10); vf.BorderSizePixel = 0\r\
        vf.Ambient = Color3.fromRGB(150, 150, 160); vf.LightColor = Color3.fromRGB(255, 255, 255)\r\
        vf.LightDirection = Vector3.new(-0.4, -1, -0.5); vf.Parent = root\r\
        Instance.new(\"UICorner\", vf).CornerRadius = UDim.new(0, 6)\r\
        local cam = Instance.new(\"Camera\"); cam.Parent = vf; vf.CurrentCamera = cam\r\
        local world = Instance.new(\"WorldModel\"); world.Parent = vf\r\
        self.VF, self.Cam, self.World = vf, cam, world\r\
\r\
        -- overlay ESP: box + nombre + healthbar (sobre el 3D)\r\
        local box = Instance.new(\"Frame\"); box.BackgroundTransparency = 1; box.BorderSizePixel = 0\r\
        box.AnchorPoint = Vector2.new(0.5, 0.5); box.Position = UDim2.new(0.5, 0, 0.5, 6)\r\
        box.Size = UDim2.fromOffset(64, 150); box.ZIndex = 3; box.Parent = vf\r\
        local boxStroke = Instance.new(\"UIStroke\", box); boxStroke.Thickness = 1.5; boxStroke.Color = Color3.fromRGB(0, 255, 120)\r\
        self._box, self._boxStroke = box, boxStroke\r\
        local nameLbl = Instance.new(\"TextLabel\"); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.Gotham\r\
        nameLbl.TextSize = 12; nameLbl.AnchorPoint = Vector2.new(0.5, 1); nameLbl.Position = UDim2.new(0.5, 0, 0, -1)\r\
        nameLbl.Size = UDim2.new(1, 0, 0, 14); nameLbl.ZIndex = 4; nameLbl.Parent = box; nameLbl.Text = \"Preview\"\r\
        self._nameLbl = nameLbl\r\
        local hpBg = Instance.new(\"Frame\"); hpBg.BorderSizePixel = 0; hpBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)\r\
        hpBg.AnchorPoint = Vector2.new(1, 0); hpBg.Position = UDim2.new(0, -3, 0, 0); hpBg.Size = UDim2.new(0, 3, 1, 0); hpBg.ZIndex = 3; hpBg.Parent = box\r\
        local hpBar = Instance.new(\"Frame\"); hpBar.BorderSizePixel = 0; hpBar.BackgroundColor3 = Color3.fromRGB(90, 220, 90)\r\
        hpBar.AnchorPoint = Vector2.new(0, 1); hpBar.Position = UDim2.new(0, 0, 1, 0); hpBar.Size = UDim2.new(1, 0, 0.7, 0); hpBar.ZIndex = 4; hpBar.Parent = hpBg\r\
        self._hpBg, self._hpBar = hpBg, hpBar\r\
\r\
        function self:SetModel(char)\r\
            for _, c in ipairs(self.World:GetChildren()) do if c ~= nil then c:Destroy() end end\r\
            self.Model = nil\r\
            if not char then return end\r\
            local m; local prev = char.Archivable; char.Archivable = true\r\
            pcall(function() m = char:Clone() end); char.Archivable = prev\r\
            if not m then return end\r\
            for _, d in ipairs(m:GetDescendants()) do if d:IsA(\"Script\") or d:IsA(\"LocalScript\") then d:Destroy() end end\r\
            m.Parent = self.World; self.Model = m\r\
            local ok, cf, size = pcall(function() return m:GetBoundingBox() end)\r\
            if ok and cf then\r\
                self._center = cf.Position; self._radius = math.max(size.Magnitude / 2, 1)\r\
                self._dist = self._radius / math.tan(math.rad(30)) + self._radius\r\
            end\r\
            self._angle = 0\r\
        end\r\
\r\
        function self:_apply(a)\r\
            if not self._center then return end\r\
            local pos = self._center + Vector3.new(math.sin(a) * self._dist, self._radius * 0.35, math.cos(a) * self._dist)\r\
            self.Cam.CFrame = CFrame.lookAt(pos, self._center)\r\
        end\r\
\r\
        function self:_step(dt)\r\
            local show = opts.always or (flags.Suite_Preview and true or false)\r\
            self.Root.Visible = show\r\
            if not show or not self.Model then return end\r\
            self._angle = (self._angle or 0) + math.rad(40) * dt\r\
            self:_apply(self._angle)\r\
            local t = tick()\r\
            -- world lighting -> viewport ambient\r\
            self.VF.Ambient = flags.World_Ambient and GV.Color.fade(flags, \"World_AmbientColor\", t) or Color3.fromRGB(150, 150, 160)\r\
            self.VF.LightColor = flags.World_Fullbright and Color3.new(1, 1, 1) or Color3.fromRGB(255, 255, 255)\r\
            -- chams\r\
            local chamsOn = flags.ESP_Chams or flags.Local_SelfChams\r\
            if chamsOn then\r\
                if not self._chams then self._chams = Instance.new(\"Highlight\"); self._chams.Parent = self.VF; table.insert(self._made, self._chams) end\r\
                self._chams.Adornee = self.Model; self._chams.Enabled = true\r\
                local isSelf = flags.Local_SelfChams and true or false\r\
                self._chams.FillColor = GV.Color.fade(flags, isSelf and \"Local_SelfChamsFill\" or \"ESP_ChamsFill\", t)\r\
                self._chams.OutlineColor = GV.Color.fade(flags, isSelf and \"Local_SelfChamsOutline\" or \"ESP_ChamsOutline\", t)\r\
            elseif self._chams then self._chams.Enabled = false end\r\
            -- ESP overlay refleja los flags\r\
            local espOn = flags.ESP_Enabled and true or false\r\
            self._box.Visible = espOn and (flags.ESP_Box ~= false)\r\
            self._boxStroke.Color = GV.Color.fade(flags, \"ESP_BoxColor\", t)\r\
            self._nameLbl.Visible = espOn and (flags.ESP_Name ~= false)\r\
            self._nameLbl.TextColor3 = GV.Color.fade(flags, \"ESP_NameColor\", t)\r\
            self._hpBg.Visible = espOn and (flags.ESP_Health ~= false)\r\
        end\r\
\r\
        table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)\r\
            local ok, err = pcall(function() self:_step(dt) end); if not ok then warn(\"[Preview] \" .. tostring(err)) end\r\
        end))\r\
\r\
        function self:Unload()\r\
            for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end\r\
            for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
            table.clear(self._conns); table.clear(self._made)\r\
        end\r\
\r\
        local lp = Players.LocalPlayer\r\
        if lp and lp.Character then self:SetModel(lp.Character) end\r\
        return self\r\
    end\r\
    GV.Preview = Preview\r\
end\r\
"
local f = loadstring(chunk, '@ui/preview.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    GV.Adapters = GV.Adapters or {}\r\
    local A = {}\r\
    local ADD = { toggle = \"AddToggle\", slider = \"AddSlider\", dropdown = \"AddDropdown\",\r\
        colorpicker = \"AddColorPicker\", label = \"AddLabel\", textbox = \"AddTextBox\", button = \"AddButton\" }\r\
\r\
    -- UN category \"Visuals\" (barra superior) + cada tab del schema = Section (sidebar izquierdo)\r\
    function A.Tab(window, name, icon)\r\
        if not window.__visualsCat then\r\
            window.__visualsCat = window:AddCategory(\"Visuals\", \"eye\")\r\
        end\r\
        local sec = window.__visualsCat:AddSection(name)\r\
        return { cat = window.__visualsCat, sec = sec }\r\
    end\r\
    function A.Group(tab, name, side)\r\
        return tab.sec:AddPanel(name, { Column = side == \"Right\" and 2 or 1 })\r\
    end\r\
    function A.Widget(panel, kind, flag, opts)\r\
        local m = ADD[kind]\r\
        if not m or type(panel[m]) ~= \"function\" then warn(\"[primordial] sin widget \" .. tostring(kind)); return { flag = flag } end\r\
        if kind == \"label\" then return panel:AddLabel(opts.Text or \"\") end\r\
        if kind == \"button\" then return panel:AddButton(opts.Text or \"Button\", opts.Callback or function() end) end\r\
        return panel[m](panel, flag, opts)\r\
    end\r\
    function A.Depend(widget, flag, val)\r\
        if widget and type(widget.DependsOn) == \"function\" then widget:DependsOn(flag, val) end\r\
    end\r\
    -- colorpicker pegado a un toggle (patron Hitmarker)\r\
    function A.AttachColor(toggleHandle, flag, opts)\r\
        if toggleHandle and type(toggleHandle.AddColorPicker) == \"function\" then\r\
            return toggleHandle:AddColorPicker(flag, opts)\r\
        end\r\
        return { flag = flag }\r\
    end\r\
\r\
    A.supportsPreview = true -- Primordial es instance-based -> puede montar el preview viewport\r\
    GV.Adapters.primordial = A\r\
end\r\
"
local f = loadstring(chunk, '@ui/adapter_primordial.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local H = {}\r\
    -- Color con fade PEGADO a un toggle de feature (patron Hitmarker):\r\
    -- 2 colorpickers sobre el toggle `spec.toggle` + un toggle \"fade\" anidado.\r\
    -- `spec.toggle` = el flag del toggle de feature (ej \"ESP_Box\"). `spec.base` = flag del color (ej \"ESP_BoxColor\").\r\
    function H.CF(spec)\r\
        local base, tgl = spec.base, spec.toggle\r\
        local function row(t)\r\
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side\r\
            return t\r\
        end\r\
        return {\r\
            row{ flag = base, type = \"colorpicker\", text = spec.text, default = spec.default, attach = tgl },\r\
            row{ flag = base .. \"_2\", type = \"colorpicker\", text = (spec.text or \"\") .. \" 2\", default = spec.default2 or spec.default, attach = tgl },\r\
            row{ flag = base .. \"_Fade\", type = \"toggle\", text = (spec.text or \"\") .. \" fade\", default = false, dependsOn = tgl },\r\
        }\r\
    end\r\
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end\r\
    function H.suiteRows()\r\
        return {\r\
            { tab = \"Mundo\", group = \"Suite\", side = \"Left\", flag = \"Suite_FadeSpeed\", type = \"slider\",\r\
                text = \"Velocidad fade\", min = 0.1, max = 5, default = 1, decimals = 2 },\r\
            { tab = \"Mundo\", group = \"Suite\", side = \"Left\", flag = \"Suite_FadeMode\", type = \"dropdown\",\r\
                text = \"Efecto fade\", values = { \"Onda\", \"Rainbow\", \"Pulso\" }, default = \"Onda\" },\r\
            { tab = \"Mundo\", group = \"Suite\", side = \"Left\", flag = \"Suite_Preview\", type = \"toggle\",\r\
                text = \"Preview (solo Primordial)\", default = false },\r\
        }\r\
    end\r\
    GV.SchemaHelpers = H\r\
    GV.CF = H.CF\r\
    GV.pushCF = H.pushCF\r\
end\r\
"
local f = loadstring(chunk, '@schema/_helpers.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local C = Color3.fromRGB\r\
    local ACC = C(96, 130, 255)\r\
    local S = {}\r\
    local function add(r) table.insert(S, r) end\r\
    local function color(toggle, base, text, tab, group, side, default, default2)\r\
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = tab, group = group, side = side,\r\
            default = default, default2 = default2 or ACC })\r\
    end\r\
\r\
    -- ================= Tab \"Mundo\" =================\r\
    -- A. Lighting\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Enabled\", type = \"toggle\", text = \"Enable visuales\", default = false, keybind = true, master = true }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Fullbright\", type = \"toggle\", text = \"Fullbright\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_NoShadows\", type = \"toggle\", text = \"Sin sombras\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Ambient\", type = \"toggle\", text = \"Ambient\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_Ambient\", \"World_AmbientColor\", \"Ambient color\", \"Mundo\", \"Lighting\", \"Left\", C(120, 120, 125))\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Brightness\", type = \"slider\", text = \"Brillo\", min = 0, max = 10, default = 3, decimals = 1, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Exposure\", type = \"slider\", text = \"Exposicion\", min = -3, max = 3, default = 0, decimals = 2, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_ColorShift\", type = \"toggle\", text = \"ColorShift\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_ColorShift\", \"World_ColorShiftTopColor\", \"ColorShift Top\", \"Mundo\", \"Lighting\", \"Left\", C(0, 0, 0))\r\
    color(\"World_ColorShift\", \"World_ColorShiftBottomColor\", \"ColorShift Bottom\", \"Mundo\", \"Lighting\", \"Left\", C(0, 0, 0))\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvDiffuse\", type = \"slider\", text = \"Env diffuse\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvSpecular\", type = \"slider\", text = \"Env specular\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Technology\", type = \"dropdown\", text = \"Technology\", values = { \"\", \"Voxel\", \"ShadowMap\", \"Future\", \"Legacy\" }, default = \"\", dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_GeoLatitude\", type = \"slider\", text = \"Latitud geo\", min = -90, max = 90, default = 41.7, decimals = 1, dependsOn = \"World_Enabled\" }\r\
    -- B. Tiempo / Sol\r\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_ClockTime\", type = \"slider\", text = \"Hora del dia\", min = 0, max = 24, default = 12, decimals = 1, suffix = \"h\", dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_UseTimeOfDay\", type = \"toggle\", text = \"Usar TimeOfDay\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_FreezeTime\", type = \"toggle\", text = \"Congelar tiempo\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_DayNightCycle\", type = \"toggle\", text = \"Ciclo dia/noche\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_CycleSpeed\", type = \"slider\", text = \"Velocidad ciclo\", min = 0.1, max = 10, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_DayNightCycle\" }\r\
    -- J. Visibilidad\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_Advanced\", type = \"toggle\", text = \"Avanzado (agresivo)\", default = false, dependsOn = \"World_Enabled\", tooltip = \"Toca el mapa; revierte al apagar\" }\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_KillParticles\", type = \"toggle\", text = \"Matar particulas del mapa\", default = false, dependsOn = \"World_Advanced\" }\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_ForceSmoothPlastic\", type = \"toggle\", text = \"Forzar SmoothPlastic\", default = false, dependsOn = \"World_Advanced\" }\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparent\", type = \"toggle\", text = \"Mapa transparente\", default = false, dependsOn = \"World_Advanced\" }\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparentAmount\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.6, decimals = 2, dependsOn = \"World_MapTransparent\" }\r\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_NoTextures\", type = \"toggle\", text = \"Sin texturas/decals\", default = false, dependsOn = \"World_Advanced\" }\r\
    -- C. Fog\r\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_NoFog\", type = \"toggle\", text = \"Sin fog\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogStart\", type = \"slider\", text = \"Fog inicio\", min = 0, max = 2000, default = 0, suffix = \"st\", dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogEnd\", type = \"slider\", text = \"Fog fin\", min = 100, max = 10000, default = 2500, suffix = \"st\", dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogTint\", type = \"toggle\", text = \"Fog color\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_FogTint\", \"World_FogColor\", \"Fog color\", \"Mundo\", \"Fog\", \"Right\", C(190, 195, 210))\r\
    -- D. Atmosphere\r\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_Atmosphere\", type = \"toggle\", text = \"Atmosfera (reemplaza fog)\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_Atmosphere\", \"World_AtmColor\", \"Atm color\", \"Mundo\", \"Atmosphere\", \"Right\", C(199, 199, 199))\r\
    color(\"World_Atmosphere\", \"World_AtmDecay\", \"Atm decay\", \"Mundo\", \"Atmosphere\", \"Right\", C(106, 112, 125))\r\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.3, decimals = 3, dependsOn = \"World_Atmosphere\" }\r\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmOffset\", type = \"slider\", text = \"Offset\", min = 0, max = 1, default = 0.25, decimals = 2, dependsOn = \"World_Atmosphere\" }\r\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmGlare\", type = \"slider\", text = \"Glare\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" }\r\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmHaze\", type = \"slider\", text = \"Haze\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" }\r\
    -- E. Post-FX\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Tint\", type = \"toggle\", text = \"Tinte (ColorCorrection)\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_Tint\", \"World_TintColor\", \"Tinte color\", \"Mundo\", \"Post-FX\", \"Right\", C(255, 255, 255))\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintBrightness\", type = \"slider\", text = \"Brillo\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintContrast\", type = \"slider\", text = \"Contraste\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintSaturation\", type = \"slider\", text = \"Saturacion\", min = -1, max = 3, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowHue\", type = \"toggle\", text = \"Rainbow hue\", default = false, dependsOn = \"World_Tint\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowSpeed\", type = \"slider\", text = \"Rainbow vel\", min = 0.05, max = 5, default = 1, decimals = 2, dependsOn = \"World_RainbowHue\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Bloom\", type = \"toggle\", text = \"Bloom\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 5, default = 0.4, decimals = 2, dependsOn = \"World_Bloom\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomSize\", type = \"slider\", text = \"Tamano\", min = 0, max = 56, default = 24, dependsOn = \"World_Bloom\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomThreshold\", type = \"slider\", text = \"Umbral\", min = 0, max = 3, default = 0.95, decimals = 2, dependsOn = \"World_Bloom\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRays\", type = \"toggle\", text = \"Rayos de sol\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 1, default = 0.05, decimals = 3, dependsOn = \"World_SunRays\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysSpread\", type = \"slider\", text = \"Dispersion\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_SunRays\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoF\", type = \"toggle\", text = \"Depth of Field\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFocus\", type = \"slider\", text = \"Foco\", min = 0, max = 500, default = 25, dependsOn = \"World_DoF\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFRadius\", type = \"slider\", text = \"Radio foco\", min = 0, max = 100, default = 10, dependsOn = \"World_DoF\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFNear\", type = \"slider\", text = \"Near\", min = 0, max = 1, default = 0, decimals = 2, dependsOn = \"World_DoF\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFar\", type = \"slider\", text = \"Far\", min = 0, max = 1, default = 0.75, decimals = 2, dependsOn = \"World_DoF\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlur\", type = \"toggle\", text = \"Blur mundo\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlurSize\", type = \"slider\", text = \"Fuerza\", min = 0, max = 40, default = 12, dependsOn = \"World_WorldBlur\" }\r\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_KillGamePostFX\", type = \"toggle\", text = \"Matar post-FX del juego\", default = false, dependsOn = \"World_Enabled\" }\r\
\r\
    -- ================= Tab \"Cielo & Clima\" =================\r\
    -- F. Cielo\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_NoSky\", type = \"toggle\", text = \"Sin cuerpos celestes\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_StarCount\", type = \"slider\", text = \"Estrellas\", min = 0, max = 5000, default = 3000, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_CustomSkybox\", type = \"toggle\", text = \"Skybox custom\", default = false, dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Up\", type = \"textbox\", text = \"Up\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Dn\", type = \"textbox\", text = \"Down\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Lf\", type = \"textbox\", text = \"Left\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Rt\", type = \"textbox\", text = \"Right\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Bk\", type = \"textbox\", text = \"Back\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Ft\", type = \"textbox\", text = \"Front\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunTextureId\", type = \"textbox\", text = \"Sol textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonTextureId\", type = \"textbox\", text = \"Luna textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunAngularSize\", type = \"slider\", text = \"Sol tamano\", min = 0, max = 90, default = 21, dependsOn = \"World_CustomSkybox\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonAngularSize\", type = \"slider\", text = \"Luna tamano\", min = 0, max = 90, default = 11, dependsOn = \"World_CustomSkybox\" }\r\
    -- G. Nubes\r\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_Clouds\", type = \"toggle\", text = \"Nubes custom\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_Clouds\", \"World_CloudColor\", \"Nubes color\", \"Cielo & Clima\", \"Nubes\", \"Left\", C(255, 255, 255))\r\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_NoClouds\", type = \"toggle\", text = \"Sin nubes\", default = false, dependsOn = \"World_Clouds\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudCover\", type = \"slider\", text = \"Cobertura\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_Clouds\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.7, decimals = 2, dependsOn = \"World_Clouds\" }\r\
    -- H. Terrain / Agua\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterEnable\", type = \"toggle\", text = \"Editar agua\", default = false, dependsOn = \"World_Enabled\" }\r\
    color(\"World_WaterEnable\", \"World_WaterColor\", \"Agua color\", \"Cielo & Clima\", \"Terrain / Agua\", \"Right\", C(12, 84, 92))\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.3, decimals = 2, dependsOn = \"World_WaterEnable\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterReflectance\", type = \"slider\", text = \"Reflectancia\", min = 0, max = 1, default = 1, decimals = 2, dependsOn = \"World_WaterEnable\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSize\", type = \"slider\", text = \"Olas tamano\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_WaterEnable\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSpeed\", type = \"slider\", text = \"Olas velocidad\", min = 0, max = 20, default = 10, decimals = 1, dependsOn = \"World_WaterEnable\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_TerrainDecoration\", type = \"toggle\", text = \"Decoracion terrain\", default = true, dependsOn = \"World_WaterEnable\" }\r\
    -- I. Clima\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Weather\", type = \"toggle\", text = \"Clima\", default = false, keybind = true, dependsOn = \"World_Enabled\" }\r\
    color(\"World_Weather\", \"World_WeatherColor\", \"Clima color\", \"Cielo & Clima\", \"Clima\", \"Right\", C(220, 230, 255))\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherMode\", type = \"dropdown\", text = \"Tipo\", values = { \"Lluvia\", \"Lluvia fuerte\", \"Nieve\", \"Niebla\", \"Ceniza\", \"Luciérnagas\", \"Custom\" }, default = \"Lluvia\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherCustomTex\", type = \"textbox\", text = \"Textura custom\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherGlow\", type = \"slider\", text = \"Brillo propio\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherDensity\", type = \"slider\", text = \"Densidad\", min = 0.1, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSpeed\", type = \"slider\", text = \"Velocidad\", min = 0.1, max = 3, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSize\", type = \"slider\", text = \"Tamano\", min = 0.2, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherArea\", type = \"slider\", text = \"Area\", min = 30, max = 200, default = 90, suffix = \"st\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherWindDir\", type = \"slider\", text = \"Viento (dir)\", min = 0, max = 360, default = 0, suffix = \"deg\", dependsOn = \"World_Weather\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Lightning\", type = \"toggle\", text = \"Relampagos\", default = false, dependsOn = \"World_Weather\" }\r\
    -- K. Presets (dropdown + boton \"Aplicar\" en el MISMO grupo, misma seccion)\r\
    add{ tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", flag = \"World_PresetSelect\", type = \"dropdown\", text = \"Preset\", values = { \"Competitivo\", \"Cinematográfico\", \"Día\", \"Noche\", \"Atardecer\", \"Niebla\" }, default = \"Competitivo\", dependsOn = \"World_Enabled\" }\r\
    add{ tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", type = \"button\", text = \"Aplicar preset\", presetAction = true }\r\
\r\
    GV.Schema = S\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.world = GV.Modules.world or {}\r\
    GV.Modules.world.schema = S\r\
end\r\
"
local f = loadstring(chunk, '@schema/world.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local C = Color3.fromRGB\r\
    local ACC = C(96, 130, 255)\r\
    local S = {}\r\
    local function add(r) table.insert(S, r) end\r\
    -- color pegado a un toggle de feature (aparece sobre el toggle). `toggle`=flag del toggle, `base`=flag del color.\r\
    local function color(toggle, base, text, group, side, default, default2)\r\
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = \"ESP\", group = group, side = side,\r\
            default = default, default2 = default2 or ACC })\r\
    end\r\
    local TAB = \"ESP\"\r\
\r\
    -- General (Left)\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Enabled\", type = \"toggle\", text = \"Enable ESP\", default = false, keybind = true, master = true }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Box\", type = \"toggle\", text = \"Box\", default = true, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Box\", \"ESP_BoxColor\", \"Box color\", \"General\", \"Left\", C(235, 235, 240))\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxFilled\", type = \"toggle\", text = \"Box relleno\", default = false, dependsOn = \"ESP_Box\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxFillAlpha\", type = \"slider\", text = \"Relleno alpha\", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = \"ESP_BoxFilled\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxOutline\", type = \"toggle\", text = \"Box contorno\", default = true, dependsOn = \"ESP_Box\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxThickness\", type = \"slider\", text = \"Box grosor\", min = 1, max = 5, default = 1, dependsOn = \"ESP_Box\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Name\", type = \"toggle\", text = \"Nombre\", default = true, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Name\", \"ESP_NameColor\", \"Nombre color\", \"General\", \"Left\", C(235, 235, 240))\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Distance\", type = \"toggle\", text = \"Distancia\", default = true, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Health\", type = \"toggle\", text = \"Vida\", default = true, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_HealthStyle\", type = \"dropdown\", text = \"Vida estilo\", values = { \"Barra\", \"Numero\", \"Barra+Numero\" }, default = \"Barra\", dependsOn = \"ESP_Health\" }\r\
\r\
    -- Extras (Left)\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_Skeleton\", type = \"toggle\", text = \"Esqueleto\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Skeleton\", \"ESP_SkeletonColor\", \"Esqueleto color\", \"Extras\", \"Left\", C(200, 200, 210))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_HeadDot\", type = \"toggle\", text = \"Head dot\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_HeadDot\", \"ESP_HeadDotColor\", \"Head dot color\", \"Extras\", \"Left\", C(255, 80, 80))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_HeadDotRadius\", type = \"slider\", text = \"Head dot radio\", min = 1, max = 12, default = 3, dependsOn = \"ESP_HeadDot\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_LookDir\", type = \"toggle\", text = \"Direccion de mira\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_LookDir\", \"ESP_LookDirColor\", \"Mira color\", \"Extras\", \"Left\", C(255, 255, 120))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_LookLength\", type = \"slider\", text = \"Mira largo\", min = 1, max = 10, default = 2, decimals = 1, dependsOn = \"ESP_LookDir\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_Tracer\", type = \"toggle\", text = \"Tracer\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Tracer\", \"ESP_TracerColor\", \"Tracer color\", \"Extras\", \"Left\", C(96, 130, 255))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_TracerFrom\", type = \"dropdown\", text = \"Tracer origen\", values = { \"Bottom\", \"Center\", \"Top\", \"Mouse\" }, default = \"Bottom\", dependsOn = \"ESP_Tracer\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreen\", type = \"toggle\", text = \"Flechas off-screen\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_OffScreen\", \"ESP_OffScreenColor\", \"Off-screen color\", \"Extras\", \"Left\", C(255, 170, 60))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreenRadius\", type = \"slider\", text = \"Off-screen radio\", min = 50, max = 400, default = 200, dependsOn = \"ESP_OffScreen\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreenSize\", type = \"slider\", text = \"Off-screen tamano\", min = 6, max = 40, default = 16, dependsOn = \"ESP_OffScreen\" }\r\
\r\
    -- Chams (Right, detectable)\r\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", type = \"label\", text = \"Chams usa Highlight = INSTANCIA detectable\" }\r\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_Chams\", type = \"toggle\", text = \"Chams\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Chams\", \"ESP_ChamsFill\", \"Chams fill\", \"Chams (detectable)\", \"Right\", C(120, 60, 200))\r\
    color(\"ESP_Chams\", \"ESP_ChamsOutline\", \"Chams outline\", \"Chams (detectable)\", \"Right\", C(200, 160, 255))\r\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsDepthMode\", type = \"dropdown\", text = \"Depth\", values = { \"AlwaysOnTop\", \"Occluded\" }, default = \"AlwaysOnTop\", dependsOn = \"ESP_Chams\" }\r\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsFillTransparency\", type = \"slider\", text = \"Fill transp\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"ESP_Chams\" }\r\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsOutlineTransparency\", type = \"slider\", text = \"Outline transp\", min = 0, max = 1, default = 0, decimals = 2, dependsOn = \"ESP_Chams\" }\r\
\r\
    -- Color / Visibilidad (Right)\r\
    add{ tab = TAB, group = \"Color / Visibilidad\", side = \"Right\", flag = \"ESP_ColorMode\", type = \"dropdown\", text = \"Modo de color\", values = { \"Fijo\", \"Team\", \"Visibilidad\", \"Distancia\" }, default = \"Fijo\", dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Color / Visibilidad\", side = \"Right\", flag = \"ESP_VisibleCheck\", type = \"toggle\", text = \"Chequeo de visibilidad (raycast)\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_VisibleCheck\", \"ESP_VisibleColor\", \"Visible color\", \"Color / Visibilidad\", \"Right\", C(64, 200, 96))\r\
    color(\"ESP_VisibleCheck\", \"ESP_HiddenColor\", \"Oculto color\", \"Color / Visibilidad\", \"Right\", C(235, 64, 52))\r\
\r\
    -- Filtros (Right)\r\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_MaxDistance\", type = \"slider\", text = \"Distancia max (0=sin limite)\", min = 0, max = 5000, default = 1200, suffix = \"st\", dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_PlayersOnly\", type = \"toggle\", text = \"Solo jugadores\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_TeamCheck\", type = \"toggle\", text = \"Team check\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_DeadCheck\", type = \"toggle\", text = \"Ocultar muertos\", default = true, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_MaxTargets\", type = \"slider\", text = \"Targets max\", min = 1, max = 100, default = 50, dependsOn = \"ESP_Enabled\" }\r\
\r\
    -- Object ESP + Prefs (Right)\r\
    add{ tab = TAB, group = \"Object ESP\", side = \"Right\", flag = \"ESP_Objects\", type = \"toggle\", text = \"Object ESP (perfil)\", default = false, dependsOn = \"ESP_Enabled\" }\r\
    color(\"ESP_Objects\", \"ESP_ObjectColor\", \"Objetos color\", \"Object ESP\", \"Right\", C(255, 220, 90))\r\
    add{ tab = TAB, group = \"Prefs\", side = \"Right\", flag = \"ESP_Font\", type = \"slider\", text = \"Fuente\", min = 0, max = 3, default = 2, dependsOn = \"ESP_Enabled\" }\r\
    add{ tab = TAB, group = \"Prefs\", side = \"Right\", flag = \"ESP_TextSize\", type = \"slider\", text = \"Texto tamano\", min = 8, max = 24, default = 13, dependsOn = \"ESP_Enabled\" }\r\
\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.esp = GV.Modules.esp or {}\r\
    GV.Modules.esp.schema = S\r\
end\r\
"
local f = loadstring(chunk, '@schema/esp.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local C = Color3.fromRGB\r\
    local ACC = C(96, 130, 255)\r\
    local S = {}\r\
    local function add(r) table.insert(S, r) end\r\
    local function color(toggle, base, text, group, side, default, default2)\r\
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = \"Local\", group = group, side = side,\r\
            default = default, default2 = default2 or ACC })\r\
    end\r\
    local TAB = \"Local\"\r\
\r\
    -- Camara (Left)\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_Enabled\", type = \"toggle\", text = \"Enable Local\", default = false, keybind = true, master = true }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOV\", type = \"toggle\", text = \"FOV changer\", default = false, dependsOn = \"Local_Enabled\" }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOVValue\", type = \"slider\", text = \"FOV\", min = 40, max = 120, default = 70, dependsOn = \"Local_FOV\" }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPerson\", type = \"toggle\", text = \"3ra persona\", default = false, dependsOn = \"Local_Enabled\" }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPersonDistance\", type = \"slider\", text = \"3ra persona distancia\", min = 5, max = 30, default = 12, dependsOn = \"Local_ThirdPerson\" }\r\
    -- Custom Aspect Ratio: stretch por matriz CFrame (funciona en cualquier executor)\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_Aspect\", type = \"toggle\", text = \"Aspect ratio (stretch)\", default = false, dependsOn = \"Local_Enabled\" }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_AspectH\", type = \"slider\", text = \"Horizontal\", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = \"Local_Aspect\" }\r\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_AspectV\", type = \"slider\", text = \"Vertical\", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = \"Local_Aspect\" }\r\
\r\
    -- Crosshair (Left)\r\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_Crosshair\", type = \"toggle\", text = \"Crosshair\", default = false, dependsOn = \"Local_Enabled\" }\r\
    color(\"Local_Crosshair\", \"Local_CrosshairColor\", \"Crosshair color\", \"Crosshair\", \"Left\", C(0, 255, 120))\r\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairStyle\", type = \"dropdown\", text = \"Estilo\", values = { \"Cross\", \"Dot\", \"Circle\", \"T\" }, default = \"Cross\", dependsOn = \"Local_Crosshair\" }\r\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 40, default = 10, dependsOn = \"Local_Crosshair\" }\r\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Crosshair\" }\r\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairThickness\", type = \"slider\", text = \"Grosor\", min = 1, max = 6, default = 1, dependsOn = \"Local_Crosshair\" }\r\
\r\
    -- Hitmarker (Right)\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_Hitmarker\", type = \"toggle\", text = \"Hitmarker (necesita hitSignal del perfil)\", default = false, dependsOn = \"Local_Enabled\" }\r\
    color(\"Local_Hitmarker\", \"Local_HitmarkerColor\", \"Hitmarker color\", \"Hitmarker\", \"Right\", C(255, 255, 255))\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 30, default = 8, dependsOn = \"Local_Hitmarker\" }\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Hitmarker\" }\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerDuration\", type = \"slider\", text = \"Duracion\", min = 0.05, max = 1, default = 0.3, decimals = 2, dependsOn = \"Local_Hitmarker\" }\r\
\r\
    -- HUD (Right)\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_Watermark\", type = \"toggle\", text = \"Watermark\", default = false, dependsOn = \"Local_Enabled\" }\r\
    color(\"Local_Watermark\", \"Local_WatermarkColor\", \"Watermark color\", \"HUD\", \"Right\", C(235, 235, 240))\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_FPS\", type = \"toggle\", text = \"  FPS\", default = true, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Ping\", type = \"toggle\", text = \"  ping\", default = true, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Name\", type = \"toggle\", text = \"  nombre\", default = true, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Time\", type = \"toggle\", text = \"  hora\", default = false, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkX\", type = \"slider\", text = \"Watermark X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkY\", type = \"slider\", text = \"Watermark Y\", min = 0, max = 1200, default = 8, dependsOn = \"Local_Watermark\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindList\", type = \"toggle\", text = \"Lista de keybinds\", default = false, dependsOn = \"Local_Enabled\" }\r\
    color(\"Local_KeybindList\", \"Local_KeybindColor\", \"Keybinds color\", \"HUD\", \"Right\", C(235, 235, 240))\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindX\", type = \"slider\", text = \"Keybinds X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_KeybindList\" }\r\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindY\", type = \"slider\", text = \"Keybinds Y\", min = 0, max = 1200, default = 120, dependsOn = \"Local_KeybindList\" }\r\
\r\
    -- Extras (Right)\r\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_AntiFlash\", type = \"toggle\", text = \"Anti-flash\", default = false, dependsOn = \"Local_Enabled\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_AntiSmoke\", type = \"toggle\", text = \"Anti-humo (necesita perfil)\", default = false, dependsOn = \"Local_Enabled\" }\r\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_SelfChams\", type = \"toggle\", text = \"Self-chams (Highlight, detectable)\", default = false, dependsOn = \"Local_Enabled\" }\r\
    color(\"Local_SelfChams\", \"Local_SelfChamsFill\", \"Self-chams fill\", \"Extras\", \"Right\", C(0, 200, 255))\r\
    color(\"Local_SelfChams\", \"Local_SelfChamsOutline\", \"Self-chams outline\", \"Extras\", \"Right\", C(180, 240, 255))\r\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_SelfChamsFillTransparency\", type = \"slider\", text = \"Self-chams transp\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"Local_SelfChams\" }\r\
\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.selffx = GV.Modules.selffx or {}\r\
    GV.Modules.selffx.schema = S\r\
end\r\
"
local f = loadstring(chunk, '@schema/local.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    GV.Profiles = GV.Profiles or {}\r\
    local Players = game:GetService(\"Players\")\r\
    GV.Profiles.rivals = {\r\
        defaults = { World_FogColor = Color3.fromRGB(190, 195, 210) },\r\
        textures = { rain = \"rbxassetid://13911374915\", snow = \"rbxassetid://15414665346\" },\r\
        -- excluir el rig de clima propio ('Camera'), la camara y el char del jugador\r\
        mapFilter = function(inst)\r\
            if inst.Name == \"Camera\" then return true end\r\
            local cam = workspace.CurrentCamera\r\
            if cam then local ok, r = pcall(function() return inst:IsDescendantOf(cam) end); if ok and r then return true end end\r\
            local plr = Players.LocalPlayer\r\
            if plr and plr.Character then\r\
                local ok, r = pcall(function() return inst:IsDescendantOf(plr.Character) end)\r\
                if ok and r then return true end\r\
            end\r\
            return false\r\
        end,\r\
        extraSchema = {}, -- controles Rivals-only si aparecen\r\
    }\r\
\r\
    -- Perfil ESP de Rivals: enumera por tag \"Entity\" (fighters + dummies), FFA.\r\
    local BONES_R15 = {\r\
        { a = \"Head\", b = \"UpperTorso\" }, { a = \"UpperTorso\", b = \"LowerTorso\" },\r\
        { a = \"UpperTorso\", b = \"LeftUpperArm\" }, { a = \"LeftUpperArm\", b = \"LeftLowerArm\" }, { a = \"LeftLowerArm\", b = \"LeftHand\" },\r\
        { a = \"UpperTorso\", b = \"RightUpperArm\" }, { a = \"RightUpperArm\", b = \"RightLowerArm\" }, { a = \"RightLowerArm\", b = \"RightHand\" },\r\
        { a = \"LowerTorso\", b = \"LeftUpperLeg\" }, { a = \"LeftUpperLeg\", b = \"LeftLowerLeg\" }, { a = \"LeftLowerLeg\", b = \"LeftFoot\" },\r\
        { a = \"LowerTorso\", b = \"RightUpperLeg\" }, { a = \"RightUpperLeg\", b = \"RightLowerLeg\" }, { a = \"RightLowerLeg\", b = \"RightFoot\" },\r\
    }\r\
    GV.Profiles.rivals.esp = {\r\
        provider = {\r\
            getTargets = function(esp)\r\
                local out = {}\r\
                local myChar = Players.LocalPlayer and Players.LocalPlayer.Character\r\
                for _, model in ipairs(esp.Services.CollectionService:GetTagged(\"Entity\")) do\r\
                    if model ~= myChar and model:IsA(\"Model\") then\r\
                        local hum = model:FindFirstChildOfClass(\"Humanoid\")\r\
                        local root = model:FindFirstChild(\"HumanoidRootPart\")\r\
                        local head = model:FindFirstChild(\"Head\")\r\
                        if hum and root and head and hum.Health > 0 then\r\
                            local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil\r\
                            table.insert(out, {\r\
                                model = model, health = hum.Health, maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),\r\
                                root = root, head = head, bones = BONES_R15, name = model.Name, team = nil,\r\
                                weapon = nil, level = nil, isEnemy = true, isPlayer = isPlayer,\r\
                            })\r\
                        end\r\
                    end\r\
                end\r\
                return out\r\
            end,\r\
        },\r\
        objectSources = {\r\
            { key = \"Grenade\", tag = \"Grenade\", name = \"Granada\", maxDistance = 500 },\r\
            { key = \"Trap\", tag = \"Trap\", name = \"Trampa\", maxDistance = 500 },\r\
        },\r\
    }\r\
end\r\
"
local f = loadstring(chunk, '@games/rivals.lua')(); f(GV) end
do local chunk = "--[[ PERFIL BASE — copiar a games/<tujuego>.lua para un script nuevo.\r\
\r\
     Los 3 modulos (World/ESP/SelfFX) corren game-agnostic SIN perfil:\r\
       V:Attach(Lib, Win, { modules = {\"world\",\"esp\",\"selffx\"} })   -- sin profile = generico\r\
     El perfil es OPCIONAL y solo agrega lo especifico del juego:\r\
       V:Attach(Lib, Win, { modules = {...}, profile = \"tujuego\" })\r\
\r\
     Contrato completo abajo. Todos los campos son opcionales; borra los que no uses. ]]\r\
return function(GV)\r\
    GV.Profiles = GV.Profiles or {}\r\
    GV.Profiles._template = {\r\
        -- === World (opcional) ===\r\
        defaults = {},                                   -- overrides de flags por defecto\r\
        textures = { rain = \"rbxassetid://13911374915\", snow = \"rbxassetid://15414665346\" },\r\
        mapFilter = function(inst) return false end,     -- true = excluir del bloque J (skybox/char propio)\r\
        extraSchema = {},                                -- filas de schema game-only\r\
\r\
        -- === ESP (opcional; sin esto usa GV.DefaultProvider por Players) ===\r\
        esp = {\r\
            provider = {\r\
                -- getTargets(esp) -> lista de Target normalizado:\r\
                -- { model, health, maxHealth, root, head, bones={{a,b}...}, name, team,\r\
                --   weapon, level, isEnemy, isPlayer }\r\
                getTargets = function(esp) return {} end,\r\
            },\r\
            objectSources = {\r\
                -- { key=\"Loot\", tag=\"Loot\", name=\"Loot\", maxDistance=500 }  -- por CollectionService tag\r\
                -- { key=\"Chest\", classFilter=\"Model\", name=\"Chest\" }        -- por clase\r\
            },\r\
        },\r\
\r\
        -- === SelfFX (opcional; sin esto usa camara/overlays genericos) ===\r\
        selffx = {\r\
            -- setFOV(offset)          -- si el juego controla la camara (ej. FOV spring propio)\r\
            -- setThirdPerson(bool)    -- override de 3ra persona del juego\r\
            -- flashEffects() -> {}    -- instancias de flash a neutralizar (default generico: CC/Blur \"flash\"/\"blind\")\r\
            -- smokeEffects() -> {}    -- instancias de humo\r\
            -- hitSignal = RBXScriptSignal  -- para el hitmarker (dispara al pegar)\r\
            -- keybinds() -> { {name=,key=} }  -- lista para el keybind-list\r\
        },\r\
    }\r\
end\r\
"
local f = loadstring(chunk, '@games/_template.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    -- GV.Attach(Library, Window, opts) -> suite\r\
    -- opts: { adapter, modules={\"world\",...}, profile, services, flags }\r\
    function GV.Attach(Library, Window, opts)\r\
        opts = opts or {}\r\
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or \"claudeui\"]\r\
        assert(adapter, \"adapter no encontrado\")\r\
        local names = opts.modules or GV._defaultModules or { \"world\" }\r\
        local flags = opts.flags or {}\r\
        local bag = { Flags = flags }\r\
        function bag:Set(k, v) self.Flags[k] = v end\r\
        function bag:Get(k) return self.Flags[k] end\r\
        local suite = { modules = {}, flags = flags }\r\
        function suite:Unload()\r\
            if self._preview then pcall(function() self._preview:Unload() end); self._preview = nil end\r\
            for _, m in pairs(self.modules) do pcall(function() m:Unload() end) end\r\
        end\r\
        bag.__suite = suite\r\
\r\
        local schema = {}\r\
        for _, r in ipairs(GV.SchemaHelpers.suiteRows()) do table.insert(schema, r) end\r\
        for _, name in ipairs(names) do\r\
            local def = GV.Modules[name]\r\
            if def then\r\
                local inst = def.new({ services = opts.services, flags = flags })\r\
                if opts.profile and inst.UseProfile then\r\
                    local prof = GV.Profiles[opts.profile]\r\
                    inst:UseProfile(prof and (prof[name] or prof) or nil)\r\
                end\r\
                suite.modules[name] = inst\r\
                for _, r in ipairs(def.schema or {}) do table.insert(schema, r) end\r\
            end\r\
        end\r\
        GV.Renderer.build(adapter, Window, schema, bag)\r\
        -- keybind-list generico: features con keybind del schema (para el HUD de SelfFX)\r\
        if suite.modules.selffx then\r\
            local kbl = {}\r\
            for _, r in ipairs(schema) do\r\
                if r.keybind and r.text then table.insert(kbl, { name = r.text, flag = r.flag }) end\r\
            end\r\
            suite.modules.selffx._keybindList = kbl\r\
        end\r\
        for _, inst in pairs(suite.modules) do inst:Init() end\r\
        -- Preview viewport: solo si el adapter lo soporta (Primordial). ClaudeUI = 0 instancias.\r\
        if adapter.supportsPreview and opts.preview ~= false and GV.Preview then\r\
            local ok, pv = pcall(function() return GV.Preview.mount(suite) end)\r\
            if ok then suite._preview = pv end\r\
        end\r\
        return suite\r\
    end\r\
end\r\
"
local f = loadstring(chunk, '@entry/attach.lua')(); f(GV) end
GV._defaultAdapter = 'primordial'
GV._defaultModules = {'world','esp','selffx'}
return { Attach = GV.Attach, _GV = GV }
