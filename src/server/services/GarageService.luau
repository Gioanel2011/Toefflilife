--!strict
-- GarageService: private Garagen innerhalb desselben Servers plus
-- Hebebuehnen-Pruefung fuer den Werkstattzustand.
-- Keine Reserved Servers: Jeder Spieler erhaelt eine eigene Garage-Instanz
-- (Anker-ID). Der Werkstattzustand ist nur aktiv, wenn das eigene Mofa
-- stillsteht, der Motor aus ist, niemand faehrt und das Fahrzeug auf der
-- Hebebuehne oder dem markierten Werkstattplatz steht.
--
-- Task 27: Der Bootstrap initialisiert genau eine Serverinstanz mit den 15
-- Weltankern aus WorldLayout.GARAGES. Oeffentliche Funktionen akzeptieren
-- sowohl Player-Objekte (UserId) als auch reine UserIds, damit Servercode
-- ohne clientseitige Berechtigungspruefung arbeitet. Jede Zuweisung ist
-- eindeutig; beim Verlassen wird der Anker wieder freigegeben.

export type GarageOptions = {
	anchors: { any }?,
	prefix: string?,
	capacity: number?,
	profiles: any?,
	world: any?,
}

export type WorkshopState = {
	userId: any,
	vehicleOwnerId: any?,
	vehicleId: string?,
	vehicleKind: string?,
	speed: number?,
	engineOn: boolean?,
	riderUserId: any?,
	occupantCount: number?,
	onLift: boolean?,
	onWorkshopPad: boolean?,
	garageId: string?,
}

export type GarageService = {
	_byPlayer: { [string]: string },
	_byGarage: { [string]: string },
	_anchors: { string },
}

local GarageService = {}
GarageService.__index = GarageService

GarageService.MAX_WORKSHOP_SPEED = 0.5
GarageService.DEFAULT_CAPACITY = 15
GarageService.BICYCLE_IDS = {
	bicycle = true,
	bike = true,
	fahrrad = true,
	startfahrrad = true,
}

local defaultInstance: GarageService? = nil

-- Liefert die UserId eines Player-Objekts oder die unveraenderte UserId.
local function extractUserId(value: any): any
	if type(value) == "table" then
		local userId = (value :: any).UserId
		if type(userId) == "number" then
			return userId
		end
	elseif type(value) == "userdata" then
		local ok, userId = pcall(function()
			return (value :: any).UserId
		end)
		if ok and type(userId) == "number" then
			return userId
		end
	end
	return value
end

local function keyOf(value: any): string?
	local userId = extractUserId(value)
	if type(userId) == "number" then
		return tostring(userId)
	elseif type(userId) == "string" and (userId :: string) ~= "" then
		return userId :: string
	end
	return nil
end

local function isBicycle(vehicleId: any, vehicleKind: any): boolean
	if type(vehicleKind) == "string" and string.lower(vehicleKind :: string) == "bicycle" then
		return true
	end
	if type(vehicleId) == "string" then
		return GarageService.BICYCLE_IDS[string.lower(vehicleId :: string)] == true
	end
	return false
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Akzeptiert sowohl Anker-IDs als auch Anker-Records aus WorldLayout.
local function resolveAnchorList(source: any): { string }?
	if type(source) ~= "table" then
		return nil
	end
	local anchors: { string } = {}
	for _, entry in ipairs(source) do
		if type(entry) == "string" and entry ~= "" then
			table.insert(anchors, entry)
		elseif type(entry) == "table" then
			local id = (entry :: any).id
			if type(id) == "string" and id ~= "" then
				table.insert(anchors, id)
			end
		end
	end
	if #anchors == 0 then
		return nil
	end
	return anchors
end

local function defaultAnchors(prefix: string, capacity: number): { string }
	local anchors: { string } = {}
	for index = 1, capacity do
		table.insert(anchors, string.format("%s_%02d", prefix, index))
	end
	return anchors
end

local function copyAnchors(source: { string }): { string }
	local out: { string } = {}
	for _, anchor in ipairs(source) do
		table.insert(out, anchor)
	end
	return out
end

