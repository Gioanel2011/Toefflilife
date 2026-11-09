--!strict
-- VehicleService.spec: Kauf, Besitz, Auswahl und einmaliger Startrabatt.

local VehicleService = require("../src/server/services/VehicleService")

local passed = 0
local function check(condition: boolean, message: string)
	if not condition then
		error("ASSERT FAILED: " .. message, 2)
	end
	passed += 1
end

local function freshProfile(money: number): { [string]: any }
	return {
		money = money,
		vehicles = {},
		selectedVehicle = nil,
		starterDiscountUsed = false,
	}
end

-- 1. Starter-Fahrrad wird kostenlos sichergestellt.
do
	local service = VehicleService.new()
	local profile = freshProfile(0)
	local created = service:ensureStarterBike(profile)
	check(created == true, "ensureStarterBike legt Fahrrad an")
	check(service:owns(profile, "bicycle") == true, "Fahrrad ist im Besitz")
	check(service:getSelected(profile) == "bicycle", "Fahrrad wird selektiert")
	local createdAgain = service:ensureStarterBike(profile)
	check(createdAgain == false, "ensureStarterBike ist idempotent")
end

-- 2. Erstes Mofa erhält den Startrabatt, Flag wird atomar verbraucht.
do
	local service = VehicleService.new()
	local profile = freshProfile(2000)
	service:ensureStarterBike(profile)
	local price, applied, _err = service:getPrice(profile, "puch_maxi_s")
	check(price == 799, "Rabattpreis für erstes Mofa gilt")
	check(applied == true, "Rabatt wird als verfügbar gemeldet")
	local ok, receipt: any = service:purchase(profile, "puch_maxi_s", "user-1")
	check(ok == true, "erster Mofakauf gelingt")
	check(receipt.pricePaid == 799, "Rabattpreis wurde abgebucht")
	check(receipt.discountApplied == true, "Receipt markiert Rabatt")
	check(profile["money"] == 2000 - 799, "Guthaben korrekt reduziert")
	check(service:owns(profile, "puch_maxi_s") == true, "Mofa ist im Besitz")
	check(profile["starterDiscountUsed"] == true, "Rabatt-Flag verbraucht")
	check(service:getSelected(profile) == "puch_maxi_s", "gekauftes Mofa selektiert")
end

-- 3. Zweites Mofa kostet den Normalpreis, kein Rabatt mehr.
do
	local service = VehicleService.new()
	local profile = freshProfile(5000)
	service:ensureStarterBike(profile)
	local ok1, _r1: any = service:purchase(profile, "puch_maxi_s", "user-1")
	check(ok1 == true, "erstes Mofa gekauft")
	local price2, applied2, _e2 = service:getPrice(profile, "piaggio_ciao")
	check(price2 == 1399, "zweites Mofa kostet Normalpreis")
	check(applied2 == false, "kein Rabatt für zweites Mofa")
	local ok2, receipt2: any = service:purchase(profile, "piaggio_ciao", "user-1")
	check(ok2 == true, "zweites Mofa gekauft")
	check(receipt2.pricePaid == 1399, "Normalpreis abgebucht")
	check(receipt2.discountApplied == false, "kein Rabatt im Receipt")
	check(service:hasStarterDiscountAvailable(profile) == false, "Rabatt danach unavailable")
end

-- 4. Doppelkauf, unbekannte Fahrzeuge und fehlender Besitz scheitern.
do
	local service = VehicleService.new()
	local profile = freshProfile(5000)
	service:ensureStarterBike(profile)
	local ok1, _r1: any = service:purchase(profile, "puch_maxi_s", "u")
	check(ok1 == true, "setup-kauf ok")
	local okDup, errDup: any = service:purchase(profile, "puch_maxi_s", "u")
	check(okDup == false and errDup == "already_owned", "Doppelkauf abgewiesen")
	local okUnknown, errUnknown: any = service:purchase(profile, "nosuchbike", "u")
	check(okUnknown == false and errUnknown == "unknown_vehicle", "unbekanntes Fahrzeug abgewiesen")
	local okSel, errSel: any = service:select(profile, "piaggio_ciao")
	check(okSel == false and errSel == "not_owned", "Auswahl ohne Besitz abgewiesen")
	local okSel2, _e: any = service:select(profile, "puch_maxi_s")
	check(okSel2 == true, "Auswahl mit Besitz gelingt")
	check(service:getSelected(profile) == "puch_maxi_s", "Auswahl übernommen")
