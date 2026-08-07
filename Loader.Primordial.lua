-- Visuals Suite — PrimordialUI (instance-based, replica primordial.dev)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/Loader.Primordial.lua"))()
local BASE = "https://raw.githubusercontent.com/T-Raxx/GUIVisuals/main/"

local Lib = loadstring(game:HttpGet(BASE .. "lib/PrimordialUI.lua"))()
local Window = Lib:CreateWindow({ Title = "Visuals Suite", Size = Vector2.new(834, 586) })

local Visuals = loadstring(game:HttpGet(BASE .. "dist/Visuals.Primordial.lua"))()
-- sin profile = generico (game-agnostic). Modulos por defecto: world + esp + selffx.
-- Preview viewport (ventana separada) disponible aca: toggle "Preview (solo Primordial)" en el grupo Suite.
local suite = Visuals.Attach(Lib, Window, {})

getgenv().Visuals = { suite = suite, lib = Lib }
warn("[Visuals] PrimordialUI cargado. Unload: getgenv().Visuals.suite:Unload()")
return suite