-- Weltanker kommen aus einem Modul mit getGarageAnchors (z. B. WorldLayout
-- oder ValleyWorld), ohne dass der Service selbst Weltcode laden muss.
local function anchorsFromWorld(world: any): { string }?
	if type(world) ~= "table" then
		return nil
	end
	local getter = (world :: any).getGarageAnchors
	if type(getter) ~= "function" then
		return nil
	end
	local ok, result = pcall(getter, world)
	if not ok or type(result) ~= "table" then
		local okDirect, direct = pcall(getter)
		if not okDirect then
			return nil
		end
		result = direct
	end
	return resolveAnchorList(result)
end

local function isInstance(value: any): boolean
	if type(value) ~= "table" or getmetatable(value) ~= GarageService then
		return false
	end
	return rawget(value, "_byPlayer") ~= nil
		and rawget(value, "_byGarage") ~= nil
		and rawget(value, "_anchors") ~= nil
end

-- Loest Methodenaufrufe auf Instanz, Modul (Singleton) oder statische Aufrufe
-- auf. callOptional(module, name, ...) ruft fn(module, ...) auf, daher wird
-- das Modul als erster Parameter erkannt.
local function resolveCall(a: any, b: any, c: any): (GarageService?, any, any, any)
	if a == GarageService then
		return defaultInstance, b, c, nil
	elseif isInstance(a) then
		return a :: GarageService, b, c, nil
	end
	return defaultInstance, a, b, c
end

local function ensureDefault(): GarageService
	if defaultInstance == nil then
		defaultInstance = GarageService.new()
	end
	return defaultInstance :: GarageService
end

local function instanceOr(instance: GarageService?): GarageService
	if instance ~= nil then
		return instance
	end
	return ensureDefault()
end

function GarageService.new(options: GarageOptions?): GarageService
	local opts: GarageOptions = options or {}
	local capacity = opts.capacity or GarageService.DEFAULT_CAPACITY
	if type(capacity) ~= "number" or capacity < 1 then
		capacity = GarageService.DEFAULT_CAPACITY
	end
	capacity = math.floor(capacity)
	local prefix = opts.prefix or "Garage"
	if type(prefix) ~= "string" or prefix == "" then
		prefix = "Garage"
	end
	local anchors = resolveAnchorList(opts.anchors)
	if anchors == nil then
		anchors = defaultAnchors(prefix, capacity)
	end
	local self: GarageService = setmetatable({}, GarageService) :: any
	self._byPlayer = {}
	self._byGarage = {}
	self._anchors = anchors
	return self
end

-- Erzeugt die serverseitige Singleton-Instanz aus den 15 Weltankern.
-- Signatur unterstuetzt init(options) und callOptional(module, "init", options).
function GarageService.init(a: any, b: any?): GarageService
	local options: any = a
	if a == GarageService then
		options = b
	end
	if type(options) ~= "table" then
		options = {}
	end
	local anchors = resolveAnchorList((options :: any).anchors)
	if anchors == nil then
		anchors = anchorsFromWorld((options :: any).world)
	end
	defaultInstance = GarageService.new({
		anchors = anchors,
		prefix = (options :: any).prefix,
		capacity = (options :: any).capacity,
	})
	return defaultInstance
end

local function anchorsOn(instance: GarageService): { string }
	return copyAnchors(instance._anchors)
end

local function getGarageOn(instance: GarageService, playerUserId: any): string?
	local key = keyOf(playerUserId)
	if key == nil then
		return nil
	end
	return instance._byPlayer[key]
end

local function getOwnerOn(instance: GarageService, garageId: any): string?
	if type(garageId) ~= "string" then
		return nil
	end
	return instance._byGarage[garageId]
end

local function hasAccessOn(instance: GarageService, playerUserId: any, garageId: any): boolean
	if type(garageId) ~= "string" or garageId == "" then
		return false
	end
	local key = keyOf(playerUserId)
	if key == nil then
		return false
	end
	return instance._byPlayer[key] == garageId and instance._byGarage[garageId] == key
end

local function assignOn(instance: GarageService, playerUserId: any): (string?, string?)
	local key = keyOf(playerUserId)
	if key == nil then
		return nil, "invalid_player"
	end
	local existing = instance._byPlayer[key]
	if existing ~= nil then
		return existing, nil
	end
	for _, anchor in ipairs(instance._anchors) do
		if instance._byGarage[anchor] == nil then
			instance._byPlayer[key] = anchor
			instance._byGarage[anchor] = key
			return anchor, nil
		end
	end
	return nil, "no_free_garage"
