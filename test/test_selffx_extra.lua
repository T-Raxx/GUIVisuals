local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local fx = Instance.new("ColorCorrectionEffect")
local s = GV.SelfFX.new({ flags = {}, services = T.mockServices(),
    provider = { flashEffects = function() return { fx } end } })
s:Set("Local_Enabled", true); s:Set("Local_AntiFlash", true)
s:_applyAntiFlash()
T.eq(fx.Enabled, false, "anti-flash desactiva el efecto")
s:_restoreAll()
T.eq(fx.Enabled, true, "restore reactiva")
fx:Destroy()
T.report()
