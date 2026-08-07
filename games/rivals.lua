return function(GV)
    GV.Profiles = GV.Profiles or {}
    local Players = game:GetService("Players")
    GV.Profiles.rivals = {
        defaults = { World_FogColor = Color3.fromRGB(190, 195, 210) },
        textures = { rain = "rbxassetid://13911374915", snow = "rbxassetid://15414665346" },
        -- excluir el rig de clima propio ('Camera'), la camara y el char del jugador
        mapFilter = function(inst)
            if inst.Name == "Camera" then return true end
            local cam = workspace.CurrentCamera
            if cam then local ok, r = pcall(function() return inst:IsDescendantOf(cam) end); if ok and r then return true end end
            local plr = Players.LocalPlayer
            if plr and plr.Character then
                local ok, r = pcall(function() return inst:IsDescendantOf(plr.Character) end)
                if ok and r then return true end
            end
            return false
        end,
        extraSchema = {}, -- controles Rivals-only si aparecen
    }

    -- Perfil ESP de Rivals: enumera por tag "Entity" (fighters + dummies), FFA.
    local BONES_R15 = {
        { a = "Head", b = "UpperTorso" }, { a = "UpperTorso", b = "LowerTorso" },
        { a = "UpperTorso", b = "LeftUpperArm" }, { a = "LeftUpperArm", b = "LeftLowerArm" }, { a = "LeftLowerArm", b = "LeftHand" },
        { a = "UpperTorso", b = "RightUpperArm" }, { a = "RightUpperArm", b = "RightLowerArm" }, { a = "RightLowerArm", b = "RightHand" },
        { a = "LowerTorso", b = "LeftUpperLeg" }, { a = "LeftUpperLeg", b = "LeftLowerLeg" }, { a = "LeftLowerLeg", b = "LeftFoot" },
        { a = "LowerTorso", b = "RightUpperLeg" }, { a = "RightUpperLeg", b = "RightLowerLeg" }, { a = "RightLowerLeg", b = "RightFoot" },
    }
    GV.Profiles.rivals.esp = {
        provider = {
            getTargets = function(esp)
                local out = {}
                local myChar = Players.LocalPlayer and Players.LocalPlayer.Character
                for _, model in ipairs(esp.Services.CollectionService:GetTagged("Entity")) do
                    if model ~= myChar and model:IsA("Model") then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        local root = model:FindFirstChild("HumanoidRootPart")
                        local head = model:FindFirstChild("Head")
                        if hum and root and head and hum.Health > 0 then
                            local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
                            table.insert(out, {
                                model = model, health = hum.Health, maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),
                                root = root, head = head, bones = BONES_R15, name = model.Name, team = nil,
                                weapon = nil, level = nil, isEnemy = true, isPlayer = isPlayer,
                            })
                        end
                    end
                end
                return out
            end,
        },
        objectSources = {
            { key = "Grenade", tag = "Grenade", name = "Granada", maxDistance = 500 },
            { key = "Trap", tag = "Trap", name = "Trampa", maxDistance = 500 },
        },
    }
end
