--!strict
-- RoadBuilder: zweispurige Hauptstrassen mit durchgehendem Mittelstreifen.
-- Baut alle Hauptstrassen aus WorldZones (ROAD_SEGMENTS: Ring, Zufahrt, Seestrasse).
-- Jede Fahrbahn folgt dem Terrain (TerrainHeight), Markierungen sind duenn,
-- nicht kollidierbar und ueberhoehen die Fahrbahn nicht.
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

local RoadBuilder = {}

local ROAD_COLOR = Color3.fromRGB(70, 70, 75)
local CENTER_COLOR = Color3.fromRGB(240, 240, 240)
local ROAD_THICKNESS = 1
local ROAD_Y_OFFSET = 0.6
local CENTER_WIDTH = 0.4
local CENTER_THICKNESS = 0.12
local CENTER_LIFT = 0.08
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

local function buildSegment(folder: Instance, id: string, from: any, to: any, width: number)
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
			string.format("%s_%02d", id, i + 1),
			Vector3.new(width, ROAD_THICKNESS, segLength + JOINT_OVERLAP),
			look,
			ROAD_COLOR,
			true
		)
		local lineCFrame = look * CFrame.new(0, ROAD_THICKNESS / 2 + CENTER_LIFT, 0)
		makePart(
			folder,
			string.format("%s_Center_%02d", id, i + 1),
			Vector3.new(CENTER_WIDTH, CENTER_THICKNESS, segLength + JOINT_OVERLAP),
			lineCFrame,
			CENTER_COLOR,
			false
		)
	end
end

-- Erzeugt alle Hauptstrassen unter `parent` und gibt den Ordner zurueck.
function RoadBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Roads"
	for _, segment in WorldZones.ROAD_SEGMENTS do
		buildSegment(root, segment.id, segment.from, segment.to, segment.width)
	end
	root.Parent = parent
	return root
end

return RoadBuilder