end

local function releaseOn(instance: GarageService, playerUserId: any): boolean
	local key = keyOf(playerUserId)
	if key == nil then
		return false
	end
	local garageId = instance._byPlayer[key]
	if garageId == nil then
		return false
	end
	instance._byPlayer[key] = nil
	if instance._byGarage[garageId] == key then
		instance._byGarage[garageId] = nil
	end
	return true
end

local function countOn(instance: GarageService): number
	local count = 0
	for _ in pairs(instance._byPlayer) do
		count += 1
	end
	return count
end

-- Prueft den Werkstattzustand. Gibt (true, nil) nur zurueck, wenn alle
-- Bedingungen gleichzeitig gelten: eigenes Mofa (kein Fahrrad), Stillstand,
-- Motor aus, niemand faehrt, auf Hebebuehne oder Werkstattplatz.
-- Bei gesetzter garageId muss der Spieler Zugriff auf diese Garage haben.
local function validateOn(instance: GarageService, state: any): (boolean, string?)
	if type(state) ~= "table" then
		return false, "invalid_state"
	end
	local current = state :: WorkshopState
	local userKey = keyOf(current.userId)
	if userKey == nil then
		return false, "invalid_player"
	end
	if current.garageId ~= nil then
		if type(current.garageId) ~= "string" or not hasAccessOn(instance, current.userId, current.garageId) then
			return false, "no_garage_access"
		end
	end
	if type(current.vehicleId) ~= "string" or (current.vehicleId :: string) == "" then
		return false, "no_vehicle"
	end
	if isBicycle(current.vehicleId, current.vehicleKind) then
		return false, "bicycle_no_workshop"
	end
	local ownerKey = keyOf(current.vehicleOwnerId)
	if ownerKey == nil or ownerKey ~= userKey then
		return false, "not_owner"
	end
	if current.engineOn == true then
		return false, "engine_on"
	end
	if not isFiniteNumber(current.speed) then
		return false, "invalid_speed"
	end
	if math.abs(current.speed :: number) > GarageService.MAX_WORKSHOP_SPEED then
		return false, "vehicle_moving"
	end
	if current.riderUserId ~= nil then
		return false, "occupied"
	end
	if current.occupantCount ~= nil then
		if not isFiniteNumber(current.occupantCount) then
			return false, "invalid_occupants"
		end
		if (current.occupantCount :: number) > 0 then
			return false, "occupied"
		end
	end
	if current.onLift ~= true and current.onWorkshopPad ~= true then
		return false, "not_on_lift_or_pad"
	end
	return true, nil
end

function GarageService.getAnchors(a: any, b: any?): { string }
	local instance = resolveCall(a, b, nil)
	return anchorsOn(instanceOr(instance))
end

function GarageService.getGarage(a: any, b: any?): string?
	local instance, player = resolveCall(a, b, nil)
	return getGarageOn(instanceOr(instance), player)
end

function GarageService.getOwner(a: any, b: any?): string?
	local instance, garageId = resolveCall(a, b, nil)
	return getOwnerOn(instanceOr(instance), garageId)
end

function GarageService.hasAccess(a: any, b: any, c: any?): boolean
	local instance, player, garageId = resolveCall(a, b, c)
	return hasAccessOn(instanceOr(instance), player, garageId)
end

function GarageService.assignGarage(a: any, b: any?): (string?, string?)
	local instance, player = resolveCall(a, b, nil)
	return assignOn(instanceOr(instance), player)
end

function GarageService.releaseGarage(a: any, b: any?): boolean
	local instance, player = resolveCall(a, b, nil)
	return releaseOn(instanceOr(instance), player)
end

function GarageService.getAssignmentCount(a: any): number
	local instance = resolveCall(a, nil, nil)
	return countOn(instanceOr(instance))
end

function GarageService.validateWorkshopState(a: any, b: any?): (boolean, string?)
	local instance, state = resolveCall(a, b, nil)
	return validateOn(instanceOr(instance), state)
end

function GarageService.isWorkshopActive(a: any, b: any?): boolean
	local instance, state = resolveCall(a, b, nil)
	local ok, _ = validateOn(instanceOr(instance), state)
	return ok
end

return GarageService
