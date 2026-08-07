return function(GV)
    -- filas de accion que necesitan la instancia world (presets)
    local function presetRows(world)
        return {
            { tab = "Cielo & Clima", group = "Presets", side = "Right", type = "button", text = "Aplicar preset",
                action = function() world:ApplyPreset(world:Get("World_PresetSelect")) end },
        }
    end

    -- World:Attach(Library, Window, opts) -> world
    -- opts: { adapter="claudeui"|"primordial", profile="rivals", services=... }
    function GV.Attach(Library, Window, opts)
        opts = opts or {}
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or "claudeui"]
        assert(adapter, "adapter no encontrado")
        local world = GV.World.new({ services = opts.services })
        if opts.profile then world:UseProfile(GV.Profiles[opts.profile]) end
        local schema = {}
        for _, r in ipairs(GV.Schema) do table.insert(schema, r) end
        if world._profileSchema then for _, r in ipairs(world._profileSchema) do table.insert(schema, r) end end
        for _, r in ipairs(presetRows(world)) do table.insert(schema, r) end
        world._uiHandles = GV.Renderer.build(adapter, Window, schema, world)
        world:Init()
        return world
    end
end
