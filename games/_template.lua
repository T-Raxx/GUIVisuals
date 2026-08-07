--[[ PERFIL BASE — copiar a games/<tujuego>.lua para un script nuevo.

     Los 3 modulos (World/ESP/SelfFX) corren game-agnostic SIN perfil:
       V:Attach(Lib, Win, { modules = {"world","esp","selffx"} })   -- sin profile = generico
     El perfil es OPCIONAL y solo agrega lo especifico del juego:
       V:Attach(Lib, Win, { modules = {...}, profile = "tujuego" })

     Contrato completo abajo. Todos los campos son opcionales; borra los que no uses. ]]
return function(GV)
    GV.Profiles = GV.Profiles or {}
    GV.Profiles._template = {
        -- === World (opcional) ===
        defaults = {},                                   -- overrides de flags por defecto
        textures = { rain = "rbxassetid://13911374915", snow = "rbxassetid://15414665346" },
        mapFilter = function(inst) return false end,     -- true = excluir del bloque J (skybox/char propio)
        extraSchema = {},                                -- filas de schema game-only

        -- === ESP (opcional; sin esto usa GV.DefaultProvider por Players) ===
        esp = {
            provider = {
                -- getTargets(esp) -> lista de Target normalizado:
                -- { model, health, maxHealth, root, head, bones={{a,b}...}, name, team,
                --   weapon, level, isEnemy, isPlayer }
                getTargets = function(esp) return {} end,
            },
            objectSources = {
                -- { key="Loot", tag="Loot", name="Loot", maxDistance=500 }  -- por CollectionService tag
                -- { key="Chest", classFilter="Model", name="Chest" }        -- por clase
            },
        },

        -- === SelfFX (opcional; sin esto usa camara/overlays genericos) ===
        selffx = {
            -- setFOV(offset)          -- si el juego controla la camara (ej. FOV spring propio)
            -- setThirdPerson(bool)    -- override de 3ra persona del juego
            -- flashEffects() -> {}    -- instancias de flash a neutralizar (default generico: CC/Blur "flash"/"blind")
            -- smokeEffects() -> {}    -- instancias de humo
            -- hitSignal = RBXScriptSignal  -- para el hitmarker (dispara al pegar)
            -- keybinds() -> { {name=,key=} }  -- lista para el keybind-list
        },
    }
end
