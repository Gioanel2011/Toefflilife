--!strict
-- ToeffliTal Server Bootstrap: integriert alle Gameplay-Systeme.
-- Reihenfolge: Config/Protokoll -> Remotes -> Profile -> Services ->
-- Router -> Welt -> Spielerbeitritt/Spawn -> Herunterfahren.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServicesFolder = ServerScriptService:WaitForChild("Services")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlayerDataSchema = require(Shared:WaitForChild("data"):WaitForChild("PlayerDataSchema"))
local VehicleCatalog = require(Shared:WaitForChild("data"):WaitForChild("VehicleCatalog"))
local PartsCatalog = require(Shared:WaitForChild("data"):WaitForChild("PartsCatalog"))
local RemoteProtocol = require(Shared:WaitForChild("net"):WaitForChild("RemoteProtocol"))

local ServerRoot = script.Parent
local ProfileService = require(ServerRoot:WaitForChild("services"):WaitForChild("ProfileService"))
local ProfileAdapter = require(ServerRoot:WaitForChild("services"):WaitForChild("ProfileAdapter"))
local PlayerStore = require(ServerRoot:WaitForChild("services"):WaitForChild("PlayerStore"))
local GameplayHandlers = require(ServerRoot:WaitForChild("services"):WaitForChild("GameplayHandlers"))
local RequestRouter = require(ServerRoot:WaitForChild("net"):WaitForChild("RequestRouter"))
local PlayerIds = require(ServerRoot:WaitForChild("net"):WaitForChild("PlayerIds"))
local EconomyService = require(ServerRoot:WaitForChild("services"):WaitForChild("EconomyService"))
local VehicleService = require(ServerRoot:WaitForChild("services"):WaitForChild("VehicleService"))
local MissionService = require(ServerRoot:WaitForChild("services"):WaitForChild("MissionService"))
local DeliveryService = require(ServerRoot:WaitForChild("services"):WaitForChild("DeliveryService"))
local GarageService = require(ServerRoot:WaitForChild("services"):WaitForChild("GarageService"))
local WorkshopService = require(ServerRoot:WaitForChild("services"):WaitForChild("WorkshopService"))
local ShopService = require(ServerRoot:WaitForChild("services"):WaitForChild("ShopService"))
local DynoService = require(ServerRoot:WaitForChild("services"):WaitForChild("DynoService"))
local FuelService = require(ServerRoot:WaitForChild("services"):WaitForChild("FuelService"))
local ValleyWorld = require(ServerRoot:WaitForChild("world"):WaitForChild("ValleyWorld"))
local WorldLayout = require(ServerRoot:WaitForChild("world"):WaitForChild("WorldLayout"))
local BicycleSpawner = require(ServerRoot:WaitForChild("vehicle"):WaitForChild("BicycleSpawner"))
local MopedSpawner = require(ServerRoot:WaitForChild("vehicle"):WaitForChild("MopedSpawner"))

-- ServicesFolder/GameConfig werden für Rojo-Mapping und Balancing-Checks referenziert.
local _Anchor: Instance? = ServicesFolder
local _MaxPlayers: number = GameConfig.MAX_PLAYERS :: any

local remotes: { [string]: Instance } = {}
local connections: { RBXScriptConnection } = {}
local shuttingDown = false
-- Studio-Mehrclient vergibt negative UserIds (-1..-8). Nur in Studio werden
-- sie auf einen reservierten positiven Bereich abgebildet; der Live-Server
-- bleibt bei der strengen Pruefung. Alle Services und der Router erhalten
-- dieselbe kanonische ID.
local allowSimulatedPlayers = RunService:IsStudio()
-- Abnahme-Modus: Studio zaehlt immer, eine veroeffentlichte Abnahme-Welt setzt
-- `ReplicatedStorage:SetAttribute("AcceptanceMode", true)`. Nur dann gibt es
-- Testguthaben und den `/buy`-Chatbefehl; Live bleibt unveraendert.
local acceptanceMode = RunService:IsStudio()
	or ReplicatedStorage:GetAttribute("AcceptanceMode") == true
local ACCEPTANCE_GRANT_CASH = 5000

