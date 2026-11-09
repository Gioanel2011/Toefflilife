--!strict
-- VehicleService: Kauf, Besitzprüfung und Auswahl von Fahrzeugen.
-- Der einmalige Startrabatt gilt nur für das erste Mofa und wird
-- serverseitig atomar mit dem Kauf verbraucht (rejoin- und parallelfest).

export type CatalogEntry = {
	price: number,
	starterPrice: number?,
	discountPrice: number?,
	starterDiscountPrice: number?,
	kind: string?,
}

export type Catalog = { [string]: CatalogEntry }

export type Profile = { [string]: any }

export type Receipt = {
	vehicleId: string,
	pricePaid: number,
	discountApplied: boolean,
}

export type VehicleService = {
	_catalog: Catalog,
	_locks: { [any]: boolean },
}

local VehicleService = {}
VehicleService.__index = VehicleService

local STARTER_BIKE_ID = "bicycle"

local DEFAULT_CATALOG: Catalog = {
	bicycle = { price = 0, kind = "bicycle" },
	puch_maxi_s = { price = 1499, starterPrice = 799, kind = "moped" },
	piaggio_ciao = { price = 1399, starterPrice = 749, kind = "moped" },
}

local function copyCatalog(source: Catalog): Catalog
	local out: Catalog = {}
	for id, entry in pairs(source) do
		out[id] = {
			price = entry.price,
			starterPrice = entry.starterPrice,
			discountPrice = entry.discountPrice,
			starterDiscountPrice = entry.starterDiscountPrice,
			kind = entry.kind,
		}
	end
	return out
end

local function isMopedId(catalog: Catalog, vehicleId: string): boolean
	local entry = catalog[vehicleId]
	if entry then
		if entry.kind ~= nil then
			return entry.kind == "moped"
		end
	end
	return vehicleId == "puch_maxi_s" or vehicleId == "piaggio_ciao"
end

local function starterPriceFor(entry: CatalogEntry): number?
	if entry.starterPrice ~= nil then
		return entry.starterPrice
	end
	if entry.starterDiscountPrice ~= nil then
		return entry.starterDiscountPrice
	end
	if entry.discountPrice ~= nil then
		return entry.discountPrice
	end
	return nil
end

local function vehiclesMap(profile: Profile): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	local raw = profile["vehicles"]
	if type(raw) == "table" then
		-- Unterstützt Dict-Form { [id] = true } und Array-Form { [n] = id }.
		for key, value in pairs(raw :: any) do
			if type(key) == "string" and value == true then
				owned[key] = true
			elseif type(value) == "string" then
				owned[value] = true
			end
		end
	end
	return owned
end

local function writeOwnership(profile: Profile, vehicleId: string)
	local raw = profile["vehicles"]
	if type(raw) == "table" then
		-- Bevorzugt Dict-Form; Array-Form wird erkannt und ergänzt.
		local isArray = true
		for key, _ in pairs(raw :: any) do
			if type(key) ~= "number" then
				isArray = false
				break
			end
		end
		if isArray then
			for _, existing in ipairs(raw :: any) do
				if existing == vehicleId then
					return
				end
			end
			table.insert(raw :: any, vehicleId)
			return
		else
			(raw :: any)[vehicleId] = true
			return
		end
	end
	profile["vehicles"] = { [vehicleId] = true }
end

local function ownsAnyMoped(self: VehicleService, profile: Profile): boolean
	local owned = vehiclesMap(profile)
	for id, _ in pairs(owned) do
		if isMopedId(self._catalog, id) then
			return true
		end
	end
	return false
end

function VehicleService.new(catalog: Catalog?): VehicleService
	local self: VehicleService = setmetatable({}, VehicleService) :: any
	self._catalog = copyCatalog(catalog or DEFAULT_CATALOG)
	self._locks = {}
	return self
end

function VehicleService.hasStarterDiscountAvailable(self: VehicleService, profile: Profile): boolean
	if profile["starterDiscountUsed"] == true then
		return false
	end
	if ownsAnyMoped(self, profile) then
		return false
	end
	return true
end

function VehicleService.owns(_self: VehicleService, profile: Profile, vehicleId: string): boolean
	return vehiclesMap(profile)[vehicleId] == true
end

function VehicleService.getOwned(_self: VehicleService, profile: Profile): { string }
	local owned = vehiclesMap(profile)
	local list: { string } = {}
	for id, _ in pairs(owned) do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

