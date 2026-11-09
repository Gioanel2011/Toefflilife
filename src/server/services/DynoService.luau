--!strict
-- DynoService: server-validated dynamometer (Pruefstand) runs.
-- Only the owner's correctly mounted moped inside the shop may run.
-- Stats always come from the shared StatsCalculator; client values are never trusted.
-- Stores the last result per vehicle.

local DynoService = {}
DynoService.__index = DynoService

export type VehicleBase = { [string]: any }
export type DynoState = { [string]: any }
export type DynoResult = { [string]: any }

local SharedCalculator: any = nil
do
	local ok, mod = pcall(function()
		-- From src/server/services/ -> src/shared/vehicle/StatsCalculator
		return require("../../shared/vehicle/StatsCalculator")
	end)
	if ok and mod ~= nil then
		SharedCalculator = mod
	end
end

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

local function isBicycleBase(base: any): boolean
	if type(base) ~= "table" then
		return false
	end
	local idFields = { base.id, base.vehicleId, base.modelId, base.name }
	for _, field in ipairs(idFields) do
		if type(field) == "string" then
			local lower = string.lower(field)
			if lower == "bicycle" or lower == "fahrrad" or lower == "bike" then
				return true
			end
			if string.find(lower, "bicycle", 1, true) ~= nil then
				return true
			end
			if string.find(lower, "fahrrad", 1, true) ~= nil then
				return true
			end
		end
	end
	if base.kind == "bicycle" or base.kind == "bike" or base.category == "bicycle" then
		return true
	end
	if base.motorized == false or base.isMotorized == false or base.hasMotor == false or base.hasEngine == false then
		return true
	end
	return false
end

local function resolveCalculate(explicit: any): ((any, any) -> any)?
	if type(explicit) == "function" then
		return explicit
	end
	if type(explicit) == "table" then
		for _, key in ipairs({ "calculate", "calculateStats", "compute", "computeStats", "getStats" }) do
			if type(explicit[key]) == "function" then
				local fn = explicit[key]
				return function(base: any, parts: any): any
					return fn(explicit, base, parts)
				end
			end
		end
		local mt = getmetatable(explicit)
		if mt ~= nil and type(mt.__call) == "function" then
			return function(base: any, parts: any): any
				return explicit(base, parts)
			end
		end
	end
	if SharedCalculator ~= nil then
		if type(SharedCalculator) == "function" then
			return SharedCalculator
		end
		if type(SharedCalculator) == "table" then
			for _, key in ipairs({ "calculate", "calculateStats", "compute", "computeStats", "getStats" }) do
				local fn = SharedCalculator[key]
				if type(fn) == "function" then
					return function(base: any, parts: any): any
						return fn(SharedCalculator, base, parts)
					end
				end
			end
			local mt = getmetatable(SharedCalculator)
			if mt ~= nil and type(mt.__call) == "function" then
				return function(base: any, parts: any): any
					return SharedCalculator(base, parts)
				end
			end
		end
	end
	return nil
end

local function shallowCopy(input: any): any
	if type(input) ~= "table" then
		return input
	end
	return table.clone(input)
end

function DynoService.new(deps: any?)
	local self: any = setmetatable({}, DynoService)
	deps = deps or {}
	self._explicitCalculate = deps.calculate
	self._explicitCalculator = deps.statsCalculator or deps.calculator
	self._isOwner = deps.isOwner
	self._getSetupFn = deps.getSetup
	self._getDynoStateFn = deps.getDynoState
	self._clock = deps.clock
	self._vehicles = {}
	self._dynoStates = {}
	self._lastResults = {}
	self._busy = {}
	return self
end

function DynoService:RegisterVehicle(vehicleId: string, ownerId: any, base: VehicleBase, parts: any)
	assert(isNonEmptyString(vehicleId), "RegisterVehicle: vehicleId must be a non-empty string")
	assert(ownerId ~= nil, "RegisterVehicle: ownerId required")
	assert(type(base) == "table", "RegisterVehicle: base must be a table")
	self._vehicles[vehicleId] = {
		ownerId = ownerId,
		base = base,
		parts = parts,
	}
end

function DynoService:SetDynoState(vehicleId: string, state: DynoState)
	assert(isNonEmptyString(vehicleId), "SetDynoState: vehicleId must be a non-empty string")
	assert(type(state) == "table", "SetDynoState: state must be a table")
	self._dynoStates[vehicleId] = shallowCopy(state)
end

function DynoService:_checkOwner(playerId: any, vehicleId: string): boolean
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

function DynoService:_getSetup(vehicleId: string): (any?, string?)
	if type(self._getSetupFn) == "function" then
		local ok, setup = pcall(self._getSetupFn, vehicleId)
		if ok and type(setup) == "table" then
			return setup, ""
		end
		return nil, "UnknownVehicle"
	end
	local entry = self._vehicles[vehicleId]
	if entry == nil then
		return nil, "UnknownVehicle"
	end
	return { base = entry.base, parts = entry.parts }, ""