end

-- 5. Zu wenig Geld: kein Abzug, Rabatt bleibt erhalten.
do
	local service = VehicleService.new()
	local profile = freshProfile(100)
	service:ensureStarterBike(profile)
	local ok, err: any = service:purchase(profile, "puch_maxi_s", "poor")
	check(ok == false and err == "insufficient_funds", "Kauf ohne Geld scheitert")
	check(profile["money"] == 100, "kein Geld abgebucht")
	check(service:owns(profile, "puch_maxi_s") == false, "kein Besitz bei Fehlkauf")
	check(profile["starterDiscountUsed"] == false, "Rabatt bleibt bei Fehlkauf erhalten")
	check(service:hasStarterDiscountAvailable(profile) == true, "Rabatt danach noch verfügbar")
end

-- 6. Parallele Anfrage (Lock) kann den Rabatt nicht doppelt nutzen.
do
	local service = VehicleService.new()
	local profile = freshProfile(5000)
	service:ensureStarterBike(profile);
	(service._locks :: any)[profile] = true
	local okBusy, errBusy: any = service:purchase(profile, "puch_maxi_s")
	check(okBusy == false and errBusy == "busy", "parallele Anfrage wird abgewiesen");
	(service._locks :: any)[profile] = nil
	local ok, receipt: any = service:purchase(profile, "puch_maxi_s")
	check(ok == true and receipt.discountApplied == true, "Kauf nach Unlock mit Rabatt")
	check(profile["starterDiscountUsed"] == true, "Rabatt genau einmal verbraucht")
end

-- 7. Rejoin mit verbrauchtem Rabatt: kein zweiter Rabatt.
do
	local service = VehicleService.new()
	-- Simuliertes reloadetes Profil nach erstem Mofakauf.
	local rejoined: { [string]: any } = {
		money = 5000,
		vehicles = { puch_maxi_s = true },
		selectedVehicle = "puch_maxi_s",
		starterDiscountUsed = true,
	}
	check(service:hasStarterDiscountAvailable(rejoined) == false, "Rabatt nach Rejoin verbraucht")
	local price, applied, _e = service:getPrice(rejoined, "piaggio_ciao")
	check(price == 1399 and applied == false, "kein Rabatt nach Rejoin")
	local ok, receipt: any = service:purchase(rejoined, "piaggio_ciao", "same-user")
	check(ok == true and receipt.discountApplied == false, "zweiter Kauf ohne Rabatt")
end

-- 8. Array-Profilform und injizierter Katalog werden unterstützt.
do
	local custom = {
		bicycle = { price = 0, kind = "bicycle" },
		puch_maxi_s = { price = 2000, starterPrice = 500, kind = "moped" },
		piaggio_ciao = { price = 1800, starterPrice = 400, kind = "moped" },
	}
	local service = VehicleService.new(custom)
	local profile: { [string]: any } = { money = 1000, vehicles = { "bicycle" } }
	local price, applied, _e = service:getPrice(profile, "piaggio_ciao")
	check(price == 400 and applied == true, "injizierter Rabattpreis gilt")
	local ok, receipt: any = service:purchase(profile, "piaggio_ciao", "arr-user")
	check(ok == true and receipt.pricePaid == 400, "Kauf mit Array-Profil gelingt")
	check(service:owns(profile, "piaggio_ciao") == true, "Besitz nach Array-Kauf")
	check(#service:getOwned(profile) == 2, "getOwned listet beide Fahrzeuge")
end

print("VehicleService.spec: " .. tostring(passed) .. " checks passed")
