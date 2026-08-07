return function(GV)
    local H = {}
    -- expande una spec de color a 3 filas (cp base, fade toggle, cp2 dep del fade)
    function H.CF(spec)
        local base = spec.base
        local function row(t)
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side
            return t
        end
        return {
            row{ flag = base, type = "colorpicker", text = spec.text, default = spec.default, dependsOn = spec.dependsOn },
            row{ flag = base .. "_Fade", type = "toggle", text = (spec.text or "") .. " fade", default = false, dependsOn = spec.dependsOn },
            row{ flag = base .. "_2", type = "colorpicker", text = (spec.text or "") .. " color 2", default = spec.default2 or spec.default, dependsOn = base .. "_Fade" },
        }
    end
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end
    function H.suiteRows()
        return {
            { tab = "Mundo", group = "Suite", side = "Left", flag = "Suite_FadeSpeed", type = "slider",
                text = "Velocidad fade", min = 0.1, max = 5, default = 1, decimals = 2 },
        }
    end
    GV.SchemaHelpers = H
    GV.CF = H.CF
    GV.pushCF = H.pushCF
end
