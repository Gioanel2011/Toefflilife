--!strict
-- PlayerStoreGrant.spec: prueft das Studio-/Abnahme-Testguthaben
-- (`sessionGrantCash`) und den normalen Kaufpfad mit diesem Guthaben.
-- Laeuft mit `lune run tests/PlayerStoreGrant.spec.luau`.
-- Keine Roblox-Laufzeit, keine globalen Variablen.

local ProfileAdapter = require("../src/server/services/ProfileAdapter")
local ProfileService = require("../src/server/services/ProfileService")
local PlayerStore = require("../src/server/services/PlayerStore")
local EconomyService = require("../src/server/services/EconomyService")
local VehicleService = require("../src/server/services/VehicleService")
local PlayerDataSchema = require("../src/shared/data/PlayerDataSchema")

local passed = 0
local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	passed += 1
	print("PASS: " .. label)
end

local function buildStore(grant: any): (any, any, any)
	local adapter = ProfileAdapter.memory()
	local profiles = ProfileService.new(adapter, PlayerDataSchema)
	local economy = EconomyService.new()
	local store = PlayerStore.new({
		profiles = profiles,
		economy = economy,
		sessionGrantCash = grant,
	})
	return store, profiles, economy
end

-- 1. Ohne Grant bleibt ein neues Profil bei 0 CHF.
do
	local store, _profiles, economy = buildStore(nil)
	store:load(2001)
	check(store:cash(2001) == 0, "no grant keeps fresh cash at 0")
	check(economy:getBalance(2001) == 0, "no grant keeps economy at 0")
end

-- 2. Grant hebt ein leeres Profil auf das Session-Minimum, ohne es zu speichern.
do
	local store, _profiles, economy = buildStore(5000)
	local view = store:load(2002)
	check(view.money == 5000, "grant floors fresh cash to 5000")
	check(store:cash(2002) == 5000, "store cash reports grant")
	check(economy:getBalance(2002) == 5000, "economy balance receives grant")
	check(view.schema.cash == 0, "grant is not written into the saved schema on load")
end

-- 3. Grant ist nur ein Minimum: hoeheres gespeichertes Guthaben bleibt.
do
	local adapter = ProfileAdapter.memory()
	local profiles = ProfileService.new(adapter, PlayerDataSchema)
	local seeded = profiles:load(2003)
	seeded.cash = 9000
	local saved, saveErr = profiles:save(2003)
	check(saved == true and saveErr == nil, "seeded profile saved")
	profiles:release(2003)

	local economy = EconomyService.new()
	local store = PlayerStore.new({
		profiles = profiles,
		economy = economy,
		sessionGrantCash = 5000,
	})
	store:load(2003)
	check(store:cash(2003) == 9000, "grant never lowers stored cash")
	check(economy:getBalance(2003) == 9000, "economy keeps stored cash")
end

-- 4. Ungueltige Grant-Werte werden abgelehnt (kein Gratisgeld).
do
	local invalidGrants: { any } = { -5, "5000", 0 / 0 }
	for _, invalid in ipairs(invalidGrants) do
		local store, _profiles, _economy = buildStore(invalid)
		store:load(2004)
		check(store:cash(2004) == 0, string.format("invalid grant %s is ignored", tostring(invalid)))
		store:release(2004)
	end
end

-- 5. Ungerade Grant-Werte werden abgerundet und bleiben ganzzahlig.
do
	local store, _profiles, economy = buildStore(1500.9)
	store:load(2005)
	check(store:cash(2005) == 1500, "grant is floored to whole CHF")
	check(economy:getBalance(2005) == 1500, "economy receives floored grant")
end

-- 6. Echter Kaufpfad mit Testguthaben: Startrabatt wird serverseitig gebucht.
do
	local store, _profiles, economy = buildStore(5000)
	local vehicles = VehicleService.new()
	local view = store:load(2006)
	local bought, receipt = vehicles:purchase(view, "puch_maxi_s", 2006)
	check(bought == true, "moped purchase succeeds with grant")
	check(type(receipt) == "table" and receipt.pricePaid == 799, "starter discount price charged")
	store:commitMoney(2006)
	check(store:cash(2006) == 4201, "grant minus price remains in store")
	check(economy:getBalance(2006) == 4201, "economy matches after purchase")
	check(store:owns(2006, "puch_maxi_s") == true, "purchase records ownership")
end

-- 7. Nach Speichern und Rejoin greift der Grant erneut als Session-Minimum.
do
	local store, _profiles, economy = buildStore(5000)
	local vehicles = VehicleService.new()
	local view = store:load(2007)
	vehicles:purchase(view, "puch_maxi_s", 2007)
	store:commitMoney(2007)
	local saved, saveErr = store:save(2007)
	check(saved == true and saveErr == nil, "purchase profile saved")
	check(store:release(2007) == true, "profile released")

	local reloaded = store:load(2007)
	check(reloaded.schema.cash == 4201, "saved cash stays at 4201")
	check(store:cash(2007) == 5000, "rejoin re-applies session grant")
	check(economy:getBalance(2007) == 5000, "economy gets rejoin grant")
	check(store:owns(2007, "puch_maxi_s") == true, "owned moped survives rejoin")
end

print(string.format("ALL PlayerStoreGrant SPEC TESTS PASSED (%d checks)", passed))
