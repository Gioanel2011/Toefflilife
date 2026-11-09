-- RateLimiter: pro Spieler und Aktion begrenzte Anfragefenster
-- plus Schutz gegen doppelt parallel laufende Aktionen.
-- Keine globalen Variablen.

export type LimitConfig = {
	limit: number,
	window: number,
}

export type LimiterOptions = {
	defaultLimit: number?,
	defaultWindow: number?,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limiter = typeof(setmetatable(
	{} :: {
		_defaultLimit: number,
		_defaultWindow: number,
		_limits: { [string]: LimitConfig },
		_hits: { [string]: { number } },
		_locks: { [string]: boolean },
	},
	RateLimiter
))

local function normalizeLimit(limit: any, fallback: number): number
	if type(limit) ~= "number" or limit ~= limit or limit < 1 then
		return fallback
	end
	return math.floor(limit)
end

local function normalizeWindow(window: any, fallback: number): number
	if type(window) ~= "number" or window ~= window or window <= 0 then
		return fallback
	end
	return window
end

local function playerKey(player: any): string
	if type(player) == "table" then
		local userId = (player :: any).UserId
		if type(userId) == "number" and userId > 0 and userId == userId then
			return "user:" .. tostring(math.floor(userId))
		end
	elseif type(player) == "number" then
		if player > 0 and player == player then
			return "user:" .. tostring(math.floor(player))
		end
	elseif type(player) == "string" and player ~= "" then
		return "user:" .. player
	end
	return "user:unknown"
end

local function bucketKey(player: any, action: string): string
	return playerKey(player) .. "|" .. action
end

local function clockNow(): number
	return os.clock()
end

function RateLimiter.new(opts: LimiterOptions?): Limiter
	local o: LimiterOptions = opts or {}
	local self = setmetatable({
		_defaultLimit = normalizeLimit(o.defaultLimit, 30),
		_defaultWindow = normalizeWindow(o.defaultWindow, 1.0),
		_limits = {},
		_hits = {},
		_locks = {},
	}, RateLimiter)
	return self :: any
end

function RateLimiter:getLimit(action: string): LimitConfig
	local configured = self._limits[action]
	if configured ~= nil then
		return { limit = configured.limit, window = configured.window }
	end
	return { limit = self._defaultLimit, window = self._defaultWindow }
end

function RateLimiter:setLimit(action: string, limit: number, window: number): boolean
	if type(action) ~= "string" or action == "" then
		error("setLimit: action must be a non-empty string")
	end
	local cleanLimit = normalizeLimit(limit, 0)
	local cleanWindow = normalizeWindow(window, 0)
	if cleanLimit < 1 then
		error("setLimit: limit must be >= 1")
	end
	if cleanWindow <= 0 then
		error("setLimit: window must be > 0")
	end
	self._limits[action] = { limit = cleanLimit, window = cleanWindow }
	return true
end

function RateLimiter:clearLimit(action: string): boolean
	if type(action) ~= "string" then
		return false
	end
	if self._limits[action] == nil then
		return false
	end
	self._limits[action] = nil
	return true
end

-- Prueft ein Anfragefenster und verbraucht bei Erfolg einen Slot.
-- `nowOverride` ist nur fuer deterministische Tests gedacht.
function RateLimiter:check(player: any, action: any, nowOverride: number?): boolean
	if type(action) ~= "string" or action == "" then
		return false
	end
	if playerKey(player) == "user:unknown" then
		return false
	end
	local now: number
	if type(nowOverride) == "number" and (nowOverride :: number) == (nowOverride :: number) then
		now = nowOverride :: number
	else
		now = clockNow()
	end
	local config = self:getLimit(action)
	local key = bucketKey(player, action)
	local hits = self._hits[key]
	if hits == nil then
		hits = {}
		self._hits[key] = hits
	end
	local kept: { number } = {}
	for _, stamp in hits do
		if type(stamp) == "number" and now - stamp < config.window then
			table.insert(kept, stamp)
		end
	end
	if #kept >= config.limit then
		self._hits[key] = kept
		return false
	end
	table.insert(kept, now)
	self._hits[key] = kept
	return true
end

-- In-Flight-Schutz: verhindert doppelte parallel laufende
-- Kaeufe, Missionen oder Umbauten desselben Spielers.
function RateLimiter:acquire(player: any, action: any): boolean
	if type(action) ~= "string" or action == "" then
		return false
	end
	if playerKey(player) == "user:unknown" then
		return false
	end
	local key = bucketKey(player, action)
	if self._locks[key] == true then
		return false
	end
	self._locks[key] = true
	return true
end

function RateLimiter:release(player: any, action: any): boolean
	if type(action) ~= "string" or action == "" then
		return false
	end
	local key = bucketKey(player, action)
	if self._locks[key] ~= true then
		return false
	end
	self._locks[key] = nil
	return true
end

function RateLimiter:isLocked(player: any, action: any): boolean
	if type(action) ~= "string" or action == "" then
		return false
	end
	return self._locks[bucketKey(player, action)] == true
end

function RateLimiter:reset(): boolean
	self._hits = {}
	self._locks = {}
	return true
end

return RateLimiter
