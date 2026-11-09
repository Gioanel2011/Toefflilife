--!strict
-- GarageFactory: einzige, strikt identische Garagenvorlage fuer alle 15 Garagen.
-- Keine Besitzerfarbe, keine Tuninglogik, keine individuellen Groessen.
-- Nur Name und Anker-Attribut variieren; alle Abmessungen, Materialien, Farben
-- und die Teilezahl sind deterministisch identisch.

local GarageFactory = {}

local FLOOR_COLOR = Color3.fromRGB(145, 145, 150)
local WALL_COLOR = Color3.fromRGB(205, 205, 212)
local ROOF_COLOR = Color3.fromRGB(72, 74, 82)
local TRIM_COLOR = Color3.fromRGB(55, 57, 64)
local DOOR_COLOR = Color3.fromRGB(58, 60, 68)
local WINDOW_COLOR = Color3.fromRGB(175, 215, 235)
local FRAME_COLOR = Color3.fromRGB(120, 122, 130)
local LIFT_COLOR = Color3.fromRGB(210, 165, 55)
local LIFT_DARK = Color3.fromRGB(95, 95, 100)
local WORKSHOP_COLOR = Color3.fromRGB(60, 190, 110)
local LIGHT_COLOR = Color3.fromRGB(255, 245, 210)
local SIGN_COLOR = Color3.fromRGB(240, 240, 245)

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	if transparency ~= nil then
		part.Transparency = transparency :: number
	end
	return part
end

local function makeSurfaceText(parent: Part, text: string, color: Color3): ()
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 120)
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

