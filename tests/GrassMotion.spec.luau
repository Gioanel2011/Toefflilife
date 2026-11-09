--!strict
-- GrassMotion.spec: prueft die reine Grasbewegung aus Task 29.
-- Lauf: lune run tests/GrassMotion.spec.luau
-- Geprueft werden: Tag-Kopplung an Task 28, feste Update-Rate, begrenzte
-- aktive Chunks, Hysterese, deterministischer Sway (endlich, begrenzt,
-- zeit- und seed-abhaengig) sowie sortierte, limitierte Chunk-Auswahl.

local GrassController = require("../src/client/controllers/GrassController")
local GrassFieldBuilder = require("../src/server/world/GrassFieldBuilder")

local checks = 0
local failures = 0

local function check(name: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(string.format("ok   %s", name))
		return
	end
	failures += 1
	if detail then
		print(string.format("FAIL %s -> %s", name, detail))
	else
		print(string.format("FAIL %s", name))
	end
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) < 1000000
end

-- API ---------------------------------------------------------------------

check("swayOffset ist eine Funktion", type(GrassController.swayOffset) == "function")
check("isChunkInRange ist eine Funktion", type(GrassController.isChunkInRange) == "function")
check("selectActiveChunks ist eine Funktion", type(GrassController.selectActiveChunks) == "function")
check("new ist eine Funktion", type(GrassController.new) == "function")
check("Tag koppelt an Task 28", GrassController.TAG_NAME == GrassFieldBuilder.TAG_NAME, tostring((GrassController :: any).TAG_NAME))

-- Performance-Budgets -----------------------------------------------------

check(
	"Update-Rate ist fest und begrenzt",
	GrassController.UPDATE_INTERVAL >= 0.1 and GrassController.UPDATE_INTERVAL <= 0.5,
	string.format("%.3f", GrassController.UPDATE_INTERVAL)
)
check(
	"aktive Chunks sind begrenzt",
	GrassController.MAX_ACTIVE_CHUNKS >= 1 and GrassController.MAX_ACTIVE_CHUNKS <= 40,
	tostring(GrassController.MAX_ACTIVE_CHUNKS)
)
check(
	"Hysterese: FAR > NEAR",
	GrassController.FAR_DISTANCE > GrassController.NEAR_DISTANCE,
	string.format("%d / %d", GrassController.NEAR_DISTANCE, GrassController.FAR_DISTANCE)
)
check(
	"Sway ist kurz und fahrneutral",
	math.abs(GrassController.SWAY_AMPLITUDE) > 0 and math.abs(GrassController.SWAY_AMPLITUDE) <= 0.15,
	string.format("%.3f", GrassController.SWAY_AMPLITUDE)
)

-- swayOffset: rein, deterministisch, begrenzt -------------------------------

local first = GrassController.swayOffset(123, 1.5)
local second = GrassController.swayOffset(123, 1.5)
check("Sway ist deterministisch", first == second)

local bounded = true
local finite = true
for seed = 0, 10 do
	for step = 0, 20 do
		local value = GrassController.swayOffset(seed * 977, step * 0.15)
		if math.abs(value) > math.abs(GrassController.SWAY_AMPLITUDE) + 0.0001 then
			bounded = false
		end
		if not isFinite(value) then
			finite = false
		end
	end
end
check("Sway ist auf Amplitude begrenzt", bounded)
check("Sway ist endlich", finite)

local variesOverTime = GrassController.swayOffset(42, 0) ~= GrassController.swayOffset(42, 1.0)
check("Sway bewegt sich ueber Zeit", variesOverTime)

local variesBySeed = GrassController.swayOffset(1, 2.0) ~= GrassController.swayOffset(999, 2.0)
check("Sway variiert je Seed", variesBySeed)

check("Sway mit NaN ist sicher", GrassController.swayOffset(0 / 0, 1) == 0)

-- isChunkInRange: Hysterese -------------------------------------------------

check("naher Chunk startet", GrassController.isChunkInRange(GrassController.NEAR_DISTANCE, false))
check("ferner Chunk startet nicht", not GrassController.isChunkInRange(GrassController.NEAR_DISTANCE + 1, false))
check(
	"aktiver Chunk bleibt in Hysterese an",
	GrassController.isChunkInRange((GrassController.NEAR_DISTANCE + GrassController.FAR_DISTANCE) / 2, true)
)
check("aktiver Chunk pausiert jenseits FAR", not GrassController.isChunkInRange(GrassController.FAR_DISTANCE + 1, true))
check("negative Distanz ist inaktiv", not GrassController.isChunkInRange(-5, false))

-- selectActiveChunks: nah, sortiert, limitiert ------------------------------

local playerPos = { x = 0, z = 0 }
local chunks = {
	{ chunkId = "c_far", x = 150, z = 0 },
	{ chunkId = "c_near", x = 10, z = 0 },
	{ chunkId = "c_mid", x = 50, z = 0 },
}
local selected = GrassController.selectActiveChunks(playerPos, chunks, 10, 200)
check(
	"Auswahl ist nach Distanz sortiert",
	#selected == 3 and selected[1] == "c_near" and selected[2] == "c_mid" and selected[3] == "c_far",
	table.concat(selected, ",")
)

local limited = GrassController.selectActiveChunks(playerPos, chunks, 1, 200)
check("Auswahl begrenzt aktive Chunks", #limited == 1 and limited[1] == "c_near", table.concat(limited, ","))

local empty = GrassController.selectActiveChunks(playerPos, chunks, 10, 5)
check("ferne Chunks werden pausiert", #empty == 0)

local beforeCount = #chunks
GrassController.selectActiveChunks(playerPos, chunks, 10, 200)
check("Eingabe wird nicht mutiert", #chunks == beforeCount)

local repeatRun = GrassController.selectActiveChunks(playerPos, chunks, 10, 200)
check(
	"Auswahl ist deterministisch",
	#repeatRun == #selected and repeatRun[1] == selected[1] and repeatRun[2] == selected[2]
)

check("Limit 0 waehlt nichts", #GrassController.selectActiveChunks(playerPos, chunks, 0, 200) == 0)

-- Controller-Lebenszyklus (ohne Roblox: Start ist No-Op, kein Fehler) --------

local controller = GrassController.new()
check("Controller wird erzeugt", controller ~= nil)
check("Controller kennt Start/Stop", type((controller :: any).Start) == "function" and type((controller :: any).Stop) == "function")

local startOk = pcall(function()
	return (controller :: any):Start()
end)
check("Start ohne Roblox wirft nicht", startOk)

local stopOk = pcall(function()
	(controller :: any):Stop()
end)
check("Stop ohne Roblox wirft nicht", stopOk)

-- Zusammenfassung -----------------------------------------------------------

print(string.format("\n%d Checks, %d Fehler", checks, failures))
if failures > 0 then
	error(string.format("GrassMotion.spec: %d von %d Checks fehlgeschlagen", failures, checks))
end
print("GrassMotion.spec: alle Checks bestanden")
