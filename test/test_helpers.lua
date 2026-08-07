local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local rows = GV.CF({ base = "ESP_Box", text = "Box", tab = "ESP", group = "C", side = "Left",
    default = Color3.fromRGB(1, 2, 3), default2 = Color3.fromRGB(4, 5, 6), dependsOn = "ESP_En" })
T.eq(#rows, 3, "CF expande a 3 filas")
T.eq(rows[1].flag, "ESP_Box", "fila1 cp base")
T.eq(rows[2].flag, "ESP_Box_Fade", "fila2 fade toggle")
T.eq(rows[2].type, "toggle", "fila2 es toggle")
T.eq(rows[3].flag, "ESP_Box_2", "fila3 cp2")
T.eq(rows[3].dependsOn, "ESP_Box_Fade", "cp2 dep del fade")
T.eq(rows[1].tab, "ESP", "hereda tab")
local sr = GV.SchemaHelpers.suiteRows()
T.eq(sr[1].flag, "Suite_FadeSpeed", "suiteRows tiene fade speed")
T.report()
