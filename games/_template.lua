return function(GV)
    GV.Profiles = GV.Profiles or {}
    -- Perfil en blanco: copiar para juegos nuevos.
    GV.Profiles._template = {
        defaults = {},
        textures = { rain = "rbxassetid://13911374915", snow = "rbxassetid://15414665346" },
        mapFilter = function(inst) return false end, -- no excluye nada
        extraSchema = {},                             -- controles game-only
    }
end
