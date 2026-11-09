--!strict
-- WorldLayout: reine, deterministische Layoutdaten fuer das Toeffli-Tal.
-- Keine Roblox-Instanzen, keine Preise, keine Gameplaylogik.
-- Positionen sind schlichte Tabellen ({ x, y, z }), damit die Daten auch ohne
-- Roblox-Laufzeit (Lune-Tests) geprueft werden koennen. `yaw` ist eine
-- Roblox-Yaw-Rotation in Grad um die Y-Achse.

export type Position = { x: number, y: number, z: number }

export type Footprint = { x: number, z: number }

export type HouseSlot = {
	id: string,
	name: string,
	villageId: string,
	position: Position,
	yaw: number,
	footprint: Footprint,
}

export type Village = {
	id: string,
	name: string,
	center: Position,
	radius: number,
	slots: { HouseSlot },
}

export type DonerPlace = {
	id: string,
	name: string,
	kind: string,
	position: Position,
	radius: number,
	pickupPosition: Position,
}

export type Church = {
	id: string,
	name: string,
	kind: string,
	villageId: string,
	position: Position,
	yaw: number,
	footprint: Footprint,
}

export type GarageAnchor = {
	id: string,
	name: string,
	position: Position,
	yaw: number,
	angleDegrees: number,
}

export type DeliveryPoint = {
	id: string,
	name: string,
	kind: string,
	villageId: string?,
	position: Position,
}

export type PointOfInterest = {
	id: string,
	name: string,
	kind: string,
	position: Position,
	radius: number,
}

local WorldLayout = {}

-- Fester Seed: identische Daten in Server, Studio und Tests.
WorldLayout.SEED = 20260101

-- Grenzen des Tals (einschliesslich), keine offene unendliche Flaeche.
WorldLayout.BOUNDS = {
	minX = -600,
	maxX = 600,
	minZ = -600,
	maxZ = 600,
	minY = 0,
	maxY = 240,
}

-- Zentraler Doenerplatz im Taltzentrum.
WorldLayout.DONER = {
	id = "DonerPlace",
	name = "Dönerplatz",
	kind = "doner",
	position = { x = 0, y = 0, z = 0 },
	radius = 36,
	pickupPosition = { x = 0, y = 0, z = 18 },
}

-- Zwei Doerfer; jedes erhaelt exakt 10 Haus-Slots.
local VILLAGE_PLAN: { { id: string, name: string, center: Position } } = {
	{ id = "Village_Alpenblick", name = "Alpenblick", center = { x = -320, y = 0, z = -280 } },
	{ id = "Village_Seeblick", name = "Seeblick", center = { x = 340, y = 0, z = 300 } },
}

local SLOTS_PER_VILLAGE = 10
local SLOT_RADIUS = 100
local SLOT_RADIUS_JITTER = 8
local SLOT_ANGLE_JITTER = 4
local SLOT_FOOTPRINT: Footprint = { x = 20, z = 16 }
local DELIVERY_OFFSET = 14

local GARAGE_COUNT = 15
local GARAGE_RING_RADIUS = 200

