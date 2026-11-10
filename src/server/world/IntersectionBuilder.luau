--!strict
-- IntersectionBuilder: zeichnet nur noch die Haltelinien der Stopstrassen.
-- Stopstrassen und Kreisel selbst sind buendig in das Terrain gemalt
-- (RoadPainter). Keine Bruecken, keine Verkehrszeichen.

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

local IntersectionBuilder = {}

local LINE_COLOR = Color3.fromRGB(240, 240, 240)
local STOP_LINE_WIDTH_FACTOR = 0.8
local STOP_LINE_LENGTH = 1.2
local STOP_LINE_THICKNESS = 0.1

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

local function buildStopLine(folder: Instance, road: any): ()
	local stopPos: any = road.stopLinePosition
	if stopPos == nil then
		return
	end
	local width: number = road.width
	local sx: number = stopPos.x
	local sz: number = stopPos.z
	local y = RoadSurface.cellTop(TerrainHeight.heightAt(sx, sz)) + RoadSurface.LINE_LIFT
	local stopCenter = Vector3.new(sx, y, sz)
	local direction = Vector3.new(road.to.x - road.from.x, 0, road.to.z - road.from.z)
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, 1)
	end
	local lineCFrame = CFrame.lookAt(stopCenter, stopCenter + direction)
	makePart(
		folder,
		string.format("%s_StopLine", road.id),
		Vector3.new(width * STOP_LINE_WIDTH_FACTOR, STOP_LINE_THICKNESS, STOP_LINE_LENGTH),
		lineCFrame,
		LINE_COLOR
	)
end

-- Erzeugt alle Haltelinien unter `parent` und gibt den Ordner zurueck.
function IntersectionBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Intersections"
	for _, road in WorldZones.STOP_ROADS do
		buildStopLine(root, road)
	end
	root.Parent = parent
	return root
end

return IntersectionBuilder
