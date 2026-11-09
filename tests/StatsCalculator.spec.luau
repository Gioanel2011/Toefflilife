--!strict
-- StatsCalculator.spec: Lune-Runner fuer Task 14.
-- Beweis: `lune run tests/StatsCalculator.spec.luau` ist erfolgreich.

local StatsCalculator: any = nil
local lastRequireError: string? = nil
for _, path in ipairs({
	"../src/shared/vehicle/StatsCalculator",
	"./src/shared/vehicle/StatsCalculator",
	"src/shared/vehicle/StatsCalculator",
}) do
	local ok, mod = pcall(require, path)
	if ok then
		StatsCalculator = mod
		break
	else
		lastRequireError = tostring(mod)
	end
end
if StatsCalculator == nil then
	error("StatsCalculator konnte nicht geladen werden: " .. tostring(lastRequireError))
end

local passed = 0
local function check(condition: boolean, label: string)
	if not condition then
		error("FEHLGESCHLAGEN: " .. label)
	end
	passed += 1
end

local function baseMoped(): any
	return {
		id = "puch_maxi_s",
		powerKw = 1.1,
		torqueNm = 2.5,
		topSpeedKmh = 45,
		acceleration = 3.0,
		braking = 8.0,
		grip = 1.0,
		consumption = 1.8,
		weightKg = 70,
	}
end

local function baseBicycle(): any
	return {
		id = "bicycle",
		powerKw = 0.3,
		torqueNm = 0,
		topSpeedKmh = 22,
		acceleration = 2.0,
		braking = 6.0,
		grip = 1.0,
		consumption = 0,
		weightKg = 15,
	}
end

-- 1) Basis ohne Teile: Werte werden unveraendert (gerundet) uebernommen.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {})
	check(stats ~= nil and err == nil, "basis ohne teile ok")
	check(stats.powerKw == 1.1, "basis leistung")
	check(stats.peakTorqueNm == 2.5, "basis drehmoment")
	check(stats.topSpeedKmh == 45, "basis vmax")
	check(stats.partCount == 0, "basis partCount")
	check(#stats.torqueCurve == 5, "drehmomentkurve hat 5 punkte")
	check(stats.torqueCurve[3].rpm == 6000, "kurven-peak bei 6000 rpm")
	check(stats.torqueCurve[3].torqueNm == 2.5, "kurven-peak entspricht spitze")
end

-- 2) Teile stapeln sich additiv.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {
		{ id = "sport_exhaust_1", slot = "exhaust", statDeltas = { powerKw = 0.3, topSpeedKmh = 4 } },
		{ id = "sport_brakes_1", slot = "brakes", statDeltas = { braking = 2.0 } },
	})
	check(stats ~= nil and err == nil, "teile-setup ok")
	check(stats.powerKw == 1.4, "leistung addiert")
	check(stats.topSpeedKmh == 49, "vmax addiert")
	check(stats.braking == 10, "bremskraft addiert")
	check(stats.partCount == 2, "partCount 2")
end

-- 3) Doppelter Slot wird abgelehnt.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {
		{ id = "a", slot = "exhaust", statDeltas = { powerKw = 0.1 } },
		{ id = "b", slot = "exhaust", statDeltas = { powerKw = 0.2 } },
	})
	check(stats == nil and type(err) == "string", "doppelter slot abgelehnt")
end

-- 4) Inkompatibles Teil wird abgelehnt.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {
		{
			id = "ciao_only_part",
			slot = "cylinder",
			compatibleModels = { "piaggio_ciao" },
			statDeltas = { powerKw = 0.5 },
		},
	})
	check(stats == nil and type(err) == "string", "inkompatibles teil abgelehnt")
end

-- 5) Kompatibles Teil mit Modellliste wird akzeptiert.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {
		{
			id = "maxi_cylinder",
			slot = "cylinder",
			compatibleModels = { "puch_maxi_s" },
			statDeltas = { powerKw = 0.5 },
		},
	})
	check(stats ~= nil and err == nil, "kompatibles teil akzeptiert")
	check(stats.powerKw == 1.6, "kompatibles teil wirkt")
end

-- 6) Fahrrad: Motorteile und Verbrauch werden abgelehnt.
do
	local stats1, err1 = StatsCalculator.calculate(baseBicycle(), {
		{ id = "motor", slot = "cylinder", statDeltas = { powerKw = 1.0 } },
	})
	check(stats1 == nil and type(err1) == "string", "fahrrad motorteil abgelehnt")
	local bikeStats, bikeErr = StatsCalculator.calculate(baseBicycle(), {})
	check(bikeStats ~= nil and bikeErr == nil, "fahrrad basis ok")
	check(#bikeStats.torqueCurve == 0, "fahrrad ohne drehmomentkurve")
	check(bikeStats.consumptionPer100Km == 0, "fahrrad ohne verbrauch")
	local stats2, err2 = StatsCalculator.calculate(baseBicycle(), {
		{ id = "tank", slot = "rims", statDeltas = { consumption = 1.0 } },
	})
	check(stats2 == nil and type(err2) == "string", "fahrrad verbrauch abgelehnt")
end

-- 7) Ungueltige Basis und unsinnige Ergebnisse werden abgelehnt.
do
	local stats1, _ = StatsCalculator.calculate(nil, {})
	check(stats1 == nil, "nil-basis abgelehnt")
	local bad = baseMoped()
	bad.powerKw = 0
	local stats2, _ = StatsCalculator.calculate(bad, {})
	check(stats2 == nil, "null-leistung abgelehnt")
	local stats3, _ = StatsCalculator.calculate(baseMoped(), {
		{ id = "drossel", slot = "exhaust", statDeltas = { powerKw = -5.0 } },
	})
	check(stats3 == nil, "negative leistung abgelehnt")
end

-- 8) Determinismus: derselbe Input liefert exakt denselben Output (Dyno == Physik).
do
	local parts = {
		{ id = "p1", slot = "exhaust", statDeltas = { powerKw = 0.25, consumption = 0.1 } },
		{ id = "p2", slot = "brakes", statDeltas = { braking = 1.5, weightKg = 1.0 } },
	}
	local first: any, _ = StatsCalculator.calculate(baseMoped(), parts)
	local second: any, _ = StatsCalculator.calculate(baseMoped(), parts)
	check(first ~= nil and second ~= nil, "determinismus laeuft")
	check(first.powerKw == second.powerKw, "deterministische leistung")
	check(first.topSpeedKmh == second.topSpeedKmh, "deterministische vmax")
	check(first.braking == second.braking, "deterministische bremse")
	check(first.weightKg == second.weightKg, "deterministisches gewicht")
	check(#first.torqueCurve == #second.torqueCurve, "deterministische kurve")
	-- Eingaben duerfen nicht mutiert werden.
	check(parts[1].statDeltas.powerKw == 0.25, "eingaben nicht mutiert")
end

-- 9) Grip und Verbrauch werden verrechnet und geclampt.
do
	local stats, err = StatsCalculator.calculate(baseMoped(), {
		{ id = "grips", slot = "wheels", statDeltas = { grip = 0.25, consumption = -0.3 } },
	})
	check(stats ~= nil and err == nil, "grip-setup ok")
	check(stats.grip == 1.25, "grip addiert")
	check(stats.consumptionPer100Km == 1.5, "verbrauch addiert")
end

print("StatsCalculator.spec: " .. tostring(passed) .. " Pruefungen bestanden.")
