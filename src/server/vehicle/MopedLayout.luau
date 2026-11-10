--!strict
-- MopedLayout: reine, deterministische Bauteilbeschreibung fuer Puch Maxi S
-- und Piaggio Ciao. Keine Roblox-Instanzen und keine Laufzeitabhaengigkeit,
-- damit die Layoutdaten mit `lune run` geprueft werden koennen.
-- Keine Preise, keine Fahrphysik und keine Gameplay-Logik.

export type Vec3 = { x: number, y: number, z: number }
export type Rgb = { r: number, g: number, b: number }

export type PartSpec = {
	name: string,
	size: Vec3,
	offset: Vec3,
	color: Rgb,
	shape: string,
	canCollide: boolean,
	transparency: number,
}

export type MopedSpec = {
	vehicleId: string,
	displayName: string,
	primaryPart: string,
	seatName: string,
	parts: { PartSpec },
}

local MopedLayout = {}

MopedLayout.TAG_NAME = "ToeffliMoped"
MopedLayout.PRIMARY_PART = "Drive"
MopedLayout.SEAT_NAME = "Seat"
MopedLayout.SPAWN_SPACING = 3.2
MopedLayout.PIVOT_HEIGHT = 0.7

MopedLayout.REQUIRED_PARTS = {
	"Drive",
	"Seat",
	"WheelFront",
	"WheelRear",
	"Handlebar",
}

local PARKING_SLOTS: { [string]: number } = {
	puch_maxi_s = 0,
	piaggio_ciao = 1,
}

