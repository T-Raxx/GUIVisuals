local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- flags compartido
local shared = {}
local w = GV.World.new({ services = T.mockServices(), flags = shared })
w:Set("World_Brightness", 5)
T.eq(shared.World_Brightness, 5, "escribe al flags compartido")
-- registro de modulo
T.truthy(GV.Modules and GV.Modules.world and type(GV.Modules.world.new) == "function", "world registrado")
local w2 = GV.Modules.world.new({ services = T.mockServices(), flags = shared })
T.eq(w2.Flags, shared, "modulo usa flags compartido")
T.report()
