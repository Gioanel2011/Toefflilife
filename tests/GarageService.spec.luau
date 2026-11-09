--!strict
-- GarageService.spec: Lune-Runner fuer Task 15 und Task 27.
-- Beweis: `lune run tests/GarageService.spec.luau` ist erfolgreich.

local GarageService: any = nil
local lastRequireError: string? = nil
for _, path in ipairs({
	"../src/server/services/GarageService",
	"./src/server/services/GarageService",
	"src/server/services/GarageService",
}) do
	local ok, mod = pcall(require, path)
	if ok then
		GarageService = mod
		break
	else
		lastRequireError = tostring(mod)
	end
end
if GarageService == nil then
	error("GarageService konnte nicht geladen werden: " .. tostring(lastRequireError))
end

local WorldLayout: any = nil
local lastLayoutError: string? = nil
for _, path in ipairs({
	"../src/server/world/WorldLayout",
	"./src/server/world/WorldLayout",
	"src/server/world/WorldLayout",
}) do
	local ok, mod = pcall(require, path)
	if ok then
		WorldLayout = mod
		break
	else
		lastLayoutError = tostring(mod)
	end
end
if WorldLayout == nil then
	error("WorldLayout konnte nicht geladen werden: " .. tostring(lastLayoutError))
end

local passed = 0
local function check(condition: boolean, label: string)
	if not condition then
		error("FEHLGESCHLAGEN: " .. label)
	end
	passed += 1
end

local function workshopState(overrides: any): any
	local state: any = {
		userId = 101,
		vehicleOwnerId = 101,
		vehicleId = "puch_maxi_s",
		vehicleKind = "moped",
		speed = 0,
		engineOn = false,
		riderUserId = nil,
		occupantCount = 0,
		onLift = true,
		onWorkshopPad = false,
		garageId = nil,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			state[key] = value
		end
	end
	return state
end

-- 1) Jeder Spieler erhaelt eine eigene private Garage im selben Server.
do
	local service = GarageService.new()
	local garageA, errA = service:assignGarage(101)
	check(garageA ~= nil and errA == nil, "garage fuer 101 zugewiesen")
	local garageB, errB = service:assignGarage(202)
	check(garageB ~= nil and errB == nil, "garage fuer 202 zugewiesen")
	check(garageA ~= garageB, "garagen sind privat und eindeutig")
	check(service:getGarage(101) == garageA, "getGarage liefert anker")
	check(service:getOwner(garageA) == "101", "getOwner liefert spieler")
	check(service:getAssignmentCount() == 2, "zwei zuweisungen")
	-- Idempotent: erneute Zuweisung liefert dieselbe Garage.
	local again, errAgain = service:assignGarage(101)
	check(again == garageA and errAgain == nil, "rejoin behaelt garage")
	check(service:getAssignmentCount() == 2, "kein duplikat bei rejoin")
end

-- 2) Zugriffsrechte: nur der Besitzer hat Zutritt.
do
	local service = GarageService.new()
	local garageA, _ = service:assignGarage(101)
	service:assignGarage(202)
	check(service:hasAccess(101, garageA) == true, "besitzer hat zugriff")
	check(service:hasAccess(202, garageA) == false, "fremder hat keinen zugriff")
	check(service:hasAccess(999, garageA) == false, "unbekannter hat keinen zugriff")
	check(service:hasAccess(101, "Garage_99") == false, "unbekannte garage kein zugriff")
	check(service:hasAccess(nil, garageA) == false, "nil-spieler kein zugriff")
end

-- 3) Freigabe gibt die Garage fuer andere frei.
do
	local service = GarageService.new({ anchors = { "Garage_01" } })
	local garageA, _ = service:assignGarage(101)
	check(garageA == "Garage_01", "feste garage zugewiesen")
	local full, errFull = service:assignGarage(202)
	check(full == nil and errFull == "no_free_garage", "keine garage bei vollbelegung")
	check(service:releaseGarage(101) == true, "freigabe ok")
	check(service:getGarage(101) == nil, "freigegebene garage weg")
	check(service:releaseGarage(101) == false, "doppelte freigabe false")
	local reused, _ = service:assignGarage(202)
	check(reused == "Garage_01", "freie garage wird wiedervergeben")
