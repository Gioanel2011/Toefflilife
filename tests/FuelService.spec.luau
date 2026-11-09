-- FuelService spec (lune-compatible).
local FuelService = require("../src/server/services/FuelService")

local function assertTrue(cond: boolean, message: string)
	if not cond then
		error("ASSERT FAILED: " .. message, 2)
	end
end

local function assertEqual(a: any, b: any, message: string)
	if a ~= b then
		error(("ASSERT FAILED: %s (expected=%s, got=%s)"):format(message, tostring(b), tostring(a)), 2)
	end
end

local function assertNear(a: number, b: number, eps: number, message: string)
	if math.abs(a - b) > eps then
		error(("ASSERT FAILED: %s (expected~%s, got=%s)"):format(message, tostring(b), tostring(a)), 2)
	end
end

local function makeService(overrides: any?): any
	overrides = overrides or {}
	local balances = { ["player-1"] = 100, ["player-2"] = 100 }
	local opts: any = {
		pricePerLiter = 2.0,
		defaultTankVolume = 3.0,
		baseConsumptionRate = 0.01,
		rescueLiters = 0.3,
		rescueCooldownSec = 300,
		balances = balances,
		clock = overrides.clock or function()
			return 1000
		end,
	}
	for key, value in pairs(overrides) do
		if key ~= "clock" then
			opts[key] = value
		end
	end
	local service = FuelService.new(opts)
	return service
end

-- 1. Bicycles never consume fuel and cannot be refueled.
do
	local service = makeService()
	service:RegisterVehicle("bike-1", "player-1", { modelId = "bicycle" })
	assertEqual(service:GetCapacity("bike-1"), 0, "bicycle capacity is zero")
	local consumed, remaining = service:Consume("bike-1", 10, 1)
	assertEqual(consumed, 0, "bicycle consumes nothing")
	assertEqual(remaining, 0, "bicycle fuel stays zero")
	service:SetAtGasStation("bike-1", true)
	local ok, err = service:Refuel("player-1", "bike-1", 1)
	assertTrue(not ok, "bicycle refuel must be rejected")
	assertEqual(err, "BicycleHasNoFuel", "bicycle refuel error")
	local okRescue, errRescue = service:RescueRefill("player-1", "bike-1")
	assertTrue(not okRescue, "bicycle rescue must be rejected")
	assertEqual(errRescue, "BicycleHasNoFuel", "bicycle rescue error")
end

-- 2. Consumption is load-dependent and never drives fuel negative.
do
	local service = makeService()
	service:RegisterVehicle("moped-a", "player-1", { modelId = "puch-maxi-s", tankVolume = 3.0, fuel = 3.0 })
	service:RegisterVehicle("moped-b", "player-1", { modelId = "puch-maxi-s", tankVolume = 3.0, fuel = 3.0 })
	local consumedIdle = service:Consume("moped-a", 100, 0)
	local consumedFull = service:Consume("moped-b", 100, 1)
	assertTrue(consumedFull > consumedIdle, "full load must consume more than idle")
	assertTrue(consumedIdle > 0, "idle still consumes a little")
	-- Drain completely; fuel must clamp at zero.
	service:SetFuel("moped-a", 0.01)
	local consumed, remaining = service:Consume("moped-a", 1000, 1)
	assertNear(consumed, 0.01, 1e-6, "cannot consume more than available")
	assertEqual(remaining, 0, "fuel clamps at zero")
	local consumed2, remaining2 = service:Consume("moped-a", 10, 1)
	assertEqual(consumed2, 0, "empty tank consumes nothing")
	assertEqual(remaining2, 0, "empty tank stays empty")
end

-- 3. Refuel only at gas stations, fills at most to capacity, charges server-side.
do
	local service = makeService()
	service:RegisterVehicle("moped-1", "player-1", { modelId = "puch-maxi-s", tankVolume = 2.0, fuel = 0.5 })
	-- Not at station -> rejected, balance untouched.
	local okFar, errFar = service:Refuel("player-1", "moped-1", 1.0)
	assertTrue(not okFar, "refuel away from station must be rejected")
	assertEqual(errFar, "NotAtGasStation", "station error")
	service:SetAtGasStation("moped-1", true)
	local ok, result = service:Refuel("player-1", "moped-1", 1.0)
	assertTrue(ok, "refuel at station should succeed")
	assertNear(result.filled, 1.0, 1e-6, "filled amount")
	assertNear(result.cost, 2.0, 1e-6, "cost = liters * price")
	assertNear(result.fuel, 1.5, 1e-6, "fuel level after refuel")
	-- Over-request is clamped to free capacity and only that is charged.
	local ok2, result2 = service:Refuel("player-1", "moped-1", 99)
	assertTrue(ok2, "over-request should clamp, not fail")
	assertNear(result2.filled, 0.5, 1e-6, "clamped to free space")
	assertNear(result2.cost, 1.0, 1e-6, "only clamped amount is charged")
	assertNear(service:GetFuel("moped-1"), 2.0, 1e-6, "tank is full")
	local okFull, errFull = service:Refuel("player-1", "moped-1", 0.5)
	assertTrue(not okFull, "full tank must be rejected")
	assertEqual(errFull, "TankFull", "tank full error")
