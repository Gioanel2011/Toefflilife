--!strict
-- FuelService: server-authoritative fuel for motorized vehicles.
-- Tracks tank content per vehicle, applies load-dependent consumption,
-- refuels only at gas stations with server-side charging, and offers a
-- fair anti-stranding rescue refill. Bicycles never consume or hold fuel.

local FuelService = {}
FuelService.__index = FuelService

export type VehicleEntry = { [string]: any }
export type RefuelResult = { [string]: any }

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

local function isValidPlayerId(playerId: any): boolean
	if playerId == nil then
		return false
	end
	if type(playerId) == "number" then
		return true
	end
	return isNonEmptyString(playerId)
end

local function clamp01(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function isBicycleModel(modelId: any, flags: any): boolean
	if type(flags) == "table" then
		if flags.isMotorized == false or flags.motorized == false then
			return true
		end
		if flags.hasMotor == false or flags.hasEngine == false then
			return true
		end
		if flags.kind == "bicycle" or flags.kind == "bike" or flags.category == "bicycle" then
			return true
		end
	end
	if type(modelId) == "string" then
		local lower = string.lower(modelId)
		if lower == "bicycle" or lower == "fahrrad" or lower == "bike" then
			return true
		end
		if string.find(lower, "bicycle", 1, true) ~= nil then
			return true
		end
		if string.find(lower, "fahrrad", 1, true) ~= nil then
			return true
		end
		if lower == "bike" or string.find(lower, "bike", 1, true) ~= nil then
			-- "bike" alone means bicycle; motorized models use distinct ids.
			if lower == "bike" or lower == "city-bike" or lower == "citybike" then
				return true
			end
		end
	end
	return false
end

local function roundToCents(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

local function shallowCopy(input: any): any
	if type(input) ~= "table" then
		return input
	end
	return table.clone(input)
end

function FuelService.new(deps: any?)
	local self: any = setmetatable({}, FuelService)
	deps = deps or {}
	self._pricePerLiter = deps.pricePerLiter
	if type(self._pricePerLiter) ~= "number" or self._pricePerLiter < 0 then
		self._pricePerLiter = 2.0
	end
	self._defaultTankVolume = deps.defaultTankVolume
	if type(self._defaultTankVolume) ~= "number" or self._defaultTankVolume <= 0 then
		self._defaultTankVolume = 3.0
	end
	self._baseConsumptionRate = deps.baseConsumptionRate
	if type(self._baseConsumptionRate) ~= "number" or self._baseConsumptionRate <= 0 then
		self._baseConsumptionRate = 0.005
	end
	self._rescueLiters = deps.rescueLiters
	if type(self._rescueLiters) ~= "number" or self._rescueLiters <= 0 then
		self._rescueLiters = 0.3
	end
	self._rescueCooldownSec = deps.rescueCooldownSec
	if type(self._rescueCooldownSec) ~= "number" or self._rescueCooldownSec < 0 then
		self._rescueCooldownSec = 300
	end
	self._strandedEpsilon = deps.strandedEpsilon
	if type(self._strandedEpsilon) ~= "number" or self._strandedEpsilon < 0 then
		self._strandedEpsilon = 0.05
	end
	self._isOwner = deps.isOwner
	self._isAtGasStation = deps.isAtGasStation
	self._debit = deps.debit
	self._balances = deps.balances
	self._clock = deps.clock
	self._vehicles = {}
	self._atStation = {}
	self._busy = {}
	self._processedTx = {}
	self._lastRescue = {}
	return self
end

function FuelService:RegisterVehicle(vehicleId: string, ownerId: any, opts: any?)
	assert(isNonEmptyString(vehicleId), "RegisterVehicle: vehicleId must be a non-empty string")
	assert(ownerId ~= nil, "RegisterVehicle: ownerId required")
	opts = opts or {}
	local modelId: any = opts.modelId or opts.vehicleModel or opts.id or "puch-maxi-s"
	local bicycle = isBicycleModel(modelId, opts)
	local capacity: number
	if bicycle then
		capacity = 0
	elseif type(opts.tankVolume) == "number" and opts.tankVolume > 0 then
		capacity = opts.tankVolume
	elseif type(opts.capacity) == "number" and opts.capacity > 0 then
		capacity = opts.capacity
	else
		capacity = self._defaultTankVolume
	end
	local rate: number = self._baseConsumptionRate
	if type(opts.consumptionRate) == "number" and opts.consumptionRate > 0 then
		rate = opts.consumptionRate
	end
	local fuel: number = capacity
	if type(opts.fuel) == "number" and opts.fuel == opts.fuel then
		fuel = math.clamp(opts.fuel, 0, capacity)
	end
	if bicycle then
		fuel = 0
	end
	self._vehicles[vehicleId] = {
		ownerId = ownerId,
		modelId = modelId,
		capacity = capacity,
		fuel = fuel,
		consumptionRate = rate,
		isBicycle = bicycle,
	}
end

function FuelService:SetAtGasStation(vehicleId: string, atStation: boolean)
	assert(isNonEmptyString(vehicleId), "SetAtGasStation: vehicleId must be a non-empty string")
	self._atStation[vehicleId] = atStation == true
end

-- Server-only helper for spawn/restore; never exposed to clients directly.
function FuelService:SetFuel(vehicleId: string, amount: number): boolean
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return false
	end
	if type(amount) ~= "number" or amount ~= amount then
		return false
	end
	entry.fuel = math.clamp(amount, 0, entry.capacity)
	return true
end

function FuelService:GetFuel(vehicleId: string): number?
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return nil
	end
	return entry.fuel
end

function FuelService:GetCapacity(vehicleId: string): number?
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return nil
	end
	return entry.capacity
end

function FuelService:GetPricePerLiter(): number
	return self._pricePerLiter
end

function FuelService:IsBicycleVehicle(vehicleId: string): boolean
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return false
	end
	return entry.isBicycle == true
end

function FuelService:IsEmpty(vehicleId: string): boolean
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return true
	end
	if entry.isBicycle == true then
		return true
	end
	return entry.fuel <= self._strandedEpsilon
end

function FuelService:_now(): number
	if type(self._clock) == "function" then
		local ok, value = pcall(self._clock)
		if ok and type(value) == "number" then
			return value
		end
	end
	return os.clock()
end

function FuelService:_checkOwner(playerId: any, vehicleId: string): boolean
	if type(self._isOwner) == "function" then
		local ok, result = pcall(self._isOwner, playerId, vehicleId)
		return ok and result == true
	end
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return false
	end
	return entry.ownerId == playerId
end

function FuelService:_checkStation(playerId: any, vehicleId: string): boolean
	if type(self._isAtGasStation) == "function" then
		local ok, result = pcall(self._isAtGasStation, playerId, vehicleId)
		return ok and result == true
	end
	return self._atStation[vehicleId] == true
end

function FuelService:_applyDebit(playerId: any, amount: number, transactionId: string?): (boolean, string?)
	if type(self._debit) == "function" then
		local ok, success, err = pcall(self._debit, playerId, amount, transactionId)
		if not ok then
			return false, "EconomyFailed"
		end
		if success == true then
			return true, nil
		end
		if type(err) == "string" and err ~= "" then
			return false, err
		end
		return false, "InsufficientFunds"
	end
	if type(self._balances) == "table" then
		local current = self._balances[playerId]
		if type(current) ~= "number" then
			return false, "UnknownPlayer"
		end
		if current < amount then
			return false, "InsufficientFunds"
		end
		self._balances[playerId] = roundToCents(current - amount)
		return true, nil
	end
	return false, "NoEconomy"
end

-- Applies load-dependent consumption. load01: 0 = idle, 1 = full load.
-- Returns consumed liters and remaining fuel. Bicycles always return 0.
function FuelService:Consume(vehicleId: string, dtSeconds: number, load01: number?): (number, number?)
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return 0, nil
	end
	if entry.isBicycle == true then
		return 0, 0
	end
	if type(dtSeconds) ~= "number" or dtSeconds ~= dtSeconds or dtSeconds <= 0 then
		return 0, entry.fuel
	end
	local load = clamp01(load01, 0.5)
	local rate: number = entry.consumptionRate
	if type(rate) ~= "number" or rate <= 0 then
		rate = self._baseConsumptionRate
	end
	local perSecond = rate * (0.4 + 1.6 * load)
	local wanted = perSecond * dtSeconds
	local consumed = math.min(wanted, entry.fuel)
	entry.fuel = entry.fuel - consumed
	if entry.fuel < 0 then
		entry.fuel = 0
	end
	return consumed, entry.fuel
end

-- Server-side refuel at a gas station. Only the filled amount is charged.
function FuelService:Refuel(playerId: any, vehicleId: string, litersRequested: number, opts: any?): (boolean, any)
	if not isValidPlayerId(playerId) then
		return false, "InvalidPlayer"
	end
	if not isNonEmptyString(vehicleId) then
		return false, "InvalidVehicle"
	end
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return false, "UnknownVehicle"
	end
	if entry.isBicycle == true then
		return false, "BicycleHasNoFuel"
	end
	if type(litersRequested) ~= "number" or litersRequested ~= litersRequested or litersRequested <= 0 then
		return false, "InvalidAmount"
	end
	if self._busy[vehicleId] == true then
		return false, "Busy"
	end
	if not self:_checkOwner(playerId, vehicleId) then
		return false, "NotOwner"
	end
	if not self:_checkStation(playerId, vehicleId) then
		return false, "NotAtGasStation"
	end
	local freeSpace = entry.capacity - entry.fuel
	if freeSpace <= 1e-9 then
		return false, "TankFull"
	end
	local fill = math.min(litersRequested, freeSpace)
	local cost = roundToCents(fill * self._pricePerLiter)
	local transactionId: string? = nil
	if type(opts) == "table" and isNonEmptyString(opts.transactionId) then
		transactionId = opts.transactionId
		local cached = self._processedTx[transactionId]
		if cached ~= nil then
			return true, shallowCopy(cached)
		end
	end
	self._busy[vehicleId] = true
	local debitOk, debitErr = self:_applyDebit(playerId, cost, transactionId)
	self._busy[vehicleId] = nil
	if not debitOk then
		return false, debitErr or "InsufficientFunds"
	end
	entry.fuel = math.min(entry.capacity, entry.fuel + fill)
	local result = {
		filled = fill,
		cost = cost,
		fuel = entry.fuel,
		capacity = entry.capacity,
	}
	if transactionId ~= nil then
		self._processedTx[transactionId] = shallowCopy(result)
	end
	return true, shallowCopy(result)
end

-- Fair solution against permanent stranding: a small free emergency refill
-- when the tank is (near-)empty. Cooldown prevents abuse; no station needed.
function FuelService:RescueRefill(playerId: any, vehicleId: string): (boolean, any)
	if not isValidPlayerId(playerId) then
		return false, "InvalidPlayer"
	end
	if not isNonEmptyString(vehicleId) then
		return false, "InvalidVehicle"
	end
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return false, "UnknownVehicle"
	end
	if entry.isBicycle == true then
		return false, "BicycleHasNoFuel"
	end
	if not self:_checkOwner(playerId, vehicleId) then
		return false, "NotOwner"
	end
	if entry.fuel > self._strandedEpsilon then
		return false, "NotStranded"
	end
	local now = self:_now()
	local last = self._lastRescue[vehicleId]
	if type(last) == "number" and now - last < self._rescueCooldownSec then
		return false, "RescueCooldown"
	end
	local fill = math.min(self._rescueLiters, entry.capacity - entry.fuel)
	if fill <= 0 then
		return false, "TankFull"
	end
	entry.fuel = entry.fuel + fill
	self._lastRescue[vehicleId] = now
	return true,
		shallowCopy({
			filled = fill,
			cost = 0,
			fuel = entry.fuel,
			capacity = entry.capacity,
			rescue = true,
		})
end

return FuelService
