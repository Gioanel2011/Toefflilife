--!strict
-- WorldZones: reine, deterministische Zonendaten fuer das Toeffli-Tal.
-- Enthaelt zweispurige Hauptstrassen, Stopstrassen, Kreisel, genau einen See,
-- drei Bergbaeche mit Quelle und Muendung, alle Brueckenkreuzungen, Weiden und
-- Waelder. Keine Roblox-Instanzen, keine Terrain-Erzeugung, keine Gameplaylogik.
-- Alle Hoehen (y) sind hier 0; die Gelaendemodellierung folgt in TerrainHeight.

export type Position = { x: number, y: number, z: number }

export type RoadSegment = {
	id: string,
	name: string,
	kind: string, -- "ring" | "access" | "trunk" | "stop"
	from: Position,
	to: Position,
	width: number,
	lanes: number,
	laneWidth: number,
	hasCenterLine: boolean,
	stopLinePosition: Position?,
}

export type Roundabout = {
	id: string,
	name: string,
	center: Position,
	radius: number,
	roadIds: { string },
}

export type LakeZone = {
	id: string,
	name: string,
	kind: "lake",
	center: Position,
	radius: number,
}

export type StreamZone = {
	id: string,
	name: string,
	kind: "stream",
	width: number,
	source: Position,
	mouth: Position,
	points: { Position },
}

export type WaterCourse = LakeZone | StreamZone

export type BridgeCrossing = {
	id: string,
	name: string,
	roadId: string,
	waterId: string,
	position: Position,
	yaw: number,
	length: number,
	width: number,
}

export type PastureZone = {
	id: string,
	name: string,
	kind: string, -- "pasture"
	center: Position,
	size: { x: number, z: number },
	yaw: number,
}

export type ForestZone = {
	id: string,
	name: string,
	kind: string, -- "forest"
	center: Position,
	radius: number,
}

-- Roblox- und Lune-taugliche Modulaufloesung (Relativpfad bzw. Script-Parent).
local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")

local WorldZones = {}

-- Abmessungen und Mindestabstaende -------------------------------------

-- Radius der Ringstrasse um den Doenerplatz.
WorldZones.RING_RADIUS = 240
-- Breite einer zweispurigen Hauptstrasse (Studs).
WorldZones.MAIN_ROAD_WIDTH = 16
-- Breite einer Stopstrasse bzw. Dorfzufahrt (Studs).
WorldZones.STOP_ROAD_WIDTH = 12
-- Aussenradius eines Kreisels (Studs).
WorldZones.ROUNDABOUT_RADIUS = 16
-- Angenommener Ankerradius einer Garage (Studs); groessere Garagen sind
-- unzulaessig, sonst kollidieren sie mit Ringstrasse und Kreiseln.
WorldZones.GARAGE_RADIUS = 12
-- Mindestabstand zwischen Zonen und Garagen, Gebaeuden bzw. Doerfern.
WorldZones.MIN_CLEARANCE = 8

local RING_RADIUS = WorldZones.RING_RADIUS
local RING_SEGMENT_COUNT = 16
local MAIN_ROAD_WIDTH = WorldZones.MAIN_ROAD_WIDTH
local STOP_ROAD_WIDTH = WorldZones.STOP_ROAD_WIDTH
local ROUNDABOUT_RADIUS = WorldZones.ROUNDABOUT_RADIUS
local GARAGE_RADIUS = WorldZones.GARAGE_RADIUS
local BRIDGE_OVERHANG = 10

WorldZones.SEED = WorldLayout.SEED
WorldZones.BOUNDS = WorldLayout.BOUNDS

-- Geometrie-Helfer (nur 2D: x/z) ---------------------------------------

local function position(x: number, z: number): Position
	return { x = x, y = 0, z = z }
end

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function distanceToSegment(point: Position, a: Position, b: Position): number
	local dx = b.x - a.x
	local dz = b.z - a.z
	local lengthSquared = dx * dx + dz * dz
	if lengthSquared == 0 then
		return distance2D(point.x, point.z, a.x, a.z)
	end
	local t = math.clamp(((point.x - a.x) * dx + (point.z - a.z) * dz) / lengthSquared, 0, 1)
	return distance2D(point.x, point.z, a.x + dx * t, a.z + dz * t)
end

