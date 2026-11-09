--!strict
-- WorldZones.spec: prueft die reinen Zonendaten auf Konsistenz.
-- Lauf: lune run tests/WorldZones.spec.luau
-- Geprueft werden: ein See, drei Bergbaeche mit Quelle und Muendung,
-- Bruecken nur auf Strassen-Wasser-Kreuzungen, keine Zonenueberschneidung an
-- Pflichtflaechen sowie Mindestabstaende zu Garagen, Gebaeuden und Doerfern.

local WorldZones = require("../src/server/world/WorldZones")
local WorldLayout = require("../src/server/world/WorldLayout")

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

local function rectContains(px: number, pz: number, center, size, yawDegrees: number, margin: number): boolean
	local localX, localZ = toRectLocal(px, pz, center, yawDegrees)
	return math.abs(localX) <= size.x / 2 + margin and math.abs(localZ) <= size.z / 2 + margin
end

local function distanceToRect(px: number, pz: number, center, size, yawDegrees: number): number
	local localX, localZ = toRectLocal(px, pz, center, yawDegrees)
	local clampedX = math.clamp(localX, -size.x / 2, size.x / 2)
	local clampedZ = math.clamp(localZ, -size.z / 2, size.z / 2)
	return math.sqrt((localX - clampedX) ^ 2 + (localZ - clampedZ) ^ 2)
end

-- Abstand zur Wasserflaeche; 0 bedeutet im Wasser.
local function distanceToWater(px: number, pz: number): number
	local best = math.huge
	for _, course in WorldZones.WATER_COURSES do
		if course.kind == "lake" then
			local centerDistance = distance2D(px, pz, course.center.x, course.center.z)
			best = math.min(best, math.max(0, centerDistance - course.radius))
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

local allRoads = {}
for _, road in WorldZones.ROAD_SEGMENTS do
	table.insert(allRoads, road)
end
for _, road in WorldZones.STOP_ROADS do
	table.insert(allRoads, road)
end

local function findRoad(id: string)
	for _, road in allRoads do
		if road.id == id then
			return road
		end
	end
	return nil
end

local function findWater(id: string)
	for _, course in WorldZones.WATER_COURSES do
		if course.id == id then
			return course
		end
	end
	return nil
end

-- Gewaesser ------------------------------------------------------------

local streams = {}
local lakes = {}
for _, course in WorldZones.WATER_COURSES do
	if course.kind == "stream" then
		table.insert(streams, course)
	else
		table.insert(lakes, course)
	end
end

