--!strict
-- GrassFieldBuilder: deterministische, serverseitige Grasbueschel.
-- Die reine Platzierungsfunktion `calculateGrassClumps` liefert Daten ohne
-- Roblox-Instanzen und ist damit in Studio und Lune testbar. Die Modelle
-- entstehen erst in `build`.
-- Gras steht nur ausserhalb von Strassen, Wasser, Gebaeuden, Garagen und
-- Lieferpunkten mit Sicherheitsabstand. Die Gesamtzahl ist fuer 15 Spieler
-- begrenzt; jede Gruppe traegt den CollectionService-Tag `ToeffliGrass` und
-- eine Chunk-ID. Keine Animation, keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")

local GrassFieldBuilder = {}

export type ClumpPosition = { x: number, y: number, z: number }

export type GrassClump = {
	position: ClumpPosition,
	chunkId: string,
	yaw: number,
	scale: number,
	seed: number,
}

-- Obergrenze fuer 15 Spieler: begrenzt Teilezahl und Streaming-Last.
GrassFieldBuilder.MAX_CLUMPS = 1500
-- Kantenlaenge eines Gras-Chunks (Studs). Die Chunk-ID gruppiert spaetere
-- clientseitige Bewegung, ohne dass Server-CFrames veraendert werden.
GrassFieldBuilder.CHUNK_SIZE = 40
-- Mindestabstand zwischen zwei Grasbuescheln (Studs).
GrassFieldBuilder.MIN_SPACING = 2.5
-- Sicherheitsabstand zu Fahrbahnen, Wasser, Gebaeuden, Garagen und
-- Lieferpunkten (Studs).
GrassFieldBuilder.CLEARANCE = 5
-- Zusaetzlicher Abstand zu Lieferpads, damit der Loop frei bleibt (Studs).
GrassFieldBuilder.DELIVERY_CLEARANCE = 8
-- Gras waechst nur auf flachen bis leicht geneigten Talflaechen.
GrassFieldBuilder.MAX_SLOPE = 0.6
-- Kurze Halme: maximale Halmhoehe inklusive Skalierung (Studs).
GrassFieldBuilder.BLADE_HEIGHT = 0.7
GrassFieldBuilder.MIN_SCALE = 0.75
GrassFieldBuilder.MAX_SCALE = 1.25
GrassFieldBuilder.TAG_NAME = "ToeffliGrass"
GrassFieldBuilder.FOLDER_NAME = "GrassFields"

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
	center: ClumpPosition,
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

-- Wasser hat keine Margin-API: Kandidat plus acht Randpunkte pruefen.
local function waterNear(px: number, pz: number, margin: number): boolean
	if WorldZones.containsWater({ x = px, y = 0, z = pz }) then
		return true
	end
	for angleIndex = 0, 7 do
		local angle = math.rad(angleIndex * 45)
		local x = px + math.cos(angle) * margin
		local z = pz + math.sin(angle) * margin
		if WorldZones.containsWater({ x = x, y = 0, z = z }) then
			return true
		end
	end
	return false
end

-- Ausschlusszonen: Strassen, Wasser, Gebaeude (Haus-Slots, Kirche,
-- Doenerplatz), Garagen und Lieferpunkte. Waelder und Weiden bleiben
-- bewusst begehbar und duerfen Gras tragen.
local function isExcluded(px: number, pz: number, margin: number): boolean
	local point = { x = px, y = 0, z = pz }

	if WorldZones.isRoad(point, margin) then
		return true
	end
	if waterNear(px, pz, margin) then
		return true
	end

	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			if rectContains(px, pz, slot.position, slot.footprint.x, slot.footprint.z, slot.yaw, margin) then
				return true
			end
		end
	end

	local church = WorldLayout.CHURCH
	if rectContains(px, pz, church.position, church.footprint.x, church.footprint.z, church.yaw, margin) then
		return true
	end

	local doner = WorldLayout.DONER
	if distance2D(px, pz, doner.position.x, doner.position.z) <= doner.radius + margin then
		return true
	end

	for _, garage in WorldLayout.GARAGES do
		if distance2D(px, pz, garage.position.x, garage.position.z) <= WorldZones.GARAGE_RADIUS + margin then
			return true
		end
	end

	for _, deliveryPoint in WorldLayout.getDeliveryPoints() do
		local deliveryPosition = deliveryPoint.position
		if distance2D(px, pz, deliveryPosition.x, deliveryPosition.z) <= GrassFieldBuilder.DELIVERY_CLEARANCE then
			return true
		end
	end

	return false
end

local function tooClose(clumps: { GrassClump }, px: number, pz: number, spacing: number): boolean
	for _, clump in clumps do
		if distance2D(px, pz, clump.position.x, clump.position.z) < spacing then
			return true
		end
	end
	return false
end

local function chunkIdFor(px: number, pz: number): string
	local chunkX = math.floor(px / GrassFieldBuilder.CHUNK_SIZE)
	local chunkZ = math.floor(pz / GrassFieldBuilder.CHUNK_SIZE)
	return string.format("GrassChunk_%d_%d", chunkX, chunkZ)
end

