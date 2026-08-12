-- core/aura.lua — modulo "aura": 15 auras cosmeticas sobre el char local (6 procedural + 9
-- rbxassetid), port 1:1 de jujudotlol.lua L19679-20335 (builders L19688-20108, asset loader
-- L20111-20119, apply/reparent L20140-20193, color-apply L20287-20330).
--
-- Mecanismo (identico a juju): cada aura es un Model "plantilla" cuyos hijos directos son Parts
-- placeholder nombrados como partes del char (UpperTorso/LowerTorso/Head/HumanoidRootPart/...),
-- cada uno con Attachment/Beam/ParticleEmitter/PointLight como hijos. Al aplicar: clonar la
-- plantilla, y por cada Part placeholder buscar la parte REAL del char por nombre (ver
-- `_resolvePart`); si hay match, reparentar sus hijos directos sobre ella (renombrados
-- "\0\0"/"\0\0att" — stealth, igual que juju); si no hay match ni fallback, destruir ese
-- placeholder (con sus hijos).
--
-- Adaptacion vs juju (necesaria, no cosmetica): LiP es R6 (ver docs/ops.md) pero los placeholders
-- (propios y de varios de los 9 assets) usan nombres R15 (UpperTorso/LeftUpperArm/...). juju nunca
-- necesita esto (corre en un juego R15) — un match por nombre EXACTO dejaria angel wing/blue
-- heat/heal aura sin un solo emitter en R6 (UpperTorso/LowerTorso/LeftUpperArm/... no existen en
-- ese rig). `_resolvePart` intenta el nombre exacto primero y cae a un mapa R15->R6 (ver
-- R15_TO_R6) antes de descartar el placeholder. Varios nombres R15 colapsan al mismo Part R6
-- (ej. UpperTorso y LowerTorso -> "Torso"): sus grupos de emitters terminan apilados en esa unica
-- parte en vez de perderse — degradacion visual aceptable, cobertura completa del rig.
--
-- Adaptacion deliberada vs juju (no cambia el mecanismo, solo el momento): juju arma las 9 auras
-- rbxassetid EAGER al cargar el modulo (9 game:GetObjects en la carga del cheat completo). Acá se
-- cargan LAZY (primera vez que el nombre aparece seleccionado), cacheadas por nombre — evita 9
-- fetches de red cada vez que el cheat entero carga aunque el usuario nunca abra el tab Aura.
return function(GV)
    local Aura = {}
    Aura.__index = Aura

    local DEFAULT_COLOR = Color3.fromRGB(133, 220, 255)

    ------------------------------------------------------------------------------------------
    -- procedural builders (juju L19688-20108) — transcripcion 1:1 (mismos valores/texturas)
    ------------------------------------------------------------------------------------------
    local function buildAngelWingAura()
        local model = Instance.new("Model")
        model.Name = "angel wing"
        local torso = Instance.new("Part")
        torso.Name = "UpperTorso"
        torso.Parent = model

        local att1 = Instance.new("Attachment")
        att1.Name = "AngelAtt1"
        att1.CFrame = CFrame.new(0, 4.25, 0)
        att1.Parent = torso

        local pe1 = Instance.new("ParticleEmitter")
        pe1.Acceleration = Vector3.new(0, -6, 0)
        pe1.Brightness = 1
        pe1.Color = ColorSequence.new(Color3.new(1, 1, 1))
        pe1.EmissionDirection = Enum.NormalId.Bottom
        pe1.Enabled = true
        pe1.Lifetime = NumberRange.new(1, 2)
        pe1.LightEmission = 1
        pe1.LightInfluence = 1
        pe1.LockedToPart = true
        pe1.Orientation = Enum.ParticleOrientation.FacingCamera
        pe1.Rate = 50
        pe1.RotSpeed = NumberRange.new(-100, 100)
        pe1.Rotation = NumberRange.new(-360, 360)
        pe1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5, 0.3), NumberSequenceKeypoint.new(1, 0.5, 0.3) })
        pe1.Speed = NumberRange.new(2.5, 2.5)
        pe1.SpreadAngle = Vector2.new(0, 360)
        pe1.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
        pe1.Texture = "rbxassetid://7511321694"
        pe1.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0),
            NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),
        })
        pe1.VelocityInheritance = 0
        pe1.WindAffectsDrag = false
        pe1.Parent = att1

        local pe2 = Instance.new("ParticleEmitter")
        pe2.Acceleration = Vector3.new(0, -6, 0)
        pe2.Brightness = 1
        pe2.Color = ColorSequence.new(Color3.new(1, 1, 1))
        pe2.EmissionDirection = Enum.NormalId.Bottom
        pe2.Enabled = true
        pe2.Lifetime = NumberRange.new(1, 2)
        pe2.LightEmission = 1
        pe2.LightInfluence = 1
        pe2.LockedToPart = true
        pe2.Orientation = Enum.ParticleOrientation.FacingCamera
        pe2.Rate = 100
        pe2.RotSpeed = NumberRange.new(-100, 100)
        pe2.Rotation = NumberRange.new(-360, 360)
        pe2.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5, 0.3), NumberSequenceKeypoint.new(1, 0.5, 0.3) })
        pe2.Speed = NumberRange.new(2.5, 2.5)
        pe2.SpreadAngle = Vector2.new(0, 360)
        pe2.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
        pe2.Texture = "rbxassetid://1084976679"
        pe2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0),
            NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),
        })
        pe2.VelocityInheritance = 0
        pe2.WindAffectsDrag = false
        pe2.Parent = att1

        local att2 = Instance.new("Attachment")
        att2.Name = "AngelAtt2"
        att2.CFrame = CFrame.new(0, 0.75, 0.5)
        att2.Parent = torso
        local att3 = Instance.new("Attachment")
        att3.Name = "AngelAtt3"
        att3.CFrame = CFrame.new(-5.25, 0, 2) * CFrame.fromMatrix(Vector3.new(0, 0, 0),
            Vector3.new(0.866025388, 0, 0.5), Vector3.new(0, 1, 0), Vector3.new(-0.5, 0, 0.866025388))
        att3.Parent = torso
        local att4 = Instance.new("Attachment")
        att4.Name = "AngelAtt4"
        att4.CFrame = CFrame.new(5.25, 0, 2) * CFrame.fromMatrix(Vector3.new(0, 0, 0),
            Vector3.new(0.866025388, 0, -0.5), Vector3.new(0, 1, 0), Vector3.new(0.5, 0, 0.866025388))
        att4.Parent = torso

        local beam1 = Instance.new("Beam")
        beam1.Attachment0 = att2
        beam1.Attachment1 = att3
        beam1.Brightness = 1
        beam1.Color = ColorSequence.new(Color3.new(1, 1, 1))
        beam1.CurveSize0 = 2
        beam1.CurveSize1 = 2
        beam1.Enabled = true
        beam1.FaceCamera = false
        beam1.LightEmission = 1
        beam1.LightInfluence = 1
        beam1.Segments = 10
        beam1.Texture = "rbxassetid://9544400688"
        beam1.TextureLength = 1
        beam1.TextureMode = Enum.TextureMode.Stretch
        beam1.TextureSpeed = 0
        beam1.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
        beam1.Width0 = 4
        beam1.Width1 = 6
        beam1.Parent = torso

        local beam2 = Instance.new("Beam")
        beam2.Attachment0 = att2
        beam2.Attachment1 = att4
        beam2.Brightness = 1
        beam2.Color = ColorSequence.new(Color3.new(1, 1, 1))
        beam2.CurveSize0 = -2
        beam2.CurveSize1 = -2
        beam2.Enabled = true
        beam2.FaceCamera = false
        beam2.LightEmission = 1
        beam2.LightInfluence = 1
        beam2.Segments = 10
        beam2.Texture = "rbxassetid://9544400688"
        beam2.TextureLength = 1
        beam2.TextureMode = Enum.TextureMode.Stretch
        beam2.TextureSpeed = 0
        beam2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
        beam2.Width0 = 4
        beam2.Width1 = 6
        beam2.Parent = torso

        local pl = Instance.new("PointLight")
        pl.Brightness = 1
        pl.Color = Color3.new(1, 1, 1)
        pl.Enabled = true
        pl.Range = 5
        pl.Shadows = false
        pl.Parent = torso

        return model
    end

    local function buildBlueHeatAura()
        local model = Instance.new("Model")
        model.Name = "blue heat"
        local blueheatColor = Color3.fromRGB(15, 15, 255)
        local partsToUse = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }
        for _, partName in ipairs(partsToUse) do
            local part = Instance.new("Part")
            part.Name = partName
            part.Parent = model

            local atom1 = Instance.new("ParticleEmitter")
            atom1.Name = "BhAtom1"
            atom1.Acceleration = Vector3.new(0, 1, 0)
            atom1.Brightness = 10
            atom1.Color = ColorSequence.new(blueheatColor)
            atom1.Drag = 50
            atom1.EmissionDirection = Enum.NormalId.Top
            atom1.Enabled = true
            atom1.Lifetime = NumberRange.new(0.4, 0.6)
            atom1.LightEmission = 1
            atom1.LightInfluence = 0
            atom1.LockedToPart = false
            atom1.Orientation = Enum.ParticleOrientation.FacingCamera
            atom1.Rate = 20
            atom1.RotSpeed = NumberRange.new(0, 0)
            atom1.Rotation = NumberRange.new(-360, 360)
            atom1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.125), NumberSequenceKeypoint.new(1, 0) })
            atom1.Speed = NumberRange.new(30, 40)
            atom1.SpreadAngle = Vector2.new(90, 90)
            atom1.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) })
            atom1.Texture = "rbxassetid://11448304274"
            atom1.TimeScale = 0.75
            atom1.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.500529, 0), NumberSequenceKeypoint.new(1, 1),
            })
            atom1.VelocityInheritance = 0
            atom1.WindAffectsDrag = false
            atom1.ZOffset = -1
            atom1.Parent = part

            local flame1 = Instance.new("ParticleEmitter")
            flame1.Name = "BhFlame1"
            flame1.Acceleration = Vector3.new(0, 1, 0)
            flame1.Brightness = 10
            flame1.Color = ColorSequence.new(blueheatColor)
            flame1.EmissionDirection = Enum.NormalId.Top
            flame1.Enabled = true
            flame1.Lifetime = NumberRange.new(0.4, 0.6)
            flame1.LightEmission = 1
            flame1.LightInfluence = 0
            flame1.LockedToPart = false
            flame1.Orientation = Enum.ParticleOrientation.FacingCamera
            flame1.Rate = 150
            flame1.RotSpeed = NumberRange.new(0, 0)
            flame1.Rotation = NumberRange.new(-360, 360)
            flame1.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
            flame1.Speed = NumberRange.new(1, 2)
            flame1.SpreadAngle = Vector2.new(90, 90)
            flame1.Texture = "rbxassetid://10545078665"
            flame1.TimeScale = 0.75
            flame1.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.500529, 0), NumberSequenceKeypoint.new(1, 1),
            })
            flame1.ZOffset = -1
            flame1.Parent = part

            local glow = Instance.new("ParticleEmitter")
            glow.Name = "BhGlow"
            glow.Acceleration = Vector3.new(0, 1, 0)
            glow.Brightness = 10
            glow.Color = ColorSequence.new(blueheatColor)
            glow.EmissionDirection = Enum.NormalId.Top
            glow.Enabled = true
            glow.FlipbookFramerate = NumberRange.new(30, 30)
            glow.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
            glow.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
            glow.Lifetime = NumberRange.new(0.4, 0.6)
            glow.LightEmission = 1
            glow.LightInfluence = 0
            glow.LockedToPart = true
            glow.Orientation = Enum.ParticleOrientation.FacingCamera
            glow.Rate = 200
            glow.RotSpeed = NumberRange.new(0, 0)
            glow.Rotation = NumberRange.new(-360, 360)
            glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.5) })
            glow.Speed = NumberRange.new(0.1, 0.1)
            glow.SpreadAngle = Vector2.new(360, 360)
            glow.Texture = "rbxassetid://8451174579"
            glow.TimeScale = 0.75
            glow.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9125), NumberSequenceKeypoint.new(1, 1),
            })
            glow.ZOffset = 1
            glow.Parent = part
        end
        return model
    end

    local function buildHealAura()
        local model = Instance.new("Model")
        model.Name = "heal aura"
        local torso = Instance.new("Part")
        torso.Name = "LowerTorso"
        torso.Parent = model
        local att = Instance.new("Attachment")
        att.Parent = torso

        local hw1 = Instance.new("ParticleEmitter")
        hw1.Name = "HealingWave1"
        hw1.Lifetime = NumberRange.new(1.5, 1.5)
        hw1.SpreadAngle = Vector2.new(10, -10)
        hw1.LockedToPart = true
        hw1.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1702454, 0.7, 0.014881),
            NumberSequenceKeypoint.new(0.2254601, 0.03125, 0.03125), NumberSequenceKeypoint.new(0.2852761, 0),
            NumberSequenceKeypoint.new(0.702454, 0), NumberSequenceKeypoint.new(0.8374233, 0.9125, 0.0601461),
            NumberSequenceKeypoint.new(1, 1),
        })
        hw1.LightEmission = 0.4
        hw1.Color = ColorSequence.new(Color3.fromRGB(234, 8, 255))
        hw1.VelocitySpread = 10
        hw1.Speed = NumberRange.new(3, 6)
        hw1.Brightness = 10
        hw1.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3.0624998, 1.8805969), NumberSequenceKeypoint.new(0.6420546, 1.9999999, 1.7619393),
            NumberSequenceKeypoint.new(1, 0.7499999, 0.7499999),
        })
        hw1.Rate = 20
        hw1.Texture = "rbxassetid://8047533775"
        hw1.RotSpeed = NumberRange.new(200, 400)
        hw1.Rotation = NumberRange.new(-180, 180)
        hw1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        hw1.Parent = att

        local hw2 = Instance.new("ParticleEmitter")
        hw2.Name = "HealingWave2"
        hw2.Lifetime = NumberRange.new(1.5, 1.5)
        hw2.SpreadAngle = Vector2.new(10, -10)
        hw2.LockedToPart = true
        hw2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2254601, 0.03125, 0.03125),
            NumberSequenceKeypoint.new(0.6288344, 0.25625, 0.0593491), NumberSequenceKeypoint.new(0.8374233, 0.9125, 0.0601461),
            NumberSequenceKeypoint.new(1, 1),
        })
        hw2.LightEmission = 1
        hw2.Color = ColorSequence.new(Color3.fromRGB(238, 3, 255))
        hw2.VelocitySpread = 10
        hw2.Speed = NumberRange.new(3, 5)
        hw2.Brightness = 10
        hw2.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3.125), NumberSequenceKeypoint.new(0.4165329, 1.3749999, 1.3749999),
            NumberSequenceKeypoint.new(1, 0.9375, 0.9375),
        })
        hw2.Rate = 20
        hw2.Texture = "rbxassetid://8047796070"
        hw2.RotSpeed = NumberRange.new(100, 300)
        hw2.Rotation = NumberRange.new(-180, 180)
        hw2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        hw2.Parent = att

        local sparks = Instance.new("ParticleEmitter")
        sparks.Name = "HealSparks"
        sparks.Lifetime = NumberRange.new(0.5, 2)
        sparks.SpreadAngle = Vector2.new(180, -180)
        sparks.LightEmission = 1
        sparks.Color = ColorSequence.new(Color3.fromRGB(255, 21, 255))
        sparks.Drag = 3
        sparks.VelocitySpread = 180
        sparks.Speed = NumberRange.new(5, 15)
        sparks.Brightness = 10
        sparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.14687, 0.4374999, 0.1875001), NumberSequenceKeypoint.new(1, 0),
        })
        sparks.Acceleration = Vector3.new(0, 3, 0)
        sparks.ZOffset = -1
        sparks.Rate = 40
        sparks.Texture = "rbxassetid://8611887361"
        sparks.RotSpeed = NumberRange.new(-30, 30)
        sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
        sparks.Parent = att

        local starSparks = Instance.new("ParticleEmitter")
        starSparks.Name = "HealStarSparks"
        starSparks.Lifetime = NumberRange.new(1.5, 1.5)
        starSparks.SpreadAngle = Vector2.new(180, -180)
        starSparks.LightEmission = 1
        starSparks.Color = ColorSequence.new(Color3.fromRGB(226, 60, 255))
        starSparks.Drag = 3
        starSparks.VelocitySpread = 180
        starSparks.Speed = NumberRange.new(5, 10)
        starSparks.Brightness = 10
        starSparks.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1492777, 0.6874996, 0.6874996), NumberSequenceKeypoint.new(1, 0),
        })
        starSparks.Acceleration = Vector3.new(0, 3, 0)
        starSparks.ZOffset = 2
        starSparks.Texture = "rbxassetid://8611887703"
        starSparks.RotSpeed = NumberRange.new(-30, 30)
        starSparks.Rotation = NumberRange.new(-30, 30)
        starSparks.Parent = att

        return model
    end

    local function buildAmbientAura()
        local model = Instance.new("Model")
        model.Name = "ambient"
        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Parent = model
        local att = Instance.new("Attachment")
        att.CFrame = CFrame.new(0, -2.75, 0)
        att.Parent = hrp

        local e1 = Instance.new("ParticleEmitter")
        e1.Name = "Ambient1"
        e1.Lifetime = NumberRange.new(2, 2)
        e1.SpreadAngle = Vector2.new(0.001, 0.001)
        e1.LockedToPart = true
        e1.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        e1.LightEmission = 1
        e1.VelocitySpread = 0.001
        e1.Squash = NumberSequence.new(0)
        e1.Speed = NumberRange.new(0.001, 0.001)
        e1.Brightness = 2
        e1.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 2.5),
            NumberSequenceKeypoint.new(0.8, 4), NumberSequenceKeypoint.new(1, 6),
        })
        e1.RotSpeed = NumberRange.new(-600, 600)
        e1.Texture = "https://assetgame.roblox.com/asset/?id=12713358087&assetName=crescent"
        e1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e1.Rotation = NumberRange.new(0, 360)
        e1.Parent = att

        local e2 = Instance.new("ParticleEmitter")
        e2.Name = "Ambient2"
        e2.Lifetime = NumberRange.new(2, 2)
        e2.SpreadAngle = Vector2.new(0.001, 0.001)
        e2.LockedToPart = true
        e2.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) })
        e2.LightEmission = 1
        e2.VelocitySpread = 0.001
        e2.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 2) })
        e2.Speed = NumberRange.new(0.001, 0.001)
        e2.Brightness = 2
        e2.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 2.5),
            NumberSequenceKeypoint.new(0.8, 4), NumberSequenceKeypoint.new(1, 6),
        })
        e2.RotSpeed = NumberRange.new(-30, 30)
        e2.Texture = "rbxassetid://7216849325"
        e2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e2.Rotation = NumberRange.new(0, 360)
        e2.Parent = att

        local e3 = Instance.new("ParticleEmitter")
        e3.Name = "Ambient3"
        e3.Lifetime = NumberRange.new(2, 2)
        e3.SpreadAngle = Vector2.new(0.001, 0.001)
        e3.LockedToPart = true
        e3.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) })
        e3.LightEmission = 1
        e3.VelocitySpread = 0.001
        e3.Squash = NumberSequence.new(0)
        e3.Speed = NumberRange.new(0.001, 0.001)
        e3.Brightness = 2
        e3.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 2), NumberSequenceKeypoint.new(0.6, 5),
            NumberSequenceKeypoint.new(0.8, 8), NumberSequenceKeypoint.new(1, 12),
        })
        e3.RotSpeed = NumberRange.new(-40, 40)
        e3.Texture = "rbxassetid://7216855136"
        e3.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e3.Rotation = NumberRange.new(0, 360)
        e3.Parent = att

        return model
    end

    local function buildNimbAura()
        local model = Instance.new("Model")
        model.Name = "nimb"
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Parent = model
        local att = Instance.new("Attachment")
        att.CFrame = CFrame.new(-0.25, 0.933, 0.259, 0.469, -0.25, -0.847, -0.117, 0.933, -0.34, 0.875, 0.259, 0.408)
        att.Parent = head

        local e1 = Instance.new("ParticleEmitter")
        e1.Name = "Nimb1"
        e1.Lifetime = NumberRange.new(1, 1)
        e1.SpreadAngle = Vector2.new(5, 5)
        e1.LockedToPart = true
        e1.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),
        })
        e1.LightEmission = 1
        e1.VelocitySpread = 5
        e1.Speed = NumberRange.new(0.001, 0.001)
        e1.Brightness = 2
        e1.Size = NumberSequence.new(2.5, 3)
        e1.RotSpeed = NumberRange.new(-400, 400)
        e1.Rate = 7
        e1.Texture = "rbxassetid://8819682608"
        e1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e1.Rotation = NumberRange.new(0, 360)
        e1.Parent = att

        local e2 = Instance.new("ParticleEmitter")
        e2.Name = "Nimb2"
        e2.Lifetime = NumberRange.new(1, 1)
        e2.SpreadAngle = Vector2.new(5, 5)
        e2.LockedToPart = true
        e2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),
        })
        e2.LightEmission = 1
        e2.VelocitySpread = 5
        e2.Speed = NumberRange.new(0.001, 0.001)
        e2.Brightness = 2
        e2.Size = NumberSequence.new(2, 3)
        e2.RotSpeed = NumberRange.new(-400, 400)
        e2.Rate = 7
        e2.Texture = "rbxassetid://8819682608"
        e2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e2.Rotation = NumberRange.new(0, 360)
        e2.Parent = att

        return model
    end

    local function buildTornadoAura()
        local model = Instance.new("Model")
        model.Name = "tornado"
        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Parent = model
        local att = Instance.new("Attachment")
        att.CFrame = CFrame.new(0, -3, 0)
        att.Parent = hrp

        local e = Instance.new("ParticleEmitter")
        e.Name = "Tornado1"
        e.LightInfluence = 1
        e.LockedToPart = true
        e.LightEmission = 1
        e.Speed = NumberRange.new(0.01, 0.01)
        e.Size = NumberSequence.new(6, 10)
        e.RotSpeed = NumberRange.new(360, 360)
        e.Rate = 1
        e.Texture = "http://www.roblox.com/asset/?id=8553497052"
        e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        e.Parent = att

        return model
    end

    -- asset auras (juju L20111-20119): game:GetObjects(rbxassetid://ID)[1] -> Model plantilla
    -- (misma forma que las procedurales: Parts placeholder con Attachment/Beam/PointLight hijos).
    local ASSET_IDS = {
        starlight = "134645216613107",
        lightning = "88833232287502",
        heavenly = "139300897520961",
        ribbon = "132069507632161",
        sakura = "81755778619404",
        angel = "97658130917593",
        wind = "80694081850877",
        flow = "119913533725648",
        star = "73754563740680",
    }
    local PROCEDURAL_BUILDERS = {
        ["angel wing"] = buildAngelWingAura,
        ["blue heat"] = buildBlueHeatAura,
        ["heal aura"] = buildHealAura,
        ["ambient"] = buildAmbientAura,
        ["nimb"] = buildNimbAura,
        ["tornado"] = buildTornadoAura,
    }

    ------------------------------------------------------------------------------------------
    -- instancia del modulo
    ------------------------------------------------------------------------------------------
    function Aura.new(opts)
        opts = opts or {}
        local svc = opts.services or {
            Players = game:GetService("Players"),
            RunService = game:GetService("RunService"),
            Workspace = workspace,
        }
        return setmetatable({
            Flags = opts.flags or {}, Services = svc, _provider = opts.provider,
            Conns = {}, Drawings = {}, _made = {}, _templates = {}, Loaded = false,
            _wasOn = false, _lastChar = nil, _lastSelKey = nil,
        }, Aura)
    end

    function Aura:Set(k, v) self.Flags[k] = v end
    function Aura:Get(k) return self.Flags[k] end
    function Aura:_flag(k, d)
        local v = self.Flags["Aura_" .. k]; if v ~= nil then return v end; return d
    end
    function Aura:UseProfile(p) if p then self._provider = p end end

    function Aura:_draw(class, props)
        if not (Drawing and Drawing.new) then return { Visible = false, Remove = function() end } end
        local o = Drawing.new(class); o.Visible = false
        if props then for k, v in pairs(props) do o[k] = v end end
        table.insert(self.Drawings, o); return o
    end

    -- ver comentario identico en core/combat.lua: onShot/onHit del perfil lifeinprison son
    -- funciones LAZY (getgenv().LIP no existe todavia cuando este modulo se construye).
    local function resolveSignal(v)
        if type(v) == "function" then local ok, r = pcall(v); return ok and r or nil end
        return v
    end

    -- R15 -> R6 fallback (ver comentario de cabecera). Cubre las 15 nombres R15 estandar (mismos
    -- que `body_parts` en jujudotlol.lua L8358-8374) por si algun asset los usa tambien.
    local R15_TO_R6 = {
        UpperTorso = "Torso", LowerTorso = "Torso",
        LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
        RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
        LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
        RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
    }
    -- nombre exacto primero (cubre R15 nativo si algun dia se porta a un juego R15, y cubre
    -- Head/HumanoidRootPart que son iguales en ambos rigs); si no existe, intenta el equivalente R6.
    function Aura:_resolvePart(char, name)
        local part = char:FindFirstChild(name)
        if part then return part end
        local fallback = R15_TO_R6[name]
        return fallback and char:FindFirstChild(fallback) or nil
    end

    -- provider.localCharacter (a diferencia de onShot/onHit) es una funcion DIRECTA (no lazy) —
    -- ver games/lifeinprison.lua. Fallback a Players.LocalPlayer.Character si el perfil no la trae.
    function Aura:_char()
        local prov = self._provider
        if prov and prov.localCharacter then
            local ok, c = pcall(prov.localCharacter)
            if ok and c then return c end
        end
        local plr = self.Services.Players and self.Services.Players.LocalPlayer
        return plr and plr.Character
    end

    -- template cache: procedural = build (pcall) una vez; asset = game:GetObjects (red, pcall) una
    -- vez. `false` cacheado = intento fallido, no se reintenta cada frame. Sobrevive a toggles
    -- on/off (solo se destruye en :Unload) — igual que la tabla particle_auras de juju.
    function Aura:_template(name)
        local cached = self._templates[name]
        if cached ~= nil then return cached or nil end
        local model
        local builder = PROCEDURAL_BUILDERS[name]
        if builder then
            local ok, m = pcall(builder)
            if ok then model = m end
        else
            local id = ASSET_IDS[name]
            if id then
                local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
                if ok and objs and objs[1] then model = objs[1] end
            end
        end
        self._templates[name] = model or false
        return model
    end

    local function applyColorToInstance(inst, color, seq)
        if inst:IsA("PointLight") then
            inst.Color = color
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
            inst.Color = seq
        end
    end

    -- juju L20287-20330: recolorea (a) las plantillas cacheadas (para que clones futuros ya
    -- salgan con el color actual) y (b) las instancias YA reparentadas sobre el char + sus
    -- descendientes (cubre los emitters anidados dentro de un Attachment "\0\0att").
    function Aura:_recolor(color)
        local seq = ColorSequence.new(color)
        for _, model in pairs(self._templates) do
            if model then
                for _, d in ipairs(model:GetDescendants()) do applyColorToInstance(d, color, seq) end
            end
        end
        for _, inst in ipairs(self._made) do
            if inst and inst.Parent then
                applyColorToInstance(inst, color, seq)
                for _, d in ipairs(inst:GetDescendants()) do applyColorToInstance(d, color, seq) end
            end
        end
    end

    function Aura:_clearParticles()
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        table.clear(self._made)
    end

    -- juju L20140-20193 (do_particle_aura), branches Beam/PointLight/else colapsados (misma
    -- accion en los 3: renombrar "\0\0" + reparentar sobre local_part) — solo Attachment difiere
    -- (renombra "\0\0att" y ademas renombra -sin reparentar- sus propios hijos a "\0\0").
    function Aura:_applyAuras(char, selected)
        self:_clearParticles()
        if not char then return end
        for _, name in ipairs(selected) do
            local template = self:_template(name)
            if template then
                local cloned = template:Clone()
                for _, part in ipairs(cloned:GetChildren()) do
                    local localPart = self:_resolvePart(char, part.Name)
                    if localPart then
                        for _, child in ipairs(part:GetChildren()) do
                            if child:IsA("Attachment") then
                                child.Name = "\0\0att"
                                child.Parent = localPart
                                table.insert(self._made, child)
                                for _, attChild in ipairs(child:GetChildren()) do attChild.Name = "\0\0" end
                            else -- Beam / PointLight / ParticleEmitter suelto
                                child.Name = "\0\0"
                                child.Parent = localPart
                                table.insert(self._made, child)
                            end
                        end
                    else
                        part:Destroy() -- sin match ni fallback R15->R6 (nombre no reconocido)
                    end
                end
                cloned:Destroy()
            end
        end
    end

    function Aura:_update(now, dt)
        GV.tweenStep(now, dt)
        local enabled = self:_flag("Enabled", false)
        if not enabled then
            if self._wasOn then
                self:_clearParticles()
                self._wasOn = false
                self._lastChar, self._lastSelKey = nil, nil
            end
            return
        end
        self._wasOn = true

        local char = self:_char()
        local selectedRaw = self:_flag("Particles", { "angel" })
        local selected = (type(selectedRaw) == "table") and selectedRaw or { selectedRaw }
        local selKey = table.concat(selected, "\1")
        -- (re)aplica cuando cambia el char (spawn/respawn, deteccion por identidad de instancia)
        -- o cuando cambia la seleccion de auras.
        if char ~= self._lastChar or selKey ~= self._lastSelKey then
            self._lastChar, self._lastSelKey = char, selKey
            self:_applyAuras(char, selected)
        end
        -- Aura_Color via CF (base + base_2 + fade) -> GV.Color.fade (igual que ESP/SelfFX).
        self:_recolor(GV.Color.fade(self.Flags, "Aura_Color", now))
    end

    function Aura:Init()
        if self.Loaded then return self end
        self.Loaded = true
        local lastT = os.clock()
        self.Conns[#self.Conns + 1] = self.Services.RunService.RenderStepped:Connect(function()
            local now = os.clock(); local dt = now - lastT; lastT = now
            local ok, err = pcall(function() self:_update(now, dt) end)
            if not ok then warn("[Aura] " .. tostring(err)) end
        end)
        if self._provider then
            local shot = resolveSignal(self._provider.onShot)
            if shot and shot.Connect then
                local ok, conn = pcall(function()
                    return shot:Connect(function(origin, hitPos, isLocal) self:_onShot(origin, hitPos, isLocal) end)
                end)
                if ok and conn then self.Conns[#self.Conns + 1] = conn end
            end
            local hit = resolveSignal(self._provider.onHit)
            if hit and hit.Connect then
                local ok, conn = pcall(function()
                    return hit:Connect(function(plr, part, dmg, lethal) self:_onHit(plr, part, dmg, lethal) end)
                end)
                if ok and conn then self.Conns[#self.Conns + 1] = conn end
            end
        end
        return self
    end

    -- stubs del provider (aura no los consume; se mantienen por paridad de interfaz con combat)
    function Aura:_onShot(origin, hitPos, isLocal) end
    function Aura:_onHit(plr, part, dmg, lethal) end

    function Aura:Unload()
        self.Loaded = false
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        for _, o in ipairs(self.Drawings) do pcall(function() o.Visible = false; o:Remove() end) end
        for _, inst in ipairs(self._made) do pcall(function() inst:Destroy() end) end
        for _, model in pairs(self._templates) do
            if model then pcall(function() model:Destroy() end) end
        end
        table.clear(self.Conns); table.clear(self.Drawings); table.clear(self._made); table.clear(self._templates)
    end

    GV.Aura = Aura
    GV.Modules = GV.Modules or {}
    GV.Modules.aura = GV.Modules.aura or {}
    GV.Modules.aura.new = function(o) return Aura.new(o) end
end
