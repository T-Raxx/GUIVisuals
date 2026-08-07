-- Visuals Suite — ClaudeUI (Drawing API, retained, 0 instancias, HvH-safe)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/Loader.ClaudeUI.lua"))()
local BASE = "https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/"

local Library = loadstring(game:HttpGet(BASE .. "lib/RivalsUI.lua"))()
local Window = Library:CreateWindow({ Title = "Visuals Suite", Size = Vector2.new(600, 540) })

local Visuals = loadstring(game:HttpGet(BASE .. "dist/Visuals.ClaudeUI.lua"))()
-- sin profile = generico (game-agnostic). Modulos por defecto: world + esp + selffx.
-- (Preview NO se monta en ClaudeUI: seria una instancia -> se mantiene 0-instancias / undetected)
local suite = Visuals.Attach(Library, Window, {})

getgenv().Visuals = { suite = suite, lib = Library }
-- Menu: RightShift (ClaudeUI). Descargar:  getgenv().Visuals.suite:Unload(); getgenv().Visuals.lib:Unload()
warn("[Visuals] ClaudeUI cargado. Menu = RightShift. Unload: getgenv().Visuals.suite:Unload()")
return suite
