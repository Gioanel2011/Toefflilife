--!strict
-- ShopService: Laptop-Bestellung und Ladenkauf (server-autoritativ).
-- Katalogabruf, Bestellung per Laptop und Direktkauf im Toeffli-Laden.
-- Preise stammen immer vom Serverkatalog. Bestellungen landen nur im
-- Inventar. Einbau, Ausbau, Lackierung und Tuning werden hier bewusst
-- nicht ausgeloest (dafuer ist WorkshopService zustaendig).

export type PartEntry = {
	id: string,
	price: number,
	slot: string?,
	models: { string }?,
}

export type Profile = {
	money: number,
	inventory: { [string]: number },
}

export type ShopOptions = {
	catalog: { [string]: PartEntry }?,
	profiles: { [number | string]: Profile }?,
	isNearStore: ((userId: number | string) -> boolean)?,
}

local ShopService = {}
ShopService.__index = ShopService

export type Shop = typeof(setmetatable(
	{} :: {
		_catalog: { [string]: PartEntry },
		_profiles: { [number | string]: Profile },
		_isNearStore: (userId: number | string) -> boolean,
		_processed: { [string]: boolean },
	},
	ShopService
))

local function defaultIsNearStore(_userId: number | string): boolean
	return false
end

local function copyPart(entry: PartEntry): PartEntry
	local modelsCopy: { string }? = nil
	if entry.models ~= nil then
		modelsCopy = {}
		for i, modelId in ipairs(entry.models :: { string }) do
			(modelsCopy :: { string })[i] = modelId
		end
	end
	return {
		id = entry.id,
		price = entry.price,
		slot = entry.slot,
		models = modelsCopy,
	}
end

function ShopService.new(options: ShopOptions?): Shop
	local opts = options or {}
	local catalog: { [string]: PartEntry } = {}
	if opts.catalog ~= nil then
		for partId, entry in pairs(opts.catalog :: { [string]: PartEntry }) do
			if type(partId) == "string" and type(entry) == "table" then
				catalog[partId] = copyPart(entry :: PartEntry)
			end
		end
	end
	local self = setmetatable({
		_catalog = catalog,
		_profiles = if opts.profiles ~= nil then opts.profiles else {},
		_isNearStore = if opts.isNearStore ~= nil then opts.isNearStore else defaultIsNearStore,
		_processed = {},
	}, ShopService)
	return (self :: any) :: Shop
end

function ShopService.getPart(self: Shop, partId: string): PartEntry?
	if type(partId) ~= "string" then
		return nil
	end
	local entry = self._catalog[partId]
	if entry == nil then
		return nil
	end
	return copyPart(entry)
end

function ShopService.getPrice(self: Shop, partId: string): number?
	local entry = self._catalog[partId]
	if entry == nil then
		return nil
	end
	return entry.price
end

function ShopService.getCatalog(self: Shop): { PartEntry }
	local list: { PartEntry } = {}
	for _, entry in pairs(self._catalog) do
		table.insert(list, copyPart(entry))
	end
	table.sort(list, function(a: PartEntry, b: PartEntry): boolean
		return a.id < b.id
	end)
	return list
end

function ShopService.isCompatibleWith(self: Shop, partId: string, vehicleId: string): boolean
	local entry = self._catalog[partId]
	if entry == nil then
		return false
	end
	if entry.models == nil or #(entry.models :: { string }) == 0 then
		return true
	end
	for _, modelId in ipairs(entry.models :: { string }) do
		if modelId == vehicleId then
			return true
		end
	end
	return false
end

function ShopService.getInventory(self: Shop, userId: number | string): { [string]: number }
	local profile = self._profiles[userId]
	if profile == nil then
		return {}
	end
	local copy: { [string]: number } = {}
	if profile.inventory ~= nil then
		for partId, count in pairs(profile.inventory) do
			copy[partId] = count
		end
	end
	return copy
end

local function claimTransaction(self: Shop, txId: string?): boolean
	if txId == nil or txId == "" then
		return false
	end
	if self._processed[txId :: string] == true then
		return true
	end
	self._processed[txId :: string] = true
	return false
end

local function buyInternal(
	self: Shop,
	userId: number | string,
	partId: string,
	txId: string?,
	requireStore: boolean
): (boolean, string)
	if type(partId) ~= "string" or partId == "" then
		return false, "unknown_part"
	end
	local entry = self._catalog[partId]
	if entry == nil then
		return false, "unknown_part"
	end
	if type(entry.price) ~= "number" or entry.price < 0 then
		return false, "invalid_price"
	end
	local profile = self._profiles[userId]
	if profile == nil then
		return false, "unknown_profile"
	end
	if requireStore then
		local ok, near = pcall(self._isNearStore, userId)
		if not ok or near ~= true then
			return false, "not_near_store"
		end
	end
	if txId ~= nil and txId ~= "" and self._processed[txId :: string] == true then
		return false, "duplicate_transaction"
	end
	if type(profile.money) ~= "number" then
		return false, "invalid_profile"
	end
	if profile.money < entry.price then
		return false, "insufficient_funds"
	end
	claimTransaction(self, txId)
	profile.money -= entry.price
	if profile.inventory == nil then
		profile.inventory = {}
	end
	profile.inventory[partId] = (profile.inventory[partId] or 0) + 1
	return true, "ok"
end

-- Laptop-Bestellung: keine Naehenpruefung, landet im Inventar.
function ShopService.orderPart(self: Shop, userId: number | string, partId: string, txId: string?): (boolean, string)
	return buyInternal(self, userId, partId, txId, false)
end

-- Direktkauf im Toeffli-Laden: nur in Ladennähe, landet im Inventar.
function ShopService.buyFromStore(self: Shop, userId: number | string, partId: string, txId: string?): (boolean, string)
	return buyInternal(self, userId, partId, txId, true)
end

return ShopService
