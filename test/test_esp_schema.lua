local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Modules.esp.schema
T.truthy(S and #S > 30, "esp schema >30 (#" .. tostring(S and #S) .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do
    if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end
end
T.truthy(ok, "deps resueltas")
T.truthy(flags["ESP_Enabled"] and flags["ESP_BoxColor"] and flags["ESP_BoxColor_Fade"] and flags["ESP_BoxColor_2"], "flags clave + CF")
T.truthy(GV.Profiles.rivals.esp and GV.Profiles.rivals.esp.provider, "rivals.esp provider")
T.report()
