local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local build = loadstring(readfile("GUIWorkspace/build.lua"))()
build(GV, "claudeui"); build(GV, "primordial")
print("[TEST] dist visuals: claudeui=" .. tostring(isfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua")) ..
    " primordial=" .. tostring(isfile("GUIWorkspace/dist/Visuals.Primordial.lua")))
-- montar claudeui + verificar fade anima Ambient
local Mod = loadstring(readfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua"))()
local Lib = loadstring(readfile("Rivals/RivalsUI.lua"))()
local Win = Lib:CreateWindow({ Title = "Visuals", Size = Vector2.new(560, 500) })
local suite = Mod.Attach(Lib, Win, { profile = "rivals" })
suite.flags.World_Enabled = true
suite.flags.World_Ambient = Color3.fromRGB(255, 0, 0)
suite.flags.World_Ambient_2 = Color3.fromRGB(0, 0, 255)
suite.flags.World_Ambient_Fade = true
suite.flags.Suite_FadeSpeed = 2
task.wait(0.5)
local a1 = game:GetService("Lighting").Ambient
task.wait(0.4)
local a2 = game:GetService("Lighting").Ambient
print("[TEST] fade anima Ambient -> " .. ((a1 ~= a2) and "PASS" or "FAIL"))
suite:Unload(); Lib:Unload()
print("[TEST] demo_suite DONE")
