local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(type(GV.Attach) == "function", "Attach expuesto")
-- construir el dist en memoria y cargarlo
local src = loadstring(readfile("GUIWorkspace/build.lua"))()(GV, "claudeui")
T.truthy(type(src) == "string" and #src > 1000, "build genera fuente (#" .. #src .. ")")
local mod = loadstring(src)()
T.truthy(type(mod.Attach) == "function", "dist expone Attach")
T.eq(mod._GV._defaultAdapter, "claudeui", "dist default adapter")
T.report()
