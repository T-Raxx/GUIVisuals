local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local ok = GV.Facade.validate({ Tab = function() end, Group = function() end, Widget = function() end, Depend = function() end })
T.truthy(ok, "adapter completo valido")
local ok2, missing = GV.Facade.validate({ Tab = function() end })
T.truthy(not ok2, "adapter incompleto invalido")
T.truthy(table.find(missing, "Widget"), "reporta Widget faltante")
T.report()
