--!strict
-- TrafficSignPlacement.spec: prueft die reine Schildplatzierung aus Task 25.
-- Lauf: lune run tests/TrafficSignPlacement.spec.luau
-- Geprueft werden: Determinismus, genau ein Stoppschild je Stopstrasse hinter
-- der Haltelinie, fahrtrichtungsbezogene Tempolimits am rechten Fahrbahnrand,
-- freie Fahrbahn/Fusswege/Garagenzufahrten und gueltige Hoehen.

local TrafficSignPlacer = require("../src/server/world/TrafficSignPlacer")
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

local function normalize2D(x: number, z: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then
		return 0, 0
	end
	return x / length, z / length
end

local function dot2D(ax: number, az: number, bx: number, bz: number): number
	return ax * bx + az * bz
end

local function frontOf(rotation: number): (number, number)
	local radians = math.rad(rotation)
	return -math.sin(radians), -math.cos(radians)
end

local function findRoad(id: string): any
	for _, road in WorldZones.ROAD_SEGMENTS do
		if road.id == id then
			return road
		end
	end
	for _, road in WorldZones.STOP_ROADS do
		if road.id == id then
			return road
		end
	end
	return nil
end

local function findRoundaboutForRoad(id: string): any
	for _, roundabout in WorldZones.ROUNDABOUTS do
		for _, roadId in roundabout.roadIds do
			if roadId == id then
				return roundabout
			end
		end
	end
	return nil
end

-- API -------------------------------------------------------------------

check("calculatePlacements ist eine Funktion", type(TrafficSignPlacer.calculatePlacements) == "function")
check("build ist eine Funktion", type(TrafficSignPlacer.build) == "function")

local placements = TrafficSignPlacer.calculatePlacements()
local secondRun = TrafficSignPlacer.calculatePlacements()

-- Determinismus ---------------------------------------------------------

local identical = #placements == #secondRun
if identical then
	for index, placement in placements do
		local other = secondRun[index]
		if
			placement.signType ~= other.signType
			or placement.roadId ~= other.roadId
			or placement.rotation ~= other.rotation
			or placement.limit ~= other.limit
			or placement.position.x ~= other.position.x
			or placement.position.y ~= other.position.y
			or placement.position.z ~= other.position.z
			or placement.travel.x ~= other.travel.x
			or placement.travel.z ~= other.travel.z
		then
			identical = false
			break
		end
	end
end

check("Platzierung ist deterministisch", identical, string.format("Laeufe: %d / %d", #placements, #secondRun))
check("Platzierung ist nicht leer", #placements > 0, string.format("gefunden: %d", #placements))

-- Kategorien ------------------------------------------------------------

local stopSigns = {}
local speedSigns = {}
local stopCountByRoad: { [string]: number } = {}
local unknownTypes = 0

for index, placement in placements do
	if placement.signType == "Stop" then
		table.insert(stopSigns, placement)
		stopCountByRoad[placement.roadId] = (stopCountByRoad[placement.roadId] or 0) + 1
	elseif placement.signType == "SpeedLimit" then
		table.insert(speedSigns, placement)
	else
		unknownTypes += 1
	end
	check(
		string.format("Platzierung %d hat endliche Werte", index),
		placement.position.x == placement.position.x
			and placement.position.y == placement.position.y
			and placement.position.z == placement.position.z
			and placement.rotation == placement.rotation
	)
	check(
		string.format("Platzierung %d hat eine RoadId", index),
		type(placement.roadId) == "string" and #placement.roadId > 0
	)
end

check("nur Stoppschilder und Tempolimits", unknownTypes == 0, string.format("unbekannt: %d", unknownTypes))

-- Stoppschilder ---------------------------------------------------------

check(
	"genau ein Stoppschild je Stopstrasse",
	#stopSigns == #WorldZones.STOP_ROADS,
	string.format("Schilder: %d, Stopstrassen: %d", #stopSigns, #WorldZones.STOP_ROADS)
)

for _, stopSign in stopSigns do
	local road = findRoad(stopSign.roadId)
	check(string.format("%s verweist auf eine Strasse", stopSign.roadId), road ~= nil)

	if road then
		check(string.format("%s ist eine Stopstrasse", road.id), road.kind == "stop")

		local expectedX, expectedZ = normalize2D(road.from.x - road.to.x, road.from.z - road.to.z)
		check(
			string.format("%s gilt fuer die Dorf-Ring-Richtung", road.id),
			math.abs(stopSign.travel.x - expectedX) < 1e-6 and math.abs(stopSign.travel.z - expectedZ) < 1e-6
		)

		local frontX, frontZ = frontOf(stopSign.rotation)
		check(
			string.format("%s zeigt zum ankommenden Verkehr", road.id),
			dot2D(frontX, frontZ, stopSign.travel.x, stopSign.travel.z) < -0.999,
			string.format("front=(%.3f, %.3f)", frontX, frontZ)
		)

		local stopLine = road.stopLinePosition
		if stopLine then
			local deltaX = stopSign.position.x - stopLine.x
			local deltaZ = stopSign.position.z - stopLine.z
			local longitudinal = dot2D(deltaX, deltaZ, expectedX, expectedZ)
			local lateral = dot2D(deltaX, deltaZ, -expectedZ, expectedX)

			check(
				string.format("%s steht hinter der Haltelinie", road.id),
				longitudinal < 0,
				string.format("laengs: %.2f", longitudinal)
			)
			check(
				string.format("%s steht rechts der Fahrtrichtung", road.id),
				lateral >= road.width / 2 + TrafficSignPlacer.EDGE_CLEARANCE - 0.01,
				string.format("seitlich: %.2f", lateral)
			)
		end

		local centerlineDistance =
			distanceToSegment(stopSign.position.x, stopSign.position.z, road.from.x, road.from.z, road.to.x, road.to.z)
		check(
			string.format("%s blockiert die Fahrbahn nicht", road.id),
			centerlineDistance > road.width / 2,
			string.format("Abstand: %.2f", centerlineDistance)
		)
		check(
			string.format("%s steht im Tal", road.id),
			WorldZones.BOUNDS.minX <= stopSign.position.x
				and stopSign.position.x <= WorldZones.BOUNDS.maxX
				and WorldZones.BOUNDS.minZ <= stopSign.position.z
				and stopSign.position.z <= WorldZones.BOUNDS.maxZ
		)
		check(
			string.format("%s steht nicht im Wasser", road.id),
			WorldZones.containsWater({ x = stopSign.position.x, y = 0, z = stopSign.position.z }) == false
		)
	end
end

for _, road in WorldZones.STOP_ROADS do
	check(
		string.format("%s hat genau ein Stoppschild", road.id),
		stopCountByRoad[road.id] == 1,
		string.format("gefunden: %d", stopCountByRoad[road.id] or 0)
	)
end

-- Tempolimits -----------------------------------------------------------

check("Tempolimits vorhanden", #speedSigns > 0, string.format("gefunden: %d", #speedSigns))
check("mindestens drei Tempolimits", #speedSigns >= 3, string.format("gefunden: %d", #speedSigns))

local allowedLimits = {
	[TrafficSignPlacer.RING_LIMIT] = true,
	[TrafficSignPlacer.ACCESS_LIMIT] = true,
	[TrafficSignPlacer.TRUNK_LIMIT] = true,
}

local ringSignCount = 0
local trunkSignCount = 0
local accessSignCount = 0

for _, speedSign in speedSigns do
	local road = findRoad(speedSign.roadId)
	check(string.format("%s verweist auf eine Hauptstrasse", speedSign.roadId), road ~= nil)
	check(
		string.format("%s hat ein zulaessiges Limit", speedSign.roadId),
		speedSign.limit ~= nil and allowedLimits[speedSign.limit] == true,
		tostring(speedSign.limit)
	)

	if road then
		if road.kind == "ring" then
			ringSignCount += 1
		elseif road.kind == "trunk" then
			trunkSignCount += 1
		elseif road.kind == "access" then
			accessSignCount += 1
		end

		local frontX, frontZ = frontOf(speedSign.rotation)
		check(
			string.format("%s zeigt gegen die Fahrtrichtung", road.id),
			dot2D(frontX, frontZ, speedSign.travel.x, speedSign.travel.z) < -0.999
		)

		local directionX, directionZ = normalize2D(speedSign.travel.x, speedSign.travel.z)
		local rightX, rightZ = -directionZ, directionX
		local roadX, roadZ = normalize2D(road.to.x - road.from.x, road.to.z - road.from.z)
		local deltaX = speedSign.position.x - road.from.x
		local deltaZ = speedSign.position.z - road.from.z
		local projected = dot2D(deltaX, deltaZ, roadX, roadZ)
		local lateral = dot2D(deltaX, deltaZ, rightX, rightZ)

		check(
			string.format("%s steht rechts der Fahrtrichtung", road.id),
			lateral > 0,
			string.format("seitlich: %.2f", lateral)
		)
		check(
			string.format("%s steht am passenden Strassenrand", road.id),
			math.abs(lateral - (road.width / 2 + TrafficSignPlacer.EDGE_CLEARANCE)) <= 0.5,
			string.format("seitlich: %.2f", lateral)
		)
		check(
			string.format("%s liegt auf dem Strassenabschnitt", road.id),
			projected >= 0 and projected <= distance2D(road.from.x, road.from.z, road.to.x, road.to.z),
			string.format("laengs: %.2f", projected)
		)

		local centerlineDistance = distanceToSegment(
			speedSign.position.x,
			speedSign.position.z,
			road.from.x,
			road.from.z,
			road.to.x,
			road.to.z
		)
		check(string.format("%s blockiert die Fahrbahn nicht", road.id), centerlineDistance > road.width / 2)

		local roundabout = findRoundaboutForRoad(road.id)
		if roundabout then
			check(
				string.format("%s steht nicht im Kreisel", road.id),
				distance2D(speedSign.position.x, speedSign.position.z, roundabout.center.x, roundabout.center.z)
					> roundabout.radius
			)
		end

		check(
			string.format("%s steht nicht im Wasser", road.id),
			WorldZones.containsWater({ x = speedSign.position.x, y = 0, z = speedSign.position.z }) == false
		)
		check(
			string.format("%s steht im Tal", road.id),
			WorldZones.BOUNDS.minX <= speedSign.position.x
				and speedSign.position.x <= WorldZones.BOUNDS.maxX
				and WorldZones.BOUNDS.minZ <= speedSign.position.z
				and speedSign.position.z <= WorldZones.BOUNDS.maxZ
		)
	end
end

check("Tempolimits stehen am Ring", ringSignCount >= 2, string.format("gefunden: %d", ringSignCount))
check("Tempolimits stehen an der Seestrasse", trunkSignCount >= 1, string.format("gefunden: %d", trunkSignCount))
check("Tempolimits stehen an der Doenerzufahrt", accessSignCount >= 1, string.format("gefunden: %d", accessSignCount))

-- Hoehen ----------------------------------------------------------------

local badHeight = 0
local uniquePositions: { [string]: boolean } = {}
local uniqueCount = 0

for _, placement in placements do
	local expectedHeight = TerrainHeight.heightAt(placement.position.x, placement.position.z)
	if math.abs(placement.position.y - expectedHeight) > 0.001 then
		badHeight += 1
	end

	local key = string.format("%.3f:%.3f", placement.position.x, placement.position.z)
	if not uniquePositions[key] then
		uniquePositions[key] = true
		uniqueCount += 1
	end
end

check("alle Schilder stehen auf Gelaendehoehe", badHeight == 0, string.format("%d falsch", badHeight))
check(
	"alle Schilder haben eine eindeutige Position",
	uniqueCount == #placements,
	string.format("%d von %d", uniqueCount, #placements)
)

-- Zonendaten unveraendert ------------------------------------------------

local firstRoadId = WorldZones.ROAD_SEGMENTS[1].id
TrafficSignPlacer.calculatePlacements()
check("Zonendaten unveraendert", WorldZones.ROAD_SEGMENTS[1].id == firstRoadId)

-- Zusammenfassung -------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("TrafficSignPlacement.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("TrafficSignPlacement.spec: alle Checks bestanden")
