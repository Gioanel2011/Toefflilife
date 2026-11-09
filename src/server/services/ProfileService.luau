--!strict
-- Töffli Tal: serverseitige Profilpersistenz.
-- Server-modul: Laden, Autosave, Migration, Speichern beim Verlassen.
-- Persistenz läuft ausschliesslich über einen injizierbaren DataStore-Adapter,
-- damit der Client niemals DataStore-Aufrufe tätigt.
-- Adaptervertrag (Methoden mit Doppelpunkt aufrufen):
--   adapter:Get(userKey: string): any?
--   adapter:Set(userKey: string, profile: any): ()
-- Alternativ werden GetAsync/SetAsync akzeptiert. Fehler (throw oder
-- explizites `false` bei Set) werden als Fehlschlag zurückgegeben, der
-- Cache bleibt zur Vermeidung von Datenverlust erhalten.

local FallbackSchema = require("../../shared/data/PlayerDataSchema")

local ProfileService = {}

local function deepCopy(value: any, seen: { [any]: any }?): any
	local seenMap: { [any]: any } = seen or {}
	if type(value) ~= "table" then
		return value
	end
	if seenMap[value] ~= nil then
		return seenMap[value]
	end
	local copy: { [any]: any } = {}
	seenMap[value] = copy
	for key, item in pairs(value) do
		copy[deepCopy(key, seenMap)] = deepCopy(item, seenMap)
	end
	return copy
end

function ProfileService.new(adapter: any, schemaOverride: any?): any
	assert(type(adapter) == "table", "adapter must be a table")
	local schema: any = schemaOverride or FallbackSchema
	assert(type(schema.createDefault) == "function", "schema needs createDefault")
	assert(type(schema.validate) == "function", "schema needs validate")
	assert(type(schema.migrate) == "function", "schema needs migrate")

	local profiles: { [string]: any } = {}
	local saving: { [string]: boolean } = {}

	local function toKey(userId: any): string
		return tostring(userId)
	end

	local function fetchRaw(key: string): any
		if type(adapter.Get) == "function" then
			return adapter:Get(key)
		elseif type(adapter.GetAsync) == "function" then
			return adapter:GetAsync(key)
		else
			error("adapter needs a Get or GetAsync method")
		end
	end

	local function storeRaw(key: string, snapshot: any): any
		if type(adapter.Set) == "function" then
			return adapter:Set(key, snapshot)
		elseif type(adapter.SetAsync) == "function" then
			return adapter:SetAsync(key, snapshot)
		else
			error("adapter needs a Set or SetAsync method")
		end
	end

	local service: any = {}

	function service.load(userId: any): any
		local key = toKey(userId)
		if profiles[key] ~= nil then
			return profiles[key]
		end
		local raw: any = nil
		local fetchOk: boolean, fetched: any = pcall(function(): any
			return fetchRaw(key)
		end)
		if fetchOk then
			raw = fetched
		else
			raw = nil
		end
		local profile: any = nil
		if raw == nil then
			profile = schema.createDefault()
		else
			local migrateOk: boolean, migrated: any = pcall(function(): any
				return schema.migrate(raw)
			end)
			if migrateOk and type(migrated) == "table" then
				profile = migrated
			else
				profile = schema.createDefault()
			end
			local valid: boolean = schema.validate(profile)
			if not valid then
				profile = schema.createDefault()
			end
		end
		profiles[key] = profile
		return profile
	end

	function service.get(userId: any): any?
		return profiles[toKey(userId)]
	end

	function service.isLoaded(userId: any): boolean
		return profiles[toKey(userId)] ~= nil
	end

	function service.loadedCount(): number
		local count = 0
		for _key in pairs(profiles) do
			count += 1
		end
		return count
	end

	function service.save(userId: any): (boolean, string?)
		local key = toKey(userId)
		local profile: any = profiles[key]
		if profile == nil then
			return false, "not loaded"
		end
		if saving[key] then
			return false, "already saving"
		end
		saving[key] = true
		local snapshot: any = deepCopy(profile)
		local storeOk: boolean, storeResult: any = pcall(function(): any
			return storeRaw(key, snapshot)
		end)
		saving[key] = false
		if not storeOk then
			return false, "store failed"
		end
		if storeResult == false then
			return false, "store rejected"
		end
		return true, nil
	end

	function service.saveAll(): (number, number)
		local saved = 0
		local failed = 0
		for key in pairs(profiles) do
			local ok: boolean = service.save(key)
			if ok then
				saved += 1
			else
				failed += 1
			end
		end
		return saved, failed
	end

	function service.release(userId: any): (boolean, string?)
		local key = toKey(userId)
		if profiles[key] == nil then
			return true, nil
		end
		local ok: boolean, err: string? = service.save(userId)
		if not ok then
			return false, err
		end
		profiles[key] = nil
		saving[key] = nil
		return true, nil
	end

	function service.clear(): ()
		for key in pairs(profiles) do
			profiles[key] = nil
		end
		for key in pairs(saving) do
			saving[key] = nil
		end
	end

	function service.tick(): (number, number)
		return service.saveAll()
	end

	function service.startAutosave(intervalSeconds: number): () -> ()
		assert(type(intervalSeconds) == "number" and intervalSeconds > 0, "interval must be positive")
		local running = { value = true }
		task.spawn(function()
			while running.value do
				task.wait(intervalSeconds)
				if not running.value then
					break
				end
				service.saveAll()
			end
		end)
		return function()
			running.value = false
		end
	end

	return service
end

return ProfileService
