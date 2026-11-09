--!strict
-- GrassLayout.spec: prueft die reine Grasplatzierung aus Task 28.
-- Lauf: lune run tests/GrassLayout.spec.luau
-- Geprueft werden: Determinismus, begrenzte Anzahl, Tal-Grenzen, Gelaendehoehe,
-- Chunk-IDs, Mindestabstand, kurze Halme sowie keine Bueschel auf Strassen,
-- im Wasser, in Gebaeuden, an Garagen oder auf Lieferpunkten.

local GrassFieldBuilder = require("../src/server/world/GrassFieldBuilder")
local WorldLayout = require("../src/server/world/WorldLayout")
local WorldZones = require("../src/server/world/WorldZones")
local TerrainHeight = require("../src/server/world/TerrainHeight")

local checks = 0
local failures = 0

local function check(name: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(string.format("ok   %s", name))
		return
	end
	failures += 1
	if detail then
		print(string.format("FAIL %s -> %s", name, detail))
	else
		print(string.format("FAIL %s", name))
	end
end

-- Geometrie-Helfer (bewusst unabhaengig vom Modul implementiert) --------

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx = bx - ax
	local dz = bz - az
	local lengthSquared = dx * dx + dz * dz
	if lengthSquared == 0 then
		return distance2D(px, pz, ax, az)
	end
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1)
	return distance2D(px, pz, ax + dx * t, az + dz * t)
end

local function rectContains(px: number, pz: number, center, sizeX: number, sizeZ: number, yawDegrees: number, margin: number): boolean
	local yaw = math.rad(yawDegrees)
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	local dx = px - center.x
	local dz = pz - center.z
	local localX = dx * cosYaw + dz * sinYaw
	local localZ = -dx * sinYaw + dz * cosYaw
	return math.abs(localX) <= sizeX / 2 + margin and math.abs(localZ) <= sizeZ / 2 + margin
end

-- Abstand zur naechsten Wasserflaeche; 0 bedeutet im Wasser.
local function distanceToWater(px: number, pz: number): number
	local best = math.huge
	for _, course in WorldZones.WATER_COURSES do
		if course.kind == "lake" then
			best = math.min(best, distance2D(px, pz, course.center.x, course.center.z) - course.radius)
		else
			for index = 1, #course.points - 1 do
				local a = course.points[index]
				local b = course.points[index + 1]
				best = math.min(best, distanceToSegment(px, pz, a.x, a.z, b.x, b.z) - course.width / 2)
			end
		end
	end
	return best
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) < 1000000
end

-- API -------------------------------------------------------------------

check("calculateGrassClumps ist eine Funktion", type(GrassFieldBuilder.calculateGrassClumps) == "function")
check("build ist eine Funktion", type(GrassFieldBuilder.build) == "function")
check("Tag ist ToeffliGrass", GrassFieldBuilder.TAG_NAME == "ToeffliGrass", tostring(GrassFieldBuilder.TAG_NAME))
check("Chunk-Groesse ist positiv", GrassFieldBuilder.CHUNK_SIZE > 0)

local clumps = GrassFieldBuilder.calculateGrassClumps()
local secondRun = GrassFieldBuilder.calculateGrassClumps()

-- Determinismus ---------------------------------------------------------

local identical = #clumps == #secondRun
if identical then
	for index, clump in clumps do
		local other = secondRun[index]
		if
			clump.position.x ~= other.position.x
			or clump.position.y ~= other.position.y
			or clump.position.z ~= other.position.z
			or clump.chunkId ~= other.chunkId
			or clump.yaw ~= other.yaw
			or clump.scale ~= other.scale
			or clump.seed ~= other.seed
		then
			identical = false
			break
		end
	end
end

