--!strict
-- RoadBuilder: zeichnet nur noch die Mittellinie auf den buendig in das
-- Terrain gemalten Asphalt (RoadPainter). Die Fahrbahn selbst ist Terrain und
-- kann daher weder schweben noch im Gras verschwinden.
-- Keine Stopstrassen, keine Kreisel, keine Bruecken, keine Schilder.

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

local RoadBuilder = {}

local CENTER_COLOR = Color3.fromRGB(240, 240, 240)
local CENTER_WIDTH = 0.5
local CENTER_THICKNESS = 0.1
local JOINT_OVERLAP = 0.4

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
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
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function buildSegment(folder: Instance, id: string, from: any, to: any)
	local fromX: number = from.x
	local fromZ: number = from.z
	local toX: number = to.x
	local toZ: number = to.z
	local dx = toX - fromX
	local dz = toZ - fromZ
	local length2D = math.sqrt(dx * dx + dz * dz)
	if length2D < 0.1 then
		return
	end
	local steps = RoadSurface.stepsFor(length2D)
	for i = 0, steps - 1 do
		local t0 = i / steps
		local t1 = (i + 1) / steps
		local x0 = fromX + dx * t0
		local z0 = fromZ + dz * t0
		local x1 = fromX + dx * t1
		local z1 = fromZ + dz * t1
		local midX = (x0 + x1) / 2
		local midZ = (z0 + z1) / 2
		local y = RoadSurface.cellTop(TerrainHeight.heightAt(midX, midZ)) + RoadSurface.LINE_LIFT
		local segLength = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		if segLength < 0.1 then
			segLength = 0.1
		end
		local center = Vector3.new(midX, y, midZ)
		local look = CFrame.lookAt(center, center + Vector3.new(dx, 0, dz))
		makePart(
			folder,
			string.format("%s_Center_%02d", id, i + 1),
			Vector3.new(CENTER_WIDTH, CENTER_THICKNESS, segLength + JOINT_OVERLAP),
			look,
			CENTER_COLOR
		)
	end
end

-- Erzeugt die Mittellinien unter `parent` und gibt den Ordner zurueck.
function RoadBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Roads"
	for _, segment in WorldZones.ROAD_SEGMENTS do
		buildSegment(root, segment.id, segment.from, segment.to)
	end
	root.Parent = parent
	return root
end

return RoadBuilder
