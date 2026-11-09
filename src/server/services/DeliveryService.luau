--!strict
-- DeliveryService: Döner-Lieferaufträge (Annahme, Abholung, Auslieferung).
-- Rein serverseitig, ohne globale Variablen. Distanz- und Zustandsprüfung
-- erfolgen anhand der übergebenen Spielerpositionen.

export type Position = { x: number, y: number, z: number }
export type AddressEntry = { id: string, position: Position }
export type EconomyAdapter = {
	addBalance: (playerId: string, amount: number, transactionId: string) -> boolean,
}
export type ServiceConfig = {
	shopPosition: Position,
	addresses: { AddressEntry },
	starterMaxDistance: number?,
	pickupRadius: number?,
	deliverRadius: number?,
	starterPayout: number?,
	standardPayout: number?,
	economy: EconomyAdapter?,
	randomIndex: ((n: number) -> number)?,
}
export type Job = {
	jobId: string,
	playerId: string,
	addressId: string,
	state: string,
	starter: boolean,
	payout: number,
	vehicleType: string,
}
export type RuntimeConfig = {
	profiles: any?,
	economy: any?,
	world: any?,
	shopPosition: Position?,
	addresses: { AddressEntry }?,
	getPlayerPosition: ((player: any) -> any)?,
	starterMaxDistance: number?,
	pickupRadius: number?,
	deliverRadius: number?,
	starterPayout: number?,
	standardPayout: number?,
}
export type DeliveryResponse = {
	ok: boolean,
	code: string?,
	orderId: string?,
	addressId: string?,
	state: string?,
	starter: boolean?,
	payout: number?,
	vehicleType: string?,
}

local DeliveryService = {}
DeliveryService.__index = DeliveryService

local STATE_ACCEPTED = "accepted"
local STATE_PICKED_UP = "pickedUp"
local STATE_DELIVERED = "delivered"

