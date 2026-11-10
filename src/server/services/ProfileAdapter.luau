--!strict
-- ProfileAdapter: injizierbare Persistenz-Adapter fuer ProfileService.
-- Produktion nutzt DataStore (GetAsync/SetAsync), Studio und Tests einen
-- In-Memory-Adapter. Keine Roblox-Laufzeit in `memory()`, damit die
-- Profilkette mit `lune run` testbar bleibt. Keine globalen Variablen.

local ProfileAdapter = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for key, item in pairs(value) do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy
end

-- In-Memory-Adapter; `Set` liefert true wie ein erfolgreicher DataStore-Write.
function ProfileAdapter.memory(initial: { [string]: any }?)
	local store: { [string]: any } = {}
	if initial ~= nil then
		for key, value in pairs(initial) do
			store[key] = deepCopy(value)
		end
	end
	local adapter: any = {}
	function adapter:Get(key: string): any?
		local value = store[key]
		if value == nil then
			return nil
		end
		return deepCopy(value)
	end
	function adapter:Set(key: string, value: any): boolean
		store[key] = deepCopy(value)
		return true
	end
	function adapter:snapshot(): { [string]: any }
		return store
	end
	return adapter
end

-- DataStore-Adapter; Fehler werden von ProfileService per pcall abgefangen.
function ProfileAdapter.dataStore(dataStore: any, options: any?)
	assert(type(dataStore) == "table" or type(dataStore) == "userdata", "dataStore required")
	local opts = options or {}
	local prefix: string = "player_"
	if type(opts.keyPrefix) == "string" and opts.keyPrefix ~= "" then
		prefix = opts.keyPrefix
	end
	local adapter: any = {}
	function adapter:GetAsync(key: string): any?
		return dataStore:GetAsync(prefix .. key)
	end
	function adapter:SetAsync(key: string, value: any): boolean
		dataStore:SetAsync(prefix .. key, value)
		return true
	end
	return adapter
end

return ProfileAdapter
