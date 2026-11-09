--!strict
-- VehicleCatalog.spec: via `lune run tests/VehicleCatalog.spec.luau` ausführbar.

local VehicleCatalog = require("../src/shared/data/VehicleCatalog")

local function check(condition: boolean, message: string)
	if not condition then
		error("VehicleCatalog.spec failed: " .. message, 2)
	end
end

-- Katalog validiert beim Laden und explizit.
check(VehicleCatalog.validate() == true, "validate() must return true")
check(VehicleCatalog.VERSION == 1, "VERSION must be 1")

-- Genau drei stabile IDs.
local vehicles = VehicleCatalog.list()
check(#vehicles == 3, "list() must return 3 vehicles")

local bicycle = VehicleCatalog.get("bicycle")
local puch = VehicleCatalog.get("puch_maxi_s")
local ciao = VehicleCatalog.get("piaggio_ciao")
check(bicycle ~= nil, "bicycle must exist")
check(puch ~= nil, "puch_maxi_s must exist")
check(ciao ~= nil, "piaggio_ciao must exist")
check(VehicleCatalog.get("unknown_id") == nil, "unknown id must return nil")

-- Fahrrad: kostenlos, ohne Motor/Tank/Tuning.
check(bicycle ~= nil and bicycle.Class == "bicycle", "bicycle class")
check(bicycle ~= nil and bicycle.Pricing.Price == 0, "bicycle must be free")
check(bicycle ~= nil and bicycle.Fuel.HasEngine == false, "bicycle must not have an engine")
check(bicycle ~= nil and bicycle.Fuel.TankLiters == 0, "bicycle tank must be 0")
check(bicycle ~= nil and bicycle.Tunable == false, "bicycle must not be tunable")

-- Mofas: Motor, Tankvolumen, Preis, Rabattfähigkeit, unterscheidbare Basiswerte.
check(puch ~= nil and puch.Class == "moped", "puch class")
check(ciao ~= nil and ciao.Class == "moped", "ciao class")
check(puch ~= nil and puch.Fuel.HasEngine == true, "puch needs engine")
check(ciao ~= nil and ciao.Fuel.HasEngine == true, "ciao needs engine")
check(puch ~= nil and puch.Fuel.TankLiters > 0, "puch needs tank volume")
check(ciao ~= nil and ciao.Fuel.TankLiters > 0, "ciao needs tank volume")
check(puch ~= nil and puch.Pricing.Price > 0, "puch needs price")
check(ciao ~= nil and ciao.Pricing.Price > 0, "ciao needs price")
check(puch ~= nil and puch.Pricing.StarterDiscountEligible == true, "puch starter discount flag")
check(ciao ~= nil and ciao.Pricing.StarterDiscountEligible == true, "ciao starter discount flag")
check(
	puch ~= nil and ciao ~= nil and (puch.Physics.TopSpeedKmh ~= ciao.Physics.TopSpeedKmh or puch.Physics.Acceleration ~= ciao.Physics.Acceleration),
	"mopeds must have distinguishable base stats"
)

-- Preis/Rabatt getrennt von Fahrphysik.
for _, vehicle in vehicles do
	local pricing = (vehicle :: any).Pricing
	local physics = (vehicle :: any).Physics
	check(pricing.TopSpeedKmh == nil, vehicle.Id .. ": Pricing must not contain physics")
	check(physics.Price == nil, vehicle.Id .. ": Physics must not contain price")
	check(physics.StarterDiscountEligible == nil, vehicle.Id .. ": Physics must not contain discount flag")
end

-- Montagepunkte und Serienteile.
for _, vehicle in vehicles do
	check(#vehicle.Mounts > 0, vehicle.Id .. " needs mounts")
	for _, slot in vehicle.Mounts do
		local partId = vehicle.StockParts[slot]
		check(typeof(partId) == "string" and partId ~= "", vehicle.Id .. " misses stock part for " .. tostring(slot))
	end
end

-- Helper.
check(VehicleCatalog.isMoped("puch_maxi_s") == true, "isMoped puch")
check(VehicleCatalog.isMoped("bicycle") == false, "isMoped bicycle")
check(VehicleCatalog.hasEngine("piaggio_ciao") == true, "hasEngine ciao")
check(VehicleCatalog.hasEngine("bicycle") == false, "hasEngine bicycle")

print("VehicleCatalog.spec: all checks passed (3 vehicles, pricing/physics separated, mounts + stock parts validated)")
