return function(GV)
    local U = {}
    function U.clamp(x, a, b) return math.max(a, math.min(b, x)) end
    function U.lerp(a, b, t) return a + (b - a) * t end
    function U.serColor(c)
        return { __ = "c3", r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) }
    end
    function U.deColor(t) return Color3.fromRGB(t.r, t.g, t.b) end
    function U.serEnum(e) return { __ = "en", t = tostring(e.EnumType), n = e.Name } end
    function U.deEnum(t)
        local et = t.t:gsub("^Enum%.", "")
        for _, item in ipairs(Enum[et]:GetEnumItems()) do
            if item.Name == t.n then return item end
        end
    end
    function U.deepcopy(t)
        if type(t) ~= "table" then return t end
        local r = {}; for k, v in pairs(t) do r[k] = U.deepcopy(v) end; return r
    end
    GV.Util = U
end
