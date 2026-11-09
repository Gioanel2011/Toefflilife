--!strict
-- ToeffliTal Server Bootstrap: integriert alle Gameplay-Systeme.
-- Reihenfolge: Config/Protokoll -> Remotes -> Profile -> Services ->
-- Router -> Welt -> Spielerbeitritt/Spawn -> Herunterfahren.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServicesFolder = ServerScriptService:WaitForChild("Services")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlayerDataSchema = require(Shared:WaitForChild("data"):WaitForChild("PlayerDataSchema"))
local RemoteProtocol = require(Shared:WaitForChild("net"):WaitForChild("RemoteProtocol"))

local ServerRoot = script.Parent
local ProfileService = require(ServerRoot:WaitForChild("services"):WaitForChild("ProfileService"))
local RequestRouter = require(ServerRoot:WaitForChild("net"):WaitForChild("RequestRouter"))
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

-- ServicesFolder/GameConfig werden für Rojo-Mapping und Balancing-Checks referenziert.
local _Anchor: Instance? = ServicesFolder
local _MaxPlayers: number = GameConfig.MAX_PLAYERS :: any

local remotes: { [string]: Instance } = {}
local connections: { RBXScriptConnection } = {}
local shuttingDown = false
-- Echte Economy-Instanz (nicht das Modul), damit Lieferungen serverseitig
-- genau einmal gutgeschrieben werden.
local economyService: any = nil

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

-- 3-5. Services in Abhängigkeitsreihenfolge initialisieren und Router verdrahten.
local function setupServices(netFolder: Folder): ()
	callOptional(ProfileService, "init")
	callOptional(EconomyService, "init", { profiles = ProfileService })
	callOptional(VehicleService, "init", { profiles = ProfileService, economy = EconomyService })
	callOptional(MissionService, "init", { profiles = ProfileService, economy = EconomyService })
	local garageAnchors = collectGarageAnchorIds()
	assert(
		#garageAnchors == 15,
		string.format("GarageService erwartet 15 Weltanker, gefunden: %d", #garageAnchors)
	)
	callOptional(GarageService, "init", { profiles = ProfileService, anchors = garageAnchors })
	callOptional(WorkshopService, "init", {
		profiles = ProfileService,
		economy = EconomyService,
		garage = GarageService,
	})
	callOptional(ShopService, "init", { profiles = ProfileService, economy = EconomyService })
	callOptional(DynoService, "init", { profiles = ProfileService, garage = GarageService })
	callOptional(FuelService, "init", { profiles = ProfileService, economy = EconomyService })

	-- Echte Economy-Instanz für serverseitige Gutschriften.
	economyService = EconomyService.new()

	-- Der Router erwartet eine tabellenbasierte Spielerzuordnung; echte Player
	-- sind userdata. Darum läuft pro UserId genau eine Aufzeichnung mit den
	-- serverseitig bekannten Werten (UserId, aktueller Character).
	local requestPlayers: { [number]: any } = {}
	local function requestPlayer(player: Player): any
		local record = requestPlayers[player.UserId]
		if record == nil then
			record = { UserId = player.UserId, Character = player.Character }
			requestPlayers[player.UserId] = record
		else
			record.Character = player.Character
		end
		return record
	end

	-- Generischer Router als echte Instanz (nicht `RequestRouter.init`, das es
	-- nicht gibt). Nicht registrierte Aktionen antworten sofort mit
	-- `unknown_action`, statt den Client hängen zu lassen.
	local genericRouter = RequestRouter.new()

	-- Fahrzeugauswahl: nur serverseitig bekannte Standardwerte aus dem
	-- versionierten Spielerschema; keine Clientwerte.
	local function vehicleSelectHandler(_player: any, payload: any): any
		local defaults = PlayerDataSchema.createDefault()
		local action = payload.action
		if action == nil or action == "getActive" then
			return {
				ok = true,
				selected = defaults.vehicles.selected,
				owned = defaults.vehicles.owned,
				cash = defaults.cash,
			}
		end
		return { ok = false, code = "unsupportedAction" }
	end
	genericRouter:register("VehicleSelect", vehicleSelectHandler)

	-- Guthabenabfrage: ausschliesslich das eigene Konto.
	local function economyGetHandler(player: any, _payload: any): any
		local balance = 0
		if economyService ~= nil then
			balance = economyService:getBalance(player.UserId)
		end
		return { ok = true, cash = balance }
	end
	genericRouter:register("EconomyGet", economyGetHandler)

	-- Alle generischen Remotes an den Router binden; die drei Delivery-Aktionen
	-- bleiben dem dedizierten Delivery-Router vorbehalten.
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
	BicycleSpawner.createForPlayer(player, CFrame.new(0, 5, 0))
end

local function onPlayerAdded(player: Player): ()
	if shuttingDown then
		return
	end
	callOptional(ProfileService, "loadPlayer", player)
	callOptional(GarageService, "assignGarage", player)
	callOptional(MissionService, "onPlayerJoined", player)
	callOptional(DeliveryService, "onPlayerJoined", player)
	spawnPlayer(player)
end

local function onPlayerRemoving(player: Player): ()
	callOptional(DeliveryService, "onPlayerLeaving", player)
	callOptional(MissionService, "onPlayerLeaving", player)
	callOptional(GarageService, "releaseGarage", player)
	callOptional(FuelService, "onPlayerLeaving", player)
	BicycleSpawner.releaseForPlayer(player)
	callOptional(ProfileService, "savePlayer", player)
	callOptional(ProfileService, "unloadPlayer", player)
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
	callOptional(RequestRouter, "shutdown")
	-- Persistenz vor Welt-Abbau: kein Datenverlust beim Herunterfahren.
	for _, player in Players:GetPlayers() do
		local ok, _ = pcall(function()
			callOptional(ProfileService, "savePlayer", player)
		end)
		if not ok then
			continue
		end
	end
	callOptional(ProfileService, "shutdown")
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
		profiles = ProfileService,
		economy = economyService,
		world = ValleyWorld,
		-- Der Vertical Slice startet nur mit dem Fahrrad. Alle aktuellen
		-- Lieferrouten (Dörfer ~450 Studs vom Dönerladen) gelten daher als
		-- Startlieferung; die Serverseite bleibt alleinige Quelle der Distanz.
		starterMaxDistance = 700,
	})
	-- 7. Spielerbeitritt, Spawn und Verlassen verdrahten.
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	-- Studio-Play-Solo: bereits verbundene Spieler nachträglich einhängen.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(shutdown)
	print("[ToeffliTal][Server] Bootstrap ready: systems integrated")
end

init()