function VehicleService.getSelected(_self: VehicleService, profile: Profile): string?
	local selected = profile["selectedVehicle"]
	if type(selected) == "string" then
		return selected
	end
	return nil
end

function VehicleService.getPrice(self: VehicleService, profile: Profile, vehicleId: string): (number?, boolean, string?)
	local entry = self._catalog[vehicleId]
	if entry == nil then
		return nil, false, "unknown_vehicle"
	end
	if type(entry.price) ~= "number" then
		return nil, false, "invalid_catalog"
	end
	local discountEligible = isMopedId(self._catalog, vehicleId)
		and profile["starterDiscountUsed"] ~= true
		and not ownsAnyMoped(self, profile)
		and starterPriceFor(entry) ~= nil
	if discountEligible then
		return starterPriceFor(entry) :: number, true, nil
	end
	return entry.price, false, nil
end

function VehicleService.ensureStarterBike(_self: VehicleService, profile: Profile): boolean
	if next(vehiclesMap(profile)) ~= nil then
		if profile["selectedVehicle"] == nil then
			-- Bestehender Besitz ohne Auswahl: erstes Fahrzeug wählen.
			local owned = vehiclesMap(profile)
			local first: string? = nil
			for id, _ in pairs(owned) do
				if first == nil or id < (first :: string) then
					first = id
				end
			end
			profile["selectedVehicle"] = first
		end
		return false
	end
	profile["vehicles"] = { [STARTER_BIKE_ID] = true }
	profile["selectedVehicle"] = STARTER_BIKE_ID
	if type(profile["money"]) ~= "number" then
		profile["money"] = 0
	end
	return true
end

local function lockKeyFor(profile: Profile, userId: any): any
	if userId ~= nil then
		return userId
	end
	return profile
end

function VehicleService.isLocked(self: VehicleService, profile: Profile, userId: any?): boolean
	return self._locks[lockKeyFor(profile, userId)] == true
end

function VehicleService.unlock(self: VehicleService, profile: Profile, userId: any?)
	self._locks[lockKeyFor(profile, userId)] = nil
end

function VehicleService.purchase(
	self: VehicleService,
	profile: Profile,
	vehicleId: string,
	userId: any?
): (boolean, any)
	if type(vehicleId) ~= "string" or vehicleId == "" then
		return false, "invalid_vehicle"
	end
	local entry = self._catalog[vehicleId]
	if entry == nil then
		return false, "unknown_vehicle"
	end
	if type(entry.price) ~= "number" or entry.price < 0 then
		return false, "invalid_catalog"
	end

	local key = lockKeyFor(profile, userId)
	if self._locks[key] == true then
		return false, "busy"
	end
	self._locks[key] = true

	-- Atomarer Block: alle Prüfungen nach Lock erneut auswerten, dann
	-- Geld, Besitz und Rabattverbrauch in einem Schritt anwenden.
	local ok = false
	local result: any = "failed"
	if vehiclesMap(profile)[vehicleId] == true then
		result = "already_owned"
	else
		local discountEligible = isMopedId(self._catalog, vehicleId)
			and profile["starterDiscountUsed"] ~= true
			and not ownsAnyMoped(self, profile)
		local price = entry.price
		local discountApplied = false
		local reduced = starterPriceFor(entry)
		if discountEligible and reduced ~= nil then
			price = reduced :: number
			discountApplied = true
		end
		if type(price) ~= "number" or price < 0 then
			result = "invalid_catalog"
		else
			local money = profile["money"]
			if type(money) ~= "number" then
				result = "invalid_profile"
			elseif money < price then
				result = "insufficient_funds"
			else
				profile["money"] = money - price
				writeOwnership(profile, vehicleId)
				if discountApplied then
					profile["starterDiscountUsed"] = true
				end
				profile["selectedVehicle"] = vehicleId
				ok = true
				local receipt: Receipt = {
					vehicleId = vehicleId,
					pricePaid = price,
					discountApplied = discountApplied,
				}
				result = receipt
			end
		end
	end

	self._locks[key] = nil
	return ok, result
end

function VehicleService.select(self: VehicleService, profile: Profile, vehicleId: string): (boolean, string?)
	if type(vehicleId) ~= "string" or vehicleId == "" then
		return false, "invalid_vehicle"
	end
	if self._catalog[vehicleId] == nil then
		return false, "unknown_vehicle"
	end
	if vehiclesMap(profile)[vehicleId] ~= true then
		return false, "not_owned"
	end
	profile["selectedVehicle"] = vehicleId
	return true, nil
end

return VehicleService
