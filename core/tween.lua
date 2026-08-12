-- core/tween.lua — motor de tween para Drawing/Instance props que TweenService no puede animar
-- (Drawing no es un Instance real). Port de jujudotlol.lua L463-529 (tween/color3_lerp/easing),
-- adaptado a un modelo data-driven pull (GV.tweenStep corrido desde el heartbeat del modulo
-- consumidor) en vez de push-into-global-heartbeat como el original.
--
-- API:
--   GV.Tween(obj, props, easing, dur)  -- registra 1 entrada por propiedad. props = { Prop = target, ... }
--   GV.tweenStep(now, dt)              -- avanza todas las entradas activas; snap + remove al completar
--   GV.Ease(style, t01)                -- curva de easing pura (0..1 -> 0..1), expuesta por si hace falta
--
-- Dedup por obj+prop: una nueva llamada GV.Tween sobre el mismo obj+prop reemplaza la anterior
-- (igual que el `old_tween` lookup+remove de juju).
return function(GV)
    local function color3_lerp(a, b, t) return a:Lerp(b, t) end
    GV.Color3Lerp = color3_lerp

    -- easing: exponential / quad / circular (default) / sine. juju usaba 355/113 como aprox de pi
    -- (artefacto de ofuscacion); acá se usa math.pi (mismo efecto visual, mas preciso).
    local function easeValue(style, t)
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        if style == "exponential" then
            return t >= 1 and 1 or (1 - 2 ^ (-10 * t))
        elseif style == "quad" then
            return t * t
        elseif style == "sine" then
            if t < 0.5 then return 0.5 * math.sin(t * math.pi)
            else return 0.5 + 0.5 * (1 - math.cos((t - 0.5) * math.pi)) end
        else -- "circular" (default, matchea el fallback de juju)
            local v = 1 - (t - 1) ^ 2
            return math.sqrt(v < 0 and 0 or v)
        end
    end
    GV.Ease = easeValue

    -- active[prop][obj] = entry. Dict anidado en vez de closures individuales (mismo resultado:
    -- 1 entrada activa por par obj+prop, se pisa sola en un nuevo GV.Tween sobre el mismo par).
    local active = {}
    GV._tweens = active

    function GV.Tween(obj, props, easing, dur)
        if not obj or not props then return end
        dur = (dur and dur > 0) and dur or 0.001
        local now = os.clock()
        for prop, target in pairs(props) do
            local byProp = active[prop]
            if not byProp then byProp = {}; active[prop] = byProp end
            local ok, old = pcall(function() return obj[prop] end)
            if ok then
                byProp[obj] = { obj = obj, prop = prop, from = old, to = target,
                    start = now, dur = dur, easing = easing or "circular" }
            end
        end
    end

    function GV.tweenStep(now, dt)
        now = now or os.clock()
        for prop, byProp in pairs(active) do
            for obj, tw in pairs(byProp) do
                local t = (tw.dur > 0) and ((now - tw.start) / tw.dur) or 1
                local done = t >= 1
                local a = easeValue(tw.easing, done and 1 or t)
                local ok = pcall(function()
                    if done then
                        obj[tw.prop] = tw.to
                    elseif typeof(tw.from) == "Color3" then
                        obj[tw.prop] = color3_lerp(tw.from, tw.to, a)
                    elseif typeof(tw.from) == "Vector2" or typeof(tw.from) == "Vector3" or typeof(tw.from) == "number" then
                        obj[tw.prop] = tw.from + (tw.to - tw.from) * a
                    else
                        obj[tw.prop] = tw.to
                    end
                end)
                if done or not ok then byProp[obj] = nil end
            end
        end
    end
end
