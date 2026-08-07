local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
-- Fullbright fuerza ambient blanco + brightness 1 + sin sombras
w:Set("World_Fullbright", true); w:_step()
T.eq(L.Ambient, Color3.fromRGB(255, 255, 255), "fullbright ambient")
T.eq(L.Brightness, 1, "fullbright brightness")
T.eq(L.GlobalShadows, false, "fullbright sin sombras")
-- Sin fullbright: aplica valores del user
w:Set("World_Fullbright", false)
w:Set("World_Ambient", true)
w:Set("World_AmbientColor", Color3.fromRGB(20, 20, 20))
w:Set("World_Brightness", 4)
w:Set("World_ClockTime", 6); w:_step()
T.eq(L.Ambient, Color3.fromRGB(20, 20, 20), "ambient user")
T.eq(L.Brightness, 4, "brightness user")
T.near(L.ClockTime, 6, 1e-6, "clocktime")
T.report()
