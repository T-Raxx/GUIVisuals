-- World Visuals (claudeui) — build autogenerado
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
    GV.Adapters = GV.Adapters or {}\
    local A = {}\
    local ADD = { toggle = \"AddToggle\", slider = \"AddSlider\", dropdown = \"AddDropdown\",\
        colorpicker = \"AddColorPicker\", label = \"AddLabel\", textbox = \"AddInput\", button = \"AddButton\" }\
\
    function A.Tab(window, name) return window:AddTab(name) end\
    function A.Group(tab, name, side)\
        if side == \"Right\" then return tab:AddRightGroupbox(name) end\
        return tab:AddLeftGroupbox(name)\
    end\
    function A.Widget(group, kind, flag, opts, parent)\
        local m = ADD[kind]\
        if not m then warn(\"[claudeui] kind desconocido: \" .. tostring(kind)); return { flag = flag } end\
        local host = parent or group\
        -- nesting = dependencia; si el child no soporta este kind (ej AddInput/AddButton bajo toggle) -> al grupo\
        if type(host[m]) ~= \"function\" then host = group end\
        if type(host[m]) ~= \"function\" then warn(\"[claudeui] sin \" .. m); return { flag = flag } end\
        if kind == \"label\" then return host:AddLabel(opts.Text or \"\") end\
        if kind == \"button\" then return host:AddButton(opts.Text or \"Button\", opts.Callback or function() end) end\
        return host[m](host, flag, opts)\
    end\
    function A.Depend() end -- no-op: en ClaudeUI la dependencia se resuelve por nesting al crear\
\
    GV.Adapters.claudeui = A\
end\
"
local f = loadstring(chunk, '@ui/adapter_claudeui.lua')(); f(GV) end
do local chunk = "return function(GV)\
    local H = {}\
    -- expande una spec de color a 3 filas (cp base, fade toggle, cp2 dep del fade)\
    function H.CF(spec)\
        local base = spec.base\
        local function row(t)\
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side\
            return t\
        end\
        return {\
            row{ flag = base, type = \"colorpicker\", text = spec.text, default = spec.default, dependsOn = spec.dependsOn },\
            row{ flag = base .. \"_Fade\", type = \"toggle\", text = (spec.text or \"\") .. \" fade\", default = false, dependsOn = spec.dependsOn },\
            row{ flag = base .. \"_2\", type = \"colorpicker\", text = (spec.text or \"\") .. \" color 2\", default = spec.default2 or spec.default, dependsOn = base .. \"_Fade\" },\
        }\
    end\
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end\
    function H.suiteRows()\
        return {\
            { tab = \"Mundo\", group = \"Suite\", side = \"Left\", flag = \"Suite_FadeSpeed\", type = \"slider\",\
                text = \"Velocidad fade\", min = 0.1, max = 5, default = 1, decimals = 2 },\
        }\
    end\
    GV.SchemaHelpers = H\
    GV.CF = H.CF\
    GV.pushCF = H.pushCF\
end\
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
    GV.Profiles = GV.Profiles or {}\
    local Players = game:GetService(\"Players\")\
    GV.Profiles.rivals = {\
        defaults = { World_FogColor = Color3.fromRGB(190, 195, 210) },\
        textures = { rain = \"rbxassetid://13911374915\", snow = \"rbxassetid://15414665346\" },\
        -- excluir el rig de clima propio ('Camera'), la camara y el char del jugador\
        mapFilter = function(inst)\
            if inst.Name == \"Camera\" then return true end\
            local cam = workspace.CurrentCamera\
            if cam then local ok, r = pcall(function() return inst:IsDescendantOf(cam) end); if ok and r then return true end end\
            local plr = Players.LocalPlayer\
            if plr and plr.Character then\
                local ok, r = pcall(function() return inst:IsDescendantOf(plr.Character) end)\
                if ok and r then return true end\
            end\
            return false\
        end,\
        extraSchema = {}, -- controles Rivals-only si aparecen\
    }\
end\
"
local f = loadstring(chunk, '@games/rivals.lua')(); f(GV) end
do local chunk = "return function(GV)\
    GV.Profiles = GV.Profiles or {}\
    -- Perfil en blanco: copiar para juegos nuevos.\
    GV.Profiles._template = {\
        defaults = {},\
        textures = { rain = \"rbxassetid://13911374915\", snow = \"rbxassetid://15414665346\" },\
        mapFilter = function(inst) return false end, -- no excluye nada\
        extraSchema = {},                             -- controles game-only\
    }\
end\
"
local f = loadstring(chunk, '@games/_template.lua')(); f(GV) end
do local chunk = "return function(GV)\
    -- filas de accion que necesitan la instancia (presets de World)\
    local function presetRows(bag)\
        return {\
            { tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", type = \"button\", text = \"Aplicar preset\",\
                action = function()\
                    local w = bag.__suite and bag.__suite.modules.world\
                    if w then w:ApplyPreset(w:Get(\"World_PresetSelect\")) end\
                end },\
        }\
    end\
\
    -- GV.Attach(Library, Window, opts) -> suite\
    -- opts: { adapter, modules={\"world\",...}, profile, services, flags }\
    function GV.Attach(Library, Window, opts)\
        opts = opts or {}\
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or \"claudeui\"]\
        assert(adapter, \"adapter no encontrado\")\
        local names = opts.modules or GV._defaultModules or { \"world\" }\
        local flags = opts.flags or {}\
        local bag = { Flags = flags }\
        function bag:Set(k, v) self.Flags[k] = v end\
        function bag:Get(k) return self.Flags[k] end\
        local suite = { modules = {}, flags = flags }\
        function suite:Unload()\
            for _, m in pairs(self.modules) do pcall(function() m:Unload() end) end\
        end\
        bag.__suite = suite\
\
        local schema = {}\
        for _, r in ipairs(GV.SchemaHelpers.suiteRows()) do table.insert(schema, r) end\
        for _, name in ipairs(names) do\
            local def = GV.Modules[name]\
            if def then\
                local inst = def.new({ services = opts.services, flags = flags })\
                if opts.profile and inst.UseProfile then\
                    local prof = GV.Profiles[opts.profile]\
                    inst:UseProfile(prof and (prof[name] or prof) or nil)\
                end\
                suite.modules[name] = inst\
                for _, r in ipairs(def.schema or {}) do table.insert(schema, r) end\
            end\
        end\
        if suite.modules.world then\
            for _, r in ipairs(presetRows(bag)) do table.insert(schema, r) end\
        end\
        GV.Renderer.build(adapter, Window, schema, bag)\
        for _, inst in pairs(suite.modules) do inst:Init() end\
        return suite\
    end\
end\
"
local f = loadstring(chunk, '@entry/attach.lua')(); f(GV) end
GV._defaultAdapter = 'claudeui'
return { Attach = GV.Attach, _GV = GV }
