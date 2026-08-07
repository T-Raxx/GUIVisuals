-- smoke: prueba que el loader arma GV y el harness reporta.
local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
T.truthy(GV.Util, "util cargado")
T.eq(1 + 1, 2, "aritmetica")
T.report()
