--!strict
-- MissionService: Start- und Distanzmissionen mit fairer Fortschrittszählung.
-- Zählt Strecke nur bei plausibler Fahrt im eigenen Fahrzeug, lehnt
-- Teleport-Sprünge ab und zahlt jede Mission pro Spieler nur einmal aus.

local MissionService = {}
MissionService.__index = MissionService

export type MissionDefinition = {
	key: string,
	label: string,
	requiredDistance: number,
	reward: number,
	vehicleScope: string,
}

export type ProgressContext = {
	vehicleId: string?,
	isOwnVehicle: boolean?,
	speedKmh: number?,
	teleported: boolean?,
}

export type PlayerMissionState = {
	totalDistance: number,
	progress: { [string]: number },
	completed: { [string]: boolean },
	claimed: { [string]: boolean },
}

export type MissionServiceInstance = typeof(setmetatable(
	{} :: {
		_states: { [string]: PlayerMissionState },
	},
	MissionService
))

local MAX_SINGLE_DELTA = 250
local MAX_PLAUSIBLE_SPEED_KMH = 70
local MIN_PLAUSIBLE_SPEED_KMH = 0.5

local MISSIONS: { MissionDefinition } = {
	{
		key = "bike_starter_500m",
		label = "Erste Runde mit dem Fahrrad",
		requiredDistance = 500,
		reward = 50,
		vehicleScope = "bicycle",
	},
	{
		key = "moped_starter_2km",
		label = "Erste Runde mit dem Mofa",
		requiredDistance = 2000,
		reward = 150,
		vehicleScope = "moped",
	},
	{
		key = "distance_10km",
		label = "10 km auf eigenen Rädern",
		requiredDistance = 10000,
		reward = 300,
		vehicleScope = "any",
	},
	{
		key = "distance_50km",
		label = "50 km Töffli-Legende",
		requiredDistance = 50000,
		reward = 1200,
		vehicleScope = "any",
	},
}

local function toKey(userId: string | number): string
	return tostring(userId)
end

local function findDefinition(missionKey: string): MissionDefinition?
	for _, def in ipairs(MISSIONS) do
		if def.key == missionKey then
			return def
		end
	end
	return nil
end

local function matchesScope(def: MissionDefinition, vehicleId: string?): boolean
	if def.vehicleScope == "any" then
		return true
	end
	if vehicleId == nil then
		return false
	end
	if def.vehicleScope == "bicycle" then
		return vehicleId == "bicycle"
	end
	if def.vehicleScope == "moped" then
		return vehicleId == "moped" or vehicleId == "puch_maxi_s" or vehicleId == "piaggio_ciao"
	end
	return false
end

function MissionService.new(): MissionServiceInstance
	local self = {
		_states = {},
	}
	return setmetatable(self, MissionService)
end

function MissionService.getMissions(): { MissionDefinition }
	local copy: { MissionDefinition } = {}
	for i, def in ipairs(MISSIONS) do
		copy[i] = {
			key = def.key,
			label = def.label,
			requiredDistance = def.requiredDistance,
			reward = def.reward,
			vehicleScope = def.vehicleScope,
		}
	end
	return copy
end

function MissionService.getDefinition(missionKey: string): MissionDefinition?
	return findDefinition(missionKey)
end

function MissionService._getState(self: MissionServiceInstance, userId: string | number): PlayerMissionState
	local key = toKey(userId)
	local state = self._states[key]
	if state == nil then
		state = {
			totalDistance = 0,
			progress = {},
			completed = {},
			claimed = {},
		}
		for _, def in ipairs(MISSIONS) do
			state.progress[def.key] = 0
		end
		self._states[key] = state
	end
	return state
end

function MissionService.getState(self: MissionServiceInstance, userId: string | number): PlayerMissionState
	local state = self:_getState(userId)
	local snapshot: PlayerMissionState = {
		totalDistance = state.totalDistance,
		progress = {},
		completed = {},
		claimed = {},
	}
	for k, v in pairs(state.progress) do
		snapshot.progress[k] = v
	end
	for k, v in pairs(state.completed) do
		snapshot.completed[k] = v
	end
	for k, v in pairs(state.claimed) do
		snapshot.claimed[k] = v
	end
	return snapshot
end

-- Zählt eine gefahrene Teilstrecke. Gibt (accepted, reason) zurück.
function MissionService.addDistance(
	self: MissionServiceInstance,
	userId: string | number,
	deltaMeters: number,
	context: ProgressContext?
): (boolean, string)
	if type(deltaMeters) ~= "number" then
		return false, "invalid_delta"
	end
	if deltaMeters ~= deltaMeters or deltaMeters == math.huge or deltaMeters == -math.huge then
		return false, "invalid_delta"
	end
	if deltaMeters <= 0 then
		return false, "invalid_delta"
	end
	if deltaMeters > MAX_SINGLE_DELTA then
		return false, "teleport_rejected"
	end

	local ctx: ProgressContext = context or {}
	if ctx.teleported == true then
		return false, "teleport_rejected"
	end
	if ctx.isOwnVehicle ~= true then
		return false, "foreign_vehicle"
	end

	local vehicleId: string? = ctx.vehicleId
	if vehicleId == nil or vehicleId == "" then
		return false, "missing_vehicle"
	end

	local speed = ctx.speedKmh
	if speed ~= nil then
		if type(speed) ~= "number" then
			return false, "implausible_speed"
		end
		if speed ~= speed or speed == math.huge or speed == -math.huge then
			return false, "implausible_speed"
		end
		if speed < MIN_PLAUSIBLE_SPEED_KMH or speed > MAX_PLAUSIBLE_SPEED_KMH then
			return false, "implausible_speed"
		end
	end

	local state = self:_getState(userId)
	state.totalDistance += deltaMeters

	for _, def in ipairs(MISSIONS) do
		if matchesScope(def, vehicleId) then
			local current = state.progress[def.key] or 0
			local nextValue = current + deltaMeters
			if nextValue > def.requiredDistance then
				nextValue = def.requiredDistance
			end
			state.progress[def.key] = nextValue
			if nextValue >= def.requiredDistance then
				state.completed[def.key] = true
			end
		end
	end

	return true, "accepted"
end

function MissionService.isCompleted(self: MissionServiceInstance, userId: string | number, missionKey: string): boolean
	local state = self:_getState(userId)
	return state.completed[missionKey] == true
end

function MissionService.isClaimed(self: MissionServiceInstance, userId: string | number, missionKey: string): boolean
	local state = self:_getState(userId)
	return state.claimed[missionKey] == true
end

-- Zahlt eine abgeschlossene Mission genau einmal aus.
-- addFunds(reward) ist ein optionaler Auszahlungshook (z.B. EconomyService).
-- Gibt (ok, info) zurück; info enthält reward oder reason.
function MissionService.claimReward(
	self: MissionServiceInstance,
	userId: string | number,
	missionKey: string,
	addFunds: ((amount: number) -> ())?
): (boolean, { reward: number } | { reason: string })
	local def = findDefinition(missionKey)
	if def == nil then
		return false, { reason = "unknown_mission" }
	end

	local state = self:_getState(userId)
	if state.claimed[missionKey] == true then
		return false, { reason = "already_claimed" }
	end
	if state.completed[missionKey] ~= true then
		return false, { reason = "not_completed" }
	end

	if addFunds ~= nil then
		local ok, err = pcall(addFunds, def.reward)
		if not ok then
			return false, { reason = "payout_failed" }
		end
		_ = err
	end

	state.claimed[missionKey] = true
	return true, { reward = def.reward }
end

return MissionService
