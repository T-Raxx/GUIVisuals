local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local cam = workspace.CurrentCamera
local dummy = T.spawnDummy(cam.CFrame * CFrame.new(0, 0, -18)) -- al frente AHORA
local prov = { getTargets = function()
    return { { model = dummy, health = 60, maxHealth = 100, root = dummy.HumanoidRootPart, head = dummy.Head,
        bones = { { a = "Head", b = "HumanoidRootPart" } }, name = "Dummy", team = nil, isEnemy = true } }
end }
local e = GV.ESP.new({ provider = prov, flags = {} })
e:Set("ESP_Enabled", true); e:Set("ESP_Box", true); e:Set("ESP_Health", true)
e:Set("ESP_Name", true); e:Set("ESP_Distance", true); e:Set("ESP_HealthStyle", "Barra+Numero")
e:Set("ESP_Skeleton", true); e:Set("ESP_HeadDot", true); e:Set("ESP_LookDir", true)
e:Set("ESP_BoxColor", Color3.fromRGB(0, 255, 0))
e:_update()
local b = e.Objects[dummy]
print("[TEST] box visible -> " .. ((b and b.box.Visible) and "PASS" or "FAIL"))
print("[TEST] skeleton visible -> " .. ((b and b.skel[1] and b.skel[1].Visible) and "PASS" or "FAIL"))
print("[TEST] headdot visible -> " .. ((b and b.headdot.Visible) and "PASS" or "FAIL"))
print("[TEST] lookdir visible -> " .. ((b and b.look.Visible) and "PASS" or "FAIL"))
-- off-screen: mover dummy detras de la camara
dummy.HumanoidRootPart.CFrame = cam.CFrame * CFrame.new(0, 0, 30)
dummy.Head.CFrame = dummy.HumanoidRootPart.CFrame * CFrame.new(0, 2.5, 0)
e:Set("ESP_OffScreen", true)
e:_update()
print("[TEST] offscreen arrow -> " .. ((b and b.arrow.Visible) and "PASS" or "FAIL"))
print("[TEST] box hidden offscreen -> " .. ((b and not b.box.Visible) and "PASS" or "FAIL"))
e:Unload(); dummy:Destroy()
print("[TEST] demo_esp DONE")
