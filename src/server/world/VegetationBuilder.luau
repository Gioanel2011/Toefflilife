--!strict
-- VegetationBuilder: deterministische Low-Poly-Waelder und Baumgruppen.
-- Die reine Platzierungsfunktion `calculatePlacements` liefert Baumdaten ohne
-- Roblox-Instanzen und ist damit in Studio und Lune testbar. Die Instanzen
-- entstehen erst in `build` ueber ConiferFactory.
-- Baeume stehen nur ausserhalb von Strassen, Wasser, Gebaeuden, Garagen,
-- Lieferpunkten und Weiden. Keine globalen Variablen, keine externen Assets.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")
local ConiferFactory = requireSibling("ConiferFactory")

local VegetationBuilder = {}

export type PlacementPosition = { x: number, y: number, z: number }

export type Placement = {
	position: PlacementPosition,
	scale: number,
	seed: number,
	group: string,
}

-- Obergrenze fuer 15 Spieler: begrenzt Teilezahl und Streaming-Last.
VegetationBuilder.MAX_TREES = 240
-- Mindestabstand zwischen zwei Baumstaemmen (Studs).
VegetationBuilder.MIN_SPACING = 7
-- Sicherheitsabstand zu Fahrbahnen, Wasser, Weiden und Gebaeuden (Studs).
VegetationBuilder.CLEARANCE = 5

