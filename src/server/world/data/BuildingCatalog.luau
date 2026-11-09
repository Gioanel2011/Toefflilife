--!strict
-- BuildingCatalog: 20 einzigartige Haeuser fuer die zwei Doerfer des Toeffli-Tals.
-- Reine Daten, keine Roblox-Instanzen, keine globalen Variablen.
-- Jede Kombination aus Grundriss, Dach, Farbe, Fenster, Tuer und Dekoration ist
-- eindeutig; keine sichtbaren Duplikate. Die Kirche ist nicht Teil dieses Katalogs.

export type HouseDefinition = { [string]: any }

local BuildingCatalog = {}

-- Optionen fuer die sechs Gestaltungsmerkmale.
local FOOTPRINTS: { string } = { "rectangular", "L_shape", "T_shape", "square", "wide_rect" }
local FOOTPRINT_SIZES: { { x: number, z: number } } = {
	{ x = 20, z = 16 },
	{ x = 18, z = 18 },
	{ x = 22, z = 14 },
	{ x = 16, z = 16 },
	{ x = 24, z = 12 },
}
local ROOFS: { string } = { "gable", "hip", "flat", "mansard" }
local COLORS: { string } = { "white", "cream", "yellow", "gray", "brown" }
local WINDOWS: { string } = { "shuttered", "plain", "arched", "bay" }
local DOORS: { string } = { "front", "left", "right", "center" }
local DECORATIONS: { string } = { "flowers", "balcony", "shutters", "garden", "none" }
local HEIGHTS: { number } = { 6.0, 7.5, 9.0, 5.5, 8.0 }

local VILLAGE_IDS: { string } = { "Village_Alpenblick", "Village_Seeblick" }
local VILLAGE_SHORT: { string } = { "Alpenblick", "Seeblick" }

local function makeHouse(
	id: string,
	name: string,
	villageId: string,
	footprint: string,
	footprintSize: { x: number, z: number },
	height: number,
	roof: string,
	colors: { string },
	windowStyle: string,
	doorSide: string,
	decoration: string
): HouseDefinition
	local signature = footprint .. "|" .. roof .. "|" .. table.concat(colors, ",") .. "|" .. windowStyle .. "|" .. doorSide .. "|" .. decoration
	local house: HouseDefinition = {}
	house.Id = id
	house.id = id
	house.Name = name
	house.name = name
	house.VillageId = villageId
	house.villageId = villageId
	house.Footprint = footprint
	house.footprint = footprint
	house.Grundriss = footprint
	house.grundriss = footprint
	house.FootprintSize = { x = footprintSize.x, z = footprintSize.z }
	house.footprintSize = { x = footprintSize.x, z = footprintSize.z }
	house.Size = { x = footprintSize.x, z = footprintSize.z }
	house.size = { x = footprintSize.x, z = footprintSize.z }
	house.Height = height
	house.height = height
	house.Hoehe = height
	house.hoehe = height
	house.RoofShape = roof
	house.roofShape = roof
	house.RoofType = roof
	house.roofType = roof
	house.Roof = roof
	house.roof = roof
	house.Dachform = roof
	house.dachform = roof
	house.FacadeColors = colors
	house.facadeColors = colors
	house.Colors = colors
	house.colors = colors
	house.FacadeColor = colors[1]
	house.facadeColor = colors[1]
	house.Fassadenfarben = colors
	house.fassadenfarben = colors
	house.WindowStyle = windowStyle
	house.windowStyle = windowStyle
	house.Windows = windowStyle
	house.windows = windowStyle
	house.Fensterstil = windowStyle
	house.fensterstil = windowStyle
	house.DoorSide = doorSide
	house.doorSide = doorSide
	house.DoorDirection = doorSide
	house.doorDirection = doorSide
	house.Door = doorSide
	house.door = doorSide
	house.Tuerseite = doorSide
	house.tuerseite = doorSide
	house.Decoration = decoration
	house.decoration = decoration
	house.DecorationSignature = decoration
	house.decorationSignature = decoration
	house.DecorationSignatur = decoration
	house.decorationSignatur = decoration
	house.Dekorationssignatur = decoration
	house.dekorationssignatur = decoration
	house.Signature = signature
	house.signature = signature
	house.DesignSignature = signature
	house.designSignature = signature
	house.Gestaltungssignatur = signature
	house.gestaltungssignatur = signature
	house.Signatur = signature
	house.signatur = signature
	return house
end