local function vec(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function rgb(r: number, g: number, b: number): Rgb
	return { r = r, g = g, b = b }
end

local function part(
	name: string,
	size: Vec3,
	offset: Vec3,
	color: Rgb,
	shape: string,
	canCollide: boolean,
	transparency: number?
): PartSpec
	return {
		name = name,
		size = size,
		offset = offset,
		color = color,
		shape = shape,
		canCollide = canCollide,
		transparency = transparency or 0,
	}
end

-- Alle Offsets beziehen sich auf den Mittelpunkt von `Drive` (Model-Pivot).
-- Die sichtbare Front liegt auf lokal -Z (Richtung `CFrame.LookVector`);
-- Vorderrad, Lenker, Scheinwerfer und Gabel zeigen deshalb nach -Z.
-- Die Raeder stehen bei y=0; der Spawner setzt den Pivot deshalb auf
-- Bodenhoehe + PIVOT_HEIGHT.
local function buildSpec(
	vehicleId: string,
	displayName: string,
	frameColor: Rgb,
	tankColor: Rgb,
	accentColor: Rgb
): MopedSpec
	local black = rgb(24, 24, 24)
	local dark = rgb(38, 38, 42)
	local rubber = rgb(18, 18, 18)
	local light = rgb(255, 226, 120)
	local tail = rgb(200, 40, 36)
	local steel = rgb(150, 152, 156)

	return {
		vehicleId = vehicleId,
		displayName = displayName,
		primaryPart = MopedLayout.PRIMARY_PART,
		seatName = MopedLayout.SEAT_NAME,
		parts = {
			part("Drive", vec(0.7, 0.5, 2.8), vec(0, 0, 0), frameColor, "Block", true),
			part("WheelFront", vec(0.35, 1.4, 1.4), vec(0, 0, -1.35), rubber, "Cylinder", true),
			part("WheelRear", vec(0.35, 1.4, 1.4), vec(0, 0, 1.35), rubber, "Cylinder", true),
			part("Seat", vec(1.0, 0.35, 1.15), vec(0, 0.7, 0.35), dark, "Block", false),
			part("Handlebar", vec(1.3, 0.16, 0.16), vec(0, 0.85, -1.05), accentColor, "Block", false),
			part("Tank", vec(0.72, 0.45, 0.95), vec(0, 0.5, -0.15), tankColor, "Block", false),
			part("LightFront", vec(0.3, 0.3, 0.3), vec(0, 0.82, -1.3), light, "Block", false),
			part("LightRear", vec(0.22, 0.22, 0.12), vec(0, 0.55, 1.35), tail, "Block", false),
			part("Exhaust", vec(0.16, 0.16, 1.3), vec(0.36, -0.1, 0.85), steel, "Block", false),
			part("Fork", vec(0.16, 0.9, 0.16), vec(0, 0.25, -1.25), black, "Block", false),
		},
	}
end

local SPEC_FACTORIES: { [string]: () -> MopedSpec } = {
	puch_maxi_s = function(): MopedSpec
		return buildSpec(
			"puch_maxi_s",
			"Puch Maxi S",
			rgb(178, 46, 40),
			rgb(214, 196, 150),
			rgb(70, 70, 74)
		)
	end,
	piaggio_ciao = function(): MopedSpec
		return buildSpec(
			"piaggio_ciao",
			"Piaggio Ciao",
			rgb(38, 95, 148),
			rgb(212, 212, 216),
			rgb(60, 60, 64)
		)
	end,
}

local function copyVec(source: Vec3): Vec3
	return { x = source.x, y = source.y, z = source.z }
end

local function copyRgb(source: Rgb): Rgb
	return { r = source.r, g = source.g, b = source.b }
end

local function copySpec(source: MopedSpec): MopedSpec
	local parts: { PartSpec } = {}
	for _, entry in ipairs(source.parts) do
		table.insert(parts, {
			name = entry.name,
			size = copyVec(entry.size),
			offset = copyVec(entry.offset),
			color = copyRgb(entry.color),
			shape = entry.shape,
			canCollide = entry.canCollide,
			transparency = entry.transparency,
		})
	end
	return {
		vehicleId = source.vehicleId,
		displayName = source.displayName,
		primaryPart = source.primaryPart,
		seatName = source.seatName,
		parts = parts,
	}
end

-- Liefert eine frische Kopie, damit Aufrufer die Konstanten nicht mutieren.
function MopedLayout.get(vehicleId: string): MopedSpec?
	local factory = SPEC_FACTORIES[vehicleId]
	if factory == nil then
		return nil
	end
	return copySpec(factory())
end

function MopedLayout.isMoped(vehicleId: string): boolean
	return SPEC_FACTORIES[vehicleId] ~= nil
end

-- Deterministischer Parkplatz seitlich des Spielers. Puch und Ciao stehen
-- nebeneinander, damit sie sich beim Kauf nicht ueberlagern.
function MopedLayout.parkingOffsetFor(vehicleId: string): Vec3?
	local slot = PARKING_SLOTS[vehicleId]
	if slot == nil then
		return nil
	end
	return vec(slot * MopedLayout.SPAWN_SPACING, 0, 0)
end

function MopedLayout.validate(): boolean
	for vehicleId, factory in SPEC_FACTORIES do
		local spec = factory()
		assert(spec.vehicleId == vehicleId, string.format("moped '%s' has mismatched id", vehicleId))
		assert(spec.primaryPart == MopedLayout.PRIMARY_PART, string.format("moped '%s' must use Drive pivot", vehicleId))
		assert(spec.seatName == MopedLayout.SEAT_NAME, string.format("moped '%s' must expose Seat", vehicleId))

		local names: { [string]: boolean } = {}
		for _, entry in ipairs(spec.parts) do
			assert(entry.name ~= "", string.format("moped '%s' has an unnamed part", vehicleId))
			assert(names[entry.name] == nil, string.format("moped '%s' duplicates part '%s'", vehicleId, entry.name))
			names[entry.name] = true
			assert(entry.size.x > 0 and entry.size.y > 0 and entry.size.z > 0, string.format("moped '%s' part '%s' has non-positive size", vehicleId, entry.name))
			assert(entry.shape == "Block" or entry.shape == "Cylinder", string.format("moped '%s' part '%s' has invalid shape", vehicleId, entry.name))
			assert(entry.transparency >= 0 and entry.transparency <= 1, string.format("moped '%s' part '%s' has invalid transparency", vehicleId, entry.name))
		end
		for _, required in MopedLayout.REQUIRED_PARTS do
			assert(names[required] == true, string.format("moped '%s' misses part '%s'", vehicleId, required))
		end
		assert(MopedLayout.parkingOffsetFor(vehicleId) ~= nil, string.format("moped '%s' misses a parking slot", vehicleId))
	end
	return true
end

assert(MopedLayout.validate(), "MopedLayout failed validation on load")

return MopedLayout