end

-- 4. Refuel validates owner, amount, funds; foreign and invalid requests fail.
do
	local service = makeService()
	service:RegisterVehicle("moped-2", "player-1", { modelId = "piaggio-ciao", tankVolume = 2.0, fuel = 0.0 })
	service:SetAtGasStation("moped-2", true)
	local okForeign, errForeign = service:Refuel("player-2", "moped-2", 1.0)
	assertTrue(not okForeign, "foreign refuel must be rejected")
	assertEqual(errForeign, "NotOwner", "foreign refuel error")
	local okBad, errBad = service:Refuel("player-1", "moped-2", -1)
	assertTrue(not okBad, "negative amount must be rejected")
	assertEqual(errBad, "InvalidAmount", "amount error")
	local okZero, _ = service:Refuel("player-1", "moped-2", 0)
	assertTrue(not okZero, "zero amount must be rejected")
	-- Insufficient funds: fuel must not change.
	local poor = FuelService.new({
		pricePerLiter = 2.0,
		balances = { ["player-1"] = 0.5 },
	})
	poor:RegisterVehicle("moped-p", "player-1", { modelId = "puch-maxi-s", tankVolume = 2.0, fuel = 0.0 })
	poor:SetAtGasStation("moped-p", true)
	local okPoor, errPoor = poor:Refuel("player-1", "moped-p", 1.0)
	assertTrue(not okPoor, "poor player must be rejected")
	assertEqual(errPoor, "InsufficientFunds", "funds error")
	assertNear(poor:GetFuel("moped-p"), 0.0, 1e-9, "no fuel without payment")
end

-- 5. Transaction ids are idempotent: replay neither charges nor fills twice.
do
	local charges = 0
	local service = FuelService.new({
		pricePerLiter = 2.0,
		defaultTankVolume = 2.0,
		debit = function(_player: any, amount: number, _tx: any)
			charges += 1
			assertTrue(amount > 0, "charge must be positive")
			return true
		end,
	})
	service:RegisterVehicle("moped-tx", "player-1", { modelId = "puch-maxi-s", tankVolume = 2.0, fuel = 0.0 })
	service:SetAtGasStation("moped-tx", true)
	local ok1, res1 = service:Refuel("player-1", "moped-tx", 1.0, { transactionId = "tx-123" })
	assertTrue(ok1, "first tx should succeed")
	local ok2, res2 = service:Refuel("player-1", "moped-tx", 1.0, { transactionId = "tx-123" })
	assertTrue(ok2, "replayed tx should return success")
	assertEqual(charges, 1, "debit called exactly once")
	assertNear(res2.filled, res1.filled, 1e-9, "replay returns cached result")
	assertNear(service:GetFuel("moped-tx"), 1.0, 1e-9, "no double fill on replay")
end

-- 6. Rescue refill is the fair anti-stranding solution: only when stranded, free, with cooldown.
do
	local now = 5000
	local service = makeService({
		clock = function()
			return now
		end,
	})
	service:RegisterVehicle("moped-s", "player-1", { modelId = "puch-maxi-s", tankVolume = 3.0, fuel = 0.0 })
	-- Works without any gas station flag (stranded anywhere).
	local ok, result = service:RescueRefill("player-1", "moped-s")
	assertTrue(ok, "stranded rescue should succeed")
	assertNear(result.filled, 0.3, 1e-6, "rescue amount")
	assertEqual(result.cost, 0, "rescue is free")
	-- Second rescue immediately: not stranded anymore.
	local ok2, err2 = service:RescueRefill("player-1", "moped-s")
	assertTrue(not ok2, "non-empty tank has no rescue")
	assertEqual(err2, "NotStranded", "not-stranded error")
	-- Drain again, still in cooldown.
	service:SetFuel("moped-s", 0)
	local ok3, err3 = service:RescueRefill("player-1", "moped-s")
	assertTrue(not ok3, "rescue during cooldown must be rejected")
	assertEqual(err3, "RescueCooldown", "cooldown error")
	-- After cooldown it works again.
	now += 301
	local ok4, _ = service:RescueRefill("player-1", "moped-s")
	assertTrue(ok4, "rescue after cooldown should succeed")
	-- Foreign rescue rejected.
	service:SetFuel("moped-s", 0)
	now += 1000
	local ok5, err5 = service:RescueRefill("player-2", "moped-s")
	assertTrue(not ok5, "foreign rescue must be rejected")
	assertEqual(err5, "NotOwner", "foreign rescue error")
end

print("FuelService.spec: all assertions passed")
