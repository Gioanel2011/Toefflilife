--!strict
-- VegetationLayout.spec: prueft die reine Vegetationsplatzierung aus Task 21.
-- Lauf: lune run tests/VegetationLayout.spec.luau
-- Geprueft werden: Determinismus, begrenzte Anzahl, Tal-Grenzen, keine Baeume
-- in Ausschlusszonen (Strassen, Wasser, Gebaeude, Garagen, Lieferpunkte,
-- Weiden), Mindestabstand, Walddichte und Variation.

local VegetationBuilder = require("../src/server/world/VegetationBuilder")
local WorldZones = require("../src/server/world/WorldZones")
local WorldLayout = require("../src/server/world/WorldLayout")
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

local function toRectLocal(px: number, pz: number, center, yawDegrees: number): (number, number)
	local yaw = math.rad(yawDegrees)
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	local dx = px - center.x
	local dz = pz - center.z
	return dx * cosYaw + dz * sinYaw, -dx * sinYaw + dz * cosYaw
end

local function rectContains(px: number, pz: number, center, sizeX: number, sizeZ: number, yawDegrees: number, margin: number): boolean
	local localX, localZ = toRectLocal(px, pz, center, yawDegrees)
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

local function forestAt(px: number, pz: number): any
	for _, forest in WorldZones.FORESTS do
		if distance2D(px, pz, forest.center.x, forest.center.z) <= forest.radius then
			return forest
		end
	end
	return nil
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) < 1000000
end

-- API -------------------------------------------------------------------

check("calculatePlacements ist eine Funktion", type(VegetationBuilder.calculatePlacements) == "function")
check("build ist eine Funktion", type(VegetationBuilder.build) == "function")

local placements = VegetationBuilder.calculatePlacements()
local secondRun = VegetationBuilder.calculatePlacements()

-- Determinismus ---------------------------------------------------------

local identical = #placements == #secondRun
if identical then
	for index, placement in placements do
		local other = secondRun[index]
		if
			placement.position.x ~= other.position.x
			or placement.position.y ~= other.position.y
			or placement.position.z ~= other.position.z
			or placement.scale ~= other.scale
			or placement.seed ~= other.seed
			or placement.group ~= other.group
		then
			identical = false
			break
		end
	end
end

