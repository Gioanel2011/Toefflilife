--!strict
-- GrassController: performante clientseitige Grasbewegung.
-- Animiert nur nahe `ToeffliGrass`-Chunks gebuendelt mit fester maximaler
-- Update-Rate. Reine Sway-Funktion `swayOffset` plus Chunk-Auswahl
-- `selectActiveChunks` / `isChunkInRange` sind ohne Roblox-Laufzeit testbar.
-- Die Laufzeit aendert keine Server-CFrames (nur lokale Visual-Offsets),
-- keine Physik (Anchored/Collide bleiben unberuehrt) und nutzt genau einen
-- Heartbeat-Callback statt einem Callback pro Grashalm. Keine globalen Variablen.

local GrassController = {}
GrassController.__index = GrassController

-- Tag muss mit dem Server-Builder uebereinstimmen (Task 28).
GrassController.TAG_NAME = "ToeffliGrass"
-- Feste maximale Update-Rate: ein Sammel-Update alle 0.15 s (~6.7 Hz).
GrassController.UPDATE_INTERVAL = 0.15
-- Begrenzung aktiver Chunks: schuetzt vor Frame-Einbruechen bei 15 Spielern.
GrassController.MAX_ACTIVE_CHUNKS = 24
-- Aktivierungsdistanz (Studs): nur nahe Chunks werden animiert.
GrassController.NEAR_DISTANCE = 120
-- Deaktivierungsdistanz (Studs): Hysterese gegen Flackern an der Grenze.
GrassController.FAR_DISTANCE = 150
-- Kurze, fahrneutrale Bewegung (Radiant, Tilt um Z).
GrassController.SWAY_AMPLITUDE = 0.08
-- Sway-Geschwindigkeit (Radiant pro Sekunde).
GrassController.SWAY_FREQUENCY = 1.6

export type GrassController = typeof(setmetatable(
	{} :: {
		_running: boolean,
		_time: number,
		_accum: number,
		_connection: RBXScriptConnection?,
		_baseFrames: { [BasePart]: CFrame },
		_activeChunks: { [string]: boolean },
	},
	GrassController
))

