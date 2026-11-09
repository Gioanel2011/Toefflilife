--!strict
-- GarageWorldBuilder: platziert exakt 15 identische Garagen aus GarageFactory
-- an den Ankern aus WorldLayout.GARAGES. Die reine Platzierungsfunktion
-- `calculatePlacements` liefert Daten ohne Roblox-Instanzen und ist damit in
-- Studio und Lune testbar. Die Modelle entstehen erst in `build`.
-- Alle Garagen teilen denselben Doenerabstand und halten Mindestabstand zu
-- Strassen, Wasser und Gebaeuden ein. Keine unterschiedlichen Groessen,
-- Farben oder Zusatzvorteile; keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local TerrainHeight = requireSibling("TerrainHeight")

local GarageWorldBuilder = {}

export type PlacementPosition = { x: number, y: number, z: number }

export type Placement = {
	id: string,
	name: string,
	anchorName: string,
	position: PlacementPosition,
	yaw: number,
	angleDegrees: number,
}

-- Exakt 15 Garagen, ein Platz je Spieler bei maximal 15 Spielern.
GarageWorldBuilder.COUNT = 15
GarageWorldBuilder.FOLDER_NAME = "Garages"

-- Die Garage steht mit ihrer Bodenplatte (Dicke 1) auf dem Gelaende.
GarageWorldBuilder.FLOOR_THICKNESS = 1

-- Reine Platzierungsdaten: deterministisch, ohne Roblox-Instanzen.
function GarageWorldBuilder.calculatePlacements(): { Placement }
	local garages = WorldLayout.GARAGES
	assert(
		#garages == GarageWorldBuilder.COUNT,
		string.format("GarageWorldBuilder erwartet %d Garagen, gefunden: %d", GarageWorldBuilder.COUNT, #garages)
	)

	local placements: { Placement } = {}
	for _, garage in garages do
		local x = garage.position.x
		local z = garage.position.z
		placements[#placements + 1] = {
			id = garage.id,
			name = garage.name,
			anchorName = garage.id,
			position = {
				x = x,
				y = TerrainHeight.heightAt(x, z),
				z = z,
			},
			yaw = garage.yaw,
			angleDegrees = garage.angleDegrees,
		}
	end
	return placements
end

-- Erzeugt alle Garagen unter einem benannten Ordner und gibt ihn zurueck.
function GarageWorldBuilder.build(parent: Instance): Folder
	-- GarageFactory verwendet Roblox-Datentypen auf Modulebene; der Require
	-- erfolgt deshalb erst beim tatsaechlichen Bau.
	local GarageFactory = requireSibling("GarageFactory")

	local folder = Instance.new("Folder")
	folder.Name = GarageWorldBuilder.FOLDER_NAME

	local floorOffset = GarageWorldBuilder.FLOOR_THICKNESS / 2

	for index, placement in GarageWorldBuilder.calculatePlacements() do
		local model = GarageFactory.create(placement.anchorName)
		model.Name = placement.id
		model:SetAttribute("GarageId", placement.id)
		model:SetAttribute("GarageIndex", index)
		model:SetAttribute("AnchorName", placement.anchorName)
		model:SetAttribute("AngleDegrees", placement.angleDegrees)
		model:PivotTo(
			CFrame.new(placement.position.x, placement.position.y + floorOffset, placement.position.z)
				* CFrame.Angles(0, math.rad(placement.yaw), 0)
		)
		model.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return GarageWorldBuilder
