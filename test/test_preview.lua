local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local suite = { flags = { Suite_Preview = true } }
local p = GV.Preview.mount(suite, { always = true })
T.truthy(p and p.VF and p.VF:IsA("ViewportFrame"), "ViewportFrame creado")
T.truthy(p.World and p.World:IsA("WorldModel"), "WorldModel creado")
local dummy = T.spawnDummy()
p:SetModel(dummy)
T.truthy(p.Model and p.Model.Parent == p.World, "modelo clonado en el viewport")
p:Unload()
T.truthy(p.VF.Parent == nil, "Unload destruye el viewport")
dummy:Destroy()
T.report()
