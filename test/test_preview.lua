local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local suite = { flags = { Suite_Preview = true } }
local p = GV.Preview.mount(suite, { always = true })
T.truthy(p and p.VF and p.VF:IsA("ViewportFrame"), "ViewportFrame creado")
T.truthy(p.World and p.World:IsA("WorldModel"), "WorldModel creado")
local dummy = T.spawnDummy()
p:SetModel(dummy)
T.truthy(p.Model and p.Model.Parent == p.World, "modelo clonado en el viewport")
-- D2: live chams + box
p.suite.flags.ESP_Chams = true
p.suite.flags.ESP_ChamsFill = Color3.fromRGB(255, 0, 255)
p:_step(0)
T.truthy(p._chams and p._chams.Enabled, "chams Highlight en preview")
T.eq(p._chams.FillColor, Color3.fromRGB(255, 0, 255), "chams fill color")
T.truthy(p._box and p._box.Visible, "box overlay visible")
T.truthy(#p._matrix == 10, "matrix rain 10 columnas")
p:Unload()
T.truthy(p.VF.Parent == nil, "Unload destruye el viewport")
dummy:Destroy()
T.report()