local function isPosition(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local pos = value :: Position
	return type(pos.x) == "number" and type(pos.y) == "number" and type(pos.z) == "number"
end

local function distance(a: Position, b: Position): number
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function findAddress(addresses: { AddressEntry }, addressId: string): AddressEntry?
	for _, entry in ipairs(addresses) do
		if entry.id == addressId then
			return entry
		end
	end
	return nil
end

function DeliveryService.new(config: ServiceConfig)
	assert(type(config) == "table", "configRequired")
	assert(isPosition(config.shopPosition), "shopPositionRequired")
	assert(type(config.addresses) == "table" and #config.addresses > 0, "addressesRequired")
	for _, entry in ipairs(config.addresses) do
		assert(type(entry.id) == "string" and #entry.id > 0, "addressIdRequired")
		assert(isPosition(entry.position), "addressPositionRequired")
	end
	if config.economy ~= nil then
		assert(type(config.economy.addBalance) == "function", "economyAdapterInvalid")
	end

	local self = setmetatable({}, DeliveryService)
	self._shopPosition = config.shopPosition
	self._addresses = config.addresses
	self._starterMaxDistance = config.starterMaxDistance or 150
	self._pickupRadius = config.pickupRadius or 12
	self._deliverRadius = config.deliverRadius or 12
	self._starterPayout = config.starterPayout or 25
	self._standardPayout = config.standardPayout or 60
	self._economy = config.economy
	self._randomIndex = config.randomIndex
	self._jobsById = {} :: { [string]: Job }
	self._activeByPlayer = {} :: { [string]: string }
	self._counter = 0
	return self
end

function DeliveryService:_pickAddressIndex(): number
	local count = #self._addresses
	if self._randomIndex ~= nil then
		local picked = (self._randomIndex :: (n: number) -> number)(count)
		assert(type(picked) == "number" and picked >= 1 and picked <= count, "randomIndexOutOfRange")
		return picked
	end
	return math.random(1, count)
end

function DeliveryService:getActiveJob(playerId: string): Job?
	local jobId = self._activeByPlayer[playerId]
	if jobId == nil then
		return nil
	end
	return self._jobsById[jobId]
end

-- Auftragsannahme: genau ein aktiver Auftrag pro Spieler. Kurze
-- Startlieferungen sind mit dem Fahrrad erlaubt, weite nur mit Mofa.
function DeliveryService:acceptJob(playerId: string, vehicleType: string): (Job?, string?)
	if type(playerId) ~= "string" or #playerId == 0 then
		return nil, "invalidPlayer"
	end
	if vehicleType ~= "bicycle" and vehicleType ~= "moped" then
		return nil, "invalidVehicle"
	end
	if self._activeByPlayer[playerId] ~= nil then
		return nil, "jobAlreadyActive"
	end

	local entry = self._addresses[self:_pickAddressIndex()]
	local routeLength = distance(self._shopPosition, entry.position)
	local starter = routeLength <= self._starterMaxDistance
	if starter == false and vehicleType == "bicycle" then
		return nil, "bicycleOnlyForStarter"
	end

	self._counter += 1
	local jobId = string.format("%s-%d", playerId, self._counter)
	local payout = self._standardPayout
	if starter then
		payout = self._starterPayout
	end
	local job: Job = {
		jobId = jobId,
		playerId = playerId,
		addressId = entry.id,
		state = STATE_ACCEPTED,
		starter = starter,
		payout = payout,
		vehicleType = vehicleType,
	}
	self._jobsById[jobId] = job
	self._activeByPlayer[playerId] = jobId
	return job, nil
end

-- Abholung: nur im Zustand "accepted" und nahe am Dönerladen.
function DeliveryService:pickup(playerId: string, jobId: string, playerPos: Position): (boolean, string?)
	local job = self._jobsById[jobId]
	if job == nil then
		return false, "unknownJob"
	end
	if job.playerId ~= playerId then
		return false, "notYourJob"
	end
	if job.state ~= STATE_ACCEPTED then
		return false, "invalidState"
	end
	if not isPosition(playerPos) then
		return false, "invalidPosition"
	end
	if distance(playerPos, self._shopPosition) > self._pickupRadius then
		return false, "tooFarFromShop"
	end
	job.state = STATE_PICKED_UP
	return true, nil
end

-- Auslieferung: nur im Zustand "pickedUp" und nahe an der Wohnadresse.
-- Jede Lieferung wird genau einmal ausgezahlt.
function DeliveryService:deliver(playerId: string, jobId: string, playerPos: Position): (number?, string?)
	local job = self._jobsById[jobId]
	if job == nil then
		return nil, "unknownJob"
	end
	if job.playerId ~= playerId then
		return nil, "notYourJob"
	end
	if job.state == STATE_DELIVERED then
		return nil, "alreadyDelivered"
	end
	if job.state ~= STATE_PICKED_UP then
		return nil, "invalidState"
	end
	if not isPosition(playerPos) then
		return nil, "invalidPosition"
	end
	local entry = findAddress(self._addresses, job.addressId)
	if entry == nil then
		return nil, "unknownAddress"
	end
	if distance(playerPos, entry.position) > self._deliverRadius then
		return nil, "tooFarFromAddress"
	end

	job.state = STATE_DELIVERED
	if self._activeByPlayer[playerId] == jobId then
		self._activeByPlayer[playerId] = nil
	end
	if self._economy ~= nil then
		local ok = (self._economy :: EconomyAdapter).addBalance(playerId, job.payout, "delivery:" .. jobId)
		if ok == false then
			return nil, "payoutFailed"
		end
	end
	return job.payout, nil
end

-- ---------------------------------------------------------------------------
-- Router-Verdrahtung: genau eine Laufzeitinstanz pro Server.
-- Der Service bleibt die einzige Zustandsmaschine; diese Funktionen prüfen nur
-- Spielerzuordnung und leiten an `acceptJob`, `pickup` und `deliver` weiter.
-- ---------------------------------------------------------------------------

local runtimeConfig: RuntimeConfig = {}
local runtime: any = nil

local function readField(value: any, key: string): any
	if value == nil then
		return nil
	end
	local ok, result = pcall(function()
		return (value :: any)[key]
	end)
	if ok then
		return result
	end
	return nil
end

local function toPosition(value: any): Position?
	if value == nil then
		return nil
	end
	-- Roblox-`Vector3` meldet in neueren Luau-Versionen `type == "vector"`;
	-- ältere Versionen liefern `userdata`. Beides muss akzeptiert werden.
	local valueType = type(value)
	if valueType ~= "table" and valueType ~= "userdata" and valueType ~= "vector" then
		return nil
	end
	local x = readField(value, "x")
	local y = readField(value, "y")
	local z = readField(value, "z")
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		x = readField(value, "X")
		y = readField(value, "Y")
		z = readField(value, "Z")
	end
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end
	return { x = x, y = y, z = z }
end

-- Adapter, damit der Service die Economy-Signatur unverändert aufrufen kann.
-- Bevorzugt `credit` (EconomyService-Instanz, Doppelpunkt-Signatur), fällt
-- danach auf `addBalance` zurück.
local function makeEconomyAdapter(economy: any): EconomyAdapter?
	if type(economy) ~= "table" then
		return nil
	end
	local credit = readField(economy, "credit")
	if type(credit) == "function" then
		return {
			addBalance = function(playerId: string, amount: number, transactionId: string): boolean
				local ok, result = pcall(function()
					return credit(economy, playerId, amount, transactionId)
				end)
				if not ok then
					ok, result = pcall(function()
						return credit(playerId, amount, transactionId)
					end)
				end
				if not ok then
					return false
				end
				return result ~= false
			end,
		}
	end
	local addBalance = readField(economy, "addBalance")
	if type(addBalance) ~= "function" then
		return nil
	end
	return {
		addBalance = function(playerId: string, amount: number, transactionId: string): boolean
			local ok, result = pcall(function()
				return addBalance(economy, playerId, amount, transactionId)
			end)
			if not ok then
				ok, result = pcall(function()
					return addBalance(playerId, amount, transactionId)
				end)
			end
			return ok and result ~= false
		end,
	}
end

local function entryName(entry: any): string?
	local name = readField(entry, "Name")
		or readField(entry, "name")
		or readField(entry, "id")
		or readField(entry, "Id")
	if type(name) == "string" and #name > 0 then
		return name
	end
	return nil
end

local function isPickupName(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "doner", 1, true) ~= nil
		or string.find(lower, "pickup", 1, true) ~= nil
end

-- Lieferpunkte stammen ausschliesslich aus der Welt. Ohne gültige Weltdaten
-- bleibt der Dienst gesperrt, statt Punkte oder Distanzen zu erfinden.
local function resolveWorldPoints(): (Position?, { AddressEntry })
	local world = runtimeConfig.world
	if type(world) ~= "table" then
		return nil, {}
	end
	local pointsFn = readField(world, "getDeliveryPoints")
	if type(pointsFn) ~= "function" then
		return nil, {}
	end
	local ok, points = pcall(pointsFn, world)
	if not ok or type(points) ~= "table" then
		return nil, {}
	end

	local shop = toPosition(readField(points, "shopPosition"))
		or toPosition(readField(points, "shop"))
		or toPosition(readField(points, "donerPosition"))
	if shop == nil then
		shop = toPosition(readField(readField(points, "doner"), "position"))
	end

	local addresses: { AddressEntry } = {}
	local rawAddresses = readField(points, "addresses")
	if type(rawAddresses) == "table" then
		for _, entry in ipairs(rawAddresses) do
			local id = readField(entry, "id")
			local position = toPosition(readField(entry, "position")) or toPosition(entry)
			if type(id) == "string" and #id > 0 and position ~= nil then
				table.insert(addresses, { id = id, position = position })
			end
		end
	end

	-- Array-Format (z. B. ValleyWorld.getDeliveryPoints): { { Name, Position } }.
	-- Der Abholpunkt heisst "Delivery_DonerPickup", alle übrigen Punkte sind
	-- Wohnadressen. Das Format bleibt rückwärtskompatibel zur strukturierten Form.
	if shop == nil or #addresses == 0 then
		local arrayShop: Position? = nil
		local arrayAddresses: { AddressEntry } = {}
		for _, entry in ipairs(points) do
			local name = entryName(entry)
			local position = toPosition(readField(entry, "Position"))
				or toPosition(readField(entry, "position"))
				or toPosition(entry)
			if name ~= nil and position ~= nil then
				if isPickupName(name) then
					if arrayShop == nil then
						arrayShop = position
					end
				else
					table.insert(arrayAddresses, { id = name, position = position })
				end
			end
		end
		if shop == nil then
			shop = arrayShop
		end
		if #addresses == 0 then
			addresses = arrayAddresses
		end
	end

	return shop, addresses
end

local function buildRuntime(): any
	if runtime ~= nil then
		return runtime
	end
	local shop = runtimeConfig.shopPosition
	local addresses = runtimeConfig.addresses
	if shop == nil or addresses == nil or #addresses == 0 then
		local worldShop, worldAddresses = resolveWorldPoints()
		if shop == nil then
			shop = worldShop
		end
		if addresses == nil or #addresses == 0 then
			addresses = worldAddresses
		end
	end
	if shop == nil or addresses == nil or #addresses == 0 then
		return nil
	end
	runtime = DeliveryService.new({
		shopPosition = shop,
		addresses = addresses,
		starterMaxDistance = runtimeConfig.starterMaxDistance,
		pickupRadius = runtimeConfig.pickupRadius,
		deliverRadius = runtimeConfig.deliverRadius,
		starterPayout = runtimeConfig.starterPayout,
		standardPayout = runtimeConfig.standardPayout,
		economy = makeEconomyAdapter(runtimeConfig.economy),
	})
	return runtime
end

local function reject(code: string): DeliveryResponse
	return { ok = false, code = code }
end

local function playerIdOf(player: any): string?
	local userId = readField(player, "UserId")
	if type(userId) ~= "number" or userId <= 0 then
		return nil
	end
	return tostring(userId)
end

-- Position kommt aus dem Charakter des Spielers, nie aus dem Payload.
local function playerPositionOf(player: any): Position?
	local resolver = runtimeConfig.getPlayerPosition
	if type(resolver) == "function" then
		local ok, result = pcall(resolver, player)
		if not ok then
			return nil
		end
		return toPosition(result)
	end
	local character = readField(player, "Character")
	local root = readField(character, "HumanoidRootPart")
	return toPosition(readField(root, "Position"))
end

local function resolveOrderId(service: any, playerId: string, payload: any): (string?, string?)
	local requested = readField(payload, "orderId")
	if requested ~= nil then
		if type(requested) ~= "string" or #requested == 0 then
			return nil, "invalidPayload"
		end
		return requested, nil
	end
	local active = service:getActiveJob(playerId)
	if active == nil then
		return nil, "noActiveJob"
	end
	return active.jobId, nil
end

function DeliveryService.init(config: RuntimeConfig?): ()
	if config ~= nil and type(config) ~= "table" then
		error("init: config must be a table")
	end
	runtimeConfig = config or {}
	runtime = nil
end

function DeliveryService.handleOrder(player: any, payload: any): DeliveryResponse
	local service = buildRuntime()
	if service == nil then
		return reject("deliveryUnavailable")
	end
	local playerId = playerIdOf(player)
	if playerId == nil then
		return reject("invalidPlayer")
	end

	local vehicleType = "bicycle"
	local requested = readField(payload, "vehicleType")
	if requested ~= nil then
		if type(requested) ~= "string" then
			return reject("invalidPayload")
		end
		vehicleType = requested
	end

	local job, err = service:acceptJob(playerId, vehicleType)
	if job == nil then
		return reject(err or "orderFailed")
	end
	return {
		ok = true,
		orderId = job.jobId,
		addressId = job.addressId,
		state = job.state,
		starter = job.starter,
		payout = job.payout,
		vehicleType = job.vehicleType,
	}
end

function DeliveryService.handlePickup(player: any, payload: any): DeliveryResponse
	local service = buildRuntime()
	if service == nil then
		return reject("deliveryUnavailable")
	end
	local playerId = playerIdOf(player)
	if playerId == nil then
		return reject("invalidPlayer")
	end
	local orderId, idErr = resolveOrderId(service, playerId, payload)
	if orderId == nil then
		return reject(idErr or "unknownJob")
	end
	local position = playerPositionOf(player)
	if position == nil then
		return reject("positionUnavailable")
	end
	local ok, err = service:pickup(playerId, orderId, position)
	if not ok then
		return reject(err or "pickupFailed")
	end
	return { ok = true, orderId = orderId, state = STATE_PICKED_UP }
end

function DeliveryService.handleDeliver(player: any, payload: any): DeliveryResponse
	local service = buildRuntime()
	if service == nil then
		return reject("deliveryUnavailable")
	end
	local playerId = playerIdOf(player)
	if playerId == nil then
		return reject("invalidPlayer")
	end
	local orderId, idErr = resolveOrderId(service, playerId, payload)
	if orderId == nil then
		return reject(idErr or "unknownJob")
	end
	local position = playerPositionOf(player)
	if position == nil then
		return reject("positionUnavailable")
	end
	local payout, err = service:deliver(playerId, orderId, position)
	if payout == nil then
		return reject(err or "deliverFailed")
	end
	return { ok = true, orderId = orderId, state = STATE_DELIVERED, payout = payout }
end

return DeliveryService
