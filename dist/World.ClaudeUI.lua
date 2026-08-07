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
    local U = GV.Util\
    local World = {}\
    World.__index = World\
\
    function World.new(opts)\
        opts = opts or {}\
        local svc = opts.services or {\
            Lighting = game:GetService(\"Lighting\"),\
            Terrain = workspace:FindFirstChildOfClass(\"Terrain\"),\
            RunService = game:GetService(\"RunService\"),\
            Workspace = workspace,\
        }\
        local self = setmetatable({\
            Flags = {}, Services = svc, Conns = {},\
            _orig = {}, _made = {}, _fxCache = {}, _applies = {},\
            Loaded = false, _wasOn = false,\
        }, World)\
        self:_installApplies()\
        return self\
    end\
\
    function World:Set(flag, v) self.Flags[flag] = v end\
    function World:Get(flag) return self.Flags[flag] end\
    function World:_flag(name, default)\
        local v = self.Flags[name]\
        if v ~= nil then return v end\
        return default\
    end\
\
    -- serializa para config (Color3/Enum -> tablas nombradas)\
    function World:GetFlags()\
        local out = {}\
        for k, v in pairs(self.Flags) do\
            if typeof(v) == \"Color3\" then out[k] = U.serColor(v)\
            elseif typeof(v) == \"EnumItem\" then out[k] = U.serEnum(v)\
            else out[k] = v end\
        end\
        return out\
    end\
    function World:LoadFlags(tbl)\
        for k, v in pairs(tbl) do\
            if type(v) == \"table\" and v.__ == \"c3\" then self.Flags[k] = U.deColor(v)\
            elseif type(v) == \"table\" and v.__ == \"en\" then self.Flags[k] = U.deEnum(v)\
            else self.Flags[k] = v end\
        end\
    end\
\
    -- perfil de juego: defaults, texturas, filtro de parts (bloque J), schema extra\
    function World:UseProfile(p)\
        if not p then return end\
        if p.defaults then\
            for k, v in pairs(p.defaults) do if self.Flags[k] == nil then self.Flags[k] = v end end\
        end\
        self._mapFilter = p.mapFilter\
        self._tex = p.textures\
        self._profileSchema = p.extraSchema\
    end\
\
    function World:_set(obj, prop, val)\
        if not obj then return end\
        local ok, cur = pcall(function() return obj[prop] end)\
        if not ok then return end\
        local mem = self._orig[obj]\
        if not mem then mem = {}; self._orig[obj] = mem end\
        if mem[prop] == nil then mem[prop] = cur end\
        if cur ~= val then pcall(function() obj[prop] = val end) end\
    end\
    function World:_restoreAll()\
        for obj, props in pairs(self._orig) do\
            for prop, val in pairs(props) do pcall(function() obj[prop] = val end) end\
        end\
        table.clear(self._orig)\
    end\
\
    -- crear (una vez) un efecto propio, nombrado como los del juego para no cantar en scan\
    function World:_fx(class, parent)\
        local got = self._fxCache[class]\
        if got then\
            -- reusar el cache; si el juego lo despareento, re-attach (Parent==nil)\
            if not got.Parent then pcall(function() got.Parent = parent or self.Services.Lighting end) end\
            return got\
        end\
        local inst = Instance.new(class)\
        inst.Name = \"LightingController\"\
        pcall(function() inst.Parent = parent or self.Services.Lighting end)\
        self._fxCache[class] = inst\
        table.insert(self._made, inst)\
        return inst\
    end\
\
    function World:_register(fn) table.insert(self._applies, fn) end\
\
    function World:_step()\
        if not self:_flag(\"World_Enabled\", false) then\
            if self._wasOn then self:_off() end\
            return\
        end\
        self._wasOn = true\
        for _, fn in ipairs(self._applies) do\
            local ok, err = pcall(fn, self)\
            if not ok then warn(\"[World] apply: \" .. tostring(err)) end\
        end\
    end\
\
    function World:_off()\
        self._wasOn = false\
        if self._wxEmit then self._wxEmit.Enabled = false end\
        self._lastWx = nil\
        for _, inst in pairs(self._fxCache) do\
            pcall(function() if inst:IsA(\"PostEffect\") then inst.Enabled = false end end)\
        end\
        self:_killAtmosphere() -- destruir, no Density=0: si queda, mata el fog\
        self:_restoreAll()\
    end\
\
    function World:Init()\
        if self.Loaded then return self end\
        self.Loaded = true\
        local conn = self.Services.RunService.RenderStepped:Connect(function()\
            local ok, err = pcall(function() self:_step() end)\
            if not ok then warn(\"[World] step: \" .. tostring(err)) end\
        end)\
        self.Conns[#self.Conns + 1] = conn\
        return self\
    end\
\
    function World:Unload()\
        if not self.Loaded then return end\
        self.Loaded = false\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\
        table.clear(self.Conns)\
        self:_restoreAll()\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\
        table.clear(self._made)\
        self._fxCache = {}\
    end\
\
    ------------------------------------------------------------------ APPLIES\
    local WHITE = Color3.fromRGB(255, 255, 255)\
\
    -- A. Lighting core\
    function World:_applyLighting()\
        local L = self.Services.Lighting\
        if self:_flag(\"World_Fullbright\", false) then\
            self:_set(L, \"Ambient\", WHITE); self:_set(L, \"OutdoorAmbient\", WHITE)\
            self:_set(L, \"Brightness\", 1); self:_set(L, \"GlobalShadows\", false)\
        else\
            local amb = self:_flag(\"World_Ambient\", Color3.fromRGB(120, 120, 125))\
            self:_set(L, \"Ambient\", amb)\
            self:_set(L, \"OutdoorAmbient\", self:_flag(\"World_OutdoorAmbient\", amb))\
            self:_set(L, \"Brightness\", self:_flag(\"World_Brightness\", 3))\
            self:_set(L, \"GlobalShadows\", not self:_flag(\"World_NoShadows\", false))\
        end\
        self:_set(L, \"ExposureCompensation\", self:_flag(\"World_Exposure\", 0))\
        self:_set(L, \"ColorShift_Top\", self:_flag(\"World_ColorShiftTop\", Color3.new()))\
        self:_set(L, \"ColorShift_Bottom\", self:_flag(\"World_ColorShiftBottom\", Color3.new()))\
        self:_set(L, \"EnvironmentDiffuseScale\", self:_flag(\"World_EnvDiffuse\", 1))\
        self:_set(L, \"EnvironmentSpecularScale\", self:_flag(\"World_EnvSpecular\", 1))\
        self:_set(L, \"GeographicLatitude\", self:_flag(\"World_GeoLatitude\", 41.733))\
        local tech = self:_flag(\"World_Technology\", \"\")\
        if tech ~= \"\" then pcall(function() L.Technology = Enum.Technology[tech] end) end\
    end\
\
    -- B. Tiempo / sol\
    function World:_applyTime()\
        local L = self.Services.Lighting\
        if self:_flag(\"World_DayNightCycle\", false) then\
            local spd = self:_flag(\"World_CycleSpeed\", 1)\
            local t = (self._cycleT or self:_flag(\"World_ClockTime\", 12)) + (1 / 60) * spd\
            if t >= 24 then t = t - 24 end\
            self._cycleT = t\
            self:_set(L, \"ClockTime\", t)\
        elseif self:_flag(\"World_FreezeTime\", false) then\
            if not self._freeze then self._freeze = self:_flag(\"World_ClockTime\", 12) end\
            self:_set(L, \"ClockTime\", self._freeze)\
        elseif self:_flag(\"World_UseTimeOfDay\", false) then\
            local c = self:_flag(\"World_ClockTime\", 12); local h = math.floor(c); local m = math.floor((c - h) * 60)\
            self:_set(L, \"TimeOfDay\", string.format(\"%02d:%02d:00\", h, m))\
        else\
            self._freeze = nil\
            self:_set(L, \"ClockTime\", self:_flag(\"World_ClockTime\", 12))\
        end\
    end\
\
    -- C. Fog  +  D. Atmosphere (destroy-on-off)\
    function World:_applyFog()\
        local L = self.Services.Lighting\
        if self:_flag(\"World_NoFog\", false) then\
            self:_set(L, \"FogStart\", 0); self:_set(L, \"FogEnd\", 1e6)\
        else\
            self:_set(L, \"FogStart\", self:_flag(\"World_FogStart\", 0))\
            self:_set(L, \"FogEnd\", self:_flag(\"World_FogEnd\", 2500))\
            self:_set(L, \"FogColor\", self:_flag(\"World_FogColor\", Color3.fromRGB(190, 195, 210)))\
        end\
        if self:_flag(\"World_Atmosphere\", false) then\
            local a = self:_fx(\"Atmosphere\")\
            a.Density = self:_flag(\"World_AtmDensity\", 0.3)\
            a.Offset  = self:_flag(\"World_AtmOffset\", 0.25)\
            a.Glare   = self:_flag(\"World_AtmGlare\", 0)\
            a.Haze    = self:_flag(\"World_AtmHaze\", 0)\
            a.Color   = self:_flag(\"World_AtmColor\", Color3.fromRGB(199, 199, 199))\
            a.Decay   = self:_flag(\"World_AtmDecay\", Color3.fromRGB(106, 112, 125))\
        else\
            self:_killAtmosphere()\
        end\
    end\
\
    function World:_killAtmosphere()\
        local a = self._fxCache and self._fxCache.Atmosphere\
        if not a then return end\
        for i, inst in ipairs(self._made) do if inst == a then table.remove(self._made, i) break end end\
        pcall(function() a:Destroy() end)\
        self._fxCache.Atmosphere = nil\
    end\
\
    -- E. Post-FX\
    function World:_applyPost()\
        local cc = self:_fx(\"ColorCorrectionEffect\")\
        cc.Enabled = self:_flag(\"World_Tint\", false)\
        if cc.Enabled then\
            cc.Brightness = self:_flag(\"World_TintBrightness\", 0)\
            cc.Contrast   = self:_flag(\"World_TintContrast\", 0)\
            cc.Saturation = self:_flag(\"World_TintSaturation\", 0)\
            if self:_flag(\"World_RainbowHue\", false) then\
                local t = (tick() * self:_flag(\"World_RainbowSpeed\", 1)) % 1\
                cc.TintColor = Color3.fromHSV(t, 0.5, 1)\
            else\
                cc.TintColor = self:_flag(\"World_TintColor\", WHITE)\
            end\
        end\
        local bm = self:_fx(\"BloomEffect\")\
        bm.Enabled = self:_flag(\"World_Bloom\", false)\
        if bm.Enabled then\
            bm.Intensity = self:_flag(\"World_BloomIntensity\", 0.4)\
            bm.Size = self:_flag(\"World_BloomSize\", 24)\
            bm.Threshold = self:_flag(\"World_BloomThreshold\", 0.95)\
        end\
        local sr = self:_fx(\"SunRaysEffect\")\
        sr.Enabled = self:_flag(\"World_SunRays\", false)\
        if sr.Enabled then\
            sr.Intensity = self:_flag(\"World_SunRaysIntensity\", 0.05)\
            sr.Spread = self:_flag(\"World_SunRaysSpread\", 0.5)\
        end\
        local df = self:_fx(\"DepthOfFieldEffect\")\
        df.Enabled = self:_flag(\"World_DoF\", false)\
        if df.Enabled then\
            df.FocusDistance = self:_flag(\"World_DoFFocus\", 25)\
            df.InFocusRadius = self:_flag(\"World_DoFRadius\", 10)\
            df.NearIntensity = self:_flag(\"World_DoFNear\", 0)\
            df.FarIntensity  = self:_flag(\"World_DoFFar\", 0.75)\
        end\
        local bu = self:_fx(\"BlurEffect\")\
        bu.Enabled = self:_flag(\"World_WorldBlur\", false)\
        if bu.Enabled then bu.Size = self:_flag(\"World_WorldBlurSize\", 12) end\
        if self:_flag(\"World_KillGamePostFX\", false) then\
            local ok, kids = pcall(function() return self.Services.Lighting:GetChildren() end)\
            if ok and kids then\
                for _, e in ipairs(kids) do\
                    if e:IsA(\"PostEffect\") and not table.find(self._made, e) then\
                        self:_set(e, \"Enabled\", false)\
                    end\
                end\
            end\
        end\
    end\
\
    -- F. Cielo / celestial  +  G. Nubes (Terrain.Clouds)\
    function World:_applySky()\
        local L = self.Services.Lighting\
        local sky = L:FindFirstChildOfClass(\"Sky\")\
        if sky then\
            local off = self:_flag(\"World_NoSky\", false)\
            self:_set(sky, \"CelestialBodiesShown\", not off)\
            self:_set(sky, \"StarCount\", off and 0 or self:_flag(\"World_StarCount\", 3000))\
            if self:_flag(\"World_CustomSkybox\", false) then\
                local faces = { Up = \"SkyboxUp\", Dn = \"SkyboxDn\", Lf = \"SkyboxLf\", Rt = \"SkyboxRt\", Bk = \"SkyboxBk\", Ft = \"SkyboxFt\" }\
                for face, prop in pairs(faces) do\
                    local v = self:_flag(\"World_Skybox_\" .. face, \"\")\
                    if v ~= \"\" then self:_set(sky, prop, v) end\
                end\
                local sun = self:_flag(\"World_SunTextureId\", \"\"); if sun ~= \"\" then self:_set(sky, \"SunTextureId\", sun) end\
                local moon = self:_flag(\"World_MoonTextureId\", \"\"); if moon ~= \"\" then self:_set(sky, \"MoonTextureId\", moon) end\
                self:_set(sky, \"SunAngularSize\", self:_flag(\"World_SunAngularSize\", 21))\
                self:_set(sky, \"MoonAngularSize\", self:_flag(\"World_MoonAngularSize\", 11))\
            end\
        end\
        local Terrain = self.Services.Terrain\
        if not Terrain or not Terrain.FindFirstChildOfClass then return end\
        if not self:_flag(\"World_Clouds\", false) then return end\
        local clouds = Terrain:FindFirstChildOfClass(\"Clouds\") or self:_fx(\"Clouds\", Terrain)\
        self:_set(clouds, \"Enabled\", not self:_flag(\"World_NoClouds\", false))\
        self:_set(clouds, \"Cover\", self:_flag(\"World_CloudCover\", 0.5))\
        self:_set(clouds, \"Density\", self:_flag(\"World_CloudDensity\", 0.7))\
        self:_set(clouds, \"Color\", self:_flag(\"World_CloudColor\", WHITE))\
    end\
\
    -- H. Terrain / agua\
    function World:_applyWater()\
        local Terrain = self.Services.Terrain\
        if not Terrain or not self:_flag(\"World_WaterEnable\", false) then return end\
        self:_set(Terrain, \"WaterColor\", self:_flag(\"World_WaterColor\", Color3.fromRGB(12, 84, 92)))\
        self:_set(Terrain, \"WaterTransparency\", self:_flag(\"World_WaterTransparency\", 0.3))\
        self:_set(Terrain, \"WaterReflectance\", self:_flag(\"World_WaterReflectance\", 1))\
        self:_set(Terrain, \"WaterWaveSize\", self:_flag(\"World_WaterWaveSize\", 0.15))\
        self:_set(Terrain, \"WaterWaveSpeed\", self:_flag(\"World_WaterWaveSpeed\", 10))\
        self:_set(Terrain, \"Decoration\", self:_flag(\"World_TerrainDecoration\", true))\
    end\
\
    -- I. Clima local (particulas sobre la camara). Texturas del cliente (no dependen de red).\
    local TEX_RAIN = \"rbxassetid://13911374915\" -- streaks\
    local TEX_SNOW = \"rbxassetid://15414665346\" -- dots\
    local WX = {\
        [\"Lluvia\"]        = { tex = TEX_RAIN, rate = 400,  speed = 105, life = 1.0,  size = 0.9,  squash = 6, spread = 1.5, drag = 0,   accel = Vector3.new(0, -35, 0),    transp = 0.45, light = 0.15, rot = 0,  rotSpeed = 0 },\
        [\"Lluvia fuerte\"] = { tex = TEX_RAIN, rate = 1400, speed = 150, life = 0.85, size = 1.15, squash = 9, spread = 2.5, drag = 0,   accel = Vector3.new(-14, -70, 0),  transp = 0.3,  light = 0.2,  rot = -9, rotSpeed = 0 },\
        [\"Nieve\"]         = { tex = TEX_SNOW, rate = 190,  speed = 6,   life = 6.5,  size = 0.28, squash = 0, spread = 26,  drag = 2.8, accel = Vector3.new(1.2, -2.4, 0.7), transp = 0.25, light = 0.05, rot = 0, rotSpeed = 22 },\
        [\"Niebla\"]        = { tex = TEX_SNOW, rate = 60,   speed = 2,   life = 9,    size = 6,    squash = 0, spread = 40,  drag = 4,   accel = Vector3.new(0.5, -0.4, 0.3), transp = 0.75, light = 0.02, rot = 0, rotSpeed = 4 },\
        [\"Ceniza\"]        = { tex = TEX_SNOW, rate = 120,  speed = 8,   life = 5,    size = 0.4,  squash = 0, spread = 30,  drag = 2,   accel = Vector3.new(2, -4, 1),      transp = 0.3,  light = 0.6,  rot = 0, rotSpeed = 30 },\
        [\"Luciérnagas\"]   = { tex = TEX_SNOW, rate = 40,   speed = 3,   life = 7,    size = 0.25, squash = 0, spread = 45,  drag = 3,   accel = Vector3.new(0, 0.2, 0),     transp = 0.1,  light = 1,    rot = 0, rotSpeed = 10 },\
        [\"Custom\"]        = { tex = TEX_SNOW, rate = 300,  speed = 20,  life = 4,    size = 1,    squash = 0, spread = 20,  drag = 1,   accel = Vector3.new(0, -10, 0),     transp = 0.3,  light = 0.3,  rot = 0, rotSpeed = 8 },\
    }\
\
    function World:_wxRig()\
        if self._wxPart and self._wxPart.Parent then return self._wxPart, self._wxEmit end\
        local p = Instance.new(\"Part\")\
        p.Name = \"Camera\"\
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false\
        p.Transparency = 1; p.Size = Vector3.new(1, 1, 1)\
        p.Parent = workspace\
        local e = Instance.new(\"ParticleEmitter\")\
        e.Enabled = false\
        e.EmissionDirection = Enum.NormalId.Bottom\
        e.LockedToPart = false\
        e.Parent = p\
        self._wxPart, self._wxEmit = p, e\
        table.insert(self._made, p)\
        return p, e\
    end\
\
    function World:_applyWeather()\
        if not self:_flag(\"World_Weather\", false) then\
            if self._wxEmit then self._wxEmit.Enabled = false end\
            self._lastWx = nil\
            return\
        end\
        local mode = self:_flag(\"World_WeatherMode\", \"Lluvia\")\
        local cfg = WX[mode]; if not cfg then return end\
        local part, emit = self:_wxRig()\
        local cam = self.Services.Workspace and self.Services.Workspace.CurrentCamera\
        if not cam then return end\
        local area = self:_flag(\"World_WeatherArea\", 90)\
        part.Size = Vector3.new(area, 1, area)\
        part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 28, 0))\
\
        if self._lastWx ~= mode then\
            self._lastWx = mode\
            local tex = cfg.tex\
            if mode == \"Custom\" then\
                local ct = self:_flag(\"World_WeatherCustomTex\", \"\")\
                if ct ~= \"\" then tex = ct end\
            elseif self._tex then\
                if cfg.tex == TEX_RAIN and self._tex.rain then tex = self._tex.rain\
                elseif cfg.tex == TEX_SNOW and self._tex.snow then tex = self._tex.snow end\
            end\
            emit.Texture = tex\
            emit.Drag = cfg.drag\
            emit.Squash = NumberSequence.new(cfg.squash)\
            emit.SpreadAngle = Vector2.new(cfg.spread, cfg.spread)\
            emit.Rotation = NumberRange.new(cfg.rot)\
            emit.RotSpeed = NumberRange.new(-cfg.rotSpeed, cfg.rotSpeed)\
            emit.ZOffset = 0\
            emit.EmissionDirection = Enum.NormalId.Bottom\
        end\
        local dens = self:_flag(\"World_WeatherDensity\", 1)\
        local spd  = self:_flag(\"World_WeatherSpeed\", 1)\
        local sz   = self:_flag(\"World_WeatherSize\", 1)\
        -- viento: rota la componente horizontal de la aceleracion\
        local wind = math.rad(self:_flag(\"World_WeatherWindDir\", 0))\
        local accel = cfg.accel * spd\
        if wind ~= 0 then\
            local mag = math.abs(accel.X) + 6\
            accel = Vector3.new(math.sin(wind) * mag, accel.Y, math.cos(wind) * mag)\
        end\
        emit.Rate = cfg.rate * dens\
        emit.Lifetime = NumberRange.new(cfg.life * 0.85, cfg.life)\
        emit.Speed = NumberRange.new(cfg.speed * spd * 0.9, cfg.speed * spd)\
        emit.Acceleration = accel\
        emit.Size = NumberSequence.new(cfg.size * sz)\
        emit.Color = ColorSequence.new(self:_flag(\"World_WeatherColor\", Color3.fromRGB(220, 230, 255)))\
        emit.LightEmission = self:_flag(\"World_WeatherGlow\", cfg.light)\
        emit.Transparency = NumberSequence.new(self:_flag(\"World_WeatherTransparency\", cfg.transp))\
        emit.Enabled = true\
        -- relampago: flash breve periodico (cosmetico, best-effort)\
        if self:_flag(\"World_Lightning\", false) then\
            local now = tick()\
            if not self._lightNext or now >= self._lightNext then\
                self._lightNext = now + 3 + math.random() * 5\
                pcall(function() self.Services.Lighting.Brightness = self:_flag(\"World_Brightness\", 3) + 6 end)\
            end\
        end\
    end\
\
    -- J. Visibilidad (agresivo). Gateado tras World_Advanced. Usa self._mapFilter del perfil.\
    function World:_applyVisibility()\
        if not self:_flag(\"World_Advanced\", false) then return end\
        local killP  = self:_flag(\"World_KillParticles\", false)\
        local smooth = self:_flag(\"World_ForceSmoothPlastic\", false)\
        local tr     = self:_flag(\"World_MapTransparent\", false)\
        local noTex  = self:_flag(\"World_NoTextures\", false)\
        if not (killP or smooth or tr or noTex) then return end\
        local amount = self:_flag(\"World_MapTransparentAmount\", 0.6)\
        local filter = self._mapFilter\
        local ok, list = pcall(function() return self.Services.Workspace:GetDescendants() end)\
        if not ok or not list then return end\
        for _, d in ipairs(list) do\
            if not (filter and filter(d)) then\
                if killP and (d:IsA(\"ParticleEmitter\") or d:IsA(\"Beam\") or d:IsA(\"Trail\")) then\
                    self:_set(d, \"Enabled\", false)\
                elseif d:IsA(\"BasePart\") then\
                    if smooth then self:_set(d, \"Material\", Enum.Material.SmoothPlastic) end\
                    if tr and d.Transparency < amount then self:_set(d, \"Transparency\", amount) end\
                elseif noTex and (d:IsA(\"Decal\") or d:IsA(\"Texture\")) then\
                    self:_set(d, \"Transparency\", 1)\
                end\
            end\
        end\
    end\
\
    -- K. Presets: batch de flags\
    local PRESETS = {\
        Competitivo         = { World_Enabled = true, World_Fullbright = true, World_NoFog = true, World_NoShadows = true, World_Atmosphere = false, World_Bloom = false },\
        [\"Cinematográfico\"] = { World_Enabled = true, World_Fullbright = false, World_Bloom = true, World_BloomIntensity = 1.2, World_DoF = true, World_Exposure = 0.2, World_Tint = true, World_TintContrast = 0.1 },\
        [\"Día\"]             = { World_Enabled = true, World_ClockTime = 13, World_Fullbright = false, World_NoFog = true },\
        Noche               = { World_Enabled = true, World_ClockTime = 0, World_Brightness = 1, World_Fullbright = false },\
        Atardecer           = { World_Enabled = true, World_ClockTime = 17.5, World_Atmosphere = true, World_AtmDensity = 0.4, World_AtmColor = Color3.fromRGB(255, 170, 120) },\
        Niebla              = { World_Enabled = true, World_NoFog = false, World_FogStart = 0, World_FogEnd = 180, World_FogColor = Color3.fromRGB(180, 185, 195) },\
    }\
    function World:ApplyPreset(name)\
        local p = PRESETS[name]; if not p then return end\
        for k, v in pairs(p) do self:Set(k, v) end\
    end\
\
    function World:_installApplies()\
        self:_register(self._applyLighting)\
        self:_register(self._applyTime)\
        self:_register(self._applyFog)\
        self:_register(self._applyPost)\
        self:_register(self._applySky)\
        self:_register(self._applyWater)\
        self:_register(self._applyWeather)\
        self:_register(self._applyVisibility)\
    end\
\
    GV.World = World\
end\
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
    local C = Color3.fromRGB\
    GV.Schema = {\
        -- ================= Tab \"Mundo\" =================\
        -- A. Lighting core\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Enabled\", type = \"toggle\", text = \"Enable visuales\", default = false, keybind = true, master = true },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Fullbright\", type = \"toggle\", text = \"Fullbright\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_NoShadows\", type = \"toggle\", text = \"Sin sombras\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Ambient\", type = \"colorpicker\", text = \"Ambient\", default = C(120, 120, 125), dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_OutdoorAmbient\", type = \"colorpicker\", text = \"Outdoor ambient\", default = C(120, 120, 125), dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Brightness\", type = \"slider\", text = \"Brillo\", min = 0, max = 10, default = 3, decimals = 1, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Exposure\", type = \"slider\", text = \"Exposicion\", min = -3, max = 3, default = 0, decimals = 2, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_ColorShiftTop\", type = \"colorpicker\", text = \"ColorShift Top\", default = C(0, 0, 0), dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_ColorShiftBottom\", type = \"colorpicker\", text = \"ColorShift Bottom\", default = C(0, 0, 0), dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvDiffuse\", type = \"slider\", text = \"Env diffuse\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_EnvSpecular\", type = \"slider\", text = \"Env specular\", min = 0, max = 5, default = 1, decimals = 2, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_Technology\", type = \"dropdown\", text = \"Technology\", values = { \"\", \"Voxel\", \"ShadowMap\", \"Future\", \"Legacy\" }, default = \"\", dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Lighting\", side = \"Left\", flag = \"World_GeoLatitude\", type = \"slider\", text = \"Latitud geo\", min = -90, max = 90, default = 41.7, decimals = 1, dependsOn = \"World_Enabled\" },\
        -- B. Tiempo / Sol\
        { tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_ClockTime\", type = \"slider\", text = \"Hora del dia\", min = 0, max = 24, default = 12, decimals = 1, suffix = \"h\", dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_UseTimeOfDay\", type = \"toggle\", text = \"Usar TimeOfDay\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_FreezeTime\", type = \"toggle\", text = \"Congelar tiempo\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_DayNightCycle\", type = \"toggle\", text = \"Ciclo dia/noche\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Tiempo / Sol\", side = \"Left\", flag = \"World_CycleSpeed\", type = \"slider\", text = \"Velocidad ciclo\", min = 0.1, max = 10, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_DayNightCycle\" },\
        -- C. Fog\
        { tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_NoFog\", type = \"toggle\", text = \"Sin fog\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogStart\", type = \"slider\", text = \"Fog inicio\", min = 0, max = 2000, default = 0, suffix = \"st\", dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogEnd\", type = \"slider\", text = \"Fog fin\", min = 100, max = 10000, default = 2500, suffix = \"st\", dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Fog\", side = \"Right\", flag = \"World_FogColor\", type = \"colorpicker\", text = \"Color fog\", default = C(190, 195, 210), dependsOn = \"World_Enabled\" },\
        -- D. Atmosphere\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_Atmosphere\", type = \"toggle\", text = \"Atmosfera (reemplaza fog)\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.3, decimals = 3, dependsOn = \"World_Atmosphere\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmOffset\", type = \"slider\", text = \"Offset\", min = 0, max = 1, default = 0.25, decimals = 2, dependsOn = \"World_Atmosphere\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmGlare\", type = \"slider\", text = \"Glare\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmHaze\", type = \"slider\", text = \"Haze\", min = 0, max = 10, default = 0, decimals = 1, dependsOn = \"World_Atmosphere\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmColor\", type = \"colorpicker\", text = \"Color\", default = C(199, 199, 199), dependsOn = \"World_Atmosphere\" },\
        { tab = \"Mundo\", group = \"Atmosphere\", side = \"Right\", flag = \"World_AtmDecay\", type = \"colorpicker\", text = \"Decay\", default = C(106, 112, 125), dependsOn = \"World_Atmosphere\" },\
        -- E. Post-FX\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Tint\", type = \"toggle\", text = \"Tinte (ColorCorrection)\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintBrightness\", type = \"slider\", text = \"Brillo\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintContrast\", type = \"slider\", text = \"Contraste\", min = -1, max = 1, default = 0, decimals = 2, dependsOn = \"World_Tint\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintSaturation\", type = \"slider\", text = \"Saturacion\", min = -1, max = 3, default = 0, decimals = 2, dependsOn = \"World_Tint\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_TintColor\", type = \"colorpicker\", text = \"Color\", default = C(255, 255, 255), dependsOn = \"World_Tint\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowHue\", type = \"toggle\", text = \"Rainbow hue\", default = false, dependsOn = \"World_Tint\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_RainbowSpeed\", type = \"slider\", text = \"Rainbow vel\", min = 0.05, max = 5, default = 1, decimals = 2, dependsOn = \"World_RainbowHue\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_Bloom\", type = \"toggle\", text = \"Bloom\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 5, default = 0.4, decimals = 2, dependsOn = \"World_Bloom\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomSize\", type = \"slider\", text = \"Tamano\", min = 0, max = 56, default = 24, dependsOn = \"World_Bloom\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_BloomThreshold\", type = \"slider\", text = \"Umbral\", min = 0, max = 3, default = 0.95, decimals = 2, dependsOn = \"World_Bloom\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRays\", type = \"toggle\", text = \"Rayos de sol\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysIntensity\", type = \"slider\", text = \"Intensidad\", min = 0, max = 1, default = 0.05, decimals = 3, dependsOn = \"World_SunRays\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_SunRaysSpread\", type = \"slider\", text = \"Dispersion\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_SunRays\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoF\", type = \"toggle\", text = \"Depth of Field\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFocus\", type = \"slider\", text = \"Foco\", min = 0, max = 500, default = 25, dependsOn = \"World_DoF\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFRadius\", type = \"slider\", text = \"Radio foco\", min = 0, max = 100, default = 10, dependsOn = \"World_DoF\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFNear\", type = \"slider\", text = \"Near\", min = 0, max = 1, default = 0, decimals = 2, dependsOn = \"World_DoF\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_DoFFar\", type = \"slider\", text = \"Far\", min = 0, max = 1, default = 0.75, decimals = 2, dependsOn = \"World_DoF\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlur\", type = \"toggle\", text = \"Blur mundo\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_WorldBlurSize\", type = \"slider\", text = \"Fuerza\", min = 0, max = 40, default = 12, dependsOn = \"World_WorldBlur\" },\
        { tab = \"Mundo\", group = \"Post-FX\", side = \"Right\", flag = \"World_KillGamePostFX\", type = \"toggle\", text = \"Matar post-FX del juego\", default = false, dependsOn = \"World_Enabled\" },\
        -- J. Visibilidad\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_Advanced\", type = \"toggle\", text = \"Avanzado (agresivo)\", default = false, dependsOn = \"World_Enabled\", tooltip = \"Toca el mapa; usar con criterio\" },\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_KillParticles\", type = \"toggle\", text = \"Matar particulas del mapa\", default = false, dependsOn = \"World_Advanced\" },\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_ForceSmoothPlastic\", type = \"toggle\", text = \"Forzar SmoothPlastic\", default = false, dependsOn = \"World_Advanced\" },\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparent\", type = \"toggle\", text = \"Mapa transparente\", default = false, dependsOn = \"World_Advanced\" },\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_MapTransparentAmount\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.6, decimals = 2, dependsOn = \"World_MapTransparent\" },\
        { tab = \"Mundo\", group = \"Visibilidad\", side = \"Left\", flag = \"World_NoTextures\", type = \"toggle\", text = \"Sin texturas/decals\", default = false, dependsOn = \"World_Advanced\" },\
        -- ================= Tab \"Cielo & Clima\" =================\
        -- F. Cielo / Celestial\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_NoSky\", type = \"toggle\", text = \"Sin cuerpos celestes\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_StarCount\", type = \"slider\", text = \"Estrellas\", min = 0, max = 5000, default = 3000, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_CustomSkybox\", type = \"toggle\", text = \"Skybox custom\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Up\", type = \"textbox\", text = \"Up\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Dn\", type = \"textbox\", text = \"Down\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Lf\", type = \"textbox\", text = \"Left\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Rt\", type = \"textbox\", text = \"Right\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Bk\", type = \"textbox\", text = \"Back\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_Skybox_Ft\", type = \"textbox\", text = \"Front\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunTextureId\", type = \"textbox\", text = \"Sol textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonTextureId\", type = \"textbox\", text = \"Luna textura\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_SunAngularSize\", type = \"slider\", text = \"Sol tamano\", min = 0, max = 90, default = 21, dependsOn = \"World_CustomSkybox\" },\
        { tab = \"Cielo & Clima\", group = \"Cielo\", side = \"Left\", flag = \"World_MoonAngularSize\", type = \"slider\", text = \"Luna tamano\", min = 0, max = 90, default = 11, dependsOn = \"World_CustomSkybox\" },\
        -- G. Nubes\
        { tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_Clouds\", type = \"toggle\", text = \"Nubes custom\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_NoClouds\", type = \"toggle\", text = \"Sin nubes\", default = false, dependsOn = \"World_Clouds\" },\
        { tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudCover\", type = \"slider\", text = \"Cobertura\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"World_Clouds\" },\
        { tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudDensity\", type = \"slider\", text = \"Densidad\", min = 0, max = 1, default = 0.7, decimals = 2, dependsOn = \"World_Clouds\" },\
        { tab = \"Cielo & Clima\", group = \"Nubes\", side = \"Left\", flag = \"World_CloudColor\", type = \"colorpicker\", text = \"Color nubes\", default = C(255, 255, 255), dependsOn = \"World_Clouds\" },\
        -- H. Terrain / Agua\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterEnable\", type = \"toggle\", text = \"Editar agua\", default = false, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterColor\", type = \"colorpicker\", text = \"Color agua\", default = C(12, 84, 92), dependsOn = \"World_WaterEnable\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.3, decimals = 2, dependsOn = \"World_WaterEnable\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterReflectance\", type = \"slider\", text = \"Reflectancia\", min = 0, max = 1, default = 1, decimals = 2, dependsOn = \"World_WaterEnable\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSize\", type = \"slider\", text = \"Olas tamano\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_WaterEnable\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_WaterWaveSpeed\", type = \"slider\", text = \"Olas velocidad\", min = 0, max = 20, default = 10, decimals = 1, dependsOn = \"World_WaterEnable\" },\
        { tab = \"Cielo & Clima\", group = \"Terrain / Agua\", side = \"Right\", flag = \"World_TerrainDecoration\", type = \"toggle\", text = \"Decoracion terrain\", default = true, dependsOn = \"World_WaterEnable\" },\
        -- I. Clima\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Weather\", type = \"toggle\", text = \"Clima\", default = false, keybind = true, dependsOn = \"World_Enabled\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherMode\", type = \"dropdown\", text = \"Tipo\", values = { \"Lluvia\", \"Lluvia fuerte\", \"Nieve\", \"Niebla\", \"Ceniza\", \"Luciérnagas\", \"Custom\" }, default = \"Lluvia\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherCustomTex\", type = \"textbox\", text = \"Textura custom\", placeholder = \"rbxassetid://\", default = \"\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherColor\", type = \"colorpicker\", text = \"Color\", default = C(220, 230, 255), dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherTransparency\", type = \"slider\", text = \"Transparencia\", min = 0, max = 1, default = 0.35, decimals = 2, dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherGlow\", type = \"slider\", text = \"Brillo propio\", min = 0, max = 1, default = 0.15, decimals = 2, dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherDensity\", type = \"slider\", text = \"Densidad\", min = 0.1, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSpeed\", type = \"slider\", text = \"Velocidad\", min = 0.1, max = 3, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherSize\", type = \"slider\", text = \"Tamano\", min = 0.2, max = 4, default = 1, decimals = 2, suffix = \"x\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherArea\", type = \"slider\", text = \"Area\", min = 30, max = 200, default = 90, suffix = \"st\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_WeatherWindDir\", type = \"slider\", text = \"Viento (dir)\", min = 0, max = 360, default = 0, suffix = \"deg\", dependsOn = \"World_Weather\" },\
        { tab = \"Cielo & Clima\", group = \"Clima\", side = \"Right\", flag = \"World_Lightning\", type = \"toggle\", text = \"Relampagos\", default = false, dependsOn = \"World_Weather\" },\
        -- K. Presets\
        { tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", flag = \"World_PresetSelect\", type = \"dropdown\", text = \"Preset\", values = { \"Competitivo\", \"Cinematográfico\", \"Día\", \"Noche\", \"Atardecer\", \"Niebla\" }, default = \"Competitivo\", dependsOn = \"World_Enabled\" },\
    }\
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
    -- filas de accion que necesitan la instancia world (presets)\
    local function presetRows(world)\
        return {\
            { tab = \"Cielo & Clima\", group = \"Presets\", side = \"Right\", type = \"button\", text = \"Aplicar preset\",\
                action = function() world:ApplyPreset(world:Get(\"World_PresetSelect\")) end },\
        }\
    end\
\
    -- World:Attach(Library, Window, opts) -> world\
    -- opts: { adapter=\"claudeui\"|\"primordial\", profile=\"rivals\", services=... }\
    function GV.Attach(Library, Window, opts)\
        opts = opts or {}\
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or \"claudeui\"]\
        assert(adapter, \"adapter no encontrado\")\
        local world = GV.World.new({ services = opts.services })\
        if opts.profile then world:UseProfile(GV.Profiles[opts.profile]) end\
        local schema = {}\
        for _, r in ipairs(GV.Schema) do table.insert(schema, r) end\
        if world._profileSchema then for _, r in ipairs(world._profileSchema) do table.insert(schema, r) end end\
        for _, r in ipairs(presetRows(world)) do table.insert(schema, r) end\
        world._uiHandles = GV.Renderer.build(adapter, Window, schema, world)\
        world:Init()\
        return world\
    end\
end\
"
local f = loadstring(chunk, '@entry/attach.lua')(); f(GV) end
GV._defaultAdapter = 'claudeui'
return { Attach = GV.Attach, _GV = GV }