end

function DynoService:_getState(vehicleId: string): any
	if type(self._getDynoStateFn) == "function" then
		local ok, state = pcall(self._getDynoStateFn, vehicleId)
		if ok and type(state) == "table" then
			return state
		end
		return nil
	end
	return self._dynoStates[vehicleId]
end

local function stateFlag(state: any, keys: { string }): boolean?
	for _, key in ipairs(keys) do
		if state[key] ~= nil then
			return state[key] == true
		end
	end
	return nil
end

function DynoService:_checkDynoReady(vehicleId: string): (boolean, string)
	local state = self:_getState(vehicleId)
	if type(state) ~= "table" then
		return false, "NotOnDyno"
	end
	-- Must be inside the shop / at the dyno.
	local inShop = stateFlag(state, { "inShop", "insideShop", "atShop", "inStore" })
	if inShop == false then
		return false, "NotInShop"
	end
	if inShop == nil then
		-- Fall back to explicit shop dyno flag.
		local onDyno = stateFlag(state, { "onDyno", "isOnDyno", "mounted", "isMounted", "jackedUp", "aufgebockt" })
		if onDyno ~= true then
			return false, "NotInShop"
		end
	end
	local onDyno = stateFlag(state, { "onDyno", "isOnDyno", "mounted", "isMounted", "jackedUp", "aufgebockt" })
	if onDyno == false then
		return false, "NotOnDyno"
	end
	if onDyno == nil then
		return false, "NotOnDyno"
	end
	local stationary = stateFlag(state, { "stationary", "isStationary", "standing", "parked" })
	if stationary == false then
		return false, "VehicleMoving"
	end
	local engineOff = stateFlag(state, { "engineOff", "isEngineOff", "motorOff", "motorAus" })
	if engineOff == false then
		-- Engine must be off before the run starts; the dyno run itself
		-- controls the engine afterwards.
		return false, "EngineRunning"
	end
	local rider = stateFlag(state, { "hasRider", "isOccupied", "occupied", "driverPresent" })
	if rider == true then
		return false, "Occupied"
	end
	if inShop == nil and onDyno == true then
		-- onDyno implies shop dyno; accept.
		return true, ""
	end
	if inShop == true and onDyno == true then
		return true, ""
	end
	return false, "NotOnDyno"
end

function DynoService:_now(): number
	if type(self._clock) == "function" then
		local ok, value = pcall(self._clock)
		if ok and type(value) == "number" then
			return value
		end
	end
	return os.clock()
end

-- Starts a dyno run. Only IDs are accepted; any client-supplied stats
-- argument is ignored to prevent manipulation.
function DynoService:StartRun(playerId: any, vehicleId: string, _clientStats: any?): (boolean, any)
	if playerId == nil or (type(playerId) ~= "string" and type(playerId) ~= "number") then
		return false, "InvalidPlayer"
	end
	if type(playerId) == "string" and playerId == "" then
		return false, "InvalidPlayer"
	end
	if not isNonEmptyString(vehicleId) then
		return false, "InvalidVehicle"
	end
	if self._busy[vehicleId] == true then
		return false, "Busy"
	end
	if not self:_checkOwner(playerId, vehicleId) then
		return false, "NotOwner"
	end
	local setup, setupErr = self:_getSetup(vehicleId)
	if setup == nil then
		return false, setupErr or "UnknownVehicle"
	end
	local base = setup.base
	local parts = setup.parts
	if type(base) ~= "table" then
		return false, "UnknownVehicle"
	end
	if isBicycleBase(base) then
		return false, "BicycleNotAllowed"
	end
	local ready, reason = self:_checkDynoReady(vehicleId)
	if not ready then
		return false, reason
	end
	local calculate = resolveCalculate(self._explicitCalculate) or resolveCalculate(self._explicitCalculator)
	if calculate == nil then
		return false, "NoCalculator"
	end
	self._busy[vehicleId] = true
	local ok, stats = pcall(calculate, base, parts)
	self._busy[vehicleId] = nil
	if not ok then
		return false, "CalculatorFailed"
	end
	if type(stats) ~= "table" then
		return false, "CalculatorFailed"
	end
	local result: { [string]: any } = shallowCopy(stats)
	result.vehicleId = vehicleId
	result.measuredAt = self:_now()
	self._lastResults[vehicleId] = shallowCopy(result)
	return true, shallowCopy(result)
end

function DynoService:GetLastResult(vehicleId: string): any?
	if not isNonEmptyString(vehicleId) then
		return nil
	end
	local stored = self._lastResults[vehicleId]
	if stored == nil then
		return nil
	end
	return shallowCopy(stored)
end

function DynoService:ClearResult(vehicleId: string)
	if isNonEmptyString(vehicleId) then
		self._lastResults[vehicleId] = nil
	end
end

return DynoService
