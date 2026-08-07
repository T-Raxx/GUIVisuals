local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(type(GV.Attach) == "function", "Attach expuesto")
-- fake adapter para montar sin UI real
local fake = { Tab = function(_, n) return { n = n } end, Group = function(_, n) return { n = n } end,
    Widget = function() return {} end, Depend = function() end }
GV.Adapters.__fake = fake
local suite = GV.Attach(nil, {}, { adapter = "__fake", modules = { "world" }, services = GV.T.mockServices() })
T.truthy(suite.modules.world, "suite monto world")
T.eq(suite.flags.World_Brightness, 3, "flags compartido sembrado (Brightness 3)")
T.eq(suite.flags.Suite_FadeSpeed, 1, "Suite_FadeSpeed sembrado")
suite:Unload()
T.report()
