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
        local c2 = flags[base .. "_2"]
        if typeof(c2) ~= "Color3" then return c1 end
        local speed = flags["Suite_FadeSpeed"] or 1
        local a = (math.sin((t or tick()) * speed * math.pi * 2) + 1) / 2
        return c1:Lerp(c2, a)
    end
    GV.Color = Color
end
