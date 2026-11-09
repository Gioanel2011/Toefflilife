--!strict
-- BuildingCatalog.spec: Validierung des Haushaltskatalogs (Task 10).

local BuildingCatalog = require("../src/server/world/data/BuildingCatalog")

local function check(condition: boolean, message: string)
	if not condition then
		error("BuildingCatalog.spec FAILED: " .. message, 2)
	end
end

-- 1. Selbstvalidierung.
local ok, err = BuildingCatalog.validate()
check(ok == true, "validate() schlug fehl: " .. tostring(err))

-- 2. 20 Haeuser.
check(type(BuildingCatalog.HOUSES) == "table", "HOUSES muss eine Tabelle sein")
check(#BuildingCatalog.HOUSES == 20, "HOUSES muss 20 Eintraege haben")

-- 3. 10 je Dorf.
local perVillage: { [string]: number } = {}
for _, house in BuildingCatalog.HOUSES do
	perVillage[house.VillageId] = (perVillage[house.VillageId] or 0) + 1
end
check(perVillage["Village_Alpenblick"] == 10, "10 Haeuser in Alpenblick erwartet")
check(perVillage["Village_Seeblick"] == 10, "10 Haeuser in Seeblick erwartet")

-- 4. 20 eindeutige IDs.
local ids: { [string]: boolean } = {}
for _, house in BuildingCatalog.HOUSES do
	check(type(house.Id) == "string" and house.Id ~= "", "Haus ohne Id")
	check(ids[house.Id] == nil, "doppelte Id: " .. tostring(house.Id))
	ids[house.Id] = true
end
local idCount = 0
for _ in ids do
	idCount += 1
end
check(idCount == 20, "20 eindeutige IDs erwartet")

-- 5. 20 eindeutige Gestaltungssignaturen.
local sigs: { [string]: boolean } = {}
for _, house in BuildingCatalog.HOUSES do
	check(type(house.Signature) == "string" and house.Signature ~= "", "Haus ohne Signature: " .. tostring(house.Id))
	check(sigs[house.Signature] == nil, "doppelte Signature: " .. tostring(house.Signature))
	sigs[house.Signature] = true
end
local sigCount = 0
for _ in sigs do
	sigCount += 1
end
check(sigCount == 20, "20 eindeutige Gestaltungssignaturen erwartet")

-- 6. getById.
local first = BuildingCatalog.HOUSES[1]
check(first ~= nil, "erstes Haus fehlt")
local found = BuildingCatalog.getById(first.Id)
check(found ~= nil, "getById findet Haus nicht")
check(found.Id == first.Id, "getById liefert falsches Haus")
check(BuildingCatalog.getById("gibt_es_nicht") == nil, "getById muss nil fuer unbekannte Id liefern")

-- 7. Kombination aus den sechs Merkmalen ist eindeutig (keine sichtbaren Duplikate).
local combos: { [string]: boolean } = {}
for _, house in BuildingCatalog.HOUSES do
	local combo = tostring(house.Footprint) .. "|" .. tostring(house.RoofShape) .. "|" .. tostring(house.FacadeColors) .. "|" .. tostring(house.WindowStyle) .. "|" .. tostring(house.DoorSide) .. "|" .. tostring(house.Decoration)
	check(combos[combo] == nil, "sichtbares Duplikat: " .. combo)
	combos[combo] = true
end

print("BuildingCatalog.spec: all assertions passed (" .. tostring(#BuildingCatalog.HOUSES) .. " houses)")