check("Platzierung ist deterministisch", identical, string.format("Laeufe: %d / %d", #placements, #secondRun))
check("Platzierung ist nicht leer", #placements > 0)
check(
	"Platzierung ist begrenzt",
	#placements <= VegetationBuilder.MAX_TREES,
	string.format("%d > %d", #placements, VegetationBuilder.MAX_TREES)
)

-- Positionen ------------------------------------------------------------

local seeds: { [number]: boolean } = {}
local uniquePositions: { [string]: boolean } = {}
local uniquePositionsCount = 0
local scaleMinimum = math.huge
local scaleMaximum = -math.huge
local scaleBuckets: { [string]: boolean } = {}
local scaleBucketCount = 0
local outOfBounds = 0
local badHeight = 0
local nonFinite = 0

for _, placement in placements do
	local position = placement.position
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
	end

	seeds[placement.seed] = true

	local key = string.format("%.3f:%.3f", position.x, position.z)
	if not uniquePositions[key] then
		uniquePositions[key] = true
		uniquePositionsCount += 1
	end

	scaleMinimum = math.min(scaleMinimum, placement.scale)
	scaleMaximum = math.max(scaleMaximum, placement.scale)
	local bucket = string.format("%.1f", placement.scale)
	if not scaleBuckets[bucket] then
		scaleBuckets[bucket] = true
		scaleBucketCount += 1
	end
end

local seedCount = 0
for _ in seeds do
	seedCount += 1
end

check("alle Positionen endlich", nonFinite == 0, string.format("%d ungueltig", nonFinite))
check("alle Baeume im Tal", outOfBounds == 0, string.format("%d ausserhalb", outOfBounds))
check("alle Baeume auf Gelaendehoehe", badHeight == 0, string.format("%d falsch", badHeight))
check("jeder Baum hat einen eindeutigen Seed", seedCount == #placements)
check("jeder Baum hat eine eindeutige Position", uniquePositionsCount == #placements)
check(
	"Baumhoehen variieren",
	scaleMaximum - scaleMinimum >= 0.2 and scaleBucketCount >= 4,
	string.format("min %.2f max %.2f buckets %d", scaleMinimum, scaleMaximum, scaleBucketCount)
)

-- Mindestabstand --------------------------------------------------------

local closestPair = math.huge
for firstIndex = 1, #placements do
	local first = placements[firstIndex].position
	for secondIndex = firstIndex + 1, #placements do
		local second = placements[secondIndex].position
		closestPair = math.min(closestPair, distance2D(first.x, first.z, second.x, second.z))
	end
end
check(
	"Baeume halten Mindestabstand",
	closestPair >= VegetationBuilder.MIN_SPACING - 0.001,
	string.format("engster Abstand: %.2f", closestPair)
)

-- Ausschlusszonen -------------------------------------------------------

local onRoad = 0
local inWater = 0
local inPasture = 0
local nearGarage = 0
local nearHouse = 0
local nearChurch = 0
local nearDoner = 0
local nearDelivery = 0

local doner = WorldLayout.DONER
local church = WorldLayout.CHURCH
local deliveryPoints = WorldLayout.getDeliveryPoints()

for _, placement in placements do
	local position = placement.position
	local px = position.x
	local pz = position.z

	if WorldZones.isRoad({ x = px, y = 0, z = pz }, 1) then
		onRoad += 1
	end
	if distanceToWater(px, pz) < 3 then
		inWater += 1
	end
	for _, pasture in WorldZones.PASTURES do
		if rectContains(px, pz, pasture.center, pasture.size.x, pasture.size.z, pasture.yaw, 2) then
			inPasture += 1
			break
		end
	end
	for _, garage in WorldLayout.GARAGES do
		if distance2D(px, pz, garage.position.x, garage.position.z) < WorldZones.GARAGE_RADIUS + 4 then
			nearGarage += 1
			break
		end
	end
	for _, village in WorldLayout.VILLAGES do
		local blocked = false
		for _, slot in village.slots do
			if rectContains(px, pz, slot.position, slot.footprint.x, slot.footprint.z, slot.yaw, 4) then
				blocked = true
				break
			end
		end
		if blocked then
			nearHouse += 1
			break
		end
	end
	if rectContains(px, pz, church.position, church.footprint.x, church.footprint.z, church.yaw, 4) then
		nearChurch += 1
	end
	if distance2D(px, pz, doner.position.x, doner.position.z) < doner.radius + 4 then
		nearDoner += 1
	end
	for _, point in deliveryPoints do
		if distance2D(px, pz, point.position.x, point.position.z) < 8 then
			nearDelivery += 1
			break
		end
	end
end

check("keine Baeume auf Fahrbahnen", onRoad == 0, string.format("%d Baeume", onRoad))
check("keine Baeume im Wasser", inWater == 0, string.format("%d Baeume", inWater))
check("keine Baeume auf Weiden", inPasture == 0, string.format("%d Baeume", inPasture))
check("keine Baeume an Garagen", nearGarage == 0, string.format("%d Baeume", nearGarage))
check("keine Baeume in Hauseingaengen", nearHouse == 0, string.format("%d Baeume", nearHouse))
check("keine Baeume an der Kirche", nearChurch == 0, string.format("%d Baeume", nearChurch))
check("keine Baeume am Doenerplatz", nearDoner == 0, string.format("%d Baeume", nearDoner))
check("keine Baeume auf Lieferpunkten", nearDelivery == 0, string.format("%d Baeume", nearDelivery))

-- Walddichte und Baumgruppen --------------------------------------------

local forestCounts: { [string]: number } = {}
local insideForests = 0

for _, forest in WorldZones.FORESTS do
	forestCounts[forest.id] = 0
end

for _, placement in placements do
	local forest = forestAt(placement.position.x, placement.position.z)
	if forest ~= nil then
		insideForests += 1
		forestCounts[forest.id] += 1
	end
end

for _, forest in WorldZones.FORESTS do
	check(
		string.format("%s ist bewaldet", forest.id),
		forestCounts[forest.id] >= 8,
		string.format("%d Baeume", forestCounts[forest.id])
	)
end

check(
	"Waelder tragen den Grossteil der Baeume",
	insideForests >= math.floor(#placements * 0.6),
	string.format("%d von %d", insideForests, #placements)
)
check(
	"Baumgruppen ausserhalb der Waelder existieren",
	#placements - insideForests >= 8,
	string.format("%d Baeume", #placements - insideForests)
)

-- Keine Mutation der Zonendaten -----------------------------------------

local firstForestXBefore = WorldZones.FORESTS[1].center.x
local garageXBefore = WorldLayout.GARAGES[1].position.x
VegetationBuilder.calculatePlacements()
check("Zonendaten unveraendert", WorldZones.FORESTS[1].center.x == firstForestXBefore)
check("Layoutdaten unveraendert", WorldLayout.GARAGES[1].position.x == garageXBefore)

-- Zusammenfassung -------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("VegetationLayout.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("VegetationLayout.spec: alle Checks bestanden")
