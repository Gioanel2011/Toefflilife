--!strict
-- PastureBuilder: umzaeunte Kuhweiden ohne Kuehe.
-- Baut fuer jede Weide aus WorldZones.PASTURES einen gruenen Boden mit
-- vollstaendiger Umzaeunung und erkennbarem Tor. Keine Tiere, keine Strassen-
-- blockade, keine Zaeune in Wasser, Gebaeuden oder Garagenzufahrten.
-- Keine globalen Variablen, keine externen Assets.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")

local PastureBuilder = {}

local FENCE_HEIGHT = 1.2
local FENCE_THICKNESS = 0.4
local GATE_WIDTH = 4
local PASTURE_FLOOR_THICKNESS = 0.4

local GRASS_COLOR = Color3.fromRGB(92, 168, 72)
local FENCE_COLOR = Color3.fromRGB(139, 92, 46)
local GATE_COLOR = Color3.fromRGB(105, 68, 34)
local POST_COLOR = Color3.fromRGB(95, 62, 30)

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	canCollide: boolean,
	material: Enum.Material?,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
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

-- Erzeugt eine vollstaendig umzaeunte Weide mit Tor und gibt das Model zurueck.
local function buildPasture(pasture: any): Model
	local center = pasture.center
	local size = pasture.size
	local yaw = pasture.yaw or 0

	local groundY = TerrainHeight.heightAt(center.x, center.z)

	local base = CFrame.new(Vector3.new(center.x, groundY, center.z))
		* CFrame.Angles(0, math.rad(yaw), 0)

	local model = Instance.new("Model")
	model.Name = "Pasture_" .. tostring(pasture.id)
	model:SetAttribute("PastureId", pasture.id)
	model:SetAttribute("IsPasture", true)

	-- Gruener Boden ohne braune Stellen.
	local floorPart = makePart(
		model,
		"PastureFloor",
		Vector3.new(size.x, PASTURE_FLOOR_THICKNESS, size.z),
		base * CFrame.new(0, PASTURE_FLOOR_THICKNESS / 2, 0),
		GRASS_COLOR,
		true,
		Enum.Material.Grass
	)
	model.PrimaryPart = floorPart

	local halfX = size.x / 2
	local halfZ = size.z / 2
	local fenceY = FENCE_HEIGHT / 2
	local postHeight = FENCE_HEIGHT + 0.3

	-- Nordseite (vollstaendig).
	makePart(
		model,
		"Fence_North",
		Vector3.new(size.x, FENCE_HEIGHT, FENCE_THICKNESS),
		base * CFrame.new(0, fenceY, -halfZ),
		FENCE_COLOR,
		true,
		Enum.Material.Wood
	)

	-- Suedseite: zwei Zaunteile mit Toroeffnung in der Mitte.
	local sideWidth = (size.x - GATE_WIDTH) / 2
	if sideWidth > 0 then
		makePart(
			model,
			"Fence_SouthLeft",
			Vector3.new(sideWidth, FENCE_HEIGHT, FENCE_THICKNESS),
			base * CFrame.new(-(GATE_WIDTH / 2 + sideWidth / 2), fenceY, halfZ),
			FENCE_COLOR,
			true,
			Enum.Material.Wood
		)
		makePart(
			model,
			"Fence_SouthRight",
			Vector3.new(sideWidth, FENCE_HEIGHT, FENCE_THICKNESS),
			base * CFrame.new(GATE_WIDTH / 2 + sideWidth / 2, fenceY, halfZ),
			FENCE_COLOR,
			true,
			Enum.Material.Wood
		)
	end

	-- Ost- und Westseite (vollstaendig).
	makePart(
		model,
		"Fence_East",
		Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, size.z),
		base * CFrame.new(halfX, fenceY, 0),
		FENCE_COLOR,
		true,
		Enum.Material.Wood
	)
	makePart(
		model,
		"Fence_West",
		Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, size.z),
		base * CFrame.new(-halfX, fenceY, 0),
		FENCE_COLOR,
		true,
		Enum.Material.Wood
	)

	-- Tor: Pfosten, Querbalken und geschlossenes Torgatter in der Oeffnung.
	makePart(
		model,
		"GatePost_Left",
		Vector3.new(FENCE_THICKNESS, postHeight, FENCE_THICKNESS),
		base * CFrame.new(-GATE_WIDTH / 2, postHeight / 2, halfZ),
		POST_COLOR,
		true,
		Enum.Material.Wood
	)
	makePart(
		model,
		"GatePost_Right",
		Vector3.new(FENCE_THICKNESS, postHeight, FENCE_THICKNESS),
		base * CFrame.new(GATE_WIDTH / 2, postHeight / 2, halfZ),
		POST_COLOR,
		true,
		Enum.Material.Wood
	)
	makePart(
		model,
		"GateLintel",
		Vector3.new(GATE_WIDTH + FENCE_THICKNESS * 2, 0.3, FENCE_THICKNESS),
		base * CFrame.new(0, postHeight, halfZ),
		POST_COLOR,
		true,
		Enum.Material.Wood
	)
	local gate = makePart(
		model,
		"Gate",
		Vector3.new(GATE_WIDTH - 0.4, FENCE_HEIGHT - 0.2, 0.2),
		base * CFrame.new(0, (FENCE_HEIGHT - 0.2) / 2, halfZ - 0.1),
		GATE_COLOR,
		true,
		Enum.Material.Wood
	)
	gate:SetAttribute("IsPastureGate", true)

	return model
end

-- Erzeugt fuer alle Weiden aus WorldZones einen Ordner und gibt ihn zurueck.
function PastureBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Pastures"

	for _, pasture in WorldZones.PASTURES do
		local model = buildPasture(pasture)
		model.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return PastureBuilder