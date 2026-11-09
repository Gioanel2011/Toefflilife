--!strict
-- MissionService.spec: Lune-Test für Start- und Distanzmissionen.

local MissionService = require("../src/server/services/MissionService")

local function fresh(): any
	return MissionService.new()
end

local function bikeCtx(): any
	return {
		vehicleId = "bicycle",
		isOwnVehicle = true,
		speedKmh = 15,
		teleported = false,
	}
end

local function mopedCtx(): any
	return {
		vehicleId = "puch_maxi_s",
		isOwnVehicle = true,
		speedKmh = 35,
		teleported = false,
	}
end

-- 1. Fahrrad-Startmission: 500m mit eigenem Fahrrad schließen.
do
	local service = fresh()
	for _ = 1, 5 do
		local ok, reason = service:addDistance("player1", 100, bikeCtx())
		assert(ok, "bike distance should be accepted: " .. tostring(reason))
	end
	assert(service:isCompleted("player1", "bike_starter_500m"), "bike starter should be completed")
	assert(not service:isCompleted("player1", "moped_starter_2km"), "moped starter must not complete from bike distance")

	local paid = 0
	local ok, info: any = service:claimReward("player1", "bike_starter_500m", function(amount: number)
		paid += amount
	end)
	assert(ok, "first claim should succeed")
	assert(info.reward == 50, "bike starter info reward should be 50")
	assert(paid == 50, "bike starter reward should be 50, got " .. tostring(paid))

	local ok2, info2: any = service:claimReward("player1", "bike_starter_500m", function(amount: number)
		paid += amount
	end)
	assert(not ok2, "second claim must fail")
	assert(info2.reason == "already_claimed", "expected already_claimed")
	assert(paid == 50, "reward must be paid exactly once")
end

-- 2. Mofa-Startmission: Fahrrad zählt nicht, Mofa schon.
do
	local service = fresh()
	local ok, _ = service:addDistance("player2", 100, bikeCtx())
	assert(ok, "bike distance accepted")
	assert(not service:isCompleted("player2", "moped_starter_2km"), "moped mission must ignore bicycle")

	for _ = 1, 20 do
		local accepted, reason = service:addDistance("player2", 100, mopedCtx())
		assert(accepted, "moped distance should be accepted: " .. tostring(reason))
	end
	assert(service:isCompleted("player2", "moped_starter_2km"), "moped starter should complete after 2000m")

	local okClaim, _ = service:claimReward("player2", "moped_starter_2km")
	assert(okClaim, "moped claim without wallet hook should succeed")
	local okAgain, infoAgain: any = service:claimReward("player2", "moped_starter_2km")
	assert(not okAgain and infoAgain.reason == "already_claimed", "moped double claim must be rejected")
end

-- 3. Teleport- und Exploit-Schutz.
do
	local service = fresh()
	local okTeleport, reasonTeleport = service:addDistance("player3", 100, {
		vehicleId = "bicycle",
		isOwnVehicle = true,
		speedKmh = 15,
		teleported = true,
	})
	assert(not okTeleport and reasonTeleport == "teleport_rejected", "teleported flag must be rejected")

	local okFar, reasonFar = service:addDistance("player3", 5000, bikeCtx())
	assert(not okFar and reasonFar == "teleport_rejected", "huge single delta must be rejected as teleport")

	local okForeign, reasonForeign = service:addDistance("player3", 50, {
		vehicleId = "bicycle",
		isOwnVehicle = false,
		speedKmh = 15,
		teleported = false,
	})
	assert(not okForeign and reasonForeign == "foreign_vehicle", "foreign vehicle must be rejected")

	local okSpeed, reasonSpeed = service:addDistance("player3", 50, {
		vehicleId = "bicycle",
		isOwnVehicle = true,
		speedKmh = 500,
		teleported = false,
	})
	assert(not okSpeed and reasonSpeed == "implausible_speed", "implausible speed must be rejected")

	local okZero, _ = service:addDistance("player3", 50, {
		vehicleId = "bicycle",
		isOwnVehicle = true,
		speedKmh = 0,
		teleported = false,
	})
	assert(not okZero, "zero speed with distance must be rejected")

	local state = service:getState("player3")
	assert(state.totalDistance == 0, "rejected distances must not accumulate")
	assert(not service:isCompleted("player3", "bike_starter_500m"), "nothing should complete after rejects")
end

-- 4. Distanzmissionen und unbekannte/frühe Claims.
do
	local service = fresh()
	local okEarly, infoEarly: any = service:claimReward("player4", "distance_10km")
	assert(not okEarly and infoEarly.reason == "not_completed", "early claim must report not_completed")

	local okUnknown, infoUnknown: any = service:claimReward("player4", "nope")
	assert(not okUnknown and infoUnknown.reason == "unknown_mission", "unknown key must be rejected")

	for _ = 1, 100 do
		local accepted, reason = service:addDistance("player4", 100, mopedCtx())
		assert(accepted, "distance accumulation failed: " .. tostring(reason))
	end
	assert(service:isCompleted("player4", "distance_10km"), "10km mission should complete")
	assert(not service:isCompleted("player4", "distance_50km"), "50km mission must not complete yet")

	local ok, info: any = service:claimReward("player4", "distance_10km")
	assert(ok and info.reward == 300, "10km reward should be 300")
end

-- 5. Spielertrennung: Fortschritt pro UserId isoliert.
do
	local service = fresh()
	for _ = 1, 5 do
		service:addDistance("alice", 100, bikeCtx())
	end
	assert(service:isCompleted("alice", "bike_starter_500m"), "alice should complete")
	assert(not service:isCompleted("bob", "bike_starter_500m"), "bob must stay incomplete")
end

print("MissionService.spec: all assertions passed")
