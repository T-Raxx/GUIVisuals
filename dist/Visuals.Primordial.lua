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
do local chunk = "-- core/tween.lua — motor de tween para Drawing/Instance props que TweenService no puede animar\r\
-- (Drawing no es un Instance real). Port de jujudotlol.lua L463-529 (tween/color3_lerp/easing),\r\
-- adaptado a un modelo data-driven pull (GV.tweenStep corrido desde el heartbeat del modulo\r\
-- consumidor) en vez de push-into-global-heartbeat como el original.\r\
--\r\
-- API:\r\
--   GV.Tween(obj, props, easing, dur)  -- registra 1 entrada por propiedad. props = { Prop = target, ... }\r\
--   GV.tweenStep(now, dt)              -- avanza todas las entradas activas; snap + remove al completar\r\
--   GV.Ease(style, t01)                -- curva de easing pura (0..1 -> 0..1), expuesta por si hace falta\r\
--\r\
-- Dedup por obj+prop: una nueva llamada GV.Tween sobre el mismo obj+prop reemplaza la anterior\r\
-- (igual que el `old_tween` lookup+remove de juju).\r\
return function(GV)\r\
    local function color3_lerp(a, b, t) return a:Lerp(b, t) end\r\
    GV.Color3Lerp = color3_lerp\r\
\r\
    -- easing: exponential / quad / circular (default) / sine. juju usaba 355/113 como aprox de pi\r\
    -- (artefacto de ofuscacion); acá se usa math.pi (mismo efecto visual, mas preciso).\r\
    local function easeValue(style, t)\r\
        if t < 0 then t = 0 elseif t > 1 then t = 1 end\r\
        if style == \"exponential\" then\r\
            return t >= 1 and 1 or (1 - 2 ^ (-10 * t))\r\
        elseif style == \"quad\" then\r\
            return t * t\r\
        elseif style == \"sine\" then\r\
            if t < 0.5 then return 0.5 * math.sin(t * math.pi)\r\
            else return 0.5 + 0.5 * (1 - math.cos((t - 0.5) * math.pi)) end\r\
        else -- \"circular\" (default, matchea el fallback de juju)\r\
            local v = 1 - (t - 1) ^ 2\r\
            return math.sqrt(v < 0 and 0 or v)\r\
        end\r\
    end\r\
    GV.Ease = easeValue\r\
\r\
    -- active[prop][obj] = entry. Dict anidado en vez de closures individuales (mismo resultado:\r\
    -- 1 entrada activa por par obj+prop, se pisa sola en un nuevo GV.Tween sobre el mismo par).\r\
    local active = {}\r\
    GV._tweens = active\r\
\r\
    function GV.Tween(obj, props, easing, dur)\r\
        if not obj or not props then return end\r\
        dur = (dur and dur > 0) and dur or 0.001\r\
        local now = os.clock()\r\
        for prop, target in pairs(props) do\r\
            local byProp = active[prop]\r\
            if not byProp then byProp = {}; active[prop] = byProp end\r\
            local ok, old = pcall(function() return obj[prop] end)\r\
            if ok then\r\
                byProp[obj] = { obj = obj, prop = prop, from = old, to = target,\r\
                    start = now, dur = dur, easing = easing or \"circular\" }\r\
            end\r\
        end\r\
    end\r\
\r\
    function GV.tweenStep(now, dt)\r\
        now = now or os.clock()\r\
        for prop, byProp in pairs(active) do\r\
            for obj, tw in pairs(byProp) do\r\
                local t = (tw.dur > 0) and ((now - tw.start) / tw.dur) or 1\r\
                local done = t >= 1\r\
                local a = easeValue(tw.easing, done and 1 or t)\r\
                local ok = pcall(function()\r\
                    if done then\r\
                        obj[tw.prop] = tw.to\r\
                    elseif typeof(tw.from) == \"Color3\" then\r\
                        obj[tw.prop] = color3_lerp(tw.from, tw.to, a)\r\
                    elseif typeof(tw.from) == \"Vector2\" or typeof(tw.from) == \"Vector3\" or typeof(tw.from) == \"number\" then\r\
                        obj[tw.prop] = tw.from + (tw.to - tw.from) * a\r\
                    else\r\
                        obj[tw.prop] = tw.to\r\
                    end\r\
                end)\r\
                if done or not ok then byProp[obj] = nil end\r\
            end\r\
        end\r\
    end\r\
end\r\
"
local f = loadstring(chunk, '@core/tween.lua')(); f(GV) end
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
        local active = (self:_flag(\"Hitmarker\", false) and self._hitUntil and tick() < self._hitUntil) and true or false\r\
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
do local chunk = "-- core/combat.lua — modulo \"combat\": tracers, hitmarker 2D/3D, damage numbers, target ring,\r\
-- hit particles, hit chams (Tasks 3-8 del combat-vfx-port). Task 1 = solo scaffold: carga,\r\
-- se engancha a provider.onShot/onHit, :_update no-op salvo GV.tweenStep. Sin render aun.\r\
-- Skeleton mirror de core/selffx.lua (misma convencion de modulo Attach-instanciable).\r\
--\r\
-- Task 3 (Hit Tracers, este bloque): port de jujudotlol.lua L13276-13303 (menu) + L13364-13547\r\
-- (beams bank / do_beam_bullet_tracer / do_line_bullet_tracer). Disparo: provider.onShot\r\
-- (origin, hitPos, isLocal) <- LIP.Weapon.fireOne en cada op14.\r\
--\r\
-- Task 4 (Hitmarker 3D + 2D, este bloque): port de jujudotlol.lua L13322-13335 (menu) +\r\
-- L14965-15085 (do_d3_hit_marker, cruz anclada al punto de impacto en world-space) + L15089-15200\r\
-- (do_d2_hit_marker, misma cruz fija en el centro de pantalla). Disparo: provider.onHit\r\
-- (player, part, damage, lethal) <- LIP.onHit. juju duplica los parametros por marker (3D/2D);\r\
-- acá se comparte 1 solo set (Combat_Marker*) para ambos, permitido explicitamente por el brief.\r\
--\r\
-- Task 5 (Damage Numbers, este bloque): port de jujudotlol.lua L13314-13321 (menu) + L14875-\r\
-- 14961 (do_damage_number). Disparo: mismo provider.onHit que Task 4. Texto = SOLO el valor\r\
-- numerico de damage redondeado -- LiP no tiene el string de \"razon del resolver\" que juju\r\
-- concatena via damage_number_show_ragebot_data; ese toggle/flag NO se porta (brief, nota de\r\
-- adaptacion: no inventar un string equivalente).\r\
--\r\
-- Task 8 (Hit Chams, este bloque -- ULTIMA feature del combat-vfx-port): port de jujudotlol.lua\r\
-- L15205-15211 (menu) + L15319-15473 (do_hit_chams/do_hit_chams_outline + los 3 animadores de\r\
-- destroy). Disparo: mismo provider.onHit que Task 4/5/7, pero solo consume el arg `player` (el\r\
-- Player golpeado) -- clona su `.Character` completo, recolorea, y lo deja fadeando in-place.\r\
-- Adaptaciones vs juju (ver brief \"adapt, do not invent\"):\r\
--   1) juju resuelve `destroy_hit_chams` (la variante de animacion) como un upvalue MUTABLE leido\r\
--      recien cuando el `delay(hit_chams_lifetime, ...)` dispara -- si el usuario cambia el\r\
--      dropdown \"animation\" MIENTRAS un chams esta en vuelo, ese chams termina usando la variante\r\
--      NUEVA, no la que estaba seleccionada al momento del hit. Acá se lee Combat_ChamsAnimation\r\
--      UNA sola vez al spawn (mismo criterio que TracerType/DamageFont/ParticlePreset en Tasks\r\
--      3/5/7 -- todos los flags de \"estilo\" de este archivo se congelan al spawn).\r\
--   2) juju usa closures push-into-heartbeat (`heartbeat[#heartbeat+1]=tween_function` +\r\
--      `delay(...)`) para el ciclo fade -> destroy. Acá se adapta al patron per-frame ya\r\
--      establecido en este archivo (e.fading/e.fadeStart, ver Tasks 3-5) -- gatea SIEMPRE desde\r\
--      Combat:_update (ver nota grande sobre :_update mas abajo), evitando el equivalente de\r\
--      \"timer huerfano\" que tendria un closure de juju cuyo `delay` nunca dispara si el modulo\r\
--      se descarga a mitad de vuelo (Unload cubre esto explicitamente, ver mandato del brief).\r\
--   3) (encontrado en verificacion LIVE, Task 9) juju filtra por `ClassName == \"MeshPart\"` en\r\
--      ambas variantes (L15338 solido, L15397 outline+Head) porque su juego de referencia (Da\r\
--      Hood) es R15 con el rig entero hecho de MeshPart. LiP es R6 y NINGUNA parte del cuerpo\r\
--      (Head/Torso/brazos/piernas/HumanoidRootPart) es MeshPart -- son `Part` comunes -- asi que\r\
--      un filtro `MeshPart`-only deja el clon solido VACIO (0 partes recoloreadas, sin error) y\r\
--      el outline solo cubre Head (unico cubierto por el fallback de nombre). Se amplia el\r\
--      filtro de seleccion de partes de MeshPart a BasePart (Material/Color/Transparency/\r\
--      Anchored/CanCollide son props de BasePart, no exclusivas de MeshPart) en :_buildChamsSolid\r\
--      y :_buildChamsOutline -- `TextureID` SI es exclusiva de MeshPart, queda gateada a\r\
--      `part:IsA(\"MeshPart\")` adentro del pcall. HumanoidRootPart se excluye explicitamente\r\
--      (normalmente invisible/al centro del torso, sin valor visual) -- cae al mismo `else:\r\
--      destroy(part)` que ya la alcanzaba antes de este fix (no era MeshPart tampoco). Verificado\r\
--      LIVE ademas: LiP agrega 5 `RDCollision` Part por Character (Transparency=1,\r\
--      CanCollide=false -- hitboxes de ragdoll por-limb, invisibles); excluida junto a\r\
--      HumanoidRootPart (helper local `isChamsLimb`) para no dejarlas recoloreadas como cajas\r\
--      fantasma flotantes. El manejo de Accessory (busca un `MeshPart` hijo, lo extrae) NO\r\
--      cambia -- 1:1 juju, fuera de scope de este fix (accesorios con Handle no-MeshPart quedan\r\
--      intactos, igual que antes).\r\
return function(GV)\r\
    local Combat = {}\r\
    Combat.__index = Combat\r\
\r\
    -- ventanas de fade POST-lifetime (constantes fijas en juju, no expuestas en el menu):\r\
    -- linea L13518 (0.3s tras el lifetime, quad ease); beam L13414/destroy_beam (0.2s, quad ease).\r\
    local LINE_FADE_DUR = 0.3\r\
    local BEAM_FADE_DUR = 0.2\r\
    -- ventanas de fade POST-lifetime de los hitmarkers (constantes fijas en juju tambien, no\r\
    -- expuestas en el menu): 3D L15013 (0.3s, quad-out), 2D L15134 (0.2s, quad-out).\r\
    local MARKER3D_FADE_DUR = 0.3\r\
    local MARKER2D_FADE_DUR = 0.2\r\
    -- offset de \"rise\" del damage number (juju L14879 show_offset = Vector3(0,1.5,0)). A\r\
    -- diferencia de los fades de arriba, la ventana de fade-out del damage number NO es una\r\
    -- constante fija -- es proporcional al lifetime de cada instancia (ver :_spawnDamageNumber).\r\
    local DAMAGE_RISE_OFFSET = Vector3.new(0, 1.5, 0)\r\
\r\
    -- Task 8 -- Hit Chams: ventanas de fade fijas (constantes en juju, no expuestas en el menu --\r\
    -- mismo criterio que LINE_FADE_DUR/MARKER3D_FADE_DUR/MARKER2D_FADE_DUR arriba).\r\
    -- destroy_hit_chams_fade (juju L15233-15261): la curva de transparencia Y la ventana total\r\
    -- hasta destroy coinciden, ambas 0.25s. destroy_hit_chams_new_fade (juju L15265-15315): la\r\
    -- curva (transparencia + grow de Size) dura 0.15s, pero la ventana total hasta destroy sigue\r\
    -- siendo 0.25s (juju L15306 delay(0.25,...) en AMBAS variantes) -- tras completar la curva a\r\
    -- los 0.15s, el modelo queda congelado en el estado final (transparency=1, size maxima) el\r\
    -- resto de la ventana hasta el destroy real a los 0.25s. animType==\"none\" destruye de\r\
    -- inmediato al vencer el lifetime, sin ventana ni curva.\r\
    local CHAMS_FADE_CURVE_DUR = 0.25    -- animType == \"fade\"\r\
    local CHAMS_NEWFADE_CURVE_DUR = 0.15 -- animType == \"new fade\"\r\
    local CHAMS_TOTAL_FADE_DUR = 0.25    -- ventana total hasta destroy (ambas variantes con curva)\r\
    local CHAMS_GROW_SIZE = Vector3.new(1, 1, 1) -- juju L15263 `size = vector3_new(1,1,1)`\r\
    -- transparency base del clon (juju menu L15211 default_transparency=0.8 -- el colorpicker CF\r\
    -- de este proyecto no tiene componente de transparencia, ver nota identica en schema/\r\
    -- combat.lua Hit Chams / Hit Particles -- se porta como constante fija, no como fila de menu).\r\
    local CHAMS_TRANSPARENCY = 0.8\r\
\r\
    -- beams bank (juju L13364-13396, port 1:1 de props/valores por estilo). Se instancian LAZY\r\
    -- (1 vez por estilo, cacheadas) y se clonan por disparo -- igual patron que Aura:_template.\r\
    local function buildBeamStyle(name)\r\
        local b = Instance.new(\"Beam\")\r\
        if name == \"laser\" then\r\
            b.FaceCamera = true; b.TextureSpeed = 1.5; b.Width0 = 0.25; b.Width1 = 0.25\r\
            b.TextureLength = 2; b.LightEmission = 3; b.Brightness = 2.5\r\
            b.Texture = \"rbxassetid://12781800668\"\r\
        elseif name == \"light\" then\r\
            b.FaceCamera = true; b.TextureSpeed = 2; b.Width0 = 0.25; b.Width1 = 0.25\r\
            b.LightInfluence = 1; b.LightEmission = 3; b.Segments = 1\r\
            b.Texture = \"http://www.roblox.com/asset/?id=2382169232\"\r\
            b.TextureLength = 15; b.TextureMode = Enum.TextureMode.Wrap\r\
        elseif name == \"flow\" then\r\
            b.FaceCamera = true; b.TextureSpeed = 2.5; b.Width0 = 0.2; b.Width1 = 0.2\r\
            b.LightEmission = 3; b.Brightness = 5\r\
            b.Texture = \"rbxassetid://12788927812\"\r\
        else\r\
            b:Destroy(); return nil\r\
        end\r\
        return b\r\
    end\r\
\r\
    -- Task 7 -- Hit Particles: preset library (juju L14313-14820, do-block \"hit particle\").\r\
    -- ONE pooled anchored Part (juju L14316 hit_particle_part) holds ALL 10 preset emitters as\r\
    -- children, prebuilt once (juju builds them EAGER at module-load; acá se difiere a la primera\r\
    -- vez que se necesita -- ver :_ensureParticleLib mas abajo, mismo criterio lazy que\r\
    -- _beamTemplate/Aura:_template). do_hit_particle (juju L14770) solo mueve el Part y llama\r\
    -- :Emit(count) sobre los emitters del preset seleccionado -- no hace falta crear/destruir\r\
    -- Instances por hit, el pool entero vive fijo desde la 1ra creacion hasta :Unload.\r\
    --\r\
    -- Preset NO portado: \"custom .rbxm\" (juju menu L13347 use_custom_extensions + getcustomasset\r\
    -- L14800 -- carga un asset LOCAL del disco del usuario de juju). Esta abstraccion de proyecto\r\
    -- (provider/schema declarativo, sin filesystem picker en el menu) no expone un mecanismo\r\
    -- equivalente para que el usuario suba un .rbxm propio -- se omite, documentado acá y en el\r\
    -- schema (brief: \"otherwise omit and document\"). Los 10 presets built-in cubren el dropdown completo.\r\
    local function newParticle(parent, props)\r\
        local e = Instance.new(\"ParticleEmitter\")\r\
        for k, v in pairs(props) do e[k] = v end\r\
        e.Enabled = false -- todos los presets de juju traen Enabled=false explicito (fire-and-forget via :Emit, no stream continuo)\r\
        e.Parent = parent\r\
        return e\r\
    end\r\
\r\
    -- transcripcion 1:1 de juju L14325-14765 (mismos valores/texturas/curvas por preset). Cada\r\
    -- entrada = { emitter = <ParticleEmitter>, count = <n de juju particle[2], el arg de :Emit()> }.\r\
    local function buildHitParticlePresets(part)\r\
        return {\r\
            sparks = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Acceleration = Vector3.new(0, -50, 0),\r\
                    Color = ColorSequence.new({\r\
                        ColorSequenceKeypoint.new(0, Color3.new(1, 0.999969, 0.999985)),\r\
                        ColorSequenceKeypoint.new(0.25, Color3.new(0.333333, 1, 0)),\r\
                        ColorSequenceKeypoint.new(1, Color3.new(0.333333, 1, 0.498039)),\r\
                    }),\r\
                    Lifetime = NumberRange.new(0.5, 1),\r\
                    LightEmission = 1,\r\
                    Orientation = Enum.ParticleOrientation.VelocityParallel,\r\
                    Rate = 0,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0.6, 0), NumberSequenceKeypoint.new(0.5, 0.6, 0), NumberSequenceKeypoint.new(1, 0, 0),\r\
                    }),\r\
                    Speed = NumberRange.new(15, 15),\r\
                    SpreadAngle = Vector2.new(50, -50),\r\
                    Texture = \"http://www.roblox.com/asset/?id=18540695516\",\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.5, 0, 0), NumberSequenceKeypoint.new(1, 1, 0),\r\
                    }),\r\
                }), count = 30 },\r\
            },\r\
            bubble = {\r\
                { emitter = newParticle(part, {\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,\r\
                    Color = ColorSequence.new({\r\
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 255)),\r\
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 255)),\r\
                    }),\r\
                    LockedToPart = true,\r\
                    Rate = 1.5,\r\
                    Rotation = NumberRange.new(-5, 5),\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.464, 0.768750011920929), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    Texture = \"rbxassetid://17086075673\",\r\
                    Lifetime = NumberRange.new(0.450000001192092896, 0.450000001192092896),\r\
                    LightEmission = 1,\r\
                    Brightness = 5,\r\
                    Speed = NumberRange.new(0, 0),\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0.10000000149011612), NumberSequenceKeypoint.new(1, 6),\r\
                    }),\r\
                }), count = 1 },\r\
            },\r\
            orbs = {\r\
                { emitter = newParticle(part, {\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,\r\
                    RotSpeed = NumberRange.new(-10, 10),\r\
                    FlipbookFramerate = NumberRange.new(40, 40),\r\
                    Drag = 1,\r\
                    Rate = 1,\r\
                    Texture = \"rbxassetid://15011464541\",\r\
                    Rotation = NumberRange.new(-1000, 1000),\r\
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),\r\
                    SpreadAngle = Vector2.new(-1000, 1000),\r\
                    Lifetime = NumberRange.new(0.44999998807907104, 0.44999998807907104),\r\
                    LightEmission = 1,\r\
                    Brightness = 10,\r\
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,\r\
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5.5), NumberSequenceKeypoint.new(1, 5.5) }),\r\
                }), count = 3 },\r\
            },\r\
            air = {\r\
                { emitter = newParticle(part, {\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.PingPong,\r\
                    VelocityInheritance = 0.15000000596046448,\r\
                    Texture = \"rbxassetid://10536350143\",\r\
                    FlipbookFramerate = NumberRange.new(30, 30),\r\
                    Drag = 4.5,\r\
                    Rate = 1,\r\
                    Speed = NumberRange.new(0, 0),\r\
                    LightInfluence = 1,\r\
                    Acceleration = Vector3.new(1, 0, 1),\r\
                    LockedToPart = true,\r\
                    Lifetime = NumberRange.new(1, 1),\r\
                    LightEmission = 1,\r\
                    Brightness = 10,\r\
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,\r\
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 3) }),\r\
                }), count = 1 },\r\
            },\r\
            blood = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.5, 0.75),\r\
                    SpreadAngle = Vector2.new(90, 90),\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.125, 0.5), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    Color = ColorSequence.new(Color3.fromRGB(130, 0, 0)),\r\
                    Speed = NumberRange.new(5, 10),\r\
                    Size = NumberSequence.new(0.5, 2),\r\
                    Acceleration = Vector3.new(0, -20, 0),\r\
                    RotSpeed = NumberRange.new(-90, 90),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://241576804\",\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 25 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.25, 0.5),\r\
                    SpreadAngle = Vector2.new(360, 360),\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    Color = ColorSequence.new(Color3.fromRGB(100, 0, 0)),\r\
                    Speed = NumberRange.new(15, 25),\r\
                    Size = NumberSequence.new(0.125, 0.6874996),\r\
                    Acceleration = Vector3.new(0, -75, 0),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://4509687978\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityParallel,\r\
                }), count = 15 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.75, 0.75),\r\
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5037407, 0), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    Color = ColorSequence.new(Color3.fromRGB(130, 0, 0)),\r\
                    Speed = NumberRange.new(0.001, 0.001),\r\
                    ZOffset = 4,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.376, 2.0625), NumberSequenceKeypoint.new(1, 2.6875),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://16664856199\",\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 5 },\r\
            },\r\
            light = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    LightInfluence = 1,\r\
                    Lifetime = NumberRange.new(1, 1),\r\
                    LockedToPart = true,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2066, 0), NumberSequenceKeypoint.new(0.4947, 0),\r\
                        NumberSequenceKeypoint.new(0.7996, 0), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Speed = NumberRange.new(0, 0),\r\
                    ZOffset = 4,\r\
                    Size = NumberSequence.new(7.5, 7.5),\r\
                    RotSpeed = NumberRange.new(100, 100),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://271370648\",\r\
                }), count = 1 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    LightInfluence = 1,\r\
                    Lifetime = NumberRange.new(1, 1),\r\
                    LockedToPart = true,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4947, 0), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Speed = NumberRange.new(0, 0),\r\
                    ZOffset = 5,\r\
                    Size = NumberSequence.new(7.5, 7.5),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://13275495915\",\r\
                }), count = 2 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    LightInfluence = 1,\r\
                    Lifetime = NumberRange.new(1, 1),\r\
                    LockedToPart = true,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.504, 0.49375), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Speed = NumberRange.new(0, 0),\r\
                    ZOffset = 5,\r\
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 7.4375) }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://15267994078\",\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 3 },\r\
            },\r\
            lightning = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    FlipbookFramerate = NumberRange.new(17, 17),\r\
                    Lifetime = NumberRange.new(0.1, 1),\r\
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,\r\
                    LockedToPart = true,\r\
                    Speed = NumberRange.new(0.01, 0.01),\r\
                    Brightness = 15,\r\
                    ZOffset = 3,\r\
                    Size = NumberSequence.new(5, 5),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://14582813693\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 5 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.4, 0.4),\r\
                    SpreadAngle = Vector2.new(360, 360),\r\
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),\r\
                    LightEmission = 1,\r\
                    Drag = 15,\r\
                    Speed = NumberRange.new(0.0099, 0.0099),\r\
                    Brightness = 5,\r\
                    ZOffset = 4,\r\
                    Size = NumberSequence.new(5, 5),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://13305806509\",\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,\r\
                }), count = 2 },\r\
            },\r\
            blackflash = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    LightInfluence = 0.2,\r\
                    Lifetime = NumberRange.new(0.1, 0.25),\r\
                    SpreadAngle = Vector2.new(360, 360),\r\
                    LockedToPart = true,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.0375, 0.291), NumberSequenceKeypoint.new(0.131, 0.602),\r\
                        NumberSequenceKeypoint.new(0.259, 0.788), NumberSequenceKeypoint.new(0.403, 0.906), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(255, 17, 17)),\r\
                    Speed = NumberRange.new(0.0135, 0.0135),\r\
                    Brightness = 10,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.0645, 5.37), NumberSequenceKeypoint.new(0.236, 11.31),\r\
                        NumberSequenceKeypoint.new(0.586, 15.7), NumberSequenceKeypoint.new(1, 18.56),\r\
                    }),\r\
                    RotSpeed = NumberRange.new(-20, 20),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://10149702982\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 3 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.07, 0.2),\r\
                    SpreadAngle = Vector2.new(-360, 360),\r\
                    LockedToPart = true,\r\
                    LightEmission = 1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(255, 17, 17)),\r\
                    Speed = NumberRange.new(0.0197, 0.0197),\r\
                    Brightness = 15,\r\
                    ZOffset = 3.96,\r\
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 25.55), NumberSequenceKeypoint.new(1, 0) }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://15446757636\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityParallel,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 3 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.6, 1.3),\r\
                    SpreadAngle = Vector2.new(180, 180),\r\
                    LockedToPart = true,\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.457, 0.9625), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Drag = 10,\r\
                    Speed = NumberRange.new(72.6, 290.5),\r\
                    Brightness = 0.75,\r\
                    ZOffset = 3.46,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0.58), NumberSequenceKeypoint.new(0.5, 16.25), NumberSequenceKeypoint.new(1, 20.34),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://15883763954\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityParallel,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 3 },\r\
            },\r\
            gravity = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.6, 0.6),\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.578, 0.7375), NumberSequenceKeypoint.new(1, 1),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(114, 44, 255)),\r\
                    Speed = NumberRange.new(0.0629, 0.0629),\r\
                    Brightness = 4,\r\
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 35.77) }),\r\
                    RotSpeed = NumberRange.new(500, 800),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://8030746658\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityPerpendicular,\r\
                    Rotation = NumberRange.new(-360, 360),\r\
                }), count = 3 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.85, 1),\r\
                    SpreadAngle = Vector2.new(-30, 30),\r\
                    LightEmission = 1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(81, 62, 189)),\r\
                    Speed = NumberRange.new(5, 10),\r\
                    Brightness = 4,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.167, 0.875), NumberSequenceKeypoint.new(1, 0),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://8030760338\",\r\
                }), count = 35 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.2, 0.4),\r\
                    Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.26, 0), NumberSequenceKeypoint.new(1, 0),\r\
                    }),\r\
                    LightEmission = 1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(114, 44, 255)),\r\
                    Drag = 1,\r\
                    Speed = NumberRange.new(5, 10),\r\
                    Brightness = 3,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.11, 4.0975), NumberSequenceKeypoint.new(1, 0),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://8801300936\",\r\
                    Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,\r\
                }), count = 20 },\r\
            },\r\
            meteor = {\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.1, 0.3),\r\
                    FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,\r\
                    SpreadAngle = Vector2.new(40, 40),\r\
                    LightEmission = 0.1,\r\
                    Color = ColorSequence.new(Color3.fromRGB(72, 26, 255)),\r\
                    Drag = 9,\r\
                    Speed = NumberRange.new(100, 200),\r\
                    Brightness = 4.57,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 14.17), NumberSequenceKeypoint.new(0.374, 16.19), NumberSequenceKeypoint.new(1, 10.31),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"http://www.roblox.com/asset/?id=13136714025\",\r\
                    FlipbookMode = Enum.ParticleFlipbookMode.OneShot,\r\
                    Rotation = NumberRange.new(0, 360),\r\
                }), count = 30 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.15, 0.25),\r\
                    SpreadAngle = Vector2.new(30, 30),\r\
                    LockedToPart = true,\r\
                    LightEmission = 0.6,\r\
                    Color = ColorSequence.new(Color3.fromRGB(69, 44, 255)),\r\
                    Drag = 26,\r\
                    Speed = NumberRange.new(0.13, 0.13),\r\
                    Brightness = 6.885,\r\
                    ZOffset = 3,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.265, 1.16), NumberSequenceKeypoint.new(0.48, 7.56),\r\
                        NumberSequenceKeypoint.new(0.72, 1.4), NumberSequenceKeypoint.new(1, 0),\r\
                    }),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://16722791958\",\r\
                    Rotation = NumberRange.new(150, 150),\r\
                }), count = 50 },\r\
                { emitter = newParticle(part, {\r\
                    Name = \"\\0\",\r\
                    Lifetime = NumberRange.new(0.2, 0.4),\r\
                    SpreadAngle = Vector2.new(50, 50),\r\
                    Color = ColorSequence.new(Color3.fromRGB(84, 41, 255)),\r\
                    Drag = 8,\r\
                    Speed = NumberRange.new(141.44, 183.87),\r\
                    Brightness = 12,\r\
                    Size = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.259, 1.77), NumberSequenceKeypoint.new(1, 0),\r\
                    }),\r\
                    Acceleration = Vector3.new(0, -282.88, 0),\r\
                    RotSpeed = NumberRange.new(-30, 30),\r\
                    Rate = 0,\r\
                    Texture = \"rbxassetid://11995504618\",\r\
                    Orientation = Enum.ParticleOrientation.VelocityParallel,\r\
                }), count = 40 },\r\
            },\r\
        }\r\
    end\r\
\r\
    function Combat.new(opts)\r\
        opts = opts or {}\r\
        local svc = opts.services or {\r\
            Players = game:GetService(\"Players\"),\r\
            RunService = game:GetService(\"RunService\"),\r\
            Workspace = workspace,\r\
            Terrain = workspace:FindFirstChildOfClass(\"Terrain\"),\r\
        }\r\
        return setmetatable({\r\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\r\
            Conns = {}, Drawings = {}, _made = {}, Loaded = false,\r\
            -- Task 3: pool de Drawings (line mode, reusado entre disparos) + listas de tracers\r\
            -- activos (line/beam) + cache de templates de Beam por estilo.\r\
            _linePool = {}, _activeLine = {}, _activeBeam = {}, _beamTemplates = {},\r\
            -- Task 4: pools de bundles cruz (8 Drawing Line c/u: 4 lineas + 4 outlines) + listas\r\
            -- de hitmarkers activos. 3D y 2D tienen pool/lista propios porque conviven al mismo\r\
            -- tiempo (un hit puede spawnear ambos si los 2 toggles estan ON).\r\
            _marker3DPool = {}, _active3D = {}, _marker2DPool = {}, _active2D = {},\r\
            -- Task 5: pool de Drawings \"Text\" (1 sola Drawing por numero, el outline vive en la\r\
            -- misma Drawing via Outline/OutlineColor) + lista de damage numbers activos.\r\
            _damagePool = {}, _activeDamage = {},\r\
            -- Task 6: _ring queda nil hasta el primer :_updateRing -> :_ensureRing lo fabrica LAZY\r\
            -- (mismo criterio lazy que _beamTemplates/_lineBundle arriba) como\r\
            -- { lines = {32 Drawing \"Line\"}, radius = {r=...}, oldRadius = ..., bounce = nil|{...} }\r\
            -- -- pool FIJO (no pool-de-prestamo), ver nota grande sobre :_updateRing.\r\
            -- Task 8: lista de clones de char (hit chams) activos + referencia al ULTIMO clone\r\
            -- spawneado (juju `last_model`, ver Combat:_spawnChams) para la logica only_last_hit --\r\
            -- a diferencia de los pools de Tasks 3-5, no hay pool-de-prestamo acá (cada hit clona\r\
            -- un Model nuevo, se destruye al terminar su fade -- mismo patron no-pooled que\r\
            -- self._particleLib del Task 7, pero POR-HIT en vez de 1-sola-vez).\r\
            _activeChams = {}, _lastChams = nil,\r\
        }, Combat)\r\
    end\r\
\r\
    function Combat:Set(k, v) self.Flags[k] = v end\r\
    function Combat:Get(k) return self.Flags[k] end\r\
    function Combat:_flag(k, d)\r\
        local v = self.Flags[\"Combat_\" .. k]; if v ~= nil then return v end; return d\r\
    end\r\
    function Combat:UseProfile(p) if p then self._provider = p end end\r\
\r\
    function Combat:_draw(class, props)\r\
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end\r\
        local o = Drawing.new(class); o.Visible = false\r\
        if props then for k, v in pairs(props) do o[k] = v end end\r\
        table.insert(self.Drawings, o); return o\r\
    end\r\
\r\
    -- resuelve un campo del provider que puede venir como Signal directa O function()->Signal.\r\
    -- El perfil lifeinprison expone onShot/onHit como funciones LAZY a proposito: el bundle de\r\
    -- GUIWorkspace se construye (y corre este modulo) ANTES de que Core.State cree\r\
    -- getgenv().LIP.onShot/onHit -> capturar el valor directo en ese momento quedaria nil para\r\
    -- siempre. Resolver en Init() (que corre despues, desde main.lua) evita el problema.\r\
    local function resolveSignal(v)\r\
        if type(v) == \"function\" then local ok, r = pcall(v); return ok and r or nil end\r\
        return v\r\
    end\r\
\r\
    -- resuelve provider.target() de forma segura (mismo espiritu pcall-wrap que resolveSignal\r\
    -- arriba, pero para el accessor de Task 6 -- ver interfaz en el brief: \"provider.target()\r\
    -- -> Player|nil\", una funcion directa, no una Signal). Usado SOLO por :_updateRing.\r\
    local function resolveTarget(provider)\r\
        if not provider or type(provider.target) ~= \"function\" then return nil end\r\
        local ok, t = pcall(provider.target)\r\
        if ok and t then return t end\r\
        return nil\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 3 -- Hit Tracers: pool/template getters\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_beamTemplate(style)\r\
        local cached = self._beamTemplates[style]\r\
        if cached ~= nil then return cached or nil end\r\
        local ok, b = pcall(buildBeamStyle, style)\r\
        local result = (ok and b) or false\r\
        self._beamTemplates[style] = result\r\
        return result or nil\r\
    end\r\
\r\
    -- pool de bundles {line, outline} (2 Drawing \"Line\" por tracer). Reusado entre disparos --\r\
    -- no se allocan Drawings nuevas mientras haya bundles libres.\r\
    function Combat:_lineBundle()\r\
        local b = table.remove(self._linePool)\r\
        if b then return b end\r\
        return { line = self:_draw(\"Line\", { Thickness = 1 }), outline = self:_draw(\"Line\", { Thickness = 3 }) }\r\
    end\r\
    function Combat:_releaseLineBundle(b)\r\
        b.line.Visible = false; b.outline.Visible = false\r\
        table.insert(self._linePool, b)\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 3 -- Hit Tracers: spawn (line / beam)\r\
    ------------------------------------------------------------------------------------------\r\
    -- line mode: 2 Drawing \"Line\" (juju L13460 do_line_bullet_tracer), proyectadas cada frame en\r\
    -- :_updateLineTracers (world->viewport + edge-clamp si Z<0). Fade: GV.Tween Transparency->0\r\
    -- (Drawing: 1=opaco/0=invisible, ver comentario ESP.lua) sobre LINE_FADE_DUR tras el lifetime.\r\
    function Combat:_spawnLineTracer(origin, hitPos, now)\r\
        local b = self:_lineBundle()\r\
        b.line.Color = GV.Color.fade(self.Flags, \"Combat_TracerColor\", now)\r\
        b.line.Transparency = 1; b.line.Visible = true\r\
        b.outline.Color = GV.Color.fade(self.Flags, \"Combat_TracerOutline\", now)\r\
        b.outline.Transparency = 1; b.outline.Visible = true\r\
        table.insert(self._activeLine, {\r\
            bundle = b, origin = origin, hitPos = hitPos, spawnT = now,\r\
            lifetime = self:_flag(\"TracerLifetime\", 0.8), fading = false,\r\
        })\r\
    end\r\
\r\
    -- beam mode: clona el estilo de Beam elegido (juju L13438 do_beam_bullet_tracer), 2\r\
    -- Attachment (origin/hitPos) parentados a Terrain. Fade: destroy_beam (juju L13406) --\r\
    -- reconstruye el NumberSequence de Transparency cada frame desde un alpha 0->1 tweeneado\r\
    -- via GV.Tween sobre una tabla Lua plana (GV.Tween/tweenStep solo interpolan numeros/\r\
    -- Vector2/Vector3/Color3 -- un NumberSequence no es interpolable directo, se recompone acá).\r\
    --\r\
    -- NOTA: beam/att0/att1 NO se registran en self._made (a diferencia de otros modulos) -- son\r\
    -- transitorios y ya viven en self._activeBeam mientras estan vivos (bounded: se remueven de\r\
    -- ahi apenas :_updateBeamTracers los destruye). Si quedaran ademas en self._made, esa lista\r\
    -- creceria sin limite durante una sesion larga (nunca se poda entre disparos, solo en\r\
    -- Unload) -- self._activeBeam ya es el safety net de Unload para instancias de beam.\r\
    function Combat:_spawnBeamTracer(origin, hitPos, now)\r\
        local style = self:_flag(\"TracerStyle\", \"laser\")\r\
        local template = self:_beamTemplate(style)\r\
        if not template then return end\r\
        local beam = template:Clone()\r\
        local mainColor = GV.Color.fade(self.Flags, \"Combat_TracerColor\", now)\r\
        local gradColor = GV.Color.fade(self.Flags, \"Combat_TracerGradient\", now)\r\
        beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, mainColor), ColorSequenceKeypoint.new(1, gradColor) })\r\
        beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
        local terrain = self.Services.Terrain or self.Services.Workspace.Terrain\r\
        local att0 = Instance.new(\"Attachment\"); att0.CFrame = CFrame.new(origin); att0.Parent = terrain\r\
        local att1 = Instance.new(\"Attachment\"); att1.CFrame = CFrame.new(hitPos); att1.Parent = terrain\r\
        beam.Attachment0 = att0; beam.Attachment1 = att1; beam.Parent = terrain\r\
        table.insert(self._activeBeam, {\r\
            beam = beam, att0 = att0, att1 = att1, spawnT = now,\r\
            lifetime = self:_flag(\"TracerLifetime\", 0.8), fading = false, fadeAlpha = 0,\r\
        })\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 3 -- Hit Tracers: per-frame update (proyeccion + fade)\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_updateLineTracers(now)\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        local list = self._activeLine\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            local b = e.bundle\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                GV.Tween(b.line, { Transparency = 0 }, \"quad\", LINE_FADE_DUR)\r\
                GV.Tween(b.outline, { Transparency = 0 }, \"quad\", LINE_FADE_DUR)\r\
            end\r\
            if e.fading and (now - e.fadeStart) >= LINE_FADE_DUR then\r\
                self:_releaseLineBundle(b)\r\
                table.remove(list, i)\r\
            elseif cam then\r\
                -- world->viewport cada frame (camara puede moverse durante el lifetime) +\r\
                -- edge-clamp detras de camara (juju L13505-13511: refleja al lado opuesto de\r\
                -- pantalla, clampeado a los bordes, en vez de ocultar).\r\
                local p1, on1 = cam:WorldToViewportPoint(e.origin)\r\
                local p2, on2 = cam:WorldToViewportPoint(e.hitPos)\r\
                if not on1 and not on2 then\r\
                    b.line.Visible = false; b.outline.Visible = false\r\
                else\r\
                    local vp = cam.ViewportSize\r\
                    local xh, yh = vp.X / 2, vp.Y / 2\r\
                    local from = (p1.Z < 0)\r\
                        and Vector2.new(math.clamp(xh + (xh - p1.X), 0, vp.X), math.clamp(yh + (yh - p1.Y), 0, vp.Y))\r\
                        or Vector2.new(p1.X, p1.Y)\r\
                    local to = (p2.Z < 0)\r\
                        and Vector2.new(math.clamp(xh + (xh - p2.X), 0, vp.X), math.clamp(yh + (yh - p2.Y), 0, vp.Y))\r\
                        or Vector2.new(p2.X, p2.Y)\r\
                    b.line.Visible = true; b.outline.Visible = true\r\
                    b.line.From = from; b.line.To = to\r\
                    -- outline levemente mas corto que la linea principal (juju L13530-13533)\r\
                    local diff = from - to\r\
                    local offset = diff.Magnitude > 0 and diff.Unit or Vector2.new(0, 0)\r\
                    b.outline.From = from + offset; b.outline.To = to - offset\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    function Combat:_updateBeamTracers(now)\r\
        local list = self._activeBeam\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                local ok, kps = pcall(function() return e.beam.Transparency.Keypoints end)\r\
                if ok and kps and #kps >= 2 then e.oldT0, e.oldT1 = kps[1].Value, kps[#kps].Value\r\
                else e.oldT0, e.oldT1 = 0, 0 end\r\
                GV.Tween(e, { fadeAlpha = 1 }, \"quad\", BEAM_FADE_DUR)\r\
            end\r\
            if e.fading then\r\
                pcall(function()\r\
                    e.beam.Transparency = NumberSequence.new({\r\
                        NumberSequenceKeypoint.new(0, e.oldT0 + (1 - e.oldT0) * e.fadeAlpha),\r\
                        NumberSequenceKeypoint.new(1, e.oldT1 + (1 - e.oldT1) * e.fadeAlpha),\r\
                    })\r\
                end)\r\
                if (now - e.fadeStart) >= BEAM_FADE_DUR then\r\
                    pcall(function() e.beam:Destroy() end)\r\
                    pcall(function() e.att0:Destroy() end)\r\
                    pcall(function() e.att1:Destroy() end)\r\
                    table.remove(list, i)\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 4 -- Hitmarker 3D + 2D: pool getters (bundle = cruz de 8 Drawing \"Line\": 4 lineas +\r\
    -- 4 outlines, mismo patron de pooling que _lineBundle de Task 3).\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_markerBundle(pool)\r\
        local b = table.remove(pool)\r\
        if b then return b end\r\
        local lines, outlines = {}, {}\r\
        for i = 1, 4 do\r\
            lines[i] = self:_draw(\"Line\", { ZIndex = 100 })\r\
            outlines[i] = self:_draw(\"Line\", { ZIndex = 99 })\r\
        end\r\
        return { lines = lines, outlines = outlines }\r\
    end\r\
    function Combat:_releaseMarkerBundle(pool, b)\r\
        for i = 1, 4 do b.lines[i].Visible = false; b.outlines[i].Visible = false end\r\
        table.insert(pool, b)\r\
    end\r\
\r\
    -- geometria de la cruz (juju L15021-15039 / L15142-15160, identica en 3D y 2D): 4 trazos\r\
    -- diagonales cortos, uno por esquina, apuntando desde ±10px hacia ±5px del centro -- deja un\r\
    -- hueco en el medio (no es una X continua ni un circulo).\r\
    function Combat:_layoutMarkerCross(b, x, y)\r\
        local corners = {\r\
            { x - 10, y - 10, x - 5, y - 5 },\r\
            { x + 10, y - 10, x + 5, y - 5 },\r\
            { x - 10, y + 10, x - 5, y + 5 },\r\
            { x + 10, y + 10, x + 5, y + 5 },\r\
        }\r\
        for i = 1, 4 do\r\
            local c = corners[i]\r\
            local from, to = Vector2.new(c[1], c[2]), Vector2.new(c[3], c[4])\r\
            b.lines[i].From, b.lines[i].To = from, to\r\
            b.outlines[i].From, b.outlines[i].To = from, to\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 4 -- Hitmarker 3D + 2D: spawn. Color: lethal (bool de provider.onHit) selecciona\r\
    -- Combat_MarkerLethal vs Combat_MarkerColor (juju L14974/L15098: player_data[player][18]).\r\
    -- Transparency=1 inicial (visible, ver convencion \"Drawing.Transparency: 1=opaco/0=invisible\"\r\
    -- documentada en ESP.lua y usada igual por los tracers de Task 3).\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_spawnMarker3D(pos, lethal, now)\r\
        local b = self:_markerBundle(self._marker3DPool)\r\
        local thickness = self:_flag(\"MarkerThickness\", 2)\r\
        local color = lethal and GV.Color.fade(self.Flags, \"Combat_MarkerLethal\", now)\r\
            or GV.Color.fade(self.Flags, \"Combat_MarkerColor\", now)\r\
        local outline = GV.Color.fade(self.Flags, \"Combat_MarkerOutline\", now)\r\
        for i = 1, 4 do\r\
            b.lines[i].Thickness = thickness; b.lines[i].Color = color\r\
            b.lines[i].Transparency = 1; b.lines[i].Visible = true\r\
            b.outlines[i].Thickness = thickness + 2; b.outlines[i].Color = outline\r\
            b.outlines[i].Transparency = 1; b.outlines[i].Visible = true\r\
        end\r\
        table.insert(self._active3D, {\r\
            bundle = b, pos = pos, spawnT = now,\r\
            lifetime = self:_flag(\"MarkerLifetime\", 0.7), fading = false,\r\
        })\r\
    end\r\
\r\
    function Combat:_spawnMarker2D(lethal, now)\r\
        local b = self:_markerBundle(self._marker2DPool)\r\
        local thickness = self:_flag(\"MarkerThickness\", 2)\r\
        local color = lethal and GV.Color.fade(self.Flags, \"Combat_MarkerLethal\", now)\r\
            or GV.Color.fade(self.Flags, \"Combat_MarkerColor\", now)\r\
        local outline = GV.Color.fade(self.Flags, \"Combat_MarkerOutline\", now)\r\
        for i = 1, 4 do\r\
            b.lines[i].Thickness = thickness; b.lines[i].Color = color\r\
            b.lines[i].Transparency = 1; b.lines[i].Visible = true\r\
            b.outlines[i].Thickness = thickness + 2; b.outlines[i].Color = outline\r\
            b.outlines[i].Transparency = 1; b.outlines[i].Visible = true\r\
        end\r\
        table.insert(self._active2D, {\r\
            bundle = b, spawnT = now, lifetime = self:_flag(\"MarkerLifetime\", 0.7), fading = false,\r\
        })\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 4 -- Hitmarker 3D + 2D: per-frame update (proyeccion/centro + fade). Mismo patron que\r\
    -- _updateLineTracers: fade se dispara una vez vencido el lifetime, release al pool al\r\
    -- terminar la ventana de fade.\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_updateMarker3D(now)\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        local list = self._active3D\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            local b = e.bundle\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                for j = 1, 4 do\r\
                    GV.Tween(b.lines[j], { Transparency = 0 }, \"quad\", MARKER3D_FADE_DUR)\r\
                    GV.Tween(b.outlines[j], { Transparency = 0 }, \"quad\", MARKER3D_FADE_DUR)\r\
                end\r\
            end\r\
            if e.fading and (now - e.fadeStart) >= MARKER3D_FADE_DUR then\r\
                self:_releaseMarkerBundle(self._marker3DPool, b)\r\
                table.remove(list, i)\r\
            elseif cam then\r\
                -- posicion capturada 1 vez al spawn (juju L14994/L15000: anclada al punto de\r\
                -- impacto en world-space, no re-lee part.Position cada frame) -- solo la camara\r\
                -- moviendose actualiza la proyeccion. Fuera de camara -> oculto (juju L15040-\r\
                -- 15044, sin edge-clamp como los tracers de Task 3).\r\
                local vp, onScreen = cam:WorldToViewportPoint(e.pos)\r\
                if onScreen then\r\
                    self:_layoutMarkerCross(b, vp.X, vp.Y)\r\
                    for j = 1, 4 do b.lines[j].Visible = true; b.outlines[j].Visible = true end\r\
                else\r\
                    for j = 1, 4 do b.lines[j].Visible = false; b.outlines[j].Visible = false end\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    function Combat:_updateMarker2D(now)\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        local list = self._active2D\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            local b = e.bundle\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                for j = 1, 4 do\r\
                    GV.Tween(b.lines[j], { Transparency = 0 }, \"quad\", MARKER2D_FADE_DUR)\r\
                    GV.Tween(b.outlines[j], { Transparency = 0 }, \"quad\", MARKER2D_FADE_DUR)\r\
                end\r\
            end\r\
            if e.fading and (now - e.fadeStart) >= MARKER2D_FADE_DUR then\r\
                self:_releaseMarkerBundle(self._marker2DPool, b)\r\
                table.remove(list, i)\r\
            elseif cam then\r\
                -- centro de pantalla recalculado cada frame (juju L15123-15125), sin proyeccion\r\
                -- ni check on-screen -- siempre visible mientras exista.\r\
                local vp = cam.ViewportSize\r\
                self:_layoutMarkerCross(b, vp.X / 2, vp.Y / 2)\r\
                for j = 1, 4 do b.lines[j].Visible = true; b.outlines[j].Visible = true end\r\
            end\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 5 -- Damage Numbers: pool getter (1 sola Drawing \"Text\" -- a diferencia de los\r\
    -- bundles de Task 3/4, el outline vive en la MISMA Drawing via las props nativas\r\
    -- Outline/OutlineColor de \"Text\", no hace falta una 2da Drawing).\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_damageText()\r\
        local t = table.remove(self._damagePool)\r\
        if t then return t end\r\
        -- ZIndex 5500 = mismo valor hardcodeado que juju (L14864/L14891) para que el numero\r\
        -- SIEMPRE dibuje encima -- en particular, encima de la cruz de Task 4 (ZIndex 99/100,\r\
        -- ver :_markerBundle) ya que Marker3D/2D y Damage suelen estar ON juntos y spawnean\r\
        -- desde el mismo :_onHit en la misma posicion de pantalla. Sin esto, Drawing \"Text\" cae\r\
        -- al ZIndex default (~0) y el numero renderiza DETRAS de la cruz. Review finding.\r\
        return self:_draw(\"Text\", { Center = false, Outline = true, ZIndex = 5500 })\r\
    end\r\
    function Combat:_releaseDamageText(t)\r\
        t.Visible = false\r\
        table.insert(self._damagePool, t)\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 5 -- Damage Numbers: spawn (juju L14875-14961, do_damage_number). Color: lethal\r\
    -- (bool de provider.onHit) selecciona Combat_DamageLethal vs Combat_DamageColor, mismo\r\
    -- patron que Task 4. Texto: SOLO el valor numerico de damage, redondeado (ver nota de\r\
    -- adaptacion en el header del archivo -- no se porta \"show ragebot data\").\r\
    --\r\
    -- Animacion (adaptada del original, ver brief): 2 fases, mismo patron 2-fase que\r\
    -- tracers/markers de arriba --\r\
    --   fase 1 [0, lifetime): sube en world-space desde part_position hasta part_position +\r\
    --     DAMAGE_RISE_OFFSET (juju L14879 show_offset), ease-in (quad, t*t) via GV.Tween sobre\r\
    --     un campo NUMERICO propio de la entry (e.riseAlpha 0->1) -- mismo patron que\r\
    --     e.fadeAlpha de :_updateBeamTracers (GV.Tween/tweenStep no interpolan Vector3 escalado\r\
    --     por un alpha directamente, se reconstruye la posicion cada frame en :_updateDamage).\r\
    --     Transparency se mantiene opaca (=1) desde el spawn, sin fade-in propio -- juju SI\r\
    --     tiene un sub-fade-in (0->transparency durante los primeros lifetime/1.6s); se omite\r\
    --     acá para quedar consistente con el resto del archivo, que solo fadea UNA vez, al\r\
    --     final (mismo criterio que tracers/markers: Transparency=1 desde el spawn).\r\
    --   fase 2 [lifetime, lifetime*1.5): fade-out de Transparency 1->0, mismo gate que Task 3/4\r\
    --     (\"not e.fading and elapsed>=lifetime\" dispara el GV.Tween) -- PERO la duracion de esa\r\
    --     ventana NO es una constante fija del archivo (a diferencia de LINE_FADE_DUR/\r\
    --     MARKER3D_FADE_DUR): es proporcional al lifetime de CADA instancia (lifetime*0.5, juju\r\
    --     L14903 new_half = lifetime/2), porque el brief fija el ciclo de vida total en\r\
    --     \"lifetime*1.5\" (juju L14931 delay(lifetime+new_half, ...)). Se guarda como\r\
    --     e.fadeDur = e.lifetime * 0.5 en el momento del spawn.\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_spawnDamageNumber(pos, damage, lethal, now)\r\
        local t = self:_damageText()\r\
        local font = tonumber(self:_flag(\"DamageFont\", \"2\")) or 2\r\
        local color = lethal and GV.Color.fade(self.Flags, \"Combat_DamageLethal\", now)\r\
            or GV.Color.fade(self.Flags, \"Combat_DamageColor\", now)\r\
        local outline = GV.Color.fade(self.Flags, \"Combat_DamageOutline\", now)\r\
        local lifetime = self:_flag(\"DamageLifetime\", 0.7)\r\
        t.Text = tostring(math.floor((tonumber(damage) or 0) + 0.5))\r\
        t.Size = 14\r\
        t.Font = font\r\
        t.Color = color\r\
        t.OutlineColor = outline\r\
        t.Transparency = 1\r\
        t.Visible = true\r\
        local entry = {\r\
            text = t, basePos = pos, spawnT = now, lifetime = lifetime,\r\
            fadeDur = lifetime * 0.5, fading = false, riseAlpha = 0,\r\
        }\r\
        GV.Tween(entry, { riseAlpha = 1 }, \"quad\", lifetime)\r\
        table.insert(self._activeDamage, entry)\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 5 -- Damage Numbers: per-frame update. basePos capturado 1 vez al spawn (igual que\r\
    -- Marker3D, no re-lee part.Position) + offset de rise reconstruido cada frame desde\r\
    -- e.riseAlpha (tweeneado por GV.tweenStep via GV.Tween en :_spawnDamageNumber, NO acá --\r\
    -- mismo split que e.fadeAlpha/_updateBeamTracers). Fuera de camara -> oculto (juju\r\
    -- L14924-14926, sin edge-clamp como los tracers de Task 3).\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_updateDamage(now)\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        local list = self._activeDamage\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            local t = e.text\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                GV.Tween(t, { Transparency = 0 }, \"quad\", e.fadeDur)\r\
            end\r\
            if e.fading and (now - e.fadeStart) >= e.fadeDur then\r\
                self:_releaseDamageText(t)\r\
                table.remove(list, i)\r\
            elseif cam then\r\
                local worldPos = e.basePos + DAMAGE_RISE_OFFSET * e.riseAlpha\r\
                local vp, onScreen = cam:WorldToViewportPoint(worldPos)\r\
                if onScreen then\r\
                    t.Position = Vector2.new(vp.X + 13, vp.Y)\r\
                    t.Visible = true\r\
                else\r\
                    t.Visible = false\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 6 -- Target Ring: pool FIJO (32 Drawing \"Line\" creadas 1 sola vez -- NO es el patron\r\
    -- event-spawn / pool-de-prestamo de Tasks 3-5 arriba). Port de jujudotlol.lua L22690-22764\r\
    -- (\"target circle\", do_target_circle): arco spinning de 32 segmentos alrededor de\r\
    -- provider.target(), con gradiente color3_lerp \"comet-tail\". El arco NO es un circulo\r\
    -- completo: el paso angular de juju (0.12566370614359174 rad = 2*pi/50) * 32 segmentos\r\
    -- cubre solo ~230.4 grados, y el segmento i=32 SIEMPRE cae con Transparency=0 (invisible en\r\
    -- la convencion Drawing de este proyecto, ver ESP.lua L238) porque `visible = (i+32) % 32`\r\
    -- da 0 para i=32 -- en Lua/Luau 0 es TRUTHY (solo nil/false son falsy), asi que juju SIEMPRE\r\
    -- deja `line[\"Visible\"] = true` y usa fade=visible/32=0 para ocultar ese segmento via\r\
    -- transparencia, no via el flag Visible. Se porta 1:1 esa mecanica (un `if visible ~= 0`\r\
    -- seria un comportamiento distinto al original).\r\
    --\r\
    -- Trigger: CONTINUO (brief Task 6), no onShot/onHit -- corre cada frame desde :_update\r\
    -- incondicionalmente (mismo mandato de la nota grande sobre :_update mas abajo) pero gatea\r\
    -- su propia VISIBILIDAD adentro de :_updateRing (Combat_Ring off / sin target / sin torso\r\
    -- -> oculta las 32 lineas y return), nunca en :_update mismo -- si se gateara ahi, apagar\r\
    -- Combat_Ring o Combat_Enabled starvearia a _updateLineTracers/_updateBeamTracers/\r\
    -- _updateMarker3D/_updateMarker2D/_updateDamage de su tick (mismo razonamiento que la nota\r\
    -- de Task 3/4/5).\r\
    ------------------------------------------------------------------------------------------\r\
    local RING_ANGLE_STEP = 0.12566370614359174 -- 2*pi/50, exacto a juju L22706/22707\r\
\r\
    function Combat:_ensureRing()\r\
        local r = self._ring\r\
        if r then return r end\r\
        local lines = {}\r\
        for i = 1, 32 do lines[i] = self:_draw(\"Line\", { ZIndex = 10 }) end\r\
        r = { lines = lines, radius = { r = 0 }, oldRadius = 0, bounce = nil }\r\
        self._ring = r\r\
        return r\r\
    end\r\
\r\
    -- Adaptaciones vs juju (ver brief \"adapt, do not invent\"):\r\
    --  1) el radio se lee via char:GetBoundingBox() directo (pcall) en vez del truco de juju de\r\
    --     extraer Model.GetBoundingBox de un Model descartable (evasion de hook -- no aplica\r\
    --     aca, ningun otro feature de este archivo porta ese tipo de evasion).\r\
    --  2) el \"bounce\" de radio en 2 fases (overshoot +3 studs en 0.07s quad-out -> asienta en\r\
    --     0.14s circular-out, juju L22698-22704, disparado solo si el radio cambio >1.1 studs)\r\
    --     se adapta del `tween(...); delay(0.07, function() if data[11]==new_radius+3 then\r\
    --     tween(...) end end)` de juju (push-into-scheduler) al patron per-frame que ya usa\r\
    --     este archivo para timers de 2 fases (e.fading/e.fadeStart de Tasks 3-5) en vez de\r\
    --     `task.delay`/`delay` -- self._ring.bounce guarda {settle=, fireAt=} y :_updateRing\r\
    --     dispara la 2da fase cuando `now >= fireAt`, con el mismo guard de juju (\"solo si nadie\r\
    --     disparo un nuevo bounce mientras tanto\", ahi comparado contra `data[11]==new_radius+3`\r\
    --     -- aca contra `ring.radius.r`).\r\
    function Combat:_updateRing(now)\r\
        local ring = self:_ensureRing()\r\
        local lines = ring.lines\r\
        local cam = self.Services.Workspace.CurrentCamera\r\
        local on = self:_flag(\"Enabled\", false) and self:_flag(\"Ring\", false)\r\
        local target = on and resolveTarget(self._provider) or nil\r\
        local char = target and target.Character\r\
        local torso = char and (char:FindFirstChild(\"UpperTorso\") or char:FindFirstChild(\"HumanoidRootPart\"))\r\
        if not on or not target or not torso or not cam then\r\
            for i = 1, 32 do lines[i].Visible = false end\r\
            ring.oldRadius = 0\r\
            ring.bounce = nil\r\
            return\r\
        end\r\
        local okPos, position = pcall(function() return torso.Position end)\r\
        if not okPos or typeof(position) ~= \"Vector3\" then\r\
            for i = 1, 32 do lines[i].Visible = false end\r\
            return\r\
        end\r\
\r\
        local baseColor = GV.Color.fade(self.Flags, \"Combat_RingColor\", now)\r\
        local gradColor = GV.Color.fade(self.Flags, \"Combat_RingGradient\", now)\r\
        local thickness = self:_flag(\"RingThickness\", 2)\r\
        local speed = self:_flag(\"RingSpeed\", 4)\r\
\r\
        -- radio: bounding box del char (juju L22696-22697, `(size.X+size.Z)/3` clampeado 2..10)\r\
        local okBB, _, size = pcall(function() return char:GetBoundingBox() end)\r\
        if okBB and size then\r\
            local newRadius = math.clamp((size.X + size.Z) / 3, 2, 10)\r\
            if newRadius ~= ring.oldRadius and math.abs(newRadius - ring.oldRadius) > 1.1 then\r\
                ring.oldRadius = newRadius\r\
                GV.Tween(ring.radius, { r = newRadius + 3 }, \"quad\", 0.07)\r\
                ring.bounce = { settle = newRadius, fireAt = now + 0.07 }\r\
            end\r\
        end\r\
        if ring.bounce and now >= ring.bounce.fireAt then\r\
            if math.abs(ring.radius.r - (ring.bounce.settle + 3)) < 0.01 then\r\
                GV.Tween(ring.radius, { r = ring.bounce.settle }, \"circular\", 0.14)\r\
            end\r\
            ring.bounce = nil\r\
        end\r\
\r\
        local offset = (now * speed) % (2 * math.pi)\r\
        local radius = ring.radius.r\r\
\r\
        for i = 1, 32 do\r\
            local line = lines[i]\r\
            local angle1 = RING_ANGLE_STEP * (i - 1) + offset\r\
            local angle2 = RING_ANGLE_STEP * i + offset\r\
            local p1, on1 = cam:WorldToViewportPoint(position + Vector3.new(math.cos(angle1) * radius, 0, math.sin(angle1) * radius))\r\
            local p2, on2 = cam:WorldToViewportPoint(position + Vector3.new(math.cos(angle2) * radius, 0, math.sin(angle2) * radius))\r\
            if on1 and on2 then\r\
                local visible = i % 32 -- 0 para i=32 (juju: (i+32)%32, identico numericamente)\r\
                local fade = visible / 32\r\
                line.Thickness = thickness\r\
                line.From = Vector2.new(p1.X, p1.Y)\r\
                line.To = Vector2.new(p2.X, p2.Y)\r\
                line.Transparency = math.max(0, fade)\r\
                line.Color = GV.Color3Lerp(baseColor, gradColor, i / 32)\r\
                line.Visible = true\r\
            else\r\
                line.Visible = false\r\
            end\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 7 -- Hit Particles: pool lazy-create (mismo criterio que :_ensureRing arriba -- 1 sola\r\
    -- fabricacion, sobrevive toggles on/off, se destruye solo en :Unload). El Part se registra en\r\
    -- self._made (a diferencia de self._ring/self._marker*Pool, que son Drawings ya cubiertas por\r\
    -- self.Drawings) -- es una Instance real (Instance.new(\"Part\")), Destroy() en cascada se lleva\r\
    -- consigo los 17 ParticleEmitter hijos (10 presets, 1-3 emitters c/u) sin loop adicional.\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_ensureParticleLib()\r\
        local lib = self._particleLib\r\
        if lib then return lib end\r\
        local part = Instance.new(\"Part\")\r\
        part.Name = \"\\0\"\r\
        part.Anchored = true\r\
        part.CanCollide = false\r\
        part.CanQuery = false\r\
        part.CanTouch = false\r\
        part.Massless = true\r\
        part.CastShadow = false\r\
        part.Size = Vector3.new(0.01, 0.01, 0.01)\r\
        part.Parent = self.Services.Workspace\r\
        table.insert(self._made, part)\r\
        lib = { part = part, presets = buildHitParticlePresets(part) }\r\
        self._particleLib = lib\r\
        return lib\r\
    end\r\
\r\
    -- juju do_hit_particle (L14770-14780): mueve el Part al CFrame de la parte golpeada (no solo\r\
    -- Position -- varios emitters usan EmissionDirection/orientacion relativa al Part, ej. sparks\r\
    -- Orientation=VelocityParallel + SpreadAngle(50,-50)), recolorea TODOS los emitters del preset\r\
    -- seleccionado (color/lethal via provider.onHit lethal bool, mismo patron que Marker/Damage),\r\
    -- fuerza ZOffset a 0/1 segun el toggle \"behind walls\" -- ESTO SOBREESCRIBE el ZOffset baked-in\r\
    -- de cada emitter (ej. blood 3er emitter trae ZOffset=4, light trae 4/5, blackflash 3/3.96/3.46,\r\
    -- meteor trae 3) -- comportamiento 1:1 de juju, no un bug de este port: cada hit fuerza 0 (o 1\r\
    -- con behind_walls ON) en TODOS los emitters del preset, pisando su valor base. Y llama\r\
    -- :Emit(count) por emitter -- fire-and-forget, sin ciclo de vida que trackear en :_update\r\
    -- (brief: \"particle emission is :Emit-based/self-expiring\").\r\
    function Combat:_fireParticle(cf, lethal, now)\r\
        local lib = self:_ensureParticleLib()\r\
        -- MULTI-SELECT: el flag ahora es un SET {name=true} (varios presets a la vez). Compat legacy: si es\r\
        -- string, un solo preset. Emitimos TODOS los seleccionados desde el mismo Part pooled.\r\
        local sel = self:_flag(\"ParticlePreset\", \"sparks\")\r\
        local names = {}\r\
        if type(sel) == \"table\" then\r\
            if sel[1] ~= nil then\r\
                for _, name in ipairs(sel) do names[#names + 1] = name end   -- multi GetValue = ARRAY {\"sparks\",...}\r\
            else\r\
                for name, on in pairs(sel) do if on then names[#names + 1] = name end end   -- set {name=true} legacy\r\
            end\r\
        elseif type(sel) == \"string\" then\r\
            names[1] = sel\r\
        end\r\
        if #names == 0 then names[1] = \"sparks\" end\r\
        local color = ColorSequence.new(lethal and GV.Color.fade(self.Flags, \"Combat_ParticleLethal\", now)\r\
            or GV.Color.fade(self.Flags, \"Combat_ParticleColor\", now))\r\
        local zOffset = self:_flag(\"ParticleBehindWalls\", false) and 1 or 0\r\
        lib.part.CFrame = cf\r\
        for _, presetName in ipairs(names) do\r\
            local preset = lib.presets[presetName]\r\
            if preset then\r\
                for _, p in ipairs(preset) do\r\
                    p.emitter.Color = color\r\
                    p.emitter.ZOffset = zOffset\r\
                    p.emitter:Emit(p.count)\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- Task 8 -- Hit Chams: clone helper (ver header del archivo para las 2 adaptaciones grandes\r\
    -- ya documentadas -- animType congelado al spawn, animador per-frame en vez de heartbeat-\r\
    -- push). Patron de clone YA establecido en este proyecto (ui/preview.lua L87-88,\r\
    -- dist/Visuals.*.lua): guarda el Archivable previo y lo RESTAURA tras el clone -- a\r\
    -- diferencia de juju (`character[\"Archivable\"]=true -> clone -> character[\"Archivable\"]=\r\
    -- false`, que deja el Character ajeno permanentemente Archivable=false incluso si estaba\r\
    -- true antes), esto no muta el estado del Character de otro jugador mas alla del instante\r\
    -- del clone.\r\
    ------------------------------------------------------------------------------------------\r\
    function Combat:_cloneCharacter(character)\r\
        local m\r\
        local ok = pcall(function()\r\
            local prev = character.Archivable\r\
            character.Archivable = true\r\
            m = character:Clone()\r\
            character.Archivable = prev\r\
        end)\r\
        if not (ok and m) then return nil end\r\
        return m\r\
    end\r\
\r\
    -- template SelectionBox lazy-cached (juju L15219-15225 `hit_chams_part`, clonado por-part en\r\
    -- la variante outline) -- mismo criterio lazy que _beamTemplate/_particleLib arriba. Nunca se\r\
    -- parentea (juju tampoco lo parentea, solo lo usa como fuente de :Clone()); se destruye en\r\
    -- :Unload.\r\
    --\r\
    -- NOTA (review finding, fix): el accessor se nombra DISTINTO al campo que cachea\r\
    -- (self._chamsOutlineTemplate) -- mismo criterio que _ensureRing()->self._ring y\r\
    -- _ensureParticleLib()->self._particleLib arriba. Nombrar el metodo IGUAL al campo\r\
    -- (`_chamsOutlineTemplate` -> `self._chamsOutlineTemplate`) rompia el lookup: con\r\
    -- Combat.__index=Combat, `self._chamsOutlineTemplate` sin valor propio en la instancia cae\r\
    -- al metodo del metatable (una funcion, truthy) -- el `if t then return t end` devolvia esa\r\
    -- funcion en vez de fabricar el SelectionBox, y `_buildChamsOutline` llamaba `:Clone()` sobre\r\
    -- una funcion -> error en TODO hit con Combat_ChamsType==\"outline\" (variante outline rota).\r\
    function Combat:_ensureChamsOutlineTemplate()\r\
        local t = self._chamsOutlineTemplate\r\
        if t then return t end\r\
        t = Instance.new(\"SelectionBox\")\r\
        t.LineThickness = 0.01\r\
        t.Name = \"\\0\"\r\
        self._chamsOutlineTemplate = t\r\
        return t\r\
    end\r\
\r\
    -- que cuenta como \"limb visible del cuerpo\" para el filtro BasePart-general (adaptacion 3,\r\
    -- ver header). Ademas de HumanoidRootPart, LiP agrega 5 `RDCollision` Part por Character\r\
    -- (verificado LIVE: Transparency=1, CanCollide=false -- hitboxes de ragdoll por-limb,\r\
    -- invisibles) -- sin esta exclusion quedarian recoloreadas como cajas fantasma flotantes\r\
    -- sobre cada limb (ni HumanoidRootPart ni RDCollision son MeshPart, asi que el filtro viejo\r\
    -- las excluia \"gratis\"; el filtro nuevo, mas amplio, necesita excluirlas a mano). Compartida\r\
    -- por :_buildChamsSolid y :_buildChamsOutline.\r\
    local function isChamsLimb(part)\r\
        return part:IsA(\"BasePart\") and part.Name ~= \"HumanoidRootPart\" and part.Name ~= \"RDCollision\"\r\
    end\r\
\r\
    -- juju do_hit_chams (L15319-15376), variantes forcefield/neon -- comparten esta logica de\r\
    -- recolor, difieren solo en `material`. Devuelve `faders` (las Instances que el animador de\r\
    -- :_updateChams debe fade/grow) + `growSizes` ([Instance]=Vector3, snapshot de Size ANTES de\r\
    -- crecer -- usado por el animador \"new fade\").\r\
    --\r\
    -- Adaptacion vs juju (ver brief \"adapt, do not invent\" + mandato de :_update sobre no-leak):\r\
    -- juju itera TODOS los hijos del modelo en el animador (`get_children(model)`) y filtra ahi\r\
    -- (`child_transparency ~= 1` salta las partes reales ocultas de la variante outline). Acá se\r\
    -- arma explicitamente la lista `faders` con SOLO las Instances que este build efectivamente\r\
    -- recoloreo/creo -- las partes reales ocultas de la variante outline (Transparency=1,\r\
    -- Anchored=true) simplemente no entran en `faders`, logrando el mismo resultado visual\r\
    -- (nunca se tocan) sin necesitar el guard `~= 1` en el animador.\r\
    -- NOTA (review finding, fix): el recolor por-part esta pcall-wrapped (igual criterio\r\
    -- defensivo que :_cloneCharacter arriba) -- una propiedad que tira error en UNA parte\r\
    -- (mesh corrupta, propiedad no soportada por el executor, etc.) ya no aborta el :_spawnChams\r\
    -- completo (que perderia el clone entero silenciosamente, antes de llegar a\r\
    -- self._activeChams/model.Parent) -- esa parte simplemente no entra en `faders`/`growSizes`\r\
    -- (no se anima), el resto del clone sigue su curso normal.\r\
    -- NOTA (review finding, fix -- ver adaptacion 3 en el header del archivo): filtro ampliado de\r\
    -- MeshPart a BasePart (verificado LIVE: LiP es R6, todo el cuerpo son `Part` comunes, no\r\
    -- MeshPart -- el filtro viejo dejaba el clon solido vacio). `TextureID` es exclusiva de\r\
    -- MeshPart -- gateada adentro del pcall para no cortar el resto de props en una parte comun.\r\
    -- HumanoidRootPart/RDCollision excluidas via :isChamsLimb (caen al mismo `else:\r\
    -- destroy(part)` de siempre).\r\
    function Combat:_buildChamsSolid(model, material, color)\r\
        local faders, growSizes = {}, {}\r\
        for _, part in ipairs(model:GetChildren()) do\r\
            if isChamsLimb(part) then\r\
                local isMesh = part:IsA(\"MeshPart\")\r\
                local ok = pcall(function()\r\
                    part.Material = material\r\
                    part.Color = color\r\
                    part.Transparency = CHAMS_TRANSPARENCY\r\
                    if isMesh then part.TextureID = \"\" end\r\
                    part.CanCollide = false\r\
                    part.Anchored = true\r\
                    if part.Name == \"Head\" then\r\
                        local decal = part:FindFirstChildOfClass(\"Decal\")\r\
                        if decal then decal:Destroy() end\r\
                    end\r\
                end)\r\
                if ok then\r\
                    faders[#faders + 1] = part\r\
                    growSizes[part] = part.Size\r\
                end\r\
            elseif part:IsA(\"Accessory\") then\r\
                -- juju L15354-15365: si el Accessory no trae un MeshPart adentro (`hat` nil), se\r\
                -- deja INTACTO (ni recolor ni destroy) -- 1:1, no un caso omitido.\r\
                local hat = part:FindFirstChildOfClass(\"MeshPart\")\r\
                if hat then\r\
                    local ok = pcall(function()\r\
                        hat.Material = material\r\
                        hat.Color = color\r\
                        hat.Transparency = CHAMS_TRANSPARENCY\r\
                        hat.TextureID = \"\"\r\
                        hat.CanCollide = false\r\
                        hat.Anchored = true\r\
                        hat.Parent = model\r\
                    end)\r\
                    if ok then\r\
                        faders[#faders + 1] = hat\r\
                        growSizes[hat] = hat.Size\r\
                    end\r\
                    part:Destroy() -- vacio (el hat ya salio, exito o no) -- siempre fuera del pcall, Destroy() no falla\r\
                end\r\
            else\r\
                part:Destroy() -- Humanoid/HumanoidRootPart/RDCollision/scripts/Shirt/Pants/BodyColors/etc.\r\
            end\r\
        end\r\
        return faders, growSizes\r\
    end\r\
\r\
    -- juju do_hit_chams_outline (L15378-15425): oculta la parte real (Transparency=1) y clona un\r\
    -- SelectionBox adornado sobre ella, por cada parte visible del cuerpo. Sin growSizes\r\
    -- (SelectionBox no tiene Size) -- animType \"new fade\" fadea igual, solo sin el efecto de\r\
    -- crecimiento.\r\
    -- NOTA (review finding, fix): mismo criterio pcall que :_buildChamsSolid arriba -- un fallo\r\
    -- a mitad de una parte (ej. Adornee rechazado) no aborta el :_spawnChams completo. El\r\
    -- `outline` sin trackear en `faders` (ok==false) igual se limpia solo: es descendiente de\r\
    -- `model`, y ese Model entero se destruye en :_updateChams/Unload independientemente de\r\
    -- `faders` -- no hay leak, solo pierde su animacion de fade individual.\r\
    -- NOTA (review finding, fix -- ver adaptacion 3 en el header del archivo): filtro ampliado de\r\
    -- \"MeshPart O Head-por-nombre\" a BasePart en general (verificado LIVE: LiP R6 -- juju's\r\
    -- fallback de nombre solo rescataba Head, dejando Torso/brazos/piernas sin outline). El\r\
    -- chequeo `isHead` se conserva SOLO para el strip del Decal \"face\" (logica sin relacion al\r\
    -- filtro de inclusion, que ahora cubre el cuerpo entero). HumanoidRootPart/RDCollision\r\
    -- excluidas via :isChamsLimb, mismo criterio que :_buildChamsSolid.\r\
    function Combat:_buildChamsOutline(model, color)\r\
        local template = self:_ensureChamsOutlineTemplate()\r\
        local faders = {}\r\
        for _, part in ipairs(model:GetChildren()) do\r\
            if isChamsLimb(part) then\r\
                local isHead = part.Name == \"Head\"\r\
                local partName = part.Name\r\
                local outline\r\
                local ok = pcall(function()\r\
                    part.Transparency = 1\r\
                    part.CanCollide = false\r\
                    part.Anchored = true\r\
                    outline = template:Clone()\r\
                    outline.Name = partName\r\
                    outline.Color3 = color\r\
                    outline.Transparency = CHAMS_TRANSPARENCY\r\
                    outline.Adornee = part\r\
                    outline.Parent = model\r\
                    part.Name = \"\\0\"\r\
                    if isHead then\r\
                        local face = part:FindFirstChild(\"face\")\r\
                        if face then face:Destroy() end\r\
                    end\r\
                end)\r\
                if ok and outline then\r\
                    faders[#faders + 1] = outline\r\
                end\r\
            else\r\
                part:Destroy()\r\
            end\r\
        end\r\
        return faders\r\
    end\r\
\r\
    -- juju L15319-15325 / L15378-15384: el destroy-si-only-last-hit pasa ANTES del chequeo de\r\
    -- Character -- si el jugador golpeado no tiene char (edge case), el chams anterior igual se\r\
    -- destruye y no se spawnea uno nuevo (1:1, mismo orden que juju).\r\
    function Combat:_spawnChams(player, now)\r\
        local ok, character = pcall(function() return player and player.Character end)\r\
        character = (ok and character) or nil\r\
\r\
        if self:_flag(\"ChamsOnlyLast\", false) and self._lastChams then\r\
            local prev = self._lastChams\r\
            pcall(function() prev.model:Destroy() end)\r\
            for i = #self._activeChams, 1, -1 do\r\
                if self._activeChams[i] == prev then table.remove(self._activeChams, i); break end\r\
            end\r\
            self._lastChams = nil\r\
        end\r\
\r\
        if not character then return end\r\
\r\
        local kind = self:_flag(\"ChamsType\", \"neon\")\r\
        -- animType leido UNA vez acá (congelado al spawn) -- ver header del archivo, adaptacion 1.\r\
        local animType = self:_flag(\"ChamsAnimation\", \"new fade\")\r\
        local color = GV.Color.fade(self.Flags, \"Combat_ChamsColor\", now)\r\
        local lifetime = self:_flag(\"ChamsLifetime\", 0.8)\r\
\r\
        local model = self:_cloneCharacter(character)\r\
        if not model then return end\r\
        model.Name = \"\\0\"\r\
\r\
        local faders, growSizes\r\
        if kind == \"outline\" then\r\
            faders = self:_buildChamsOutline(model, color)\r\
        else\r\
            -- juju L15454: \"neon\"->Neon, \"forcefield\" o cualquier otro valor->ForceField (mismo fallback).\r\
            local material = (kind == \"neon\") and Enum.Material.Neon or Enum.Material.ForceField\r\
            faders, growSizes = self:_buildChamsSolid(model, material, color)\r\
        end\r\
        model.Parent = self.Services.Workspace\r\
\r\
        local entry = {\r\
            model = model, faders = faders, growSizes = growSizes, animType = animType,\r\
            curveDur = (animType == \"new fade\") and CHAMS_NEWFADE_CURVE_DUR or CHAMS_FADE_CURVE_DUR,\r\
            spawnT = now, lifetime = lifetime, fading = false, fadeStart = nil, fadeAlpha = 0,\r\
        }\r\
        table.insert(self._activeChams, entry)\r\
        self._lastChams = entry\r\
    end\r\
\r\
    -- animador per-frame (reemplaza destroy_hit_chams_fade/new_fade/none de juju, ver header del\r\
    -- archivo adaptacion 2). animType==\"none\": destruye INMEDIATO al vencer el lifetime, sin\r\
    -- ventana (juju destroy_hit_chams_none = destroy(model) directo, sin delay adicional).\r\
    -- fade/new fade: dispara GV.Tween sobre `e.fadeAlpha` (0->1, mismo patron que e.fadeAlpha de\r\
    -- :_updateBeamTracers) durante `e.curveDur`; la ventana total hasta destroy sigue siendo\r\
    -- CHAMS_TOTAL_FADE_DUR (0.25s) para ambas variantes con curva (juju: el `delay(0.25,...)` de\r\
    -- destroy es el mismo en L15252 y L15306 independiente de que la curva interna dure 0.25 o\r\
    -- 0.15) -- tras completar la curva (curveDur<TOTAL_FADE_DUR en \"new fade\"), el modelo queda\r\
    -- congelado en transparency=1/size maxima el resto de la ventana.\r\
    function Combat:_updateChams(now)\r\
        local list = self._activeChams\r\
        for i = #list, 1, -1 do\r\
            local e = list[i]\r\
            if not e.fading and (now - e.spawnT) >= e.lifetime then\r\
                e.fading = true; e.fadeStart = now\r\
                if e.animType == \"none\" then\r\
                    pcall(function() e.model:Destroy() end)\r\
                    if self._lastChams == e then self._lastChams = nil end\r\
                    table.remove(list, i)\r\
                else\r\
                    GV.Tween(e, { fadeAlpha = 1 }, \"quad\", e.curveDur)\r\
                end\r\
            elseif e.fading then\r\
                local transparency = CHAMS_TRANSPARENCY + (1 - CHAMS_TRANSPARENCY) * e.fadeAlpha\r\
                for _, part in ipairs(e.faders) do\r\
                    pcall(function()\r\
                        part.Transparency = transparency\r\
                        local oldSize = e.growSizes and e.growSizes[part]\r\
                        if oldSize then part.Size = oldSize + CHAMS_GROW_SIZE * transparency end\r\
                    end)\r\
                end\r\
                if (now - e.fadeStart) >= CHAMS_TOTAL_FADE_DUR then\r\
                    pcall(function() e.model:Destroy() end)\r\
                    if self._lastChams == e then self._lastChams = nil end\r\
                    table.remove(list, i)\r\
                end\r\
            end\r\
        end\r\
    end\r\
\r\
    -- ── triggers del provider ──\r\
    function Combat:_onShot(origin, hitPos, isLocal)\r\
        if not (self:_flag(\"Enabled\", false) and self:_flag(\"Tracer\", false)) then return end\r\
        if typeof(origin) ~= \"Vector3\" or typeof(hitPos) ~= \"Vector3\" then return end\r\
        local now = os.clock()\r\
        local kind = self:_flag(\"TracerType\", \"beam\")\r\
        if kind == \"line\" then self:_spawnLineTracer(origin, hitPos, now)\r\
        else self:_spawnBeamTracer(origin, hitPos, now) end\r\
    end\r\
    function Combat:_onHit(plr, part, dmg, lethal)\r\
        -- Task 4 (Hitmarker 3D+2D) + Task 5 (Damage Numbers, este bloque). Tasks 7/8 (Hit\r\
        -- Particles, Hit Chams) enganchan acá tambien mas adelante. Gate SOLO del lado del spawn\r\
        -- (Combat_Enabled + el toggle de cada feature) -- ver nota en :_update sobre por que los\r\
        -- updaters corren incondicionalmente.\r\
        if not self:_flag(\"Enabled\", false) then return end\r\
        local now = os.clock()\r\
        if self:_flag(\"Marker3D\", false) then\r\
            local ok, pos = pcall(function() return part.Position end)\r\
            if ok and typeof(pos) == \"Vector3\" then self:_spawnMarker3D(pos, lethal, now) end\r\
        end\r\
        if self:_flag(\"Marker2D\", false) then\r\
            self:_spawnMarker2D(lethal, now)\r\
        end\r\
        if self:_flag(\"Damage\", false) then\r\
            local ok, pos = pcall(function() return part.Position end)\r\
            if ok and typeof(pos) == \"Vector3\" then self:_spawnDamageNumber(pos, dmg, lethal, now) end\r\
        end\r\
        -- Task 7 (Hit Particles, este bloque). CFrame completo (no solo Position) -- ver nota en\r\
        -- :_fireParticle sobre por que la orientacion del Part importa para varios emitters.\r\
        if self:_flag(\"Particle\", false) then\r\
            local ok, cf = pcall(function() return part.CFrame end)\r\
            if ok and typeof(cf) == \"CFrame\" then self:_fireParticle(cf, lethal, now) end\r\
        end\r\
        -- Task 8 (Hit Chams, este bloque -- ULTIMA feature). A diferencia de Marker/Damage/\r\
        -- Particle arriba, no consume `part`/`dmg`/`lethal` -- solo `plr` (el Player golpeado,\r\
        -- ver :_spawnChams).\r\
        if self:_flag(\"Chams\", false) then\r\
            self:_spawnChams(plr, now)\r\
        end\r\
    end\r\
\r\
    -- GV.tweenStep + TODOS los updaters (tracers + hitmarkers + damage numbers + target ring +\r\
    -- hit chams) corren SIEMPRE, sin gatear por Combat_Enabled -- igual convencion que Aura:_update/\r\
    -- ESP:_update (tweenStep incondicional). Si se gatearan, apagar Combat_Enabled con un\r\
    -- tracer/marker/numero a mitad de fade lo congelaria (Drawing/Beam visibles) para siempre\r\
    -- hasta re-activar o Unload -- el pool nunca liberaria el bundle ni el Beam se destruiria.\r\
    -- El toggle solo debe frenar SPAWNS nuevos (ya gateado en :_onShot/:_onHit); lo ya disparado\r\
    -- debe poder terminar su ciclo de vida (fade -> release/destroy) igual. Confirmado como\r\
    -- review finding de Task 3, mandatorio para Task 4/5. Task 6 (:_updateRing) no es\r\
    -- event-spawn (no tiene ciclo de vida que terminar), pero sigue el MISMO mandato de correr\r\
    -- incondicional -- gatea su propia visibilidad adentro (ver nota grande sobre\r\
    -- :_updateRing), nunca aca, para no starvear al resto de updaters de arriba si alguien\r\
    -- intentara un `if not self:_flag(\"Ring\") then return end` temprano en :_update.\r\
    function Combat:_update(now, dt)\r\
        GV.tweenStep(now, dt)\r\
        self:_updateLineTracers(now)\r\
        self:_updateBeamTracers(now)\r\
        self:_updateMarker3D(now)\r\
        self:_updateMarker2D(now)\r\
        self:_updateDamage(now)\r\
        self:_updateRing(now)\r\
        self:_updateChams(now)\r\
    end\r\
\r\
    function Combat:Init()\r\
        if self.Loaded then return self end\r\
        self.Loaded = true\r\
        local lastT = os.clock()\r\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\r\
            local now = os.clock(); local dt = now - lastT; lastT = now\r\
            local ok, err = pcall(function() self:_update(now, dt) end)\r\
            if not ok then warn(\"[Combat] \" .. tostring(err)) end\r\
        end)\r\
        if self._provider then\r\
            local shot = resolveSignal(self._provider.onShot)\r\
            if shot and shot.Connect then\r\
                local ok, conn = pcall(function()\r\
                    return shot:Connect(function(origin, hitPos, isLocal) self:_onShot(origin, hitPos, isLocal) end)\r\
                end)\r\
                if ok and conn then self.Conns[#self.Conns + 1] = conn end\r\
            end\r\
            local hit = resolveSignal(self._provider.onHit)\r\
            if hit and hit.Connect then\r\
                local ok, conn = pcall(function()\r\
                    return hit:Connect(function(plr, part, dmg, lethal) self:_onHit(plr, part, dmg, lethal) end)\r\
                end)\r\
                if ok and conn then self.Conns[#self.Conns + 1] = conn end\r\
            end\r\
        end\r\
        return self\r\
    end\r\
\r\
    function Combat:Unload()\r\
        self.Loaded = false\r\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\r\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\r\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
        -- beams no viven en self._made (ver nota en :_spawnBeamTracer) -- self._activeBeam es su\r\
        -- propio safety net: cualquier tracer todavia vivo/fading al momento de Unload se destruye acá.\r\
        for _, e in ipairs(self._activeBeam) do\r\
            pcall(function() e.beam:Destroy() end)\r\
            pcall(function() e.att0:Destroy() end)\r\
            pcall(function() e.att1:Destroy() end)\r\
        end\r\
        -- hitmarkers (Task 4), damage numbers (Task 5) y el target ring (Task 6) NO necesitan\r\
        -- destroy explicito -- sus Drawing \"Line\"/\"Text\" ya se crearon via self:_draw y quedaron\r\
        -- registradas en self.Drawings, cubiertas por el loop de arriba. Solo hace falta vaciar\r\
        -- los pools/listas de tracking -- self._ring = nil (a diferencia de los table.clear() de\r\
        -- abajo, que vacian pero conservan la MISMA tabla) fuerza a :_ensureRing a fabricar un\r\
        -- pool de 32 Drawings NUEVO en el proximo Init -- las 32 lineas viejas ya fueron\r\
        -- :Remove()-idas arriba, retener esa referencia las dejaria apuntando a Drawings muertas.\r\
        -- self._particleLib (Task 7) sigue el mismo criterio que self._ring: el Part (y sus 17\r\
        -- ParticleEmitter hijos, destruidos en cascada) ya fue :Destroy()-ido arriba via el loop de\r\
        -- self._made (esta registrado ahi, ver :_ensureParticleLib) -- self._particleLib = nil solo\r\
        -- fuerza una fabricacion NUEVA (Part + presets) en el proximo :_ensureParticleLib, evitando\r\
        -- retener una referencia a un Part ya destruido.\r\
        -- self._activeChams (Task 8) NO vive en self._made (mismo motivo que self._activeBeam:\r\
        -- son Models parenteados directo a Workspace, con su propio ciclo de vida de fade->\r\
        -- destroy) -- cualquier chams todavia vivo/fading al momento de Unload se destruye acá\r\
        -- (mandato del brief: \"no unbounded growth\" cubre tambien el caso \"modulo descargado a\r\
        -- mitad de vuelo\"). self._chamsOutlineTemplate sigue el mismo criterio que\r\
        -- self._particleLib/self._ring: se destruye y se nillea para forzar una fabricacion\r\
        -- nueva en el proximo :_ensureChamsOutlineTemplate.\r\
        for _, e in ipairs(self._activeChams) do\r\
            pcall(function() e.model:Destroy() end)\r\
        end\r\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made)\r\
        table.clear(self._linePool); table.clear(self._activeLine); table.clear(self._activeBeam)\r\
        table.clear(self._marker3DPool); table.clear(self._active3D)\r\
        table.clear(self._marker2DPool); table.clear(self._active2D)\r\
        table.clear(self._damagePool); table.clear(self._activeDamage)\r\
        table.clear(self._activeChams)\r\
        self._lastChams = nil\r\
        if self._chamsOutlineTemplate then\r\
            pcall(function() self._chamsOutlineTemplate:Destroy() end)\r\
            self._chamsOutlineTemplate = nil\r\
        end\r\
        self._ring = nil\r\
        self._particleLib = nil\r\
    end\r\
\r\
    GV.Combat = Combat\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.combat = GV.Modules.combat or {}\r\
    GV.Modules.combat.new = function(o) return Combat.new(o) end\r\
end\r\
"
local f = loadstring(chunk, '@core/combat.lua')(); f(GV) end
do local chunk = "-- core/aura.lua — modulo \"aura\": 15 auras cosmeticas sobre el char local (6 procedural + 9\r\
-- rbxassetid), port 1:1 de jujudotlol.lua L19679-20335 (builders L19688-20108, asset loader\r\
-- L20111-20119, apply/reparent L20140-20193, color-apply L20287-20330).\r\
--\r\
-- Mecanismo (identico a juju): cada aura es un Model \"plantilla\" cuyos hijos directos son Parts\r\
-- placeholder nombrados como partes del char (UpperTorso/LowerTorso/Head/HumanoidRootPart/...),\r\
-- cada uno con Attachment/Beam/ParticleEmitter/PointLight como hijos. Al aplicar: clonar la\r\
-- plantilla, y por cada Part placeholder buscar la parte REAL del char por nombre (ver\r\
-- `_resolvePart`); si hay match, reparentar sus hijos directos sobre ella (renombrados\r\
-- \"\\0\\0\"/\"\\0\\0att\" — stealth, igual que juju); si no hay match ni fallback, destruir ese\r\
-- placeholder (con sus hijos).\r\
--\r\
-- Adaptacion vs juju (necesaria, no cosmetica): LiP es R6 (ver docs/ops.md) pero los placeholders\r\
-- (propios y de varios de los 9 assets) usan nombres R15 (UpperTorso/LeftUpperArm/...). juju nunca\r\
-- necesita esto (corre en un juego R15) — un match por nombre EXACTO dejaria angel wing/blue\r\
-- heat/heal aura sin un solo emitter en R6 (UpperTorso/LowerTorso/LeftUpperArm/... no existen en\r\
-- ese rig). `_resolvePart` intenta el nombre exacto primero y cae a un mapa R15->R6 (ver\r\
-- R15_TO_R6) antes de descartar el placeholder. Varios nombres R15 colapsan al mismo Part R6\r\
-- (ej. UpperTorso y LowerTorso -> \"Torso\"): sus grupos de emitters terminan apilados en esa unica\r\
-- parte en vez de perderse — degradacion visual aceptable, cobertura completa del rig.\r\
--\r\
-- Adaptacion deliberada vs juju (no cambia el mecanismo, solo el momento): juju arma las 9 auras\r\
-- rbxassetid EAGER al cargar el modulo (9 game:GetObjects en la carga del cheat completo). Acá se\r\
-- cargan LAZY (primera vez que el nombre aparece seleccionado), cacheadas por nombre — evita 9\r\
-- fetches de red cada vez que el cheat entero carga aunque el usuario nunca abra el tab Aura.\r\
return function(GV)\r\
    local Aura = {}\r\
    Aura.__index = Aura\r\
\r\
    local DEFAULT_COLOR = Color3.fromRGB(133, 220, 255)\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- procedural builders (juju L19688-20108) — transcripcion 1:1 (mismos valores/texturas)\r\
    ------------------------------------------------------------------------------------------\r\
    local function buildAngelWingAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"angel wing\"\r\
        local torso = Instance.new(\"Part\")\r\
        torso.Name = \"UpperTorso\"\r\
        torso.Parent = model\r\
\r\
        local att1 = Instance.new(\"Attachment\")\r\
        att1.Name = \"AngelAtt1\"\r\
        att1.CFrame = CFrame.new(0, 4.25, 0)\r\
        att1.Parent = torso\r\
\r\
        local pe1 = Instance.new(\"ParticleEmitter\")\r\
        pe1.Acceleration = Vector3.new(0, -6, 0)\r\
        pe1.Brightness = 1\r\
        pe1.Color = ColorSequence.new(Color3.new(1, 1, 1))\r\
        pe1.EmissionDirection = Enum.NormalId.Bottom\r\
        pe1.Enabled = true\r\
        pe1.Lifetime = NumberRange.new(1, 2)\r\
        pe1.LightEmission = 1\r\
        pe1.LightInfluence = 1\r\
        pe1.LockedToPart = true\r\
        pe1.Orientation = Enum.ParticleOrientation.FacingCamera\r\
        pe1.Rate = 50\r\
        pe1.RotSpeed = NumberRange.new(-100, 100)\r\
        pe1.Rotation = NumberRange.new(-360, 360)\r\
        pe1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5, 0.3), NumberSequenceKeypoint.new(1, 0.5, 0.3) })\r\
        pe1.Speed = NumberRange.new(2.5, 2.5)\r\
        pe1.SpreadAngle = Vector2.new(0, 360)\r\
        pe1.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
        pe1.Texture = \"rbxassetid://7511321694\"\r\
        pe1.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0),\r\
            NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        pe1.VelocityInheritance = 0\r\
        pe1.WindAffectsDrag = false\r\
        pe1.Parent = att1\r\
\r\
        local pe2 = Instance.new(\"ParticleEmitter\")\r\
        pe2.Acceleration = Vector3.new(0, -6, 0)\r\
        pe2.Brightness = 1\r\
        pe2.Color = ColorSequence.new(Color3.new(1, 1, 1))\r\
        pe2.EmissionDirection = Enum.NormalId.Bottom\r\
        pe2.Enabled = true\r\
        pe2.Lifetime = NumberRange.new(1, 2)\r\
        pe2.LightEmission = 1\r\
        pe2.LightInfluence = 1\r\
        pe2.LockedToPart = true\r\
        pe2.Orientation = Enum.ParticleOrientation.FacingCamera\r\
        pe2.Rate = 100\r\
        pe2.RotSpeed = NumberRange.new(-100, 100)\r\
        pe2.Rotation = NumberRange.new(-360, 360)\r\
        pe2.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5, 0.3), NumberSequenceKeypoint.new(1, 0.5, 0.3) })\r\
        pe2.Speed = NumberRange.new(2.5, 2.5)\r\
        pe2.SpreadAngle = Vector2.new(0, 360)\r\
        pe2.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
        pe2.Texture = \"rbxassetid://1084976679\"\r\
        pe2.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0),\r\
            NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        pe2.VelocityInheritance = 0\r\
        pe2.WindAffectsDrag = false\r\
        pe2.Parent = att1\r\
\r\
        local att2 = Instance.new(\"Attachment\")\r\
        att2.Name = \"AngelAtt2\"\r\
        att2.CFrame = CFrame.new(0, 0.75, 0.5)\r\
        att2.Parent = torso\r\
        local att3 = Instance.new(\"Attachment\")\r\
        att3.Name = \"AngelAtt3\"\r\
        att3.CFrame = CFrame.new(-5.25, 0, 2) * CFrame.fromMatrix(Vector3.new(0, 0, 0),\r\
            Vector3.new(0.866025388, 0, 0.5), Vector3.new(0, 1, 0), Vector3.new(-0.5, 0, 0.866025388))\r\
        att3.Parent = torso\r\
        local att4 = Instance.new(\"Attachment\")\r\
        att4.Name = \"AngelAtt4\"\r\
        att4.CFrame = CFrame.new(5.25, 0, 2) * CFrame.fromMatrix(Vector3.new(0, 0, 0),\r\
            Vector3.new(0.866025388, 0, -0.5), Vector3.new(0, 1, 0), Vector3.new(0.5, 0, 0.866025388))\r\
        att4.Parent = torso\r\
\r\
        local beam1 = Instance.new(\"Beam\")\r\
        beam1.Attachment0 = att2\r\
        beam1.Attachment1 = att3\r\
        beam1.Brightness = 1\r\
        beam1.Color = ColorSequence.new(Color3.new(1, 1, 1))\r\
        beam1.CurveSize0 = 2\r\
        beam1.CurveSize1 = 2\r\
        beam1.Enabled = true\r\
        beam1.FaceCamera = false\r\
        beam1.LightEmission = 1\r\
        beam1.LightInfluence = 1\r\
        beam1.Segments = 10\r\
        beam1.Texture = \"rbxassetid://9544400688\"\r\
        beam1.TextureLength = 1\r\
        beam1.TextureMode = Enum.TextureMode.Stretch\r\
        beam1.TextureSpeed = 0\r\
        beam1.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
        beam1.Width0 = 4\r\
        beam1.Width1 = 6\r\
        beam1.Parent = torso\r\
\r\
        local beam2 = Instance.new(\"Beam\")\r\
        beam2.Attachment0 = att2\r\
        beam2.Attachment1 = att4\r\
        beam2.Brightness = 1\r\
        beam2.Color = ColorSequence.new(Color3.new(1, 1, 1))\r\
        beam2.CurveSize0 = -2\r\
        beam2.CurveSize1 = -2\r\
        beam2.Enabled = true\r\
        beam2.FaceCamera = false\r\
        beam2.LightEmission = 1\r\
        beam2.LightInfluence = 1\r\
        beam2.Segments = 10\r\
        beam2.Texture = \"rbxassetid://9544400688\"\r\
        beam2.TextureLength = 1\r\
        beam2.TextureMode = Enum.TextureMode.Stretch\r\
        beam2.TextureSpeed = 0\r\
        beam2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
        beam2.Width0 = 4\r\
        beam2.Width1 = 6\r\
        beam2.Parent = torso\r\
\r\
        local pl = Instance.new(\"PointLight\")\r\
        pl.Brightness = 1\r\
        pl.Color = Color3.new(1, 1, 1)\r\
        pl.Enabled = true\r\
        pl.Range = 5\r\
        pl.Shadows = false\r\
        pl.Parent = torso\r\
\r\
        return model\r\
    end\r\
\r\
    local function buildBlueHeatAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"blue heat\"\r\
        local blueheatColor = Color3.fromRGB(15, 15, 255)\r\
        local partsToUse = { \"UpperTorso\", \"LowerTorso\", \"LeftUpperArm\", \"RightUpperArm\", \"LeftUpperLeg\", \"RightUpperLeg\" }\r\
        for _, partName in ipairs(partsToUse) do\r\
            local part = Instance.new(\"Part\")\r\
            part.Name = partName\r\
            part.Parent = model\r\
\r\
            local atom1 = Instance.new(\"ParticleEmitter\")\r\
            atom1.Name = \"BhAtom1\"\r\
            atom1.Acceleration = Vector3.new(0, 1, 0)\r\
            atom1.Brightness = 10\r\
            atom1.Color = ColorSequence.new(blueheatColor)\r\
            atom1.Drag = 50\r\
            atom1.EmissionDirection = Enum.NormalId.Top\r\
            atom1.Enabled = true\r\
            atom1.Lifetime = NumberRange.new(0.4, 0.6)\r\
            atom1.LightEmission = 1\r\
            atom1.LightInfluence = 0\r\
            atom1.LockedToPart = false\r\
            atom1.Orientation = Enum.ParticleOrientation.FacingCamera\r\
            atom1.Rate = 20\r\
            atom1.RotSpeed = NumberRange.new(0, 0)\r\
            atom1.Rotation = NumberRange.new(-360, 360)\r\
            atom1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.125), NumberSequenceKeypoint.new(1, 0) })\r\
            atom1.Speed = NumberRange.new(30, 40)\r\
            atom1.SpreadAngle = Vector2.new(90, 90)\r\
            atom1.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })\r\
            atom1.Texture = \"rbxassetid://11448304274\"\r\
            atom1.TimeScale = 0.75\r\
            atom1.Transparency = NumberSequence.new({\r\
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.500529, 0), NumberSequenceKeypoint.new(1, 1),\r\
            })\r\
            atom1.VelocityInheritance = 0\r\
            atom1.WindAffectsDrag = false\r\
            atom1.ZOffset = -1\r\
            atom1.Parent = part\r\
\r\
            local flame1 = Instance.new(\"ParticleEmitter\")\r\
            flame1.Name = \"BhFlame1\"\r\
            flame1.Acceleration = Vector3.new(0, 1, 0)\r\
            flame1.Brightness = 10\r\
            flame1.Color = ColorSequence.new(blueheatColor)\r\
            flame1.EmissionDirection = Enum.NormalId.Top\r\
            flame1.Enabled = true\r\
            flame1.Lifetime = NumberRange.new(0.4, 0.6)\r\
            flame1.LightEmission = 1\r\
            flame1.LightInfluence = 0\r\
            flame1.LockedToPart = false\r\
            flame1.Orientation = Enum.ParticleOrientation.FacingCamera\r\
            flame1.Rate = 150\r\
            flame1.RotSpeed = NumberRange.new(0, 0)\r\
            flame1.Rotation = NumberRange.new(-360, 360)\r\
            flame1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })\r\
            flame1.Speed = NumberRange.new(1, 2)\r\
            flame1.SpreadAngle = Vector2.new(90, 90)\r\
            flame1.Texture = \"rbxassetid://10545078665\"\r\
            flame1.TimeScale = 0.75\r\
            flame1.Transparency = NumberSequence.new({\r\
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.500529, 0), NumberSequenceKeypoint.new(1, 1),\r\
            })\r\
            flame1.ZOffset = -1\r\
            flame1.Parent = part\r\
\r\
            local glow = Instance.new(\"ParticleEmitter\")\r\
            glow.Name = \"BhGlow\"\r\
            glow.Acceleration = Vector3.new(0, 1, 0)\r\
            glow.Brightness = 10\r\
            glow.Color = ColorSequence.new(blueheatColor)\r\
            glow.EmissionDirection = Enum.NormalId.Top\r\
            glow.Enabled = true\r\
            glow.FlipbookFramerate = NumberRange.new(30, 30)\r\
            glow.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4\r\
            glow.FlipbookMode = Enum.ParticleFlipbookMode.OneShot\r\
            glow.Lifetime = NumberRange.new(0.4, 0.6)\r\
            glow.LightEmission = 1\r\
            glow.LightInfluence = 0\r\
            glow.LockedToPart = true\r\
            glow.Orientation = Enum.ParticleOrientation.FacingCamera\r\
            glow.Rate = 200\r\
            glow.RotSpeed = NumberRange.new(0, 0)\r\
            glow.Rotation = NumberRange.new(-360, 360)\r\
            glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.5) })\r\
            glow.Speed = NumberRange.new(0.1, 0.1)\r\
            glow.SpreadAngle = Vector2.new(360, 360)\r\
            glow.Texture = \"rbxassetid://8451174579\"\r\
            glow.TimeScale = 0.75\r\
            glow.Transparency = NumberSequence.new({\r\
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9125), NumberSequenceKeypoint.new(1, 1),\r\
            })\r\
            glow.ZOffset = 1\r\
            glow.Parent = part\r\
        end\r\
        return model\r\
    end\r\
\r\
    local function buildHealAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"heal aura\"\r\
        local torso = Instance.new(\"Part\")\r\
        torso.Name = \"LowerTorso\"\r\
        torso.Parent = model\r\
        local att = Instance.new(\"Attachment\")\r\
        att.Parent = torso\r\
\r\
        local hw1 = Instance.new(\"ParticleEmitter\")\r\
        hw1.Name = \"HealingWave1\"\r\
        hw1.Lifetime = NumberRange.new(1.5, 1.5)\r\
        hw1.SpreadAngle = Vector2.new(10, -10)\r\
        hw1.LockedToPart = true\r\
        hw1.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1702454, 0.7, 0.014881),\r\
            NumberSequenceKeypoint.new(0.2254601, 0.03125, 0.03125), NumberSequenceKeypoint.new(0.2852761, 0),\r\
            NumberSequenceKeypoint.new(0.702454, 0), NumberSequenceKeypoint.new(0.8374233, 0.9125, 0.0601461),\r\
            NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        hw1.LightEmission = 0.4\r\
        hw1.Color = ColorSequence.new(Color3.fromRGB(234, 8, 255))\r\
        hw1.VelocitySpread = 10\r\
        hw1.Speed = NumberRange.new(3, 6)\r\
        hw1.Brightness = 10\r\
        hw1.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 3.0624998, 1.8805969), NumberSequenceKeypoint.new(0.6420546, 1.9999999, 1.7619393),\r\
            NumberSequenceKeypoint.new(1, 0.7499999, 0.7499999),\r\
        })\r\
        hw1.Rate = 20\r\
        hw1.Texture = \"rbxassetid://8047533775\"\r\
        hw1.RotSpeed = NumberRange.new(200, 400)\r\
        hw1.Rotation = NumberRange.new(-180, 180)\r\
        hw1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        hw1.Parent = att\r\
\r\
        local hw2 = Instance.new(\"ParticleEmitter\")\r\
        hw2.Name = \"HealingWave2\"\r\
        hw2.Lifetime = NumberRange.new(1.5, 1.5)\r\
        hw2.SpreadAngle = Vector2.new(10, -10)\r\
        hw2.LockedToPart = true\r\
        hw2.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2254601, 0.03125, 0.03125),\r\
            NumberSequenceKeypoint.new(0.6288344, 0.25625, 0.0593491), NumberSequenceKeypoint.new(0.8374233, 0.9125, 0.0601461),\r\
            NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        hw2.LightEmission = 1\r\
        hw2.Color = ColorSequence.new(Color3.fromRGB(238, 3, 255))\r\
        hw2.VelocitySpread = 10\r\
        hw2.Speed = NumberRange.new(3, 5)\r\
        hw2.Brightness = 10\r\
        hw2.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 3.125), NumberSequenceKeypoint.new(0.4165329, 1.3749999, 1.3749999),\r\
            NumberSequenceKeypoint.new(1, 0.9375, 0.9375),\r\
        })\r\
        hw2.Rate = 20\r\
        hw2.Texture = \"rbxassetid://8047796070\"\r\
        hw2.RotSpeed = NumberRange.new(100, 300)\r\
        hw2.Rotation = NumberRange.new(-180, 180)\r\
        hw2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        hw2.Parent = att\r\
\r\
        local sparks = Instance.new(\"ParticleEmitter\")\r\
        sparks.Name = \"HealSparks\"\r\
        sparks.Lifetime = NumberRange.new(0.5, 2)\r\
        sparks.SpreadAngle = Vector2.new(180, -180)\r\
        sparks.LightEmission = 1\r\
        sparks.Color = ColorSequence.new(Color3.fromRGB(255, 21, 255))\r\
        sparks.Drag = 3\r\
        sparks.VelocitySpread = 180\r\
        sparks.Speed = NumberRange.new(5, 15)\r\
        sparks.Brightness = 10\r\
        sparks.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.14687, 0.4374999, 0.1875001), NumberSequenceKeypoint.new(1, 0),\r\
        })\r\
        sparks.Acceleration = Vector3.new(0, 3, 0)\r\
        sparks.ZOffset = -1\r\
        sparks.Rate = 40\r\
        sparks.Texture = \"rbxassetid://8611887361\"\r\
        sparks.RotSpeed = NumberRange.new(-30, 30)\r\
        sparks.Orientation = Enum.ParticleOrientation.VelocityParallel\r\
        sparks.Parent = att\r\
\r\
        local starSparks = Instance.new(\"ParticleEmitter\")\r\
        starSparks.Name = \"HealStarSparks\"\r\
        starSparks.Lifetime = NumberRange.new(1.5, 1.5)\r\
        starSparks.SpreadAngle = Vector2.new(180, -180)\r\
        starSparks.LightEmission = 1\r\
        starSparks.Color = ColorSequence.new(Color3.fromRGB(226, 60, 255))\r\
        starSparks.Drag = 3\r\
        starSparks.VelocitySpread = 180\r\
        starSparks.Speed = NumberRange.new(5, 10)\r\
        starSparks.Brightness = 10\r\
        starSparks.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1492777, 0.6874996, 0.6874996), NumberSequenceKeypoint.new(1, 0),\r\
        })\r\
        starSparks.Acceleration = Vector3.new(0, 3, 0)\r\
        starSparks.ZOffset = 2\r\
        starSparks.Texture = \"rbxassetid://8611887703\"\r\
        starSparks.RotSpeed = NumberRange.new(-30, 30)\r\
        starSparks.Rotation = NumberRange.new(-30, 30)\r\
        starSparks.Parent = att\r\
\r\
        return model\r\
    end\r\
\r\
    local function buildAmbientAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"ambient\"\r\
        local hrp = Instance.new(\"Part\")\r\
        hrp.Name = \"HumanoidRootPart\"\r\
        hrp.Parent = model\r\
        local att = Instance.new(\"Attachment\")\r\
        att.CFrame = CFrame.new(0, -2.75, 0)\r\
        att.Parent = hrp\r\
\r\
        local e1 = Instance.new(\"ParticleEmitter\")\r\
        e1.Name = \"Ambient1\"\r\
        e1.Lifetime = NumberRange.new(2, 2)\r\
        e1.SpreadAngle = Vector2.new(0.001, 0.001)\r\
        e1.LockedToPart = true\r\
        e1.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })\r\
        e1.LightEmission = 1\r\
        e1.VelocitySpread = 0.001\r\
        e1.Squash = NumberSequence.new(0)\r\
        e1.Speed = NumberRange.new(0.001, 0.001)\r\
        e1.Brightness = 2\r\
        e1.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 2.5),\r\
            NumberSequenceKeypoint.new(0.8, 4), NumberSequenceKeypoint.new(1, 6),\r\
        })\r\
        e1.RotSpeed = NumberRange.new(-600, 600)\r\
        e1.Texture = \"https://assetgame.roblox.com/asset/?id=12713358087&assetName=crescent\"\r\
        e1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e1.Rotation = NumberRange.new(0, 360)\r\
        e1.Parent = att\r\
\r\
        local e2 = Instance.new(\"ParticleEmitter\")\r\
        e2.Name = \"Ambient2\"\r\
        e2.Lifetime = NumberRange.new(2, 2)\r\
        e2.SpreadAngle = Vector2.new(0.001, 0.001)\r\
        e2.LockedToPart = true\r\
        e2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) })\r\
        e2.LightEmission = 1\r\
        e2.VelocitySpread = 0.001\r\
        e2.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 2) })\r\
        e2.Speed = NumberRange.new(0.001, 0.001)\r\
        e2.Brightness = 2\r\
        e2.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 2.5),\r\
            NumberSequenceKeypoint.new(0.8, 4), NumberSequenceKeypoint.new(1, 6),\r\
        })\r\
        e2.RotSpeed = NumberRange.new(-30, 30)\r\
        e2.Texture = \"rbxassetid://7216849325\"\r\
        e2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e2.Rotation = NumberRange.new(0, 360)\r\
        e2.Parent = att\r\
\r\
        local e3 = Instance.new(\"ParticleEmitter\")\r\
        e3.Name = \"Ambient3\"\r\
        e3.Lifetime = NumberRange.new(2, 2)\r\
        e3.SpreadAngle = Vector2.new(0.001, 0.001)\r\
        e3.LockedToPart = true\r\
        e3.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) })\r\
        e3.LightEmission = 1\r\
        e3.VelocitySpread = 0.001\r\
        e3.Squash = NumberSequence.new(0)\r\
        e3.Speed = NumberRange.new(0.001, 0.001)\r\
        e3.Brightness = 2\r\
        e3.Size = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2), NumberSequenceKeypoint.new(0.6, 5),\r\
            NumberSequenceKeypoint.new(0.8, 8), NumberSequenceKeypoint.new(1, 12),\r\
        })\r\
        e3.RotSpeed = NumberRange.new(-40, 40)\r\
        e3.Texture = \"rbxassetid://7216855136\"\r\
        e3.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e3.Rotation = NumberRange.new(0, 360)\r\
        e3.Parent = att\r\
\r\
        return model\r\
    end\r\
\r\
    local function buildNimbAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"nimb\"\r\
        local head = Instance.new(\"Part\")\r\
        head.Name = \"Head\"\r\
        head.Parent = model\r\
        local att = Instance.new(\"Attachment\")\r\
        att.CFrame = CFrame.new(-0.25, 0.933, 0.259, 0.469, -0.25, -0.847, -0.117, 0.933, -0.34, 0.875, 0.259, 0.408)\r\
        att.Parent = head\r\
\r\
        local e1 = Instance.new(\"ParticleEmitter\")\r\
        e1.Name = \"Nimb1\"\r\
        e1.Lifetime = NumberRange.new(1, 1)\r\
        e1.SpreadAngle = Vector2.new(5, 5)\r\
        e1.LockedToPart = true\r\
        e1.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        e1.LightEmission = 1\r\
        e1.VelocitySpread = 5\r\
        e1.Speed = NumberRange.new(0.001, 0.001)\r\
        e1.Brightness = 2\r\
        e1.Size = NumberSequence.new(2.5, 3)\r\
        e1.RotSpeed = NumberRange.new(-400, 400)\r\
        e1.Rate = 7\r\
        e1.Texture = \"rbxassetid://8819682608\"\r\
        e1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e1.Rotation = NumberRange.new(0, 360)\r\
        e1.Parent = att\r\
\r\
        local e2 = Instance.new(\"ParticleEmitter\")\r\
        e2.Name = \"Nimb2\"\r\
        e2.Lifetime = NumberRange.new(1, 1)\r\
        e2.SpreadAngle = Vector2.new(5, 5)\r\
        e2.LockedToPart = true\r\
        e2.Transparency = NumberSequence.new({\r\
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),\r\
        })\r\
        e2.LightEmission = 1\r\
        e2.VelocitySpread = 5\r\
        e2.Speed = NumberRange.new(0.001, 0.001)\r\
        e2.Brightness = 2\r\
        e2.Size = NumberSequence.new(2, 3)\r\
        e2.RotSpeed = NumberRange.new(-400, 400)\r\
        e2.Rate = 7\r\
        e2.Texture = \"rbxassetid://8819682608\"\r\
        e2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e2.Rotation = NumberRange.new(0, 360)\r\
        e2.Parent = att\r\
\r\
        return model\r\
    end\r\
\r\
    local function buildTornadoAura()\r\
        local model = Instance.new(\"Model\")\r\
        model.Name = \"tornado\"\r\
        local hrp = Instance.new(\"Part\")\r\
        hrp.Name = \"HumanoidRootPart\"\r\
        hrp.Parent = model\r\
        local att = Instance.new(\"Attachment\")\r\
        att.CFrame = CFrame.new(0, -3, 0)\r\
        att.Parent = hrp\r\
\r\
        local e = Instance.new(\"ParticleEmitter\")\r\
        e.Name = \"Tornado1\"\r\
        e.LightInfluence = 1\r\
        e.LockedToPart = true\r\
        e.LightEmission = 1\r\
        e.Speed = NumberRange.new(0.01, 0.01)\r\
        e.Size = NumberSequence.new(6, 10)\r\
        e.RotSpeed = NumberRange.new(360, 360)\r\
        e.Rate = 1\r\
        e.Texture = \"http://www.roblox.com/asset/?id=8553497052\"\r\
        e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular\r\
        e.Parent = att\r\
\r\
        return model\r\
    end\r\
\r\
    -- asset auras (juju L20111-20119): game:GetObjects(rbxassetid://ID)[1] -> Model plantilla\r\
    -- (misma forma que las procedurales: Parts placeholder con Attachment/Beam/PointLight hijos).\r\
    local ASSET_IDS = {\r\
        starlight = \"134645216613107\",\r\
        lightning = \"88833232287502\",\r\
        heavenly = \"139300897520961\",\r\
        ribbon = \"132069507632161\",\r\
        sakura = \"81755778619404\",\r\
        angel = \"97658130917593\",\r\
        wind = \"80694081850877\",\r\
        flow = \"119913533725648\",\r\
        star = \"73754563740680\",\r\
    }\r\
    local PROCEDURAL_BUILDERS = {\r\
        [\"angel wing\"] = buildAngelWingAura,\r\
        [\"blue heat\"] = buildBlueHeatAura,\r\
        [\"heal aura\"] = buildHealAura,\r\
        [\"ambient\"] = buildAmbientAura,\r\
        [\"nimb\"] = buildNimbAura,\r\
        [\"tornado\"] = buildTornadoAura,\r\
    }\r\
\r\
    ------------------------------------------------------------------------------------------\r\
    -- instancia del modulo\r\
    ------------------------------------------------------------------------------------------\r\
    function Aura.new(opts)\r\
        opts = opts or {}\r\
        local svc = opts.services or {\r\
            Players = game:GetService(\"Players\"),\r\
            RunService = game:GetService(\"RunService\"),\r\
            Workspace = workspace,\r\
        }\r\
        return setmetatable({\r\
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,\r\
            Conns = {}, Drawings = {}, _made = {}, _templates = {}, Loaded = false,\r\
            _wasOn = false, _lastChar = nil, _lastSelKey = nil,\r\
        }, Aura)\r\
    end\r\
\r\
    function Aura:Set(k, v) self.Flags[k] = v end\r\
    function Aura:Get(k) return self.Flags[k] end\r\
    function Aura:_flag(k, d)\r\
        local v = self.Flags[\"Aura_\" .. k]; if v ~= nil then return v end; return d\r\
    end\r\
    function Aura:UseProfile(p) if p then self._provider = p end end\r\
\r\
    function Aura:_draw(class, props)\r\
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end\r\
        local o = Drawing.new(class); o.Visible = false\r\
        if props then for k, v in pairs(props) do o[k] = v end end\r\
        table.insert(self.Drawings, o); return o\r\
    end\r\
\r\
    -- ver comentario identico en core/combat.lua: onShot/onHit del perfil lifeinprison son\r\
    -- funciones LAZY (getgenv().LIP no existe todavia cuando este modulo se construye).\r\
    local function resolveSignal(v)\r\
        if type(v) == \"function\" then local ok, r = pcall(v); return ok and r or nil end\r\
        return v\r\
    end\r\
\r\
    -- R15 -> R6 fallback (ver comentario de cabecera). Cubre las 15 nombres R15 estandar (mismos\r\
    -- que `body_parts` en jujudotlol.lua L8358-8374) por si algun asset los usa tambien.\r\
    local R15_TO_R6 = {\r\
        UpperTorso = \"Torso\", LowerTorso = \"Torso\",\r\
        LeftUpperArm = \"Left Arm\", LeftLowerArm = \"Left Arm\", LeftHand = \"Left Arm\",\r\
        RightUpperArm = \"Right Arm\", RightLowerArm = \"Right Arm\", RightHand = \"Right Arm\",\r\
        LeftUpperLeg = \"Left Leg\", LeftLowerLeg = \"Left Leg\", LeftFoot = \"Left Leg\",\r\
        RightUpperLeg = \"Right Leg\", RightLowerLeg = \"Right Leg\", RightFoot = \"Right Leg\",\r\
    }\r\
    -- nombre exacto primero (cubre R15 nativo si algun dia se porta a un juego R15, y cubre\r\
    -- Head/HumanoidRootPart que son iguales en ambos rigs); si no existe, intenta el equivalente R6.\r\
    function Aura:_resolvePart(char, name)\r\
        local part = char:FindFirstChild(name)\r\
        if part then return part end\r\
        local fallback = R15_TO_R6[name]\r\
        return fallback and char:FindFirstChild(fallback) or nil\r\
    end\r\
\r\
    -- provider.localCharacter (a diferencia de onShot/onHit) es una funcion DIRECTA (no lazy) —\r\
    -- ver games/lifeinprison.lua. Fallback a Players.LocalPlayer.Character si el perfil no la trae.\r\
    function Aura:_char()\r\
        local prov = self._provider\r\
        if prov and prov.localCharacter then\r\
            local ok, c = pcall(prov.localCharacter)\r\
            if ok and c then return c end\r\
        end\r\
        local plr = self.Services.Players and self.Services.Players.LocalPlayer\r\
        return plr and plr.Character\r\
    end\r\
\r\
    -- template cache: procedural = build (pcall) una vez; asset = game:GetObjects (red, pcall) una\r\
    -- vez. `false` cacheado = intento fallido, no se reintenta cada frame. Sobrevive a toggles\r\
    -- on/off (solo se destruye en :Unload) — igual que la tabla particle_auras de juju.\r\
    function Aura:_template(name)\r\
        local cached = self._templates[name]\r\
        if cached ~= nil then return cached or nil end\r\
        local model\r\
        local builder = PROCEDURAL_BUILDERS[name]\r\
        if builder then\r\
            local ok, m = pcall(builder)\r\
            if ok then model = m end\r\
        else\r\
            local id = ASSET_IDS[name]\r\
            if id then\r\
                local ok, objs = pcall(function() return game:GetObjects(\"rbxassetid://\" .. id) end)\r\
                if ok and objs and objs[1] then model = objs[1] end\r\
            end\r\
        end\r\
        self._templates[name] = model or false\r\
        return model\r\
    end\r\
\r\
    local function applyColorToInstance(inst, color, seq)\r\
        if inst:IsA(\"PointLight\") then\r\
            inst.Color = color\r\
        elseif inst:IsA(\"ParticleEmitter\") or inst:IsA(\"Beam\") or inst:IsA(\"Trail\") then\r\
            inst.Color = seq\r\
        end\r\
    end\r\
\r\
    -- juju L20287-20330: recolorea (a) las plantillas cacheadas (para que clones futuros ya\r\
    -- salgan con el color actual) y (b) las instancias YA reparentadas sobre el char + sus\r\
    -- descendientes (cubre los emitters anidados dentro de un Attachment \"\\0\\0att\").\r\
    function Aura:_recolor(color)\r\
        local seq = ColorSequence.new(color)\r\
        for _, model in pairs(self._templates) do\r\
            if model then\r\
                for _, d in ipairs(model:GetDescendants()) do applyColorToInstance(d, color, seq) end\r\
            end\r\
        end\r\
        for _, inst in ipairs(self._made) do\r\
            if inst and inst.Parent then\r\
                applyColorToInstance(inst, color, seq)\r\
                for _, d in ipairs(inst:GetDescendants()) do applyColorToInstance(d, color, seq) end\r\
            end\r\
        end\r\
    end\r\
\r\
    function Aura:_clearParticles()\r\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
        table.clear(self._made)\r\
    end\r\
\r\
    -- juju L20140-20193 (do_particle_aura), branches Beam/PointLight/else colapsados (misma\r\
    -- accion en los 3: renombrar \"\\0\\0\" + reparentar sobre local_part) — solo Attachment difiere\r\
    -- (renombra \"\\0\\0att\" y ademas renombra -sin reparentar- sus propios hijos a \"\\0\\0\").\r\
    function Aura:_applyAuras(char, selected)\r\
        self:_clearParticles()\r\
        if not char then return end\r\
        for _, name in ipairs(selected) do\r\
            local template = self:_template(name)\r\
            if template then\r\
                local cloned = template:Clone()\r\
                for _, part in ipairs(cloned:GetChildren()) do\r\
                    local localPart = self:_resolvePart(char, part.Name)\r\
                    if localPart then\r\
                        for _, child in ipairs(part:GetChildren()) do\r\
                            if child:IsA(\"Attachment\") then\r\
                                child.Name = \"\\0\\0att\"\r\
                                child.Parent = localPart\r\
                                table.insert(self._made, child)\r\
                                for _, attChild in ipairs(child:GetChildren()) do attChild.Name = \"\\0\\0\" end\r\
                            else -- Beam / PointLight / ParticleEmitter suelto\r\
                                child.Name = \"\\0\\0\"\r\
                                child.Parent = localPart\r\
                                table.insert(self._made, child)\r\
                            end\r\
                        end\r\
                    else\r\
                        part:Destroy() -- sin match ni fallback R15->R6 (nombre no reconocido)\r\
                    end\r\
                end\r\
                cloned:Destroy()\r\
            end\r\
        end\r\
    end\r\
\r\
    function Aura:_update(now, dt)\r\
        GV.tweenStep(now, dt)\r\
        local enabled = self:_flag(\"Enabled\", false)\r\
        if not enabled then\r\
            if self._wasOn then\r\
                self:_clearParticles()\r\
                self._wasOn = false\r\
                self._lastChar, self._lastSelKey = nil, nil\r\
            end\r\
            return\r\
        end\r\
        self._wasOn = true\r\
\r\
        local char = self:_char()\r\
        local selectedRaw = self:_flag(\"Particles\", { \"angel\" })\r\
        local selected = (type(selectedRaw) == \"table\") and selectedRaw or { selectedRaw }\r\
        local selKey = table.concat(selected, \"\\1\")\r\
        -- (re)aplica cuando cambia el char (spawn/respawn, deteccion por identidad de instancia)\r\
        -- o cuando cambia la seleccion de auras.\r\
        if char ~= self._lastChar or selKey ~= self._lastSelKey then\r\
            self._lastChar, self._lastSelKey = char, selKey\r\
            self:_applyAuras(char, selected)\r\
        end\r\
        -- Aura_Color via CF (base + base_2 + fade) -> GV.Color.fade (igual que ESP/SelfFX).\r\
        self:_recolor(GV.Color.fade(self.Flags, \"Aura_Color\", now))\r\
    end\r\
\r\
    function Aura:Init()\r\
        if self.Loaded then return self end\r\
        self.Loaded = true\r\
        local lastT = os.clock()\r\
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()\r\
            local now = os.clock(); local dt = now - lastT; lastT = now\r\
            local ok, err = pcall(function() self:_update(now, dt) end)\r\
            if not ok then warn(\"[Aura] \" .. tostring(err)) end\r\
        end)\r\
        if self._provider then\r\
            local shot = resolveSignal(self._provider.onShot)\r\
            if shot and shot.Connect then\r\
                local ok, conn = pcall(function()\r\
                    return shot:Connect(function(origin, hitPos, isLocal) self:_onShot(origin, hitPos, isLocal) end)\r\
                end)\r\
                if ok and conn then self.Conns[#self.Conns + 1] = conn end\r\
            end\r\
            local hit = resolveSignal(self._provider.onHit)\r\
            if hit and hit.Connect then\r\
                local ok, conn = pcall(function()\r\
                    return hit:Connect(function(plr, part, dmg, lethal) self:_onHit(plr, part, dmg, lethal) end)\r\
                end)\r\
                if ok and conn then self.Conns[#self.Conns + 1] = conn end\r\
            end\r\
        end\r\
        return self\r\
    end\r\
\r\
    -- stubs del provider (aura no los consume; se mantienen por paridad de interfaz con combat)\r\
    function Aura:_onShot(origin, hitPos, isLocal) end\r\
    function Aura:_onHit(plr, part, dmg, lethal) end\r\
\r\
    function Aura:Unload()\r\
        self.Loaded = false\r\
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end\r\
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end\r\
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end\r\
        for _, model in pairs(self._templates) do\r\
            if model then pcall(function() model:Destroy() end) end\r\
        end\r\
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made); table.clear(self._templates)\r\
    end\r\
\r\
    GV.Aura = Aura\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.aura = GV.Modules.aura or {}\r\
    GV.Modules.aura.new = function(o) return Aura.new(o) end\r\
end\r\
"
local f = loadstring(chunk, '@core/aura.lua')(); f(GV) end
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
    -- cuenta columnas por tab: 3 si algun grupo usa side \"Mid\"/\"Center\" o col numerica >=3.\r\
    local function tabColumns(schema)\r\
        local m = {}\r\
        for _, row in ipairs(schema) do\r\
            local n = 2\r\
            local s = row.side\r\
            if s == \"Mid\" or s == \"Center\" then n = 3\r\
            elseif type(s) == \"number\" then n = math.clamp(s, 1, 4) end\r\
            if not m[row.tab] or m[row.tab] < n then m[row.tab] = n end\r\
        end\r\
        return m\r\
    end\r\
\r\
    function R.build(adapter, window, schema, world)\r\
        assert(GV.Facade.validate(adapter))\r\
        local handles, byFlag = {}, {}\r\
        local cols = tabColumns(schema)\r\
        local curTabName, curTab, curKey, curGroup\r\
        for _, row in ipairs(schema) do\r\
            if row.tab ~= curTabName then\r\
                curTab = adapter.Tab(window, row.tab, row.icon, cols[row.tab] or 2); curTabName = row.tab; curKey = nil\r\
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
    -- side -> columna. Left=1, Mid/Center=2, Right=ultima columna del tab (numCols).\r\
    -- side numerico => columna explicita. Permite tabs de 3 columnas para grupos chicos.\r\
    local function sideToCol(side, numCols)\r\
        if type(side) == \"number\" then return math.clamp(side, 1, numCols) end\r\
        if side == \"Right\" then return numCols end\r\
        if side == \"Mid\" or side == \"Center\" then return math.min(2, numCols) end\r\
        return 1 -- Left / default\r\
    end\r\
\r\
    -- UN category \"Visuals\" (barra superior) + cada tab del schema = Section (sidebar izquierdo)\r\
    function A.Tab(window, name, icon, numCols)\r\
        if not window.__visualsCat then\r\
            window.__visualsCat = window:AddCategory(\"Visuals\", \"eye\")\r\
        end\r\
        numCols = numCols or 2\r\
        local sec = window.__visualsCat:AddSection(name, nil, { Columns = numCols })\r\
        return { cat = window.__visualsCat, sec = sec, numCols = numCols }\r\
    end\r\
    function A.Group(tab, name, side)\r\
        return tab.sec:AddPanel(name, { Column = sideToCol(side, tab.numCols or 2) })\r\
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
do local chunk = "return function(GV)\
    local C = Color3.fromRGB\
    local ACC = C(96, 130, 255)\
    local S = {}\
    local function add(r) table.insert(S, r) end\
    local function color(toggle, base, text, group, side, default, default2)\
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = \"Local\", group = group, side = side,\
            default = default, default2 = default2 or ACC })\
    end\
    local TAB = \"Local\"\
\
    -- Layout de 3 columnas (grupos chicos): col1=Camara+Extras, col2=Crosshair+Hitmarker, col3=HUD.\
    -- side \"Mid\" activa el 3er panel de fondo. En ClaudeUI (2 cajas) \"Mid\" cae a la izquierda.\
\
    -- Camara (col 1 / Left)\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_Enabled\", type = \"toggle\", text = \"Enable Local\", default = false, keybind = true, master = true }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOV\", type = \"toggle\", text = \"FOV changer\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_FOVValue\", type = \"slider\", text = \"FOV\", min = 40, max = 120, default = 70, dependsOn = \"Local_FOV\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPerson\", type = \"toggle\", text = \"3ra persona\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_ThirdPersonDistance\", type = \"slider\", text = \"3ra persona distancia\", min = 5, max = 30, default = 12, dependsOn = \"Local_ThirdPerson\" }\
    -- Custom Aspect Ratio: stretch por matriz CFrame (funciona en cualquier executor)\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_Aspect\", type = \"toggle\", text = \"Aspect ratio (stretch)\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_AspectH\", type = \"slider\", text = \"Horizontal\", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = \"Local_Aspect\" }\
    add{ tab = TAB, group = \"Camara\", side = \"Left\", flag = \"Local_AspectV\", type = \"slider\", text = \"Vertical\", min = 0.3, max = 3, default = 1, decimals = 2, dependsOn = \"Local_Aspect\" }\
\
    -- Extras (col 1 / Left)\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"Local_AntiFlash\", type = \"toggle\", text = \"Anti-flash\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"Local_AntiSmoke\", type = \"toggle\", text = \"Anti-humo (necesita perfil)\", default = false, dependsOn = \"Local_Enabled\" }\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"Local_SelfChams\", type = \"toggle\", text = \"Self-chams (Highlight, detectable)\", default = false, dependsOn = \"Local_Enabled\" }\
    color(\"Local_SelfChams\", \"Local_SelfChamsFill\", \"Self-chams fill\", \"Extras\", \"Left\", C(0, 200, 255))\
    color(\"Local_SelfChams\", \"Local_SelfChamsOutline\", \"Self-chams outline\", \"Extras\", \"Left\", C(180, 240, 255))\
    add{ tab = TAB, group = \"Extras\", side = \"Left\", flag = \"Local_SelfChamsFillTransparency\", type = \"slider\", text = \"Self-chams transp\", min = 0, max = 1, default = 0.5, decimals = 2, dependsOn = \"Local_SelfChams\" }\
\
    -- Crosshair (col 2 / Mid)\
    add{ tab = TAB, group = \"Crosshair\", side = \"Mid\", flag = \"Local_Crosshair\", type = \"toggle\", text = \"Crosshair\", default = false, dependsOn = \"Local_Enabled\" }\
    color(\"Local_Crosshair\", \"Local_CrosshairColor\", \"Crosshair color\", \"Crosshair\", \"Mid\", C(0, 255, 120))\
    add{ tab = TAB, group = \"Crosshair\", side = \"Mid\", flag = \"Local_CrosshairStyle\", type = \"dropdown\", text = \"Estilo\", values = { \"Cross\", \"Dot\", \"Circle\", \"T\" }, default = \"Cross\", dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Mid\", flag = \"Local_CrosshairSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 40, default = 10, dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Mid\", flag = \"Local_CrosshairGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Crosshair\" }\
    add{ tab = TAB, group = \"Crosshair\", side = \"Mid\", flag = \"Local_CrosshairThickness\", type = \"slider\", text = \"Grosor\", min = 1, max = 6, default = 1, dependsOn = \"Local_Crosshair\" }\
\
    -- Hitmarker (col 2 / Mid)\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Mid\", flag = \"Local_Hitmarker\", type = \"toggle\", text = \"Hitmarker (necesita hitSignal del perfil)\", default = false, dependsOn = \"Local_Enabled\" }\
    color(\"Local_Hitmarker\", \"Local_HitmarkerColor\", \"Hitmarker color\", \"Hitmarker\", \"Mid\", C(255, 255, 255))\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Mid\", flag = \"Local_HitmarkerSize\", type = \"slider\", text = \"Tamano\", min = 2, max = 30, default = 8, dependsOn = \"Local_Hitmarker\" }\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Mid\", flag = \"Local_HitmarkerGap\", type = \"slider\", text = \"Gap\", min = 0, max = 20, default = 4, dependsOn = \"Local_Hitmarker\" }\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Mid\", flag = \"Local_HitmarkerDuration\", type = \"slider\", text = \"Duracion\", min = 0.05, max = 1, default = 0.3, decimals = 2, dependsOn = \"Local_Hitmarker\" }\
\
    -- HUD (col 3 / Right)\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_Watermark\", type = \"toggle\", text = \"Watermark\", default = false, dependsOn = \"Local_Enabled\" }\
    color(\"Local_Watermark\", \"Local_WatermarkColor\", \"Watermark color\", \"HUD\", \"Right\", C(235, 235, 240))\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_FPS\", type = \"toggle\", text = \"  FPS\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Ping\", type = \"toggle\", text = \"  ping\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Name\", type = \"toggle\", text = \"  nombre\", default = true, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WM_Time\", type = \"toggle\", text = \"  hora\", default = false, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkX\", type = \"slider\", text = \"Watermark X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_WatermarkY\", type = \"slider\", text = \"Watermark Y\", min = 0, max = 1200, default = 8, dependsOn = \"Local_Watermark\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindList\", type = \"toggle\", text = \"Lista de keybinds\", default = false, dependsOn = \"Local_Enabled\" }\
    color(\"Local_KeybindList\", \"Local_KeybindColor\", \"Keybinds color\", \"HUD\", \"Right\", C(235, 235, 240))\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindX\", type = \"slider\", text = \"Keybinds X\", min = 0, max = 2000, default = 10, dependsOn = \"Local_KeybindList\" }\
    add{ tab = TAB, group = \"HUD\", side = \"Right\", flag = \"Local_KeybindY\", type = \"slider\", text = \"Keybinds Y\", min = 0, max = 1200, default = 120, dependsOn = \"Local_KeybindList\" }\
\
    GV.Modules = GV.Modules or {}\
    GV.Modules.selffx = GV.Modules.selffx or {}\
    GV.Modules.selffx.schema = S\
end\
"
local f = loadstring(chunk, '@schema/local.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local C = Color3.fromRGB\r\
    local S = {}\r\
    local function add(r) table.insert(S, r) end\r\
    local TAB = \"Combat\"\r\
\r\
    -- Master de la categoria \"Combat\" (Tracers/Hitmarker/Damage Numbers/Target Ring/Hit\r\
    -- Particles/Hit Chams). Filas por feature se agregan en Tasks 3-8.\r\
    add{ tab = TAB, group = \"General\", side = \"Left\", flag = \"Combat_Enabled\", type = \"toggle\",\r\
        text = \"Enable Combat VFX\", default = false, keybind = true, master = true }\r\
\r\
    -- Task 3 -- Hit Tracers (juju menu L13276-13303, port de \"local/player bullet tracers\").\r\
    -- LiP no distingue tracer propio vs de otros jugadores (onShot no trae esa granularidad para\r\
    -- terceros todavia) -> 1 sola fila de flags (equivalente a los \"local_bullet_tracers_*\" de\r\
    -- juju), aplicada a cualquier onShot independientemente de isLocal.\r\
    add{ tab = TAB, group = \"Tracers\", side = \"Left\", flag = \"Combat_Tracer\", type = \"toggle\",\r\
        text = \"Hit tracers\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Tracers\", side = \"Left\", flag = \"Combat_TracerType\", type = \"dropdown\",\r\
        text = \"Type\", values = { \"line\", \"beam\" }, default = \"beam\", dependsOn = \"Combat_Tracer\" }\r\
    add{ tab = TAB, group = \"Tracers\", side = \"Left\", flag = \"Combat_TracerStyle\", type = \"dropdown\",\r\
        text = \"Style (beam)\", values = { \"laser\", \"light\", \"flow\" }, default = \"laser\", dependsOn = \"Combat_Tracer\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Tracer\", base = \"Combat_TracerColor\", text = \"Tracer color\",\r\
        tab = TAB, group = \"Tracers\", side = \"Left\", default = C(133, 220, 255) })\r\
    GV.pushCF(S, { toggle = \"Combat_Tracer\", base = \"Combat_TracerOutline\", text = \"Tracer outline (line)\",\r\
        tab = TAB, group = \"Tracers\", side = \"Left\", default = C(15, 15, 15) })\r\
    GV.pushCF(S, { toggle = \"Combat_Tracer\", base = \"Combat_TracerGradient\", text = \"Tracer gradient (beam)\",\r\
        tab = TAB, group = \"Tracers\", side = \"Left\", default = C(241, 133, 255) })\r\
    add{ tab = TAB, group = \"Tracers\", side = \"Left\", flag = \"Combat_TracerLifetime\", type = \"slider\",\r\
        text = \"Lifetime\", min = 0.1, max = 1.5, default = 0.8, decimals = 1, dependsOn = \"Combat_Tracer\" }\r\
\r\
    -- Task 4 -- Hitmarker 3D + 2D (juju menu L13322-13335: \"d3_hit_marker\"/\"d2_hit_marker\").\r\
    -- juju duplica lifetime/thickness/color/lethal/outline por marker (3D y 2D); acá se comparte\r\
    -- 1 solo set (brief lo permite explicitamente) -- ambos toggles cuelgan de Combat_Enabled, y\r\
    -- los colorpickers compartidos tambien (no de un solo toggle de marker, porque cualquiera de\r\
    -- los dos -- 3D o 2D -- los consume).\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Combat_Marker3D\", type = \"toggle\",\r\
        text = \"3D hit marker\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Combat_Marker2D\", type = \"toggle\",\r\
        text = \"2D hit marker\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Combat_MarkerLifetime\", type = \"slider\",\r\
        text = \"Lifetime\", min = 0.1, max = 2, default = 0.7, decimals = 1, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Hitmarker\", side = \"Right\", flag = \"Combat_MarkerThickness\", type = \"slider\",\r\
        text = \"Thickness\", min = 0, max = 4, default = 2, decimals = 0, dependsOn = \"Combat_Enabled\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Enabled\", base = \"Combat_MarkerColor\", text = \"Marker color\",\r\
        tab = TAB, group = \"Hitmarker\", side = \"Right\", default = C(133, 220, 255) })\r\
    GV.pushCF(S, { toggle = \"Combat_Enabled\", base = \"Combat_MarkerLethal\", text = \"Marker lethal color\",\r\
        tab = TAB, group = \"Hitmarker\", side = \"Right\", default = C(255, 0, 0) })\r\
    GV.pushCF(S, { toggle = \"Combat_Enabled\", base = \"Combat_MarkerOutline\", text = \"Marker outline\",\r\
        tab = TAB, group = \"Hitmarker\", side = \"Right\", default = C(15, 15, 15) })\r\
\r\
    -- Task 5 -- Damage Numbers (juju menu L13314-13321: \"damage_number\"). NO se porta\r\
    -- \"damage_number_show_ragebot_data\" (LiP no tiene string de razon de resolver -- ver nota de\r\
    -- adaptacion en core/combat.lua); el texto es siempre el valor numerico de damage.\r\
    add{ tab = TAB, group = \"Damage Numbers\", side = \"Right\", flag = \"Combat_Damage\", type = \"toggle\",\r\
        text = \"Damage numbers\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    -- valores del dropdown son strings numericos (mismo criterio que TracerType/TracerStyle) --\r\
    -- core/combat.lua hace tonumber() al asignarlos a Drawing.Text.Font.\r\
    add{ tab = TAB, group = \"Damage Numbers\", side = \"Right\", flag = \"Combat_DamageFont\", type = \"dropdown\",\r\
        text = \"Font\", values = { \"0\", \"1\", \"2\", \"3\" }, default = \"2\", dependsOn = \"Combat_Damage\" }\r\
    add{ tab = TAB, group = \"Damage Numbers\", side = \"Right\", flag = \"Combat_DamageLifetime\", type = \"slider\",\r\
        text = \"Lifetime\", min = 0.7, max = 2, default = 0.7, decimals = 1, dependsOn = \"Combat_Damage\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Damage\", base = \"Combat_DamageColor\", text = \"Damage color\",\r\
        tab = TAB, group = \"Damage Numbers\", side = \"Right\", default = C(255, 255, 255) })\r\
    GV.pushCF(S, { toggle = \"Combat_Damage\", base = \"Combat_DamageLethal\", text = \"Damage lethal color\",\r\
        tab = TAB, group = \"Damage Numbers\", side = \"Right\", default = C(255, 55, 55) })\r\
    GV.pushCF(S, { toggle = \"Combat_Damage\", base = \"Combat_DamageOutline\", text = \"Damage outline\",\r\
        tab = TAB, group = \"Damage Numbers\", side = \"Right\", default = C(15, 15, 15) })\r\
\r\
    -- Task 6 -- Target Ring (juju menu L20392-20395: \"3d_target_circle\" + color/gradient\r\
    -- color colorpickers; thickness=2/ZIndex=10/speed=4 son constantes hardcoded en\r\
    -- do_target_circle -- juju L22690-22764 -- sin fila de menu propia ahi, expuestas acá como\r\
    -- sliders con esos mismos valores de default per el brief). CONTINUO, no event-based: ver\r\
    -- nota en core/combat.lua Combat:_updateRing -- corre cada frame gateado por su propio\r\
    -- toggle, no por un onShot/onHit.\r\
    add{ tab = TAB, group = \"Target Ring\", side = \"Left\", flag = \"Combat_Ring\", type = \"toggle\",\r\
        text = \"Target ring\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Ring\", base = \"Combat_RingColor\", text = \"Ring color\",\r\
        tab = TAB, group = \"Target Ring\", side = \"Left\", default = C(255, 184, 243) })\r\
    GV.pushCF(S, { toggle = \"Combat_Ring\", base = \"Combat_RingGradient\", text = \"Ring gradient\",\r\
        tab = TAB, group = \"Target Ring\", side = \"Left\", default = C(255, 255, 255) })\r\
    add{ tab = TAB, group = \"Target Ring\", side = \"Left\", flag = \"Combat_RingThickness\", type = \"slider\",\r\
        text = \"Thickness\", min = 0, max = 4, default = 2, decimals = 0, dependsOn = \"Combat_Ring\" }\r\
    add{ tab = TAB, group = \"Target Ring\", side = \"Left\", flag = \"Combat_RingSpeed\", type = \"slider\",\r\
        text = \"Spin speed\", min = 0.5, max = 8, default = 4, decimals = 1, dependsOn = \"Combat_Ring\" }\r\
\r\
    -- Task 7 -- Hit Particles (juju menu L13342-13347: \"hit_particle\"). 10 emitter presets\r\
    -- prebuilt sobre 1 Part pooled (core/combat.lua Combat:_ensureParticleLib), ported literalmente\r\
    -- L14325-14765 -- ver esa funcion para el detalle de cada preset. \"custom .rbxm\" (juju\r\
    -- use_custom_extensions L13347 + getcustomasset L14800, carga un asset local del disco del\r\
    -- usuario de juju) NO se porta -- este proyecto (schema declarativo + provider, sin filesystem\r\
    -- picker) no expone un mecanismo equivalente de subida de asset propio; se omite (brief:\r\
    -- \"otherwise omit and document\"). El dropdown solo trae los 10 presets built-in. juju tiene\r\
    -- default_color = default_lethal_color = rgb(133,220,255) transparencia 0.2 para AMBOS\r\
    -- colorpickers (no es un default distinto para lethal como en Marker/Damage) -- se porta ese\r\
    -- mismo valor 1:1 en los 2 (la transparencia de juju no tiene equivalente en el colorpicker CF\r\
    -- de este proyecto, mismo criterio ya aplicado en Marker/Damage/Ring arriba -- GV.Color.fade\r\
    -- solo devuelve Color3, no transparency).\r\
    add{ tab = TAB, group = \"Hit Particles\", side = \"Left\", flag = \"Combat_Particle\", type = \"toggle\",\r\
        text = \"Hit particles\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Hit Particles\", side = \"Left\", flag = \"Combat_ParticlePreset\", type = \"dropdown\",\r\
        text = \"Preset\", multi = true,\r\
        values = { \"bubble\", \"sparks\", \"orbs\", \"air\", \"blood\", \"light\", \"lightning\", \"blackflash\", \"gravity\", \"meteor\" },\r\
        default = { \"sparks\" }, dependsOn = \"Combat_Particle\" }\r\
    add{ tab = TAB, group = \"Hit Particles\", side = \"Left\", flag = \"Combat_ParticleBehindWalls\", type = \"toggle\",\r\
        text = \"Behind walls\", default = false, dependsOn = \"Combat_Particle\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Particle\", base = \"Combat_ParticleColor\", text = \"Particle color\",\r\
        tab = TAB, group = \"Hit Particles\", side = \"Left\", default = C(133, 220, 255) })\r\
    GV.pushCF(S, { toggle = \"Combat_Particle\", base = \"Combat_ParticleLethal\", text = \"Particle lethal color\",\r\
        tab = TAB, group = \"Hit Particles\", side = \"Left\", default = C(133, 220, 255) })\r\
\r\
    -- Task 8 -- Hit Chams (juju menu L15205-15211: \"hit_chams\"). Ultima feature del combat-vfx-\r\
    -- port -- ver core/combat.lua Combat:_spawnChams/_updateChams para el mecanismo (clone del\r\
    -- Character golpeado, recolor, fade/grow). juju trae 1 SOLO colorpicker acá (a diferencia de\r\
    -- Marker/Damage/Particle arriba) -- no existe \"hit_chams_lethal_color\" en el menu original,\r\
    -- se porta 1:1 esa ausencia (sin variante lethal). El componente transparency del colorpicker\r\
    -- de juju ([\"transparency_flag\"]=\"hit_chams_transparency\", default 0.8) NO tiene equivalente\r\
    -- en el helper GV.pushCF/GV.CF de este proyecto (mismo limite ya documentado arriba en Hit\r\
    -- Particles -- GV.Color.fade solo devuelve Color3, no transparency) -- se porta como\r\
    -- constante fija CHAMS_TRANSPARENCY en core/combat.lua (valor 0.8, el default real del menu\r\
    -- de juju), no como fila de menu propia.\r\
    add{ tab = TAB, group = \"Hit Chams\", side = \"Right\", flag = \"Combat_Chams\", type = \"toggle\",\r\
        text = \"Hit chams\", default = false, dependsOn = \"Combat_Enabled\" }\r\
    add{ tab = TAB, group = \"Hit Chams\", side = \"Right\", flag = \"Combat_ChamsOnlyLast\", type = \"toggle\",\r\
        text = \"Only last hit\", default = false, dependsOn = \"Combat_Chams\" }\r\
    add{ tab = TAB, group = \"Hit Chams\", side = \"Right\", flag = \"Combat_ChamsAnimation\", type = \"dropdown\",\r\
        text = \"Animation\", values = { \"new fade\", \"fade\", \"none\" }, default = \"new fade\", dependsOn = \"Combat_Chams\" }\r\
    add{ tab = TAB, group = \"Hit Chams\", side = \"Right\", flag = \"Combat_ChamsType\", type = \"dropdown\",\r\
        text = \"Type\", values = { \"forcefield\", \"outline\", \"neon\" }, default = \"neon\", dependsOn = \"Combat_Chams\" }\r\
    add{ tab = TAB, group = \"Hit Chams\", side = \"Right\", flag = \"Combat_ChamsLifetime\", type = \"slider\",\r\
        text = \"Lifetime\", min = 0.1, max = 1.5, default = 0.8, decimals = 1, dependsOn = \"Combat_Chams\" }\r\
    GV.pushCF(S, { toggle = \"Combat_Chams\", base = \"Combat_ChamsColor\", text = \"Chams color\",\r\
        tab = TAB, group = \"Hit Chams\", side = \"Right\", default = C(142, 242, 255) })\r\
\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.combat = GV.Modules.combat or {}\r\
    GV.Modules.combat.schema = S\r\
end\r\
"
local f = loadstring(chunk, '@schema/combat.lua')(); f(GV) end
do local chunk = "return function(GV)\r\
    local C = Color3.fromRGB\r\
    local S = {}\r\
    local function add(r) table.insert(S, r) end\r\
    local function color(toggle, base, text, group, side, default, default2)\r\
        GV.pushCF(S, { toggle = toggle, base = base, text = text, tab = \"Local\", group = group, side = side,\r\
            default = default, default2 = default2 })\r\
    end\r\
    -- Task 10 (UI rebalance): Aura deja de ser tab standalone y pasa a vivir dentro del tab\r\
    -- \"Local\" (SelfFX) -- aura = self-cosmetic = local, y asi el usuario no tiene que saltar de\r\
    -- categoria para prender su propia aura junto al resto de cosmeticos propios (self-chams,\r\
    -- crosshair, watermark, etc). Cambio 100% de layout (tab/group/side); flags/defaults/\r\
    -- dependsOn/master/keybind intactos. Para que el renderer (ui/renderer.lua) fusione estas\r\
    -- filas con las de schema/local.lua en UNA sola seccion \"Local\" (en vez de crear una segunda\r\
    -- seccion duplicada) las filas de ambos modulos deben quedar CONTIGUAS en el array de schema\r\
    -- concatenado -- eso depende del orden del `modules = {...}` en LifeInPrisonPrimordial/\r\
    -- main.lua (selffx inmediatamente antes de aura, sin combat en el medio; ver commit companero\r\
    -- en LiP). Layout de 3 columnas existente en schema/local.lua: Left=Camara+Extras 18 filas,\r\
    -- Mid=Crosshair+Hitmarker 15 filas, Right=HUD 16 filas -- \"Mid\" es la columna mas liviana,\r\
    -- Aura (6 filas) entra ahi.\r\
    local TAB = \"Local\"\r\
\r\
    -- Master de la categoria \"Aura\" (15 auras: 6 procedurales + 9 rbxassetid).\r\
    add{ tab = TAB, group = \"Aura\", side = \"Mid\", flag = \"Aura_Enabled\", type = \"toggle\",\r\
        text = \"Enable Aura\", default = false, keybind = true, master = true }\r\
\r\
    -- Particula(s): multiselect, mismas 15 opciones y mismo orden que el dropdown de juju\r\
    -- (jujudotlol.lua L19684). \"+ custom .rbxm/.rbmx\" de juju (isfile/getcustomasset, L20219-20280)\r\
    -- queda deliberadamente fuera de esta pasada (opcional per brief) — las 15 built-in cubren el\r\
    -- feature.\r\
    add{ tab = TAB, group = \"Aura\", side = \"Mid\", flag = \"Aura_Particles\", type = \"dropdown\",\r\
        text = \"Particle\", values = {\r\
            \"starlight\", \"heavenly\", \"ribbon\", \"lightning\", \"sakura\", \"angel\", \"wind\", \"flow\", \"star\",\r\
            \"angel wing\", \"blue heat\", \"heal aura\", \"ambient\", \"nimb\", \"tornado\",\r\
        }, multi = true, default = { \"angel\" }, dependsOn = \"Aura_Enabled\" }\r\
\r\
    -- Color (pinned a Aura_Enabled via CF, patron Hitmarker/SelfChams). Default = juju rgb(133,220,255).\r\
    color(\"Aura_Enabled\", \"Aura_Color\", \"Color\", \"Aura\", \"Mid\", C(133, 220, 255))\r\
    -- juju tambien expone un slider de transparencia junto al colorpicker (default 0.2,\r\
    -- jujudotlol.lua L19683) pero su propio color-apply handler (L20287-20330) nunca lo lee —\r\
    -- se replica el flag por paridad de menu, sin inventar un mecanismo de aplicacion que el\r\
    -- original tampoco tiene.\r\
    add{ tab = TAB, group = \"Aura\", side = \"Mid\", flag = \"Aura_ColorTransparency\", type = \"slider\",\r\
        text = \"Color transp. (paridad juju, sin uso)\", min = 0, max = 1, default = 0.2, decimals = 2,\r\
        dependsOn = \"Aura_Enabled\" }\r\
\r\
    GV.Modules = GV.Modules or {}\r\
    GV.Modules.aura = GV.Modules.aura or {}\r\
    GV.Modules.aura.schema = S\r\
end\r\
"
local f = loadstring(chunk, '@schema/aura.lua')(); f(GV) end
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
do local chunk = "-- games/lifeinprison.lua — perfil para LifeInPrisonPrimordial. Provider FLAT (sin nesting\r\
-- .combat/.aura): entry/attach.lua resuelve `prof[name] or prof` por modulo, y como este perfil\r\
-- no tiene claves \"combat\"/\"aura\", TANTO combat COMO aura reciben la misma tabla completa de\r\
-- abajo como su _provider (coincide con el contrato del design doc: 1 solo provider consumido\r\
-- por los 2 modulos).\r\
--\r\
-- GOTCHA DE ORDEN (por eso onShot/onHit son funciones, no valores): bundle.lua arma\r\
-- `local Visuals = (function() <dist GUIWorkspace> end)()` (que corre y evalua este archivo)\r\
-- ANTES de que LiP `Core/State.lua` cree getgenv().LIP (eso pasa recien en\r\
-- `LIP = _MODS[\"Core.State\"](...)`, mas abajo en el bundle). Si onShot/onHit fueran valores\r\
-- capturados en este momento (`getgenv().LIP and getgenv().LIP.onShot`), quedarian `nil` para\r\
-- siempre — getgenv().LIP todavia no existe. Como funciones lazy, se resuelven recien en\r\
-- Combat:Init()/Aura:Init() (llamado desde main.lua, DESPUES de Core.State) -> LIP.onShot/onHit\r\
-- ya existen en ese punto.\r\
return function(GV)\r\
    GV.Profiles = GV.Profiles or {}\r\
    local Players = game:GetService(\"Players\")\r\
\r\
    GV.Profiles.lifeinprison = {\r\
        localCharacter = function()\r\
            local plr = Players.LocalPlayer\r\
            return plr and plr.Character\r\
        end,\r\
        target = function()\r\
            local LIP = getgenv().LIP\r\
            return LIP and LIP.target\r\
        end,\r\
        onShot = function()\r\
            local LIP = getgenv().LIP\r\
            return LIP and LIP.onShot\r\
        end,\r\
        onHit = function()\r\
            local LIP = getgenv().LIP\r\
            return LIP and LIP.onHit\r\
        end,\r\
    }\r\
end\r\
"
local f = loadstring(chunk, '@games/lifeinprison.lua')(); f(GV) end
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
