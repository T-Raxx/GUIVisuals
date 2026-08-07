local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
w:UseProfile(GV.Profiles.rivals)
T.truthy(w._mapFilter ~= nil, "mapFilter seteado")
T.truthy(w._tex and w._tex.rain ~= nil, "textura lluvia del perfil")
-- filtro excluye el rig propio ('Camera')
local fake = { Name = "Camera", IsA = function() return false end }
T.truthy(w._mapFilter(fake), "filtro excluye Camera")
T.report()
