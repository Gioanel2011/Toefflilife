--!strict
-- MopedLayout.spec: prueft die reinen Mofa-Bauteilbeschreibungen fuer
-- Puch Maxi S und Piaggio Ciao ohne Roblox-Laufzeit.
-- Laeuft mit `lune run tests/MopedLayout.spec.luau`.

local MopedLayout = require("../src/server/vehicle/MopedLayout")

local passed = 0
local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	passed += 1
	print("PASS: " .. label)
end

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function findPart(spec: any, name: string): any?
	for _, entry in ipairs(spec.parts) do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

local MOPED_IDS = { "puch_maxi_s", "piaggio_ciao" }

-- 1. Nur echte Mofas besitzen ein Layout.
check(MopedLayout.isMoped("puch_maxi_s"), "puchMustBeMoped")
check(MopedLayout.isMoped("piaggio_ciao"), "ciaoMustBeMoped")
check(not MopedLayout.isMoped("bicycle"), "bicycleMustNotBeMoped")
check(not MopedLayout.isMoped("unknown"), "unknownMustNotBeMoped")
check(MopedLayout.get("bicycle") == nil, "bicycleLayoutMustBeNil")
check(MopedLayout.get("unknown") == nil, "unknownLayoutMustBeNil")

-- 2. Beide Mofas besitzen alle Pflichtbauteile und ein gueltiges Pivot.
for _, vehicleId in MOPED_IDS do
	local spec = MopedLayout.get(vehicleId)
	check(spec ~= nil, vehicleId .. "LayoutPresent")
	if spec == nil then
		continue
	end
	local moped = spec :: any
	check(moped.vehicleId == vehicleId, vehicleId .. "IdMatches")
	check(type(moped.displayName) == "string" and moped.displayName ~= "", vehicleId .. "DisplayNamePresent")
	check(moped.primaryPart == "Drive", vehicleId .. "DriveIsPivot")
	check(moped.seatName == "Seat", vehicleId .. "SeatNamedSeat")
	check(#moped.parts >= 8, vehicleId .. "EnoughParts")
	check(findPart(moped, "Drive") ~= nil, vehicleId .. "HasDrive")
	check(findPart(moped, "WheelFront") ~= nil, vehicleId .. "HasFrontWheel")
	check(findPart(moped, "WheelRear") ~= nil, vehicleId .. "HasRearWheel")
	check(findPart(moped, "Handlebar") ~= nil, vehicleId .. "HasHandlebar")

	local seat = findPart(moped, "Seat")
	local front = findPart(moped, "WheelFront")
	local rear = findPart(moped, "WheelRear")
	check(seat ~= nil and seat.canCollide == false, vehicleId .. "SeatMustNotCollide")
	if seat ~= nil then
		check(seat.offset.y > 0, vehicleId .. "SeatAbovePivot")
	end
	local handlebar = findPart(moped, "Handlebar")
	if front ~= nil and rear ~= nil then
		-- Roblox' CFrame.LookVector zeigt nach -Z; die sichtbare Front muss
		-- deshalb auf lokal -Z liegen.
		check(front.offset.z < 0, vehicleId .. "FrontWheelFacesMinusZ")
		check(rear.offset.z > 0, vehicleId .. "RearWheelFacesPlusZ")
		check(front.offset.z < rear.offset.z, vehicleId .. "FrontWheelAheadOfRear")
	end
	if handlebar ~= nil then
		check(handlebar.offset.z < 0, vehicleId .. "HandlebarFacesMinusZ")
	end

	-- 3. Namen eindeutig, Masse positiv und endlich.
	local seen: { [string]: boolean } = {}
	for _, entry in ipairs(moped.parts) do
		check(not seen[entry.name], vehicleId .. "UniquePart_" .. entry.name)
		seen[entry.name] = true
		check(
			entry.size.x > 0 and entry.size.y > 0 and entry.size.z > 0,
			vehicleId .. "PositiveSize_" .. entry.name
		)
		check(
			finite(entry.offset.x) and finite(entry.offset.y) and finite(entry.offset.z),
			vehicleId .. "FiniteOffset_" .. entry.name
		)
		check(
			entry.shape == "Block" or entry.shape == "Cylinder",
			vehicleId .. "ValidShape_" .. entry.name
		)
	end
end

-- 4. Deterministische, getrennte Parkplaetze.
local puchSlot = MopedLayout.parkingOffsetFor("puch_maxi_s")
local ciaoSlot = MopedLayout.parkingOffsetFor("piaggio_ciao")
check(puchSlot ~= nil and ciaoSlot ~= nil, "BothParkingSlotsPresent")
check(MopedLayout.parkingOffsetFor("bicycle") == nil, "BicycleHasNoParkingSlot")
if puchSlot ~= nil and ciaoSlot ~= nil then
	check(puchSlot.x ~= ciaoSlot.x, "ParkingSlotsMustDiffer")
	check(math.abs(puchSlot.x - ciaoSlot.x) >= 3, "ParkingSlotsNeedSpace")
	local repeated = MopedLayout.parkingOffsetFor("puch_maxi_s")
	check(repeated ~= nil and repeated.x == puchSlot.x and repeated.z == puchSlot.z, "ParkingSlotDeterministic")
end
check(MopedLayout.SPAWN_SPACING >= 3, "SpawnSpacingLargeEnough")
check(MopedLayout.PIVOT_HEIGHT > 0, "PivotHeightPositive")

-- 5. Rueckgaben sind Kopien; Mutation darf die Quelle nicht veraendern.
local first = MopedLayout.get("puch_maxi_s")
local second = MopedLayout.get("puch_maxi_s")
check(first ~= nil and second ~= nil, "CopiesPresent")
if first ~= nil and second ~= nil then
	first.parts[1].size.x = 999
	first.parts[1].offset.y = 999
	check(second.parts[1].size.x ~= 999, "SizeCopyIsolated")
	check(second.parts[1].offset.y ~= 999, "OffsetCopyIsolated")
end

-- 6. Eigene Validierung des Moduls.
check(MopedLayout.validate(), "ModuleValidationPasses")

print(string.format("MopedLayout.spec: %d checks passed", passed))
