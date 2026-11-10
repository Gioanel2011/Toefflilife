--!strict
-- VillageBuilder: erzeugt beide Doerfer mit je 10 Haeusern aus dem Katalog.
-- Keine Greyboxen, keine Kirche, keine Garagen. Eingangstueren bleiben frei.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local BuildingCatalog: any
do
	local ok, module = pcall(require, "./data/BuildingCatalog")
	if ok then
		BuildingCatalog = module
	else
		BuildingCatalog = require(script.Parent.data.BuildingCatalog)
	end
end
local WorldLayout = requireSibling("WorldLayout")
local TerrainHeight = requireSibling("TerrainHeight")
local BuildingFactory = requireSibling("BuildingFactory")
local BuildingPlacement = requireSibling("BuildingPlacement")

local VillageBuilder = {}

local function villageIdOf(definition: { [string]: any }): string
	local value = definition.VillageId
	if type(value) == "string" then
		return value
	end
	value = definition.villageId
	if type(value) == "string" then
		return value
	end
	return ""
end

local function houseIdOf(definition: { [string]: any }): string
	local value = definition.Id
	if type(value) == "string" and value ~= "" then
		return value
	end
	value = definition.id
	if type(value) == "string" then
		return value
	end
	return ""
end

function VillageBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Villages"

	local villages: any = WorldLayout.VILLAGES
	for _, village in villages do
		local villageId: string = village.id
		local houses: { { [string]: any } } = {}
		for _, definition in BuildingCatalog.HOUSES do
			if villageIdOf(definition) == villageId then
				table.insert(houses, definition)
			end
		end
		table.sort(houses, function(a, b)
			return houseIdOf(a) < houseIdOf(b)
		end)

		local slots: any = village.slots
		for index, slot in slots do
			local definition = houses[index]
			if definition == nil then
				continue
			end
			local model: Model = BuildingFactory.create(definition)
			model:SetAttribute("SlotId", slot.id)
			model.Parent = folder
			local groundY: number = BuildingPlacement.surfaceAt(slot.position.x, slot.position.z)
				or TerrainHeight.heightAt(slot.position.x, slot.position.z)
			local ground = Vector3.new(slot.position.x, groundY, slot.position.z)
			local rigid = CFrame.new(ground) * CFrame.Angles(0, math.rad(slot.yaw), 0)
			local pivot: CFrame = model:GetPivot()
			model:PivotTo(rigid * pivot)
		end
	end

	folder.Parent = parent
	return folder
end

return VillageBuilder
