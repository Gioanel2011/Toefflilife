--!strict
-- Nachweis für Task 09: Annahme, Abholung, Auslieferung, Distanz- und
-- Zustandsprüfung, Fahrrad nur für kurze Startlieferungen, Einmal-Auszahlung.

local DeliveryService = require("../src/server/services/DeliveryService")

local SHOP = { x = 0, y = 0, z = 0 }
local NEAR = { id = "haus-nah", position = { x = 50, y = 0, z = 0 } }
local FAR = { id = "haus-fern", position = { x = 800, y = 0, z = 0 } }

local function makeService(pickIndex: number, ledger: { [string]: number }?)
	local charges = ledger or {}
	local economy = {
		addBalance = function(playerId: string, amount: number, transactionId: string): boolean
			if charges[transactionId] ~= nil then
				return false
			end
			charges[transactionId] = amount
			assert(playerId ~= nil, "playerRequired")
			return true
		end,
	}
	local service = DeliveryService.new({
		shopPosition = SHOP,
		addresses = { NEAR, FAR },
		starterMaxDistance = 150,
		pickupRadius = 12,
		deliverRadius = 12,
		starterPayout = 25,
		standardPayout = 60,
		economy = economy,
		randomIndex = function(_n: number): number
			return pickIndex
		end,
	})
	return service, charges
end

local function check(condition: boolean, message: string)
	assert(condition, message)
end

-- 1. Kurze Startlieferung mit dem Fahrrad: Annahme, Abholung, Auslieferung.
do
	local service, charges = makeService(1)
	local job, err = service:acceptJob("anna", "bicycle")
	check(job ~= nil and err == nil, "starterAcceptFailed")
	check((job :: any).starter == true, "starterFlagExpected")
	check((job :: any).payout == 25, "starterPayoutExpected")

	local okFar, errFar = service:pickup("anna", (job :: any).jobId, { x = 500, y = 0, z = 0 })
	check(okFar == false and errFar == "tooFarFromShop", "pickupDistanceNotChecked")

	local ok, pickErr = service:pickup("anna", (job :: any).jobId, { x = 5, y = 0, z = 0 })
	check(ok == true and pickErr == nil, "pickupFailed")

	local payoutFar, deliverErrFar =
		service:deliver("anna", (job :: any).jobId, { x = 500, y = 0, z = 0 })
	check(payoutFar == nil and deliverErrFar == "tooFarFromAddress", "deliverDistanceNotChecked")

	local payout, deliverErr = service:deliver("anna", (job :: any).jobId, { x = 50, y = 0, z = 0 })
	check(payout == 25 and deliverErr == nil, "deliverFailed")
	check(charges["delivery:" .. (job :: any).jobId] == 25, "payoutNotRecorded")

	local again, againErr = service:deliver("anna", (job :: any).jobId, { x = 50, y = 0, z = 0 })
	check(again == nil and againErr == "alreadyDelivered", "doublePayoutNotBlocked")
end

-- 2. Weite Lieferung: Fahrrad abgelehnt, Mofa erlaubt, Zustandsreihenfolge erzwungen.
do
	local service, _ = makeService(2)
	local denied, deniedErr = service:acceptJob("ben", "bicycle")
	check(denied == nil and deniedErr == "bicycleOnlyForStarter", "bicycleFarNotRejected")

	local job, err = service:acceptJob("ben", "moped")
	check(job ~= nil and err == nil, "mopedAcceptFailed")
	check((job :: any).starter == false, "standardFlagExpected")

	local early, earlyErr = service:deliver("ben", (job :: any).jobId, { x = 800, y = 0, z = 0 })
	check(early == nil and earlyErr == "invalidState", "stateOrderNotChecked")

	local foreign, foreignErr = service:pickup("clara", (job :: any).jobId, { x = 0, y = 0, z = 0 })
	check(foreign == false and foreignErr == "notYourJob", "foreignJobNotRejected")

	local second, secondErr = service:acceptJob("ben", "moped")
	check(second == nil and secondErr == "jobAlreadyActive", "parallelJobNotBlocked")

	local ok, _ = service:pickup("ben", (job :: any).jobId, { x = 0, y = 0, z = 0 })
	check(ok == true, "mopedPickupFailed")
	local payout, deliverErr = service:deliver("ben", (job :: any).jobId, { x = 800, y = 0, z = 0 })
	check(payout == 60 and deliverErr == nil, "mopedDeliverFailed")
end

print("DeliveryService.spec: all assertions passed")