-- Reine Platzierungsdaten: deterministisch, ohne Roblox-Instanzen.
function GrassFieldBuilder.calculateGrassClumps(): { GrassClump }
	local clumps: { GrassClump } = {}

	local bounds = WorldZones.BOUNDS
	local chunkSize = GrassFieldBuilder.CHUNK_SIZE
	local minChunkX = math.floor(bounds.minX / chunkSize)
	local maxChunkX = math.floor(bounds.maxX / chunkSize)
	local minChunkZ = math.floor(bounds.minZ / chunkSize)
	local maxChunkZ = math.floor(bounds.maxZ / chunkSize)
	local targetPerChunk = 3
	local maxAttempts = targetPerChunk * 8

	for chunkX = minChunkX, maxChunkX do
		for chunkZ = minChunkZ, maxChunkZ do
			-- Eigener Zufallsstrom je Chunk: reproduzierbar und unabhaengig
			-- von der Reihenfolge anderer Chunks.
			local random = createRandom(
				WorldZones.SEED + chunkX * 73856093 + chunkZ * 19349663
			)
			local placed = 0
			local attempts = 0

			while placed < targetPerChunk and attempts < maxAttempts do
				attempts += 1
				local px = chunkX * chunkSize + random() * chunkSize
				local pz = chunkZ * chunkSize + random() * chunkSize

				if
					px >= bounds.minX
					and px <= bounds.maxX
					and pz >= bounds.minZ
					and pz <= bounds.maxZ
					and not isExcluded(px, pz, GrassFieldBuilder.CLEARANCE)
					and TerrainHeight.slopeAt(px, pz) <= GrassFieldBuilder.MAX_SLOPE
					and not tooClose(clumps, px, pz, GrassFieldBuilder.MIN_SPACING)
				then
					local scale = GrassFieldBuilder.MIN_SCALE
						+ random() * (GrassFieldBuilder.MAX_SCALE - GrassFieldBuilder.MIN_SCALE)
					clumps[#clumps + 1] = {
						position = {
							x = px,
							y = TerrainHeight.heightAt(px, pz),
							z = pz,
						},
						chunkId = chunkIdFor(px, pz),
						yaw = random() * 360,
						scale = scale,
						seed = 9000 + (#clumps + 1) * 37,
					}
					placed += 1
				end
			end
		end
	end

	-- Gleichmaessig ueber das Tal verteilen, falls mehr Kandidaten als das
	-- Budget fuer 15 Spieler entstanden sind.
	if #clumps > GrassFieldBuilder.MAX_CLUMPS then
		local random = createRandom(WorldZones.SEED + 424242)
		for index = #clumps, 2, -1 do
			local swapIndex = 1 + math.floor(random() * index)
			clumps[index], clumps[swapIndex] = clumps[swapIndex], clumps[index]
		end
		for index = #clumps, GrassFieldBuilder.MAX_CLUMPS + 1, -1 do
			clumps[index] = nil
		end
	end

	return clumps
end

-- Erzeugt ein kurzes Grasbueschel aus drei gekreuzten Halmen.
local function buildClumpModel(clump: GrassClump): Model
	local model = Instance.new("Model")
	model.Name = "GrassClump"

	local random = createRandom(clump.seed)
	local baseYaw = math.rad(clump.yaw)
	local height = GrassFieldBuilder.BLADE_HEIGHT * clump.scale
	local green = 110 + math.floor(random() * 50)
	local color = Color3.fromRGB(
		60 + math.floor(random() * 20),
		green,
		55 + math.floor(random() * 20)
	)

	local firstBlade: Part? = nil

	for bladeIndex = 1, 3 do
		local bladeHeight = height * (0.8 + random() * 0.4)
		local angle = baseYaw + (bladeIndex - 1) * (math.pi / 3)
		local tilt = (random() * 2 - 1) * 0.12
		local blade = Instance.new("Part")
		blade.Name = string.format("Blade_%d", bladeIndex)
		blade.Size = Vector3.new(0.14, bladeHeight, 0.5)
		blade.CFrame = CFrame.new(clump.position.x, clump.position.y + bladeHeight / 2 - 0.03, clump.position.z)
			* CFrame.Angles(0, angle, tilt)
		blade.Color = color
		blade.Material = Enum.Material.SmoothPlastic
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanTouch = false
		blade.CanQuery = false
		blade.CastShadow = false
		blade.TopSurface = Enum.SurfaceType.Smooth
		blade.BottomSurface = Enum.SurfaceType.Smooth
		blade.Parent = model

		if firstBlade == nil then
			firstBlade = blade
		end
	end

	model.PrimaryPart = firstBlade
	model:SetAttribute("IsGrass", true)
	model:SetAttribute("ChunkId", clump.chunkId)
	model:SetAttribute("GrassSeed", clump.seed)
	model:SetAttribute("GrassScale", clump.scale)
	return model
end

-- Erzeugt alle Grasbueschel unter einem benannten Ordner und gibt ihn zurueck.
function GrassFieldBuilder.build(parent: Instance): Folder
	-- CollectionService erst beim tatsaechlichen Bau holen, damit das Modul
	-- auch ohne Roblox-Laufzeit (Lune-Tests) geladen werden kann.
	local CollectionService = game:GetService("CollectionService")

	local folder = Instance.new("Folder")
	folder.Name = GrassFieldBuilder.FOLDER_NAME

	for index, clump in GrassFieldBuilder.calculateGrassClumps() do
		local model = buildClumpModel(clump)
		model.Name = string.format("GrassClump_%04d", index)
		CollectionService:AddTag(model, GrassFieldBuilder.TAG_NAME)
		model.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return GrassFieldBuilder
