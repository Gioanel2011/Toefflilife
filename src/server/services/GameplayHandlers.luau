--!strict
-- GameplayHandlers: registriert die generischen Remotes am RequestRouter.
-- Alle Preise, Rabatte, Besitzpruefungen, Distanzen und Zustaende stammen aus
-- den Services; Payloads liefern nur IDs und optional harmlose Quellen.
-- Keine Roblox-Laufzeit, damit die Handler mit `lune run` testbar bleiben.
-- Keine globalen Variablen.

local PartsCatalog = require("../../shared/data/PartsCatalog")

local GameplayHandlers = {}

-- Modul-lokaler Fallback, falls der Bootstrap keinen Transaktionszaehler
-- injiziert. Keine globalen Variablen.
local fallbackTransactionCounter = 0

export type Deps = {
	playerStore: any,
	vehicleService: any,
	shopService: any,
	workshopService: any,
	garageService: any,
	dynoService: any,
	fuelService: any,
	missionService: any,
	economy: any,
	onVehicleOwned: ((userId: number, vehicleId: string) -> ())?,
	nextTransactionId: ((userId: number, kind: string) -> string)?,
}

local function reply(payload: any?): any
	local result: any = { ok = true }
	if payload ~= nil then
		for key, value in pairs(payload) do
			result[key] = value
		end
	end
	return result
end

local function reject(code: any?): any
	if type(code) == "string" and code ~= "" then
		return { ok = false, code = code }
	end
	return { ok = false, code = "failed" }
end

local function catalogList(shopService: any): { any }
	local list: { any } = {}
	for _, entry in ipairs(shopService:getCatalog()) do
		local part = PartsCatalog.getPartById(entry.id)
		table.insert(list, {
			id = entry.id,
			name = if part ~= nil then part.name else entry.id,
			category = if part ~= nil then part.slot elseif entry.slot ~= nil then entry.slot else "misc",
			price = entry.price,
			compatibleModels = if part ~= nil then part.compatibleModels else {},
			mountPoint = if part ~= nil then part.mountPoint else nil,
		})
	end
	return list
end