end

-- 4) Werkstatt-Happy-Path: eigenes Mofa, Stillstand, Motor aus, leer, auf Buehne.
do
	local service = GarageService.new()
	local ok, err = service:validateWorkshopState(workshopState())
	check(ok == true and err == nil, "werkstatt happy-path aktiv")
	check(service:isWorkshopActive(workshopState()) == true, "isWorkshopActive true")
	-- Werkstattplatz statt Hebebuehne gilt ebenfalls.
	check(
		service:isWorkshopActive(workshopState({ onLift = false, onWorkshopPad = true })) == true,
		"werkstattplatz gilt"
	)
end

-- 5) Werkstatt wird bei jeder Verletzung verweigert.
do
	local service = GarageService.new()
	local ok1, err1 = service:validateWorkshopState(workshopState({ vehicleOwnerId = 202 }))
	check(ok1 == false and err1 == "not_owner", "fremdes mofa abgelehnt")
	local ok2, err2 = service:validateWorkshopState(workshopState({ vehicleId = "bicycle", vehicleKind = "bicycle" }))
	check(ok2 == false and err2 == "bicycle_no_workshop", "fahrrad abgelehnt")
	local ok3, err3 = service:validateWorkshopState(workshopState({ speed = 5 }))
	check(ok3 == false and err3 == "vehicle_moving", "fahrt abgelehnt")
	local ok4, err4 = service:validateWorkshopState(workshopState({ engineOn = true }))
	check(ok4 == false and err4 == "engine_on", "motor an abgelehnt")
	local ok5, err5 = service:validateWorkshopState(workshopState({ riderUserId = 303 }))
	check(ok5 == false and err5 == "occupied", "fahrer abgelehnt")
	local ok6, err6 = service:validateWorkshopState(workshopState({ occupantCount = 1 }))
	check(ok6 == false and err6 == "occupied", "besetzt abgelehnt")
	local ok7, err7 = service:validateWorkshopState(workshopState({ onLift = false, onWorkshopPad = false }))
	check(ok7 == false and err7 == "not_on_lift_or_pad", "abseits der buehne abgelehnt")
	local ok8, err8 = service:validateWorkshopState(workshopState({ vehicleId = "" }))
	check(ok8 == false and err8 == "no_vehicle", "ohne fahrzeug abgelehnt")
	check(service:isWorkshopActive(workshopState({ speed = 5 })) == false, "isWorkshopActive false bei fahrt")
end

-- 6) Garagenbindung: Werkstatt nur mit Zugriff auf die angegebene Garage.
do
	local service = GarageService.new()
	local garageA, _ = service:assignGarage(101)
	service:assignGarage(202)
	local okOwn, _ = service:validateWorkshopState(workshopState({ garageId = garageA }))
	check(okOwn == true, "eigene garage erlaubt werkstatt")
	local foreign =
		service:validateWorkshopState(workshopState({ userId = 202, vehicleOwnerId = 202, garageId = garageA }))
	check(foreign == false, "fremde garage verweigert werkstatt")
end

