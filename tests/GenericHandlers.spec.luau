--!strict
-- GenericHandlers.spec: registriert die generischen Gameplay-Remotes und
-- prueft sie ueber den echten RequestRouter gegen echte Service-Instanzen.
-- Laeuft mit `lune run tests/GenericHandlers.spec.luau`.
-- Keine Roblox-Laufzeit, keine erfundenen Ergebnisse.

local ProfileAdapter = require("../src/server/services/ProfileAdapter")
local ProfileService = require("../src/server/services/ProfileService")
local PlayerStore = require("../src/server/services/PlayerStore")
local GameplayHandlers = require("../src/server/services/GameplayHandlers")
local PlayerDataSchema = require("../src/shared/data/PlayerDataSchema")
local PartsCatalog = require("../src/shared/data/PartsCatalog")
local RequestRouter = require("../src/server/net/RequestRouter")
local EconomyService = require("../src/server/services/EconomyService")
local VehicleService = require("../src/server/services/VehicleService")
local ShopService = require("../src/server/services/ShopService")
local WorkshopService = require("../src/server/services/WorkshopService")
local GarageService = require("../src/server/services/GarageService")
local DynoService = require("../src/server/services/DynoService")
local FuelService = require("../src/server/services/FuelService")
local MissionService = require("../src/server/services/MissionService")

local passed = 0
local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	passed += 1
	print("PASS: " .. label)
end

-- 1. Echte Instanzen mit In-Memory-Persistenz aufbauen.
local adapter = ProfileAdapter.memory()
local profiles = ProfileService.new(adapter, PlayerDataSchema)
local economy = EconomyService.new()
local store = PlayerStore.new({ profiles = profiles, economy = economy })
local vehicleService = VehicleService.new()

local shopCatalog: { [string]: any } = {}
local workshopParts: { [string]: any } = {}
for _, part in PartsCatalog.Parts do
	shopCatalog[part.id] = {
		id = part.id,
		price = part.price,
		slot = part.slot,
		models = part.compatibleModels,
	}
	workshopParts[part.id] = { slot = part.slot, models = part.compatibleModels }
end

local shopService = ShopService.new({
	catalog = shopCatalog,
	profiles = store:getVehicleProfiles(),
	isNearStore = function(_userId: any): boolean
		return false
	end,
})
local workshopService = WorkshopService.new({
	profiles = store:getWorkshopProfiles(),
	parts = workshopParts,
	isWorkshopActive = function(_playerId: string): boolean
		return true
	end,
})

GarageService.init({ anchors = { "Garage_01", "Garage_02" } })
GarageService.assignGarage(1001)

