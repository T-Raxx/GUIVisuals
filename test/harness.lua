return function(GV)
    local T = { _p = 0, _n = 0 }
    local function fmt(v)
        return typeof(v) == "Color3" and string.format("Color3(%d,%d,%d)", v.R * 255, v.G * 255, v.B * 255) or tostring(v)
    end
    function T.truthy(v, name)
        T._n += 1
        if v then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: valor falsy") end
    end
    function T.eq(a, b, name)
        T._n += 1
        if a == b then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: " .. fmt(a) .. " ~= " .. fmt(b)) end
    end
    function T.near(a, b, eps, name)
        T._n += 1; eps = eps or 1e-3
        if math.abs(a - b) <= eps then T._p += 1; print("[TEST] " .. name .. " PASS")
        else print("[TEST] " .. name .. " FAIL: " .. tostring(a) .. " ~= " .. tostring(b)) end
    end
    function T.report()
        print(string.format("[TEST] SUMMARY %d/%d", T._p, T._n)); return T._p, T._n
    end
    function T.mockServices()
        local function fakeInst(props)
            local o = { _props = props or {}, _children = {} }
            setmetatable(o, {
                __index = function(t, k) return rawget(t, "_props")[k] end,
                __newindex = function(t, k, v) rawget(t, "_props")[k] = v end,
            })
            rawget(o, "_props").FindFirstChildOfClass = function() return nil end
            rawget(o, "_props").GetChildren = function() return {} end
            rawget(o, "_props").GetDescendants = function() return {} end
            return o
        end
        local Lighting = fakeInst({ Ambient = Color3.new(), OutdoorAmbient = Color3.new(), Brightness = 1,
            GlobalShadows = true, ClockTime = 12, ExposureCompensation = 0, FogStart = 0, FogEnd = 1000,
            FogColor = Color3.new() })
        return {
            Lighting = Lighting,
            Terrain = fakeInst({}),
            RunService = { RenderStepped = { Connect = function() return { Disconnect = function() end } end } },
            Workspace = { CurrentCamera = fakeInst({ CFrame = CFrame.new() }) },
        }
    end
    GV.T = T
end
