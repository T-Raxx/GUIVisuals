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
-- _fx crea una sola vez (parent real: el mock no acepta Instance.Parent)
local realParent = Instance.new("Folder")
local a = w:_fx("Folder", realParent)
local b = w:_fx("Folder", realParent)
T.eq(a, b, "_fx cachea")
-- apply registrado corre bajo master; _off restaura
local L2 = w.Services.Lighting; L2.Brightness = 3
w:_register(function(s) s:_set(L2, "Brightness", 99) end)
w:Set("World_Enabled", true); w:_step()
T.eq(L2.Brightness, 99, "apply corre con master on")
w:Set("World_Enabled", false); w:_step()
T.eq(L2.Brightness, 3, "master off restaura")
realParent:Destroy()
T.report()
