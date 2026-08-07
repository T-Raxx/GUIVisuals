local GV = loadstring(readfile("GUIWorkspace/init.lua"))()
local T = GV.T
local model = Instance.new("Model"); model.Name = "Enemy1"
local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = model
local head = Instance.new("Part"); head.Name = "Head"; head.Parent = model
local realHum = Instance.new("Humanoid"); realHum.Parent = model
local svc = {
    Players = {
        GetPlayers = function() return { { Name = "Enemy1", Character = model, Team = nil } } end,
        LocalPlayer = { Character = nil, Team = nil },
    },
    Workspace = workspace,
    RunService = { RenderStepped = { Connect = function() return { Disconnect = function() end } end } },
    CollectionService = { GetTagged = function() return {} end },
}
local e = GV.ESP.new({ services = svc, flags = {} })
local targets = GV.DefaultProvider.getTargets(e)
T.eq(#targets, 1, "1 target enumerado")
T.eq(targets[1].name, "Enemy1", "nombre")
T.eq(targets[1].root, hrp, "root = HRP")
T.truthy(targets[1].head and #targets[1].bones > 0, "head + bones")
model:Destroy()
T.report()
