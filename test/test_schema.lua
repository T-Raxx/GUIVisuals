local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Schema
T.truthy(#S > 90, "schema >90 filas (#" .. #S .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do
    if not (r.tab and r.group and r.type) then ok = false end
    if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end
end
T.truthy(ok, "filas validas + deps resueltas")
T.truthy(flags["World_Ambient"] and flags["World_Ambient_Fade"] and flags["World_Ambient_2"], "Ambient tiene CF (base/fade/2)")
T.truthy(flags["World_WeatherColor_2"] and flags["World_FogColor_Fade"], "Weather/Fog color con CF")
T.truthy(GV.Modules.world.schema == S, "registrado en Modules.world.schema")
T.report()
