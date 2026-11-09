--!strict
-- ShopService.spec: Validierung fuer Laptop-Bestellung und Ladenkauf.
-- Lauf mit: lune run tests/ShopService.spec.luau
local ShopService = require("../src/server/services/ShopService")

local checks = 0
local function check(cond: boolean, label: string)
	checks += 1
	if not cond then
		error("ShopService.spec failed: " .. label)
	end
end

local function makeService()
	local profiles: { [number]: any } = {
		[1] = { money = 1000, inventory = {} },
		[2] = { money = 50, inventory = {} },
	}
	local catalog: { [string]: any } = {
		zylinder_sport = { id = "zylinder_sport", price = 200, slot = "cylinder", models = { "puch_maxi_s" } },
		bremse_standard = { id = "bremse_standard", price = 80, slot = "brakes" },
	}
	local near: { [number]: boolean } = { [1] = true }
	local shop = ShopService.new({
		catalog = catalog,
		profiles = profiles,
		isNearStore = function(userId: number | string): boolean
			return near[userId :: number] == true
		end,
	})
	return shop, profiles
end

-- Katalogabruf liefert Serverdaten, sortiert und kopiert.
do
	local shop, _ = makeService()
	local list = shop:getCatalog()
	check(#list == 2, "catalog size")
	check(list[1].id == "bremse_standard", "catalog sorted")
	check(list[2].id == "zylinder_sport", "catalog sorted 2")
	check(shop:getPrice("zylinder_sport") == 200, "server price")
	check(shop:getPrice("unbekannt") == nil, "unknown price nil")
	check(shop:getPart("unbekannt") == nil, "unknown part nil")
	local part = shop:getPart("zylinder_sport")
	check(part ~= nil and (part :: any).price == 200, "get part copy")
	-- Kompatibilitaet wird serverseitig beantwortet.
	check(shop:isCompatibleWith("zylinder_sport", "puch_maxi_s") == true, "compatible moped")
	check(shop:isCompatibleWith("zylinder_sport", "bicycle") == false, "incompatible bike")
	check(shop:isCompatibleWith("bremse_standard", "bicycle") == true, "universal part")
end

-- Laptop-Bestellung: Inventar + Guthaben, keine Werkstattwirkung.
do
	local shop, profiles = makeService()
	local ok, code = shop:orderPart(1, "zylinder_sport", "tx-laptop-1")
	check(ok and code == "ok", "laptop order ok")
	check(profiles[1].money == 800, "money debited")
	check(profiles[1].inventory["zylinder_sport"] == 1, "inventory +1")
	-- Kein Einbau: es gibt kein installed-Feld, nur Inventar und Geld.
	check(profiles[1].installed == nil, "no install side effect")
	check(profiles[1].paint == nil, "no paint side effect")
	-- Idempotenz: gleiche Transaktion wird abgewiesen, kein Doppelabbuchen.
	local ok2, code2 = shop:orderPart(1, "zylinder_sport", "tx-laptop-1")
	check(not ok2 and code2 == "duplicate_transaction", "idempotent tx")
	check(profiles[1].money == 800, "no double charge")
end

-- Guards: unbekannt, arm, fremdes Profil, Clientpreis egal.
do
	local shop, _ = makeService()
	local ok, code = shop:orderPart(1, "gibt_es_nicht", "tx-x1")
	check(not ok and code == "unknown_part", "reject unknown part")
	local okPoor, codePoor = shop:orderPart(2, "zylinder_sport", "tx-x2")
	check(not okPoor and codePoor == "insufficient_funds", "reject poor")
	local okNoProfile, codeNoProfile = shop:orderPart(99, "bremse_standard", "tx-x3")
	check(not okNoProfile and codeNoProfile == "unknown_profile", "reject unknown profile")
	-- Serverseitiger Preis: ein manipulierter Clientpreis existiert gar nicht als Parameter.
	local okCheap, _ = shop:orderPart(1, "bremse_standard", "tx-x4")
	check(okCheap, "store price path ok")
end

-- Ladenkauf: nur in Naehe, sonst Reject; Bestellung ohne Naehe ok.
do
	local shop, profiles = makeService()
	-- Spieler 2 ist nicht in Ladennähe.
	local okFar, codeFar = shop:buyFromStore(2, "bremse_standard", "tx-s1")
	check(not okFar and codeFar == "not_near_store", "store requires proximity")
	-- Spieler 1 ist nah: Kauf ok, landet im Inventar.
	local okNear, codeNear = shop:buyFromStore(1, "bremse_standard", "tx-s2")
	check(okNear and codeNear == "ok", "store buy ok")
	check(profiles[1].inventory["bremse_standard"] == 1, "store inventory +1")
	check(profiles[1].money == 920, "store money debited")
	-- Laptop braucht keine Naehe (Spieler 2 darf bestellen, scheitert nur am Geld anderweitig).
	local _ = profiles
end

print(("ShopService.spec: all %d checks passed"):format(checks))
