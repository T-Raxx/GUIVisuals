-- Dev-loader. Correr en executor con GUIWorkspace sincronizado al root del workspace.
local ROOT = "GUIWorkspace/"
local GV = { _root = ROOT }
local ORDER = {
    "test/harness.lua",
    "core/util.lua",
    "core/color.lua",
    "core/World.lua",
    "core/ESP.lua",
    "core/esp_default.lua",
    "core/selffx.lua",
    "ui/facade.lua",
    "ui/renderer.lua",
    "ui/preview.lua",
    "ui/adapter_claudeui.lua",
    "ui/adapter_primordial.lua",
    "schema/_helpers.lua",
    "schema/world.lua",
    "schema/esp.lua",
    "schema/local.lua",
    "games/rivals.lua",
    "games/_template.lua",
    "entry/attach.lua",
}
for _, p in ipairs(ORDER) do
    local ok, src = pcall(readfile, ROOT .. p)
    if ok and src then
        local chunk = assert(loadstring(src, "@" .. p))
        chunk()(GV) -- el modulo retorna function(GV)
    end
end
return GV
