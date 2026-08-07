--[[ RESEARCH: Custom Aspect Ratio sin function-hooks (fase C, 2026-08-07)
     Probado en Potassium contra Baseplate live.

     RESULTADO:
     - c1 setscriptable(cam,"ViewportSize",true) + write  -> ERROR "Property is read only"
     - c2 sethiddenproperty(cam,"ViewportSize", Vector2) -> ERROR "Property is read only"
     - c3 cam.FieldOfViewMode = MaxAxis + MaxAxisFieldOfView -> OK (FOV 70 -> 64.1, cambia mapeo FOV<->aspecto)

     CONCLUSION: en Potassium ViewportSize es read-only DURO (ni setscriptable ni sethiddenproperty
     lo escriben) -> stretch pixel-real NO reproducible sin render-hooks. El user lo vio funcionar en
     Solara, que probablemente expone una escritura de render que Potassium bloquea.
     Mecanismo entregable = FieldOfViewMode (Vertical/Diagonal/MaxAxis) + MaxAxisFieldOfView.
     Implementado así en core/selffx.lua:_applyCamera (flag Local_AspectMode / Local_MaxAxisFOV).
]]
local cam = workspace.CurrentCamera
local base = { vs = cam.ViewportSize, fov = cam.FieldOfView, mode = cam.FieldOfViewMode }
print("[RESEARCH] baseline", tostring(base.vs), base.fov, tostring(base.mode))
print("[RESEARCH] setscriptable=" .. tostring(setscriptable ~= nil) .. " sethiddenproperty=" .. tostring(sethiddenproperty ~= nil))
print("[RESEARCH] c1", pcall(function() setscriptable(cam, "ViewportSize", true); cam.ViewportSize = Vector2.new(base.vs.X * 0.55, base.vs.Y) end))
print("[RESEARCH] c2", pcall(function() sethiddenproperty(cam, "ViewportSize", Vector2.new(1000, base.vs.Y)) end))
print("[RESEARCH] c3", pcall(function() cam.FieldOfViewMode = Enum.FieldOfViewMode.MaxAxis; cam.MaxAxisFieldOfView = 100 end), "FOV=" .. cam.FieldOfView)
cam.FieldOfViewMode = base.mode; cam.FieldOfView = base.fov -- restore
print("[RESEARCH] restaurado")