-- Deterministischer Pseudozufall (Lehmer-LCG), unabhaengig von Roblox.
local function createRandom(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Punkt in einem gedrehten Rechteck (yaw um die Y-Achse in Grad).
local function rectContains(
	px: number,
	pz: number,
	center: PlacementPosition,
	sizeX: number,
	sizeZ: number,
	yawDegrees: number,
	margin: number
): boolean
	local yaw = math.rad(yawDegrees)
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	local dx = px - center.x
	local dz = pz - center.z
	local localX = dx * cosYaw + dz * sinYaw
	local localZ = -dx * sinYaw + dz * cosYaw
	return math.abs(localX) <= sizeX / 2 + margin and math.abs(localZ) <= sizeZ / 2 + margin
end

local function forestAt(px: number, pz: number, margin: number): any
	for _, forest in WorldZones.FORESTS do
		if distance2D(px, pz, forest.center.x, forest.center.z) <= forest.radius + margin then
			return forest
		end
	end
	return nil
end

-- Wasser hat keine Margin-API: Kandidat plus vier Randpunkte pruefen.
local function waterNear(px: number, pz: number, margin: number): boolean
	if WorldZones.containsWater({ x = px, y = 0, z = pz }) then
		return true
	end
	local probes = {
		{ margin, 0 },
		{ -margin, 0 },
		{ 0, margin },
		{ 0, -margin },
	}
	for _, probe in probes do
		if WorldZones.containsWater({ x = px + probe[1], y = 0, z = pz + probe[2] }) then
			return true
		end
	end
	return false
end

local function pastureNear(px: number, pz: number, margin: number): boolean
	for _, pasture in WorldZones.PASTURES do
		if
			rectContains(
				px,
				pz,
				pasture.center,
				pasture.size.x,
				pasture.size.z,
				pasture.yaw,
				margin
			)
		then
			return true
		end
	end
	return false
end

-- Ausschlusszonen. Innerhalb eines Waldes wuerde `isReserved` durch den Wald
-- selbst blockieren; dort greifen die expliziten Strassen-, Wasser- und
-- Weidenpruefungen. Gebaeude, Garagen und Lieferpunkte liegen laut den
-- validierten Zonendaten (WorldZones.spec) ausserhalb der Waldradien und
-- werden ausserhalb der Waelder zusaetzlich ueber `isReserved` abgedeckt.
local function isExcluded(px: number, pz: number, margin: number): boolean
	local point = { x = px, y = 0, z = pz }
	if WorldZones.isRoad(point, margin) then
		return true
	end
	if waterNear(px, pz, margin) then
		return true
	end
	if pastureNear(px, pz, margin) then
		return true
	end
	if forestAt(px, pz, margin) == nil and WorldZones.isReserved(point, margin) then
		return true
	end
	return false
end

local function tooClose(placements: { Placement }, px: number, pz: number, spacing: number): boolean
	for _, placement in placements do
		if distance2D(px, pz, placement.position.x, placement.position.z) < spacing then
			return true
		end
	end
	return false
end

-- Reine Platzierungsdaten: deterministisch, ohne Roblox-Instanzen.
function VegetationBuilder.calculatePlacements(): { Placement }
	local placements: { Placement } = {}

	local function addTree(px: number, pz: number, scale: number, group: string): boolean
		if #placements >= VegetationBuilder.MAX_TREES then
			return false
		end
		if tooClose(placements, px, pz, VegetationBuilder.MIN_SPACING) then
			return false
		end
		placements[#placements + 1] = {
			position = {
				x = px,
				y = TerrainHeight.heightAt(px, pz),
				z = pz,
			},
			scale = scale,
			seed = 7000 + (#placements + 1) * 37,
			group = group,
		}
		return true
	end

	-- Waelder: deterministisch gestreute Gruppen statt identischer Baumreihen.
	for forestIndex, forest in WorldZones.FORESTS do
		local random = createRandom(WorldZones.SEED + forestIndex * 211)
		local density = 0.35 + random() * 0.25
		local target = math.clamp(math.round(forest.radius * density), 14, 48)
		local maxRadius = forest.radius * 0.92
		local placed = 0
		local attempts = 0
		local maxAttempts = target * 10

		while placed < target and attempts < maxAttempts do
			attempts += 1
			local angle = random() * math.pi * 2
			local radius = math.sqrt(random()) * maxRadius
			local px = forest.center.x + math.cos(angle) * radius
			local pz = forest.center.z + math.sin(angle) * radius
			if not isExcluded(px, pz, VegetationBuilder.CLEARANCE) then
				local scale = 0.7 + random() * 0.65
				if addTree(px, pz, scale, forest.id) then
					placed += 1
				end
			end
		end
	end

	-- Kleine Baumgruppen ausserhalb der Waelder, deterministisch verteilt.
	for groveIndex = 1, 6 do
		local random = createRandom(WorldZones.SEED + 900 + groveIndex * 131)
		local centerX = 0
		local centerZ = 0
		local found = false

		for _ = 1, 120 do
			local candidateX = (random() * 2 - 1) * 520
			local candidateZ = (random() * 2 - 1) * 520
			if not isExcluded(candidateX, candidateZ, 20) then
				centerX = candidateX
				centerZ = candidateZ
				found = true
				break
			end
		end

		if found then
			local groveRadius = 6 + random() * 6
			local groveTarget = 3 + math.floor(random() * 3)
			local placed = 0

			for _ = 1, groveTarget * 12 do
				if placed >= groveTarget then
					break
				end
				local angle = random() * math.pi * 2
				local radius = math.sqrt(random()) * groveRadius
				local px = centerX + math.cos(angle) * radius
				local pz = centerZ + math.sin(angle) * radius
				if not isExcluded(px, pz, VegetationBuilder.CLEARANCE) then
					local scale = 0.7 + random() * 0.65
					if addTree(px, pz, scale, string.format("Grove_%02d", groveIndex)) then
						placed += 1
					end
				end
			end
		end
	end

	return placements
end

-- Setzt den Stammfuss exakt auf die Gelaendehoehe am Platzierungspunkt.
local function placeOnGround(model: Model, position: PlacementPosition): ()
	local pivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local baseOffset = pivot.Y - (boundsCFrame.Y - boundsSize.Y / 2)
	model:PivotTo(CFrame.new(Vector3.new(position.x, position.y + baseOffset, position.z)))
end

-- Erzeugt alle Baeume unter einem benannten Ordner und gibt ihn zurueck.
function VegetationBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Vegetation"

	for index, placement in VegetationBuilder.calculatePlacements() do
		local model = ConiferFactory.create(placement.seed, placement.scale)
		model.Name = string.format("Conifer_%03d", index)
		model:SetAttribute("IsVegetation", true)
		model:SetAttribute("VegetationGroup", placement.group)
		placeOnGround(model, placement.position)
		model.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return VegetationBuilder
