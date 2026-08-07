local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local build = loadstring(readfile("GUIWorkspace/build.lua"))()
build(GV, "claudeui"); build(GV, "primordial")
print("[TEST] dist visuals: claudeui=" .. tostring(isfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua")) ..
    " primordial=" .. tostring(isfile("GUIWorkspace/dist/Visuals.Primordial.lua")))
local cam = workspace.CurrentCamera

local function testUI(label, distPath, libPath, mkWindow)
    local Mod = loadstring(readfile(distPath))()
    local Lib = loadstring(readfile(libPath))()
    local Win = mkWindow(Lib)
    local suite = Mod.Attach(Lib, Win, { profile = "rivals" }) -- default modules world+esp
    print("[TEST] " .. label .. " world+esp montados -> " ..
        ((suite.modules.world and suite.modules.esp) and "PASS" or "FAIL"))
    -- ESP live: inyectar dummy y verificar bundle
    local dummy = GV.T.spawnDummy(cam.CFrame * CFrame.new(0, 0, -16))
    suite.modules.esp._provider = { getTargets = function()
        return { { model = dummy, health = 70, maxHealth = 100, root = dummy.HumanoidRootPart, head = dummy.Head, bones = {}, name = "D", isEnemy = true } }
    end }
    suite.flags.ESP_Enabled = true; suite.flags.ESP_Box = true
    suite.modules.esp:_update()
    local b = suite.modules.esp.Objects[dummy]
    print("[TEST] " .. label .. " ESP bundle -> " .. ((b and b.box.Visible) and "PASS" or "FAIL"))
    suite:Unload(); Lib:Unload(); dummy:Destroy()
end

testUI("claudeui", "GUIWorkspace/dist/Visuals.ClaudeUI.lua", "Rivals/RivalsUI.lua",
    function(Lib) return Lib:CreateWindow({ Title = "Visuals", Size = Vector2.new(560, 520) }) end)
testUI("primordial", "GUIWorkspace/dist/Visuals.Primordial.lua", "PrimordialUI/dist/PrimordialUI.lua",
    function(Lib) return Lib:CreateWindow({ Title = "Visuals", Size = Vector2.new(834, 586) }) end)
print("[TEST] demo_suite DONE")