-- 7) Vollstaendige Vergabe: alle 15 Weltanker, genau ein Anker je Spieler.
local worldAnchorIds: { string } = {}
do
	for _, anchor in ipairs(WorldLayout.getGarageAnchors()) do
		check(type(anchor) == "table" and type(anchor.id) == "string", "weltanker besitzt id")
		table.insert(worldAnchorIds, anchor.id)
	end
	check(#worldAnchorIds == 15, "worldlayout liefert 15 anker")

	local service = GarageService.new({ anchors = worldAnchorIds })
	check(#service:getAnchors() == 15, "service uebernimmt 15 weltanker")

	local assigned: { [string]: number } = {}
	local firstGarage: string? = nil
	for playerId = 1001, 1015 do
		local garage, err = service:assignGarage(playerId)
		check(garage ~= nil and err == nil, "spieler " .. tostring(playerId) .. " erhaelt anker")
		check(assigned[garage :: string] == nil, "anker ist eindeutig")
		assigned[garage :: string] = playerId
		if firstGarage == nil then
			firstGarage = garage
		end
		check(service:getOwner(garage) == tostring(playerId), "besitzer ist spieler")
	end
	check(service:getAssignmentCount() == 15, "15 vollstaendige zuweisungen")
	for _, anchorId in ipairs(worldAnchorIds) do
		check(assigned[anchorId] ~= nil, "anker " .. anchorId .. " ist vergeben")
	end

	local none, errFull = service:assignGarage(1016)
	check(none == nil and errFull == "no_free_garage", "16. spieler erhaelt keinen anker")

	check(service:releaseGarage(1001) == true, "freigabe des ersten spielers")
	check(service:getAssignmentCount() == 14, "nach freigabe 14 zuweisungen")
	local reused, errReused = service:assignGarage(1016)
	check(reused == firstGarage and errReused == nil, "freier anker wird wiedervergeben")
	check(service:getOwner(firstGarage :: string) == "1016", "neuer besitzer eingetragen")

	for playerId = 1002, 1015 do
		service:releaseGarage(playerId)
	end
	service:releaseGarage(1016)
	check(service:getAssignmentCount() == 0, "alle anker wieder frei")
	check(service:releaseGarage(9999) == false, "unbekannter spieler ohne freigabe")
end

-- 8) Fremdzugriff: fremde Anker und fremde Hebebuehne werden abgewiesen.
do
	local service = GarageService.new({ anchors = worldAnchorIds })
	local garageA, _ = service:assignGarage(101)
	local garageB, _ = service:assignGarage(202)
	check(garageA ~= garageB, "zwei spieler erhalten verschiedene anker")
	check(service:hasAccess(101, garageA) == true, "besitzer nutzt eigenen anker")
	check(service:hasAccess(202, garageA) == false, "fremder nutzt keinen fremden anker")
	check(service:hasAccess(202, garageB) == true, "besitzer nutzt eigenen zweiten anker")

	local okForeign, errForeign = service:validateWorkshopState(workshopState({
		userId = 202,
		vehicleOwnerId = 202,
		garageId = garageA,
	}))
	check(okForeign == false and errForeign == "no_garage_access", "fremde hebebuehne verweigert")
	check(service:isWorkshopActive(workshopState({
		userId = 202,
		vehicleOwnerId = 202,
		garageId = garageA,
	})) == false, "fremder werkstattzustand inaktiv")

	local okOwner, errOwner = service:validateWorkshopState(workshopState({
		userId = 101,
		vehicleOwnerId = 101,
		garageId = garageA,
	}))
	check(okOwner == true and errOwner == nil, "eigene hebebuehne erlaubt")
end

-- 9) Singleton-Verdrahtung: Player-Objekte, callOptional-Stil und Freigabe.
do
	GarageService.init({ anchors = worldAnchorIds })
	local playerA = { UserId = 501, Name = "Anna" }
	local playerB = { UserId = 502, Name = "Beat" }

	local garageA, errA = GarageService.assignGarage(playerA)
	check(garageA ~= nil and errA == nil, "singleton vergibt an player-objekt")
	local garageB = GarageService.assignGarage(GarageService, playerB)
	check(garageB ~= nil and garageB ~= garageA, "callOptional-stil vergibt eigenen anker")
	check(GarageService.getGarage(playerA) == garageA, "player-objekt findet garage")
	check(GarageService:hasAccess(playerB, garageA) == false, "fremder player hat keinen zugriff")
	check(GarageService:hasAccess(playerB, garageB) == true, "eigener player hat zugriff")

	local okForeign, errForeign = GarageService:validateWorkshopState(workshopState({
		userId = playerB,
		vehicleOwnerId = playerB,
		garageId = garageA,
	}))
	check(okForeign == false and errForeign == "no_garage_access", "fremder player kein werkstattzustand")

	check(GarageService.releaseGarage(playerA) == true, "singleton freigabe")
	check(GarageService.getGarage(playerA) == nil, "freigabe entfernt zuordnung")
	local reused, errReused = GarageService.assignGarage(playerA)
	check(reused == garageA and errReused == nil, "freigegebener anker wieder verfuegbar")
end

print("GarageService.spec: " .. tostring(passed) .. " Pruefungen bestanden.")
