local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local s = GV.SelfFX.new({ flags = {}, services = T.mockServices() })
local cam = s.Services.Workspace.CurrentCamera
cam.FieldOfView = 70
s:Set("Local_Enabled", true)
s:Set("Local_FOV", true); s:Set("Local_FOVValue", 100)
s:_update()
T.eq(cam.FieldOfView, 100, "FOV changer escribe")
-- provider.setFOV tiene prioridad
local got
local s2 = GV.SelfFX.new({ flags = {}, services = T.mockServices(), provider = { setFOV = function(o) got = o end } })
s2:Set("Local_FOV", true); s2:Set("Local_FOVValue", 90)
s2:_applyCamera()
T.eq(got, 20, "provider.setFOV recibe offset (90-70)")
-- off + restore
s:Set("Local_Enabled", false); s:_update()
T.eq(cam.FieldOfView, 70, "off restaura FOV")
T.report()
