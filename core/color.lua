return function(GV)
    local Color = {}
    local WHITE = Color3.new(1, 1, 1)
    function Color.solid(flags, base)
        local c = flags[base]
        return typeof(c) == "Color3" and c or WHITE
    end
    function Color.fade(flags, base, t)
        local c1 = flags[base]
        if typeof(c1) ~= "Color3" then return WHITE end
        if not flags[base .. "_Fade"] then return c1 end
        t = t or tick()
        local speed = flags["Suite_FadeSpeed"] or 1
        local mode = flags["Suite_FadeMode"] or "Onda"
        if mode == "Rainbow" then
            local _, s, v = Color3.toHSV(c1)
            return Color3.fromHSV((t * speed * 0.2) % 1, math.max(s, 0.55), math.max(v, 0.7))
        end
        local c2 = flags[base .. "_2"]
        if typeof(c2) ~= "Color3" then return c1 end
        if mode == "Pulso" then
            return c1:Lerp(c2, math.abs(math.sin(t * speed * math.pi)))
        end
        -- Onda (default): oscila suave c1<->c2
        return c1:Lerp(c2, (math.sin(t * speed * math.pi * 2) + 1) / 2)
    end
    GV.Color = Color
end
