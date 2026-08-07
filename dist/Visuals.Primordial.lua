-- World Visuals (primordial) — build autogenerado
local GV = {}
do local chunk = "return function(GV)\
    local U = {}\
    function U.clamp(x, a, b) return math.max(a, math.min(b, x)) end\
    function U.lerp(a, b, t) return a + (b - a) * t end\
    function U.serColor(c)\
        return { __ = \"c3\", r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) }\
    end\
    function U.deColor(t) return Color3.fromRGB(t.r, t.g, t.b) end\
    function U.serEnum(e) return { __ = \"en\", t = tostring(e.EnumType), n = e.Name } end\
    function U.deEnum(t)\
        local et = t.t:gsub(\"^Enum%.\", \"\")\
        for _, item in ipairs(Enum[et]:GetEnumItems()) do\
            if item.Name == t.n then return item end\
        end\
    end\
    function U.deepcopy(t)\
        if type(t) ~= \"table\" then return t end\
        local r = {}; for k, v in pairs(t) do r[k] = U.deepcopy(v) end; return r\
    end\
    GV.Util = U\
end\
"
local f = loadstring(chunk, '@core/util.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local Color = {}\
    local WHITE = Color3.new(1, 1, 1)\
    function Color.solid(flags, base)\
        local c = flags[base]\
        return typeof(c) == \"Color3\" and c or WHITE\
    end\
    function Color.fade(flags, base, t)\
        local c1 = flags[base]\
        if typeof(c1) ~= \"Color3\" then return WHITE end\
        if not flags[base .. \"_Fade\"] then return c1 end\
        local c2 = flags[base .. \"_2\"]\
        if typeof(c2) ~= \"Color3\" then return c1 end\
        local speed = flags[\"Suite_FadeSpeed\"] or 1\
        local a = (math.sin((t or tick()) * speed * math.pi * 2) + 1) / 2\
        return c1:Lerp(c2, a)\
    end\
    GV.Color = Color\
end\
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
            local amb = GV.Color.fade(self.Flags, \"World_Ambient\", tick())\r\
            self:_set(L, \"Ambient\", amb)\r\
            local oa = self.Flags[\"World_OutdoorAmbient\"] and GV.Color.fade(self.Flags, \"World_OutdoorAmbient\", tick()) or amb\r\
            self:_set(L, \"OutdoorAmbient\", oa)\r\
            self:_set(L, \"Brightness\", self:_flag(\"World_Brightness\", 3))\r\
            self:_set(L, \"GlobalShadows\", not self:_flag(\"World_NoShadows\", false))\r\
        end\r\
        self:_set(L, \"ExposureCompensation\", self:_flag(\"World_Exposure\", 0))\r\
        self:_set(L, \"ColorShift_Top\", GV.Color.fade(self.Flags, \"World_ColorShiftTop\", tick()))\r\
        self:_set(L, \"ColorShift_Bottom\", GV.Color.fade(self.Flags, \"World_ColorShiftBottom\", tick()))\r\
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
            self:_set(L, \"FogColor\", GV.Color.fade(self.Flags, \"World_FogColor\", tick()))\r\
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
    -- J. Visibilidad (agresivo). Gateado tras World_Advanced. Usa self._mapFilter del perfil.\r\
    function World:_applyVisibility()\r\
        if not self:_flag(\"World_Advanced\", false) then return end\r\
        local killP  = self:_flag(\"World_KillParticles\", false)\r\
        local smooth = self:_flag(\"World_ForceSmoothPlastic\", false)\r\
        local tr     = self:_flag(\"World_MapTransparent\", false)\r\
        local noTex  = self:_flag(\"World_NoTextures\", false)\r\
        if not (killP or smooth or tr or noTex) then return end\r\
        local amount = self:_flag(\"World_MapTransparentAmount\", 0.6)\r\
        local filter = self._mapFilter\r\
        local ok, list = pcall(function() return self.Services.Workspace:GetDescendants() end)\r\
        if not ok or not list then return end\r\
        for _, d in ipairs(list) do\r\
            if not (filter and filter(d)) then\r\
                if killP and (d:IsA(\"ParticleEmitter\") or d:IsA(\"Beam\") or d:IsA(\"Trail\")) then\r\
                    self:_set(d, \"Enabled\", false)\r\
                elseif d:IsA(\"BasePart\") then\r\
                    if smooth then self:_set(d, \"Material\", Enum.Material.SmoothPlastic) end\r\
                    if tr and d.Transparency < amount then self:_set(d, \"Transparency\", amount) end\r\
                elseif noTex and (d:IsA(\"Decal\") or d:IsA(\"Texture\")) then\r\
                    self:_set(d, \"Transparency\", 1)\r\
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
        Niebla              = { World_Enabled = true, World_NoFog = false, World_FogStart = 0, World_FogEnd = 180, World_FogColor = Color3.fromRGB(180, 185, 195) },\r\
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
do local chunk = "return function(GV)\
    if not (Drawing and Drawing.new) then\
        GV.Modules = GV.Modules or {}; GV.Modules.esp = GV.Modules.esp or {}\
        GV.Modules.esp.new = GV.Modules.esp.new or function() return { Init = function() end, Unload = function() end } end\
        return\
    end\
    local ESP = {}\
    ESP.__index = ESP\
\
    function ESP.new(opts)\
        opts = opts or {}\
        local svc = opts.services or {\
            Players = game:GetService(\"Players\"),\
            RunService = game:GetService(\"RunService\"),\
            Workspace = workspace,\
            CollectionService = game:GetService(\"CollectionService\"),\
        }\
        return setmetatable({\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\
            Conns = {}, Drawings = {}, Objects = {}, Highlights = {}, Loaded = false,\
        }, ESP)\
    end\
\
    function ESP:Set(k, v) self.Flags[k] = v end\
    function ESP:Get(k) return self.Flags[k] end\
    function ESP:_flag(k, d)\
        local v = self.Flags[\"ESP_\" .. k]; if v ~= nil then return v end; return d\
    end\
    function ESP:UseProfile(p)\
        if not p then return end\
        if p.provider then self._provider = p.provider end\
        if p.objectSources then self._objectSources = p.objectSources end\
    end\
\
    function ESP:_draw(class, props)\
        local o = Drawing.new(class)\
        o.Visible = false\
        if props then for k, v in pairs(props) do o[k] = v end end\
        table.insert(self.Drawings, o)\
        return o\
    end\
\
    function ESP:_provget()\
        local p = self._provider or GV.DefaultProvider\
        if not p then return {} end\
        local ok, list = pcall(p.getTargets, self)\
        return (ok and list) or {}\
    end\
\
    local BLACK = Color3.new(0, 0, 0)\
    local function hideBundle(b)\
        for k, o in pairs(b) do\
            if k == \"skel\" then for _, l in ipairs(o) do pcall(function() l.Visible = false end) end\
            else pcall(function() o.Visible = false end) end\
        end\
    end\
\
    function ESP:_make()\
        return {\
            box     = self:_draw(\"Square\", { Filled = false, Thickness = 1 }),\
            boxOl   = self:_draw(\"Square\", { Filled = false, Thickness = 3, Color = BLACK }),\
            name    = self:_draw(\"Text\", { Center = true, Outline = true }),\
            dist    = self:_draw(\"Text\", { Center = true, Outline = true }),\
            hpBg    = self:_draw(\"Square\", { Filled = true, Color = BLACK }),\
            hpBar   = self:_draw(\"Square\", { Filled = true }),\
            hpText  = self:_draw(\"Text\", { Center = false, Outline = true }),\
            tracer  = self:_draw(\"Line\", { Thickness = 1 }),\
            headdot = self:_draw(\"Circle\", { Filled = true, NumSides = 16 }),\
            look    = self:_draw(\"Line\", { Thickness = 1 }),\
            arrow   = self:_draw(\"Triangle\", { Filled = true }),\
            skel    = {},\
        }\
    end\
\
    function ESP:_drawArrow(b, tg, cam, t, vp)\
        local center = Vector2.new(vp.X / 2, vp.Y / 2)\
        local sp = cam:WorldToViewportPoint(tg.root.Position)\
        local dir\
        if sp.Z > 0 then dir = Vector2.new(sp.X, sp.Y) - center\
        else dir = center - Vector2.new(sp.X, sp.Y) end\
        if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end\
        dir = dir.Unit\
        local radius = self:_flag(\"OffScreenRadius\", 200)\
        local size = self:_flag(\"OffScreenSize\", 16)\
        local perp = Vector2.new(-dir.Y, dir.X)\
        local tip = center + dir * radius\
        b.arrow.Visible = true\
        b.arrow.PointA = tip\
        b.arrow.PointB = tip - dir * size + perp * (size * 0.6)\
        b.arrow.PointC = tip - dir * size - perp * (size * 0.6)\
        b.arrow.Color = self:_col(tg, \"ESP_OffScreenColor\", t)\
        b.arrow.ZIndex = 5\
    end\
\
    function ESP:_drawExtras(b, tg, cam, t)\
        -- skeleton\
        local showSkel = self:_flag(\"Skeleton\", false)\
        local bones = tg.bones or {}\
        for i, bone in ipairs(bones) do\
            local l = b.skel[i]\
            if not l then l = self:_draw(\"Line\", { Thickness = 1 }); b.skel[i] = l end\
            local pa = tg.model:FindFirstChild(bone.a)\
            local pb = tg.model:FindFirstChild(bone.b)\
            if showSkel and pa and pb then\
                local va = cam:WorldToViewportPoint(pa.Position)\
                local vb = cam:WorldToViewportPoint(pb.Position)\
                if va.Z > 0 and vb.Z > 0 then\
                    l.Visible = true\
                    l.From = Vector2.new(va.X, va.Y); l.To = Vector2.new(vb.X, vb.Y)\
                    l.Color = self:_col(tg, \"ESP_SkeletonColor\", t); l.ZIndex = 2\
                else l.Visible = false end\
            else l.Visible = false end\
        end\
        for i = #bones + 1, #b.skel do b.skel[i].Visible = false end\
        -- headdot\
        local showDot = self:_flag(\"HeadDot\", false)\
        b.headdot.Visible = showDot\
        if showDot then\
            local hv = cam:WorldToViewportPoint(tg.head.Position)\
            if hv.Z > 0 then\
                b.headdot.Position = Vector2.new(hv.X, hv.Y)\
                b.headdot.Radius = self:_flag(\"HeadDotRadius\", 3)\
                b.headdot.Color = self:_col(tg, \"ESP_HeadDotColor\", t)\
                b.headdot.ZIndex = 4\
            else b.headdot.Visible = false end\
        end\
        -- look direction\
        local showLook = self:_flag(\"LookDir\", false)\
        b.look.Visible = showLook\
        if showLook then\
            local hp = tg.head.Position\
            local a = cam:WorldToViewportPoint(hp)\
            local c = cam:WorldToViewportPoint(hp + tg.head.CFrame.LookVector * self:_flag(\"LookLength\", 2))\
            if a.Z > 0 and c.Z > 0 then\
                b.look.From = Vector2.new(a.X, a.Y); b.look.To = Vector2.new(c.X, c.Y)\
                b.look.Color = self:_col(tg, \"ESP_LookDirColor\", t); b.look.ZIndex = 3\
            else b.look.Visible = false end\
        end\
    end\
\
    function ESP:_healthColor(frac)\
        return Color3.fromRGB(math.floor(220 * (1 - frac)) + 20, math.floor(200 * frac) + 20, 40)\
    end\
\
    -- color de un target para un flag base, segun ColorMode\
    local TEAM_ENEMY, TEAM_ALLY = Color3.fromRGB(235, 64, 52), Color3.fromRGB(64, 200, 96)\
    local GREY = Color3.fromRGB(90, 90, 90)\
    function ESP:_col(tg, base, t)\
        local mode = self:_flag(\"ColorMode\", \"Fijo\")\
        if mode == \"Team\" then return tg.isEnemy and TEAM_ENEMY or TEAM_ALLY end\
        if mode == \"Visibilidad\" then\
            return tg._visible and GV.Color.fade(self.Flags, \"ESP_VisibleColor\", t)\
                or GV.Color.fade(self.Flags, \"ESP_HiddenColor\", t)\
        end\
        if mode == \"Distancia\" then\
            local frac = math.clamp((tg._dist or 0) / self:_flag(\"MaxDistance\", 1200), 0, 1)\
            return GV.Color.fade(self.Flags, base, t):Lerp(GREY, frac)\
        end\
        return GV.Color.fade(self.Flags, base, t)\
    end\
\
    -- raycast LOS camara->root (ignora camara + char local)\
    function ESP:_visible(root)\
        local cam = self.Services.Workspace.CurrentCamera\
        if not cam or not root then return true end\
        local origin = cam.CFrame.Position\
        local params = RaycastParams.new()\
        params.FilterType = Enum.RaycastFilterType.Exclude\
        local ignore = { cam }\
        local lp = self.Services.Players and self.Services.Players.LocalPlayer\
        if lp and lp.Character then table.insert(ignore, lp.Character) end\
        params.FilterDescendantsInstances = ignore\
        local res = self.Services.Workspace:Raycast(origin, root.Position - origin, params)\
        if not res then return true end\
        return res.Instance and root.Parent and res.Instance:IsDescendantOf(root.Parent) or false\
    end\
\
    -- chams via Highlight (detectable). Uno por modelo en self.Highlights.\
    function ESP:_chams(tg, t)\
        if not self:_flag(\"Chams\", false) then\
            local h = self.Highlights[tg.model]; if h then h.Enabled = false end\
            return\
        end\
        local h = self.Highlights[tg.model]\
        if not h or not h.Parent then\
            h = Instance.new(\"Highlight\")\
            h.Name = \"LC\"\
            h.Adornee = tg.model\
            h.Parent = self.Services.Workspace.CurrentCamera\
            self.Highlights[tg.model] = h\
        end\
        h.Enabled = true\
        h.FillColor = GV.Color.fade(self.Flags, \"ESP_ChamsFill\", t)\
        h.OutlineColor = GV.Color.fade(self.Flags, \"ESP_ChamsOutline\", t)\
        h.FillTransparency = self:_flag(\"ChamsFillTransparency\", 0.5)\
        h.OutlineTransparency = self:_flag(\"ChamsOutlineTransparency\", 0)\
        h.DepthMode = (self:_flag(\"ChamsDepthMode\", \"AlwaysOnTop\") == \"Occluded\")\
            and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop\
    end\
\
    function ESP:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)\
        local topV = cam:WorldToViewportPoint(tg.head.Position + Vector3.new(0, 0.6, 0))\
        local botV = cam:WorldToViewportPoint(tg.root.Position - Vector3.new(0, 3.0, 0))\
        local onScreen = topV.Z > 0 and topV.X >= 0 and topV.X <= vp.X and topV.Y >= 0 and topV.Y <= vp.Y\
        b.arrow.Visible = false\
        if not onScreen then\
            -- ocultar el bundle on-screen; flecha off-screen si aplica\
            for _, k in ipairs({ \"box\", \"boxOl\", \"name\", \"dist\", \"hpBg\", \"hpBar\", \"hpText\", \"tracer\", \"headdot\", \"look\" }) do\
                b[k].Visible = false\
            end\
            for _, l in ipairs(b.skel) do l.Visible = false end\
            if self:_flag(\"OffScreen\", false) then self:_drawArrow(b, tg, cam, t, vp) end\
            return\
        end\
        local top = Vector2.new(topV.X, topV.Y)\
        local bot = Vector2.new(botV.X, botV.Y)\
        local h = math.abs(bot.Y - top.Y)\
        local w = h * 0.62\
        local x = top.X - w / 2\
        local y = top.Y\
\
        local showBox   = self:_flag(\"Box\", true)\
        local showName  = self:_flag(\"Name\", true)\
        local showHp    = self:_flag(\"Health\", true)\
        local showDist  = self:_flag(\"Distance\", true)\
        local showTrace = self:_flag(\"Tracer\", false)\
        local hpStyle   = self:_flag(\"HealthStyle\", \"Barra\")\
        local showBar   = hpStyle == \"Barra\" or hpStyle == \"Barra+Numero\"\
        local showNum   = hpStyle == \"Numero\" or hpStyle == \"Barra+Numero\"\
\
        -- box\
        b.box.Visible = showBox\
        b.boxOl.Visible = showBox and self:_flag(\"BoxOutline\", true)\
        if showBox then\
            b.box.Color = self:_col(tg, \"ESP_BoxColor\", t)\
            b.box.Filled = self:_flag(\"BoxFilled\", false)\
            b.box.Thickness = self:_flag(\"BoxThickness\", 1)\
            b.box.Size = Vector2.new(w, h); b.box.Position = Vector2.new(x, y); b.box.ZIndex = 2\
            b.boxOl.Size = b.box.Size; b.boxOl.Position = b.box.Position; b.boxOl.ZIndex = 1\
        end\
\
        -- health\
        local frac = math.clamp((tg.health or 0) / (tg.maxHealth and tg.maxHealth > 0 and tg.maxHealth or 100), 0, 1)\
        b.hpBg.Visible = showHp and showBar\
        b.hpBar.Visible = showHp and showBar\
        b.hpText.Visible = showHp and showNum\
        if showHp and showBar then\
            local bx = x - 5\
            b.hpBg.Position = Vector2.new(bx, y - 1); b.hpBg.Size = Vector2.new(3, h + 2); b.hpBg.ZIndex = 2\
            local bh = h * frac\
            b.hpBar.Position = Vector2.new(bx, y + (h - bh)); b.hpBar.Size = Vector2.new(3, bh)\
            b.hpBar.Color = self:_healthColor(frac); b.hpBar.ZIndex = 3\
        end\
        if showHp and showNum then\
            b.hpText.Text = tostring(math.floor(tg.health or 0))\
            b.hpText.Font = font; b.hpText.Size = textSize; b.hpText.Color = self:_healthColor(frac)\
            b.hpText.Position = Vector2.new(x + w + 3, y); b.hpText.ZIndex = 4\
        end\
\
        -- name\
        b.name.Visible = showName\
        if showName then\
            b.name.Text = tg.name or \"?\"\
            b.name.Font = font; b.name.Size = textSize; b.name.Color = self:_col(tg, \"ESP_NameColor\", t)\
            b.name.Position = Vector2.new(top.X, y - textSize - 2); b.name.ZIndex = 4\
        end\
\
        -- distance\
        b.dist.Visible = showDist\
        if showDist then\
            b.dist.Text = math.floor(dist) .. \"m\"\
            b.dist.Font = font; b.dist.Size = textSize; b.dist.Color = Color3.fromRGB(180, 180, 185)\
            b.dist.Position = Vector2.new(top.X, bot.Y + 2); b.dist.ZIndex = 4\
        end\
\
        -- tracer\
        b.tracer.Visible = showTrace\
        if showTrace then\
            local from = self:_flag(\"TracerFrom\", \"Bottom\")\
            local fx, fy = vp.X / 2, vp.Y\
            if from == \"Center\" then fy = vp.Y / 2 elseif from == \"Top\" then fy = 0\
            elseif from == \"Mouse\" then local m = self.Services.Workspace.CurrentCamera; fx, fy = vp.X / 2, vp.Y / 2 end\
            b.tracer.From = Vector2.new(fx, fy)\
            b.tracer.To = Vector2.new(top.X, bot.Y)\
            b.tracer.Color = self:_col(tg, \"ESP_TracerColor\", t)\
            b.tracer.ZIndex = 1\
        end\
\
        self:_drawExtras(b, tg, cam, t)\
    end\
\
    function ESP:_update()\
        local cam = self.Services.Workspace.CurrentCamera\
        if not cam then return end\
        local enabled = self:_flag(\"Enabled\", false)\
        local targets = enabled and self:_provget() or {}\
        local origin = cam.CFrame.Position\
        local vp = cam.ViewportSize\
        local font = self:_flag(\"Font\", 2)\
        local textSize = self:_flag(\"TextSize\", 13)\
        local maxDist = self:_flag(\"MaxDistance\", 1200)\
        local maxTargets = self:_flag(\"MaxTargets\", 50)\
        local t = tick()\
        local live, count = {}, 0\
        for _, tg in ipairs(targets) do\
            if tg.root and tg.head and count < maxTargets and self:_passFilters(tg) then\
                local dist = (tg.root.Position - origin).Magnitude\
                if dist <= maxDist then\
                    count += 1\
                    live[tg.model] = true\
                    tg._dist = dist\
                    if self:_flag(\"VisibleCheck\", false) or self:_flag(\"ColorMode\", \"Fijo\") == \"Visibilidad\" then\
                        tg._visible = self:_visible(tg.root)\
                    else\
                        tg._visible = true\
                    end\
                    local b = self.Objects[tg.model] or self:_make()\
                    self.Objects[tg.model] = b\
                    self:_drawTarget(b, tg, cam, dist, t, font, textSize, vp)\
                    self:_chams(tg, t)\
                end\
            end\
        end\
        for model, b in pairs(self.Objects) do\
            if not live[model] then\
                hideBundle(b)\
                local h = self.Highlights[model]; if h then h.Enabled = false end\
                if not (model and model.Parent) then self.Objects[model] = nil end\
            end\
        end\
        self:_updateObjects()\
    end\
\
    function ESP:_passFilters(tg)\
        if self:_flag(\"DeadCheck\", false) and (tg.health or 0) <= 0 then return false end\
        if self:_flag(\"PlayersOnly\", false) and tg.isPlayer == false then return false end\
        return true\
    end\
\
    -- Object ESP: fuentes declaradas por el perfil (tag o clase) -> box+name+dist\
    function ESP:_updateObjects()\
        self._objBundles = self._objBundles or {}\
        local live = {}\
        if self:_flag(\"Objects\", false) and self._objectSources then\
            local cam = self.Services.Workspace.CurrentCamera\
            if cam then\
                local origin, vp, t = cam.CFrame.Position, cam.ViewportSize, tick()\
                for _, src in ipairs(self._objectSources) do\
                    if self:_flag(\"Obj_\" .. (src.key or src.name), true) then\
                        local insts = {}\
                        if src.tag then insts = self.Services.CollectionService:GetTagged(src.tag)\
                        elseif src.classFilter then\
                            for _, d in ipairs(self.Services.Workspace:GetDescendants()) do\
                                if d:IsA(src.classFilter) then table.insert(insts, d) end\
                            end\
                        end\
                        for _, inst in ipairs(insts) do\
                            local part = inst:IsA(\"BasePart\") and inst or inst:FindFirstChildWhichIsA(\"BasePart\")\
                            if part then\
                                local dist = (part.Position - origin).Magnitude\
                                if dist <= (src.maxDistance or self:_flag(\"MaxDistance\", 1200)) then\
                                    live[inst] = true\
                                    local ob = self._objBundles[inst]\
                                    if not ob then\
                                        ob = { box = self:_draw(\"Square\", { Filled = false, Thickness = 1 }),\
                                            name = self:_draw(\"Text\", { Center = true, Outline = true }),\
                                            dist = self:_draw(\"Text\", { Center = true, Outline = true }) }\
                                        self._objBundles[inst] = ob\
                                    end\
                                    local v = cam:WorldToViewportPoint(part.Position)\
                                    if v.Z > 0 then\
                                        local col = src.color or GV.Color.fade(self.Flags, \"ESP_ObjectColor\", t)\
                                        local ts = self:_flag(\"TextSize\", 13)\
                                        ob.box.Visible = true; ob.box.Color = col; ob.box.Size = Vector2.new(14, 14); ob.box.Position = Vector2.new(v.X - 7, v.Y - 7)\
                                        ob.name.Visible = true; ob.name.Text = src.name; ob.name.Color = col; ob.name.Size = ts; ob.name.Position = Vector2.new(v.X, v.Y - 18)\
                                        ob.dist.Visible = true; ob.dist.Text = math.floor(dist) .. \"m\"; ob.dist.Color = col; ob.dist.Size = ts; ob.dist.Position = Vector2.new(v.X, v.Y + 10)\
                                    else\
                                        for _, o in pairs(ob) do o.Visible = false end\
                                    end\
                                end\
                            end\
                        end\
                    end\
                end\
            end\
        end\
        for inst, ob in pairs(self._objBundles) do\
            if not live[inst] then\
                for _, o in pairs(ob) do pcall(function() o.Visible = false end) end\
                if not (inst and inst.Parent) then self._objBundles[inst] = nil end\
            end\
        end\
    end\
\
    -- Preview mode: dibuja box+skeleton de UN modelo con una camara de ViewportFrame (para §D)\
    function ESP:RenderPreview(cam, model)\
        if not (cam and model) then return end\
        self._preview = self._preview or { box = self:_draw(\"Square\", { Filled = false, Thickness = 1 }), skel = {} }\
        local root = model:FindFirstChild(\"HumanoidRootPart\") or model:FindFirstChildWhichIsA(\"BasePart\")\
        local head = model:FindFirstChild(\"Head\") or root\
        if not root then return end\
        local t = tick()\
        local topV = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))\
        local botV = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))\
        if topV.Z > 0 then\
            local h = math.abs(botV.Y - topV.Y); local w = h * 0.62\
            self._preview.box.Visible = true\
            self._preview.box.Color = GV.Color.fade(self.Flags, \"ESP_BoxColor\", t)\
            self._preview.box.Size = Vector2.new(w, h)\
            self._preview.box.Position = Vector2.new(topV.X - w / 2, topV.Y)\
        else\
            self._preview.box.Visible = false\
        end\
    end\
\
    function ESP:Init()\
        if self.Loaded then return self end\
        self.Loaded = true\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\
            local ok, err = pcall(function() self:_update() end)\
            if not ok then warn(\"[ESP] \" .. tostring(err)) end\
        end)\
        return self\
    end\
\
    function ESP:Unload()\
        self.Loaded = false\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Objects); table.clear(self.Highlights)\
    end\
\
    GV.ESP = ESP\
    GV.Modules = GV.Modules or {}\
    GV.Modules.esp = GV.Modules.esp or {}\
    GV.Modules.esp.new = function(o) return ESP.new(o) end\
end\
"
local f = loadstring(chunk, '@core/ESP.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local BONES_R15 = {\
        { a = \"Head\", b = \"UpperTorso\" }, { a = \"UpperTorso\", b = \"LowerTorso\" },\
        { a = \"UpperTorso\", b = \"LeftUpperArm\" }, { a = \"LeftUpperArm\", b = \"LeftLowerArm\" }, { a = \"LeftLowerArm\", b = \"LeftHand\" },\
        { a = \"UpperTorso\", b = \"RightUpperArm\" }, { a = \"RightUpperArm\", b = \"RightLowerArm\" }, { a = \"RightLowerArm\", b = \"RightHand\" },\
        { a = \"LowerTorso\", b = \"LeftUpperLeg\" }, { a = \"LeftUpperLeg\", b = \"LeftLowerLeg\" }, { a = \"LeftLowerLeg\", b = \"LeftFoot\" },\
        { a = \"LowerTorso\", b = \"RightUpperLeg\" }, { a = \"RightUpperLeg\", b = \"RightLowerLeg\" }, { a = \"RightLowerLeg\", b = \"RightFoot\" },\
    }\
    local BONES_R6 = {\
        { a = \"Head\", b = \"Torso\" }, { a = \"Torso\", b = \"Left Arm\" }, { a = \"Torso\", b = \"Right Arm\" },\
        { a = \"Torso\", b = \"Left Leg\" }, { a = \"Torso\", b = \"Right Leg\" },\
    }\
    local function bonesFor(model)\
        return model:FindFirstChild(\"UpperTorso\") and BONES_R15 or BONES_R6\
    end\
    GV.DefaultProvider = {\
        getTargets = function(esp)\
            local svc = esp.Services\
            local out = {}\
            local lp = svc.Players.LocalPlayer\
            local localChar = lp and lp.Character\
            local localTeam = lp and lp.Team\
            local teamCheck = esp:_flag(\"TeamCheck\", false)\
            for _, p in ipairs(svc.Players:GetPlayers()) do\
                local char = p.Character\
                if char and char ~= localChar then\
                    local hum = char:FindFirstChildOfClass(\"Humanoid\")\
                    local root = char:FindFirstChild(\"HumanoidRootPart\")\
                    local head = char:FindFirstChild(\"Head\")\
                    if hum and root and head and hum.Health > 0 then\
                        table.insert(out, {\
                            model = char, health = hum.Health,\
                            maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),\
                            root = root, head = head, bones = bonesFor(char), name = p.Name, team = p.Team,\
                            weapon = nil, level = nil,\
                            isEnemy = (not teamCheck) or (p.Team ~= localTeam),\
                        })\
                    end\
                end\
            end\
            return out\
        end,\
    }\
end\
"
local f = loadstring(chunk, '@core/esp_default.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local SelfFX = {}\
    SelfFX.__index = SelfFX\
\
    function SelfFX.new(opts)\
        opts = opts or {}\
        local svc = opts.services or {\
            Players = game:GetService(\"Players\"),\
            RunService = game:GetService(\"RunService\"),\
            UserInputService = game:GetService(\"UserInputService\"),\
            Workspace = workspace,\
            Stats = game:FindService(\"Stats\"),\
        }\
        return setmetatable({\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\
            Conns = {}, Drawings = {}, _orig = {}, _made = {}, Highlights = {}, Loaded = false,\
        }, SelfFX)\
    end\
\
    function SelfFX:Set(k, v) self.Flags[k] = v end\
    function SelfFX:Get(k) return self.Flags[k] end\
    function SelfFX:_flag(k, d)\
        local v = self.Flags[\"Local_\" .. k]; if v ~= nil then return v end; return d\
    end\
    function SelfFX:UseProfile(p) if p then self._provider = p end end\
\
    function SelfFX:_draw(class, props)\
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end\
        local o = Drawing.new(class); o.Visible = false\
        if props then for k, v in pairs(props) do o[k] = v end end\
        table.insert(self.Drawings, o); return o\
    end\
\
    -- escritura con memoria (restaura en Unload/off)\
    function SelfFX:_set(obj, prop, val)\
        if not obj then return end\
        local ok, cur = pcall(function() return obj[prop] end)\
        if not ok then return end\
        local mem = self._orig[obj]; if not mem then mem = {}; self._orig[obj] = mem end\
        if mem[prop] == nil then mem[prop] = cur end\
        if cur ~= val then pcall(function() obj[prop] = val end) end\
    end\
    function SelfFX:_restoreAll()\
        for obj, props in pairs(self._orig) do\
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end\
        end\
        table.clear(self._orig)\
    end\
\
    -- Camara: FOV changer + 3ra persona + Custom Aspect Ratio.\
    -- NOTA aspect: en Potassium ViewportSize es read-only duro (setscriptable/sethiddenproperty\
    -- no lo escriben) -> stretch pixel-real NO reproducible sin render-hooks. Mecanismo entregable:\
    -- FieldOfViewMode (Vertical/Diagonal/MaxAxis) + MaxAxisFieldOfView, que altera el mapeo FOV<->aspecto.\
    function SelfFX:_applyCamera()\
        local cam = self.Services.Workspace.CurrentCamera\
        if not cam then return end\
        if self:_flag(\"FOV\", false) then\
            local fov = self:_flag(\"FOVValue\", 70)\
            if self._provider and self._provider.setFOV then self._provider.setFOV(fov - 70)\
            else self:_set(cam, \"FieldOfView\", fov) end\
        end\
        if self:_flag(\"ThirdPerson\", false) then\
            if self._provider and self._provider.setThirdPerson then self._provider.setThirdPerson(true)\
            else self:_thirdPersonGeneric() end\
        end\
        local am = self:_flag(\"AspectMode\", \"Off\")\
        if am ~= \"Off\" then\
            pcall(function() self:_set(cam, \"FieldOfViewMode\", Enum.FieldOfViewMode[am]) end)\
            if am == \"MaxAxis\" then self:_set(cam, \"MaxAxisFieldOfView\", self:_flag(\"MaxAxisFOV\", 90)) end\
        end\
    end\
\
    -- 3ra persona genérica (best-effort): habilita zoom-out (restaurado en unload).\
    function SelfFX:_thirdPersonGeneric()\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\
        if not plr then return end\
        pcall(function() self:_set(plr, \"CameraMode\", Enum.CameraMode.Classic) end)\
        self:_set(plr, \"CameraMaxZoomDistance\", self:_flag(\"ThirdPersonDistance\", 12))\
    end\
\
    -- fallback genérico (game-agnostic): CC/Blur en Lighting con nombre flash/blind\
    function SelfFX:_genericFlashEffects()\
        local out = {}\
        local L = self.Services.Workspace and game:GetService(\"Lighting\")\
        if not L then return out end\
        for _, e in ipairs(L:GetChildren()) do\
            if (e:IsA(\"ColorCorrectionEffect\") or e:IsA(\"BlurEffect\")) then\
                local n = string.lower(e.Name)\
                if n:find(\"flash\") or n:find(\"blind\") then table.insert(out, e) end\
            end\
        end\
        return out\
    end\
\
    -- Anti-flash / anti-smoke. Usa hooks del perfil si existen; si no, fallback genérico.\
    function SelfFX:_applyAntiFlash()\
        if self:_flag(\"AntiFlash\", false) then\
            local list\
            if self._provider and self._provider.flashEffects then\
                local ok, r = pcall(self._provider.flashEffects); list = ok and r or nil\
            else\
                list = self:_genericFlashEffects()\
            end\
            if list then for _, e in ipairs(list) do self:_set(e, \"Enabled\", false) end end\
        end\
        if self:_flag(\"AntiSmoke\", false) and self._provider and self._provider.smokeEffects then\
            local ok, list = pcall(self._provider.smokeEffects)\
            if ok and list then for _, e in ipairs(list) do self:_set(e, \"Enabled\", false) end end\
        end\
    end\
\
    -- Self-chams (Highlight sobre el char propio, detectable)\
    function SelfFX:_applySelfChams(t)\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\
        local char = plr and plr.Character\
        if not self:_flag(\"SelfChams\", false) or not char then\
            local h = self.Highlights[\"self\"]; if h then h.Enabled = false end\
            return\
        end\
        local h = self.Highlights[\"self\"]\
        if not h or not h.Parent then\
            h = Instance.new(\"Highlight\"); h.Name = \"LC\"; h.Parent = self.Services.Workspace.CurrentCamera\
            self.Highlights[\"self\"] = h\
        end\
        h.Adornee = char; h.Enabled = true\
        h.FillColor = GV.Color.fade(self.Flags, \"Local_SelfChamsFill\", t)\
        h.OutlineColor = GV.Color.fade(self.Flags, \"Local_SelfChamsOutline\", t)\
        h.FillTransparency = self:_flag(\"SelfChamsFillTransparency\", 0.5)\
    end\
\
    -- Crosshair (Drawing centrado en pantalla)\
    function SelfFX:_makeCrosshair()\
        if self._cross then return self._cross end\
        self._cross = {\
            top = self:_draw(\"Line\", { Thickness = 1 }),\
            bottom = self:_draw(\"Line\", { Thickness = 1 }),\
            left = self:_draw(\"Line\", { Thickness = 1 }),\
            right = self:_draw(\"Line\", { Thickness = 1 }),\
            dot = self:_draw(\"Square\", { Filled = true }),\
            circle = self:_draw(\"Circle\", { Filled = false, NumSides = 32 }),\
        }\
        return self._cross\
    end\
\
    function SelfFX:_applyCrosshair(t)\
        local c = self:_makeCrosshair()\
        for _, o in pairs(c) do o.Visible = false end\
        if not self:_flag(\"Crosshair\", false) then return end\
        local cam = self.Services.Workspace.CurrentCamera\
        if not cam then return end\
        local vp = cam.ViewportSize\
        local cx, cy = vp.X / 2, vp.Y / 2\
        local col = GV.Color.fade(self.Flags, \"Local_CrosshairColor\", t)\
        local style = self:_flag(\"CrosshairStyle\", \"Cross\")\
        local gap = self:_flag(\"CrosshairGap\", 4)\
        local size = self:_flag(\"CrosshairSize\", 10)\
        local th = self:_flag(\"CrosshairThickness\", 1)\
        local function line(o, fx, fy, tx, ty)\
            o.Visible = true; o.From = Vector2.new(fx, fy); o.To = Vector2.new(tx, ty); o.Color = col; o.Thickness = th; o.ZIndex = 10\
        end\
        if style == \"Cross\" or style == \"T\" then\
            line(c.left, cx - gap - size, cy, cx - gap, cy)\
            line(c.right, cx + gap, cy, cx + gap + size, cy)\
            line(c.bottom, cx, cy + gap, cx, cy + gap + size)\
            if style == \"Cross\" then line(c.top, cx, cy - gap - size, cx, cy - gap) end\
        elseif style == \"Dot\" then\
            local d = math.max(2, size / 3)\
            c.dot.Visible = true; c.dot.Size = Vector2.new(d, d); c.dot.Position = Vector2.new(cx - d / 2, cy - d / 2); c.dot.Color = col; c.dot.ZIndex = 10\
        elseif style == \"Circle\" then\
            c.circle.Visible = true; c.circle.Position = Vector2.new(cx, cy); c.circle.Radius = size; c.circle.Color = col; c.circle.Thickness = th; c.circle.ZIndex = 10\
        end\
    end\
\
    -- HUD: watermark + hitmarker + keybind-list\
    function SelfFX:_makeHUD()\
        if self._hud then return self._hud end\
        self._hud = {\
            wm = self:_draw(\"Text\", { Outline = true, Size = 14, Font = 2 }),\
            kb = {},\
            hit = { self:_draw(\"Line\", { Thickness = 2 }), self:_draw(\"Line\", { Thickness = 2 }),\
                self:_draw(\"Line\", { Thickness = 2 }), self:_draw(\"Line\", { Thickness = 2 }) },\
        }\
        return self._hud\
    end\
\
    function SelfFX:_applyWatermark(t)\
        local hud = self:_makeHUD()\
        hud.wm.Visible = self:_flag(\"Watermark\", false)\
        if not hud.wm.Visible then return end\
        local parts = {}\
        if self:_flag(\"WM_Title\", true) then table.insert(parts, \"Visuals\") end\
        if self:_flag(\"WM_FPS\", true) then table.insert(parts, (self._fps or 0) .. \" fps\") end\
        if self:_flag(\"WM_Ping\", true) then\
            local ok, p = pcall(function() return math.floor(self.Services.Stats.Network.ServerStatsItem[\"Data Ping\"]:GetValue()) end)\
            if ok then table.insert(parts, p .. \" ms\") end\
        end\
        if self:_flag(\"WM_Name\", true) then\
            local ok, n = pcall(function() return self.Services.Players.LocalPlayer.Name end)\
            if ok and n then table.insert(parts, n) end\
        end\
        if self:_flag(\"WM_Time\", false) then\
            local ok, ts = pcall(function() return os.date(\"%H:%M:%S\") end); if ok then table.insert(parts, ts) end\
        end\
        if #parts == 0 then parts[1] = \"Visuals\" end\
        hud.wm.Text = table.concat(parts, \" | \")\
        hud.wm.Color = GV.Color.fade(self.Flags, \"Local_WatermarkColor\", t)\
        hud.wm.Position = Vector2.new(self:_flag(\"WatermarkX\", 10), self:_flag(\"WatermarkY\", 8))\
        hud.wm.ZIndex = 10\
    end\
\
    function SelfFX:_applyHitmarker(t)\
        local hud = self:_makeHUD()\
        local active = self:_flag(\"Hitmarker\", false) and self._hitUntil and tick() < self._hitUntil\
        for _, l in ipairs(hud.hit) do l.Visible = active end\
        if not active then return end\
        local cam = self.Services.Workspace.CurrentCamera; if not cam then return end\
        local vp = cam.ViewportSize; local cx, cy = vp.X / 2, vp.Y / 2\
        local gap = self:_flag(\"HitmarkerGap\", 4); local size = self:_flag(\"HitmarkerSize\", 8)\
        local col = GV.Color.fade(self.Flags, \"Local_HitmarkerColor\", t)\
        local segs = {\
            { cx - gap - size, cy - gap - size, cx - gap, cy - gap },\
            { cx + gap, cy - gap, cx + gap + size, cy - gap - size },\
            { cx - gap - size, cy + gap + size, cx - gap, cy + gap },\
            { cx + gap, cy + gap, cx + gap + size, cy + gap + size },\
        }\
        for i, l in ipairs(hud.hit) do\
            local s = segs[i]; l.From = Vector2.new(s[1], s[2]); l.To = Vector2.new(s[3], s[4]); l.Color = col; l.ZIndex = 11\
        end\
    end\
\
    function SelfFX:_applyKeybindList(t)\
        local hud = self:_makeHUD()\
        for _, l in ipairs(hud.kb) do l.Visible = false end\
        if not self:_flag(\"KeybindList\", false) then return end\
        local list = self._provider and self._provider.keybinds and self._provider.keybinds() or {}\
        local col = GV.Color.fade(self.Flags, \"Local_KeybindColor\", t)\
        local x, y = self:_flag(\"KeybindX\", 10), self:_flag(\"KeybindY\", 120)\
        for i, kb in ipairs(list) do\
            local o = hud.kb[i]\
            if not o then o = self:_draw(\"Text\", { Outline = true, Size = 13, Font = 2 }); hud.kb[i] = o end\
            o.Visible = true; o.Text = (kb.name or \"?\") .. \": \" .. tostring(kb.key or \"?\")\
            o.Color = col; o.Position = Vector2.new(x, y + (i - 1) * 15); o.ZIndex = 10\
        end\
    end\
\
    function SelfFX:_off()\
        self._wasOn = false\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false end) end\
        for _, h in pairs(self.Highlights) do pcall(function() h.Enabled = false end) end\
        self:_restoreAll()\
    end\
\
    function SelfFX:_update()\
        if not self:_flag(\"Enabled\", false) then\
            if self._wasOn then self:_off() end\
            return\
        end\
        self._wasOn = true\
        local now = tick()\
        if self._lastT then self._fps = math.floor(1 / math.max(1e-3, now - self._lastT) + 0.5) end\
        self._lastT = now\
        self:_applyCamera()\
        self:_applyCrosshair(now)\
        self:_applyWatermark(now)\
        self:_applyHitmarker(now)\
        self:_applyKeybindList(now)\
        self:_applyAntiFlash()\
        self:_applySelfChams(now)\
    end\
\
    function SelfFX:Init()\
        if self.Loaded then return self end\
        self.Loaded = true\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\
            local ok, err = pcall(function() self:_update() end)\
            if not ok then warn(\"[SelfFX] \" .. tostring(err)) end\
        end)\
        if self._provider and self._provider.hitSignal then\
            local ok, conn = pcall(function()\
                return self._provider.hitSignal:Connect(function()\
                    self._hitUntil = tick() + self:_flag(\"HitmarkerDuration\", 0.3)\
                end)\
            end)\
            if ok and conn then self.Conns[#self.Conns + 1] = conn end\
        end\
        return self\
    end\
\
    function SelfFX:Unload()\
        self.Loaded = false\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\
        for _, h in pairs(self.Highlights) do pcall(function() h:Destroy() end) end\
        self:_restoreAll()\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self.Highlights); table.clear(self._made)\
    end\
\
    GV.SelfFX = SelfFX\
    GV.Modules = GV.Modules or {}\
    GV.Modules.selffx = GV.Modules.selffx or {}\
    GV.Modules.selffx.new = function(o) return SelfFX.new(o) end\
end\
"
local f = loadstring(chunk, '@core/selffx.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local F = {}\
    F.KINDS = { \"toggle\", \"slider\", \"dropdown\", \"colorpicker\", \"label\", \"textbox\", \"button\" }\
    F.METHODS = { \"Tab\", \"Group\", \"Widget\", \"Depend\" }\
    function F.validate(adapter)\
        local missing = {}\
        for _, m in ipairs(F.METHODS) do\
            if type(adapter[m]) ~= \"function\" then table.insert(missing, m) end\
        end\
        return #missing == 0, missing\
    end\
    GV.Facade = F\
end\
"
local f = loadstring(chunk, '@ui/facade.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local R = {}\
    local KIND_KEYS = { \"Text\", \"Default\", \"Min\", \"Max\", \"Decimals\", \"Suffix\", \"Values\", \"Multi\",\
        \"Searchable\", \"Tooltip\", \"Header\", \"Placeholder\", \"Numeric\", \"Keybind\", \"OffAtMin\" }\
\
    function R.build(adapter, window, schema, world)\
        assert(GV.Facade.validate(adapter))\
        local handles, byFlag = {}, {}\
        local curTabName, curTab, curKey, curGroup\
        for _, row in ipairs(schema) do\
            if row.tab ~= curTabName then\
                curTab = adapter.Tab(window, row.tab, row.icon); curTabName = row.tab; curKey = nil\
            end\
            local gk = row.tab .. \"|\" .. row.group .. \"|\" .. (row.side or \"Left\")\
            if gk ~= curKey then\
                curGroup = adapter.Group(curTab, row.group, row.side or \"Left\"); curKey = gk\
            end\
            -- opts desde la fila\
            local opts = {}\
            for _, k in ipairs(KIND_KEYS) do\
                local sk = k:lower()\
                if row[sk] ~= nil then opts[k] = row[sk] end\
            end\
            if row.text then opts.Text = row.text end\
            -- seed del flag + default\
            if row.flag and world.Flags[row.flag] == nil and row.default ~= nil then\
                world.Flags[row.flag] = row.default\
            end\
            if row.flag then opts.Default = world.Flags[row.flag] end\
            if row.type ~= \"label\" and row.type ~= \"button\" and row.flag then\
                opts.Callback = function(v) world:Set(row.flag, v) end\
            elseif row.type == \"button\" then\
                opts.Callback = row.action\
            end\
            -- parent para dependencia (ClaudeUI nesting)\
            local parent = row.dependsOn and byFlag[row.dependsOn] or nil\
            local h = adapter.Widget(curGroup, row.type, row.flag, opts, parent)\
            if row.flag then byFlag[row.flag] = h end\
            if row.dependsOn then\
                adapter.Depend(h, row.dependsOn, row.dependsValue == nil and true or row.dependsValue)\
            end\
            table.insert(handles, h)\
        end\
        return handles\
    end\
    GV.Renderer = R\
end\
"
local f = loadstring(chunk, '@ui/renderer.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local Preview = {}\
    local RunService = game:GetService(\"RunService\")\
    local Players = game:GetService(\"Players\")\
    local UIS = game:GetService(\"UserInputService\")\
\
    local function huiParent()\
        local ok, g = pcall(function() return gethui and gethui() end)\
        if ok and g then return g end\
        return game:GetService(\"CoreGui\")\
    end\
\
    function Preview.mount(suite, opts)\
        opts = opts or {}\
        local flags = suite.flags\
        local self = { suite = suite, _made = {}, _conns = {} }\
\
        local gui = Instance.new(\"ScreenGui\")\
        gui.Name = \"PUIpv_\" .. tostring(math.random(1e5, 9e5))\
        gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling\
        gui.Parent = huiParent(); table.insert(self._made, gui)\
\
        local root = Instance.new(\"Frame\")\
        root.Size = UDim2.fromOffset(260, 320)\
        root.Position = UDim2.new(0.5, 440, 0.5, -160)\
        root.BackgroundColor3 = Color3.fromRGB(20, 20, 24); root.BorderSizePixel = 0; root.Parent = gui\
        Instance.new(\"UICorner\", root).CornerRadius = UDim.new(0, 8)\
        local st = Instance.new(\"UIStroke\", root); st.Color = Color3.fromRGB(8, 8, 10); st.Thickness = 1\
        self.Root = root\
\
        local header = Instance.new(\"Frame\"); header.Size = UDim2.new(1, 0, 0, 26)\
        header.BackgroundColor3 = Color3.fromRGB(30, 30, 36); header.BorderSizePixel = 0; header.Parent = root\
        Instance.new(\"UICorner\", header).CornerRadius = UDim.new(0, 8)\
        local title = Instance.new(\"TextLabel\"); title.BackgroundTransparency = 1\
        title.Size = UDim2.new(1, -10, 1, 0); title.Position = UDim2.fromOffset(8, 0)\
        title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.TextColor3 = Color3.fromRGB(202, 151, 161)\
        title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = \"Preview\"; title.Parent = header\
\
        local dragging, sPos, sMouse\
        header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; sPos = root.Position; sMouse = UIS:GetMouseLocation() end end)\
        header.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)\
        table.insert(self._conns, UIS.InputChanged:Connect(function(i)\
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then\
                local d = UIS:GetMouseLocation() - sMouse\
                root.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)\
            end\
        end))\
\
        local vf = Instance.new(\"ViewportFrame\")\
        vf.Position = UDim2.fromOffset(8, 32); vf.Size = UDim2.new(1, -16, 1, -40)\
        vf.BackgroundColor3 = Color3.fromRGB(6, 10, 6); vf.BorderSizePixel = 0\
        vf.Ambient = Color3.fromRGB(170, 170, 175); vf.LightColor = Color3.fromRGB(255, 255, 255)\
        vf.LightDirection = Vector3.new(-0.4, -1, -0.5); vf.Parent = root\
        Instance.new(\"UICorner\", vf).CornerRadius = UDim.new(0, 6)\
        local cam = Instance.new(\"Camera\"); cam.Parent = vf; vf.CurrentCamera = cam\
        local world = Instance.new(\"WorldModel\"); world.Parent = vf\
        self.VF, self.Cam, self.World = vf, cam, world\
\
        -- box overlay (borde ESP representativo, sobre el 3D)\
        local box = Instance.new(\"Frame\"); box.BackgroundTransparency = 1; box.BorderSizePixel = 0\
        box.AnchorPoint = Vector2.new(0.5, 0.5); box.Position = UDim2.new(0.5, 0, 0.5, 6)\
        box.Size = UDim2.fromOffset(66, 150); box.ZIndex = 3; box.Parent = vf\
        local boxStroke = Instance.new(\"UIStroke\", box); boxStroke.Thickness = 1.5; boxStroke.Color = Color3.fromRGB(0, 255, 120)\
        self._box, self._boxStroke = box, boxStroke\
\
        -- matrix rain (columnas verdes low-alpha delante del modelo)\
        self._matrix = {}\
        for i = 1, 10 do\
            local l = Instance.new(\"TextLabel\"); l.BackgroundTransparency = 1; l.Font = Enum.Font.Code\
            l.TextSize = 12; l.TextColor3 = Color3.fromRGB(0, 255, 80); l.TextTransparency = 0.55\
            l.Size = UDim2.fromOffset(12, 220); l.TextYAlignment = Enum.TextYAlignment.Top; l.Text = \"\"\
            l.Position = UDim2.fromScale((i - 0.5) / 10, math.random()); l.ZIndex = 2; l.Parent = vf\
            table.insert(self._matrix, l)\
        end\
\
        function self:SetModel(char)\
            for _, c in ipairs(self.World:GetChildren()) do c:Destroy() end\
            self.Model = nil\
            if not char then return end\
            local m; local prev = char.Archivable; char.Archivable = true\
            pcall(function() m = char:Clone() end); char.Archivable = prev\
            if not m then return end\
            for _, d in ipairs(m:GetDescendants()) do if d:IsA(\"Script\") or d:IsA(\"LocalScript\") then d:Destroy() end end\
            m.Parent = self.World; self.Model = m\
            local ok, cf, size = pcall(function() return m:GetBoundingBox() end)\
            if ok and cf then\
                self._center = cf.Position; self._radius = math.max(size.Magnitude / 2, 1)\
                self._dist = self._radius / math.tan(math.rad(30)) + self._radius\
            end\
            self._angle = 0\
        end\
\
        function self:_apply(a)\
            if not self._center then return end\
            local pos = self._center + Vector3.new(math.sin(a) * self._dist, self._radius * 0.35, math.cos(a) * self._dist)\
            self.Cam.CFrame = CFrame.lookAt(pos, self._center)\
        end\
\
        function self:_step(dt)\
            local show = opts.always or (flags.Suite_Preview and true or false)\
            self.Root.Visible = show\
            if not show or not self.Model then return end\
            self._angle = (self._angle or 0) + math.rad(40) * dt\
            self:_apply(self._angle)\
            local t = tick()\
            -- world lighting -> viewport\
            self.VF.Ambient = GV.Color.fade(flags, \"World_Ambient\", t)\
            self.VF.LightColor = flags.World_Fullbright and Color3.new(1, 1, 1) or Color3.fromRGB(255, 255, 255)\
            -- chams (ESP o self-chams) sobre el clone\
            local chamsOn = flags.ESP_Chams or flags.Local_SelfChams\
            if chamsOn then\
                if not self._chams then self._chams = Instance.new(\"Highlight\"); self._chams.Parent = self.VF; table.insert(self._made, self._chams) end\
                self._chams.Adornee = self.Model; self._chams.Enabled = true\
                local isSelf = flags.Local_SelfChams and true or false\
                self._chams.FillColor = GV.Color.fade(flags, isSelf and \"Local_SelfChamsFill\" or \"ESP_ChamsFill\", t)\
                self._chams.OutlineColor = GV.Color.fade(flags, isSelf and \"Local_SelfChamsOutline\" or \"ESP_ChamsOutline\", t)\
            elseif self._chams then self._chams.Enabled = false end\
            -- box overlay color (representativo)\
            self._box.Visible = flags.ESP_Box ~= false\
            self._boxStroke.Color = GV.Color.fade(flags, \"ESP_BoxColor\", t)\
            -- matrix rain\
            for i, l in ipairs(self._matrix) do\
                local y = (l.Position.Y.Scale + dt * (0.15 + (i % 3) * 0.08)) % 1.3 - 0.3\
                l.Position = UDim2.fromScale(l.Position.X.Scale, y)\
                if math.floor(t * 6 + i) % 3 == 0 then\
                    local s = {}; for k = 1, 9 do s[k] = string.char(48 + (i * 7 + k * 3) % 10) end\
                    l.Text = table.concat(s, \"\\n\")\
                end\
            end\
        end\
\
        table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)\
            local ok, err = pcall(function() self:_step(dt) end); if not ok then warn(\"[Preview] \" .. tostring(err)) end\
        end))\
\
        function self:Unload()\
            for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end\
            for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\
            table.clear(self._conns); table.clear(self._made)\
        end\
\
        local lp = Players.LocalPlayer\
        if lp and lp.Character then self:SetModel(lp.Character) end\
        return self\
    end\
    GV.Preview = Preview\
end\
"
local f = loadstring(chunk, '@ui/preview.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    GV.Adapters = GV.Adapters or {}\r\
    local A = {}\r\
    local ADD = { toggle = \"AddToggle\", slider = \"AddSlider\", dropdown = \"AddDropdown\",\r\
        colorpicker = \"AddColorPicker\", label = \"AddLabel\", textbox = \"AddTextBox\", button = \"AddButton\" }\r\
\r\
    function A.Tab(window, name, icon)\r\
        local cat = window:AddCategory(name, icon)\r\
        local sec = cat:AddSection(name)\r\
        return { cat = cat, sec = sec }\r\
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
\r\
    A.supportsPreview = true -- Primordial es instance-based -> puede montar el preview viewport\r\
    GV.Adapters.primordial = A\r\
end\r\
"
local f = loadstring(chunk, '@ui/adapter_primordial.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local H = {}\r\
    -- expande una spec de color a 3 filas (cp base, fade toggle, cp2 dep del fade)\r\
    function H.CF(spec)\r\
        local base = spec.base\r\
        local function row(t)\r\
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side\r\
            return t\r\
        end\r\
        return {\r\
            row{ flag = base, type = \"colorpicker\", text = spec.text, default = spec.default, dependsOn = spec.dependsOn },\r\
            row{ flag = base .. \"_Fade\", type = \"toggle\", text = (spec.text or \"\") .. \" fade\", default = false, dependsOn = spec.dependsOn },\r\
            row{ flag = base .. \"_2\", type = \"colorpicker\", text = (spec.text or \"\") .. \" color 2\", default = spec.default2 or spec.default, dependsOn = base .. \"_Fade\" },\r\
        }\r\
    end\r\
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end\r\
    function H.suiteRows()\r\
        return {\r\
            { tab = \"Mundo\", group = \"Suite\", side = \"Left\", flag = \"Suite_FadeSpeed\", type = \"slider\",\r\
                text = \"Velocidad fade\", min = 0.1, max = 5, default = 1, decimals = 2 },\r\
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
do local chunk = "return function(GV)\
    local C = Color3.fromRGB\
    local ACC = C(96, 130, 255) -- default2 sugerido para fades\
    local S = {}\
    local function add(r) table.insert(S, r) end\
    local function addCF(spec)\
        spec.default2 = spec.default2 or ACC\
        GV.pushCF(S, spec)\
    end\
\
    -- ================= Tab \"Mundo\" =================\
    -- A. Lighting\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Enabled\", type = \"toggle\", text = \"Enable visuales\", default = false, keybind = true, master = true }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Fullbright\", type = \"toggle\", text = \"Fullbright\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_NoShadows\", type = \"toggle\", text = \"Sin sombras\", default = false, dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_Ambient\", text = \"Ambient\", tab = \"Mundo\", group = \"Lighting\", side = \"Left\", default = C(120, 120, 125), dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_OutdoorAmbient\", text = \"Outdoor ambient\", tab = \"Mundo\", group = \"Lighting\", side = \"Left\", default = C(120, 120, 125), dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Brightness\", type = \"slider\", text = \"Brillo\", min = 0, max = 10, default = 3, decimals = 1, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Exposure\", type = \"slider\", text = \"Exposicion\", min = -3, max = 3, default = 0, decimals = 2, dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_ColorShiftTop\", text = \"ColorShift Top\", tab = \"Mundo\", group = \"Lighting\", side = \"Left\", default = C(0, 0, 0), dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_ColorShiftBottom\", text = \"ColorShift Bottom\", tab = \"Mundo\", group = \"Lighting\", side = \"Left\", default = C(0, 0, 0), dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvDiffuse\", type = \"slider\", text = \"Env diffuse\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvSpecular\", type = \"slider\", text = \"Env specular\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Technology\", type = \"dropdown\", text = \"Technology\", values = { \"\", \"Voxel\", \"ShadowMap\", \"Future\", \"Legacy\" }, default = \"\", dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_GeoLatitude\", type = \"slider\", text = \"Latitud geo\", min = -90, max = 90, default = 41.7, decimals = 1, dependsOn = \"World_Enabled\" }\
    -- B. Tiempo / Sol\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_ClockTime\", type = \"slider\", text = \"Hora del dia\", min = 0, max = 24, default = 12, decimals = 1, suffix = \"h\", dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_UseTimeOfDay\", type = \"toggle\", text = \"Usar TimeOfDay\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_FreezeTime\", type = \"toggle\", text = \"Congelar tiempo\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_DayNightCycle\", type = \"toggle\", text = \"Ciclo dia/noche\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_CycleSpeed\", type = \"slider\", text = \"Velocidad ciclo\", min = 0.1, max = 10, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_DayNightCycle\" }\
    -- C. Fog\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_NoFog\", type = \"toggle\", text = \"Sin fog\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogStart\", type = \"slider\", text = \"Fog inicio\", min = 0, max = 2000, default = 0, suffix = \"st\", dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogEnd\", type = \"slider\", text = \"Fog fin\", min = 100, max = 10000, default = 2500, suffix = \"st\", dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_FogColor\", text = \"Color fog\", tab = \"Mundo\", group = \"Fog\", side = \"Right\", default = C(190, 195, 210), dependsOn = \"World_Enabled\" }\
    -- D. Atmosphere\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_Atmosphere\", type = \"toggle\", text = \"Atmosfera (reemplaza fog)\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.3, decimals = 3, dependsOn = \"World_Atmosphere\" }\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmOffset\", type = \"slider\", text = \"Offset\", min = 0, max = 1, default = 0.25, decimals = 2, dependsOn = \"World_Atmosphere\" }\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmGlare\", type = \"slider\", text = \"Glare\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" }\
    add{ tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmHaze\", type = \"slider\", text = \"Haze\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" }\
    addCF{ base = \"World_AtmColor\", text = \"Color\", tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", default = C(199, 199, 199), dependsOn = \"World_Atmosphere\" }\
    addCF{ base = \"World_AtmDecay\", text = \"Decay\", tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", default = C(106, 112, 125), dependsOn = \"World_Atmosphere\" }\
    -- E. Post-FX\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Tint\", type = \"toggle\", text = \"Tinte (ColorCorrection)\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintBrightness\", type = \"slider\", text = \"Brillo\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintContrast\", type = \"slider\", text = \"Contraste\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintSaturation\", type = \"slider\", text = \"Saturacion\", min = -1, max = 3, default = 0, decimals = 2, dependsOn = \"World_Tint\" }\
    addCF{ base = \"World_TintColor\", text = \"Color tinte\", tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", default = C(255, 255, 255), dependsOn = \"World_Tint\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowHue\", type = \"toggle\", text = \"Rainbow hue\", default = false, dependsOn = \"World_Tint\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowSpeed\", type = \"slider\", text = \"Rainbow vel\", min = 0.05, max = 5, default = 1, decimals = 2, dependsOn = \"World_RainbowHue\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Bloom\", type = \"toggle\", text = \"Bloom\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 5, default = 0.4, decimals = 2, dependsOn = \"World_Bloom\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomSize\", type = \"slider\", text = \"Tamano\", min = 0, max = 56, default = 24, dependsOn = \"World_Bloom\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomThreshold\", type = \"slider\", text = \"Umbral\", min = 0, max = 3, default = 0.95, decimals = 2, dependsOn = \"World_Bloom\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRays\", type = \"toggle\", text = \"Rayos de sol\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 1, default = 0.05, decimals = 3, dependsOn = \"World_SunRays\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysSpread\", type = \"slider\", text = \"Dispersion\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_SunRays\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoF\", type = \"toggle\", text = \"Depth of Field\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFocus\", type = \"slider\", text = \"Foco\", min = 0, max = 500, default = 25, dependsOn = \"World_DoF\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFRadius\", type = \"slider\", text = \"Radio foco\", min = 0, max = 100, default = 10, dependsOn = \"World_DoF\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFNear\", type = \"slider\", text = \"Near\", min = 0, max = 1, default = 0, decimals = 2, dependsOn = \"World_DoF\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFar\", type = \"slider\", text = \"Far\", min = 0, max = 1, default = 0.75, decimals = 2, dependsOn = \"World_DoF\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlur\", type = \"toggle\", text = \"Blur mundo\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlurSize\", type = \"slider\", text = \"Fuerza\", min = 0, max = 40, default = 12, dependsOn = \"World_WorldBlur\" }\
    add{ tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_KillGamePostFX\", type = \"toggle\", text = \"Matar post-FX del juego\", default = false, dependsOn = \"World_Enabled\" }\
    -- J. Visibilidad\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_Advanced\", type = \"toggle\", text = \"Avanzado (agresivo)\", default = false, dependsOn = \"World_Enabled\", tooltip = \"Toca el mapa; usar con criterio\" }\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_KillParticles\", type = \"toggle\", text = \"Matar particulas del mapa\", default = false, dependsOn = \"World_Advanced\" }\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_ForceSmoothPlastic\", type = \"toggle\", text = \"Forzar SmoothPlastic\", default = false, dependsOn = \"World_Advanced\" }\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparent\", type = \"toggle\", text = \"Mapa transparente\", default = false, dependsOn = \"World_Advanced\" }\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparentAmount\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.6, decimals = 2, dependsOn = \"World_MapTransparent\" }\
    add{ tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_NoTextures\", type = \"toggle\", text = \"Sin texturas/decals\", default = false, dependsOn = \"World_Advanced\" }\
    -- ================= Tab \"Cielo & Clima\" =================\
    -- F. Cielo\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_NoSky\", type = \"toggle\", text = \"Sin cuerpos celestes\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_StarCount\", type = \"slider\", text = \"Estrellas\", min = 0, max = 5000, default = 3000, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_CustomSkybox\", type = \"toggle\", text = \"Skybox custom\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Up\", type = \"textbox\", text = \"Up\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Dn\", type = \"textbox\", text = \"Down\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Lf\", type = \"textbox\", text = \"Left\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Rt\", type = \"textbox\", text = \"Right\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Bk\", type = \"textbox\", text = \"Back\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Ft\", type = \"textbox\", text = \"Front\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunTextureId\", type = \"textbox\", text = \"Sol textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonTextureId\", type = \"textbox\", text = \"Luna textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunAngularSize\", type = \"slider\", text = \"Sol tamano\", min = 0, max = 90, default = 21, dependsOn = \"World_CustomSkybox\" }\
    add{ tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonAngularSize\", type = \"slider\", text = \"Luna tamano\", min = 0, max = 90, default = 11, dependsOn = \"World_CustomSkybox\" }\
    -- G. Nubes\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_Clouds\", type = \"toggle\", text = \"Nubes custom\", default = false, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_NoClouds\", type = \"toggle\", text = \"Sin nubes\", default = false, dependsOn = \"World_Clouds\" }\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudCover\", type = \"slider\", text = \"Cobertura\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_Clouds\" }\
    add{ tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.7, decimals = 2, dependsOn = \"World_Clouds\" }\
    addCF{ base = \"World_CloudColor\", text = \"Color nubes\", tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", default = C(255, 255, 255), dependsOn = \"World_Clouds\" }\
    -- H. Terrain / Agua\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterEnable\", type = \"toggle\", text = \"Editar agua\", default = false, dependsOn = \"World_Enabled\" }\
    addCF{ base = \"World_WaterColor\", text = \"Color agua\", tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", default = C(12, 84, 92), dependsOn = \"World_WaterEnable\" }\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.3, decimals = 2, dependsOn = \"World_WaterEnable\" }\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterReflectance\", type = \"slider\", text = \"Reflectancia\", min = 0, max = 1, default = 1, decimals = 2, dependsOn = \"World_WaterEnable\" }\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSize\", type = \"slider\", text = \"Olas tamano\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_WaterEnable\" }\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSpeed\", type = \"slider\", text = \"Olas velocidad\", min = 0, max = 20, default = 10, decimals = 1, dependsOn = \"World_WaterEnable\" }\
    add{ tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_TerrainDecoration\", type = \"toggle\", text = \"Decoracion terrain\", default = true, dependsOn = \"World_WaterEnable\" }\
    -- I. Clima\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Weather\", type = \"toggle\", text = \"Clima\", default = false, keybind = true, dependsOn = \"World_Enabled\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherMode\", type = \"dropdown\", text = \"Tipo\", values = { \"Lluvia\", \"Lluvia fuerte\", \"Nieve\", \"Niebla\", \"Ceniza\", \"Luciérnagas\", \"Custom\" }, default = \"Lluvia\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherCustomTex\", type = \"textbox\", text = \"Textura custom\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_Weather\" }\
    addCF{ base = \"World_WeatherColor\", text = \"Color\", tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", default = C(220, 230, 255), dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherGlow\", type = \"slider\", text = \"Brillo propio\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherDensity\", type = \"slider\", text = \"Densidad\", min = 0.1, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSpeed\", type = \"slider\", text = \"Velocidad\", min = 0.1, max = 3, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSize\", type = \"slider\", text = \"Tamano\", min = 0.2, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherArea\", type = \"slider\", text = \"Area\", min = 30, max = 200, default = 90, suffix = \"st\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherWindDir\", type = \"slider\", text = \"Viento (dir)\", min = 0, max = 360, default = 0, suffix = \"deg\", dependsOn = \"World_Weather\" }\
    add{ tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Lightning\", type = \"toggle\", text = \"Relampagos\", default = false, dependsOn = \"World_Weather\" }\
    -- K. Presets\
    add{ tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", flag = \"World_PresetSelect\", type = \"dropdown\", text = \"Preset\", values = { \"Competitivo\", \"Cinematográfico\", \"Día\", \"Noche\", \"Atardecer\", \"Niebla\" }, default = \"Competitivo\", dependsOn = \"World_Enabled\" }\
\
    GV.Schema = S\
    GV.Modules = GV.Modules or {}\
    GV.Modules.world = GV.Modules.world or {}\
    GV.Modules.world.schema = S\
end\
"
local f = loadstring(chunk, '@schema/world.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local C = Color3.fromRGB\
    local ACC = C(96, 130, 255)\
    local S = {}\
    local function add(r) table.insert(S, r) end\
    local function addCF(spec) spec.default2 = spec.default2 or ACC; GV.pushCF(S, spec) end\
    local TAB, TC = \"ESP\", \"ESP Colores\"\
\
    -- ===== Tab ESP =====\
    -- General (Left)\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Enabled\", type = \"toggle\", text = \"Enable ESP\", default = false, keybind = true, master = true }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Box\", type = \"toggle\", text = \"Box\", default = true, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxFilled\", type = \"toggle\", text = \"Box relleno\", default = false, dependsOn = \"ESP_Box\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxOutline\", type = \"toggle\", text = \"Box contorno\", default = true, dependsOn = \"ESP_Box\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_BoxThickness\", type = \"slider\", text = \"Box grosor\", min = 1, max = 5, default = 1, dependsOn = \"ESP_Box\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Name\", type = \"toggle\", text = \"Nombre\", default = true, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Distance\", type = \"toggle\", text = \"Distancia\", default = true, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_Health\", type = \"toggle\", text = \"Vida\", default = true, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"ESP_HealthStyle\", type = \"dropdown\", text = \"Vida estilo\", values = { \"Barra\", \"Numero\", \"Barra+Numero\" }, default = \"Barra\", dependsOn = \"ESP_Health\" }\
    -- Extras (Left)\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_Skeleton\", type = \"toggle\", text = \"Esqueleto\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_HeadDot\", type = \"toggle\", text = \"Head dot\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_HeadDotRadius\", type = \"slider\", text = \"Head dot radio\", min = 1, max = 12, default = 3, dependsOn = \"ESP_HeadDot\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_LookDir\", type = \"toggle\", text = \"Direccion de mira\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_LookLength\", type = \"slider\", text = \"Mira largo\", min = 1, max = 10, default = 2, decimals = 1, dependsOn = \"ESP_LookDir\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_Tracer\", type = \"toggle\", text = \"Tracer\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_TracerFrom\", type = \"dropdown\", text = \"Tracer origen\", values = { \"Bottom\", \"Center\", \"Top\", \"Mouse\" }, default = \"Bottom\", dependsOn = \"ESP_Tracer\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreen\", type = \"toggle\", text = \"Flechas off-screen\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreenRadius\", type = \"slider\", text = \"Off-screen radio\", min = 50, max = 400, default = 200, dependsOn = \"ESP_OffScreen\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"ESP_OffScreenSize\", type = \"slider\", text = \"Off-screen tamano\", min = 6, max = 40, default = 16, dependsOn = \"ESP_OffScreen\" }\
    -- Chams (Right, detectable)\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", type = \"label\", text = \"Chams usa Highlight = INSTANCIA detectable\" }\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_Chams\", type = \"toggle\", text = \"Chams\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsDepthMode\", type = \"dropdown\", text = \"Depth\", values = { \"AlwaysOnTop\", \"Occluded\" }, default = \"AlwaysOnTop\", dependsOn = \"ESP_Chams\" }\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsFillTransparency\", type = \"slider\", text = \"Fill transp\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"ESP_Chams\" }\
    add{ tab = TAB, group = \"Chams (detectable)\", side = \"Right\", flag = \"ESP_ChamsOutlineTransparency\", type = \"slider\", text = \"Outline transp\", min = 0, max = 1, default = 0, decimals = 2, dependsOn = \"ESP_Chams\" }\
    -- Color / Visibilidad (Right)\
    add{ tab = TAB, group = \"Color / Visibilidad\", side = \"Right\", flag = \"ESP_ColorMode\", type = \"dropdown\", text = \"Modo de color\", values = { \"Fijo\", \"Team\", \"Visibilidad\", \"Distancia\" }, default = \"Fijo\", dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Color / Visibilidad\", side = \"Right\", flag = \"ESP_VisibleCheck\", type = \"toggle\", text = \"Chequeo de visibilidad (raycast)\", default = false, dependsOn = \"ESP_Enabled\" }\
    -- Filtros (Right)\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_MaxDistance\", type = \"slider\", text = \"Distancia max\", min = 50, max = 5000, default = 1200, suffix = \"st\", dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_PlayersOnly\", type = \"toggle\", text = \"Solo jugadores\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_TeamCheck\", type = \"toggle\", text = \"Team check\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_DeadCheck\", type = \"toggle\", text = \"Ocultar muertos\", default = true, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Filtros\", side = \"Right\", flag = \"ESP_MaxTargets\", type = \"slider\", text = \"Targets max\", min = 1, max = 100, default = 50, dependsOn = \"ESP_Enabled\" }\
    -- Object ESP + Prefs (Right)\
    add{ tab = TAB, group = \"Object ESP\", side = \"Right\", flag = \"ESP_Objects\", type = \"toggle\", text = \"Object ESP (perfil)\", default = false, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Prefs\", side = \"Right\", flag = \"ESP_Font\", type = \"slider\", text = \"Fuente\", min = 0, max = 3, default = 2, dependsOn = \"ESP_Enabled\" }\
    add{ tab = TAB, group = \"Prefs\", side = \"Right\", flag = \"ESP_TextSize\", type = \"slider\", text = \"Texto tamano\", min = 8, max = 24, default = 13, dependsOn = \"ESP_Enabled\" }\
\
    -- ===== Tab ESP Colores (todos CF) =====\
    addCF{ base = \"ESP_BoxColor\", text = \"Box\", tab = TC, group = \"Colores\", side = \"Left\", default = C(235, 235, 240), dependsOn = \"ESP_Box\" }\
    addCF{ base = \"ESP_NameColor\", text = \"Nombre\", tab = TC, group = \"Colores\", side = \"Left\", default = C(235, 235, 240), dependsOn = \"ESP_Name\" }\
    addCF{ base = \"ESP_TracerColor\", text = \"Tracer\", tab = TC, group = \"Colores\", side = \"Left\", default = C(96, 130, 255), dependsOn = \"ESP_Tracer\" }\
    addCF{ base = \"ESP_SkeletonColor\", text = \"Esqueleto\", tab = TC, group = \"Colores\", side = \"Left\", default = C(200, 200, 210), dependsOn = \"ESP_Skeleton\" }\
    addCF{ base = \"ESP_HeadDotColor\", text = \"Head dot\", tab = TC, group = \"Colores\", side = \"Left\", default = C(255, 80, 80), dependsOn = \"ESP_HeadDot\" }\
    addCF{ base = \"ESP_LookDirColor\", text = \"Direccion de mira\", tab = TC, group = \"Colores\", side = \"Right\", default = C(255, 255, 120), dependsOn = \"ESP_LookDir\" }\
    addCF{ base = \"ESP_OffScreenColor\", text = \"Off-screen\", tab = TC, group = \"Colores\", side = \"Right\", default = C(255, 170, 60), dependsOn = \"ESP_OffScreen\" }\
    addCF{ base = \"ESP_ChamsFill\", text = \"Chams fill\", tab = TC, group = \"Chams\", side = \"Right\", default = C(120, 60, 200), dependsOn = \"ESP_Chams\" }\
    addCF{ base = \"ESP_ChamsOutline\", text = \"Chams outline\", tab = TC, group = \"Chams\", side = \"Right\", default = C(200, 160, 255), dependsOn = \"ESP_Chams\" }\
    addCF{ base = \"ESP_VisibleColor\", text = \"Visible\", tab = TC, group = \"Visibilidad\", side = \"Right\", default = C(64, 200, 96), dependsOn = \"ESP_VisibleCheck\" }\
    addCF{ base = \"ESP_HiddenColor\", text = \"Oculto\", tab = TC, group = \"Visibilidad\", side = \"Right\", default = C(235, 64, 52), dependsOn = \"ESP_VisibleCheck\" }\
    addCF{ base = \"ESP_ObjectColor\", text = \"Objetos\", tab = TC, group = \"Colores\", side = \"Right\", default = C(255, 220, 90), dependsOn = \"ESP_Objects\" }\
\
    GV.Modules = GV.Modules or {}\
    GV.Modules.esp = GV.Modules.esp or {}\
    GV.Modules.esp.schema = S\
end\
"
local f = loadstring(chunk, '@schema/esp.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local C = Color3.fromRGB\
    local S = {}\
    local function add(r) table.insert(S, r) end\
    local function addCF(spec) spec.default2 = spec.default2 or C(96, 130, 255); GV.pushCF(S, spec) end\
    local TAB, TC = \"Local\", \"Local Colores\"\
\
    -- ===== Tab Local =====\
    -- Camara (Left)\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_Enabled\", type = \"toggle\", text = \"Enable Local\", default = false, keybind = true, master = true }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOV\", type = \"toggle\", text = \"FOV changer\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOVValue\", type = \"slider\", text = \"FOV\", min = 40, max = 120, default = 70, dependsOn = \"Local_FOV\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPerson\", type = \"toggle\", text = \"3ra persona\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPersonDistance\", type = \"slider\", text = \"3ra persona distancia\", min = 5, max = 30, default = 12, dependsOn = \"Local_ThirdPerson\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_AspectMode\", type = \"dropdown\", text = \"Aspect (FieldOfViewMode)\", values = { \"Off\", \"Vertical\", \"Diagonal\", \"MaxAxis\" }, default = \"Off\", dependsOn = \"Local_Enabled\", tooltip = \"Stretch pixel-real requiere executor que permita escribir ViewportSize\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_MaxAxisFOV\", type = \"slider\", text = \"MaxAxis FOV\", min = 40, max = 120, default = 90, dependsOn = \"Local_AspectMode\" }\
    -- Crosshair (Left)\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_Crosshair\", type = \"toggle\", text = \"Crosshair\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairStyle\", type = \"dropdown\", text = \"Estilo\", values = { \"Cross\", \"Dot\", \"Circle\", \"T\" }, default = \"Cross\", dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 40, default = 10, dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Left\", flag = \"Local_CrosshairThickness\", type = \"slider\", text = \"Grosor\", min = 1, max = 6, default = 1, dependsOn = \"Local_Crosshair\" }\
    -- Hitmarker (Right)\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_Hitmarker\", type = \"toggle\", text = \"Hitmarker (necesita hitSignal del perfil)\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 30, default = 8, dependsOn = \"Local_Hitmarker\" }\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Hitmarker\" }\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Local_HitmarkerDuration\", type = \"slider\", text = \"Duracion\", min = 0.05, max = 1, default = 0.3, decimals = 2, dependsOn = \"Local_Hitmarker\" }\
    -- HUD (Right)\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_Watermark\", type = \"toggle\", text = \"Watermark\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Title\", type = \"toggle\", text = \"  titulo\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_FPS\", type = \"toggle\", text = \"  FPS\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Ping\", type = \"toggle\", text = \"  ping\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Name\", type = \"toggle\", text = \"  nombre\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Time\", type = \"toggle\", text = \"  hora\", default = false, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkX\", type = \"slider\", text = \"Watermark X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkY\", type = \"slider\", text = \"Watermark Y\", min = 0, max = 1200, default = 8, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindList\", type = \"toggle\", text = \"Lista de keybinds\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindX\", type = \"slider\", text = \"Keybinds X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_KeybindList\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindY\", type = \"slider\", text = \"Keybinds Y\", min = 0, max = 1200, default = 120, dependsOn = \"Local_KeybindList\" }\
    -- Extras (Right)\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_AntiFlash\", type = \"toggle\", text = \"Anti-flash\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_AntiSmoke\", type = \"toggle\", text = \"Anti-humo (necesita perfil)\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_SelfChams\", type = \"toggle\", text = \"Self-chams (Highlight, detectable)\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Right\", flag = \"Local_SelfChamsFillTransparency\", type = \"slider\", text = \"Self-chams transp\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"Local_SelfChams\" }\
\
    -- ===== Tab Local Colores (CF) =====\
    addCF{ base = \"Local_CrosshairColor\", text = \"Crosshair\", tab = TC, group = \"Colores\", side = \"Left\", default = C(0, 255, 120), dependsOn = \"Local_Crosshair\" }\
    addCF{ base = \"Local_HitmarkerColor\", text = \"Hitmarker\", tab = TC, group = \"Colores\", side = \"Left\", default = C(255, 255, 255), dependsOn = \"Local_Hitmarker\" }\
    addCF{ base = \"Local_WatermarkColor\", text = \"Watermark\", tab = TC, group = \"Colores\", side = \"Left\", default = C(235, 235, 240), dependsOn = \"Local_Watermark\" }\
    addCF{ base = \"Local_KeybindColor\", text = \"Keybinds\", tab = TC, group = \"Colores\", side = \"Right\", default = C(235, 235, 240), dependsOn = \"Local_KeybindList\" }\
    addCF{ base = \"Local_SelfChamsFill\", text = \"Self-chams fill\", tab = TC, group = \"Colores\", side = \"Right\", default = C(0, 200, 255), dependsOn = \"Local_SelfChams\" }\
    addCF{ base = \"Local_SelfChamsOutline\", text = \"Self-chams outline\", tab = TC, group = \"Colores\", side = \"Right\", default = C(180, 240, 255), dependsOn = \"Local_SelfChams\" }\
\
    GV.Modules = GV.Modules or {}\
    GV.Modules.selffx = GV.Modules.selffx or {}\
    GV.Modules.selffx.schema = S\
end\
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
do local chunk = "--[[ PERFIL BASE — copiar a games/<tujuego>.lua para un script nuevo.\
\
     Los 3 modulos (World/ESP/SelfFX) corren game-agnostic SIN perfil:\
       V:Attach(Lib, Win, { modules = {\"world\",\"esp\",\"selffx\"} })   -- sin profile = generico\
     El perfil es OPCIONAL y solo agrega lo especifico del juego:\
       V:Attach(Lib, Win, { modules = {...}, profile = \"tujuego\" })\
\
     Contrato completo abajo. Todos los campos son opcionales; borra los que no uses. ]]\
return function(GV)\
    GV.Profiles = GV.Profiles or {}\
    GV.Profiles._template = {\
        -- === World (opcional) ===\
        defaults = {},                                   -- overrides de flags por defecto\
        textures = { rain = \"rbxassetid://13911374915\", snow = \"rbxassetid://15414665346\" },\
        mapFilter = function(inst) return false end,     -- true = excluir del bloque J (skybox/char propio)\
        extraSchema = {},                                -- filas de schema game-only\
\
        -- === ESP (opcional; sin esto usa GV.DefaultProvider por Players) ===\
        esp = {\
            provider = {\
                -- getTargets(esp) -> lista de Target normalizado:\
                -- { model, health, maxHealth, root, head, bones={{a,b}...}, name, team,\
                --   weapon, level, isEnemy, isPlayer }\
                getTargets = function(esp) return {} end,\
            },\
            objectSources = {\
                -- { key=\"Loot\", tag=\"Loot\", name=\"Loot\", maxDistance=500 }  -- por CollectionService tag\
                -- { key=\"Chest\", classFilter=\"Model\", name=\"Chest\" }        -- por clase\
            },\
        },\
\
        -- === SelfFX (opcional; sin esto usa camara/overlays genericos) ===\
        selffx = {\
            -- setFOV(offset)          -- si el juego controla la camara (ej. FOV spring propio)\
            -- setThirdPerson(bool)    -- override de 3ra persona del juego\
            -- flashEffects() -> {}    -- instancias de flash a neutralizar (default generico: CC/Blur \"flash\"/\"blind\")\
            -- smokeEffects() -> {}    -- instancias de humo\
            -- hitSignal = RBXScriptSignal  -- para el hitmarker (dispara al pegar)\
            -- keybinds() -> { {name=,key=} }  -- lista para el keybind-list\
        },\
    }\
end\
"
local f = loadstring(chunk, '@games/_template.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    -- filas de accion que necesitan la instancia (presets de World)\r\
    local function presetRows(bag)\r\
        return {\r\
            { tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", type = \"button\", text = \"Aplicar preset\",\r\
                action = function()\r\
                    local w = bag.__suite and bag.__suite.modules.world\r\
                    if w then w:ApplyPreset(w:Get(\"World_PresetSelect\")) end\r\
                end },\r\
        }\r\
    end\r\
\r\
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
        if suite.modules.world then\r\
            for _, r in ipairs(presetRows(bag)) do table.insert(schema, r) end\r\
        end\r\
        GV.Renderer.build(adapter, Window, schema, bag)\r\
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
