return function(GV)
    local BONES_R15 = {
        { a = "Head", b = "UpperTorso" }, { a = "UpperTorso", b = "LowerTorso" },
        { a = "UpperTorso", b = "LeftUpperArm" }, { a = "LeftUpperArm", b = "LeftLowerArm" }, { a = "LeftLowerArm", b = "LeftHand" },
        { a = "UpperTorso", b = "RightUpperArm" }, { a = "RightUpperArm", b = "RightLowerArm" }, { a = "RightLowerArm", b = "RightHand" },
        { a = "LowerTorso", b = "LeftUpperLeg" }, { a = "LeftUpperLeg", b = "LeftLowerLeg" }, { a = "LeftLowerLeg", b = "LeftFoot" },
        { a = "LowerTorso", b = "RightUpperLeg" }, { a = "RightUpperLeg", b = "RightLowerLeg" }, { a = "RightLowerLeg", b = "RightFoot" },
    }
    local BONES_R6 = {
        { a = "Head", b = "Torso" }, { a = "Torso", b = "Left Arm" }, { a = "Torso", b = "Right Arm" },
        { a = "Torso", b = "Left Leg" }, { a = "Torso", b = "Right Leg" },
    }
    local function bonesFor(model)
        return model:FindFirstChild("UpperTorso") and BONES_R15 or BONES_R6
    end
    GV.DefaultProvider = {
        getTargets = function(esp)
            local svc = esp.Services
            local out = {}
            local lp = svc.Players.LocalPlayer
            local localChar = lp and lp.Character
            local localTeam = lp and lp.Team
            local teamCheck = esp:_flag("TeamCheck", false)
            for _, p in ipairs(svc.Players:GetPlayers()) do
                local char = p.Character
                if char and char ~= localChar then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    if hum and root and head and hum.Health > 0 then
                        table.insert(out, {
                            model = char, health = hum.Health,
                            maxHealth = (hum.MaxHealth > 0 and hum.MaxHealth or 100),
                            root = root, head = head, bones = bonesFor(char), name = p.Name, team = p.Team,
                            weapon = nil, level = nil,
                            isEnemy = (not teamCheck) or (p.Team ~= localTeam),
                        })
                    end
                end
            end
            return out
        end,
    }
end
