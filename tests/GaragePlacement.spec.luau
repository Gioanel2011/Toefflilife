--!strict
-- GaragePlacement.spec: prueft die reine Garagenplatzierung aus Task 26.
-- Lauf: lune run tests/GaragePlacement.spec.luau
-- Geprueft werden: genau 15 Garagen aus WorldLayout.GARAGES, identische
-- Doenerdistanz, Mindestabstand, eindeutige Anker, Gelaendehoehe, Tal-Grenzen
-- sowie keine Ueberschneidung mit Strassen, Wasser oder Gebaeuden.

local GarageWorldBuilder = require("../src/server/world/GarageWorldBuilder")
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

local function rectContains(
	px: number,
	pz: number,
	center,
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

local function waterNear(px: number, pz: number, margin: number): boolean
	for angleIndex = 0, 7 do
		local angle = math.rad(angleIndex * 45)
		local x = px + math.cos(angle) * margin
		local z = pz + math.sin(angle) * margin
		if WorldZones.containsWater({ x = x, y = 0, z = z }) then
			return true
		end
	end
	return WorldZones.containsWater({ x = px, y = 0, z = pz })
end

-- API --------------------------------------------------------------------

check("calculatePlacements ist eine Funktion", type(GarageWorldBuilder.calculatePlacements) == "function")
check("build ist eine Funktion", type(GarageWorldBuilder.build) == "function")
check("COUNT entspricht 15", GarageWorldBuilder.COUNT == 15, tostring(GarageWorldBuilder.COUNT))

local placements = GarageWorldBuilder.calculatePlacements()
local secondRun = GarageWorldBuilder.calculatePlacements()

-- Anzahl und Determinismus ----------------------------------------------

check("genau 15 Platzierungen", #placements == 15, string.format("gefunden: %d", #placements))
check("Layout liefert 15 Garagen", #WorldLayout.GARAGES == 15, string.format("gefunden: %d", #WorldLayout.GARAGES))

local deterministic = #placements == #secondRun
if deterministic then
	for index, placement in placements do
		local other = secondRun[index]
		if
			placement.id ~= other.id
			or placement.name ~= other.name
			or placement.anchorName ~= other.anchorName
			or placement.yaw ~= other.yaw
			or placement.angleDegrees ~= other.angleDegrees
			or placement.position.x ~= other.position.x
			or placement.position.y ~= other.position.y
			or placement.position.z ~= other.position.z
		then
			deterministic = false
			break
		end
	end
end
check("Platzierung ist deterministisch", deterministic)

-- Uebernahme aus WorldLayout.GARAGES -------------------------------------

local uniqueIds: { [string]: boolean } = {}
local uniqueNames: { [string]: boolean } = {}
local uniqueAnchors: { [string]: boolean } = {}
local uniqueIdCount = 0
local uniqueNameCount = 0
local uniqueAnchorCount = 0
local mappingErrors = 0
local heightErrors = 0
local boundsErrors = 0

for index, placement in placements do
	local anchor = WorldLayout.GARAGES[index]
	if
		placement.id ~= anchor.id
		or placement.name ~= anchor.name
		or math.abs(placement.position.x - anchor.position.x) > 1e-9
		or math.abs(placement.position.z - anchor.position.z) > 1e-9
		or math.abs(placement.yaw - anchor.yaw) > 1e-9
		or math.abs(placement.angleDegrees - anchor.angleDegrees) > 1e-9
	then
		mappingErrors += 1
	end

	local expectedHeight = TerrainHeight.heightAt(placement.position.x, placement.position.z)
	if math.abs(placement.position.y - expectedHeight) > 0.001 then
		heightErrors += 1
	end

	if
		placement.position.x < WorldLayout.BOUNDS.minX
		or placement.position.x > WorldLayout.BOUNDS.maxX
		or placement.position.z < WorldLayout.BOUNDS.minZ
		or placement.position.z > WorldLayout.BOUNDS.maxZ
	then
		boundsErrors += 1
	end

	if not uniqueIds[placement.id] then
		uniqueIds[placement.id] = true
		uniqueIdCount += 1
	end
	if not uniqueNames[placement.name] then
		uniqueNames[placement.name] = true
		uniqueNameCount += 1
	end
	if not uniqueAnchors[placement.anchorName] then
		uniqueAnchors[placement.anchorName] = true
		uniqueAnchorCount += 1
	end

	check(
		string.format("%s hat einen Anker-Namen", placement.id),
		type(placement.anchorName) == "string" and #placement.anchorName > 0
	)
	check(
		string.format("%s liegt auf einer Bauflaeche", placement.id),
		TerrainHeight.isBuildPad({ x = placement.position.x, y = placement.position.y, z = placement.position.z } :: any)
	)
end

check("Positionen und Winkel stammen aus WorldLayout", mappingErrors == 0, string.format("%d falsch", mappingErrors))
check("alle Garagen stehen auf Gelaendehoehe", heightErrors == 0, string.format("%d falsch", heightErrors))
check("alle Garagen liegen im Tal", boundsErrors == 0, string.format("%d falsch", boundsErrors))
check("15 eindeutige IDs", uniqueIdCount == 15, string.format("%d eindeutig", uniqueIdCount))
check("15 eindeutige Namen", uniqueNameCount == 15, string.format("%d eindeutig", uniqueNameCount))
check("15 eindeutige Anker", uniqueAnchorCount == 15, string.format("%d eindeutig", uniqueAnchorCount))

-- Gleicher Doenerabstand ------------------------------------------------

local doner = WorldLayout.DONER.position
local referenceDistance = distance2D(placements[1].position.x, placements[1].position.z, doner.x, doner.z)
local distanceErrors = 0

for _, placement in placements do
	local distance = distance2D(placement.position.x, placement.position.z, doner.x, doner.z)
	if math.abs(distance - referenceDistance) > 1e-6 then
		distanceErrors += 1
	end
end

check("alle Garagen haben denselben Doenerabstand", distanceErrors == 0, string.format("%d abweichend", distanceErrors))
check(
	"Garagen liegen ausserhalb des Doenerplatzes",
	referenceDistance > WorldLayout.DONER.radius,
	string.format("Abstand: %.2f", referenceDistance)
)

-- Mindestabstand zueinander ---------------------------------------------

local closestDistance = math.huge
for firstIndex = 1, #placements - 1 do
	for secondIndex = firstIndex + 1, #placements do
		local first = placements[firstIndex].position
		local second = placements[secondIndex].position
		closestDistance = math.min(closestDistance, distance2D(first.x, first.z, second.x, second.z))
	end
end

check("Garagen haben Mindestabstand zueinander", closestDistance >= 60, string.format("min: %.2f", closestDistance))
check(
	"Garagen ueberschneiden sich nicht",
	closestDistance >= WorldZones.GARAGE_RADIUS * 2,
	string.format("min: %.2f", closestDistance)
)

-- Keine Ueberschneidung mit Strassen, Wasser und Gebaeuden --------------

local roadConflicts = 0
local waterConflicts = 0
local buildingConflicts = 0
local donerConflicts = 0

for _, placement in placements do
	local x = placement.position.x
	local z = placement.position.z
	local point = { x = x, y = 0, z = z }

	if WorldZones.isRoad(point, WorldZones.GARAGE_RADIUS + WorldZones.MIN_CLEARANCE) then
		roadConflicts += 1
	end
	if waterNear(x, z, WorldZones.GARAGE_RADIUS + WorldZones.MIN_CLEARANCE) then
		waterConflicts += 1
	end

	if distance2D(x, z, doner.x, doner.z) <= WorldLayout.DONER.radius + WorldZones.GARAGE_RADIUS then
		donerConflicts += 1
	end

	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			if
				rectContains(
					x,
					z,
					slot.position,
					slot.footprint.x,
					slot.footprint.z,
					slot.yaw,
					WorldZones.GARAGE_RADIUS
				)
			then
				buildingConflicts += 1
			end
		end
	end

	local church = WorldLayout.CHURCH
	if
		rectContains(
			x,
			z,
			church.position,
			church.footprint.x,
			church.footprint.z,
			church.yaw,
			WorldZones.GARAGE_RADIUS
		)
	then
		buildingConflicts += 1
	end
end

check("keine Garage auf einer Strasse", roadConflicts == 0, string.format("%d Konflikte", roadConflicts))
check("keine Garage im Wasser", waterConflicts == 0, string.format("%d Konflikte", waterConflicts))
check("keine Garage in einem Gebaeude", buildingConflicts == 0, string.format("%d Konflikte", buildingConflicts))
check("keine Garage auf dem Doenerplatz", donerConflicts == 0, string.format("%d Konflikte", donerConflicts))

-- Layoutdaten unveraendert ------------------------------------------------

local firstGarageId = WorldLayout.GARAGES[1].id
local firstGarageX = WorldLayout.GARAGES[1].position.x
GarageWorldBuilder.calculatePlacements()
check("Layoutdaten unveraendert", WorldLayout.GARAGES[1].id == firstGarageId and WorldLayout.GARAGES[1].position.x == firstGarageX)

-- Zusammenfassung ---------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("GaragePlacement.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("GaragePlacement.spec: alle Checks bestanden")
