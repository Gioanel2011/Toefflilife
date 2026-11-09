--!strict
-- VehicleCatalog: statische Definitionen für Fahrrad, Puch Maxi S und Piaggio Ciao.
-- Preis-/Rabattdaten (Pricing) sind strikt von Fahrphysik (Physics) getrennt.
-- Der Katalog wird beim Laden validiert.

export type VehicleClass = "bicycle" | "moped"

export type VehiclePricing = {
	Price: number,
	StarterDiscountEligible: boolean,
	Currency: string,
}

export type VehiclePhysics = {
	TopSpeedKmh: number,
	Acceleration: number,
	Braking: number,
	Handling: number,
	WeightKg: number,
}

export type VehicleFuel = {
	HasEngine: boolean,
	TankLiters: number,
	FuelType: string,
}

export type VehicleDefinition = {
	Id: string,
	Name: string,
	Class: VehicleClass,
	Pricing: VehiclePricing,
	Physics: VehiclePhysics,
	Fuel: VehicleFuel,
	Mounts: { string },
	StockParts: { [string]: string },
	Tunable: boolean,
}

local VehicleCatalog = {}

VehicleCatalog.VERSION = 1

VehicleCatalog.BICYCLE_ID = "bicycle"
VehicleCatalog.PUCH_MAXI_S_ID = "puch_maxi_s"
VehicleCatalog.PIAGGIO_CIAO_ID = "piaggio_ciao"

local BICYCLE_MOUNTS: { string } = {
	"BrakeFront",
	"BrakeRear",
	"WheelFront",
	"WheelRear",
	"LightFront",
}

local MOPED_MOUNTS: { string } = {
	"Cylinder",
	"CylinderHead",
	"Carburetor",
	"Exhaust",
	"AirFilter",
	"IntakeManifold",
	"Handlebar",
	"BrakeFront",
	"BrakeRear",
	"WheelFront",
	"WheelRear",
	"RimFront",
	"RimRear",
	"LightFront",
	"LightRear",
}

local function makeStockParts(mounts: { string }, prefix: string): { [string]: string }
	local parts: { [string]: string } = {}
	for _, slot in mounts do
		parts[slot] = string.format("%s_stock_%s", prefix, string.lower(slot))
	end
	return parts
end

local VEHICLES: { [string]: VehicleDefinition } = {
	bicycle = {
		Id = "bicycle",
		Name = "Startfahrrad",
		Class = "bicycle",
		Pricing = {
			Price = 0,
			StarterDiscountEligible = false,
			Currency = "CHF",
		},
		Physics = {
			TopSpeedKmh = 25,
			Acceleration = 3.0,
			Braking = 6.0,
			Handling = 9.0,
			WeightKg = 15,
		},
		Fuel = {
			HasEngine = false,
			TankLiters = 0,
			FuelType = "none",
		},
		Mounts = BICYCLE_MOUNTS,
		StockParts = makeStockParts(BICYCLE_MOUNTS, "bicycle"),
		Tunable = false,
	},
	puch_maxi_s = {
		Id = "puch_maxi_s",
		Name = "Puch Maxi S",
		Class = "moped",
		Pricing = {
			Price = 1799,
			StarterDiscountEligible = true,
			Currency = "CHF",
		},
		Physics = {
			TopSpeedKmh = 45,
			Acceleration = 6.5,
			Braking = 7.0,
			Handling = 7.5,
			WeightKg = 68,
		},
		Fuel = {
			HasEngine = true,
			TankLiters = 3.8,
			FuelType = "petrol",
		},
		Mounts = MOPED_MOUNTS,
		StockParts = makeStockParts(MOPED_MOUNTS, "puch_maxi_s"),
		Tunable = true,
	},
	piaggio_ciao = {
		Id = "piaggio_ciao",
		Name = "Piaggio Ciao",
		Class = "moped",
		Pricing = {
			Price = 1899,
			StarterDiscountEligible = true,
			Currency = "CHF",
		},
		Physics = {
			TopSpeedKmh = 42,
			Acceleration = 5.8,
			Braking = 6.8,
			Handling = 8.0,
			WeightKg = 55,
		},
		Fuel = {
			HasEngine = true,
			TankLiters = 2.8,
			FuelType = "petrol",
		},
		Mounts = MOPED_MOUNTS,
		StockParts = makeStockParts(MOPED_MOUNTS, "piaggio_ciao"),
		Tunable = true,
	},
}

local function isNonEmptyString(value: unknown): boolean
	return typeof(value) == "string" and (value :: string) ~= ""
end

local function isPositiveNumber(value: unknown): boolean
	return typeof(value) == "number" and (value :: number) > 0
end

local function isNonNegativeNumber(value: unknown): boolean
	return typeof(value) == "number" and (value :: number) >= 0
end

