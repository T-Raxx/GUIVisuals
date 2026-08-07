local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
-- preset Competitivo setea fullbright+nofog
w:ApplyPreset("Competitivo")
T.eq(w:Get("World_Fullbright"), true, "preset fullbright")
T.eq(w:Get("World_NoFog"), true, "preset nofog")
T.eq(w:Get("World_Enabled"), true, "preset enabled")
T.report()
