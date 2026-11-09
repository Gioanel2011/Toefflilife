--!strict
-- PartsCatalog: Platzhalter-Tuningteile für TöffliTal.
-- Modell-IDs ("bicycle", "puch_maxi_s", "piaggio_ciao") spiegeln die
-- stabilen IDs aus VehicleCatalog. Motor-Teile sind bewusst nicht mit dem
-- Fahrrad kompatibel (kein Motor, keine Tuning-Schnittstelle).

export type StatChanges = {
	powerDelta: number,
	torqueDelta: number,
	topSpeedDelta: number,
	accelerationDelta: number,
	brakingDelta: number,
	gripDelta: number,
	consumptionDelta: number,
}

export type PartDefinition = {
	id: string,
	name: string,
	slot: string,
	compatibleModels: { string },
	price: number,
	statChanges: StatChanges,
	mountPoint: string,
	paintableAreas: { string },
}

local PartsCatalog = {}

PartsCatalog.SLOTS = {
	"cylinder",
	"cylinderHead",
	"carburetor",
	"exhaust",
	"airFilter",
	"intakeManifold",
	"handlebar",
	"brakes",
	"wheels",
	"rims",
	"lamp",
}

PartsCatalog.MODELS = {
	"bicycle",
	"puch_maxi_s",
	"piaggio_ciao",
}

local MOPEDS: { string } = { "puch_maxi_s", "piaggio_ciao" }
local ALL_MODELS: { string } = { "bicycle", "puch_maxi_s", "piaggio_ciao" }

local function stats(
	powerDelta: number,
	torqueDelta: number,
	topSpeedDelta: number,
	accelerationDelta: number,
	brakingDelta: number,
	gripDelta: number,
	consumptionDelta: number
): StatChanges
	return {
		powerDelta = powerDelta,
		torqueDelta = torqueDelta,
		topSpeedDelta = topSpeedDelta,
		accelerationDelta = accelerationDelta,
		brakingDelta = brakingDelta,
		gripDelta = gripDelta,
		consumptionDelta = consumptionDelta,
	}
end

local function copyModels(source: { string }): { string }
	local result: { string } = {}
	for _, modelId in source do
		table.insert(result, modelId)
	end
	return result
end