local function segmentIntersection(a: Position, b: Position, c: Position, d: Position): number?
	local rx = b.x - a.x
	local rz = b.z - a.z
	local sx = d.x - c.x
	local sz = d.z - c.z
	local denominator = rx * sz - rz * sx
	if math.abs(denominator) < 1e-9 then
		return nil
	end
	local qpx = c.x - a.x
	local qpz = c.z - a.z
	local t = (qpx * sz - qpz * sx) / denominator
	local u = (qpx * rz - qpz * rx) / denominator
	if t < 0 or t > 1 or u < 0 or u > 1 then
		return nil
	end
	return t
end

-- Punkt in einem gedrehten Rechteck (yaw um die Y-Achse in Grad).
local function rectContains(
	point: Position,
	center: Position,
	sizeX: number,
	sizeZ: number,
	yawDegrees: number,
	margin: number
): boolean
	local yaw = math.rad(yawDegrees)
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	local dx = point.x - center.x
	local dz = point.z - center.z
	local localX = dx * cosYaw + dz * sinYaw
	local localZ = -dx * sinYaw + dz * cosYaw
	return math.abs(localX) <= sizeX / 2 + margin and math.abs(localZ) <= sizeZ / 2 + margin
end

-- Hauptstrassen --------------------------------------------------------

local roadSegments: { RoadSegment } = {}

-- Ringstrasse: 16 Segmente, zweispurig, mit durchgehendem Mittelstreifen.
for index = 1, RING_SEGMENT_COUNT do
	local startAngle = math.rad((index - 1) * 360 / RING_SEGMENT_COUNT)
	local endAngle = math.rad(index * 360 / RING_SEGMENT_COUNT)
	table.insert(roadSegments, {
		id = string.format("Road_Ring_%02d", index),
		name = string.format("Ringstrasse %02d", index),
		kind = "ring",
		from = position(math.cos(startAngle) * RING_RADIUS, math.sin(startAngle) * RING_RADIUS),
		to = position(math.cos(endAngle) * RING_RADIUS, math.sin(endAngle) * RING_RADIUS),
		width = MAIN_ROAD_WIDTH,
		lanes = 2,
		laneWidth = MAIN_ROAD_WIDTH / 2,
		hasCenterLine = true,
	})
end

-- Doenerplatzzufahrt: laeuft genau zwischen zwei benachbarten Garagen
-- hindurch (Mittelwinkel), damit keine Garage angefahren wird.
local garages = WorldLayout.GARAGES
local accessAngleDegrees = 270
if #garages >= 2 then
	accessAngleDegrees = (garages[1].angleDegrees + garages[2].angleDegrees) / 2
end
local accessAngle = math.rad(accessAngleDegrees)
local accessDirectionX = math.cos(accessAngle)
local accessDirectionZ = math.sin(accessAngle)

table.insert(roadSegments, {
	id = "Road_DonerAccess",
	name = "Doenerplatz-Zufahrt",
	kind = "access",
	from = position(accessDirectionX * (RING_RADIUS - 8), accessDirectionZ * (RING_RADIUS - 8)),
	to = position(accessDirectionX * WorldLayout.DONER.radius, accessDirectionZ * WorldLayout.DONER.radius),
	width = MAIN_ROAD_WIDTH,
	lanes = 2,
	laneWidth = MAIN_ROAD_WIDTH / 2,
	hasCenterLine = true,
})

-- Seestrasse: vom Ring nach Suedosten, quert genau einen Bergbach.
local trunkAngle = math.rad(315)
table.insert(roadSegments, {
	id = "Road_Seestrasse",
	name = "Seestrasse",
	kind = "trunk",
	from = position(math.cos(trunkAngle) * RING_RADIUS, math.sin(trunkAngle) * RING_RADIUS),
	to = position(500, -430),
	width = MAIN_ROAD_WIDTH,
	lanes = 2,
	laneWidth = MAIN_ROAD_WIDTH / 2,
	hasCenterLine = true,
})

WorldZones.ROAD_SEGMENTS = roadSegments

-- Stopstrassen: Dorfzufahrten, die mit Haltelinie in den Ring muenden.
local stopRoads: { RoadSegment } = {}