function GameplayHandlers.register(router: any, deps: Deps): ()
	local playerStore = deps.playerStore
	local economy = deps.economy

	local function transactionId(userId: number, kind: string): string
		if deps.nextTransactionId ~= nil then
			return deps.nextTransactionId(userId, kind)
		end
		fallbackTransactionCounter += 1
		return string.format("%s:%s:%d", kind, tostring(userId), fallbackTransactionCounter)
	end

	local function prepare(userId: number): any
		local view = playerStore:ensure(userId)
		playerStore:refreshMoney(userId)
		return view
	end

	local function persist(userId: number): ()
		playerStore:sync(userId)
		playerStore:save(userId)
	end

	local function vehicleSelect(_player: any, _payload: any): any
		local userId = _player.UserId
		prepare(userId)
		local view = playerStore:view(userId)
		return reply({
			selected = view.selectedVehicle,
			owned = playerStore:owned(userId),
			cash = view.money,
		})
	end

	local function economyGet(player: any, _payload: any): any
		prepare(player.UserId)
		return reply({ cash = economy:getBalance(player.UserId) })
	end

	local function vehicleBuy(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local view = playerStore:view(userId)
		local purchased, outcome = deps.vehicleService:purchase(view, payload.vehicleId, userId)
		if not purchased then
			return reject(outcome)
		end
		playerStore:commitMoney(userId)
		playerStore:sync(userId)
		if deps.onVehicleOwned ~= nil then
			deps.onVehicleOwned(userId, payload.vehicleId)
		end
		persist(userId)
		return reply({
			receipt = outcome,
			selected = view.selectedVehicle,
			owned = playerStore:owned(userId),
			cash = view.money,
		})
	end

	local function missionProgress(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local claimInfo: any = nil
		if payload.claim == true then
			if type(payload.missionKey) ~= "string" or payload.missionKey == "" then
				return reject("invalid_mission")
			end
			local missionKey = payload.missionKey :: string
			local claimed, info = deps.missionService:claimReward(userId, missionKey, function(reward: number)
				local creditOk, creditErr = economy:credit(
					userId,
					reward,
					string.format("mission:%s:%s", tostring(userId), missionKey)
				)
				if not creditOk then
					error(creditErr or "credit_failed")
				end
			end)
			if not claimed then
				local reason: any = info
				if type(reason) == "table" then
					return reject(reason.reason)
				end
				return reject("claim_failed")
			end
			claimInfo = info
			playerStore:refreshMoney(userId)
			persist(userId)
		end
		return reply({
			missions = deps.missionService.getMissions(),
			state = deps.missionService:getState(userId),
			claim = claimInfo,
			cash = playerStore:cash(userId),
		})
	end

	local function garageEnter(player: any, _payload: any): any
		local userId = player.UserId
		prepare(userId)
		local garageId = deps.garageService.getGarage(userId)
		if garageId == nil then
			return reject("no_garage")
		end
		return reply({
			garage = garageId,
			cash = playerStore:cash(userId),
		})
	end

	local function workshopInstall(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local installed, code = deps.workshopService:installPart(
			tostring(userId),
			payload.vehicleId,
			payload.partId,
			{ source = "workshop" }
		)
		if not installed then
			return reject(code)
		end
		local record = playerStore:workshopVehicle(userId, payload.vehicleId)
		persist(userId)
		return reply({
			vehicleId = payload.vehicleId,
			parts = if record ~= nil then record.parts else {},
			inventory = playerStore:view(userId).inventory,
		})
	end

	local function workshopPaint(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local painted, code = deps.workshopService:paint(
			tostring(userId),
			payload.vehicleId,
			{ surface = payload.surface, color = payload.color },
			{ source = "workshop" }
		)
		if not painted then
			return reject(code)
		end
		local record = playerStore:workshopVehicle(userId, payload.vehicleId)
		persist(userId)
		return reply({
			vehicleId = payload.vehicleId,
			colors = if record ~= nil then record.colors else {},
		})
	end

	local function shopCatalog(player: any, _payload: any): any
		prepare(player.UserId)
		return reply({ parts = catalogList(deps.shopService) })
	end

	local function shopBuy(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local key = tostring(userId)
		local tx = transactionId(userId, "shop")
		local bought: boolean
		local code: string
		if payload.source == "store" then
			bought, code = deps.shopService:buyFromStore(key, payload.partId, tx)
		else
			bought, code = deps.shopService:orderPart(key, payload.partId, tx)
		end
		if not bought then
			return reject(code)
		end
		playerStore:commitMoney(userId)
		persist(userId)
		return reply({
			partId = payload.partId,
			inventory = deps.shopService:getInventory(key),
			cash = playerStore:cash(userId),
		})
	end

	local function dynoRun(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		local vehicleKey = playerStore:vehicleKey(userId, payload.vehicleId)
		local started, result = deps.dynoService:StartRun(userId, vehicleKey)
		if not started then
			return reject(result)
		end
		return reply({ result = result, cash = playerStore:cash(userId) })
	end

	local function fuelRefill(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		if payload.action == "requestRescue" then
			local vehicleId: any = payload.vehicleId
			if type(vehicleId) ~= "string" or vehicleId == "" then
				vehicleId = playerStore:selected(userId)
			end
			if type(vehicleId) ~= "string" or vehicleId == "" then
				return reject("no_vehicle")
			end
			local vehicleKey = playerStore:vehicleKey(userId, vehicleId)
			local refilled, result = deps.fuelService:RescueRefill(userId, vehicleKey)
			if not refilled then
				return reject(result)
			end
			playerStore:refreshMoney(userId)
			persist(userId)
			return reply({ refuel = result, cash = playerStore:cash(userId) })
		end
		local vehicleId: any = payload.vehicleId
		if type(vehicleId) ~= "string" or vehicleId == "" then
			return reject("invalid_vehicle")
		end
		if type(payload.liters) ~= "number" then
			return reject("invalid_amount")
		end
		local vehicleKey = playerStore:vehicleKey(userId, vehicleId)
		local refilled, result = deps.fuelService:Refuel(userId, vehicleKey, payload.liters, {
			transactionId = transactionId(userId, "fuel"),
		})
		if not refilled then
			return reject(result)
		end
		playerStore:refreshMoney(userId)
		persist(userId)
		return reply({ refuel = result, cash = playerStore:cash(userId) })
	end

	local function economyTransfer(player: any, payload: any): any
		local userId = player.UserId
		prepare(userId)
		if payload.targetUserId ~= nil and tostring(payload.targetUserId) ~= tostring(userId) then
			return reject("access_denied")
		end
		return reply({ cash = economy:getBalance(userId) })
	end

	local handlers: { [string]: any } = {
		VehicleSelect = vehicleSelect,
		EconomyGet = economyGet,
		VehicleBuy = vehicleBuy,
		MissionProgress = missionProgress,
		GarageEnter = garageEnter,
		WorkshopInstall = workshopInstall,
		WorkshopPaint = workshopPaint,
		ShopCatalog = shopCatalog,
		ShopBuy = shopBuy,
		DynoRun = dynoRun,
		FuelRefill = fuelRefill,
		EconomyTransfer = economyTransfer,
	}
	local limits: { [string]: { number } } = {
		VehicleBuy = { 5, 1 },
		ShopBuy = { 10, 1 },
		WorkshopInstall = { 10, 1 },
		WorkshopPaint = { 10, 1 },
		DynoRun = { 5, 1 },
		FuelRefill = { 10, 1 },
		MissionProgress = { 20, 1 },
		EconomyTransfer = { 10, 1 },
	}
	for action, handler in pairs(handlers) do
		router:register(action, handler)
		local limit = limits[action]
		if limit ~= nil then
			pcall(function()
				router:setRateLimit(action, limit[1], limit[2])
			end)
		end
	end
end

return GameplayHandlers
