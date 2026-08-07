-- Bundler. Corre en el executor (necesita readfile). Concatena los modulos
-- (escapados con %q, sin readfile en runtime) -> dist/World.<lib>.lua self-contained.
-- Uso:  loadstring(readfile("GUIWorkspace/build.lua"))()(GV, "claudeui" | "primordial")
return function(GV, target)
    local ORDER = {
        "core/util.lua", "core/World.lua", "ui/facade.lua", "ui/renderer.lua",
        target == "primordial" and "ui/adapter_primordial.lua" or "ui/adapter_claudeui.lua",
        "schema/world.lua", "games/rivals.lua", "games/_template.lua", "entry/attach.lua",
    }
    local parts = { "-- World Visuals (" .. target .. ") — build autogenerado\nlocal GV = {}\n" }
    for _, p in ipairs(ORDER) do
        local src = readfile("GUIWorkspace/" .. p)
        table.insert(parts, "do local chunk = " .. string.format("%q", src) .. "\n"
            .. "local f = loadstring(chunk, '@" .. p .. "')(); f(GV) end\n")
    end
    table.insert(parts, "GV._defaultAdapter = '" .. target .. "'\nreturn { Attach = GV.Attach, _GV = GV }\n")
    local out = table.concat(parts)
    if writefile then
        local name = target == "primordial" and "World.Primordial.lua" or "World.ClaudeUI.lua"
        pcall(writefile, "GUIWorkspace/dist/" .. name, out)
    end
    return out
end
