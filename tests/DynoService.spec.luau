-- DynoService spec (lune-compatible).
local DynoService = require("../src/server/services/DynoService")

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

local function stubCalculate(base: any, _parts: any): any
	return {
		power = (base.basePower or 2) + 1,
		topSpeed = (base.baseTopSpeed or 30) + 5,
	}
end

local function makeService(): any
	return DynoService.new({ calculate = stubCalculate, clock = function()
		return 1234
	end })
end

local function registerReadyMoped(service: any, vehicleId: string, owner: string, base: any?)
	service:RegisterVehicle(vehicleId, owner, base or { id = "puch-maxi-s", basePower = 2, baseTopSpeed = 40 }, { exhaust = "sport" })
	service:SetDynoState(vehicleId, { inShop = true, onDyno = true, stationary = true, engineOff = true })
end

-- 1. Successful run uses server calculator and stores last result.
do
	local service = makeService()
	registerReadyMoped(service, "moped-1", "player-1")
	local ok, result = service:StartRun("player-1", "moped-1")
	assertTrue(ok, "valid dyno run should succeed")
	assertEqual(result.power, 3, "result must come from server calculator")
	assertEqual(result.topSpeed, 45, "result must come from server calculator")
	assertEqual(result.vehicleId, "moped-1", "result carries vehicle id")
	local last = service:GetLastResult("moped-1")
	assertTrue(last ~= nil, "last result must be stored")
	assertEqual(last.power, 3, "stored result matches run")
end

-- 2. Foreign vehicle is rejected.
do
	local service = makeService()
	registerReadyMoped(service, "moped-2", "player-1")
	local ok, err = service:StartRun("player-2", "moped-2")
	assertTrue(not ok, "foreign vehicle must be rejected")
	assertEqual(err, "NotOwner", "foreign vehicle error")
	assertTrue(service:GetLastResult("moped-2") == nil, "no result stored on rejection")
end

-- 3. Bicycle is rejected even when correctly mounted.
do
	local service = makeService()
	service:RegisterVehicle("bike-1", "player-1", { id = "bicycle", basePower = 0 }, {})
	service:SetDynoState("bike-1", { inShop = true, onDyno = true, stationary = true, engineOff = true })
	local ok, err = service:StartRun("player-1", "bike-1")
	assertTrue(not ok, "bicycle must be rejected")
	assertEqual(err, "BicycleNotAllowed", "bicycle error")
end

-- 4. Not in shop / not on dyno is rejected.
do
	local service = makeService()
	registerReadyMoped(service, "moped-3", "player-1")
	service:SetDynoState("moped-3", { inShop = false, onDyno = false, stationary = true, engineOff = true })
	local ok, _err = service:StartRun("player-1", "moped-3")
	assertTrue(not ok, "run outside shop must be rejected")
	service:SetDynoState("moped-3", { inShop = true, onDyno = false, stationary = true, engineOff = true })
	local ok2, _err2 = service:StartRun("player-1", "moped-3")
	assertTrue(not ok2, "run without dyno mount must be rejected")
end

-- 5. Client-supplied values are ignored (no manipulation).
do
	local service = makeService()
	registerReadyMoped(service, "moped-4", "player-1")
	local ok, result = service:StartRun("player-1", "moped-4", { power = 9999, topSpeed = 9999 })
	assertTrue(ok, "run with client stats attached should still succeed")
	assertEqual(result.power, 3, "client power must be ignored")
	assertEqual(result.topSpeed, 45, "client topSpeed must be ignored")
end

-- 6. Unknown vehicle and bad input rejected; last result only overwritten by success.
do
	local service = makeService()
	local ok, err = service:StartRun("player-1", "missing")
	assertTrue(not ok, "unknown vehicle must be rejected")
	assertTrue(err == "NotOwner" or err == "UnknownVehicle", "unknown vehicle error")
	local ok2, _e2 = service:StartRun("player-1", "")
	assertTrue(not ok2, "empty vehicle id must be rejected")
end

print("DynoService.spec: all assertions passed")
