return function(GV)
    local H = {}
    -- Color con fade PEGADO a un toggle de feature (patron Hitmarker):
    -- 2 colorpickers sobre el toggle `spec.toggle` + un toggle "fade" anidado.
    -- `spec.toggle` = el flag del toggle de feature (ej "ESP_Box"). `spec.base` = flag del color (ej "ESP_BoxColor").
    function H.CF(spec)
        local base, tgl = spec.base, spec.toggle
        local function row(t)
            t.tab, t.group, t.side = spec.tab, spec.group, spec.side
            return t
        end
        return {
            row{ flag = base, type = "colorpicker", text = spec.text, default = spec.default, attach = tgl },
            row{ flag = base .. "_2", type = "colorpicker", text = (spec.text or "") .. " 2", default = spec.default2 or spec.default, attach = tgl },
            row{ flag = base .. "_Fade", type = "toggle", text = (spec.text or "") .. " fade", default = false, dependsOn = tgl },
        }
    end
    function H.pushCF(arr, spec) for _, r in ipairs(H.CF(spec)) do table.insert(arr, r) end end
    function H.suiteRows()
        return {
            { tab = "Mundo", group = "Suite", side = "Left", flag = "Suite_FadeSpeed", type = "slider",
                text = "Velocidad fade", min = 0.1, max = 5, default = 1, decimals = 2 },
            { tab = "Mundo", group = "Suite", side = "Left", flag = "Suite_Preview", type = "toggle",
                text = "Preview (solo Primordial)", default = false },
        }
    end
    GV.SchemaHelpers = H
    GV.CF = H.CF
    GV.pushCF = H.pushCF
end
