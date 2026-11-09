-- RateLimiter.spec: Beweist Ratelimits pro Spieler/Aktion,
-- sichere Fehlerantworten und In-Flight-Schutz im Router.
-- Keine globalen Variablen.

local RateLimiter = require("../src/shared/net/RateLimiter")
local RequestRouter = require("../src/server/net/RequestRouter")

local passed = 0

local function check(condition: boolean, label: string)
	if not condition then
		error("FAIL: " .. label)
	end
	passed += 1
end

local function player(userId: number): any
	return { UserId = userId }
end

-- 1. Erlaubt Anfragen bis zum Limit, blockt darueber im Fenster.
do
	local limiter = RateLimiter.new({ defaultLimit = 3, defaultWindow = 10 })
	local p = player(101)
	check(limiter:check(p, "ShopBuy", 100.0) == true, "slot 1 erlaubt")
	check(limiter:check(p, "ShopBuy", 100.1) == true, "slot 2 erlaubt")
	check(limiter:check(p, "ShopBuy", 100.2) == true, "slot 3 erlaubt")
	check(limiter:check(p, "ShopBuy", 100.3) == false, "slot 4 im Fenster blockiert")
end

-- 2. Fenster laeuft ab, danach wieder erlaubt.
do
	local limiter = RateLimiter.new({ defaultLimit = 1, defaultWindow = 5 })
	local p = player(102)
	check(limiter:check(p, "MissionClaim", 0.0) == true, "erste Anfrage erlaubt")
	check(limiter:check(p, "MissionClaim", 1.0) == false, "zweite im Fenster blockiert")
	check(limiter:check(p, "MissionClaim", 6.0) == true, "nach Fensterablauf erlaubt")
end

-- 3. Isolation pro Spieler und pro Aktion.
do
	local limiter = RateLimiter.new({ defaultLimit = 1, defaultWindow = 60 })
	local a = player(201)
	local b = player(202)
	check(limiter:check(a, "ShopBuy", 0.0) == true, "spieler A erlaubt")
	check(limiter:check(a, "ShopBuy", 0.1) == false, "spieler A danach limitiert")
	check(limiter:check(b, "ShopBuy", 0.1) == true, "spieler B unabhaengig erlaubt")
	check(limiter:check(a, "MissionClaim", 0.1) == true, "andere Aktion unabhaengig erlaubt")
end

-- 4. Ungueltige Eingaben werden sicher abgewiesen.
do
	local limiter = RateLimiter.new()
	check(limiter:check(player(301), "", 0.0) == false, "leere Aktion abgewiesen")
	check(limiter:check({} , "ShopBuy", 0.0) == false, "spieler ohne UserId abgewiesen")
	check(limiter:check(player(301), "ShopBuy", 0.0) == true, "gueltige Anfrage erlaubt")
	check(limiter:acquire(player(301), "") == false, "leerer Lock abgelehnt")
end

-- 5. In-Flight-Schutz gegen doppelte parallele Aktionen.
do
	local limiter = RateLimiter.new()
	local p = player(401)
	check(limiter:acquire(p, "WorkshopInstall") == true, "erster Lock erfolgreich")
	check(limiter:acquire(p, "WorkshopInstall") == false, "zweiter paralleler Lock blockiert")
	check(limiter:isLocked(p, "WorkshopInstall") == true, "isLocked meldet aktiven Lock")
	check(limiter:release(p, "WorkshopInstall") == true, "release erfolgreich")
	check(limiter:isLocked(p, "WorkshopInstall") == false, "nach release entsperrt")
	check(limiter:acquire(p, "WorkshopInstall") == true, "nach release erneut erlaubt")
	check(limiter:reset() == true, "reset erfolgreich")
	check(limiter:isLocked(p, "WorkshopInstall") == false, "reset loescht Locks")
end

