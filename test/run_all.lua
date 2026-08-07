-- corre todos los tests unitarios (no demos) y reporta
local files = {
    "smoke", "test_util", "test_color", "test_helpers", "test_core", "test_suite",
    "test_apply_ab", "test_apply_cd", "test_apply_e", "test_apply_fg", "test_apply_hi",
    "test_apply_jk", "test_world_fade", "test_facade", "test_renderer", "test_schema",
    "test_profile", "test_build",
    "test_esp_core", "test_esp_provider", "test_esp_filters", "test_esp_schema",
    "test_selffx_core", "test_selffx_cam", "test_selffx_extra", "test_selffx_schema",
    "test_preview",
}
for _, f in ipairs(files) do
    print("=== " .. f .. " ===")
    local ok, err = pcall(function() loadstring(readfile("GUIWorkspace/test/" .. f .. ".lua"), "@" .. f)() end)
    if not ok then print("[TEST] " .. f .. " CRASH: " .. tostring(err)) end
end
print("[TEST] ALL DONE")
