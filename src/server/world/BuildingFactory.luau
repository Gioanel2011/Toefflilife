--!strict
-- BuildingFactory: erzeugt ein einzelnes Low-Poly-Haus aus einer Katalogdefinition.
-- Reine Fabrik ohne globale Variablen. Das Model steht lokal am Ursprung mit
-- Bodenbasis Y=0 (Front = -Z); die Positionierung uebernimmt VillageBuilder.
-- Jedes Haus besitzt sichtbare Eingangstuer, Fenster und eindeutige Dekoration.

local BuildingFactory = {}

local function pickString(definition: { [string]: any }, keys: { string }, fallback: string): string
	local value: any = nil
	for _, key in keys do
		if definition[key] ~= nil then
			value = definition[key]
			break
		end
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return fallback
end

local function pickNumber(definition: { [string]: any }, keys: { string }, fallback: number): number
	for _, key in keys do
		local value = definition[key]
		if type(value) == "number" then
			return value
		end
	end
	return fallback
end

local function footprintOf(definition: { [string]: any }): { x: number, z: number }
	local candidates = {
		definition.FootprintSize,
		definition.footprintSize,
		definition.Size,
		definition.size,
	}
	for _, candidate in candidates do
		if type(candidate) == "table" then
			local x = candidate.x or candidate.X
			local z = candidate.z or candidate.Z
			if type(x) == "number" and type(z) == "number" and x > 0 and z > 0 then
				return { x = x, z = z }
			end
		end
	end
	return { x = 20, z = 16 }
end

local function colorsOf(definition: { [string]: any }): { string }
	local candidates = {
		definition.FacadeColors,
		definition.facadeColors,
		definition.Colors,
		definition.colors,
		definition.Fassadenfarben,
		definition.fassadenfarben,
	}
	for _, candidate in candidates do
		if type(candidate) == "table" and type(candidate[1]) == "string" then
			return candidate
		end
	end
	local single = pickString(definition, { "FacadeColor", "facadeColor" }, "white")
	return { single }
end

local FACADE_COLORS: { [string]: Color3 } = {
	white = Color3.fromRGB(245, 245, 240),
	cream = Color3.fromRGB(245, 235, 200),
	yellow = Color3.fromRGB(240, 210, 120),
	gray = Color3.fromRGB(170, 170, 170),
	brown = Color3.fromRGB(150, 110, 70),
}

local ROOF_COLORS: { [string]: Color3 } = {
	gable = Color3.fromRGB(150, 60, 50),
	hip = Color3.fromRGB(90, 90, 95),
	flat = Color3.fromRGB(180, 180, 180),
	mansard = Color3.fromRGB(120, 80, 50),
}

local function facadeColor(name: string): Color3
	local found = FACADE_COLORS[string.lower(name)]
	if found ~= nil then
		return found
	end
	return Color3.fromRGB(235, 235, 230)
end

local function roofColor(roof: string): Color3
	local found = ROOF_COLORS[string.lower(roof)]
	if found ~= nil then
		return found
	end
	return Color3.fromRGB(130, 70, 60)
end

local function trimColor(colors: { string }): Color3
	if #colors >= 2 and type(colors[2]) == "string" then
		return facadeColor(colors[2])
	end
	return Color3.fromRGB(80, 80, 85)
end

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean
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
	part.Parent = model
	return part
end

local function doorXFor(doorSide: string, sizeX: number): number
	local side = string.lower(doorSide)
	if side == "left" then
		return -sizeX / 4
	elseif side == "right" then
		return sizeX / 4
	else
		return 0
	end
end

