--!strict
-- PlayerStore: Bruecke zwischen dem persistierten PlayerDataSchema und den
-- Service-Sichten. `PlayerDataSchema` bleibt das Speicherformat (`cash`,
-- `vehicles.owned`, `vehicles.selected`); VehicleService und ShopService
-- erhalten eine Sicht mit `money`, `inventory`, `vehicles` und
-- `selectedVehicle`, WorkshopService eine Sicht mit Fahrzeug-Records.
-- `EconomyService` bleibt waehrend einer Session die Geldquelle; beim Laden
-- wird `cash` uebernommen, beim Speichern zurueckgeschrieben.
-- Keine Roblox-Laufzeit, keine globalen Variablen.

local PlayerDataSchema = require("../../shared/data/PlayerDataSchema")

local PlayerStore = {}
PlayerStore.__index = PlayerStore

export type Options = {
	profiles: any,
	economy: any,
	schema: any?,
}

local function toKey(userId: any): string
	return tostring(userId)
end

local function copyMap(source: { [string]: any }?): { [string]: any }
	local copy: { [string]: any } = {}
	if source ~= nil then
		for key, value in pairs(source) do
			copy[key] = value
		end
	end
	return copy
end

local function copyList(source: { string }?): { string }
	local copy: { string } = {}
	if source ~= nil then
		for _, value in ipairs(source) do
			table.insert(copy, value)
		end
	end
	return copy
end

local function defaultView(profile: any): any
	return {
		money = profile.cash,
		inventory = profile.inventory,
		vehicles = copyList(profile.vehicles.owned),
		selectedVehicle = profile.vehicles.selected,
		starterDiscountUsed = profile.starterDiscountUsed == true,
	}
end

function PlayerStore.new(options: Options)
	assert(type(options) == "table", "PlayerStore.new needs options")
	assert(type(options.profiles) == "table", "PlayerStore needs a ProfileService instance")
	assert(type(options.economy) == "table", "PlayerStore needs an EconomyService instance")
	local self = setmetatable({}, PlayerStore)
	self._profiles = options.profiles
	self._economy = options.economy
	self._schema = options.schema or PlayerDataSchema
	self._views = {}
	self._workshopProfiles = {}
	self._workshopVehicles = {}
	return self
end

function PlayerStore:getVehicleProfiles(): { [string]: any }
	return self._views
end

function PlayerStore:getWorkshopProfiles(): { [string]: any }
	return self._workshopProfiles
end

local function buildWorkshopProfile(profile: any, view: any, records: { [string]: any }): any
	local vehicles: { [string]: any } = {}
	local stored = profile.parts.byVehicle
	for _, vehicleId in ipairs(view.vehicles) do
		local data: any = nil
		if type(stored) == "table" then
			data = (stored :: any)[vehicleId]
		end
		local fallbackInstalled = vehicleId == profile.vehicles.selected and type(profile.parts.installed) == "table"
		local fallbackPaints = vehicleId == profile.vehicles.selected and type(profile.paints) == "table"
		local record = {
			modelId = vehicleId,
			parts = if type(data) == "table" and type(data.parts) == "table"
				then copyMap(data.parts)
				elseif fallbackInstalled then copyMap(profile.parts.installed)
				else {},
			colors = if type(data) == "table" and type(data.colors) == "table"
				then copyMap(data.colors)
				elseif fallbackPaints then copyMap(profile.paints)
				else {},
		}
		vehicles[vehicleId] = record
		records[vehicleId] = record
	end
	return {
		inventory = view.inventory,
		vehicles = vehicles,
	}
end

-- Laedt das Schema-Profil und baut beide Service-Sichten. Ist der Spieler
-- bereits geladen, wird die vorhandene Sicht zurueckgegeben.
function PlayerStore:load(userId: any): any
	local key = toKey(userId)
	local existing = self._views[key]
	if existing ~= nil then
		return existing
	end
	local profile = self._profiles:load(userId)
	self._schema.migrate(profile)
	if type(profile.cash) ~= "number" then
		profile.cash = 0
	end
	local view = defaultView(profile)
	view.schema = profile
	self._views[key] = view
	local records: { [string]: any } = {}
	self._workshopProfiles[key] = buildWorkshopProfile(profile, view, records)
	self._workshopVehicles[key] = records
	self._economy:setBalance(userId, view.money)
	return view
end

function PlayerStore:ensure(userId: any): any
	return self:load(userId)
end

function PlayerStore:get(userId: any): any?
	return self._views[toKey(userId)]
end

function PlayerStore:view(userId: any): any?
	return self._views[toKey(userId)]
end

function PlayerStore:workshopVehicle(userId: any, vehicleId: string): any?
	local records = self._workshopVehicles[toKey(userId)]
	if records == nil then
		return nil
	end
	return records[vehicleId]
