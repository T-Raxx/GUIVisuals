local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
local L = w.Services.Lighting
w:Set("World_Enabled", true)
w:Set("World_Ambient", true) -- toggle ambient
-- fade OFF: color = c1 (regresion)
w:Set("World_AmbientColor", Color3.fromRGB(20, 20, 20))
w:_step()
T.eq(L.Ambient, Color3.fromRGB(20, 20, 20), "fade off = c1 (regresion)")
-- fade ON: color != c1 puro (mezcla) en alguna muestra
w:Set("World_AmbientColor_2", Color3.fromRGB(200, 200, 200))
w:Set("World_AmbientColor_Fade", true)
w:Set("Suite_FadeSpeed", 1)
local diff = false
for i = 1, 8 do
    w:_applyLighting()
    if L.Ambient ~= Color3.fromRGB(20, 20, 20) then diff = true break end
    task.wait(0.03)
end
T.truthy(diff, "fade on cambia el color en el tiempo")
w:_restoreAll()
T.report()
