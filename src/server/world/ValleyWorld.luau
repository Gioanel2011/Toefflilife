--!strict
-- ValleyWorld: idempotente Weltgenerierung fuer das Toeffli-Tal.
-- Layoutdaten stammen ausschliesslich aus WorldLayout; dieses Modul erzeugt
-- nur Instanzen und bietet die stabilen Abfrage- und Cleanup-APIs.
-- Keine globalen Variablen, keine Greybox-Reste, keine Client-Abhaengigkeiten.

local ValleyWorld = {}

local ROOT_NAME = "ValleyWorld"

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")

local TerrainBuilder = requireSibling("TerrainBuilder")
local WaterBuilder = requireSibling("WaterBuilder")
local RoadBuilder = requireSibling("RoadBuilder")
local RoadPainter = requireSibling("RoadPainter")
local IntersectionBuilder = requireSibling("IntersectionBuilder")
local BridgeBuilder = requireSibling("BridgeBuilder")
local TrafficSignPlacer = requireSibling("TrafficSignPlacer")
local DonerShopBuilder = requireSibling("DonerShopBuilder")
local ChurchBuilder = requireSibling("ChurchBuilder")
local VillageBuilder = requireSibling("VillageBuilder")
local PastureBuilder = requireSibling("PastureBuilder")
local VegetationBuilder = requireSibling("VegetationBuilder")
local GrassFieldBuilder = requireSibling("GrassFieldBuilder")
local AtmosphereBuilder = requireSibling("AtmosphereBuilder")
local GarageWorldBuilder = requireSibling("GarageWorldBuilder")
local SpawnBuilder = requireSibling("SpawnBuilder")

ValleyWorld.MAX_PLAYERS = 15

-- Konvertiert die reinen Layoutdaten in die von diesem Modul gewohnten Vektoren.
local function toVector3(position: { x: number, y: number, z: number }): Vector3
	return Vector3.new(position.x, position.y, position.z)
end

function ValleyWorld.getBounds(): (number, number)
	local bounds = WorldLayout.BOUNDS
	return (bounds.maxX - bounds.minX) / 2, (bounds.maxZ - bounds.minZ) / 2
end

function ValleyWorld.isInsideBounds(position: Vector3): boolean
	return WorldLayout.isInsideBounds({ x = position.X, y = position.Y, z = position.Z })
end

function ValleyWorld.getDeliveryPoints(): { { Name: string, Position: Vector3 } }
	local points = WorldLayout.getDeliveryPoints()
	local copy: { { Name: string, Position: Vector3 } } = {}
	for _, point in points do
		table.insert(copy, { Name = point.id, Position = toVector3(point.position) })
	end
	return copy
end

function ValleyWorld.getGarageAnchors(): { { Name: string, Position: Vector3 } }
	local anchors = WorldLayout.getGarageAnchors()
	local copy: { { Name: string, Position: Vector3 } } = {}
	for _, anchor in anchors do
		table.insert(copy, { Name = anchor.id, Position = toVector3(anchor.position) })
	end
	return copy
end

function ValleyWorld.getPointsOfInterest(): { { Name: string, Kind: string, Position: Vector3, Size: Vector3 } }
	local points = WorldLayout.getPointsOfInterest()
	local copy: { { Name: string, Kind: string, Position: Vector3, Size: Vector3 } } = {}
	for _, point in points do
		local diameter = point.radius * 2
		table.insert(copy, {
			Name = point.id,
			Kind = point.kind,
			Position = toVector3(point.position),
			Size = Vector3.new(diameter, point.radius, diameter),
		})
	end
	return copy
end

-- Entfernt ausschliesslich die zuvor generierte Welt unter `parent`.
function ValleyWorld.cleanup(parent: Instance): ()
	for _, child in parent:GetChildren() do
		if child.Name == ROOT_NAME then
			child:Destroy()
		end
	end
end

-- Feste Reihenfolge: Terrain, Wasser, Strassen, Kreuzungen, Bruecken, Gebaeude,
-- Garagen, Vegetation inkl. Gras, Weiden, Schilder, Atmosphaere.
local function buildWorld(root: Instance): ()
	TerrainBuilder.build(root)

	WaterBuilder.build(root)

	-- Asphalt buendig in die oberste Terrainvoxel malen (keine schwebenden Parts).
	RoadPainter.paint(workspace.Terrain)

	RoadBuilder.build(root)
	IntersectionBuilder.build(root)
	BridgeBuilder.build(root)

	DonerShopBuilder.build(root)
	ChurchBuilder.build(root)
	VillageBuilder.build(root)

	GarageWorldBuilder.build(root)

	VegetationBuilder.build(root)
	GrassFieldBuilder.build(root)

	PastureBuilder.build(root)

	TrafficSignPlacer.build(root)

	-- Start-Spawn zuletzt: die Bodenhoehe ist dann bereits endgueltig.
	SpawnBuilder.build(root)

	AtmosphereBuilder.apply()
end

-- Erzeugt die Welt unter `parent`. Ein erneuter Aufruf entfernt zuerst genau
-- die bisher generierte Welt und baut sie anschliessend vollstaendig neu auf.
function ValleyWorld.build(parent: Instance): Instance
	ValleyWorld.cleanup(parent)

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME

	local ok, err = pcall(buildWorld, root)
	if not ok then
		root:Destroy()
		error(err, 0)
	end

	root.Parent = parent
	return root
end

return ValleyWorld
