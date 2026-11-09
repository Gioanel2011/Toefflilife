--!strict
-- TrafficSignPlacer: rein berechnete, deterministische Platzierung von
-- Schweizer Verkehrszeichen im Strassennetz. Vor jeder Stopstrasse steht genau
-- ein Stoppschild; Tempolimits stehen fahrtrichtungsbezogen am rechten
-- Fahrbahnrand. Die reinen Platzierungen sind ohne Roblox-Instanzen testbar,
-- die Modelle entstehen erst in `build` ueber TrafficSignBuilder.
-- Keine anderen Schildtypen, keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")
local TrafficSignBuilder = requireSibling("TrafficSignBuilder")

local TrafficSignPlacer = {}

export type PlacementPosition = { x: number, y: number, z: number }

export type Placement = {
	signType: string, -- "Stop" | "SpeedLimit"
	position: PlacementPosition,
	rotation: number, -- Yaw in Grad; Vorderseite (Roblox-Forward = -Z) zeigt zum Verkehr.
	roadId: string,
	limit: number?, -- nur bei "SpeedLimit"
	travel: { x: number, z: number }, -- Fahrtrichtung, fuer die das Schild gilt.
}

-- Zulaessige Tempolimits (km/h) je Strassenart.
TrafficSignPlacer.RING_LIMIT = 60
TrafficSignPlacer.ACCESS_LIMIT = 30
TrafficSignPlacer.TRUNK_LIMIT = 80
-- Abstand der Stoppschilder vor der Haltelinie in Fahrtrichtung (Studs).
TrafficSignPlacer.STOP_SETBACK = 5
-- Abstand vom Fahrbahnrand zum Schildfuss (Studs); blockiert weder Fahrbahn
-- noch Fussweg.
TrafficSignPlacer.EDGE_CLEARANCE = 2
-- Nur jedes n-te Ringsegment erhaelt ein Tempolimit.
TrafficSignPlacer.RING_SIGN_INTERVAL = 4

