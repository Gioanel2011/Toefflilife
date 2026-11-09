--!strict
-- WorkshopService.spec: Lune-faehiger Validierungstest.
local WorkshopService = require("../src/server/services/WorkshopService")

local function makeService(active: boolean)
	local profiles = {
		p1 = {
			vehicles = {
				v1 = {
					modelId = "puch-maxi-s",
					parts = {},
					colors = {},
					stats = nil,
				},
			},
			inventory = {
				["zylinder-70ccm"] = 1,
			},
		},
	}
	local parts = {
		["zylinder-70ccm"] = {
			slot = "zylinder",
			models = { "puch-maxi-s" },
		},
		["fremd-teil"] = {
			slot = "auspuff",
			models = { "piaggio-ciao" },
		},
	}
	local computeCalls = { n = 0 }
	local svc = WorkshopService.new({
		profiles = profiles,
		parts = parts,
		isWorkshopActive = function(_playerId: string): boolean
			return active
		end,
		computeStats = function(_modelId: string, _partMap: { [string]: string })
			computeCalls.n += 1
			return { version = computeCalls.n }
		end,
	})
	return svc, profiles, computeCalls
end

local function check(cond: boolean, msg: string)
	if not cond then
		error("ASSERT: " .. msg)
	end
end

-- 1. Inaktiver Werkstattzustand blockiert Einbau.
do
	local svc = makeService(false)
	local ok, err = svc:installPart("p1", "v1", "zylinder-70ccm", { source = "workshop" })
	check(ok == false and err == "WorkshopInactive", "inaktive Werkstatt muss blockieren")
end

-- 2. Laptop-Quelle wird abgewiesen, auch bei aktiver Werkstatt.
do
	local svc = makeService(true)
	local ok, err = svc:installPart("p1", "v1", "zylinder-70ccm", { source = "laptop" })
	check(ok == false and err == "LaptopNotAllowed", "laptop muss abgewiesen werden")
	local ok2, err2 = svc:paint("p1", "v1", { surface = "tank", color = "#FF0000" }, { source = "laptop" })
	check(ok2 == false and err2 == "LaptopNotAllowed", "laptop-lackierung muss abgewiesen werden")
end

-- 3. Erfolgreicher Einbau: Inventar -1, Teil gesetzt, Stats neu berechnet.
do
	local svc, profiles, calls = makeService(true)
	local ok, err = svc:installPart("p1", "v1", "zylinder-70ccm", { source = "workshop" })
	check(ok == true, "einbau muss gelingen, err=" .. tostring(err))
	check(profiles.p1.inventory["zylinder-70ccm"] == 0, "inventar muss verbraucht sein")
	check(profiles.p1.vehicles.v1.parts["zylinder"] == "zylinder-70ccm", "teil muss verbaut sein")
	check(calls.n == 1, "stats muessen neu berechnet werden")
	check(profiles.p1.vehicles.v1.stats ~= nil, "stats muessen gesetzt sein")
end

-- 4. Inkompatibles Teil und fehlendes Inventar werden abgelehnt.
do
	local svc = makeService(true)
	local ok, err = svc:installPart("p1", "v1", "fremd-teil", { source = "workshop" })
	check(ok == false and err == "IncompatiblePart", "inkompatibel muss abgelehnt werden")
	local ok2, err2 = svc:installPart("p1", "v1", "unbekannt", { source = "workshop" })
	check(ok2 == false and err2 == "PartNotFound", "unbekanntes teil muss abgelehnt werden")
end

-- 5. Ausbau legt Teil zurueck und rechnet neu; leerer Slot schlaegt fehl.
do
	local svc, profiles, calls = makeService(true)
	local okInstall, _ = svc:installPart("p1", "v1", "zylinder-70ccm", { source = "workshop" })
	check(okInstall, "setup-einbau muss gelingen")
	local before = calls.n
	local ok, err = svc:removePart("p1", "v1", "zylinder", { source = "workshop" })
	check(ok == true, "ausbau muss gelingen, err=" .. tostring(err))
	check(profiles.p1.inventory["zylinder-70ccm"] == 1, "inventar muss zurueckgebucht sein")
	check(profiles.p1.vehicles.v1.parts["zylinder"] == nil, "slot muss leer sein")
	check(calls.n == before + 1, "stats nach ausbau neu berechnen")
	local ok2, err2 = svc:removePart("p1", "v1", "zylinder", { source = "workshop" })
	check(ok2 == false and err2 == "SlotEmpty", "leerer slot muss fehlschlagen")
end

-- 6. Lackierung nur aktiv, atomar, valide Farbe.
do
	local svc, profiles, _ = makeService(true)
	local ok, err = svc:paint("p1", "v1", { surface = "tank", color = "#00FF00" }, { source = "workshop" })
	check(ok == true, "lackierung muss gelingen, err=" .. tostring(err))
	check(profiles.p1.vehicles.v1.colors["tank"] == "#00FF00", "farbe muss gesetzt sein")
	local okBad, errBad = svc:paint("p1", "v1", { surface = "tank", color = "rot" }, { source = "workshop" })
	check(okBad == false and errBad == "InvalidColor", "ungueltige farbe ablehnen")
	check(profiles.p1.vehicles.v1.colors["tank"] == "#00FF00", "fehlversuch darf farbe nicht aendern")
end

-- 7. Fremdes Fahrzeug / fehlendes Profil.
do
	local svc = makeService(true)
	local ok, err = svc:installPart("p2", "v1", "zylinder-70ccm", { source = "workshop" })
	check(ok == false and err == "ProfileNotFound", "fehlendes profil ablehnen")
	local ok2, err2 = svc:installPart("p1", "vX", "zylinder-70ccm", { source = "workshop" })
	check(ok2 == false and err2 == "VehicleNotOwned", "fremdes fahrzeug ablehnen")
end

print("WorkshopService.spec: all assertions passed")
