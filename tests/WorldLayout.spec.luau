--!strict
-- Nachweis fuer Task 07: deterministische Layoutdaten fuer zwei Doerfer,
-- genau eine Kirche, einen zentralen Doenerplatz und 15 gleichwertige Garagen.

local WorldLayout = require("../src/server/world/WorldLayout")

local function check(condition: boolean, message: string)
	assert(condition, message)
end

local function distanceXZ(a: { x: number, z: number }, b: { x: number, z: number }): number
	local deltaX = a.x - b.x
	local deltaZ = a.z - b.z
	return math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
end

-- 1. Fester Seed und begrenztes Tal.
check(WorldLayout.SEED == 20260101, "seedMustBeFixed")
check(WorldLayout.BOUNDS.minX < WorldLayout.BOUNDS.maxX, "boundsXInvalid")
check(WorldLayout.BOUNDS.minZ < WorldLayout.BOUNDS.maxZ, "boundsZInvalid")

-- 2. Zwei Doerfer mit je 10 eindeutigen Haus-Slots (20 gesamt).
check(#WorldLayout.VILLAGES == 2, "twoVillagesExpected")
local slotIds: { [string]: boolean } = {}
local slotCount = 0
for _, village in WorldLayout.VILLAGES do
	check(#village.slots == 10, "tenSlotsPerVillageExpected")
	for _, slot in village.slots do
		slotCount += 1
		check(slotIds[slot.id] == nil, "slotIdsMustBeUnique")
		slotIds[slot.id] = true
		check(slot.villageId == village.id, "slotVillageMismatch")
		check(WorldLayout.isInsideBounds(slot.position), "slotOutsideBounds")
		check(distanceXZ(slot.position, village.center) > 60, "slotTooCloseToVillageCenter")
	end
end
check(slotCount == 20, "twentySlotsExpected")

-- 3. Genau eine Kirche, im Zentrum des ersten Dorfes.
check(WorldLayout.CHURCH.villageId == WorldLayout.VILLAGES[1].id, "churchVillageMismatch")
check(distanceXZ(WorldLayout.CHURCH.position, WorldLayout.VILLAGES[1].center) < 1, "churchMustSitAtVillageCenter")
local churchCount = 0
local donerCount = 0
local villageCount = 0
for _, poi in WorldLayout.getPointsOfInterest() do
	if poi.kind == "church" then
		churchCount += 1
	elseif poi.kind == "doner" then
		donerCount += 1
	elseif poi.kind == "village" then
		villageCount += 1
	end
end
check(churchCount == 1, "exactlyOneChurchExpected")
check(donerCount == 1, "exactlyOneDonerExpected")
check(villageCount == 2, "twoVillagePoisExpected")

-- 4. 15 Garagen mit gleichem Abstand zum Doenerplatz und Mindestabstand zueinander.
local garages = WorldLayout.getGarageAnchors()
check(#garages == 15, "fifteenGaragesExpected")
local referenceDistance = distanceXZ(garages[1].position, WorldLayout.DONER.position)
check(referenceDistance > WorldLayout.DONER.radius, "garagesMustBeOutsideDonerPlaza")
for _, garage in garages do
	check(WorldLayout.isInsideBounds(garage.position), "garageOutsideBounds")
	check(
		math.abs(distanceXZ(garage.position, WorldLayout.DONER.position) - referenceDistance) < 0.001,
		"garagesMustShareDonerDistance"
	)
end
for firstIndex = 1, #garages - 1 do
	for secondIndex = firstIndex + 1, #garages do
		check(
			distanceXZ(garages[firstIndex].position, garages[secondIndex].position) >= 60,
			"garagesTooClose"
		)
	end
end

-- 5. Garagen ueberschneiden weder Wohn-Slots noch Kirche.
for _, garage in garages do
	check(distanceXZ(garage.position, WorldLayout.CHURCH.position) >= 80, "garageOverlapsChurch")
	for _, village in WorldLayout.VILLAGES do
		for _, slot in village.slots do
			check(distanceXZ(garage.position, slot.position) >= 80, "garageOverlapsHouseSlot")
		end
	end
end

-- 6. Lieferpunkte: 20 Adressen plus genau eine Abholung, alle im Tal.
local deliveries = WorldLayout.getDeliveryPoints()
check(#deliveries == 21, "twentyAddressesAndOnePickupExpected")
local pickupCount = 0
local deliveryIds: { [string]: boolean } = {}
for _, point in deliveries do
	check(deliveryIds[point.id] == nil, "deliveryIdsMustBeUnique")
	deliveryIds[point.id] = true
	check(WorldLayout.isInsideBounds(point.position), "deliveryOutsideBounds")
	if point.kind == "pickup" then
		pickupCount += 1
	end
end
check(pickupCount == 1, "onePickupExpected")

-- 7. Grenzpruefung inklusive Rand und Ablehnung ausserhalb.
check(WorldLayout.isInsideBounds({ x = 0, y = 0, z = 0 }), "centerInsideBoundsExpected")
check(
	WorldLayout.isInsideBounds({ x = WorldLayout.BOUNDS.maxX, y = 0, z = WorldLayout.BOUNDS.maxZ }),
	"edgeInsideBoundsExpected"
)
check(not WorldLayout.isInsideBounds({ x = WorldLayout.BOUNDS.maxX + 1, y = 0, z = 0 }), "outsideXNotDetected")
check(not WorldLayout.isInsideBounds({ x = 0, y = 0, z = WorldLayout.BOUNDS.minZ - 1 }), "outsideZNotDetected")
check(not WorldLayout.isInsideBounds({ x = 0, y = WorldLayout.BOUNDS.maxY + 1, z = 0 }), "outsideYNotDetected")

-- 8. Rueckgaben sind Kopien; die Konstanten bleiben unveraendert.
local garageCopy = WorldLayout.getGarageAnchors()
garageCopy[1].position.x = 99999
garageCopy[1].name = "Manipuliert"
check(WorldLayout.GARAGES[1].position.x ~= 99999, "garageConstantsMustBeImmutable")
check(WorldLayout.getGarageAnchors()[1].name ~= "Manipuliert", "garageNameMustComeFromConstant")

local villageCopy = WorldLayout.getVillages()
villageCopy[1].center.x = -99999
villageCopy[1].slots[1].position.x = -99999
check(WorldLayout.VILLAGES[1].center.x ~= -99999, "villageCenterCopyExpected")
check(WorldLayout.VILLAGES[1].slots[1].position.x ~= -99999, "villageSlotCopyExpected")

local deliveryCopy = WorldLayout.getDeliveryPoints()
deliveryCopy[1].position.z = 99999
check(WorldLayout.getDeliveryPoints()[1].position.z ~= 99999, "deliveryCopyExpected")

local poiCopy = WorldLayout.getPointsOfInterest()
poiCopy[1].position.x = 99999
check(WorldLayout.getPointsOfInterest()[1].position.x ~= 99999, "poiCopyExpected")

-- 9. Determinismus: wiederholte Aufrufe liefern identische Daten.
local firstSnapshot = WorldLayout.getDeliveryPoints()
local secondSnapshot = WorldLayout.getDeliveryPoints()
check(#firstSnapshot == #secondSnapshot, "deliveryCountNotRepeatable")
for index = 1, #firstSnapshot do
	check(firstSnapshot[index].id == secondSnapshot[index].id, "deliveryIdsNotRepeatable")
	check(
		math.abs(firstSnapshot[index].position.x - secondSnapshot[index].position.x) < 1e-9,
		"deliveryPositionsNotRepeatable"
	)
end

print("WorldLayout.spec: all assertions passed")
