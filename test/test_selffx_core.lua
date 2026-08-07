local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(GV.SelfFX and type(GV.SelfFX.new) == "function", "GV.SelfFX.new existe")
T.truthy(GV.Modules.selffx and type(GV.Modules.selffx.new) == "function", "selffx registrado")
local shared = {}
local s = GV.SelfFX.new({ flags = shared, services = T.mockServices() })
s:Set("Local_FOVValue", 90)
T.eq(shared.Local_FOVValue, 90, "usa flags compartido")
local cam = s.Services.Workspace.CurrentCamera
cam.FieldOfView = 70
s:_set(cam, "FieldOfView", 100)
T.eq(cam.FieldOfView, 100, "_set escribe")
s:_restoreAll()
T.eq(cam.FieldOfView, 70, "_restoreAll revierte")
s:Init(); T.truthy(s.Loaded, "Init")
s:Unload(); T.truthy(not s.Loaded, "Unload")
T.report()
