-- PlayerIds.spec: kanonische Spieler-IDs fuer Studio-Mehrclient.
-- Laeuft mit `lune run tests/PlayerIds.spec.luau`.

local PlayerIds = require("../src/server/net/PlayerIds")

local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	print("PASS: " .. label)
end

-- Reale IDs bleiben unveraendert, unabhaengig vom Studio-Flag.
check(PlayerIds.canonical(8195446797, false) == 8195446797, "real id unchanged")
check(PlayerIds.canonical(8195446797, true) == 8195446797, "real id unchanged in studio")

-- Simulierte Studio-IDs werden nur mit Freigabe abgebildet.
check(PlayerIds.canonical(-1, true) == 9000000001, "first simulated id mapped in studio")
check(PlayerIds.canonical(-8, true) == 9000000008, "eighth simulated id mapped in studio")
check(PlayerIds.canonical(-1, false) == nil, "simulated id rejected outside studio")
check(PlayerIds.canonical(-1) == nil, "simulated id rejected by default")

-- Ungueltige Werte werden immer abgewiesen.
check(PlayerIds.canonical(0, true) == nil, "zero rejected")
check(PlayerIds.canonical(1.5, true) == nil, "non-integer rejected")
check(PlayerIds.canonical(0 / 0, true) == nil, "nan rejected")
check(PlayerIds.canonical(math.huge, true) == nil, "infinity rejected")
check(PlayerIds.canonical(-math.huge, true) == nil, "negative infinity rejected")
check(PlayerIds.canonical("1", true) == nil, "string rejected")
check(PlayerIds.canonical(nil, true) == nil, "nil rejected")

-- Klassifikation.
check(PlayerIds.isSimulated(-3) == true, "negative id is simulated")
check(PlayerIds.isSimulated(3) == false, "positive id is not simulated")
check(PlayerIds.isSimulated(0) == false, "zero is not simulated")
check(PlayerIds.SIMULATED_OFFSET == 9000000000, "offset is documented")

-- Alle 15 Studio-Clients erhalten eindeutige kanonische IDs.
local seen: { [number]: boolean } = {}
local unique = true
for index = 1, 15 do
	local id = PlayerIds.canonical(-index, true)
	if id == nil or seen[id] then
		unique = false
	else
		seen[id] = true
	end
end
check(unique, "fifteen simulated ids are unique")

print("ALL PlayerIds SPEC TESTS PASSED")
