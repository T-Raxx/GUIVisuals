-- Corre en Baseplate/Rivals con RivalsUI (ClaudeUI) en el workspace del executor.
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local Library = loadstring(readfile("Rivals/RivalsUI.lua"))()
local Window = Library:CreateWindow({ Title = "World", Size = Vector2.new(560, 500) })
local world = GV.World.new({})
local n = #GV.Renderer.build(GV.Adapters.claudeui, Window, GV.Schema, world)
world:Init()
task.wait(0.4)
print("[TEST] demo_claudeui widgets=" .. n .. " -> " .. (n > 40 and "PASS" or "FAIL"))
-- mover una prop del mundo via flags
world:Set("World_Enabled", true); world:Set("World_Fullbright", true)
task.wait(0.2)
local b = game:GetService("Lighting").Brightness
print("[TEST] fullbright Brightness=" .. tostring(b) .. " -> " .. (b == 1 and "PASS" or "FAIL"))
world:Unload()
Library:Unload()
task.wait(0.1)
print("[TEST] demo_claudeui unload OK")