function BuildingFactory.create(definition: { [string]: any }): Model
	local id = pickString(definition, { "Id", "id" }, "House_Unknown")
	local villageId = pickString(definition, { "VillageId", "villageId" }, "")
	local footprint = footprintOf(definition)
	local sizeX: number = footprint.x
	local sizeZ: number = footprint.z
	local height: number = pickNumber(definition, { "Height", "height", "Hoehe", "hoehe" }, 7)
	if height < 5 then
		height = 5
	end
	local roof = pickString(definition, { "RoofShape", "roofShape", "RoofType", "roofType", "Roof", "roof", "Dachform", "dachform" }, "gable")
	local colorNames = colorsOf(definition)
	local baseColor = facadeColor(colorNames[1])
	local trim = trimColor(colorNames)
	local windowStyle = pickString(definition, { "WindowStyle", "windowStyle", "Windows", "windows", "Fensterstil", "fensterstil" }, "plain")
	local doorSide = pickString(definition, { "DoorSide", "doorSide", "DoorDirection", "doorDirection", "Door", "door", "Tuerseite", "tuerseite" }, "front")
	local decoration = pickString(definition, { "Decoration", "decoration", "DecorationSignature", "decorationSignature", "Dekorationssignatur", "dekorationssignatur" }, "none")
	local signature = pickString(definition, { "Signature", "signature", "DesignSignature", "designSignature", "Gestaltungssignatur", "gestaltungssignatur", "Signatur", "signatur" }, "")

	local model = Instance.new("Model")
	model.Name = id

	-- Hauptkörper, Basis bei Y=0.
	local body = makePart(
		model,
		"Body",
		Vector3.new(sizeX, height, sizeZ),
		CFrame.new(0, height / 2, 0),
		baseColor,
		Enum.Material.SmoothPlastic,
		true
	)
	model.PrimaryPart = body

	-- Dach je Dachform.
	local roofMat = roofColor(roof)
	local roofKey = string.lower(roof)
	if roofKey == "flat" then
		makePart(model, "Roof", Vector3.new(sizeX + 1, 0.8, sizeZ + 1), CFrame.new(0, height + 0.4, 0), roofMat, Enum.Material.SmoothPlastic, true)
	elseif roofKey == "hip" then
		makePart(model, "RoofBase", Vector3.new(sizeX + 1, 0.6, sizeZ + 1), CFrame.new(0, height + 0.3, 0), roofMat, Enum.Material.SmoothPlastic, true)
		makePart(model, "RoofTop", Vector3.new(sizeX * 0.5, 1.6, sizeZ * 0.5), CFrame.new(0, height + 1.4, 0), roofMat, Enum.Material.SmoothPlastic, true)
	elseif roofKey == "mansard" then
		makePart(model, "RoofBase", Vector3.new(sizeX + 1.4, 2.0, sizeZ + 1.4), CFrame.new(0, height + 1.0, 0), roofMat, Enum.Material.SmoothPlastic, true)
		makePart(model, "RoofTop", Vector3.new(sizeX * 0.7, 0.6, sizeZ * 0.7), CFrame.new(0, height + 2.3, 0), trim, Enum.Material.SmoothPlastic, true)
	else
		-- Giebeldach: zwei geneigte Platten plus Firstbalken.
		local slope = math.rad(30)
		makePart(model, "RoofFront", Vector3.new(sizeX + 1.2, 0.6, sizeZ / 2 + 1.2), CFrame.new(0, height + 1.5, -sizeZ / 4) * CFrame.Angles(-slope, 0, 0), roofMat, Enum.Material.SmoothPlastic, true)
		makePart(model, "RoofBack", Vector3.new(sizeX + 1.2, 0.6, sizeZ / 2 + 1.2), CFrame.new(0, height + 1.5, sizeZ / 4) * CFrame.Angles(slope, 0, 0), roofMat, Enum.Material.SmoothPlastic, true)
		makePart(model, "RoofRidge", Vector3.new(sizeX + 1.2, 0.6, 0.8), CFrame.new(0, height + 3.0, 0), trim, Enum.Material.SmoothPlastic, true)
	end

	-- Eingangstür auf der Frontseite (-Z), Boden bündig bei Y=0, leicht vor der Wand.
	local frontZ = -sizeZ / 2
	local dx = doorXFor(doorSide, sizeX)
	local door = makePart(model, "Entrance", Vector3.new(3, 5, 0.6), CFrame.new(dx, 2.5, frontZ - 0.35), Color3.fromRGB(90, 60, 40), Enum.Material.WoodPlanks, false)
	door:SetAttribute("IsEntrance", true)
	makePart(model, "Doorstep", Vector3.new(4, 0.4, 2), CFrame.new(dx, 0.2, frontZ - 1.5), Color3.fromRGB(160, 160, 155), Enum.Material.Concrete, false)

	-- Fenster: zwei auf der Front plus je eines an den Seiten.
	local windowY = math.min(4.4, height * 0.55)
	if windowY < 3.2 then
		windowY = 3.2
	end
	local styleKey = string.lower(windowStyle)
	local glass = Color3.fromRGB(180, 220, 240)
	local frontOffsets = { -sizeX / 2 + 3, sizeX / 2 - 3 }
	local windowIndex = 0
	for _, xOffset in frontOffsets do
		if math.abs(xOffset - dx) < 3.2 then
			continue
		end
		windowIndex += 1
		if styleKey == "bay" then
			makePart(model, "Window_Front_" .. tostring(windowIndex), Vector3.new(3.0, 2.4, 1.4), CFrame.new(xOffset, windowY, frontZ - 0.7), glass, Enum.Material.Glass, false)
		else
			makePart(model, "Window_Front_" .. tostring(windowIndex), Vector3.new(2.6, 2.2, 0.4), CFrame.new(xOffset, windowY, frontZ - 0.2), glass, Enum.Material.Glass, false)
			if styleKey == "shuttered" then
				makePart(model, "Shutter_Front_" .. tostring(windowIndex) .. "_L", Vector3.new(0.8, 2.2, 0.3), CFrame.new(xOffset - 1.8, windowY, frontZ - 0.2), trim, Enum.Material.Wood, false)
				makePart(model, "Shutter_Front_" .. tostring(windowIndex) .. "_R", Vector3.new(0.8, 2.2, 0.3), CFrame.new(xOffset + 1.8, windowY, frontZ - 0.2), trim, Enum.Material.Wood, false)
			elseif styleKey == "arched" then
				makePart(model, "WindowArch_Front_" .. tostring(windowIndex), Vector3.new(3.4, 0.6, 0.5), CFrame.new(xOffset, windowY + 1.4, frontZ - 0.2), trim, Enum.Material.SmoothPlastic, false)
			end
		end
	end
	if windowIndex == 0 then
		-- Fallback: mindestens ein Frontfenster oberhalb der Tür, damit jedes Haus Fenster zeigt.
		makePart(model, "Window_Front_Top", Vector3.new(2.6, 1.6, 0.4), CFrame.new(dx, height - 1.2, frontZ - 0.2), glass, Enum.Material.Glass, false)
	end
	makePart(model, "Window_Side_L", Vector3.new(0.4, 2.2, 2.6), CFrame.new(-sizeX / 2 - 0.2, windowY, 0), glass, Enum.Material.Glass, false)
	makePart(model, "Window_Side_R", Vector3.new(0.4, 2.2, 2.6), CFrame.new(sizeX / 2 + 0.2, windowY, 0), glass, Enum.Material.Glass, false)

	-- Eindeutige Dekoration, Türkorridor (|x - dx| < 2.2, vor der Front) bleibt frei.
	local decorKey = string.lower(decoration)
	if decorKey == "flowers" then
		for _, side in { -1, 1 } do
			local px = dx + side * 4.2
			makePart(model, "Decor_FlowerPot_" .. tostring(side), Vector3.new(1, 1, 1), CFrame.new(px, 0.5, frontZ - 1.5), Color3.fromRGB(120, 70, 40), Enum.Material.Concrete, false)
			makePart(model, "Decor_Flower_" .. tostring(side), Vector3.new(0.8, 0.8, 0.8), CFrame.new(px, 1.3, frontZ - 1.5), Color3.fromRGB(220, 80, 90), Enum.Material.SmoothPlastic, false)
		end
	elseif decorKey == "balcony" then
		local balconyY = math.min(5.8, height - 0.6)
		makePart(model, "Decor_Balcony", Vector3.new(5, 0.5, 2), CFrame.new(dx, balconyY, frontZ - 1.0), trim, Enum.Material.WoodPlanks, true)
		for _, offset in { -2.2, 0, 2.2 } do
			makePart(model, "Decor_BalconyPost_" .. tostring(offset), Vector3.new(0.3, 1.2, 0.3), CFrame.new(dx + offset, balconyY + 0.8, frontZ - 1.9), trim, Enum.Material.Wood, false)
		end
	elseif decorKey == "shutters" then
		makePart(model, "Decor_Shutter_L", Vector3.new(0.3, 2.2, 0.9), CFrame.new(-sizeX / 2 - 0.35, windowY, -1.8), trim, Enum.Material.Wood, false)
		makePart(model, "Decor_Shutter_R", Vector3.new(0.3, 2.2, 0.9), CFrame.new(sizeX / 2 + 0.35, windowY, -1.8), trim, Enum.Material.Wood, false)
		makePart(model, "Decor_Shutter_L2", Vector3.new(0.3, 2.2, 0.9), CFrame.new(-sizeX / 2 - 0.35, windowY, 1.8), trim, Enum.Material.Wood, false)
		makePart(model, "Decor_Shutter_R2", Vector3.new(0.3, 2.2, 0.9), CFrame.new(sizeX / 2 + 0.35, windowY, 1.8), trim, Enum.Material.Wood, false)
	elseif decorKey == "garden" then
		local gx = sizeX / 2 + 4.5
		makePart(model, "Decor_GardenBed", Vector3.new(6, 0.3, 5), CFrame.new(gx, 0.15, 2), Color3.fromRGB(90, 160, 80), Enum.Material.Grass, false)
		for _, offset in { -2.5, 2.5 } do
			makePart(model, "Decor_GardenPost_" .. tostring(offset), Vector3.new(0.4, 1.4, 0.4), CFrame.new(gx + offset, 0.7, -0.5), Color3.fromRGB(110, 75, 45), Enum.Material.Wood, false)
		end
	else
		makePart(model, "Decor_Trim", Vector3.new(sizeX + 0.2, 0.5, sizeZ + 0.2), CFrame.new(0, height - 0.3, 0), trim, Enum.Material.SmoothPlastic, false)
	end

	model:SetAttribute("HouseId", id)
	model:SetAttribute("VillageId", villageId)
	if signature ~= "" then
		model:SetAttribute("DesignSignature", signature)
	end

	return model
end

return BuildingFactory
