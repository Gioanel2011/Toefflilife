--!strict
-- Töffli Tal: versioniertes Spielerprofil-Schema.
-- Geld, Fahrzeuge, Inventar, Teile, Lacke, Missionen und Rabattstatus.
-- Server-autoritativ; keine globalen Variablen.

local PlayerDataSchema = {}

PlayerDataSchema.VERSION = 1
PlayerDataSchema.START_VEHICLE_ID = "bicycle"

local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number" and value >= 0 and math.floor(value) == value
end

local function isStringArray(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, item in pairs(value) do
		if type(key) ~= "number" or type(item) ~= "string" then
			return false
		end
	end
	return true
end

local function isCountMap(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, count in pairs(value) do
		if type(key) ~= "string" or not isNonNegativeInteger(count) then
			return false
		end
	end
	return true
end

local function contains(array: { string }, needle: string): boolean
	for _, item in ipairs(array) do
		if item == needle then
			return true
		end
	end
	return false
end

function PlayerDataSchema.createDefault(): any
	return {
		version = PlayerDataSchema.VERSION,
		cash = 0,
		vehicles = {
			owned = { PlayerDataSchema.START_VEHICLE_ID },
			selected = PlayerDataSchema.START_VEHICLE_ID,
		},
		inventory = {},
		parts = {
			installed = {},
		},
		paints = {},
		missions = {
			completed = {},
			progress = {},
		},
		starterDiscountUsed = false,
	}
end

function PlayerDataSchema.validate(profile: any): (boolean, string?)
	if type(profile) ~= "table" then
		return false, "profile must be a table"
	end
	if profile.version ~= PlayerDataSchema.VERSION then
		return false, "unsupported profile version"
	end
	if not isNonNegativeInteger(profile.cash) then
		return false, "cash must be a non-negative integer"
	end
	if type(profile.vehicles) ~= "table" then
		return false, "vehicles must be a table"
	end
	if not isStringArray(profile.vehicles.owned) then
		return false, "vehicles.owned must be a string array"
	end
	if type(profile.vehicles.selected) ~= "string" then
		return false, "vehicles.selected must be a string"
	end
	if not contains(profile.vehicles.owned, profile.vehicles.selected) then
		return false, "vehicles.selected must be owned"
	end
	if not isCountMap(profile.inventory) then
		return false, "inventory must map item id to count"
	end
	if type(profile.parts) ~= "table" or type(profile.parts.installed) ~= "table" then
		return false, "parts.installed must be a table"
	end
	if type(profile.paints) ~= "table" then
		return false, "paints must be a table"
	end
	if type(profile.missions) ~= "table" then
		return false, "missions must be a table"
	end
	if not isStringArray(profile.missions.completed) then
		return false, "missions.completed must be a string array"
	end
	if type(profile.missions.progress) ~= "table" then
		return false, "missions.progress must be a table"
	end
	if type(profile.starterDiscountUsed) ~= "boolean" then
		return false, "starterDiscountUsed must be a boolean"
	end
	return true, nil
end

function PlayerDataSchema.migrate(profile: any): any
	if type(profile) ~= "table" then
		return PlayerDataSchema.createDefault()
	end
	local defaults: any = PlayerDataSchema.createDefault()
	for key, value in pairs(defaults) do
		if profile[key] == nil then
			profile[key] = value
		end
	end
	if type(profile.vehicles) ~= "table" then
		profile.vehicles = defaults.vehicles
	end
	if not isStringArray(profile.vehicles.owned) or #profile.vehicles.owned == 0 then
		profile.vehicles.owned = { PlayerDataSchema.START_VEHICLE_ID }
	end
	if type(profile.vehicles.selected) ~= "string" or not contains(profile.vehicles.owned, profile.vehicles.selected) then
		profile.vehicles.selected = profile.vehicles.owned[1]
	end
	if type(profile.inventory) ~= "table" then
		profile.inventory = {}
	end
	if type(profile.parts) ~= "table" then
		profile.parts = { installed = {} }
	end
	if type(profile.parts.installed) ~= "table" then
		profile.parts.installed = {}
	end
	if type(profile.paints) ~= "table" then
		profile.paints = {}
	end
	if type(profile.missions) ~= "table" then
		profile.missions = { completed = {}, progress = {} }
	end
	if not isStringArray(profile.missions.completed) then
		profile.missions.completed = {}
	end
	if type(profile.missions.progress) ~= "table" then
		profile.missions.progress = {}
	end
	if type(profile.starterDiscountUsed) ~= "boolean" then
		profile.starterDiscountUsed = false
	end
	if not isNonNegativeInteger(profile.cash) then
		profile.cash = 0
	end
	profile.version = PlayerDataSchema.VERSION
	return profile
end

function PlayerDataSchema.isStarterDiscountAvailable(profile: any): boolean
	return type(profile) == "table" and profile.starterDiscountUsed == false
end

return PlayerDataSchema
