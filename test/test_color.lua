local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local Cc = GV.Color
local flags = { X = Color3.fromRGB(255, 0, 0), X_2 = Color3.fromRGB(0, 0, 255), Suite_FadeSpeed = 1 }
-- fade off -> c1 solido
T.eq(Cc.fade(flags, "X", 0), Color3.fromRGB(255, 0, 0), "fade off = c1")
-- fade on -> t=0 -> sin(0)=0 -> a=0.5 -> mezcla
flags.X_Fade = true
local mid = Cc.fade(flags, "X", 0)
T.near(mid.B, 0.5, 0.02, "fade on mezcla azul ~0.5")
-- guarda: flag no seteada -> blanco
T.eq(Cc.fade({}, "Nope", 0), Color3.new(1, 1, 1), "guarda nil -> blanco")
T.report()
