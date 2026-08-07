local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local build = loadstring(readfile("GUIWorkspace/build.lua"))()
build(GV, "claudeui"); build(GV, "primordial")
local function countVPF()
    local n = 0
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then for _, d in ipairs(hui:GetDescendants()) do if d:IsA("ViewportFrame") then n = n + 1 end end end
    return n
end
-- Primordial: preview montado
local ModP = loadstring(readfile("GUIWorkspace/dist/Visuals.Primordial.lua"))()
local LibP = loadstring(readfile("PrimordialUI/dist/PrimordialUI.lua"))()
local WinP = LibP:CreateWindow({ Title = "Visuals", Size = Vector2.new(834, 586) })
local before = countVPF()
local sP = ModP.Attach(LibP, WinP, {})
sP.flags.Suite_Preview = true
task.wait(0.3)
print("[TEST] primordial preview mont -> " .. ((sP._preview and sP._preview.VF and sP._preview.VF.Parent) and "PASS" or "FAIL"))
print("[TEST] primordial ViewportFrame +1 -> " .. ((countVPF() > before) and "PASS" or "FAIL"))
sP:Unload(); LibP:Unload()
-- ClaudeUI: SIN preview (undetected)
local ModC = loadstring(readfile("GUIWorkspace/dist/Visuals.ClaudeUI.lua"))()
local LibC = loadstring(readfile("Rivals/RivalsUI.lua"))()
local WinC = LibC:CreateWindow({ Title = "Visuals", Size = Vector2.new(560, 500) })
local c0 = countVPF()
local sC = ModC.Attach(LibC, WinC, {})
task.wait(0.2)
print("[TEST] claudeui SIN preview -> " .. ((sC._preview == nil and countVPF() == c0) and "PASS" or "FAIL"))
sC:Unload(); LibC:Unload()
print("[TEST] demo_preview DONE")