PartsCatalog.Parts = {
	{
		id = "cylinder_stock_50",
		name = "Serienzylinder 50ccm",
		slot = "cylinder",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.CylinderMount",
		paintableAreas = {},
	},
	{
		id = "cylinder_sport_70",
		name = "Sportzylinder 70ccm (Platzhalter)",
		slot = "cylinder",
		compatibleModels = copyModels(MOPEDS),
		price = 450,
		statChanges = stats(0.35, 0.25, 8, 0.2, 0, 0, 0.3),
		mountPoint = "Engine.CylinderMount",
		paintableAreas = { "Cylinder" },
	},
	{
		id = "head_stock",
		name = "Serien-Zylinderkopf",
		slot = "cylinderHead",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.HeadMount",
		paintableAreas = {},
	},
	{
		id = "head_sport",
		name = "Sport-Zylinderkopf (Platzhalter)",
		slot = "cylinderHead",
		compatibleModels = copyModels(MOPEDS),
		price = 220,
		statChanges = stats(0.12, 0.08, 2, 0.05, 0, 0, 0.1),
		mountPoint = "Engine.HeadMount",
		paintableAreas = { "Head" },
	},
	{
		id = "carb_stock_12",
		name = "Serienvergaser 12mm",
		slot = "carburetor",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.CarbMount",
		paintableAreas = {},
	},
	{
		id = "carb_sport_15",
		name = "Sportvergaser 15mm (Platzhalter)",
		slot = "carburetor",
		compatibleModels = copyModels(MOPEDS),
		price = 180,
		statChanges = stats(0.15, 0.1, 3, 0.1, 0, 0, 0.15),
		mountPoint = "Engine.CarbMount",
		paintableAreas = {},
	},
	{
		id = "exhaust_stock",
		name = "Serienauspuff",
		slot = "exhaust",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.ExhaustMount",
		paintableAreas = {},
	},
	{
		id = "exhaust_sport",
		name = "Sportauspuff (Platzhalter)",
		slot = "exhaust",
		compatibleModels = copyModels(MOPEDS),
		price = 320,
		statChanges = stats(0.18, 0.1, 4, 0.12, 0, 0, 0.1),
		mountPoint = "Engine.ExhaustMount",
		paintableAreas = { "ExhaustPipe" },
	},
	{
		id = "airfilter_stock",
		name = "Serienluftfilter",
		slot = "airFilter",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.AirboxMount",
		paintableAreas = {},
	},
	{
		id = "airfilter_sport",
		name = "Sportluftfilter (Platzhalter)",
		slot = "airFilter",
		compatibleModels = copyModels(MOPEDS),
		price = 90,
		statChanges = stats(0.06, 0.03, 1, 0.04, 0, 0, 0.05),
		mountPoint = "Engine.AirboxMount",
		paintableAreas = { "Airbox" },
	},
	{
		id = "intake_stock",
		name = "Serien-Ansaugstutzen",
		slot = "intakeManifold",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Engine.IntakeMount",
		paintableAreas = {},
	},
	{
		id = "intake_sport",
		name = "Sport-Ansaugstutzen (Platzhalter)",
		slot = "intakeManifold",
		compatibleModels = copyModels(MOPEDS),
		price = 110,
		statChanges = stats(0.08, 0.06, 1, 0.05, 0, 0, 0.05),
		mountPoint = "Engine.IntakeMount",
		paintableAreas = {},
	},
	{
		id = "handlebar_stock",
		name = "Serienlenker mit Gasgriff",
		slot = "handlebar",
		compatibleModels = copyModels(ALL_MODELS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Cockpit.HandlebarMount",
		paintableAreas = {},
	},
	{
		id = "handlebar_touring",
		name = "Touringlenker mit Gasgriff (Platzhalter)",
		slot = "handlebar",
		compatibleModels = copyModels(ALL_MODELS),
		price = 140,
		statChanges = stats(0, 0, 0, 0, 0, 0.08, 0),
		mountPoint = "Cockpit.HandlebarMount",
		paintableAreas = { "Handlebar", "Grips" },
	},
	{
		id = "brakes_stock",
		name = "Serienbremsen",
		slot = "brakes",
		compatibleModels = copyModels(ALL_MODELS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Wheel.BrakeMount",
		paintableAreas = {},
	},
	{
		id = "brakes_sport",
		name = "Sportbremsen (Platzhalter)",
		slot = "brakes",
		compatibleModels = copyModels(ALL_MODELS),
		price = 200,
		statChanges = stats(0, 0, 0, 0, 0.25, 0.02, 0),
		mountPoint = "Wheel.BrakeMount",
		paintableAreas = { "BrakeCaliper" },
	},
	{
		id = "wheels_stock",
		name = "Serienräder",
		slot = "wheels",
		compatibleModels = copyModels(ALL_MODELS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Wheel.HubMount",
		paintableAreas = {},
	},
	{
		id = "wheels_alloy",
		name = "Aluräder (Platzhalter)",
		slot = "wheels",
		compatibleModels = copyModels(ALL_MODELS),
		price = 260,
		statChanges = stats(0, 0, 1, 0.03, 0, 0.1, 0),
		mountPoint = "Wheel.HubMount",
		paintableAreas = { "Hub" },
	},
	{
		id = "rims_stock",
		name = "Serienfelgen",
		slot = "rims",
		compatibleModels = copyModels(MOPEDS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Wheel.RimMount",
		paintableAreas = { "RimFront", "RimRear" },
	},
	{
		id = "rims_color",
		name = "Farb-Felgen (Platzhalter)",
		slot = "rims",
		compatibleModels = copyModels(MOPEDS),
		price = 160,
		statChanges = stats(0, 0, 0, 0, 0, 0.02, 0),
		mountPoint = "Wheel.RimMount",
		paintableAreas = { "RimFront", "RimRear" },
	},
	{
		id = "lamp_stock",
		name = "Serienlampe",
		slot = "lamp",
		compatibleModels = copyModels(ALL_MODELS),
		price = 0,
		statChanges = stats(0, 0, 0, 0, 0, 0, 0),
		mountPoint = "Frame.LampMount",
		paintableAreas = {},
	},
	{
		id = "lamp_led",
		name = "LED-Lampe (Platzhalter)",
		slot = "lamp",
		compatibleModels = copyModels(ALL_MODELS),
		price = 120,
		statChanges = stats(0, 0, 0, 0, 0, 0, -0.02),
		mountPoint = "Frame.LampMount",
		paintableAreas = { "LampHousing" },
	},
}

PartsCatalog.ById = {}
for _, part in PartsCatalog.Parts do
	PartsCatalog.ById[part.id] = part
end

local STAT_KEYS: { string } = {
	"powerDelta",
	"torqueDelta",
	"topSpeedDelta",
	"accelerationDelta",
	"brakingDelta",
	"gripDelta",
	"consumptionDelta",
}

function PartsCatalog.getPartById(id: string): PartDefinition?
	return PartsCatalog.ById[id]
end

function PartsCatalog.getPartsForSlot(slot: string): { PartDefinition }
	local result: { PartDefinition } = {}
	for _, part in PartsCatalog.Parts do
		if part.slot == slot then
			table.insert(result, part)
		end
	end
	return result
end

function PartsCatalog.getPartsForModel(modelId: string): { PartDefinition }
	local result: { PartDefinition } = {}
	for _, part in PartsCatalog.Parts do
		for _, compatible in part.compatibleModels do
			if compatible == modelId then
				table.insert(result, part)
				break
			end
		end
	end
	return result
end

function PartsCatalog.isCompatible(partOrId: PartDefinition | string, modelId: string): boolean
	local part: PartDefinition?
	if type(partOrId) == "string" then
		part = PartsCatalog.ById[partOrId :: string]
	else
		part = partOrId :: PartDefinition
	end
	if part == nil then
		return false
	end
	for _, compatible in (part :: PartDefinition).compatibleModels do
		if compatible == modelId then
			return true
		end
	end
	return false
end

function PartsCatalog.validate(): (boolean, string?)
	local slotSet: { [string]: boolean } = {}
	for _, slot in PartsCatalog.SLOTS do
		if type(slot) ~= "string" or slot == "" then
			return false, "invalid slot entry"
		end
		if slotSet[slot] then
			return false, "duplicate slot: " .. slot
		end
		slotSet[slot] = true
	end

	local seenIds: { [string]: boolean } = {}
	for index, part in PartsCatalog.Parts do
		if type(part.id) ~= "string" or part.id == "" then
			return false, string.format("part #%d has invalid id", index)
		end
		if seenIds[part.id] then
			return false, "duplicate part id: " .. part.id
		end
		seenIds[part.id] = true

		if type(part.name) ~= "string" or part.name == "" then
			return false, "part has invalid name: " .. part.id
		end
		if not slotSet[part.slot] then
			return false, "part has unknown slot: " .. part.id
		end
		if type(part.compatibleModels) ~= "table" or #part.compatibleModels == 0 then
			return false, "part has no compatible models: " .. part.id
		end
		local seenModels: { [string]: boolean } = {}
		for _, modelId in part.compatibleModels do
			if type(modelId) ~= "string" or modelId == "" then
				return false, "part has invalid model entry: " .. part.id
			end
			if seenModels[modelId] then
				return false, "part lists model twice: " .. part.id
			end
			seenModels[modelId] = true
		end
		if type(part.price) ~= "number" or part.price < 0 or part.price ~= math.floor(part.price) then
			return false, "part has invalid price: " .. part.id
		end
		if type(part.statChanges) ~= "table" then
			return false, "part has invalid statChanges: " .. part.id
		end
		for _, key in STAT_KEYS do
			local value = (part.statChanges :: { [string]: any })[key]
			if type(value) ~= "number" then
				return false, "part has invalid stat " .. key .. ": " .. part.id
			end
		end
		if type(part.mountPoint) ~= "string" or part.mountPoint == "" then
			return false, "part has invalid mountPoint: " .. part.id
		end
		if type(part.paintableAreas) ~= "table" then
			return false, "part has invalid paintableAreas: " .. part.id
		end
		for _, area in part.paintableAreas do
			if type(area) ~= "string" or area == "" then
				return false, "part has invalid paintable area: " .. part.id
			end
		end
	end

	for _, slot in PartsCatalog.SLOTS do
		if #PartsCatalog.getPartsForSlot(slot) == 0 then
			return false, "slot without parts: " .. slot
		end
	end

	return true, nil
end

local ok, err = PartsCatalog.validate()
assert(ok, "PartsCatalog invalid: " .. tostring(err))

return PartsCatalog
