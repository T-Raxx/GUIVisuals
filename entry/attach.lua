return function(GV)
    -- GV.Attach(Library, Window, opts) -> suite
    -- opts: { adapter, modules={"world",...}, profile, services, flags }
    function GV.Attach(Library, Window, opts)
        opts = opts or {}
        local adapter = GV.Adapters[opts.adapter or GV._defaultAdapter or "claudeui"]
        assert(adapter, "adapter no encontrado")
        local names = opts.modules or GV._defaultModules or { "world" }
        local flags = opts.flags or {}
        local bag = { Flags = flags }
        function bag:Set(k, v) self.Flags[k] = v end
        function bag:Get(k) return self.Flags[k] end
        local suite = { modules = {}, flags = flags }
        function suite:Unload()
            if self._preview then pcall(function() self._preview:Unload() end); self._preview = nil end
            for _, m in pairs(self.modules) do pcall(function() m:Unload() end) end
        end
        bag.__suite = suite

        local schema = {}
        for _, r in ipairs(GV.SchemaHelpers.suiteRows()) do table.insert(schema, r) end
        for _, name in ipairs(names) do
            local def = GV.Modules[name]
            if def then
                local inst = def.new({ services = opts.services, flags = flags })
                if opts.profile and inst.UseProfile then
                    local prof = GV.Profiles[opts.profile]
                    inst:UseProfile(prof and (prof[name] or prof) or nil)
                end
                suite.modules[name] = inst
                for _, r in ipairs(def.schema or {}) do table.insert(schema, r) end
            end
        end
        GV.Renderer.build(adapter, Window, schema, bag)
        for _, inst in pairs(suite.modules) do inst:Init() end
        -- Preview viewport: solo si el adapter lo soporta (Primordial). ClaudeUI = 0 instancias.
        if adapter.supportsPreview and opts.preview ~= false and GV.Preview then
            local ok, pv = pcall(function() return GV.Preview.mount(suite) end)
            if ok then suite._preview = pv end
        end
        return suite
    end
end