-- Deterministischer Pseudozufall (Lehmer-LCG). Der Zustand bleibt lokal,
-- damit ein erneutes Laden immer dieselben Layoutdaten erzeugt.
local function createRandom(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function jitter(random: () -> number, amount: number): number
	return (random() * 2 - 1) * amount
end

local function copyPosition(position: Position): Position
	return { x = position.x, y = position.y, z = position.z }
end

-- Yaw, mit dem die Vorderseite (Roblox-Forward = -Z) auf `to` zeigt.
local function yawTowards(from: Position, to: Position): number
	local deltaX = to.x - from.x
	local deltaZ = to.z - from.z
	return math.deg(math.atan2(-deltaX, -deltaZ))
end

local random = createRandom(WorldLayout.SEED)

local villages: { Village } = {}
local deliveryPoints: { DeliveryPoint } = {}

for _, plan in VILLAGE_PLAN do
	local slots: { HouseSlot } = {}
	local startAngle = random() * 360

	for slotIndex = 0, SLOTS_PER_VILLAGE - 1 do
		local angleDegrees = startAngle
			+ slotIndex * (360 / SLOTS_PER_VILLAGE)
			+ jitter(random, SLOT_ANGLE_JITTER)
		local radius = SLOT_RADIUS + jitter(random, SLOT_RADIUS_JITTER)
		local angleRadians = math.rad(angleDegrees)

		local position: Position = {
			x = plan.center.x + math.cos(angleRadians) * radius,
			y = plan.center.y,
			z = plan.center.z + math.sin(angleRadians) * radius,
		}

		local slot: HouseSlot = {
			id = string.format("%s_Slot_%02d", plan.id, slotIndex + 1),
			name = string.format("%s Haus %02d", plan.name, slotIndex + 1),
			villageId = plan.id,
			position = position,
			yaw = yawTowards(position, plan.center),
			footprint = { x = SLOT_FOOTPRINT.x, z = SLOT_FOOTPRINT.z },
		}
		table.insert(slots, slot)

		-- Lieferpunkt liegt zur Dorfmitte hin vor dem Haus (Eingangsseite).
		local deltaX = plan.center.x - position.x
		local deltaZ = plan.center.z - position.z
		local length = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
		table.insert(deliveryPoints, {
			id = string.format("Delivery_%s", slot.id),
			name = string.format("Lieferung %s", slot.name),
			kind = "address",
			villageId = plan.id,
			position = {
				x = position.x + (deltaX / length) * DELIVERY_OFFSET,
				y = position.y,
				z = position.z + (deltaZ / length) * DELIVERY_OFFSET,
			},
		})
	end

	table.insert(villages, {
		id = plan.id,
		name = plan.name,
		center = copyPosition(plan.center),
		radius = 150,
		slots = slots,
	})
end

WorldLayout.VILLAGES = villages

-- Genau eine Kirche: im Zentrum des ersten Dorfes.
WorldLayout.CHURCH = {
	id = "Church_Alpenblick",
	name = "Dorfkirche Alpenblick",
	kind = "church",
	villageId = VILLAGE_PLAN[1].id,
	position = copyPosition(VILLAGE_PLAN[1].center),
	yaw = yawTowards(VILLAGE_PLAN[1].center, WorldLayout.DONER.position),
	footprint = { x = 22, z = 30 },
}

-- 15 Garagen auf einem gemeinsamen Ring: gleicher Abstand zum Doenerplatz,
-- gleichmaessig verteilt und damit mit Mindestabstand zueinander.
local garages: { GarageAnchor } = {}
local garageStartAngle = random() * 360

for garageIndex = 1, GARAGE_COUNT do
	local angleDegrees = garageStartAngle + (garageIndex - 1) * (360 / GARAGE_COUNT)
	local angleRadians = math.rad(angleDegrees)

	local position: Position = {
		x = math.cos(angleRadians) * GARAGE_RING_RADIUS,
		y = 0,
		z = math.sin(angleRadians) * GARAGE_RING_RADIUS,
	}

	table.insert(garages, {
		id = string.format("Garage_%02d", garageIndex),
		name = string.format("Garage %02d", garageIndex),
		position = position,
		yaw = yawTowards(position, WorldLayout.DONER.position),
		angleDegrees = angleDegrees,
	})
end

WorldLayout.GARAGES = garages

table.insert(deliveryPoints, {
	id = "Delivery_DonerPickup",
	name = "Döner Laden Abholung",
	kind = "pickup",
	position = copyPosition(WorldLayout.DONER.pickupPosition),
})

local function copySlot(slot: HouseSlot): HouseSlot
	return {
		id = slot.id,
		name = slot.name,
		villageId = slot.villageId,
		position = copyPosition(slot.position),
		yaw = slot.yaw,
		footprint = { x = slot.footprint.x, z = slot.footprint.z },
	}
end

function WorldLayout.getVillages(): { Village }
	local copy: { Village } = {}
	for _, village in WorldLayout.VILLAGES do
		local slots: { HouseSlot } = {}
		for _, slot in village.slots do
			table.insert(slots, copySlot(slot))
		end
		table.insert(copy, {
			id = village.id,
			name = village.name,
			center = copyPosition(village.center),
			radius = village.radius,
			slots = slots,
		})
	end
	return copy
end

function WorldLayout.getDeliveryPoints(): { DeliveryPoint }
	local copy: { DeliveryPoint } = {}
	for _, point in deliveryPoints do
		table.insert(copy, {
			id = point.id,
			name = point.name,
			kind = point.kind,
			villageId = point.villageId,
			position = copyPosition(point.position),
		})
	end
	return copy
end

function WorldLayout.getGarageAnchors(): { GarageAnchor }
	local copy: { GarageAnchor } = {}
	for _, garage in WorldLayout.GARAGES do
		table.insert(copy, {
			id = garage.id,
			name = garage.name,
			position = copyPosition(garage.position),
			yaw = garage.yaw,
			angleDegrees = garage.angleDegrees,
		})
	end
	return copy
end

function WorldLayout.getPointsOfInterest(): { PointOfInterest }
	local points: { PointOfInterest } = {
		{
			id = WorldLayout.DONER.id,
			name = WorldLayout.DONER.name,
			kind = WorldLayout.DONER.kind,
			position = copyPosition(WorldLayout.DONER.position),
			radius = WorldLayout.DONER.radius,
		},
		{
			id = WorldLayout.CHURCH.id,
			name = WorldLayout.CHURCH.name,
			kind = WorldLayout.CHURCH.kind,
			position = copyPosition(WorldLayout.CHURCH.position),
			radius = 18,
		},
	}
	for _, village in WorldLayout.VILLAGES do
		table.insert(points, {
			id = village.id,
			name = village.name,
			kind = "village",
			position = copyPosition(village.center),
			radius = village.radius,
		})
	end
	return points
end

function WorldLayout.isInsideBounds(position: Position): boolean
	local bounds = WorldLayout.BOUNDS
	return position.x >= bounds.minX
		and position.x <= bounds.maxX
		and position.z >= bounds.minZ
		and position.z <= bounds.maxZ
		and position.y >= bounds.minY
		and position.y <= bounds.maxY
end

return WorldLayout