-- 20 Haeuser generieren: gemischte Basis sorgt fuer eindeutige 6-Tupel.
local houses: { HouseDefinition } = {}
for i = 0, 19 do
	-- Dorfzuordnung: erste 10 / zweite 10
	local villageIndex = 0
	if i >= 10 then
		villageIndex = 1
	end
	local villageId = VILLAGE_IDS[villageIndex + 1]
	local villageShort = VILLAGE_SHORT[villageIndex + 1]
	local localIndex = (i % 10) + 1

	local n = i
	local fi = n % 5
	n = math.floor(n / 5)
	local ri = n % 4
	n = math.floor(n / 4)
	local ci = n % 5
	n = math.floor(n / 5)
	local wi = n % 4
	n = math.floor(n / 4)
	local di = n % 4
	n = math.floor(n / 4)
	local ei = n % 5

	local footprint = FOOTPRINTS[fi + 1]
	local footprintSize = FOOTPRINT_SIZES[fi + 1]
	local roof = ROOFS[ri + 1]
	local color = COLORS[ci + 1]
	local trimColor = COLORS[(ci + 2) % 5 + 1]
	local colors = { color, trimColor }
	local windowStyle = WINDOWS[wi + 1]
	local doorSide = DOORS[di + 1]
	local decoration = DECORATIONS[ei + 1]
	local height = HEIGHTS[fi + 1] + (di * 0.3)

	local id = string.format("House_%s_%02d", villageShort, localIndex)
	local name = string.format("%s Haus %02d", villageShort, localIndex)

	table.insert(
		houses,
		makeHouse(id, name, villageId, footprint, footprintSize, height, roof, colors, windowStyle, doorSide, decoration)
	)
end

BuildingCatalog.HOUSES = houses
BuildingCatalog.Houses = houses

-- Lookup-Index.
local BY_ID: { [string]: HouseDefinition } = {}
for _, house in houses do
	BY_ID[house.Id] = house
end

function BuildingCatalog.getById(id: string): HouseDefinition?
	return BY_ID[id]
end

function BuildingCatalog.GetById(id: string): HouseDefinition?
	return BY_ID[id]
end

function BuildingCatalog.getHouse(id: string): HouseDefinition?
	return BY_ID[id]
end

function BuildingCatalog.GetHouse(id: string): HouseDefinition?
	return BY_ID[id]
end

function BuildingCatalog.validate(): (boolean, string?)
	if type(BuildingCatalog.HOUSES) ~= "table" then
		return false, "HOUSES must be a table"
	end
	if #BuildingCatalog.HOUSES ~= 20 then
		return false, string.format("expected 20 houses, found %d", #BuildingCatalog.HOUSES)
	end

	local ids: { [string]: boolean } = {}
	local signatures: { [string]: boolean } = {}
	local perVillage: { [string]: number } = {}

	for index, house in BuildingCatalog.HOUSES do
		if type(house) ~= "table" then
			return false, string.format("house #%d is not a table", index)
		end
		if type(house.Id) ~= "string" or house.Id == "" then
			return false, string.format("house #%d has invalid Id", index)
		end
		if ids[house.Id] then
			return false, "duplicate Id: " .. house.Id
		end
		ids[house.Id] = true

		if type(house.VillageId) ~= "string" or (house.VillageId ~= "Village_Alpenblick" and house.VillageId ~= "Village_Seeblick") then
			return false, string.format("house '%s' has invalid VillageId", tostring(house.Id))
		end
		perVillage[house.VillageId] = (perVillage[house.VillageId] or 0) + 1

		if type(house.Signature) ~= "string" or house.Signature == "" then
			return false, string.format("house '%s' has invalid Signature", tostring(house.Id))
		end
		if signatures[house.Signature] then
			return false, "duplicate Signature: " .. house.Signature
		end
		signatures[house.Signature] = true
	end

	if perVillage["Village_Alpenblick"] ~= 10 then
		return false, string.format("expected 10 houses for Village_Alpenblick, found %d", perVillage["Village_Alpenblick"] or 0)
	end
	if perVillage["Village_Seeblick"] ~= 10 then
		return false, string.format("expected 10 houses for Village_Seeblick, found %d", perVillage["Village_Seeblick"] or 0)
	end

	local signatureCount = 0
	for _ in signatures do
		signatureCount += 1
	end
	if signatureCount ~= 20 then
		return false, string.format("expected 20 unique signatures, found %d", signatureCount)
	end

	return true, nil
end

local ok, err = BuildingCatalog.validate()
assert(ok, "BuildingCatalog invalid: " .. tostring(err))

return BuildingCatalog