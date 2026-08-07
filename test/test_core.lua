local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
-- estado
w:Set("World_Brightness", 7)
T.eq(w:Get("World_Brightness"), 7, "set/get flag")
-- _set con memoria: escribe y recuerda original
local L = w.Services.Lighting
L.Brightness = 1
w:_set(L, "Brightness", 5)
T.eq(L.Brightness, 5, "_set escribe")
w:_set(L, "Brightness", 5) -- mismo valor: no re-guarda original
w:_restoreAll()
T.eq(L.Brightness, 1, "_restoreAll revierte al original")
-- GetFlags/LoadFlags roundtrip con Color3
w:Set("World_Ambient", Color3.fromRGB(9, 9, 9))
local dump = w:GetFlags()
local w2 = GV.World.new({ services = T.mockServices() })
w2:LoadFlags(dump)
T.eq(w2:Get("World_Ambient"), Color3.fromRGB(9, 9, 9), "flags roundtrip color")
T.report()
