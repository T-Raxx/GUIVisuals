local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local e = GV.ESP.new({ flags = {} })
-- color mode Team: enemigo != aliado
e:Set("ESP_ColorMode", "Team")
e:Set("ESP_BoxColor", Color3.fromRGB(255, 255, 255))
local cEnemy = e:_col({ isEnemy = true }, "ESP_BoxColor", 0)
local cAlly = e:_col({ isEnemy = false }, "ESP_BoxColor", 0)
T.truthy(cEnemy ~= cAlly, "team mode: enemigo != aliado")
-- filtro dead
e:Set("ESP_DeadCheck", true)
T.truthy(e:_passFilters({ health = 0 }) == false, "dead filtrado")
T.truthy(e:_passFilters({ health = 50 }) == true, "vivo pasa")
-- visibility mode
e:Set("ESP_ColorMode", "Visibilidad")
e:Set("ESP_VisibleColor", Color3.fromRGB(0, 255, 0))
e:Set("ESP_HiddenColor", Color3.fromRGB(255, 0, 0))
local cv = e:_col({ _visible = true }, "ESP_BoxColor", 0)
local ch = e:_col({ _visible = false }, "ESP_BoxColor", 0)
T.truthy(cv ~= ch, "visibility mode: visible != oculto")
T.report()