-- Echte Service-Instanzen (nicht die Module), damit Profile, Guthaben und
-- Spielerzustand serverseitig zusammenlaufen.
local economyService: any = nil
local profileService: any = nil
local playerStore: any = nil
local vehicleServiceInst: any = nil
local fuelServiceInst: any = nil
local dynoServiceInst: any = nil
local transactionCounter = 0
-- Kanonische UserId -> echte Player-Instanz. Nur so kann `onVehicleOwned`
-- ein gekauftes Mofa beim Kaeufer spawnen, obwohl der Router kanonische IDs
-- verwendet.
local playersByCanonicalId: { [number]: Player } = {}

local function canonicalUserId(player: Player): number?
	return PlayerIds.canonical(player.UserId, allowSimulatedPlayers)
end

-- Fuer Services, die nur die UserId benoetigen (z. B. GarageService).
local function servicePlayer(player: Player): any
	local userId = canonicalUserId(player)
	if userId == nil then
		return player
	end
	return { UserId = userId }
end

local function getModuleFn(module: any, name: string): any
	local fn = (module :: any)[name]
	if typeof(fn) == "function" then
		return fn
	end
	return nil
end

local function callOptional(module: any, name: string, ...: any): any
	local fn = getModuleFn(module, name)
	if fn then
		return (fn :: any)(module, ...)
	end
	return nil
end

-- 15 Weltanker (Garage_01..Garage_15) aus dem Layout: identische Quelle wie
-- GarageWorldBuilder. Der Service erhaelt damit exakt die gebauten Anker,
-- bevor Spieler beitreten. Es gibt keine Besitzerfarben und keine
-- clientseitige Berechtigungspruefung.
local function collectGarageAnchorIds(): { string }
	local anchors: { string } = {}
	for _, anchor in WorldLayout.getGarageAnchors() do
		if type(anchor) == "table" and type(anchor.id) == "string" then
			table.insert(anchors, anchor.id)
		end
	end
	return anchors
end

-- 1-2. Remotes aus dem versionierten Protokoll erzeugen.
local function setupRemotes(): Folder
	local folder = ReplicatedStorage:FindFirstChild("ToeffliTalRemotes")
	local netFolder: Folder
	if folder and folder:IsA("Folder") then
		netFolder = folder
	else
		netFolder = Instance.new("Folder")
		netFolder.Name = "ToeffliTalRemotes"
		netFolder.Parent = ReplicatedStorage
	end
	local names: { string } = {}
	local listFn = getModuleFn(RemoteProtocol, "listRemoteNames")
	if listFn then
		local ok, result = pcall(listFn, RemoteProtocol)
		if ok and typeof(result) == "table" then
			names = result :: { string }
		end
	end
	if #names == 0 then
		names = {
			"EconomyGet",
			"EconomyTransfer",
			"VehicleBuy",
			"VehicleSelect",
			"MissionProgress",
			"DeliveryOrder",
			"DeliveryPickup",
			"DeliveryDeliver",
			"GarageEnter",
			"WorkshopInstall",
			"WorkshopPaint",
			"ShopCatalog",
			"ShopBuy",
			"DynoRun",
			"FuelRefill",
		}
	end
	for _, remoteName in names do
		local existing = netFolder:FindFirstChild(remoteName)
		if existing == nil then
			local remote = Instance.new("RemoteFunction")
			remote.Name = remoteName
			remote.Parent = netFolder
			remotes[remoteName] = remote
		else
			remotes[remoteName] = existing
		end
	end
	return netFolder
end

-- Produktion: DataStore. Studio/Test: In-Memory, damit Play Solo ohne
-- API-Zugriff deterministisch bleibt. Fehler fallen auf In-Memory zurueck.
local function buildProfileAdapter(): any
	if RunService:IsStudio() then
		return ProfileAdapter.memory()
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("ToeffliTalProfiles_v1")
	end)
	if not ok or store == nil then
		warn("[ToeffliTal][Server] DataStore nicht verfuegbar; Profile bleiben session-lokal")
		return ProfileAdapter.memory()
	end
	return ProfileAdapter.dataStore(store)
end

local function playerPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	if player == nil or player.Character == nil then
		return nil
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function garageAnchorPosition(garageId: string): Vector3?
	for _, anchor in WorldLayout.getGarageAnchors() do
		if anchor.id == garageId then
			local point = anchor.position
			return Vector3.new(point.x, point.y, point.z)
		end
	end
	return nil
end

-- Echte serverseitige Naehekontrolle fuer die eigene Garage. Kein Clientwert.
local function isNearOwnGarage(userId: any): boolean
	local numericId = tonumber(userId)
	if numericId == nil then
		return false
	end
	local garageId = GarageService.getGarage(numericId)
	if garageId == nil then
		return false
	end
	local anchor = garageAnchorPosition(garageId)
	local position = playerPosition(numericId)
	if anchor == nil or position == nil then
		return false
	end
	return (position - anchor).Magnitude <= 24
