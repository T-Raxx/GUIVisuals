local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- CF nuevo: colorpickers pegados al toggle `spec.toggle`, orden [cp, cp2, fadeToggle]
local rows = GV.CF({ toggle = "ESP_Box", base = "ESP_BoxColor", text = "Box", tab = "ESP", group = "C", side = "Left",
    default = Color3.fromRGB(1, 2, 3), default2 = Color3.fromRGB(4, 5, 6) })
T.eq(#rows, 3, "CF expande a 3 filas")
T.eq(rows[1].flag, "ESP_BoxColor", "fila1 cp base")
T.eq(rows[1].attach, "ESP_Box", "fila1 attach al toggle")
T.eq(rows[2].flag, "ESP_BoxColor_2", "fila2 cp2")
T.eq(rows[2].attach, "ESP_Box", "fila2 attach al toggle")
T.eq(rows[3].flag, "ESP_BoxColor_Fade", "fila3 fade toggle")
T.eq(rows[3].type, "toggle", "fila3 es toggle")
T.eq(rows[3].dependsOn, "ESP_Box", "fade dep del toggle")
T.eq(rows[1].tab, "ESP", "hereda tab")
local sr = GV.SchemaHelpers.suiteRows()
T.eq(sr[1].flag, "Suite_FadeSpeed", "suiteRows tiene fade speed")
T.report()
