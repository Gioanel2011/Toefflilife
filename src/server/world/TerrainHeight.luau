--!strict
-- TerrainHeight: sanftes, deterministisches Hoehenmodell fuer das Toeffli-Tal.
-- Reine Mathematik ohne Roblox-Instanzen. Berge an den Raendern liefern die
-- Wasserquellen, Tal, Seeufer und Brueckenauffahrten bleiben flach.
-- Strassen-, Dorf-, Doener- und Garagenflaechen werden auf eine gemeinsame
-- lokale Hoehe abgeflacht. Keine Bodenmaterialien, kein Sand und keine
-- Mutation der Layoutdaten.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local WorldZones = requireSibling("WorldZones")

local TerrainHeight = {}

TerrainHeight.SEED = WorldLayout.SEED

-- Konstanten -------------------------------------------------------------

local MOUNTAIN_HEIGHT = 110
local MOUNTAIN_START = 380
local MOUNTAIN_FULL = 600
local LAKE_BOTTOM = -5
local PAD_FEATHER = 20
local ROAD_FLAT = 8
local ROAD_FEATHER = 20

-- Helfer (rein, deterministisch) ------------------------------------------

local function clamp01(value: number): number
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function smoothstep(edge0: number, edge1: number, value: number): number
	local t = clamp01((value - edge0) / (edge1 - edge0))
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Sanfte Talwellen, Amplitude wenige Studs, deterministisch und endlich.
local function valleyHeight(x: number, z: number): number
	return 2.5 * math.sin(x * 0.01) * math.cos(z * 0.012)
		+ 1.5 * math.sin(x * 0.023 + 1.7) * math.sin(z * 0.019 + 0.6)
		+ 1.0 * math.sin((x + z) * 0.007 + 0.3)
end

local function mountainRise(x: number, z: number): number
	local edge = math.max(math.abs(x), math.abs(z))
	return MOUNTAIN_HEIGHT * smoothstep(MOUNTAIN_START, MOUNTAIN_FULL, edge)
end

-- See ---------------------------------------------------------------------

local lakeCenterX: number = WorldZones.LAKE.center.x
local lakeCenterZ: number = WorldZones.LAKE.center.z
local lakeRadius: number = WorldZones.LAKE.radius
local SHORE_HEIGHT: number = valleyHeight(lakeCenterX, lakeCenterZ + lakeRadius + 12)

local function naturalHeight(x: number, z: number): number
	local valley = valleyHeight(x, z)
	local lakeDistance = distance2D(x, z, lakeCenterX, lakeCenterZ)
	-- Berge werden in Seenähe unterdrückt, damit der See im Tal liegt.
	local lakeMask = 1 - smoothstep(lakeRadius + 20, lakeRadius + 80, lakeDistance)
	local base = valley + mountainRise(x, z) * (1 - lakeMask)
	if lakeDistance < lakeRadius - 25 then
		return LAKE_BOTTOM
	elseif lakeDistance < lakeRadius then
		return lerp(LAKE_BOTTOM, SHORE_HEIGHT, smoothstep(lakeRadius - 25, lakeRadius, lakeDistance))
	elseif lakeDistance <= lakeRadius + 25 then
		return SHORE_HEIGHT
	elseif lakeDistance <= lakeRadius + 45 then
		return lerp(SHORE_HEIGHT, base, smoothstep(lakeRadius + 25, lakeRadius + 45, lakeDistance))
	else
		return base
	end
end

-- Abgeflachte Zonen --------------------------------------------------------

type DiscPad = { x: number, z: number, radius: number, target: number }
type Corridor = { ax: number, az: number, bx: number, bz: number, halfWidth: number }

local discPads: { DiscPad } = {}

local function addDisc(x: number, z: number, radius: number, target: number)
	table.insert(discPads, { x = x, z = z, radius = radius, target = target })
end

local donerPosition = WorldLayout.DONER.position
local donerRadius: number = WorldLayout.DONER.radius
addDisc(donerPosition.x, donerPosition.z, donerRadius, valleyHeight(donerPosition.x, donerPosition.z))

for _, village in WorldLayout.VILLAGES do
	local center = village.center
	local villageTarget = valleyHeight(center.x, center.z)
	addDisc(center.x, center.z, village.radius, villageTarget)
	for _, slot in village.slots do
		addDisc(slot.position.x, slot.position.z, 18, villageTarget)
	end
end

local churchPosition = WorldLayout.CHURCH.position
addDisc(churchPosition.x, churchPosition.z, 26, valleyHeight(churchPosition.x, churchPosition.z))

