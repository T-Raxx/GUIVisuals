local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
-- fake adapter que registra llamadas
local log = {}
local fake = {
    Tab = function(win, name) table.insert(log, "tab:" .. name); return { name = name } end,
    Group = function(tab, name, side) table.insert(log, "grp:" .. name .. ":" .. side); return { name = name } end,
    Widget = function(grp, kind, flag, opts, parent)
        table.insert(log, "w:" .. kind .. ":" .. tostring(flag) .. (parent and ":child" or ""))
        return { flag = flag, opts = opts }
    end,
    Depend = function(widget, flag, val) table.insert(log, "dep:" .. tostring(widget.flag) .. "->" .. flag) end,
}
local schema = {
    { tab = "Mundo", group = "G", side = "Left", flag = "World_Enabled", type = "toggle", text = "On", default = false, master = true },
    { tab = "Mundo", group = "G", side = "Left", flag = "World_Brightness", type = "slider", text = "B", default = 3, min = 0, max = 10, dependsOn = "World_Enabled" },
}
local world = GV.World.new({ services = T.mockServices() })
local handles = GV.Renderer.build(fake, {}, schema, world)
T.eq(world:Get("World_Brightness"), 3, "renderer siembra default")
T.truthy(table.find(log, "tab:Mundo"), "creo tab")
T.truthy(table.find(log, "w:toggle:World_Enabled"), "creo toggle")
-- callback del slider escribe al world
for _, h in ipairs(handles) do
    if h.flag == "World_Brightness" then h.opts.Callback(8) end
end
T.eq(world:Get("World_Brightness"), 8, "callback escribe al world")
-- dependencia registrada
T.truthy(table.find(log, "dep:World_Brightness->World_Enabled"), "dep registrada")
T.report()