for _, village in WorldLayout.VILLAGES do
	local center = village.center
	local centerDistance = distance2D(center.x, center.z, 0, 0)
	local directionX = center.x / centerDistance
	local directionZ = center.z / centerDistance
	local from = position(directionX * RING_RADIUS, directionZ * RING_RADIUS)
	local toRadius = centerDistance - village.radius
	local to = position(directionX * toRadius, directionZ * toRadius)

	table.insert(stopRoads, {
		id = string.format("StopRoad_%s", village.id),
		name = string.format("Dorfzufahrt %s", village.name),
		kind = "stop",
		from = from,
		to = to,
		width = STOP_ROAD_WIDTH,
		lanes = 1,
		laneWidth = STOP_ROAD_WIDTH,
		hasCenterLine = false,
		stopLinePosition = position(
			from.x + (to.x - from.x) * 0.15,
			from.z + (to.z - from.z) * 0.15
		),
	})
end

WorldZones.STOP_ROADS = stopRoads

-- Kreisel --------------------------------------------------------------

local roundabouts: { Roundabout } = {}

local function addRoundabout(id: string, name: string, angleDegrees: number, extraRoadId: string)
	local angle = math.rad(angleDegrees)
	local normalized = angleDegrees % 360
	local segmentIndex = math.floor(normalized / (360 / RING_SEGMENT_COUNT)) + 1
	local previousIndex = ((segmentIndex - 2) % RING_SEGMENT_COUNT) + 1

	table.insert(roundabouts, {
		id = id,
		name = name,
		center = position(math.cos(angle) * RING_RADIUS, math.sin(angle) * RING_RADIUS),
		radius = ROUNDABOUT_RADIUS,
		roadIds = {
			string.format("Road_Ring_%02d", previousIndex),
			string.format("Road_Ring_%02d", segmentIndex),
			extraRoadId,
		},
	})
end

addRoundabout("Roundabout_Donerplatz", "Kreisel Doenerplatz", accessAngleDegrees, "Road_DonerAccess")

for _, village in WorldLayout.VILLAGES do
	local center = village.center
	local angleDegrees = math.deg(math.atan2(center.z, center.x))
	addRoundabout(
		string.format("Roundabout_%s", village.id),
		string.format("Kreisel %s", village.name),
		angleDegrees,
		string.format("StopRoad_%s", village.id)
	)
end

WorldZones.ROUNDABOUTS = roundabouts

-- Gewaesser ------------------------------------------------------------

local lake: LakeZone = {
	id = "Lake_Toefflisee",
	name = "Toefflisee",
	kind = "lake",
	center = position(0, -480),
	radius = 80,
}

-- Muendungspunkt exakt auf dem Seeufer in Richtung der jeweiligen Quelle.
local function lakeShoreTowards(source: Position): Position
	local dx = source.x - lake.center.x
	local dz = source.z - lake.center.z
	local length = math.sqrt(dx * dx + dz * dz)
	return position(lake.center.x + (dx / length) * lake.radius, lake.center.z + (dz / length) * lake.radius)
end

local streamSources: { { id: string, name: string, width: number, source: Position, bend: { Position } } } = {
	{
		id = "Stream_West",
		name = "Westbach",
		width = 14,
		source = position(-560, -520),
		bend = { position(-400, -505), position(-220, -520) },
	},
	{
		id = "Stream_East",
		name = "Ostbach",
		width = 14,
		source = position(560, -520),
		bend = { position(380, -540), position(200, -525) },
	},
	{
		id = "Stream_Northeast",
		name = "Nordostbach",
		width = 14,
		source = position(560, -240),
		bend = { position(430, -310), position(280, -350), position(150, -395) },
	},
}

local streams: { StreamZone } = {}

for _, plan in streamSources do
	local mouth = lakeShoreTowards(plan.source)
	local points: { Position } = { plan.source }
	for _, point in plan.bend do
		table.insert(points, point)
	end
	table.insert(points, mouth)

	table.insert(streams, {
		id = plan.id,
		name = plan.name,
		kind = "stream",
		width = plan.width,
		source = plan.source,
		mouth = mouth,
		points = points,
	})
end

WorldZones.LAKE = lake
WorldZones.STREAMS = streams
WorldZones.WATER_COURSES = { lake, streams[1], streams[2], streams[3] }

-- Brueckenkreuzungen: jede Ueberschneidung Strasse x Bach wird ermittelt.

local allRoads: { RoadSegment } = {}
for _, road in roadSegments do
	table.insert(allRoads, road)
end
for _, road in stopRoads do
	table.insert(allRoads, road)
end

local bridgeCrossings: { BridgeCrossing } = {}

