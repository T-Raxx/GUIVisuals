return function(GV)
    local F = {}
    F.KINDS = { "toggle", "slider", "dropdown", "colorpicker", "label", "textbox", "button" }
    F.METHODS = { "Tab", "Group", "Widget", "Depend" }
    function F.validate(adapter)
        local missing = {}
        for _, m in ipairs(F.METHODS) do
            if type(adapter[m]) ~= "function" then table.insert(missing, m) end
        end
        return #missing == 0, missing
    end
    GV.Facade = F
end
