local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local svc = T.mockServices()
local RL = game:GetService("Lighting")
svc.Lighting = RL
local existing = RL:FindFirstChildOfClass("Sky")
local sky = existing or Instance.new("Sky")
if not existing then sky.Parent = RL end
local w = GV.World.new({ services = svc })
w:Set("World_CustomSkybox", true)
w:Set("World_Skybox_Up", "rbxassetid://12345")
w:_applySky()
T.eq(sky.SkyboxUp, "rbxassetid://12345", "skybox up seteado")
w:_restoreAll()
if not existing then sky:Destroy() end
T.report()