for _, road in allRoads do
	for _, course in WorldZones.WATER_COURSES do
		if course.kind == "stream" then
			for index = 1, #course.points - 1 do
				local t = segmentIntersection(road.from, road.to, course.points[index], course.points[index + 1])
				if t then
					local crossing = position(
						road.from.x + (road.to.x - road.from.x) * t,
						road.from.z + (road.to.z - road.from.z) * t
					)
					table.insert(bridgeCrossings, {
						id = string.format("Bridge_%02d", #bridgeCrossings + 1),
						name = string.format("Bruecke %s", road.name),
						roadId = road.id,
						waterId = course.id,
						position = crossing,
						yaw = math.deg(math.atan2(
							-(road.to.x - road.from.x),
							-(road.to.z - road.from.z)
						)),
						length = course.width + BRIDGE_OVERHANG * 2,
						width = road.width + 2,
					})
				end
			end
		end
	end
end

WorldZones.BRIDGE_CROSSINGS = bridgeCrossings

-- Weiden und Waelder (ausserhalb von Ring, Doerfern und Gewaessern) -----

WorldZones.PASTURES = {
	{
		id = "Pasture_Nordwest",
		name = "Weide Nordwest",
		kind = "pasture",
		center = position(-520, 250),
		size = { x = 100, z = 70 },
		yaw = 0,
	},
	{
		id = "Pasture_Ost",
		name = "Weide Ost",
		kind = "pasture",
		center = position(310, 110),
		size = { x = 110, z = 80 },
		yaw = 12,
	},
	{
		id = "Pasture_Sued",
		name = "Weide Sued",
		kind = "pasture",
		center = position(-150, 470),
		size = { x = 120, z = 70 },
		yaw = -8,
	},
}

WorldZones.FORESTS = {
	{
		id = "Forest_West",
		name = "Wald West",
		kind = "forest",
		center = position(-420, 60),
		radius = 90,
	},
	{
		id = "Forest_Ost",
		name = "Wald Ost",
		kind = "forest",
		center = position(450, -80),
		radius = 85,
	},
	{
		id = "Forest_See",
		name = "Wald am See",
		kind = "forest",
		center = position(60, -320),
		radius = 60,
	},
	{
		id = "Forest_Sued",
		name = "Wald Sued",
		kind = "forest",
		center = position(-360, 380),
		radius = 80,
	},
}

-- Abfragen -------------------------------------------------------------

local function waterContains(point: Position, margin: number): boolean
	for _, course in WorldZones.WATER_COURSES do
		if course.kind == "lake" then
			if distance2D(point.x, point.z, course.center.x, course.center.z) <= course.radius + margin then
				return true
			end
		else
			for index = 1, #course.points - 1 do
				local distance = distanceToSegment(point, course.points[index], course.points[index + 1])
				if distance <= course.width / 2 + margin then
					return true
				end
			end
		end
	end
	return false
end

function WorldZones.containsWater(point: Position): boolean
	return waterContains(point, 0)
end

function WorldZones.isRoad(point: Position, margin: number?): boolean
	local required = margin or 0
	for _, road in allRoads do
		if distanceToSegment(point, road.from, road.to) <= road.width / 2 + required then
			return true
		end
	end
	for _, roundabout in WorldZones.ROUNDABOUTS do
		if distance2D(point.x, point.z, roundabout.center.x, roundabout.center.z) <= roundabout.radius + required then
			return true
		end
	end
	return false
end

function WorldZones.isReserved(point: Position, margin: number?): boolean
	local required = margin or 0

	if WorldZones.isRoad(point, required) then
		return true
	end
	if waterContains(point, required) then
		return true
	end

	for _, pasture in WorldZones.PASTURES do
		if rectContains(point, pasture.center, pasture.size.x, pasture.size.z, pasture.yaw, required) then
			return true
		end
	end

	for _, forest in WorldZones.FORESTS do
		if distance2D(point.x, point.z, forest.center.x, forest.center.z) <= forest.radius + required then
			return true
		end
	end

	for _, garage in WorldLayout.GARAGES do
		if distance2D(point.x, point.z, garage.position.x, garage.position.z) <= GARAGE_RADIUS + required then
			return true
		end
	end

	local doner = WorldLayout.DONER
	if distance2D(point.x, point.z, doner.position.x, doner.position.z) <= doner.radius + required then
		return true
	end

	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			if rectContains(point, slot.position, slot.footprint.x, slot.footprint.z, slot.yaw, required) then
				return true
			end
		end
	end

	local church = WorldLayout.CHURCH
	return rectContains(point, church.position, church.footprint.x, church.footprint.z, church.yaw, required)
end

return WorldZones
