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
end
