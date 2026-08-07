return function(GV)
    local R = {}
    local KIND_KEYS = { "Text", "Default", "Min", "Max", "Decimals", "Suffix", "Values", "Multi",
        "Searchable", "Tooltip", "Header", "Placeholder", "Numeric", "Keybind", "OffAtMin" }

    function R.build(adapter, window, schema, world)
        assert(GV.Facade.validate(adapter))
        local handles, byFlag = {}, {}
        local curTabName, curTab, curKey, curGroup
        for _, row in ipairs(schema) do
            if row.tab ~= curTabName then
                curTab = adapter.Tab(window, row.tab, row.icon); curTabName = row.tab; curKey = nil
            end
            local gk = row.tab .. "|" .. row.group .. "|" .. (row.side or "Left")
            if gk ~= curKey then
                curGroup = adapter.Group(curTab, row.group, row.side or "Left"); curKey = gk
            end
            -- opts desde la fila
            local opts = {}
            for _, k in ipairs(KIND_KEYS) do
                local sk = k:lower()
                if row[sk] ~= nil then opts[k] = row[sk] end
            end
            if row.text then opts.Text = row.text end
            -- seed del flag + default
            if row.flag and world.Flags[row.flag] == nil and row.default ~= nil then
                world.Flags[row.flag] = row.default
            end
            if row.flag then opts.Default = world.Flags[row.flag] end
            if row.type ~= "label" and row.type ~= "button" and row.flag then
                opts.Callback = function(v) world:Set(row.flag, v) end
            elseif row.type == "button" then
                if row.presetAction then
                    opts.Callback = function()
                        local suite = world.__suite
                        local w = suite and suite.modules and suite.modules.world
                        if w then w:ApplyPreset(w:Get("World_PresetSelect")) end
                    end
                else
                    opts.Callback = row.action
                end
            end
            -- crear widget
            local h
            if row.attach then
                -- colorpicker pegado a un toggle ya creado (patron Hitmarker)
                local tgl = byFlag[row.attach]
                h = adapter.AttachColor and adapter.AttachColor(tgl, row.flag, opts) or { flag = row.flag }
            else
                local parent = row.dependsOn and byFlag[row.dependsOn] or nil
                h = adapter.Widget(curGroup, row.type, row.flag, opts, parent)
                if row.dependsOn then
                    adapter.Depend(h, row.dependsOn, row.dependsValue == nil and true or row.dependsValue)
                end
            end
            if row.flag then byFlag[row.flag] = h end
            table.insert(handles, h)
        end
        return handles
    end
    GV.Renderer = R
end
