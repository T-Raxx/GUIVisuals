local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local S = GV.Modules.selffx.schema
T.truthy(S and #S > 20, "local schema >20 (#" .. tostring(S and #S) .. ")")
local flags = {}
for _, r in ipairs(S) do if r.flag then flags[r.flag] = true end end
local ok = true
for _, r in ipairs(S) do if r.dependsOn and not flags[r.dependsOn] then ok = false; print("dep rota:", r.flag, "->", r.dependsOn) end end
T.truthy(ok, "deps resueltas")
T.truthy(flags["Local_Enabled"] and flags["Local_CrosshairColor"] and flags["Local_CrosshairColor_Fade"], "flags clave + CF")
-- base game-agnostic: el contrato vive en el _template (no en un juego)
T.truthy(GV.Profiles._template and GV.Profiles._template.selffx and GV.Profiles._template.esp, "template = contrato base (esp+selffx)")
-- corre sin perfil (generico): DefaultProvider existe
T.truthy(GV.DefaultProvider ~= nil, "ESP generico (DefaultProvider) sin perfil")
T.report()
