-- games/lifeinprison.lua — perfil para LifeInPrisonPrimordial. Provider FLAT (sin nesting
-- .combat/.aura): entry/attach.lua resuelve `prof[name] or prof` por modulo, y como este perfil
-- no tiene claves "combat"/"aura", TANTO combat COMO aura reciben la misma tabla completa de
-- abajo como su _provider (coincide con el contrato del design doc: 1 solo provider consumido
-- por los 2 modulos).
--
-- GOTCHA DE ORDEN (por eso onShot/onHit son funciones, no valores): bundle.lua arma
-- `local Visuals = (function() <dist GUIWorkspace> end)()` (que corre y evalua este archivo)
-- ANTES de que LiP `Core/State.lua` cree getgenv().LIP (eso pasa recien en
-- `LIP = _MODS["Core.State"](...)`, mas abajo en el bundle). Si onShot/onHit fueran valores
-- capturados en este momento (`getgenv().LIP and getgenv().LIP.onShot`), quedarian `nil` para
-- siempre — getgenv().LIP todavia no existe. Como funciones lazy, se resuelven recien en
-- Combat:Init()/Aura:Init() (llamado desde main.lua, DESPUES de Core.State) -> LIP.onShot/onHit
-- ya existen en ese punto.
return function(GV)
    GV.Profiles = GV.Profiles or {}
    local Players = game:GetService("Players")

    GV.Profiles.lifeinprison = {
        localCharacter = function()
            local plr = Players.LocalPlayer
            return plr and plr.Character
        end,
        target = function()
            local LIP = getgenv().LIP
            return LIP and LIP.target
        end,
        onShot = function()
            local LIP = getgenv().LIP
            return LIP and LIP.onShot
        end,
        onHit = function()
            local LIP = getgenv().LIP
            return LIP and LIP.onHit
        end,
    }
end