local function distance2D(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function getGame(): any
	local ok, value = pcall(function(): any
		return (game :: any)
	end)
	if ok then
		return value
	end
	return nil
end

-- Reine, testbare Sway-Funktion: deterministisch, endlich, begrenzt.
function GrassController.swayOffset(seed: number, time: number): number
	if seed ~= seed or time ~= time then
		return 0
	end
	if math.abs(seed) >= 1000000 or math.abs(time) >= 1000000 then
		seed = seed % 100000
		time = time % 100000
	end
	return math.sin(time * GrassController.SWAY_FREQUENCY + seed * 0.37) * GrassController.SWAY_AMPLITUDE
end

-- Hysterese: nahe Chunks starten, aktive bleiben bis zur FAR-Distanz an.
function GrassController.isChunkInRange(distance: number, currentlyActive: boolean): boolean
	if distance ~= distance or distance < 0 then
		return false
	end
	if currentlyActive then
		return distance <= GrassController.FAR_DISTANCE
	end
	return distance <= GrassController.NEAR_DISTANCE
end

export type ChunkAnchor = { chunkId: string, x: number, z: number }

-- Reine Chunk-Auswahl: naechste Chunks innerhalb maxDistance, begrenzt auf
-- maxActive. Gibt Chunk-IDs nach Distanz sortiert zurueck, ohne Eingabe zu mutieren.
function GrassController.selectActiveChunks(
	playerPos: { x: number, z: number },
	chunks: { ChunkAnchor },
	maxActive: number?,
	maxDistance: number?
): { string }
	local limit = maxActive or GrassController.MAX_ACTIVE_CHUNKS
	local radius = maxDistance or GrassController.NEAR_DISTANCE
	if limit <= 0 or radius <= 0 then
		return {}
	end
	local scored: { { id: string, dist: number } } = {}
	for _, chunk in chunks do
		local dist = distance2D(playerPos.x, playerPos.z, chunk.x, chunk.z)
		if dist == dist and dist <= radius then
			scored[#scored + 1] = { id = chunk.chunkId, dist = dist }
		end
	end
	table.sort(scored, function(a, b)
		if a.dist == b.dist then
			return a.id < b.id
		end
		return a.dist < b.dist
	end)
	local result: { string } = {}
	for index = 1, math.min(limit, #scored) do
		result[#result + 1] = scored[index].id
	end
	return result
end

function GrassController.new(): GrassController
	local self = setmetatable({
		_running = false,
		_time = 0,
		_accum = 0,
		_connection = nil,
		_baseFrames = {},
		_activeChunks = {},
	}, GrassController)
	return self
end

function GrassController.IsRunning(self: GrassController): boolean
	return self._running
end

function GrassController.GetActiveChunks(self: GrassController): { string }
	local result: { string } = {}
	for chunkId, _ in self._activeChunks do
		result[#result + 1] = chunkId
	end
	table.sort(result)
	return result
end

-- Stellt alle zwischengespeicherten Basis-CFrames wieder her (Chunk pausiert).
function GrassController._restoreAll(self: GrassController): ()
	for part, base in self._baseFrames do
		local ok, _ = pcall(function()
			(part :: BasePart).CFrame = base
		end)
		if not ok then
			continue
		end
	end
	table.clear(self._baseFrames)
	table.clear(self._activeChunks)
end

function GrassController.Start(self: GrassController): boolean
	if self._running then
		return true
	end
	local gameRef = getGame()
	if gameRef == nil then
		-- Lune/Testumgebung ohne Roblox: kein Laufzeit-Start, aber API bleibt nutzbar.
		return false
	end
	local ok, runService = pcall(function(): any
		return gameRef:GetService("RunService")
	end)
	if not ok or runService == nil then
		return false
	end
	self._running = true
	self._accum = 0
	-- Genau ein Sammel-Callback (Heartbeat), kein Callback pro Grashalm.
	self._connection = (runService :: RunService).Heartbeat:Connect(function(dt: number)
		self:_onHeartbeat(dt)
	end)
	return true
end

function GrassController._onHeartbeat(self: GrassController, dt: number): ()
	if not self._running then
		return
	end
	local clamped = math.clamp(dt, 0, 0.5)
	self._accum += clamped
	if self._accum < GrassController.UPDATE_INTERVAL then
		return
	end
	self._accum = 0
	self._time += GrassController.UPDATE_INTERVAL
	self:updateNow()
end

-- Ein gebuendeltes Update: nur nahe Chunks animieren, ferne pausieren.
function GrassController.updateNow(self: GrassController): ()
	local gameRef = getGame()
	if gameRef == nil then
		return
	end
	local okPlayers, players = pcall(function(): any
		return gameRef:GetService("Players")
	end)
	local okTags, collectionService = pcall(function(): any
		return gameRef:GetService("CollectionService")
	end)
	if not okPlayers or not okTags or players == nil or collectionService == nil then
		return
	end
	local localPlayer = (players :: Players).LocalPlayer
	if localPlayer == nil then
		return
	end
	local character = localPlayer.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not (root :: Instance):IsA("BasePart") then
		return
	end
	local playerPos = (root :: BasePart).Position

	local tagged: { Instance }
	do
		local ok, result = pcall(function(): any
			return (collectionService :: CollectionService):GetTagged(GrassController.TAG_NAME)
		end)
		if not ok or typeof(result) ~= "table" then
			return
		end
		tagged = result :: { Instance }
	end

	-- Chunks buendeln: ein Eintrag je Chunk-ID mit Ankerposition.
	local chunkAnchors: { [string]: { x: number, z: number } } = {}
	local modelsByChunk: { [string]: { Model } } = {}
	for _, instance in tagged do
		if (instance :: Instance):IsA("Model") then
			local model = instance :: Model
			local chunkAttr = model:GetAttribute("ChunkId")
			if typeof(chunkAttr) == "string" and (chunkAttr :: string) ~= "" then
				local chunkId = chunkAttr :: string
				local pivotOk, pivot = pcall(function(): any
					return model:GetPivot()
				end)
				if pivotOk and pivot ~= nil then
					local pos = (pivot :: CFrame).Position
					if chunkAnchors[chunkId] == nil then
						chunkAnchors[chunkId] = { x = pos.X, z = pos.Z }
					end
					if modelsByChunk[chunkId] == nil then
						modelsByChunk[chunkId] = {}
					end
					table.insert(modelsByChunk[chunkId], model)
				end
			end
		end
	end

	local anchors: { ChunkAnchor } = {}
	for chunkId, anchor in chunkAnchors do
		anchors[#anchors + 1] = { chunkId = chunkId, x = anchor.x, z = anchor.z }
	end
	local wanted = GrassController.selectActiveChunks(
		{ x = playerPos.X, z = playerPos.Z },
		anchors
	)
	local wantedSet: { [string]: boolean } = {}
	for _, chunkId in wanted do
		wantedSet[chunkId] = true
	end
	self._activeChunks = wantedSet

	-- Ferne Chunks pausieren: Basis-CFrame wiederherstellen, danach ignorieren.
	-- Aktive Chunks: Tilt um die gespeicherte Basis legen (clientseitig visual only).
	for chunkId, models in modelsByChunk do
		if wantedSet[chunkId] then
			for _, model in models do
				local seedAttr = model:GetAttribute("GrassSeed")
				local seed = if typeof(seedAttr) == "number" then (seedAttr :: number) else 0
				local descendants: { Instance } = model:GetDescendants()
				for _, descendant in descendants do
					if descendant:IsA("BasePart") then
						local blade = descendant :: BasePart
						if self._baseFrames[blade] == nil then
							local ok, current = pcall(function(): any
								return blade.CFrame
							end)
							if ok and current ~= nil then
								self._baseFrames[blade] = current :: CFrame
							else
								continue
							end
						end
						local base = self._baseFrames[blade]
						if base ~= nil then
							local sway = GrassController.swayOffset(seed + blade.Size.Y * 100, self._time)
							-- Nur Rotation um die Basis: keine Positions-/Physik-Aenderung,
							-- keine Auswirkung auf Fahreigenschaften.
							local applyOk, _ = pcall(function()
								blade.CFrame = (base :: CFrame) * CFrame.Angles(0, 0, sway)
							end)
							if not applyOk then
								continue
							end
						end
					end
				end
			end
		else
			for _, model in models do
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						local blade = descendant :: BasePart
						local base = self._baseFrames[blade]
						if base ~= nil then
							pcall(function()
								blade.CFrame = base
							end)
							self._baseFrames[blade] = nil
						end
					end
				end
			end
		end
	end
end

function GrassController.Stop(self: GrassController): ()
	self._running = false
	if self._connection ~= nil then
		pcall(function()
			(self._connection :: RBXScriptConnection):Disconnect()
		end)
		self._connection = nil
	end
	-- In Studio: wiederherstellen; in Lune (ohne Parts) ist die Tabelle leer.
	if getGame() ~= nil then
		self:_restoreAll()
	else
		table.clear(self._baseFrames)
		table.clear(self._activeChunks)
	end
	self._accum = 0
end

return GrassController