-- Geometrie-Helfer (rein, deterministisch) ------------------------------

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function normalize2D(x: number, z: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then
		return 0, 0
	end
	return x / length, z / length
end

-- Yaw, mit dem die Vorderseite (-Z) in Richtung (targetX, targetZ) zeigt.
local function facingYaw(targetX: number, targetZ: number): number
	return math.deg(math.atan2(-targetX, -targetZ))
end

local function groundHeight(x: number, z: number): number
	return TerrainHeight.heightAt(x, z)
end

local function isRoundaboutPoint(x: number, z: number): boolean
	for _, roundabout in WorldZones.ROUNDABOUTS do
		if distance2D(x, z, roundabout.center.x, roundabout.center.z) <= roundabout.radius + 2 then
			return true
		end
	end
	return false
end

-- Schildfuss darf weder im Wasser noch auf der Fahrbahn oder im Kreisel stehen.
local function isFreeSpot(x: number, z: number): boolean
	local point = { x = x, y = 0, z = z }
	if WorldZones.containsWater(point) then
		return false
	end
	if WorldZones.isRoad(point, 1) then
		return false
	end
	return not isRoundaboutPoint(x, z)
end

local function centerPoint(road: any, t: number): (number, number)
	return road.from.x + (road.to.x - road.from.x) * t, road.from.z + (road.to.z - road.from.z) * t
end

local function makePlacement(
	signType: string,
	x: number,
	z: number,
	travelX: number,
	travelZ: number,
	roadId: string,
	limit: number?
): Placement
	return {
		signType = signType,
		position = { x = x, y = groundHeight(x, z), z = z },
		rotation = facingYaw(-travelX, -travelZ),
		roadId = roadId,
		limit = limit,
		travel = { x = travelX, z = travelZ },
	}
end

-- Stoppschilder ----------------------------------------------------------

local function collectStopSigns(): { Placement }
	local placements: { Placement } = {}

	for _, road in WorldZones.STOP_ROADS do
		local stopLine = road.stopLinePosition
		if stopLine then
			-- Der Verkehr faehrt vom Dorf (to) in den Ring (from) und haelt vor
			-- der Haltelinie. Rechts der Fahrtrichtung steht das Schild.
			local travelX, travelZ = normalize2D(road.from.x - road.to.x, road.from.z - road.to.z)
			local rightX, rightZ = -travelZ, travelX
			local outwardX, outwardZ = normalize2D(road.to.x - road.from.x, road.to.z - road.from.z)
			local offset = road.width / 2 + TrafficSignPlacer.EDGE_CLEARANCE
			local length = distance2D(road.from.x, road.from.z, road.to.x, road.to.z)
			local lineDistance = (stopLine.x - road.from.x) * outwardX + (stopLine.z - road.from.z) * outwardZ
			-- Mindestens hinter der Haltelinie und ausserhalb des Kreisels, der
			-- am Ringende der Stopstrasse liegt.
			local along = math.max(lineDistance + TrafficSignPlacer.STOP_SETBACK, WorldZones.ROUNDABOUT_RADIUS + 4)

			while along <= length - 2 do
				local centerX = road.from.x + outwardX * along
				local centerZ = road.from.z + outwardZ * along
				local x = centerX + rightX * offset
				local z = centerZ + rightZ * offset

				if isFreeSpot(x, z) then
					table.insert(placements, makePlacement("Stop", x, z, travelX, travelZ, road.id))
					break
				end

				along += 2
			end
		end
	end

	return placements
end

-- Tempolimits ------------------------------------------------------------

local function addSpeedLimit(
	placements: { Placement },
	road: any,
	t: number,
	travelX: number,
	travelZ: number,
	limit: number
): boolean
	local rightX, rightZ = -travelZ, travelX
	local offset = road.width / 2 + TrafficSignPlacer.EDGE_CLEARANCE
	local centerX, centerZ = centerPoint(road, t)
	local x = centerX + rightX * offset
	local z = centerZ + rightZ * offset

	if not isFreeSpot(x, z) then
		return false
	end

	table.insert(placements, makePlacement("SpeedLimit", x, z, travelX, travelZ, road.id, limit))
	return true
end

-- Platziert ein Tempolimit mit Rueckfallpositionen, damit Kreisel und
-- Wasserflaechen den Schildfuss nicht verdecken.
local function addSpeedLimitWithFallback(
	placements: { Placement },
	road: any,
	candidates: { number },
	travelX: number,
	travelZ: number,
	limit: number
): ()
	for _, t in candidates do
		if addSpeedLimit(placements, road, t, travelX, travelZ, limit) then
			return
		end
	end
end

local function collectSpeedLimits(): { Placement }
	local placements: { Placement } = {}
	local ringIndex = 0

	for _, road in WorldZones.ROAD_SEGMENTS do
		local forwardX, forwardZ = normalize2D(road.to.x - road.from.x, road.to.z - road.from.z)

		if road.kind == "ring" then
			ringIndex += 1
			if ringIndex % TrafficSignPlacer.RING_SIGN_INTERVAL == 1 then
				-- Ring wird im Uhrzeigersinn befahren; das Schild steht damit am
				-- aeusseren Rand und nicht vor den Garagen.
				local travelX, travelZ = normalize2D(road.from.x - road.to.x, road.from.z - road.to.z)
				addSpeedLimitWithFallback(
					placements,
					road,
					{ 0.5, 0.3, 0.7 },
					travelX,
					travelZ,
					TrafficSignPlacer.RING_LIMIT
				)
			end
		elseif road.kind == "access" then
			addSpeedLimitWithFallback(placements, road, { 0.35 }, forwardX, forwardZ, TrafficSignPlacer.ACCESS_LIMIT)
			addSpeedLimitWithFallback(placements, road, { 0.65 }, -forwardX, -forwardZ, TrafficSignPlacer.ACCESS_LIMIT)
		elseif road.kind == "trunk" then
			addSpeedLimitWithFallback(placements, road, { 0.3 }, forwardX, forwardZ, TrafficSignPlacer.TRUNK_LIMIT)
			addSpeedLimitWithFallback(placements, road, { 0.7 }, -forwardX, -forwardZ, TrafficSignPlacer.TRUNK_LIMIT)
		end
	end

	return placements
end

-- Oeffentliche API -------------------------------------------------------

-- Alle Schilder in fester Reihenfolge: erst Stoppschilder, dann Tempolimits.
function TrafficSignPlacer.calculatePlacements(): { Placement }
	local placements: { Placement } = {}

	for _, placement in collectStopSigns() do
		table.insert(placements, placement)
	end
	for _, placement in collectSpeedLimits() do
		table.insert(placements, placement)
	end

	return placements
end

-- Erzeugt die Schildmodelle unter einem benannten Ordner.
function TrafficSignPlacer.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TrafficSigns"

	local counters: { [string]: number } = {}

	for _, placement in TrafficSignPlacer.calculatePlacements() do
		local model: Model
		if placement.signType == "Stop" then
			model = TrafficSignBuilder.createStopSign()
		else
			model = TrafficSignBuilder.createSpeedLimit(placement.limit or 50)
		end

		counters[placement.signType] = (counters[placement.signType] or 0) + 1
		model.Name = string.format("%s_%02d", placement.signType, counters[placement.signType])
		model:PivotTo(
			CFrame.new(placement.position.x, placement.position.y, placement.position.z)
				* CFrame.Angles(0, math.rad(placement.rotation), 0)
		)
		model:SetAttribute("RoadId", placement.roadId)
		model:SetAttribute("SignType", placement.signType)

		model.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return TrafficSignPlacer
