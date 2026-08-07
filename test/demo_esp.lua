local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local cam = workspace.CurrentCamera
local dummy = T.spawnDummy(cam.CFrame * CFrame.new(0, 0, -18)) -- 18 studs al frente AHORA
local prov = { getTargets = function()
    return { { model = dummy, health = 60, maxHealth = 100, root = dummy.HumanoidRootPart, head = dummy.Head,
        bones = {}, name = "Dummy", team = nil, isEnemy = true } }
end }
local e = GV.ESP.new({ provider = prov, flags = {} })
e:Set("ESP_Enabled", true); e:Set("ESP_Box", true); e:Set("ESP_Health", true)
e:Set("ESP_Name", true); e:Set("ESP_Distance", true); e:Set("ESP_HealthStyle", "Barra+Numero")
e:Set("ESP_BoxColor", Color3.fromRGB(0, 255, 0))
e:_update() -- directo, misma frame -> sin drift de camara
local b = e.Objects[dummy]
print("[TEST] bundle creado -> " .. ((b and b.box.Visible) and "PASS" or "FAIL"))
print("[TEST] box size Y>0 -> " .. ((b and b.box.Size.Y > 0) and "PASS" or "FAIL"))
print("[TEST] hpBar visible -> " .. ((b and b.hpBar.Visible) and "PASS" or "FAIL"))
print("[TEST] name text -> " .. ((b and b.name.Text == "Dummy") and "PASS" or "FAIL"))
e:Unload(); dummy:Destroy()
print("[TEST] demo_esp DONE")