function GarageFactory.create(anchorName: string): Model
	local name = if type(anchorName) == "string" and anchorName ~= "" then anchorName else "Garage"

	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("AnchorName", name)
	model:SetAttribute("GarageAnchor", name)
	model:SetAttribute("IsGarage", true)

	local halfW = 12
	local halfD = 10
	local wallH = 10
	local floorT = 1

	-- Bodenplatte.
	local floor = makePart("Floor", Vector3.new(halfW * 2, floorT, halfD * 2), CFrame.new(0, floorT / 2, 0), FLOOR_COLOR, Enum.Material.Concrete, true, nil)
	floor.Parent = model

	-- Seitenwaende (links/rechts).
	local leftWall = makePart("WallLeft", Vector3.new(1, wallH, halfD * 2), CFrame.new(-halfW + 0.5, floorT + wallH / 2, 0), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	leftWall.Parent = model
	local rightWall = makePart("WallRight", Vector3.new(1, wallH, halfD * 2), CFrame.new(halfW - 0.5, floorT + wallH / 2, 0), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	rightWall.Parent = model

	-- Rueckwand (mit Personeneingang).
	local backDoorW = 3
	local backSegW = (halfW * 2 - backDoorW) / 2
	local backLeft = makePart("WallBackLeft", Vector3.new(backSegW, wallH, 1), CFrame.new(-halfW + backSegW / 2 + 0.5, floorT + wallH / 2, -halfD + 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	backLeft.Parent = model
	local backRight = makePart("WallBackRight", Vector3.new(backSegW, wallH, 1), CFrame.new(halfW - backSegW / 2 - 0.5, floorT + wallH / 2, -halfD + 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	backRight.Parent = model
	local backLintel = makePart("WallBackLintel", Vector3.new(backDoorW, wallH - 7, 1), CFrame.new(0, floorT + 7 + (wallH - 7) / 2, -halfD + 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	backLintel.Parent = model

	-- Vorderwand (mit grossem Fahrzeugtor).
	local doorW = 10
	local frontSegW = (halfW * 2 - doorW) / 2
	local frontLeft = makePart("WallFrontLeft", Vector3.new(frontSegW, wallH, 1), CFrame.new(-halfW + frontSegW / 2 + 0.5, floorT + wallH / 2, halfD - 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	frontLeft.Parent = model
	local frontRight = makePart("WallFrontRight", Vector3.new(frontSegW, wallH, 1), CFrame.new(halfW - frontSegW / 2 - 0.5, floorT + wallH / 2, halfD - 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	frontRight.Parent = model
	local frontLintel = makePart("WallFrontLintel", Vector3.new(doorW, wallH - 8, 1), CFrame.new(0, floorT + 8 + (wallH - 8) / 2, halfD - 0.5), WALL_COLOR, Enum.Material.SmoothPlastic, true, nil)
	frontLintel.Parent = model

	-- Dachplatte mit Ueberstand.
	local roof = makePart("Roof", Vector3.new(halfW * 2 + 2, 1, halfD * 2 + 2), CFrame.new(0, floorT + wallH + 0.5, 0), ROOF_COLOR, Enum.Material.SmoothPlastic, true, nil)
	roof.Parent = model

	-- Dachkante.
	local trimFront = makePart("RoofTrimFront", Vector3.new(halfW * 2 + 2, 0.6, 0.6), CFrame.new(0, floorT + wallH + 1.0, halfD + 1.0), TRIM_COLOR, Enum.Material.SmoothPlastic, true, nil)
	trimFront.Parent = model
	local trimBack = makePart("RoofTrimBack", Vector3.new(halfW * 2 + 2, 0.6, 0.6), CFrame.new(0, floorT + wallH + 1.0, -halfD - 1.0), TRIM_COLOR, Enum.Material.SmoothPlastic, true, nil)
	trimBack.Parent = model
	local trimLeft = makePart("RoofTrimLeft", Vector3.new(0.6, 0.6, halfD * 2 + 2), CFrame.new(-halfW - 1.0, floorT + wallH + 1.0, 0), TRIM_COLOR, Enum.Material.SmoothPlastic, true, nil)
	trimLeft.Parent = model
	local trimRight = makePart("RoofTrimRight", Vector3.new(0.6, 0.6, halfD * 2 + 2), CFrame.new(halfW + 1.0, floorT + wallH + 1.0, 0), TRIM_COLOR, Enum.Material.SmoothPlastic, true, nil)
	trimRight.Parent = model

	-- Grosses Fahrzeugtor (Panel + Rahmen).
	local doorFrameLeft = makePart("VehicleDoorFrameLeft", Vector3.new(0.3, 8, 0.6), CFrame.new(-doorW / 2 - 0.15, floorT + 4, halfD - 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	doorFrameLeft.Parent = model
	local doorFrameRight = makePart("VehicleDoorFrameRight", Vector3.new(0.3, 8, 0.6), CFrame.new(doorW / 2 + 0.15, floorT + 4, halfD - 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	doorFrameRight.Parent = model
	local doorFrameTop = makePart("VehicleDoorFrameTop", Vector3.new(doorW + 0.6, 0.3, 0.6), CFrame.new(0, floorT + 8.15, halfD - 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	doorFrameTop.Parent = model
	local vehicleDoor = makePart("VehicleDoor", Vector3.new(doorW, 8, 0.4), CFrame.new(0, floorT + 4, halfD - 0.05), DOOR_COLOR, Enum.Material.Metal, true, nil)
	vehicleDoor.Parent = model

	-- Separater Personeneingang (Panel + Rahmen).
	local personDoorW = backDoorW
	local personDoorH = 7
	local personFrameLeft = makePart("PersonDoorFrameLeft", Vector3.new(0.25, personDoorH, 0.6), CFrame.new(-personDoorW / 2 - 0.125, floorT + personDoorH / 2, -halfD + 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	personFrameLeft.Parent = model
	local personFrameRight = makePart("PersonDoorFrameRight", Vector3.new(0.25, personDoorH, 0.6), CFrame.new(personDoorW / 2 + 0.125, floorT + personDoorH / 2, -halfD + 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	personFrameRight.Parent = model
	local personFrameTop = makePart("PersonDoorFrameTop", Vector3.new(personDoorW + 0.5, 0.25, 0.6), CFrame.new(0, floorT + personDoorH + 0.125, -halfD + 0.2), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
	personFrameTop.Parent = model
	local personDoor = makePart("PersonDoor", Vector3.new(personDoorW, personDoorH, 0.35), CFrame.new(0, floorT + personDoorH / 2, -halfD + 0.05), DOOR_COLOR, Enum.Material.Metal, true, nil)
	personDoor.Parent = model
	local doorHandle = makePart("PersonDoorHandle", Vector3.new(0.15, 0.6, 0.15), CFrame.new(personDoorW / 2 - 0.35, floorT + personDoorH / 2, -halfD + 0.3), Color3.fromRGB(200, 180, 90), Enum.Material.Metal, true, nil)
	doorHandle.Parent = model

	-- Fenster (links und rechts), je Glas + Rahmen.
	local function addWindow(sideSign: number, namePrefix: string)
		local x = sideSign * (halfW - 0.6)
		local w = 4
		local h = 3
		local cy = floorT + 6
		local cz = 0
		local glass = makePart(namePrefix .. "Glass", Vector3.new(0.25, h, w), CFrame.new(x, cy, cz), WINDOW_COLOR, Enum.Material.Glass, false, 0.35)
		glass.Parent = model
		local ft = makePart(namePrefix .. "FrameTop", Vector3.new(0.3, 0.25, w + 0.5), CFrame.new(x, cy + h / 2 + 0.125, cz), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
		ft.Parent = model
		local fb = makePart(namePrefix .. "FrameBottom", Vector3.new(0.3, 0.25, w + 0.5), CFrame.new(x, cy - h / 2 - 0.125, cz), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
		fb.Parent = model
		local fl = makePart(namePrefix .. "FrameLeft", Vector3.new(0.3, h + 0.5, 0.25), CFrame.new(x, cy, cz - w / 2 - 0.125), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
		fl.Parent = model
		local fr = makePart(namePrefix .. "FrameRight", Vector3.new(0.3, h + 0.5, 0.25), CFrame.new(x, cy, cz + w / 2 + 0.125), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
		fr.Parent = model
	end
	addWindow(-1, "WindowLeft")
	addWindow(1, "WindowRight")

	-- Beleuchtung (2 Deckenleuchten).
	for i = 0, 1 do
		local z = if i == 0 then -4 else 4
		local housing = makePart("CeilingLight" .. tostring(i + 1) .. "Housing", Vector3.new(1.6, 0.25, 1.0), CFrame.new(0, floorT + wallH - 0.4, z), FRAME_COLOR, Enum.Material.SmoothPlastic, true, nil)
		housing.Parent = model
		local bulb = makePart("CeilingLight" .. tostring(i + 1) .. "Bulb", Vector3.new(1.2, 0.15, 0.7), CFrame.new(0, floorT + wallH - 0.7, z), LIGHT_COLOR, Enum.Material.Neon, false, 0.05)
		bulb.Parent = model
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = LIGHT_COLOR
		light.Brightness = 2
		light.Range = 24
		light.Parent = bulb
	end

	-- Dekoration: Werkbank.
	local benchTop = makePart("WorkbenchTop", Vector3.new(6, 0.4, 2), CFrame.new(-7, floorT + 3.4, -7), Color3.fromRGB(170, 130, 85), Enum.Material.Wood, true, nil)
	benchTop.Parent = model
	local benchLegL = makePart("WorkbenchLegLeft", Vector3.new(0.3, 3.0, 0.3), CFrame.new(-9.7, floorT + 1.5, -7), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, true, nil)
	benchLegL.Parent = model
	local benchLegR = makePart("WorkbenchLegRight", Vector3.new(0.3, 3.0, 0.3), CFrame.new(-4.3, floorT + 1.5, -7), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, true, nil)
	benchLegR.Parent = model

	-- Dekoration: Werkzeugschrank.
	local cabinet = makePart("ToolCabinet", Vector3.new(2.2, 4.0, 1.6), CFrame.new(7, floorT + 2.0, -7), Color3.fromRGB(70, 95, 130), Enum.Material.Metal, true, nil)
	cabinet.Parent = model

	-- Dekoration: Feuerloescher.
	local extinguisher = makePart("FireExtinguisher", Vector3.new(0.5, 1.6, 0.5), CFrame.new(halfW - 1.0, floorT + 0.8, -2), Color3.fromRGB(210, 50, 45), Enum.Material.SmoothPlastic, true, nil)
	extinguisher.Parent = model

	-- Schild ueber dem Fahrzeugtor.
	local sign = makePart("GarageSign", Vector3.new(doorW, 2, 0.3), CFrame.new(0, floorT + wallH + 1.6, halfD - 0.2), SIGN_COLOR, Enum.Material.SmoothPlastic, true, nil)
	sign.Parent = model
	makeSurfaceText(sign, "GARAGE", Color3.fromRGB(40, 40, 45))

	-- Hebebuehne (Lift).
	local liftBase = makePart("LiftBase", Vector3.new(8, 0.3, 4), CFrame.new(0, 0.15, 2), LIFT_DARK, Enum.Material.Metal, true, nil)
	liftBase.Parent = model
	local pillarOffsets = { Vector3.new(-3.5, 0, -1.5), Vector3.new(3.5, 0, -1.5), Vector3.new(-3.5, 0, 1.5), Vector3.new(3.5, 0, 1.5) }
	for i, off in pillarOffsets do
		local pillar = makePart("LiftPillar" .. tostring(i), Vector3.new(0.4, 1.2, 0.4), CFrame.new(off.X, 0.15 + 0.3 + 0.6, off.Z + 2), LIFT_COLOR, Enum.Material.Metal, true, nil)
		pillar.Parent = model
	end
	local platform = makePart("LiftPlatform", Vector3.new(8, 0.5, 4), CFrame.new(0, 0.15 + 0.3 + 1.2 + 0.25, 2), LIFT_COLOR, Enum.Material.DiamondPlate, true, nil)
	platform.Parent = model
	local railLeft = makePart("LiftRailLeft", Vector3.new(0.2, 1.0, 4), CFrame.new(-4.1, 0.15 + 0.3 + 1.2 + 0.75, 2), LIFT_COLOR, Enum.Material.Metal, true, nil)
	railLeft.Parent = model
	local railRight = makePart("LiftRailRight", Vector3.new(0.2, 1.0, 4), CFrame.new(4.1, 0.15 + 0.3 + 1.2 + 0.75, 2), LIFT_COLOR, Enum.Material.Metal, true, nil)
	railRight.Parent = model
	local rampFront = makePart("LiftRampFront", Vector3.new(3, 0.25, 1.5), CFrame.new(0, 0.15 + 0.125, 2 + 2.75), LIFT_DARK, Enum.Material.Metal, true, nil)
	rampFront.Parent = model
	local rampBack = makePart("LiftRampBack", Vector3.new(3, 0.25, 1.5), CFrame.new(0, 0.15 + 0.125, 2 - 2.75), LIFT_DARK, Enum.Material.Metal, true, nil)
	rampBack.Parent = model

	-- Markierter Werkstattanker.
	local workshopAnchor = makePart("WorkshopAnchor", Vector3.new(2, 0.3, 2), CFrame.new(0, 0.15, 2), WORKSHOP_COLOR, Enum.Material.Neon, false, 0)
	workshopAnchor.Parent = model
	workshopAnchor:SetAttribute("IsWorkshopAnchor", true)
	workshopAnchor:SetAttribute("WorkshopAnchor", true)

	model.PrimaryPart = floor

	return model
end

return GarageFactory