end

local function isNearStore(_userId: any): boolean
	-- Es gibt noch kein gebautes Toeffli-Ladengebaeude; Bestellungen laufen
	-- deshalb ausschliesslich ueber das Laptop-Terminal. Kein Clientwert.
	return false
end

local function isOwnerOfVehicleKey(userId: any, vehicleKey: any): boolean
	if type(vehicleKey) ~= "string" then
		return false
	end
	local prefix = tostring(userId) .. ":"
	if string.sub(vehicleKey, 1, #prefix) ~= prefix then
		return false
	end
	local vehicleId = string.sub(vehicleKey, #prefix + 1)
	if playerStore == nil then
		return false
	end
	return playerStore:owns(userId, vehicleId)
end

local function nextTransactionId(userId: number, kind: string): string
	transactionCounter += 1
	return string.format("%s:%s:%d:%d", kind, tostring(userId), os.time(), transactionCounter)
end

-- Nur fuer Studio/Abnahme: Testkauf per Chat. Der Befehl ruft denselben
-- serverseitigen VehicleBuy-Handler auf wie der Remote; Preis, Besitz und
-- Guthaben bleiben serverseitig. Ausserhalb des Abnahme-Modus wird nichts
-- verbunden.
local acceptanceRouter: any = nil
local acceptancePlayerFor: any = nil
local acceptanceChatConnections: { [number]: RBXScriptConnection } = {}
local acceptanceLastCommand: { [number]: string } = {}
local acceptanceLastCommandAt: { [number]: number } = {}

local function acceptancePurchase(player: Player, vehicleId: string): ()
	if acceptanceRouter == nil or acceptancePlayerFor == nil then
		return
	end
	local response = acceptanceRouter:handle(acceptancePlayerFor(player), "VehicleBuy", {
		vehicleId = vehicleId,
	})
	local data: any = nil
	if type(response) == "table" then
		data = response.data
	end
	if type(data) == "table" and data.ok == true then
		local cash = data.cash
		if type(cash) ~= "number" then
			cash = -1
		end
		print(string.format(
			"[ToeffliTal][Abnahme] %s kaufte %s; Guthaben: %d",
			player.Name,
			vehicleId,
			cash
		))
	else
		local code = "unknown"
		if type(data) == "table" and type(data.code) == "string" then
			code = data.code
		end
		print(string.format(
			"[ToeffliTal][Abnahme] Kauf von %s fuer %s abgelehnt: %s",
			vehicleId,
			player.Name,
			code
		))
	end
end

local function onAcceptanceChat(player: Player, message: any): ()
	if type(message) ~= "string" then
		return
	end
	local vehicleId = string.match(message, "^%s*/buy%s+(%S+)%s*$")
	if vehicleId == nil then
		return
	end
	-- Legacy-Chat und TextChatService koennen beide feuern; dieselbe Eingabe
	-- innerhalb einer Sekunde wird nur einmal ausgefuehrt.
	local now = os.clock()
	local lastAt = acceptanceLastCommandAt[player.UserId]
	if
		lastAt ~= nil
		and now - lastAt < 1
		and acceptanceLastCommand[player.UserId] == vehicleId
	then
		return
	end
	acceptanceLastCommand[player.UserId] = vehicleId
	acceptanceLastCommandAt[player.UserId] = now
	if VehicleCatalog.get(vehicleId) == nil then
		print(string.format(
			"[ToeffliTal][Abnahme] Unbekanntes Fahrzeug: %s",
			vehicleId
		))
		return
	end
	acceptancePurchase(player, vehicleId)
end

local function bindAcceptanceTextChat(): ()
	if not acceptanceMode then
		return
	end
	local ok, connection = pcall(function()
		return game:GetService("TextChatService").MessageReceived:Connect(function(message: any)
			local source = message.TextSource
			if source == nil then
				return
			end
			local player = Players:GetPlayerByUserId(source.UserId)
			if player == nil then
				return
			end
			onAcceptanceChat(player, message.Text)
		end)
	end)
	if ok and connection ~= nil then
		table.insert(connections, connection :: RBXScriptConnection)
	end
end

local function bindAcceptanceChat(player: Player): ()
	if not acceptanceMode or acceptanceRouter == nil then
		return
	end
	local existing = acceptanceChatConnections[player.UserId]
	if existing ~= nil then
		existing:Disconnect()
	end
	local connection = player.Chatted:Connect(function(message: string)
		onAcceptanceChat(player, message)
	end)
	acceptanceChatConnections[player.UserId] = connection
	table.insert(connections, connection)
end

local function unbindAcceptanceChat(player: Player): ()
	local connection = acceptanceChatConnections[player.UserId]
	if connection ~= nil then
		connection:Disconnect()
		acceptanceChatConnections[player.UserId] = nil
	end
	acceptanceLastCommand[player.UserId] = nil
	acceptanceLastCommandAt[player.UserId] = nil
end

local function registerVehicle(userId: number, vehicleId: string, spawnNow: boolean?): ()
	if playerStore == nil or fuelServiceInst == nil or dynoServiceInst == nil then
		return
	end
	local definition = VehicleCatalog.get(vehicleId)
	if definition == nil then
		return
	end
	local vehicleKey = playerStore:vehicleKey(userId, vehicleId)
	fuelServiceInst:RegisterVehicle(vehicleKey, userId, {
		modelId = vehicleId,
		kind = definition.Class,
		hasEngine = definition.Fuel.HasEngine,
		tankVolume = definition.Fuel.TankLiters,
	})
	local record = playerStore:workshopVehicle(userId, vehicleId)
	local parts: any = {}
	if record ~= nil then
		parts = record.parts
	end
	dynoServiceInst:RegisterVehicle(vehicleKey, userId, {
		id = vehicleId,
		modelId = vehicleId,
		kind = definition.Class,
		hasEngine = definition.Fuel.HasEngine,
		physics = definition.Physics,
	}, parts)

	-- Nur echte Mofas erhalten ein Weltmodell. Beim Beitritt wird bewusst
	-- spaeter gespawnt, wenn der Charakter sicher existiert.
	if spawnNow ~= false and definition.Class == "moped" then
		local player = playersByCanonicalId[userId]
		if player ~= nil then
			MopedSpawner.createForPlayer(player, vehicleId, userId)
		end
	end
end

local function registerOwnedVehicles(userId: number): ()
	for _, vehicleId in ipairs(playerStore:owned(userId)) do
		registerVehicle(userId, vehicleId, false)
	end
end

local function spawnOwnedMopeds(player: Player): ()
	if playerStore == nil then
		return
	end
	local userId = canonicalUserId(player)
	if userId == nil then
		return
	end
	for _, vehicleId in ipairs(playerStore:owned(userId)) do
		if VehicleCatalog.isMoped(vehicleId) then
			MopedSpawner.createForPlayer(player, vehicleId, userId)
		end
	end
end

-- 3-5. Services in Abhängigkeitsreihenfolge initialisieren und Router verdrahten.
local function setupServices(netFolder: Folder): ()
	profileService = ProfileService.new(buildProfileAdapter(), PlayerDataSchema)
	economyService = EconomyService.new()

	local garageAnchors = collectGarageAnchorIds()
	assert(
		#garageAnchors == 15,
		string.format("GarageService erwartet 15 Weltanker, gefunden: %d", #garageAnchors)
	)
	GarageService.init({ anchors = garageAnchors })

	playerStore = PlayerStore.new({
		profiles = profileService,
		economy = economyService,
		sessionGrantCash = if acceptanceMode then ACCEPTANCE_GRANT_CASH else 0,
	})

	-- Preise kommen ausschliesslich aus den Serverkatalogen.
	vehicleServiceInst = VehicleService.new()
	local shopCatalog: { [string]: any } = {}
	local workshopParts: { [string]: any } = {}
	for _, part in PartsCatalog.Parts do
		shopCatalog[part.id] = {
			id = part.id,
			price = part.price,
			slot = part.slot,
			models = part.compatibleModels,
		}
		workshopParts[part.id] = { slot = part.slot, models = part.compatibleModels }
	end
	local shopServiceInst = ShopService.new({
		catalog = shopCatalog,
		profiles = playerStore:getVehicleProfiles(),
		isNearStore = isNearStore,
	})
	local workshopServiceInst = WorkshopService.new({
		profiles = playerStore:getWorkshopProfiles(),
		parts = workshopParts,
		isWorkshopActive = isNearOwnGarage,
	})
	fuelServiceInst = FuelService.new({
		isOwner = isOwnerOfVehicleKey,
		isAtGasStation = function(_userId: any, _vehicleKey: any): boolean
			-- Es gibt noch keine Tankstelle in der Welt; ehrliche Ablehnung.
			return false
		end,
		debit = function(userId: any, amount: number, transactionId: string?): (boolean, string?)
			-- EconomyService rechnet in ganzen CHF; Tankkosten sind gerundet.
			local tx = transactionId
			if type(tx) ~= "string" or tx == "" then
				transactionCounter += 1
				tx = string.format("fuel:%s:%d:%d", tostring(userId), os.time(), transactionCounter)
			end
			local ok, result = economyService:debit(userId, math.ceil(amount), tx :: string)
			if not ok then
				return false, tostring(result)
			end
			return true, nil
		end,
	})
	dynoServiceInst = DynoService.new({ isOwner = isOwnerOfVehicleKey })
	local missionServiceInst = MissionService.new()

	-- Der Router erwartet eine tabellenbasierte Spielerzuordnung; echte Player
	-- sind userdata. Darum läuft pro kanonischer UserId genau eine
	-- Aufzeichnung mit den serverseitig bekannten Werten (UserId, Character).
	local requestPlayers: { [number]: any } = {}
	local function requestPlayer(player: Player): any
		local userId = canonicalUserId(player)
		if userId == nil then
			-- Ungueltige IDs bleiben unveraendert; der Router weist sie mit
			-- `invalid_player` ab, statt sie stillschweigend abzubilden.
			return { UserId = player.UserId, Character = player.Character }
		end
		local record = requestPlayers[userId]
		if record == nil then
			record = { UserId = userId, Character = player.Character }
			requestPlayers[userId] = record
		else
			record.Character = player.Character
		end
		return record
	end

	-- Generischer Router als echte Instanz. Nicht registrierte Aktionen
	-- antworten sofort mit `unknown_action`, statt den Client hängen zu lassen.
	local genericRouter = RequestRouter.new()
	GameplayHandlers.register(genericRouter, {
		playerStore = playerStore,
		vehicleService = vehicleServiceInst,
		shopService = shopServiceInst,
		workshopService = workshopServiceInst,
		garageService = GarageService,
		dynoService = dynoServiceInst,
		fuelService = fuelServiceInst,
		missionService = missionServiceInst,
		economy = economyService,
		onVehicleOwned = registerVehicle,
		nextTransactionId = nextTransactionId,
	})

	-- Alle generischen Remotes an den Router binden; die drei Delivery-Aktionen
	-- bleiben dem dedizierten Delivery-Router vorbehalten.
	if acceptanceMode then
		acceptanceRouter = genericRouter
		acceptancePlayerFor = requestPlayer
	end
	local deliveryActions = {
		[RemoteProtocol.ACTIONS.DELIVERY_ORDER] = true,
		[RemoteProtocol.ACTIONS.DELIVERY_PICKUP] = true,
		[RemoteProtocol.ACTIONS.DELIVERY_DELIVER] = true,
	}
	for remoteName, remote in remotes do
		if deliveryActions[remoteName] ~= true and remote:IsA("RemoteFunction") then
			(remote :: RemoteFunction).OnServerInvoke = function(player: Player, payload: any): any
				return genericRouter:handle(requestPlayer(player), remoteName, payload)
			end
		end
	end

	-- Lieferaufträge: ausschliesslich die drei versionierten Delivery-Aktionen
	-- laufen über einen eigenen Router, der Spieler, Payload und Rate prüft und
	-- danach an den DeliveryService delegiert. Distanz, Fahrzeugtyp, Zieladresse,
	-- Zustandswechsel und Auszahlung bleiben vollständig serverseitig.
	local deliveryRouter = RequestRouter.new()
	local deliveryBindings = {
		{ action = RemoteProtocol.ACTIONS.DELIVERY_ORDER, handler = DeliveryService.handleOrder },
		{ action = RemoteProtocol.ACTIONS.DELIVERY_PICKUP, handler = DeliveryService.handlePickup },
		{ action = RemoteProtocol.ACTIONS.DELIVERY_DELIVER, handler = DeliveryService.handleDeliver },
	}
	for _, binding in deliveryBindings do
		deliveryRouter:register(binding.action, function(player: any, payload: any): any
			return binding.handler(player, payload)
		end)
		pcall(function()
			deliveryRouter:setRateLimit(binding.action, 10, 1)
		end)
	end
	for _, binding in deliveryBindings do
		local remote = netFolder:FindFirstChild(binding.action)
		if remote ~= nil and remote:IsA("RemoteFunction") then
			(remote :: RemoteFunction).OnServerInvoke = function(player: Player, payload: any): any
				return deliveryRouter:handle(requestPlayer(player), binding.action, payload)
			end
		end
	end
end

local function spawnPlayer(player: Player): ()
	local character: Model? = player.Character
	if character == nil then
		local ok, _ = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			return
		end
	end
	callOptional(VehicleService, "onPlayerSpawned", player)
	callOptional(FuelService, "onPlayerSpawned", player)
	BicycleSpawner.createForPlayer(player)
	spawnOwnedMopeds(player)
end

local function onPlayerAdded(player: Player): ()
	if shuttingDown then
		return
	end
	local userId = canonicalUserId(player)
	if userId == nil then
		warn(string.format("[ToeffliTal][Server] Ungueltige UserId: %s", tostring(player.UserId)))
		return
	end
	playersByCanonicalId[userId] = player
	local loaded, err = pcall(function()
		playerStore:load(userId)
	end)
	if not loaded then
		warn(string.format("[ToeffliTal][Server] Profil konnte nicht geladen werden: %s", tostring(err)))
	end
	bindAcceptanceChat(player)
	callOptional(GarageService, "assignGarage", servicePlayer(player))
	registerOwnedVehicles(userId)
	spawnPlayer(player)
	-- Respawn: Fahrzeuge erst setzen, wenn der neue Charakter-Root existiert;
	-- so landet der Boden-Raycast zuverlaessig auf dem echten Grund.
	table.insert(connections, player.CharacterAdded:Connect(function()
		task.defer(function()
			if player.Parent == nil then
				return
			end
			BicycleSpawner.createForPlayer(player)
			spawnOwnedMopeds(player)
		end)
	end))
end

local function onPlayerRemoving(player: Player): ()
	local userId = canonicalUserId(player)
	unbindAcceptanceChat(player)
	callOptional(GarageService, "releaseGarage", servicePlayer(player))
	BicycleSpawner.releaseForPlayer(player)
	MopedSpawner.releaseForPlayer(player)
	if userId ~= nil then
		playersByCanonicalId[userId] = nil
	end
	if userId ~= nil and playerStore ~= nil then
		local ok, err = playerStore:release(userId)
		if not ok then
			warn(string.format("[ToeffliTal][Server] Profil konnte nicht gespeichert werden: %s", tostring(err)))
		end
	end
end

local function shutdown(): ()
	if shuttingDown then
		return
	end
	shuttingDown = true
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(acceptanceChatConnections)
	table.clear(acceptanceLastCommand)
	table.clear(acceptanceLastCommandAt)
	-- Persistenz vor Welt-Abbau: kein Datenverlust beim Herunterfahren.
	if playerStore ~= nil then
		local saved, failed = playerStore:saveAll()
		print(string.format("[ToeffliTal][Server] Profile gespeichert: %d, fehlgeschlagen: %d", saved, failed))
	end
	callOptional(ValleyWorld, "cleanup")
	print("[ToeffliTal][Server] Shutdown complete")
end

local function init(): ()
	local netFolder = setupRemotes()
	setupServices(netFolder)
	-- 6. Welt erst nach Services bauen, damit Lieferpunkte/Garagenanker existieren.
	ValleyWorld.build(workspace)
	-- 6b. Lieferpunkte entstehen mit der Welt: DeliveryService danach konfigurieren.
	DeliveryService.init({
		profiles = profileService,
		economy = economyService,
		world = ValleyWorld,
		-- Der Vertical Slice startet nur mit dem Fahrrad. Alle aktuellen
		-- Lieferrouten (Dörfer ~450 Studs vom Dönerladen) gelten daher als
		-- Startlieferung; die Serverseite bleibt alleinige Quelle der Distanz.
		starterMaxDistance = 700,
	})
	-- 7. Spielerbeitritt, Spawn und Verlassen verdrahten.
	bindAcceptanceTextChat()
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	-- Studio-Play-Solo: bereits verbundene Spieler nachträglich einhängen.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(shutdown)
	if acceptanceMode then
		print(string.format(
			"[ToeffliTal][Abnahme] aktiv: Testguthaben %d CHF, Chatbefehl /buy <vehicleId>",
			ACCEPTANCE_GRANT_CASH
		))
	end
	print("[ToeffliTal][Server] Bootstrap ready: systems integrated")
end

init()
