local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
w:Set("World_NoFog", true); w:_step()
T.eq(L.FogStart, 0, "nofog start 0")
T.eq(L.FogEnd, 1e6, "nofog end 1e6")
-- Atmosphere on -> existe en cache; off -> destruida
w:Set("World_NoFog", false)
w:Set("World_Atmosphere", true); w:_step()
T.truthy(w._fxCache.Atmosphere, "atmosphere creada")
w:Set("World_Atmosphere", false); w:_step()
T.eq(w._fxCache.Atmosphere, nil, "atmosphere destruida al off")
w:Unload()
T.report()
