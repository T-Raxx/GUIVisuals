return function(GV)
    GV.Adapters = GV.Adapters or {}
    local A = {}
    local ADD = { toggle = "AddToggle", slider = "AddSlider", dropdown = "AddDropdown",
        colorpicker = "AddColorPicker", label = "AddLabel", textbox = "AddTextBox", button = "AddButton" }

    function A.Tab(window, name, icon)
        local cat = window:AddCategory(name, icon)
        local sec = cat:AddSection(name)
        return { cat = cat, sec = sec }
    end
    function A.Group(tab, name, side)
        return tab.sec:AddPanel(name, { Column = side == "Right" and 2 or 1 })
    end
    function A.Widget(panel, kind, flag, opts)
        local m = ADD[kind]
        if not m or type(panel[m]) ~= "function" then warn("[primordial] sin widget " .. tostring(kind)); return { flag = flag } end
        if kind == "label" then return panel:AddLabel(opts.Text or "") end
        if kind == "button" then return panel:AddButton(opts.Text or "Button", opts.Callback or function() end) end
        return panel[m](panel, flag, opts)
    end
    function A.Depend(widget, flag, val)
        if widget and type(widget.DependsOn) == "function" then widget:DependsOn(flag, val) end
    end

    GV.Adapters.primordial = A
end
