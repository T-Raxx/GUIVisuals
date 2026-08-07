local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local w = GV.World.new({ services = T.mockServices() })
w:Set("World_Enabled", true)
w:Set("World_Tint", true); w:Set("World_TintSaturation", -1); w:_step()
local cc = w._fxCache.ColorCorrectionEffect
T.truthy(cc, "CC creado"); T.eq(cc.Enabled, true, "CC enabled"); T.eq(cc.Saturation, -1, "CC saturation")
w:Set("World_Bloom", true); w:Set("World_BloomIntensity", 2); w:_step()
T.eq(w._fxCache.BloomEffect.Intensity, 2, "bloom intensity")
w:Set("World_Tint", false); w:_step()
T.eq(cc.Enabled, false, "CC off")
w:Unload()
T.report()