function VehicleCatalog.validate(): boolean
	local count = 0
	for key, vehicle in VEHICLES do
		count += 1
		assert(key == vehicle.Id, string.format("vehicle key '%s' must match Id '%s'", tostring(key), tostring(vehicle.Id)))
		assert(isNonEmptyString(vehicle.Id), "vehicle Id must be a non-empty string")
		assert(isNonEmptyString(vehicle.Name), string.format("vehicle '%s' needs a name", tostring(vehicle.Id)))
		assert(vehicle.Class == "bicycle" or vehicle.Class == "moped", string.format("vehicle '%s' has invalid class", tostring(vehicle.Id)))

		-- Pricing getrennt von Physics prüfen.
		assert(vehicle.Pricing ~= nil, string.format("vehicle '%s' needs Pricing", tostring(vehicle.Id)))
		assert(vehicle.Physics ~= nil, string.format("vehicle '%s' needs Physics", tostring(vehicle.Id)))
		assert((vehicle.Pricing :: any).TopSpeedKmh == nil, string.format("vehicle '%s': physics must not leak into Pricing", tostring(vehicle.Id)))
		assert((vehicle.Physics :: any).Price == nil, string.format("vehicle '%s': price must not leak into Physics", tostring(vehicle.Id)))
		assert(isNonNegativeNumber(vehicle.Pricing.Price), string.format("vehicle '%s' needs Price >= 0", tostring(vehicle.Id)))
		assert(typeof(vehicle.Pricing.StarterDiscountEligible) == "boolean", string.format("vehicle '%s' needs StarterDiscountEligible flag", tostring(vehicle.Id)))
		assert(isNonEmptyString(vehicle.Pricing.Currency), string.format("vehicle '%s' needs Currency", tostring(vehicle.Id)))

		assert(isPositiveNumber(vehicle.Physics.TopSpeedKmh), string.format("vehicle '%s' needs TopSpeedKmh > 0", tostring(vehicle.Id)))
		assert(isPositiveNumber(vehicle.Physics.Acceleration), string.format("vehicle '%s' needs Acceleration > 0", tostring(vehicle.Id)))
		assert(isPositiveNumber(vehicle.Physics.Braking), string.format("vehicle '%s' needs Braking > 0", tostring(vehicle.Id)))
		assert(isPositiveNumber(vehicle.Physics.Handling), string.format("vehicle '%s' needs Handling > 0", tostring(vehicle.Id)))
		assert(isPositiveNumber(vehicle.Physics.WeightKg), string.format("vehicle '%s' needs WeightKg > 0", tostring(vehicle.Id)))

		assert(vehicle.Fuel ~= nil, string.format("vehicle '%s' needs Fuel", tostring(vehicle.Id)))
		assert(typeof(vehicle.Fuel.HasEngine) == "boolean", string.format("vehicle '%s' needs Fuel.HasEngine", tostring(vehicle.Id)))
		assert(isNonNegativeNumber(vehicle.Fuel.TankLiters), string.format("vehicle '%s' needs TankLiters >= 0", tostring(vehicle.Id)))

		if vehicle.Class == "bicycle" then
			assert(vehicle.Fuel.HasEngine == false, "bicycle must not have an engine")
			assert(vehicle.Fuel.TankLiters == 0, "bicycle must have TankLiters == 0")
			assert(vehicle.Pricing.Price == 0, "bicycle must be free")
			assert(vehicle.Tunable == false, "bicycle must not expose a tuning interface")
		else
			assert(vehicle.Fuel.HasEngine == true, string.format("moped '%s' needs an engine", tostring(vehicle.Id)))
			assert(vehicle.Fuel.TankLiters > 0, string.format("moped '%s' needs TankLiters > 0", tostring(vehicle.Id)))
			assert(vehicle.Pricing.Price > 0, string.format("moped '%s' needs Price > 0", tostring(vehicle.Id)))
			assert(vehicle.Tunable == true, string.format("moped '%s' must be tunable", tostring(vehicle.Id)))
		end

		assert(typeof(vehicle.Mounts) == "table", string.format("vehicle '%s' needs Mounts", tostring(vehicle.Id)))
		assert(#vehicle.Mounts > 0, string.format("vehicle '%s' needs at least one mount", tostring(vehicle.Id)))
		assert(typeof(vehicle.StockParts) == "table", string.format("vehicle '%s' needs StockParts", tostring(vehicle.Id)))
		for _, slot in vehicle.Mounts do
			assert(isNonEmptyString(slot), string.format("vehicle '%s' has invalid mount slot", tostring(vehicle.Id)))
			assert(isNonEmptyString(vehicle.StockParts[slot]), string.format("vehicle '%s' misses stock part for slot '%s'", tostring(vehicle.Id), tostring(slot)))
		end
	end
	assert(count == 3, string.format("catalog must contain exactly 3 vehicles, found %d", count))
	assert(VEHICLES.bicycle ~= nil, "catalog misses 'bicycle'")
	assert(VEHICLES.puch_maxi_s ~= nil, "catalog misses 'puch_maxi_s'")
	assert(VEHICLES.piaggio_ciao ~= nil, "catalog misses 'piaggio_ciao'")
	return true
end

function VehicleCatalog.get(vehicleId: string): VehicleDefinition?
	return VEHICLES[vehicleId]
end

function VehicleCatalog.list(): { VehicleDefinition }
	return { VEHICLES.bicycle, VEHICLES.puch_maxi_s, VEHICLES.piaggio_ciao }
end

function VehicleCatalog.isMoped(vehicleId: string): boolean
	local vehicle = VEHICLES[vehicleId]
	return vehicle ~= nil and vehicle.Class == "moped"
end

function VehicleCatalog.hasEngine(vehicleId: string): boolean
	local vehicle = VEHICLES[vehicleId]
	return vehicle ~= nil and vehicle.Fuel.HasEngine == true
end

assert(VehicleCatalog.validate(), "VehicleCatalog failed validation on load")

return VehicleCatalog
