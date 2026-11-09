--!strict
-- Spec für die serverseitige Profilpersistenz.
-- Ausführbar mit: lune run tests/ProfileService.spec.luau

local ProfileService = require("../src/server/services/ProfileService")
local Schema = require("../src/shared/data/PlayerDataSchema")

local function check(condition: boolean, message: string)
	assert(condition, message)
	print("OK: " .. message)
end

local function createMemoryAdapter(): any
	local adapter: any = { _store = {}, _failGet = false, _failSet = false }
	function adapter:Get(key: string): any?
		if self._failGet then
			error("Get boom")
		end
		return self._store[key]
	end
	function adapter:Set(key: string, value: any): ()
		if self._failSet then
			error("Set boom")
		end
		self._store[key] = value
	end
	return adapter
end

-- 1. Laden eines neuen Spielers erzeugt ein gültiges Default-Profil.
local adapter: any = createMemoryAdapter()
local service: any = ProfileService.new(adapter, Schema)
local fresh: any = service.load("101")
local okFresh: boolean = Schema.validate(fresh)
check(okFresh, "fresh profile validates")
check(fresh.vehicles.selected == "bicycle", "fresh profile selects bicycle")
check(Schema.isStarterDiscountAvailable(fresh), "discount available for fresh profile")
check(service.isLoaded("101"), "fresh profile is cached")
check(service.loadedCount() == 1, "one profile loaded")

-- 2. Zweites Laden gibt dieselbe Referenz zurück (kein Datenverlust im Cache).
local again: any = service.load("101")
check(again == fresh, "load returns cached reference")

-- 3. Speichern legt eine entkoppelte Kopie im Adapter ab.
fresh.cash = 50
local okSave: boolean = service.save("101")
check(okSave, "save succeeds")
check(adapter._store["101"].cash == 50, "store holds saved cash")
fresh.cash = 999
check(adapter._store["101"].cash == 50, "store keeps snapshot until next save")

-- 4. saveAll sichert mehrere Profile.
service.load("102").cash = 7
local saved: number, failed: number = service.saveAll()
check(saved == 2 and failed == 0, "saveAll persists all profiles")

-- 5. Legacy-Daten werden beim Laden migriert.
adapter._store["legacy"] = { version = 0, cash = 5 }
local migrated: any = service.load("legacy")
check(migrated.version == Schema.VERSION, "legacy profile migrates version")
local okMigrated: boolean = Schema.validate(migrated)
check(okMigrated, "migrated profile validates")

-- 6. Ungültige Daten fallen auf Defaults zurück statt abzustürzen.
adapter._store["broken"] = { version = Schema.VERSION, cash = -99 }
local fallback: any = service.load("broken")
local okFallback: boolean = Schema.validate(fallback)
check(okFallback, "invalid stored data falls back to valid profile")
check(fallback.cash == 0, "fallback resets invalid cash")

-- 7. Adapter-Fehler beim Laden führen zu Defaults ohne Absturz.
local throwingGet: any = createMemoryAdapter()
throwingGet._failGet = true
local serviceGetFail: any = ProfileService.new(throwingGet, Schema)
local defaulted: any = serviceGetFail.load("201")
local okDefaulted: boolean = Schema.validate(defaulted)
check(okDefaulted, "failing Get still yields valid default")

-- 8. Fehlgeschlagenes Speichern behält den Cache (kein Datenverlust).
local failingSet: any = createMemoryAdapter()
local serviceSetFail: any = ProfileService.new(failingSet, Schema)
serviceSetFail.load("301").cash = 42
failingSet._failSet = true
local okFail: boolean, _errFail: string? = serviceSetFail.save("301")
check(okFail == false, "failing Set reports failure")
check(serviceSetFail.get("301") ~= nil, "cache survives failed save")
check(serviceSetFail.get("301").cash == 42, "unsaved changes stay in cache")

-- 9. Parallele Speichervorgänge werden abgewiesen (Reentrancy-Guard).
local guardedAdapter: any = createMemoryAdapter()
local guardedService: any = nil
local innerResult: boolean? = nil
local innerError: string? = nil
function guardedAdapter:Get(key: string): any?
	return self._store[key]
end
function guardedAdapter:Set(key: string, value: any): ()
	innerResult, innerError = guardedService.save(key)
	self._store[key] = value
end
guardedService = ProfileService.new(guardedAdapter, Schema)
guardedService.load("401")
local outerOk: boolean = guardedService.save("401")
check(outerOk, "outer save succeeds")
check(innerResult == false, "reentrant save is rejected")
check(innerError == "already saving", "reentrant save reports guard")

-- 10. release speichert und räumt den Cache (Verlassen-Pfad).
local releaseOk: boolean = service.release("101")
check(releaseOk, "release saves on leave")
check(service.get("101") == nil, "release evicts cache")
check(adapter._store["101"].cash == 999, "release persists latest state")

-- 11. release bei Speicherfehler behält den Cache.
failingSet._failSet = true
local releaseFail: boolean = serviceSetFail.release("301")
check(releaseFail == false, "release reports store failure")
check(serviceSetFail.get("301") ~= nil, "release keeps cache on failure")

-- 12. Server-only: das Modul referenziert weder DataStoreService noch Client-Remotes.
local fsOk: boolean, fsMod: any = pcall(function(): any
	return require("@lune/fs")
end)
if fsOk then
	local source: string = fsMod.readFile("src/server/services/ProfileService.luau")
	check(string.find(source, "DataStoreService") == nil, "no direct DataStoreService usage")
	check(string.find(source, "RemoteEvent") == nil, "no client remote usage")
else
	print("SKIP: @lune/fs unavailable, server-only source check skipped")
end

print("ProfileService.spec: all assertions passed")
