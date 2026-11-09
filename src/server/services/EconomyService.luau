--!strict
-- EconomyService: server-authoritative Guthabenverwaltung.
-- Nur fuer den Server. Clients erhalten Zugriff ausschliesslich ueber
-- validierte Router-Handler, die Requestor und Ziel abgleichen.

local EconomyService = {}
EconomyService.__index = EconomyService

export type EconomyService = typeof(setmetatable(
	{} :: {
		_balances: { [string]: number },
		_processed: { [string]: { [string]: { kind: string, amount: number, balance: number } } },
	},
	EconomyService
))

local function normalizeUserId(userId: any): string?
	if typeof(userId) == "number" then
		if userId ~= math.floor(userId) or userId <= 0 then
			return nil
		end
		return tostring(userId)
	elseif typeof(userId) == "string" then
		if #userId == 0 then
			return nil
		end
		return userId
	end
	return nil
end

local function isValidAmount(amount: any): boolean
	if typeof(amount) ~= "number" then
		return false
	end
	if amount ~= amount then
		return false
	end
	if amount == math.huge or amount == -math.huge then
		return false
	end
	if math.floor(amount) ~= amount then
		return false
	end
	if amount <= 0 then
		return false
	end
	return true
end

local function isValidTransactionId(transactionId: any): boolean
	if typeof(transactionId) ~= "string" then
		return false
	end
	if #transactionId == 0 then
		return false
	end
	return true
end

function EconomyService.new(): EconomyService
	local self = setmetatable({
		_balances = {},
		_processed = {},
	}, EconomyService)
	return (self :: any) :: EconomyService
end

function EconomyService:getBalance(userId: number | string): number
	local key = normalizeUserId(userId)
	assert(key ~= nil, "invalid userId")
	local balance = self._balances[(key :: any) :: string]
	if balance == nil then
		return 0
	end
	return balance
end

function EconomyService:getBalanceFor(requestorUserId: number | string, targetUserId: number | string): (number?, string?)
	local requestorKey = normalizeUserId(requestorUserId)
	local targetKey = normalizeUserId(targetUserId)
	if requestorKey == nil or targetKey == nil then
		return nil, "invalid_user"
	end
	if requestorKey ~= targetKey then
		return nil, "access_denied"
	end
	return self:getBalance(targetKey), nil
end

function EconomyService:setBalance(userId: number | string, amount: number): number
	local key = normalizeUserId(userId)
	assert(key ~= nil, "invalid userId")
	assert(typeof(amount) == "number", "invalid amount")
	assert(amount == math.floor(amount), "amount must be an integer")
	assert(amount >= 0, "balance must not be negative")
	assert(amount ~= math.huge, "amount out of range")
	local resolved = key :: string
	self._balances[resolved] = amount
	return amount
end

function EconomyService:hasProcessed(userId: number | string, transactionId: string): boolean
	local key = normalizeUserId(userId)
	if key == nil then
		return false
	end
	local perUser = self._processed[key]
	if perUser == nil then
		return false
	end
	return perUser[transactionId] ~= nil
end

function EconomyService:credit(userId: number | string, amount: number, transactionId: string): (boolean, number | string)
	local key = normalizeUserId(userId)
	if key == nil then
		return false, "invalid_user"
	end
	if not isValidAmount(amount) then
		return false, "invalid_amount"
	end
	if not isValidTransactionId(transactionId) then
		return false, "invalid_transaction_id"
	end
	local resolved = key :: string

	local perUser = self._processed[resolved]
	if perUser == nil then
		perUser = {}
		self._processed[resolved] = perUser
	end

	local existing = perUser[transactionId]
	if existing ~= nil then
		if existing.kind == "credit" and existing.amount == amount then
			return true, existing.balance
		end
		return false, "duplicate_transaction_id"
	end

	local current = self._balances[resolved]
	if current == nil then
		current = 0
	end
	local nextBalance = current + amount
	self._balances[resolved] = nextBalance
	perUser[transactionId] = { kind = "credit", amount = amount, balance = nextBalance }
	return true, nextBalance
end

function EconomyService:debit(userId: number | string, amount: number, transactionId: string): (boolean, number | string)
	local key = normalizeUserId(userId)
	if key == nil then
		return false, "invalid_user"
	end
	if not isValidAmount(amount) then
		return false, "invalid_amount"
	end
	if not isValidTransactionId(transactionId) then
		return false, "invalid_transaction_id"
	end
	local resolved = key :: string

	local perUser = self._processed[resolved]
	if perUser == nil then
		perUser = {}
		self._processed[resolved] = perUser
	end

	local existing = perUser[transactionId]
	if existing ~= nil then
		if existing.kind == "debit" and existing.amount == amount then
			return true, existing.balance
		end
		return false, "duplicate_transaction_id"
	end

	local current = self._balances[resolved]
	if current == nil then
		current = 0
	end
	if current < amount then
		return false, "insufficient_funds"
	end
	local nextBalance = current - amount
	self._balances[resolved] = nextBalance
	perUser[transactionId] = { kind = "debit", amount = amount, balance = nextBalance }
	return true, nextBalance
end

return EconomyService
