--!strict
-- EconomyService.spec: ausfuehrbar via `lune run tests/EconomyService.spec.luau`.
local EconomyService = require("../src/server/services/EconomyService")

local passed = 0

local function check(condition: boolean, label: string)
	if not condition then
		error("FAILED: " .. label, 2)
	end
	passed += 1
	print("ok: " .. label)
end

-- 1. Startguthaben und Zugriffsschutz.
do
	local service = EconomyService.new()
	check(service:getBalance("player-1") == 0, "startguthaben ist 0")
	local own = service:getBalanceFor("player-1", "player-1")
	check(own == 0, "eigener kontostand lesbar")
	local foreign, err = service:getBalanceFor("player-1", "player-2")
	check(foreign == nil and err == "access_denied", "fremder kontostand verweigert")
	local invalid, invalidErr = service:getBalanceFor("player-1", "")
	check(invalid == nil and invalidErr == "invalid_user", "ungueltiger spieler abgelehnt")
end

-- 2. Gutschrift mit Idempotenz (keine doppelte Belohnung).
do
	local service = EconomyService.new()
	local ok, balance = service:credit("player-1", 150, "tx-credit-1")
	check(ok == true and balance == 150, "gutschrift erhoeht guthaben")
	local okReplay, balanceReplay = service:credit("player-1", 150, "tx-credit-1")
	check(okReplay == true and balanceReplay == 150, "gleiche transaktions-id wird nicht doppelt gutgeschrieben")
	check(service:getBalance("player-1") == 150, "guthaben nach replay unveraendert")
	local okConflict, errConflict = service:credit("player-1", 200, "tx-credit-1")
	check(okConflict == false and errConflict == "duplicate_transaction_id", "transaktions-id mit anderem betrag abgelehnt")
end

-- 3. Abbuchung, kein negativer Kontostand.
do
	local service = EconomyService.new()
	service:setBalance("player-1", 100)
	local ok, balance = service:debit("player-1", 40, "tx-debit-1")
	check(ok == true and balance == 60, "abbuchung reduziert guthaben")
	local okReplay, balanceReplay = service:debit("player-1", 40, "tx-debit-1")
	check(okReplay == true and balanceReplay == 60, "gleiche abbuchung wird nicht doppelt abgezogen")
	local okEmpty, errEmpty = service:debit("player-1", 100, "tx-debit-2")
	check(okEmpty == false and errEmpty == "insufficient_funds", "abbuchung ueber guthaben abgelehnt")
	check(service:getBalance("player-1") == 60, "guthaben nach abgelehnter abbuchung unveraendert")
end

-- 4. Ungueltige Betraege und Transaktions-IDs.
do
	local service = EconomyService.new()
	local okZero, _ = service:credit("player-1", 0, "tx-bad-1")
	check(okZero == false, "nullbetrag abgelehnt")
	local okNegative, _ = service:credit("player-1", -10, "tx-bad-2")
	check(okNegative == false, "negativbetrag abgelehnt")
	local okFraction, _ = service:credit("player-1", 10.5, "tx-bad-3")
	check(okFraction == false, "bruchbetrag abgelehnt")
	local okEmptyTx, errEmptyTx = service:credit("player-1", 10, "")
	check(okEmptyTx == false and errEmptyTx == "invalid_transaction_id", "leere transaktions-id abgelehnt")
	local okCrossKind, _ = service:credit("player-1", 10, "tx-kind-1")
	check(okCrossKind == true, "erste buchung mit id ok")
	local okCrossKindConflict, errCrossKind = service:debit("player-1", 10, "tx-kind-1")
	check(okCrossKindConflict == false and errCrossKind == "duplicate_transaction_id", "id ueber kredit/debit nicht wiederverwendbar")
end

-- 5. Transaktions-IDs sind pro Spieler isoliert.
do
	local service = EconomyService.new()
	local okA, balanceA = service:credit("player-a", 50, "tx-shared")
	local okB, balanceB = service:credit("player-b", 50, "tx-shared")
	check(okA == true and balanceA == 50, "spieler a erhaelt gutschrift")
	check(okB == true and balanceB == 50, "gleiche id bei anderem spieler unabhaengig")
	check(service:hasProcessed("player-a", "tx-shared") == true, "transaktion fuer spieler a markiert")
	check(service:hasProcessed("player-b", "tx-shared") == true, "transaktion fuer spieler b markiert")
	check(service:hasProcessed("player-a", "tx-missing") == false, "unbekannte transaktion nicht markiert")
end

print("EconomyService.spec: " .. tostring(passed) .. " checks passed")
