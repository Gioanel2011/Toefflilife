--!strict
-- PartsCatalog.spec: Validierung des Tuningteile-Katalogs (Task 13).

local PartsCatalog = require("../src/shared/data/PartsCatalog")

local function expect(condition: boolean, message: string)
	if not condition then
		error("PartsCatalog.spec FAILED: " .. message, 2)
	end
end

local EXPECTED_SLOTS: { string } = {
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

-- 1. Katalog validiert sich selbst.
local ok, err = PartsCatalog.validate()
expect(ok, "validate() schlug fehl: " .. tostring(err))

-- 2. Alle erwarteten Einbauplätze sind vorhanden.
expect(#PartsCatalog.SLOTS == #EXPECTED_SLOTS, "SLOTS-Anzahl muss 11 sein")
local slotSet: { [string]: boolean } = {}
for _, slot in PartsCatalog.SLOTS do
	slotSet[slot] = true
end
for _, slot in EXPECTED_SLOTS do
	expect(slotSet[slot] == true, "Slot fehlt: " .. slot)
end

-- 3. Jeder Slot besitzt mindestens ein Teil.
for _, slot in EXPECTED_SLOTS do
	local parts = PartsCatalog.getPartsForSlot(slot)
	expect(#parts >= 1, "Slot ohne Teile: " .. slot)
end

-- 4. Jedes Teil besitzt alle Pflichtfelder mit korrekten Typen.
local seenIds: { [string]: boolean } = {}
for _, part in PartsCatalog.Parts do
	expect(type(part.id) == "string" and part.id ~= "", "Teil ohne id")
	expect(seenIds[part.id] == nil, "doppelte id: " .. tostring(part.id))
	seenIds[part.id] = true
	expect(type(part.name) == "string" and part.name ~= "", "Teil ohne name: " .. part.id)
	expect(slotSet[part.slot] == true, "unbekannter Slot bei: " .. part.id)
	expect(type(part.compatibleModels) == "table" and #part.compatibleModels >= 1, "keine Modellkompatibilität: " .. part.id)
	expect(
		type(part.price) == "number" and part.price >= 0 and part.price == math.floor(part.price),
		"ungültiger Preis bei: " .. part.id
	)
	expect(type(part.statChanges) == "table", "keine Statänderungen bei: " .. part.id)
	expect(type(part.statChanges.powerDelta) == "number", "powerDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.torqueDelta) == "number", "torqueDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.topSpeedDelta) == "number", "topSpeedDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.accelerationDelta) == "number", "accelerationDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.brakingDelta) == "number", "brakingDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.gripDelta) == "number", "gripDelta fehlt bei: " .. part.id)
	expect(type(part.statChanges.consumptionDelta) == "number", "consumptionDelta fehlt bei: " .. part.id)
	expect(type(part.mountPoint) == "string" and part.mountPoint ~= "", "kein Montagepunkt bei: " .. part.id)
	expect(type(part.paintableAreas) == "table", "keine lackierbaren Flächen bei: " .. part.id)
	for _, area in part.paintableAreas do
		expect(type(area) == "string" and area ~= "", "ungültige Lackfläche bei: " .. part.id)
	end
end

-- 5. Zugriffsfunktionen arbeiten korrekt.
local cylinder = PartsCatalog.getPartById("cylinder_sport_70")
expect(cylinder ~= nil, "getPartById findet cylinder_sport_70 nicht")
expect((cylinder :: any).slot == "cylinder", "falscher Slot für cylinder_sport_70")
expect(PartsCatalog.getPartById("gibt_es_nicht") == nil, "getPartById muss nil für unbekannte IDs liefern")
expect(PartsCatalog.isCompatible("cylinder_sport_70", "puch_maxi_s"), "Sportzylinder muss mit Puch Maxi S kompatibel sein")
expect(PartsCatalog.isCompatible("cylinder_sport_70", "piaggio_ciao"), "Sportzylinder muss mit Piaggio Ciao kompatibel sein")
expect(not PartsCatalog.isCompatible("cylinder_sport_70", "bicycle"), "Motor-Teil darf nicht mit Fahrrad kompatibel sein")
expect(not PartsCatalog.isCompatible("unbekanntes_teil", "puch_maxi_s"), "unbekannte Teile sind inkompatibel")
expect(#PartsCatalog.getPartsForModel("puch_maxi_s") >= 1, "keine Teile für puch_maxi_s gefunden")
expect(#PartsCatalog.getPartsForModel("unbekanntes_modell") == 0, "unbekanntes Modell muss leere Liste liefern")

-- 6. Mindestens ein lackierbares Teil existiert (Felgen/Lampen-Pfad).
local paintableCount = 0
for _, part in PartsCatalog.Parts do
	if #part.paintableAreas > 0 then
		paintableCount += 1
	end
end
expect(paintableCount >= 1, "kein Teil mit lackierbaren Flächen gefunden")

print("PartsCatalog.spec: alle Prüfungen bestanden (" .. tostring(#PartsCatalog.Parts) .. " Teile, " .. tostring(#EXPECTED_SLOTS) .. " Slots).")
