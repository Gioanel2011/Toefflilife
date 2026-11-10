--!strict
-- RoadPainter: faerbt die oberste Terrain-Voxelreihe entlang aller Strassen,
-- Stopstrassen und Kreisel mit Material Asphalt. Dadurch liegt die Strasse
-- exakt buendig auf der Karte und kann weder schweben noch im Gras versinken.
-- Keine Parts, keine Preise, keine Gameplay-Logik, keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")
local RoadSurface = requireSibling("RoadSurface")

local RoadPainter = {}

local function distanceToSegment(
	px: number,
	pz: number,
	ax: number,
	az: number,
	bx: number,
	bz: number
): number
	local dx = bx - ax
	local dz = bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = 0
	if lengthSquared > 0 then
		t = math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1)
	end
	local cx = ax + dx * t
	local cz = az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function paintCell(terrain: Terrain, cx: number, cz: number): ()
	local top = RoadSurface.cellTop(TerrainHeight.heightAt(cx, cz))
	local size = Vector3.new(
		RoadSurface.paintSize(),
		RoadSurface.paintSize(),
		RoadSurface.paintSize()
	)
	terrain:FillBlock(CFrame.new(cx, top - RoadSurface.VOXEL / 2, cz), size, Enum.Material.Asphalt)
end

-- Zellenraster auf das globale 4-Studs-Voxelraster ausrichten.
local function firstCell(minValue: number): number
	return math.floor(minValue / RoadSurface.VOXEL) * RoadSurface.VOXEL + RoadSurface.VOXEL / 2
end

local function paintSegment(
	terrain: Terrain,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	width: number
): ()
	local half = width / 2 + 0.01
	local minX = math.min(ax, bx) - half
	local maxX = math.max(ax, bx) + half
	local minZ = math.min(az, bz) - half
	local maxZ = math.max(az, bz) + half

	local x = firstCell(minX)
	while x <= maxX do
		local z = firstCell(minZ)
		while z <= maxZ do
			if distanceToSegment(x, z, ax, az, bx, bz) <= half then
				paintCell(terrain, x, z)
			end
			z += RoadSurface.VOXEL
		end
		x += RoadSurface.VOXEL
	end
end

local function paintRoundabout(terrain: Terrain, centerX: number, centerZ: number, radius: number): ()
	local reach = radius + 0.01
	local minX = centerX - reach
	local maxX = centerX + reach
	local minZ = centerZ - reach
	local maxZ = centerZ + reach

	local x = firstCell(minX)
	while x <= maxX do
		local z = firstCell(minZ)
		while z <= maxZ do
			local dx = x - centerX
			local dz = z - centerZ
			if math.sqrt(dx * dx + dz * dz) <= reach then
				paintCell(terrain, x, z)
			end
			z += RoadSurface.VOXEL
		end
		x += RoadSurface.VOXEL
	end
end

function RoadPainter.paint(terrain: Terrain): ()
	for _, road in WorldZones.ROAD_SEGMENTS do
		paintSegment(terrain, road.from.x, road.from.z, road.to.x, road.to.z, road.width)
	end
	for _, road in WorldZones.STOP_ROADS do
		paintSegment(terrain, road.from.x, road.from.z, road.to.x, road.to.z, road.width)
	end
	for _, roundabout in WorldZones.ROUNDABOUTS do
		paintRoundabout(terrain, roundabout.center.x, roundabout.center.z, roundabout.radius)
	end
end

return RoadPainter