-- 6. Router laesst legitime UI-Nutzung durch.
do
	local limiter = RateLimiter.new({ defaultLimit = 30, defaultWindow = 1.0 })
	local router = RequestRouter.new(limiter)
	router:register("RateSpecPing", function(_player: any, _payload: any)
		return { echo = true }
	end)
	local p = player(501)
	for _ = 1, 5 do
		local response = router:handle(p, "RateSpecPing", {})
		check(response.ok == true, "legitime UI-Anfrage passiert")
	end
end

-- 7. Router begrenzt Spam mit sicherer Fehlerantwort ohne Details.
do
	local limiter = RateLimiter.new({ defaultLimit = 2, defaultWindow = 60 })
	local router = RequestRouter.new(limiter)
	router:register("RateSpecBuy", function(_player: any, _payload: any)
		return { bought = true }
	end)
	local p = player(502)
	check(router:handle(p, "RateSpecBuy", {}).ok == true, "kauf 1 ok")
	check(router:handle(p, "RateSpecBuy", {}).ok == true, "kauf 2 ok")
	local limited = router:handle(p, "RateSpecBuy", {})
	check(limited.ok == false, "kauf 3 limitiert")
	check(limited.code == "rate_limited", "code rate_limited")
	check(type(limited.message) == "string", "sichere Nachricht vorhanden")
	check(string.find(limited.message, "bought") == nil, "kein internes Detail in Nachricht")
end

-- 8. Router meldet parallele Aktion als busy und gibt Lock wieder frei.
do
	local limiter = RateLimiter.new()
	local router = RequestRouter.new(limiter)
	router:register("RateSpecInstall", function(_player: any, _payload: any)
		return { installed = true }
	end)
	local p = player(503)
	check(limiter:acquire(p, "RateSpecInstall") == true, "externer Lock gesetzt")
	local busy = router:handle(p, "RateSpecInstall", {})
	check(busy.ok == false, "parallele Anfrage abgewiesen")
	check(busy.code == "busy", "code busy")
	check(limiter:release(p, "RateSpecInstall") == true, "externer Lock freigegeben")
	local after = router:handle(p, "RateSpecInstall", {})
	check(after.ok == true, "nach Freigabe wieder erlaubt")
	-- Sequentielle Router-Aufrufe duerfen sich nicht selbst blockieren.
	local second = router:handle(p, "RateSpecInstall", {})
	check(second.ok == true, "sequentieller Umbau erlaubt")
	check(limiter:isLocked(p, "RateSpecInstall") == false, "router gibt Lock nach Handler frei")
end

-- 9. Router gibt Lock auch bei Handler-Fehler frei und behält alte Fehlercodes.
do
	local limiter = RateLimiter.new()
	local router = RequestRouter.new(limiter)
	router:register("RateSpecCrash", function(_player: any, _payload: any)
		error("boom")
	end)
	router:register("RateSpecOk", function(_player: any, _payload: any)
		return { okEcho = true }
	end)
	local p = player(504)
	local failed = router:handle(p, "RateSpecCrash", {})
	check(failed.ok == false, "handler-fehler abgefangen")
	check(failed.code == "handler_error", "code handler_error")
	check(limiter:isLocked(p, "RateSpecCrash") == false, "lock nach fehler freigegeben")
	check(router:handle(p, "RateSpecOk", {}).ok == true, "router danach nutzbar")
	check(router:handle(p, "NoSuchAction", {}).code == "unknown_action", "unbekannte Aktion abgewiesen")
	check(router:handle(p, "RateSpecOk", "kein-table").code == "invalid_payload", "ungueltige Payload abgewiesen")
end

-- 10. setLimit erlaubt aktionsspezifische Haertung.
do
	local limiter = RateLimiter.new({ defaultLimit = 30, defaultWindow = 1.0 })
	limiter:setLimit("RateSpecStrict", 1, 60)
	local p = player(505)
	check(limiter:check(p, "RateSpecStrict", 0.0) == true, "strikt: erste erlaubt")
	check(limiter:check(p, "RateSpecStrict", 0.1) == false, "strikt: zweite blockiert")
	check(limiter:check(p, "RateSpecLoose", 0.1) == true, "default bleibt grosszuegig")
end

print("RateLimiter.spec: OK (" .. tostring(passed) .. " checks)")
