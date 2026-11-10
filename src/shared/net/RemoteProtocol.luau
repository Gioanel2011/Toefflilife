-- RemoteProtocol: versionierte Remote-Namen und Payload-Schemas.
-- Rein datengetrieben, ohne Roblox-Laufzeit. Keine globalen Variablen.

local RemoteProtocol = {}

RemoteProtocol.PROTOCOL_VERSION = 1

RemoteProtocol.REMOTES = {
	REQUEST = "TT_Request_v1",
	RESPONSE = "TT_Response_v1",
}

RemoteProtocol.ACTIONS = {
	PING = "ping",
	ECHO = "echo",
	DELIVERY_ORDER = "DeliveryOrder",
	DELIVERY_PICKUP = "DeliveryPickup",
	DELIVERY_DELIVER = "DeliveryDeliver",
}

-- Kanonische Remote-Namen für Protokoll v1. Aktion und Remote heissen gleich,
-- damit der RequestRouter ohne Zusatzabbildung dispatchen kann.
local REMOTE_NAMES: { string } = {
	"EconomyGet",
	"EconomyTransfer",
	"VehicleBuy",
	"VehicleSelect",
	"MissionProgress",
	"DeliveryOrder",
	"DeliveryPickup",
	"DeliveryDeliver",
	"GarageEnter",
	"WorkshopInstall",
	"WorkshopPaint",
	"ShopCatalog",
	"ShopBuy",
	"DynoRun",
	"FuelRefill",
}

-- Payloads v1. Nur der Fahrzeugtyp kommt vom Client; `orderId` ist optional,
-- weil ein Spieler genau einen aktiven Auftrag besitzt. Preise, Distanzen,
-- Belohnungen und Zustandswechsel werden nie im Payload übertragen.
local PAYLOAD_SCHEMAS: { [string]: { [string]: { kind: string, required: boolean } } } = {
	ping = {},
	echo = {
		message = { kind = "string", required = true },
	},
	EconomyGet = {},
	EconomyTransfer = {
		targetUserId = { kind = "number", required = false },
	},
	VehicleSelect = {
		action = { kind = "string", required = false },
	},
	VehicleBuy = {
		vehicleId = { kind = "string", required = true },
	},
	MissionProgress = {
		missionKey = { kind = "string", required = false },
		claim = { kind = "boolean", required = false },
	},
	GarageEnter = {},
	WorkshopInstall = {
		vehicleId = { kind = "string", required = true },
		partId = { kind = "string", required = true },
	},
	WorkshopPaint = {
		vehicleId = { kind = "string", required = true },
		surface = { kind = "string", required = true },
		color = { kind = "string", required = true },
	},
	ShopCatalog = {
		modelFilter = { kind = "string", required = false },
	},
	ShopBuy = {
		partId = { kind = "string", required = true },
		source = { kind = "string", required = false },
	},
	DynoRun = {
		vehicleId = { kind = "string", required = true },
	},
	FuelRefill = {
		action = { kind = "string", required = false },
		vehicleId = { kind = "string", required = false },
		liters = { kind = "number", required = false },
	},
	DeliveryOrder = {
		vehicleType = { kind = "string", required = true },
	},
	DeliveryPickup = {
		orderId = { kind = "string", required = false },
	},
	DeliveryDeliver = {
		orderId = { kind = "string", required = false },
	},
}

function RemoteProtocol.getRemoteNames(): { REQUEST: string, RESPONSE: string }
	return {
		REQUEST = RemoteProtocol.REMOTES.REQUEST,
		RESPONSE = RemoteProtocol.REMOTES.RESPONSE,
	}
end

function RemoteProtocol.listRemoteNames(): { string }
	local names: { string } = {}
	for _, name in REMOTE_NAMES do
		table.insert(names, name)
	end
	return names
end

function RemoteProtocol.isKnownAction(action: any): boolean
	if type(action) ~= "string" then
		return false
	end
	return PAYLOAD_SCHEMAS[action] ~= nil
end

function RemoteProtocol.getSchema(action: string): any
	if type(action) ~= "string" then
		return nil
	end
	return PAYLOAD_SCHEMAS[action]
end

function RemoteProtocol.defineAction(action: string, schema: { [string]: { kind: string, required: boolean } }): boolean
	if type(action) ~= "string" or action == "" then
		return false
	end
	if type(schema) ~= "table" then
		return false
	end
	if PAYLOAD_SCHEMAS[action] ~= nil then
		return false
	end
	PAYLOAD_SCHEMAS[action] = schema
	return true
end

function RemoteProtocol.validatePayload(action: any, payload: any): (boolean, string?)
	if type(action) ~= "string" then
		return false, "unknown_action"
	end
	local schema = PAYLOAD_SCHEMAS[action]
	if schema == nil then
		return false, "unknown_action"
	end
	if type(payload) ~= "table" then
		return false, "invalid_payload"
	end
	local typedPayload = payload :: { [string]: any }
	for fieldName, rule in pairs(schema) do
		local value = typedPayload[fieldName]
		if value == nil then
			if rule.required then
				return false, "invalid_payload"
			end
		elseif type(value) ~= rule.kind then
			return false, "invalid_payload"
		end
	end
	return true, nil
end

return RemoteProtocol