local function isOwner(userId: any, vehicleKey: any): boolean
	if type(vehicleKey) ~= "string" then
		return false
	end
	local prefix = tostring(userId) .. ":"
	if string.sub(vehicleKey, 1, #prefix) ~= prefix then
		return false
	end
	return store:owns(userId, string.sub(vehicleKey, #prefix + 1))
end

local fuelService = FuelService.new({
	isOwner = isOwner,
	isAtGasStation = function(_userId: any, _vehicleKey: any): boolean
		return false
	end,
	debit = function(userId: any, amount: number, tx: string?): (boolean, string?)
		local id = tx
		if type(id) ~= "string" or id == "" then
			id = "fuel:" .. tostring(userId)
		end
		local ok, result = economy:debit(userId, math.ceil(amount), id)
		if not ok then
			return false, tostring(result)
		end
		return true, nil
	end,
})
local dynoService = DynoService.new({ isOwner = isOwner })
local missionService = MissionService.new()

local router = RequestRouter.new()
local txCounter = 0
GameplayHandlers.register(router, {
	playerStore = store,
	vehicleService = vehicleService,
	shopService = shopService,
	workshopService = workshopService,
	garageService = GarageService,
	dynoService = dynoService,
	fuelService = fuelService,
	missionService = missionService,
	economy = economy,
	nextTransactionId = function(userId: number, kind: string): string
		txCounter += 1
		return string.format("%s:%d:%d", kind, userId, txCounter)
	end,
})

local player = { UserId = 1001 }

-- RequestRouter kapselt Handler-Ergebnisse als { ok=true, data=... }.
local function call(action: string, payload: any): any
	local result = router:handle(player, action, payload)
	if result.ok == false then
		return result
	end
	return result.data
end

-- 2. Alle generischen Aktionen sind registriert (kein unknown_action).
local actions = {
	"VehicleSelect",
	"EconomyGet",
	"VehicleBuy",
	"MissionProgress",
	"GarageEnter",
	"WorkshopInstall",
	"WorkshopPaint",
	"ShopCatalog",
	"ShopBuy",
	"DynoRun",
	"FuelRefill",
	"EconomyTransfer",
}
for _, action in actions do
	check(router:hasHandler(action) == true, action .. " is registered")
end

-- 3. Profil laden und Testguthaben serverseitig setzen.
store:load(1001)
economy:setBalance(1001, 5000)
store:refreshMoney(1001)

local selectResult = call("VehicleSelect", { action = "getActive" })
check(selectResult.ok == true, "VehicleSelect ok")
check(selectResult.cash == 5000, "VehicleSelect cash from economy")
check(selectResult.selected == "bicycle", "VehicleSelect selected bicycle")
check(#selectResult.owned == 1 and selectResult.owned[1] == "bicycle", "VehicleSelect owns only bicycle")

local economyResult = call("EconomyGet", {})
check(economyResult.ok == true and economyResult.cash == selectResult.cash, "EconomyGet matches VehicleSelect cash")

-- 4. Mofa-Kauf mit einmaligem Startrabatt.
local buyResult = call("VehicleBuy", { vehicleId = "puch_maxi_s" })
check(buyResult.ok == true, "VehicleBuy discounted moped ok")
check(buyResult.receipt.discountApplied == true, "starter discount applied")
check(buyResult.receipt.pricePaid == 799, "discounted price charged")
check(buyResult.cash == 5000 - 799, "cash after discounted buy")
check(buyResult.selected == "puch_maxi_s", "new vehicle selected")
check(store:view(1001).starterDiscountUsed == true, "discount flag stored in view")

-- Doppelkauf wird abgelehnt und bucht nichts ab.
local duplicate = call("VehicleBuy", { vehicleId = "puch_maxi_s" })
check(duplicate.ok == false and duplicate.code == "already_owned", "duplicate buy rejected")
check(store:cash(1001) == 4201, "duplicate buy does not charge")

-- 5. Fremdkonto-Schutz.
local foreign = call("EconomyTransfer", { targetUserId = 1002 })
check(foreign.ok == false and foreign.code == "access_denied", "foreign wallet rejected")
local ownTransfer = call("EconomyTransfer", { targetUserId = 1001 })
check(ownTransfer.ok == true and ownTransfer.cash == 4201, "own wallet readable")

-- 6. Shop: Katalog und zwei Bestellungen.
local catalogResult = call("ShopCatalog", { action = "list" })
check(catalogResult.ok == true and #catalogResult.parts > 0, "ShopCatalog returns parts")

local chosenPart: any = nil
for _, part in PartsCatalog.getPartsForModel("puch_maxi_s") do
	if part.price > 0 and part.price <= 4201 then
		chosenPart = part
		break
	end
end
check(chosenPart ~= nil, "compatible shop part found")

local firstBuy = call("ShopBuy", { action = "buy", partId = chosenPart.id })
check(firstBuy.ok == true, "ShopBuy first order ok")
check(firstBuy.inventory[chosenPart.id] == 1, "first order in inventory")
check(firstBuy.cash == 4201 - chosenPart.price, "first order charges catalog price")

local secondBuy = call("ShopBuy", { action = "buy", partId = chosenPart.id })
check(secondBuy.ok == true, "ShopBuy second order ok")
check(secondBuy.inventory[chosenPart.id] == 2, "second order in inventory")
check(secondBuy.cash == 4201 - 2 * chosenPart.price, "second order charges catalog price")

-- 7. Werkstatt: Einbau und Lackierung auf dem eigenen Mofa.
local installResult = call(
	"WorkshopInstall",
	{ vehicleId = "puch_maxi_s", partId = chosenPart.id }
)
check(installResult.ok == true, "WorkshopInstall ok")
check(installResult.parts[chosenPart.slot] == chosenPart.id, "installed part occupies its slot")
check(installResult.inventory[chosenPart.id] == 1, "install consumes one inventory item")
check(store:cash(1001) == secondBuy.cash, "install does not charge cash")

local paintResult = call(
	"WorkshopPaint",
	{ vehicleId = "puch_maxi_s", surface = "body", color = "#FF0000" }
)
check(paintResult.ok == true, "WorkshopPaint ok")
check(paintResult.colors.body == "#FF0000", "paint stored on vehicle")

-- 8. Garage: serverseitige Zuweisung wird geliefert.
local garageResult = call("GarageEnter", {})
check(garageResult.ok == true and garageResult.garage == "Garage_01", "GarageEnter returns own garage")

-- 9. Mission: 500 m Fahrrad, Auszahlung genau einmal.
missionService:addDistance(1001, 250, { vehicleId = "bicycle", isOwnVehicle = true, speedKmh = 20 })
missionService:addDistance(1001, 250, { vehicleId = "bicycle", isOwnVehicle = true, speedKmh = 20 })
check(missionService:isCompleted(1001, "bike_starter_500m") == true, "bike mission completed")

local cashBeforeClaim = store:cash(1001)
local claimResult = call("MissionProgress", { missionKey = "bike_starter_500m", claim = true })
check(claimResult.ok == true, "MissionProgress claim ok")
check(claimResult.cash == cashBeforeClaim + 50, "mission reward credited once")
local claimAgain = call("MissionProgress", { missionKey = "bike_starter_500m", claim = true })
check(claimAgain.ok == false and claimAgain.code == "already_claimed", "mission cannot be claimed twice")

-- 10. Dyno/Tanken antworten mit echten Service-Codes, nicht unknown_action.
fuelService:RegisterVehicle(store:vehicleKey(1001, "puch_maxi_s"), 1001, {
	modelId = "puch_maxi_s",
	tankVolume = 5,
})
dynoService:RegisterVehicle(store:vehicleKey(1001, "puch_maxi_s"), 1001, {
	id = "puch_maxi_s",
	modelId = "puch_maxi_s",
}, {})

local dynoResult = call("DynoRun", { vehicleId = "puch_maxi_s" })
check(dynoResult.ok == false and dynoResult.code ~= "unknown_action", "DynoRun answers with service code")

local fuelResult = call("FuelRefill", { vehicleId = "puch_maxi_s", liters = 1 })
check(fuelResult.ok == false and fuelResult.code ~= "unknown_action", "FuelRefill answers with service code")

local rescueResult = call("FuelRefill", { action = "requestRescue" })
check(rescueResult.code ~= "unknown_action", "FuelRefill rescue path is routed")

-- 11. Guthaben bleibt ueber alle Handler konsistent.
local finalSelect = call("VehicleSelect", { action = "getActive" })
local finalEconomy = call("EconomyGet", {})
check(finalSelect.ok == true and finalEconomy.ok == true, "final cash queries ok")
check(finalSelect.cash == finalEconomy.cash, "VehicleSelect.cash == EconomyGet.cash")
check(finalSelect.cash == store:cash(1001), "cash matches PlayerStore")

-- 12. Persistenz: Rabatt, Besitz, Inventar und Teile ueberleben Release/Reload.
local savedCash = store:cash(1001)
local saveOk, saveErr = store:save(1001)
check(saveOk == true and saveErr == nil, "profile saved")
local releaseOk = store:release(1001)
check(releaseOk == true, "profile released")
check(store:loadedCount() == 0, "no profiles left in memory")

local reloaded = store:load(1001)
check(reloaded.starterDiscountUsed == true, "discount flag persists")
check(store:owns(1001, "puch_maxi_s") == true, "moped ownership persists")
check(store:cash(1001) == savedCash, "cash persists")
check(store:workshopVehicle(1001, "puch_maxi_s").parts[chosenPart.slot] == chosenPart.id, "installed part persists")
check(reloaded.schema.paints.body == "#FF0000", "paint persists")

local afterReload = call("EconomyGet", {})
check(afterReload.ok == true and afterReload.cash == savedCash, "cash after rejoin matches")

-- K-04: nach Rejoin kein zweiter Startrabatt auf ein anderes Mofa.
local secondMoped = call("VehicleBuy", { vehicleId = "piaggio_ciao" })
check(secondMoped.ok == true, "full-price moped purchase ok")
check(secondMoped.receipt.discountApplied == false, "no second starter discount after rejoin")
check(secondMoped.receipt.pricePaid == 1399, "full moped price charged")

print(string.format("ALL GenericHandlers SPEC TESTS PASSED (%d checks)", passed))
