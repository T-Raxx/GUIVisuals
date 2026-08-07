local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Schema
T.truthy(#S > 40, "schema tiene >40 controles (#" .. tostring(#S) .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do
    if not (r.tab and r.group and r.type) then ok = false end
    if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end
end
T.truthy(ok, "todas las filas validas + deps resueltas")
T.truthy(flags["World_Enabled"] and flags["World_Weather"] and flags["World_WaterEnable"], "flags clave presentes")
T.report()