for _, garage in WorldLayout.GARAGES do
	addDisc(garage.position.x, garage.position.z, 20, valleyHeight(garage.position.x, garage.position.z))
end

for _, roundabout in WorldZones.ROUNDABOUTS do
	addDisc(
		roundabout.center.x,
		roundabout.center.z,
		roundabout.radius + 8,
		valleyHeight(roundabout.center.x, roundabout.center.z)
	)
end

for _, bridge in WorldZones.BRIDGE_CROSSINGS do
	addDisc(
		bridge.position.x,
		bridge.position.z,
		bridge.length / 2 + 8,
		valleyHeight(bridge.position.x, bridge.position.z)
	)
end

local corridors: { Corridor } = {}

local function addCorridor(from: any, to: any, width: number)
	table.insert(corridors, {
		ax = from.x,
		az = from.z,
		bx = to.x,
		bz = to.z,
		halfWidth = width / 2,
	})
end

for _, road in WorldZones.ROAD_SEGMENTS do
	addCorridor(road.from, road.to, road.width)
end
for _, road in WorldZones.STOP_ROADS do
	addCorridor(road.from, road.to, road.width)
end

local function projectOnSegment(x: number, z: number, corridor: Corridor): (number, number, number)
	local dx = corridor.bx - corridor.ax
	local dz = corridor.bz - corridor.az
	local lengthSquared = dx * dx + dz * dz
	if lengthSquared == 0 then
		return corridor.ax, corridor.az, distance2D(x, z, corridor.ax, corridor.az)
	end
	local t = ((x - corridor.ax) * dx + (z - corridor.az) * dz) / lengthSquared
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end
	local px = corridor.ax + dx * t
	local pz = corridor.az + dz * t
	return px, pz, distance2D(x, z, px, pz)
end

-- Öffentliche API ----------------------------------------------------------

function TerrainHeight.heightAt(x: number, z: number): number
	local natural = naturalHeight(x, z)
	local bestMask = 0
	local bestTarget = natural

	for _, pad in discPads do
		local distance = distance2D(x, z, pad.x, pad.z)
		if distance < pad.radius + PAD_FEATHER then
			local mask = 1 - smoothstep(pad.radius, pad.radius + PAD_FEATHER, distance)
			if mask > bestMask then
				bestMask = mask
				bestTarget = pad.target
				if bestMask >= 1 then
					break
				end
			end
		end
	end

	for _, corridor in corridors do
		local px, pz, distance = projectOnSegment(x, z, corridor)
		local flatEdge = corridor.halfWidth + ROAD_FLAT
		if distance < flatEdge + ROAD_FEATHER then
			local mask = 1 - smoothstep(flatEdge, flatEdge + ROAD_FEATHER, distance)
			if mask > bestMask then
				bestMask = mask
				bestTarget = valleyHeight(px, pz)
			end
		end
	end

	if bestMask <= 0 then
		return natural
	end
	if bestMask >= 1 then
		return bestTarget
	end
	return lerp(natural, bestTarget, bestMask)
end

function TerrainHeight.slopeAt(x: number, z: number): number
	local e = 2
	local hx1 = TerrainHeight.heightAt(x + e, z)
	local hx0 = TerrainHeight.heightAt(x - e, z)
	local hz1 = TerrainHeight.heightAt(x, z + e)
	local hz0 = TerrainHeight.heightAt(x, z - e)
	local dx = (hx1 - hx0) / (2 * e)
	local dz = (hz1 - hz0) / (2 * e)
	return math.sqrt(dx * dx + dz * dz)
end

local function rectContains(
	px: number,
	pz: number,
	center: any,
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

function TerrainHeight.isBuildPad(position: Vector3): boolean
	local raw: any = position
	local px: number = raw.x
	if px == nil then
		px = raw.X
	end
	local pz: number = raw.z
	if pz == nil then
		pz = raw.Z
	end

	if distance2D(px, pz, donerPosition.x, donerPosition.z) <= donerRadius + 4 then
		return true
	end

	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			if rectContains(px, pz, slot.position, slot.footprint.x, slot.footprint.z, slot.yaw, 6) then
				return true
			end
		end
	end

	local church = WorldLayout.CHURCH
	if rectContains(px, pz, church.position, church.footprint.x, church.footprint.z, church.yaw, 6) then
		return true
	end

	for _, garage in WorldLayout.GARAGES do
		if distance2D(px, pz, garage.position.x, garage.position.z) <= 18 then
			return true
		end
	end

	return false
end

return TerrainHeight