check("genau ein See", #lakes == 1, string.format("gefunden: %d", #lakes))
check("genau drei Bergbaeche", #streams == 3, string.format("gefunden: %d", #streams))

local lake = lakes[1]
if lake then
	check("See liegt im Tal", WorldLayout.isInsideBounds(lake.center))
	check("See hat endlichen Radius", lake.radius > 0 and lake.radius < 200)
end

for _, stream in streams do
	check(string.format("%s hat Quelle, Muendung und Verlauf", stream.id), stream.source ~= nil
		and stream.mouth ~= nil
		and #stream.points >= 2)
	if not lake then
		break
	end
	local first = stream.points[1]
	local last = stream.points[#stream.points]
	check(
		string.format("%s beginnt an der Quelle", stream.id),
		distance2D(first.x, first.z, stream.source.x, stream.source.z) < 0.01
	)
	check(
		string.format("%s endet an der Muendung", stream.id),
		distance2D(last.x, last.z, stream.mouth.x, stream.mouth.z) < 0.01
	)
	local mouthDistance = distance2D(stream.mouth.x, stream.mouth.z, lake.center.x, lake.center.z)
	check(
		string.format("%s muendet in den See", stream.id),
		math.abs(mouthDistance - lake.radius) <= 1,
		string.format("Uferabstand: %.2f", mouthDistance - lake.radius)
	)
	local sourceDistance = distance2D(stream.source.x, stream.source.z, lake.center.x, lake.center.z)
	check(
		string.format("%s entspringt im Gebirge", stream.id),
		sourceDistance >= lake.radius + 200,
		string.format("Quellabstand: %.2f", sourceDistance)
	)
	for index = 1, #stream.points - 1 do
		local a = stream.points[index]
		local b = stream.points[index + 1]
		check(
			string.format("%s Segment %d ist zusammenhaengend", stream.id, index),
			distance2D(a.x, a.z, b.x, b.z) > 1
		)
	end
end

-- Strassen -------------------------------------------------------------

local ringRoads = {}
for _, road in WorldZones.ROAD_SEGMENTS do
	if road.kind == "ring" then
		table.insert(ringRoads, road)
	end
end

check("16 Ringsegmente", #ringRoads == 16, string.format("gefunden: %d", #ringRoads))

for _, road in WorldZones.ROAD_SEGMENTS do
	check(
		string.format("%s ist zweispurig", road.id),
		road.lanes == 2 and road.hasCenterLine == true and math.abs(road.width - road.lanes * road.laneWidth) < 1e-6
	)
	check(string.format("%s hat eine Laenge", road.id), distance2D(road.from.x, road.from.z, road.to.x, road.to.z) > 1)
end

check(
	"zwei Dorfzufahrten",
	#WorldZones.STOP_ROADS == #WorldLayout.VILLAGES,
	string.format("gefunden: %d", #WorldZones.STOP_ROADS)
)

for _, road in WorldZones.STOP_ROADS do
	local stopLine = road.stopLinePosition
	check(string.format("%s hat eine Haltelinie", road.id), stopLine ~= nil)
	check(string.format("%s ist einspurig", road.id), road.lanes == 1 and road.hasCenterLine == false)
	if stopLine then
		check(
			string.format("%s Haltelinie liegt auf der Stopstrasse", road.id),
			distanceToSegment(stopLine.x, stopLine.z, road.from.x, road.from.z, road.to.x, road.to.z) <= 1
		)
	end
	local ringDistance = math.huge
	for _, ringRoad in ringRoads do
		ringDistance = math.min(
			ringDistance,
			distanceToSegment(road.from.x, road.from.z, ringRoad.from.x, ringRoad.from.z, ringRoad.to.x, ringRoad.to.z)
		)
	end
	check(
		string.format("%s beginnt am Ring", road.id),
		ringDistance <= 5,
		string.format("Abstand: %.2f", ringDistance)
	)
end

for _, roundabout in WorldZones.ROUNDABOUTS do
	check(
		string.format("%s ist angebunden", roundabout.id),
		#roundabout.roadIds >= 2 and roundabout.radius > 0
	)
	check(string.format("%s liegt im Tal", roundabout.id), WorldLayout.isInsideBounds(roundabout.center))
	for _, roadId in roundabout.roadIds do
		check(string.format("%s verweist auf %s", roundabout.id, roadId), findRoad(roadId) ~= nil)
	end
end

check("mindestens ein Kreisel", #WorldZones.ROUNDABOUTS >= 1)

-- Talgrenzen -----------------------------------------------------------

local function checkInside(name: string, x: number, z: number)
	check(name, WorldLayout.isInsideBounds({ x = x, y = 0, z = z }), string.format("x=%.1f z=%.1f", x, z))
end

for _, road in allRoads do
	checkInside(string.format("%s Start liegt im Tal", road.id), road.from.x, road.from.z)
	checkInside(string.format("%s Ende liegt im Tal", road.id), road.to.x, road.to.z)
end

for _, roundabout in WorldZones.ROUNDABOUTS do
	checkInside(
		string.format("%s Rand liegt im Tal", roundabout.id),
		roundabout.center.x + roundabout.radius,
		roundabout.center.z + roundabout.radius
	)
end

for _, course in WorldZones.WATER_COURSES do
	if course.kind == "lake" then
		checkInside(string.format("%s liegt im Tal", course.id), course.center.x, course.center.z + course.radius)
	else
		for index, point in course.points do
			checkInside(string.format("%s Punkt %d liegt im Tal", course.id, index), point.x, point.z)
		end
	end
end

for _, pasture in WorldZones.PASTURES do
	local yaw = math.rad(pasture.yaw)
	local halfX = pasture.size.x / 2
	local halfZ = pasture.size.z / 2
	for _, corner in {
		{ x = halfX, z = halfZ },
		{ x = -halfX, z = halfZ },
		{ x = halfX, z = -halfZ },
		{ x = -halfX, z = -halfZ },
	} do
		local worldX = pasture.center.x + corner.x * math.cos(yaw) - corner.z * math.sin(yaw)
		local worldZ = pasture.center.z + corner.x * math.sin(yaw) + corner.z * math.cos(yaw)
		checkInside(string.format("%s Ecke liegt im Tal", pasture.id), worldX, worldZ)
	end
end

for _, forest in WorldZones.FORESTS do
	checkInside(
		string.format("%s Rand liegt im Tal", forest.id),
		forest.center.x + forest.radius,
		forest.center.z + forest.radius
	)
end

-- Bruecken -------------------------------------------------------------

check("mindestens eine Bruecke", #WorldZones.BRIDGE_CROSSINGS >= 1)

for _, bridge in WorldZones.BRIDGE_CROSSINGS do
	local road = findRoad(bridge.roadId)
	local water = findWater(bridge.waterId)

	check(string.format("%s verweist auf eine Strasse", bridge.id), road ~= nil)
	check(string.format("%s verweist auf ein Gewaesser", bridge.id), water ~= nil)
	check(string.format("%s liegt auf der Strasse", bridge.id), WorldZones.isRoad(bridge.position, 1))
	check(string.format("%s liegt ueber Wasser", bridge.id), WorldZones.containsWater(bridge.position))
	check(
		string.format("%s ist an der Kreuzung zentriert", bridge.id),
		distanceToWater(bridge.position.x, bridge.position.z) <= 1
	)
	check(
		string.format("%s deckt die Fahrbahnbreite ab", bridge.id),
		road ~= nil and bridge.width >= road.width
	)

	if road then
		check(
			string.format("%s liegt auf der Fahrbahnmitte", bridge.id),
			distanceToSegment(
				bridge.position.x,
				bridge.position.z,
				road.from.x,
				road.from.z,
				road.to.x,
				road.to.z
			) <= 1
		)
	end
end

-- Keine Strasse darf Wasser ausserhalb einer Bruecke queren.
for _, road in allRoads do
	local roadLength = distance2D(road.from.x, road.from.z, road.to.x, road.to.z)
	local steps = math.max(1, math.ceil(roadLength / 2))
	local uncovered = 0

	for step = 0, steps do
		local t = step / steps
		local x = road.from.x + (road.to.x - road.from.x) * t
		local z = road.from.z + (road.to.z - road.from.z) * t
		if WorldZones.containsWater({ x = x, y = 0, z = z }) then
			local covered = false
			for _, bridge in WorldZones.BRIDGE_CROSSINGS do
				if
					bridge.roadId == road.id
					and distance2D(x, z, bridge.position.x, bridge.position.z) <= bridge.length / 2 + 2
				then
					covered = true
					break
				end
			end
			if not covered then
				uncovered += 1
			end
		end
	end

	check(
		string.format("%s quert Wasser nur auf Bruecken", road.id),
		uncovered == 0,
		string.format("%d ungedeckte Punkte", uncovered)
	)
end

-- Mindestabstaende zu Garagen, Gebaeuden und Doerfern ------------------

local requiredGarageClearance = WorldZones.GARAGE_RADIUS + WorldZones.MIN_CLEARANCE

for _, garage in WorldLayout.GARAGES do
	local clearance = math.huge
	for _, road in allRoads do
		clearance = math.min(
			clearance,
			distanceToSegment(
				garage.position.x,
				garage.position.z,
				road.from.x,
				road.from.z,
				road.to.x,
				road.to.z
			) - road.width / 2
		)
	end
	for _, roundabout in WorldZones.ROUNDABOUTS do
		clearance = math.min(
			clearance,
			distance2D(
				garage.position.x,
				garage.position.z,
				roundabout.center.x,
				roundabout.center.z
			) - roundabout.radius
		)
	end

	check(
		string.format("%s haelt Strassenabstand", garage.id),
		clearance >= requiredGarageClearance,
		string.format("%.2f < %.2f", clearance, requiredGarageClearance)
	)
	check(
		string.format("%s steht nicht im Wasser", garage.id),
		WorldZones.containsWater(garage.position) == false
	)

	local blocked = false
	for _, forest in WorldZones.FORESTS do
		if distance2D(garage.position.x, garage.position.z, forest.center.x, forest.center.z)
			< forest.radius + WorldZones.GARAGE_RADIUS
		then
			blocked = true
		end
	end
	for _, pasture in WorldZones.PASTURES do
		if distanceToRect(garage.position.x, garage.position.z, pasture.center, pasture.size, pasture.yaw)
			< WorldZones.GARAGE_RADIUS
		then
			blocked = true
		end
	end
	check(string.format("%s steht frei", garage.id), blocked == false)
end

for _, village in WorldLayout.VILLAGES do
	for _, slot in village.slots do
		local halfDiagonal = math.sqrt((slot.footprint.x / 2) ^ 2 + (slot.footprint.z / 2) ^ 2)
		local clearance = math.huge
		for _, road in allRoads do
			clearance = math.min(
				clearance,
				distanceToSegment(
					slot.position.x,
					slot.position.z,
					road.from.x,
					road.from.z,
					road.to.x,
					road.to.z
				) - road.width / 2
			)
		end
		for _, roundabout in WorldZones.ROUNDABOUTS do
			clearance = math.min(
				clearance,
				distance2D(slot.position.x, slot.position.z, roundabout.center.x, roundabout.center.z)
					- roundabout.radius
			)
		end

		check(
			string.format("%s haelt Strassenabstand", slot.id),
			clearance >= halfDiagonal + 4,
			string.format("%.2f < %.2f", clearance, halfDiagonal + 4)
		)
		check(
			string.format("%s steht nicht im Wasser", slot.id),
			WorldZones.containsWater(slot.position) == false
		)
	end
end

local church = WorldLayout.CHURCH
local churchClearance = math.huge
for _, road in allRoads do
	churchClearance = math.min(
		churchClearance,
		distanceToSegment(
			church.position.x,
			church.position.z,
			road.from.x,
			road.from.z,
			road.to.x,
			road.to.z
		) - road.width / 2
	)
end
check(
	"Kirche haelt Strassenabstand",
	churchClearance >= math.max(church.footprint.x, church.footprint.z) / 2 + 4,
	string.format("%.2f", churchClearance)
)

-- Doenerplatz ----------------------------------------------------------

local doner = WorldLayout.DONER
local donerAccess = findRoad("Road_DonerAccess")
check("Doenerplatzzufahrt existiert", donerAccess ~= nil)

if donerAccess then
	local donerDistance = distanceToSegment(
		doner.position.x,
		doner.position.z,
		donerAccess.from.x,
		donerAccess.from.z,
		donerAccess.to.x,
		donerAccess.to.z
	)
	check(
		"Doenerplatz ist angebunden",
		math.abs(donerDistance - doner.radius) <= 0.5,
		string.format("Abstand: %.2f", donerDistance)
	)

	local accessAngle = math.deg(math.atan2(
		donerAccess.from.z - donerAccess.to.z,
		donerAccess.from.x - donerAccess.to.x
	)) % 360
	local garageAngles = WorldLayout.GARAGES
	if #garageAngles >= 2 then
		local expected = ((garageAngles[1].angleDegrees + garageAngles[2].angleDegrees) / 2) % 360
		local difference = math.abs(((accessAngle - expected + 180) % 360) - 180)
		check(
			"Zufahrt fuehrt zwischen zwei Garagen",
			difference <= 0.01,
			string.format("Abweichung: %.3f", difference)
		)
	end
end

check(
	"Doenerplatz bleibt frei von Wasser",
	WorldZones.containsWater(doner.position) == false and distanceToWater(doner.position.x, doner.position.z) >= 4
)

-- Weiden und Waelder ---------------------------------------------------

for _, pasture in WorldZones.PASTURES do
	check(
		string.format("%s liegt nicht im Wasser", pasture.id),
		WorldZones.containsWater(pasture.center) == false
	)
	check(
		string.format("%s haelt Wasserabstand", pasture.id),
		distanceToWater(pasture.center.x, pasture.center.z) >= 4
	)
	for _, forest in WorldZones.FORESTS do
		local gap = distanceToRect(forest.center.x, forest.center.z, pasture.center, pasture.size, pasture.yaw)
			- forest.radius
		check(
			string.format("%s ueberschneidet %s nicht", pasture.id, forest.id),
			gap >= 4,
			string.format("Abstand: %.2f", gap)
		)
	end
	local garageInside = false
	for _, garage in WorldLayout.GARAGES do
		if
			rectContains(
				garage.position.x,
				garage.position.z,
				pasture.center,
				pasture.size,
				pasture.yaw,
				WorldZones.GARAGE_RADIUS
			)
		then
			garageInside = true
		end
	end
	check(string.format("%s enthaelt keine Garage", pasture.id), garageInside == false)
end

for _, forest in WorldZones.FORESTS do
	check(
		string.format("%s liegt nicht im Wasser", forest.id),
		WorldZones.containsWater(forest.center) == false
	)
	check(
		string.format("%s haelt Wasserabstand", forest.id),
		distanceToWater(forest.center.x, forest.center.z) >= forest.radius + 4,
		string.format("%.2f", distanceToWater(forest.center.x, forest.center.z))
	)
	local garageInside = false
	for _, garage in WorldLayout.GARAGES do
		if
			distance2D(garage.position.x, garage.position.z, forest.center.x, forest.center.z)
			< forest.radius + WorldZones.GARAGE_RADIUS
		then
			garageInside = true
		end
	end
	check(string.format("%s enthaelt keine Garage", forest.id), garageInside == false)

	local villageGap = math.huge
	for _, village in WorldLayout.VILLAGES do
		villageGap = math.min(
			villageGap,
			distance2D(forest.center.x, forest.center.z, village.center.x, village.center.z)
				- village.radius
				- forest.radius
		)
	end
	check(
		string.format("%s haelt Dorfabstand", forest.id),
		villageGap >= WorldZones.MIN_CLEARANCE,
		string.format("Abstand: %.2f", villageGap)
	)
end

-- Strassen halten Abstand zu Weiden und Waeldern.

for _, road in allRoads do
	local roadLength = distance2D(road.from.x, road.from.z, road.to.x, road.to.z)
	local steps = math.max(1, math.ceil(roadLength / 4))
	local pastureGap = math.huge
	local forestGap = math.huge

	for step = 0, steps do
		local t = step / steps
		local x = road.from.x + (road.to.x - road.from.x) * t
		local z = road.from.z + (road.to.z - road.from.z) * t
		for _, pasture in WorldZones.PASTURES do
			pastureGap = math.min(pastureGap, distanceToRect(x, z, pasture.center, pasture.size, pasture.yaw))
		end
		for _, forest in WorldZones.FORESTS do
			forestGap = math.min(forestGap, distance2D(x, z, forest.center.x, forest.center.z) - forest.radius)
		end
	end

	check(
		string.format("%s beruehrt keine Weide", road.id),
		pastureGap >= road.width / 2 + 4,
		string.format("Abstand: %.2f", pastureGap)
	)
	check(
		string.format("%s beruehrt keinen Wald", road.id),
		forestGap >= road.width / 2 + 4,
		string.format("Abstand: %.2f", forestGap)
	)
end

-- Abfrage-API ----------------------------------------------------------

check("isRoad erkennt den Ring", WorldZones.isRoad({ x = 240, y = 0, z = 0 }))
check("isRoad lehnt den Doenerplatz ab", WorldZones.isRoad(doner.position) == false)
check(
	"isRoad respektiert den Rand",
	WorldZones.isRoad({ x = 260, y = 0, z = 0 }) == false
		and WorldZones.isRoad({ x = 260, y = 0, z = 0 }, 20) == true
)

check("containsWater erkennt den See", WorldZones.containsWater(lake.center))
check("containsWater lehnt den Doenerplatz ab", WorldZones.containsWater(doner.position) == false)
check("containsWater erkennt einen Bach", WorldZones.containsWater(streams[1].source))

local freePoint = { x = -520, y = 0, z = -300 }
check("freier Punkt ist nicht reserviert", WorldZones.isReserved(freePoint) == false)
check("Doenerplatz ist reserviert", WorldZones.isReserved(doner.position) == true)
check("Garage ist reserviert", WorldZones.isReserved(WorldLayout.GARAGES[1].position) == true)

local churchReserved = WorldZones.isReserved({ x = church.position.x, y = 0, z = church.position.z })
check("Kirche ist reserviert", churchReserved == true)

for _, forest in WorldZones.FORESTS do
	check(string.format("%s ist reserviert", forest.id), WorldZones.isReserved(forest.center) == true)
end

for _, bridge in WorldZones.BRIDGE_CROSSINGS do
	check(string.format("%s ist reserviert", bridge.id), WorldZones.isReserved(bridge.position) == true)
end

-- Zusammenfassung ------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("WorldZones.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("WorldZones.spec: alle Checks bestanden")
