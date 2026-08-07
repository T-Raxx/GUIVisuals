-- corre todos los tests unitarios (no demos) y reporta
local files = {
    "smoke", "test_util", "test_core", "test_apply_ab", "test_apply_cd", "test_apply_e",
    "test_apply_fg", "test_apply_hi", "test_apply_jk", "test_facade", "test_renderer",
    "test_schema", "test_profile", "test_build",
}
for _, f in ipairs(files) do
    print("=== " .. f .. " ===")
    local ok, err = pcall(function() loadstring(readfile("GUIWorkspace/test/" .. f .. ".lua"), "@" .. f)() end)
    if not ok then print("[TEST] " .. f .. " CRASH: " .. tostring(err)) end
end
print("[TEST] ALL DONE")
