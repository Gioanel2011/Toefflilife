--!strict
-- DonerShopBuilder: zentraler Doener Laden am Doenerplatz.
-- Reine Bau-Funktion ohne Preise, Belohen oder Gameplaylogik.
-- Position und Abholpunkt stammen aus WorldLayout, Hoehen aus TerrainHeight.
-- Keine globalen Variablen, keine externen Assets.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local TerrainHeight = requireSibling("TerrainHeight")

local DonerShopBuilder = {}

local SHOP_NAME = "DonerShop"
local SIGN_TEXT = "Döner Laden"
local PICKUP_NAME = "Delivery_Doner_Pickup"

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	canCollide: boolean,
	transparency: number?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	if material ~= nil then
		part.Material = material
	else
		part.Material = Enum.Material.SmoothPlastic
	end
	if transparency ~= nil then
		part.Transparency = transparency
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	part.Parent = parent
	return part
end

local function makeSignGui(face: Enum.NormalId, adornee: Part): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DonerSignGui"
	gui.Face = face
	gui.CanvasSize = Vector2.new(800, 150)
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Name = "DonerSignLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = SIGN_TEXT
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 0, 0)
	stroke.Parent = label
	gui.Parent = adornee
	return gui
end

-- Erzeugt den Doener Laden am zentralen Doenerplatz und gibt das Model zurueck.
-- Enthaelt Eingangstuer, Schaufenster, Beleuchtung, lesbares Schild und einen
-- kompatiblen Abholpunkt fuer Lieferungen (IsDeliveryPoint-Attribut).
function DonerShopBuilder.build(parent: Instance): Model
	local donerCenter: any = WorldLayout.DONER.position
	local pickup: any = WorldLayout.DONER.pickupPosition
	local centerX: number = donerCenter.x
	local centerZ: number = donerCenter.z
	local pickupX: number = pickup.x
	local pickupZ: number = pickup.z

	local groundY = TerrainHeight.heightAt(centerX, centerZ)
	local pickupGroundY = TerrainHeight.heightAt(pickupX, pickupZ)

	local model = Instance.new("Model")
	model.Name = SHOP_NAME
	model:SetAttribute("PoiKind", "Doner")
	model:SetAttribute("IsDonerShop", true)

	local wallColor = Color3.fromRGB(235, 220, 190)
	local trimColor = Color3.fromRGB(150, 30, 30)
	local roofColor = Color3.fromRGB(120, 25, 25)
	local floorColor = Color3.fromRGB(170, 165, 155)
	local doorColor = Color3.fromRGB(110, 70, 40)
	local glassColor = Color3.fromRGB(170, 220, 240)
	local lightFixtureColor = Color3.fromRGB(255, 250, 220)

	local wallHeight = 7
	local halfWidth = 10
	local halfDepth = 7
	local wallThickness = 1

	-- Fundamentplatte, Oberkante ist der Ladenboden.
	local floorPart = makePart(
		model,
		"Floor",
		Vector3.new(22, 1, 16),
		Vector3.new(centerX, groundY + 0.5, centerZ),
		floorColor,
		true
	)
	local floorTop = groundY + 1
	local wallCenterY = floorTop + wallHeight / 2
	local frontZ = centerZ + halfDepth - wallThickness / 2
	local backZ = centerZ - halfDepth + wallThickness / 2

	-- Rueckwand und Seitenwaende (geschlossen).
	makePart(
		model,
		"Wall_Back",
		Vector3.new(halfWidth * 2, wallHeight, wallThickness),
		Vector3.new(centerX, wallCenterY, backZ),
		wallColor,
		true
	)
	makePart(
		model,
		"Wall_Left",
		Vector3.new(wallThickness, wallHeight, halfDepth * 2),
		Vector3.new(centerX - halfWidth + wallThickness / 2, wallCenterY, centerZ),
		wallColor,
		true
	)
	makePart(
		model,
		"Wall_Right",
		Vector3.new(wallThickness, wallHeight, halfDepth * 2),
		Vector3.new(centerX + halfWidth - wallThickness / 2, wallCenterY, centerZ),
		wallColor,
		true
	)

	-- Vorderwand mit Türoeffnung (4 breit, 5.5 hoch, mittig).
	local doorWidth = 4
	local doorHeight = 5.5
	local sideWidth = (halfWidth * 2 - doorWidth) / 2
	makePart(
		model,
		"Wall_FrontLeft",
		Vector3.new(sideWidth, wallHeight, wallThickness),
		Vector3.new(centerX - doorWidth / 2 - sideWidth / 2, wallCenterY, frontZ),
		wallColor,
		true
	)
	makePart(
		model,
		"Wall_FrontRight",
		Vector3.new(sideWidth, wallHeight, wallThickness),
		Vector3.new(centerX + doorWidth / 2 + sideWidth / 2, wallCenterY, frontZ),
		wallColor,
		true
	)
	makePart(
		model,
		"Wall_FrontLintel",
		Vector3.new(doorWidth, wallHeight - doorHeight, wallThickness),
		Vector3.new(centerX, floorTop + doorHeight + (wallHeight - doorHeight) / 2, frontZ),
		wallColor,
		true
	)

	-- Klare Eingangstuer (begehbar: CanCollide false, frei erreichbar).
	makePart(
		model,
		"EntranceDoor",
		Vector3.new(doorWidth, doorHeight, 0.5),
		Vector3.new(centerX, floorTop + doorHeight / 2, frontZ),
		doorColor,
		false,
		0.15,
		Enum.Material.WoodPlanks
	)
	-- Tuerrahmen.
	makePart(
		model,
		"DoorFrame_Left",
		Vector3.new(0.5, doorHeight, 1.2),
		Vector3.new(centerX - doorWidth / 2, floorTop + doorHeight / 2, frontZ),
		trimColor,
		true
	)
	makePart(
		model,
		"DoorFrame_Right",
		Vector3.new(0.5, doorHeight, 1.2),
		Vector3.new(centerX + doorWidth / 2, floorTop + doorHeight / 2, frontZ),
		trimColor,
		true
	)

	-- Schaufenster links und rechts der Tuer (Glas, gut sichtbar).
	local windowY = floorTop + 3
	makePart(
		model,
		"ShopWindow_Left",
		Vector3.new(5, 3, 0.4),
		Vector3.new(centerX - doorWidth / 2 - sideWidth / 2, windowY, frontZ + 0.2),
		glassColor,
		true,
		0.35,
		Enum.Material.Glass
	)
	makePart(
		model,
		"ShopWindow_Right",
		Vector3.new(5, 3, 0.4),
		Vector3.new(centerX + doorWidth / 2 + sideWidth / 2, windowY, frontZ + 0.2),
		glassColor,
		true,
		0.35,
		Enum.Material.Glass
	)
	-- Fensterrahmen als Blenden ueber dem Glas.
	makePart(
		model,
		"WindowTrim_Left",
		Vector3.new(5.6, 0.5, 0.5),
		Vector3.new(centerX - doorWidth / 2 - sideWidth / 2, windowY + 1.75, frontZ + 0.2),
		trimColor,
		false
	)
	makePart(
		model,
		"WindowTrim_Right",
		Vector3.new(5.6, 0.5, 0.5),
		Vector3.new(centerX + doorWidth / 2 + sideWidth / 2, windowY + 1.75, frontZ + 0.2),
		trimColor,
		false
	)

	-- Dach mit Ueberstand und Dachkante.
	makePart(
		model,
		"Roof",
		Vector3.new(22, 1, 16),
		Vector3.new(centerX, floorTop + wallHeight + 0.5, centerZ),
		roofColor,
		true
	)
	makePart(
		model,
		"RoofTrim",
		Vector3.new(22.4, 0.5, 16.4),
		Vector3.new(centerX, floorTop + wallHeight + 0.1, centerZ),
		trimColor,
		false
	)

	-- Beleuchtung: Deckenleuchte innen und Aussenlampe ueber dem Eingang.
	local ceilingLightPart = makePart(
		model,
		"CeilingLight",
		Vector3.new(4, 0.4, 2),
		Vector3.new(centerX, floorTop + wallHeight - 0.3, centerZ),
		lightFixtureColor,
		false,
		0,
		Enum.Material.Neon
	)
	local ceilingLight = Instance.new("PointLight")
	ceilingLight.Name = "InteriorLight"
	ceilingLight.Brightness = 2
	ceilingLight.Range = 45
	ceilingLight.Color = Color3.fromRGB(255, 245, 220)
	ceilingLight.Parent = ceilingLightPart

	local porchLightPart = makePart(
		model,
		"PorchLight",
		Vector3.new(2, 0.4, 0.6),
		Vector3.new(centerX, floorTop + doorHeight + 0.6, frontZ + 0.8),
		lightFixtureColor,
		false,
		0,
		Enum.Material.Neon
	)
	local porchLight = Instance.new("PointLight")
	porchLight.Name = "EntranceLight"
	porchLight.Brightness = 2
	porchLight.Range = 30
	porchLight.Color = Color3.fromRGB(255, 240, 200)
	porchLight.Parent = porchLightPart

	-- Grosses lesbares Schild mit exakt "Döner Laden" zur Abholseite (+Z).
	local signPart = makePart(
		model,
		"ShopSign",
		Vector3.new(16, 2.5, 0.6),
		Vector3.new(centerX, floorTop + wallHeight - 0.6, frontZ + 0.8),
		trimColor,
		false
	)
	makeSignGui(Enum.NormalId.Back, signPart)
	makeSignGui(Enum.NormalId.Front, signPart)

	-- Kompatibler Abholpunkt fuer Lieferungen (keine Preise, keine Logik).
	local pickupPad = makePart(
		model,
		PICKUP_NAME,
		Vector3.new(6, 0.4, 6),
		Vector3.new(pickupX, pickupGroundY + 0.2, pickupZ),
		Color3.fromRGB(220, 150, 60),
		false
	)
	pickupPad:SetAttribute("IsDeliveryPoint", true)
	pickupPad:SetAttribute("PickupKind", "doner")

	model.PrimaryPart = floorPart
	model.Parent = parent
	return model
end

return DonerShopBuilder
