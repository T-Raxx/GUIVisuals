local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local svc = T.mockServices()
svc.Terrain = workspace:FindFirstChildOfClass("Terrain")
svc.Workspace = workspace
local w = GV.World.new({ services = svc })
w:Set("World_Enabled", true)
if svc.Terrain then
    w:Set("World_WaterEnable", true); w:Set("World_WaterTransparency", 0.9); w:_step()
    T.near(svc.Terrain.WaterTransparency, 0.9, 1e-3, "water transp")
    w:_restoreAll()
end
-- clima: crea rig y habilita emitter
w:Set("World_Weather", true); w:Set("World_WeatherMode", "Lluvia"); w:_step()
T.truthy(w._wxPart, "wx rig creado")
T.eq(w._wxEmit.Enabled, true, "emitter on")
w:Set("World_Weather", false); w:_step()
T.eq(w._wxEmit.Enabled, false, "emitter off")
w:Unload()
T.report()
