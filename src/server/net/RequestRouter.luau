-- RequestRouter: serverseitiger Router mit Handler-Registrierung,
-- Typpruefung, Spielerzuordnung und sicheren Fehlerantworten.
-- Keine globalen Variablen.

local RemoteProtocol = require("../../shared/net/RemoteProtocol")
local RateLimiter = require("../../shared/net/RateLimiter")

type Handler = (player: any, payload: any) -> any

local RequestRouter = {}
RequestRouter.__index = RequestRouter

export type Router = typeof(setmetatable(
	{} :: { _handlers: { [string]: Handler }, _limiter: any },
	RequestRouter
))

local function invalidPlayer(player: any): boolean
	if type(player) ~= "table" then
		return true
	end
	local userId = (player :: any).UserId
	if type(userId) ~= "number" then
		return true
	end
	if userId <= 0 or userId ~= userId then
		return true
	end
	return false
end

local function fail(code: string): { ok: boolean, code: string, message: string }
	local message = "request rejected"
	if code == "unknown_action" then
		message = "unknown action"
	elseif code == "invalid_payload" then
		message = "invalid payload"
	elseif code == "invalid_player" then
		message = "invalid player"
	elseif code == "handler_error" then
		message = "handler failed"
	elseif code == "rate_limited" then
		message = "too many requests"
	elseif code == "busy" then
		message = "request in progress"
	end
	return { ok = false, code = code, message = message }
end

function RequestRouter.new(limiter: any?): Router
	local activeLimiter = limiter
	if activeLimiter == nil then
		activeLimiter = RateLimiter.new()
	end
	local self = setmetatable({ _handlers = {}, _limiter = activeLimiter }, RequestRouter)
	return self :: any
end

function RequestRouter:setRateLimiter(limiter: any): boolean
	if type(limiter) ~= "table" then
		error("setRateLimiter: limiter must be a table")
	end
	if type((limiter :: any).check) ~= "function" then
		error("setRateLimiter: limiter must provide check()")
	end
	if type((limiter :: any).acquire) ~= "function" then
		error("setRateLimiter: limiter must provide acquire()")
	end
	if type((limiter :: any).release) ~= "function" then
		error("setRateLimiter: limiter must provide release()")
	end
	self._limiter = limiter
	return true
end

function RequestRouter:getRateLimiter(): any
	return self._limiter
end

function RequestRouter:setRateLimit(action: string, limit: number, window: number): boolean
	if self._limiter == nil or type((self._limiter :: any).setLimit) ~= "function" then
		error("setRateLimit: active limiter does not support setLimit()")
	end
	local anyLimiter: any = self._limiter
	anyLimiter:setLimit(action, limit, window)
	return true
end

function RequestRouter:register(action: string, handler: Handler): boolean
	if type(action) ~= "string" or action == "" then
		error("register: action must be a non-empty string")
	end
	if type(handler) ~= "function" then
		error("register: handler must be a function")
	end
	if self._handlers[action] ~= nil then
		error("register: handler already registered")
	end
	self._handlers[action] = handler
	return true
end

function RequestRouter:unregister(action: string): boolean
	if type(action) ~= "string" then
		return false
	end
	if self._handlers[action] == nil then
		return false
	end
	self._handlers[action] = nil
	return true
end

function RequestRouter:hasHandler(action: any): boolean
	if type(action) ~= "string" then
		return false
	end
	return self._handlers[action] ~= nil
end

function RequestRouter:handle(player: any, action: any, payload: any): any
	if invalidPlayer(player) then
		return fail("invalid_player")
	end
	if type(action) ~= "string" or self._handlers[action] == nil then
		return fail("unknown_action")
	end
	if type(payload) ~= "table" then
		return fail("invalid_payload")
	end
	if RemoteProtocol.isKnownAction(action) then
		local valid, _ = RemoteProtocol.validatePayload(action, payload)
		if not valid then
			return fail("invalid_payload")
		end
	end
	local handler = self._handlers[action]
	local limiter = self._limiter
	if limiter ~= nil then
		local allowed = false
		local acquireOk = false
		local checkOk, checkResult = pcall(function()
			return (limiter :: any):check(player, action)
		end)
		allowed = checkOk and checkResult == true
		if not allowed then
			return fail("rate_limited")
		end
		local acquireCallOk, acquireResult = pcall(function()
			return (limiter :: any):acquire(player, action)
		end)
		acquireOk = acquireCallOk and acquireResult == true
		if not acquireOk then
			return fail("busy")
		end
		local ok, result = pcall(handler, player, payload)
		local anyLimiter: any = limiter
		pcall(function()
			anyLimiter:release(player, action)
		end)
		if not ok then
			return fail("handler_error")
		end
		return { ok = true, data = result }
	end
	local ok, result = pcall(handler, player, payload)
	if not ok then
		return fail("handler_error")
	end
	return { ok = true, data = result }
end

return RequestRouter