check("Platzierung ist deterministisch", identical, string.format("Laeufe: %d / %d", #clumps, #secondRun))
check("Platzierung ist nicht leer", #clumps > 0)
check(
	"Platzierung ist fuer 15 Spieler begrenzt",
	#clumps <= GrassFieldBuilder.MAX_CLUMPS,
	string.format("%d > %d", #clumps, GrassFieldBuilder.MAX_CLUMPS)
)

-- Positionen, Hoehe und Chunks ------------------------------------------

local uniquePositions: { [string]: boolean } = {}
local uniquePositionsCount = 0
local uniqueSeeds: { [number]: boolean } = {}
local uniqueSeedCount = 0
local uniqueChunks: { [string]: boolean } = {}
local uniqueChunkCount = 0
local outOfBounds = 0
local badHeight = 0
local nonFinite = 0
local badChunk = 0
local steepClumps = 0
local scaleMinimum = math.huge
local scaleMaximum = -math.huge

for _, clump in clumps do
	local position = clump.position
	if not (isFinite(position.x) and isFinite(position.y) and isFinite(position.z)) then
		nonFinite += 1
	else
		if not WorldLayout.isInsideBounds({ x = position.x, y = 0, z = position.z }) then
			outOfBounds += 1
		end
		local expectedHeight = TerrainHeight.heightAt(position.x, position.z)
		if math.abs(position.y - expectedHeight) > 0.001 then
			badHeight += 1
		end
		if TerrainHeight.slopeAt(position.x, position.z) > GrassFieldBuilder.MAX_SLOPE + 0.001 then
			steepClumps += 1
		end
	end

	local key = string.format("%.3f:%.3f", position.x, position.z)
	if not uniquePositions[key] then
		uniquePositions[key] = true
		uniquePositionsCount += 1
	end

	if not uniqueSeeds[clump.seed] then
		uniqueSeeds[clump.seed] = true
		uniqueSeedCount += 1
	end

	local chunkX = math.floor(position.x / GrassFieldBuilder.CHUNK_SIZE)
	local chunkZ = math.floor(position.z / GrassFieldBuilder.CHUNK_SIZE)
	local expectedChunkId = string.format("GrassChunk_%d_%d", chunkX, chunkZ)
	if clump.chunkId == "" or clump.chunkId ~= expectedChunkId then
		badChunk += 1
	end
	if not uniqueChunks[clump.chunkId] then
		uniqueChunks[clump.chunkId] = true
		uniqueChunkCount += 1
	end

	scaleMinimum = math.min(scaleMinimum, clump.scale)
	scaleMaximum = math.max(scaleMaximum, clump.scale)
end

check("alle Positionen endlich", nonFinite == 0, string.format("%d ungueltig", nonFinite))
check("alle Bueschel im Tal", outOfBounds == 0, string.format("%d ausserhalb", outOfBounds))
check("alle Bueschel auf Gelaendehoehe", badHeight == 0, string.format("%d falsch", badHeight))
check("alle Chunk-IDs stimmen", badChunk == 0, string.format("%d falsch", badChunk))
check("Chunks sind fein genug verteilt", uniqueChunkCount >= 20, string.format("%d Chunks", uniqueChunkCount))
check("jedes Bueschel hat eine eindeutige Position", uniquePositionsCount == #clumps)
check("jedes Bueschel hat einen eindeutigen Seed", uniqueSeedCount == #clumps)
check("Gras waechst nur auf flachen Flaechen", steepClumps == 0, string.format("%d zu steil", steepClumps))
check(
	"Halme sind kurz",
	GrassFieldBuilder.BLADE_HEIGHT * GrassFieldBuilder.MAX_SCALE <= 1.2,
	string.format("%.2f Studs", GrassFieldBuilder.BLADE_HEIGHT * GrassFieldBuilder.MAX_SCALE)
)
check(
	"Grasgroessen variieren",
	scaleMinimum >= GrassFieldBuilder.MIN_SCALE - 0.001
		and scaleMaximum <= GrassFieldBuilder.MAX_SCALE + 0.001
		and scaleMaximum - scaleMinimum >= 0.1,
	string.format("min %.2f max %.2f", scaleMinimum, scaleMaximum)
)

-- Mindestabstand --------------------------------------------------------

local closestPair = math.huge
for firstIndex = 1, #clumps do
	local first = clumps[firstIndex].position
	for secondIndex = firstIndex + 1, #clumps do
		local second = clumps[secondIndex].position
		closestPair = math.min(closestPair, distance2D(first.x, first.z, second.x, second.z))
	end
end
check(
	"Bueschel halten Mindestabstand",
	closestPair >= GrassFieldBuilder.MIN_SPACING - 0.001,
	string.format("engster Abstand: %.2f", closestPair)
)

-- Ausschlusszonen -------------------------------------------------------

local onRoad = 0
local inWater = 0
local inBuilding = 0
local nearGarage = 0
local onDelivery = 0

local church = WorldLayout.CHURCH
local doner = WorldLayout.DONER
local deliveryPoints = WorldLayout.getDeliveryPoints()

for _, clump in clumps do
	local position = clump.position
	local px = position.x
	local pz = position.z

	if WorldZones.isRoad({ x = px, y = 0, z = pz }, 1) then
		onRoad += 1
	end
	if distanceToWater(px, pz) < 3 then
		inWater += 1
	end

	local blockedByBuilding = false
	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			if rectContains(px, pz, slot.position, slot.footprint.x, slot.footprint.z, slot.yaw, 1) then
				blockedByBuilding = true
				break
			end
		end
		if blockedByBuilding then
			break
		end
	end
	if rectContains(px, pz, church.position, church.footprint.x, church.footprint.z, church.yaw, 1) then
		blockedByBuilding = true
	end
	if distance2D(px, pz, doner.position.x, doner.position.z) < doner.radius + 1 then
		blockedByBuilding = true
	end
	if blockedByBuilding then
		inBuilding += 1
	end

	for _, garage in WorldLayout.GARAGES do
		if distance2D(px, pz, garage.position.x, garage.position.z) < WorldZones.GARAGE_RADIUS + 2 then
			nearGarage += 1
			break
		end
	end

	for _, point in deliveryPoints do
		if distance2D(px, pz, point.position.x, point.position.z) < 3 then
			onDelivery += 1
			break
		end
	end
end

check("keine Bueschel auf Fahrbahnen", onRoad == 0, string.format("%d Bueschel", onRoad))
check("keine Bueschel im Wasser", inWater == 0, string.format("%d Bueschel", inWater))
check("keine Bueschel in Gebaeuden", inBuilding == 0, string.format("%d Bueschel", inBuilding))
check("keine Bueschel an Garagen", nearGarage == 0, string.format("%d Bueschel", nearGarage))
check("keine Bueschel auf Lieferpunkten", onDelivery == 0, string.format("%d Bueschel", onDelivery))

-- Keine Mutation der Zonendaten -----------------------------------------

local lakeXBefore = WorldZones.LAKE.center.x
local garageXBefore = WorldLayout.GARAGES[1].position.x
GrassFieldBuilder.calculateGrassClumps()
check("Zonendaten unveraendert", WorldZones.LAKE.center.x == lakeXBefore)
check("Layoutdaten unveraendert", WorldLayout.GARAGES[1].position.x == garageXBefore)

-- Zusammenfassung -------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("GrassLayout.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("GrassLayout.spec: alle Checks bestanden")