end

function PlayerStore:owns(userId: any, vehicleId: string): boolean
	local view = self._views[toKey(userId)]
	if view == nil then
		return false
	end
	for _, ownedId in ipairs(view.vehicles) do
		if ownedId == vehicleId then
			return true
		end
	end
	return false
end

function PlayerStore:owned(userId: any): { string }
	local view = self._views[toKey(userId)]
	if view == nil then
		return {}
	end
	local owned: { string } = {}
	for _, vehicleId in ipairs(view.vehicles) do
		table.insert(owned, vehicleId)
	end
	table.sort(owned)
	return owned
end

function PlayerStore:selected(userId: any): string?
	local view = self._views[toKey(userId)]
	if view == nil then
		return nil
	end
	return view.selectedVehicle
end

function PlayerStore:cash(userId: any): number
	local view = self._views[toKey(userId)]
	if view == nil then
		return 0
	end
	return view.money
end

-- Eindeutiger Schluessel pro Spieler und Fahrzeug, weil mehrere Spieler
-- dasselbe Modell besitzen koennen (FuelService/DynoService keyen nur nach ID).
function PlayerStore:vehicleKey(userId: any, vehicleId: string): string
	return string.format("%s:%s", toKey(userId), vehicleId)
end

function PlayerStore:refreshMoney(userId: any): number
	local view = self._views[toKey(userId)]
	if view == nil then
		return 0
	end
	view.money = self._economy:getBalance(userId)
	return view.money
end

function PlayerStore:commitMoney(userId: any): number
	local view = self._views[toKey(userId)]
	if view == nil then
		return 0
	end
	view.money = math.max(0, math.floor(view.money))
	view.schema.cash = view.money
	self._economy:setBalance(userId, view.money)
	return view.money
end

-- Schreibt beide Service-Sichten ins Schema zurueck.
function PlayerStore:sync(userId: any): any?
	local key = toKey(userId)
	local view = self._views[key]
	if view == nil then
		return nil
	end
	local profile = view.schema
	profile.cash = math.max(0, math.floor(view.money))
	profile.inventory = view.inventory
	profile.vehicles.owned = view.vehicles
	profile.starterDiscountUsed = view.starterDiscountUsed == true
	if type(view.selectedVehicle) == "string" and view.selectedVehicle ~= "" then
		profile.vehicles.selected = view.selectedVehicle
	elseif profile.vehicles.selected == nil or profile.vehicles.selected == "" then
		profile.vehicles.selected = view.vehicles[1] or "bicycle"
	end
	local records = self._workshopVehicles[key]
	if records == nil then
		records = {}
		self._workshopVehicles[key] = records
	end
	local workshop = self._workshopProfiles[key]
	if workshop == nil then
		workshop = { inventory = view.inventory, vehicles = {} }
		self._workshopProfiles[key] = workshop
	end
	-- Neukaeufe erhalten einen Werkstatt-Record, damit Einbau/Lackierung
	-- sofort moeglich sind.
	for _, vehicleId in ipairs(view.vehicles) do
		if records[vehicleId] == nil then
			local record = { modelId = vehicleId, parts = {}, colors = {} }
			records[vehicleId] = record
			workshop.vehicles[vehicleId] = record
		end
	end
	local byVehicle: { [string]: any } = {}
	for vehicleId, record in pairs(records) do
		byVehicle[vehicleId] = {
			parts = copyMap(record.parts),
			colors = copyMap(record.colors),
		}
	end
	profile.parts.byVehicle = byVehicle
	local selectedRecord = records[profile.vehicles.selected]
	if selectedRecord ~= nil then
		profile.parts.installed = selectedRecord.parts
		profile.paints = selectedRecord.colors
	end
	self._economy:setBalance(userId, profile.cash)
	return profile
end

function PlayerStore:save(userId: any): (boolean, string?)
	local profile = self:sync(userId)
	if profile == nil then
		return false, "not loaded"
	end
	return self._profiles:save(userId)
end

function PlayerStore:saveAll(): (number, number)
	local saved = 0
	local failed = 0
	for key in pairs(self._views) do
		local ok = self:save(key)
		if ok then
			saved += 1
		else
			failed += 1
		end
	end
	return saved, failed
end

function PlayerStore:release(userId: any): (boolean, string?)
	local key = toKey(userId)
	if self._views[key] == nil then
		return true, nil
	end
	self:sync(userId)
	local ok, err = self._profiles:release(userId)
	if not ok then
		return false, err
	end
	self._views[key] = nil
	self._workshopProfiles[key] = nil
	self._workshopVehicles[key] = nil
	return true, nil
end

function PlayerStore:loadedCount(): number
	local count = 0
	for _key in pairs(self._views) do
		count += 1
	end
	return count
end

return PlayerStore
