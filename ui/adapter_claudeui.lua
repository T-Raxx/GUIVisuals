return function(GV)
    GV.Adapters = GV.Adapters or {}
    local A = {}
    local ADD = { toggle = "AddToggle", slider = "AddSlider", dropdown = "AddDropdown",
        colorpicker = "AddColorPicker", label = "AddLabel", textbox = "AddInput", button = "AddButton" }

    function A.Tab(window, name) return window:AddTab(name) end
    function A.Group(tab, name, side)
        if side == "Right" then return tab:AddRightGroupbox(name) end
        return tab:AddLeftGroupbox(name)
    end
    function A.Widget(group, kind, flag, opts, parent)
        local m = ADD[kind]
        if not m then warn("[claudeui] kind desconocido: " .. tostring(kind)); return { flag = flag } end
        local host = parent or group
        -- nesting = dependencia; si el child no soporta este kind (ej AddInput/AddButton bajo toggle) -> al grupo
        if type(host[m]) ~= "function" then host = group end
        if type(host[m]) ~= "function" then warn("[claudeui] sin " .. m); return { flag = flag } end
        if kind == "label" then return host:AddLabel(opts.Text or "") end
        if kind == "button" then return host:AddButton(opts.Text or "Button", opts.Callback or function() end) end
        return host[m](host, flag, opts)
    end
    function A.Depend() end -- no-op: en ClaudeUI la dependencia se resuelve por nesting al crear
    -- colorpicker pegado a un toggle
    function A.AttachColor(toggleHandle, flag, opts)
        if toggleHandle and type(toggleHandle.AddColorPicker) == "function" then
            return toggleHandle:AddColorPicker(flag, opts)
        end
        return { flag = flag }
    end

    GV.Adapters.claudeui = A
end
