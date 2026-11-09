--!strict
-- IntersectionBuilder: Stopstrassen mit Haltelinie sowie flache, befahrbare Kreisel.
-- Baut alle Stopstrassen (STOP_ROADS) und Kreisel (ROUNDABOUTS) aus WorldZones.
-- Stopstrassen folgen dem Terrain und besitzen eine gut sichtbare Haltelinie.
-- Kreisel sind flach (eine Hoehe), befahrbar und enthalten keinen Mittelstreifen.
-- Keine Bruecken, keine Verkehrszeichen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")

local IntersectionBuilder = {}

local ROAD_COLOR = Color3.fromRGB(70, 70, 75)
local LINE_COLOR = Color3.fromRGB(240, 240, 240)
local ROAD_THICKNESS = 1
local ROAD_Y_OFFSET = 0.6
local STOP_LINE_WIDTH_FACTOR = 0.8
local STOP_LINE_LENGTH = 1.2
local STOP_LINE_THICKNESS = 0.12
local STOP_LINE_LIFT = 0.08
local STEP_LENGTH = 12
local MAX_STEPS = 64
local JOINT_OVERLAP = 0.6

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function buildStopRoad(folder: Instance, road: any)
	local fromX: number = road.from.x
	local fromZ: number = road.from.z
	local toX: number = road.to.x
	local toZ: number = road.to.z
	local width: number = road.width
	local dx = toX - fromX
	local dz = toZ - fromZ
	local length2D = math.sqrt(dx * dx + dz * dz)
	if length2D < 0.1 then
		return
	end
	local steps = math.clamp(math.ceil(length2D / STEP_LENGTH), 1, MAX_STEPS)
	for i = 0, steps - 1 do
		local t0 = i / steps
		local t1 = (i + 1) / steps
		local x0 = fromX + dx * t0
		local z0 = fromZ + dz * t0
		local x1 = fromX + dx * t1
		local z1 = fromZ + dz * t1
		local h0 = TerrainHeight.heightAt(x0, z0) + ROAD_Y_OFFSET
		local h1 = TerrainHeight.heightAt(x1, z1) + ROAD_Y_OFFSET
		local p0 = Vector3.new(x0, h0, z0)
		local p1 = Vector3.new(x1, h1, z1)
		local delta = p1 - p0
		local segLength = delta.Magnitude
		if segLength < 0.1 then
			segLength = 0.1
		end
		local center = (p0 + p1) / 2
		local look = CFrame.lookAt(center, p1)
		makePart(
			folder,
			string.format("%s_%02d", road.id, i + 1),
			Vector3.new(width, ROAD_THICKNESS, segLength + JOINT_OVERLAP),
			look,
			ROAD_COLOR,
			true
		)
	end

	-- Haltelinie quer zur Fahrtrichtung, gut sichtbar, nicht kollidierbar.
	local stopPos: any = road.stopLinePosition
	if stopPos ~= nil then
		local sx: number = stopPos.x
		local sz: number = stopPos.z
		local roadY = TerrainHeight.heightAt(sx, sz) + ROAD_Y_OFFSET
		local lineY = roadY + ROAD_THICKNESS / 2 + STOP_LINE_LIFT
		local stopCenter = Vector3.new(sx, lineY, sz)
		local direction = Vector3.new(dx, 0, dz)
		if direction.Magnitude < 0.01 then
			direction = Vector3.new(0, 0, 1)
		end
		local lineCFrame = CFrame.lookAt(stopCenter, stopCenter + direction)
		makePart(
			folder,
			string.format("%s_StopLine", road.id),
			Vector3.new(width * STOP_LINE_WIDTH_FACTOR, STOP_LINE_THICKNESS, STOP_LINE_LENGTH),
			lineCFrame,
			LINE_COLOR,
			false
		)
	end
end

local function buildRoundabout(folder: Instance, roundabout: any)
	local cx: number = roundabout.center.x
	local cz: number = roundabout.center.z
	local radius: number = roundabout.radius
	local height = TerrainHeight.heightAt(cx, cz) + ROAD_Y_OFFSET
	local diameter = radius * 2
	local disc = Instance.new("Part")
	disc.Name = roundabout.id
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(ROAD_THICKNESS, diameter, diameter)
	disc.CFrame = CFrame.new(Vector3.new(cx, height, cz)) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Color = ROAD_COLOR
	disc.Material = Enum.Material.SmoothPlastic
	disc.TopSurface = Enum.SurfaceType.Smooth
	disc.BottomSurface = Enum.SurfaceType.Smooth
	disc.Anchored = true
	disc.CanCollide = true
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Parent = folder
end

-- Erzeugt alle Stopstrassen und Kreisel unter `parent` und gibt den Ordner zurueck.
function IntersectionBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Intersections"
	for _, road in WorldZones.STOP_ROADS do
		buildStopRoad(root, road)
	end
	for _, roundabout in WorldZones.ROUNDABOUTS do
		buildRoundabout(root, roundabout)
	end
	root.Parent = parent
	return root
end

return IntersectionBuilder
