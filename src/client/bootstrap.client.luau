--!strict
-- ToeffliTal Client Bootstrap: verdrahtet Controller und UI in der
-- Reihenfolge Remotes -> Fahrzeugwerte -> Controller -> Terminal -> Spawn/UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteProtocol = require(Shared:WaitForChild("net"):WaitForChild("RemoteProtocol"))

local ClientRoot = script.Parent
local BicycleController = require(ClientRoot:WaitForChild("controllers"):WaitForChild("BicycleController"))
local MopedController = require(ClientRoot:WaitForChild("controllers"):WaitForChild("MopedController"))
local GrassController = require(ClientRoot:WaitForChild("controllers"):WaitForChild("GrassController"))
local ShopTerminal = require(ClientRoot:WaitForChild("ui"):WaitForChild("ShopTerminal"))
local DeliveryPrompt = require(ClientRoot:WaitForChild("ui"):WaitForChild("DeliveryPrompt"))

-- Ein Controller pro Client; verdrahtet E-Auf-/Absteigen im BicycleController.
local bicycleController = BicycleController.new()
local grassController = GrassController.new()

local deliveryPrompt: any = nil

local connections: { RBXScriptConnection } = {}

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

-- 1. Auf versionierte Remotes warten; sendet nur validierte Shop-Anfragen.
local function waitForRemotes(): Folder
	local netFolder = ReplicatedStorage:WaitForChild("ToeffliTalRemotes", 30) :: Instance
	assert(netFolder and netFolder:IsA("Folder"), "ToeffliTalRemotes missing")
	-- Protokollnamen gegen vorhandene Remotes prüfen, ohne Clientwerte zu vertrauen.
	local expected: { string }? = nil
	local listFn = getModuleFn(RemoteProtocol, "listRemoteNames")
	if listFn then
		local ok, result = pcall(listFn, RemoteProtocol)
		if ok and typeof(result) == "table" then
			expected = result :: { string }
		end
	end
	if expected then
		for _, remoteName in expected do
			(netFolder :: Folder):WaitForChild(remoteName, 30)
		end
	end
	return netFolder :: Folder
end

local function requestViaRouter(netFolder: Folder, action: string, payload: any): any
	local remote = netFolder:FindFirstChild(action)
	if remote and remote:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return (remote :: RemoteFunction):InvokeServer(payload)
		end)
		if ok then
			return result
		end
	end
	return nil
end

-- 2-4. Controller mit serverseitig gelieferten Fahrzeugwerten starten.
local function setupControllers(netFolder: Folder): ()
	-- Fahrzeugauswahl und Werte kommen ausschliesslich vom Server.
	local vehicleSnapshot = requestViaRouter(netFolder, "VehicleSelect", { action = "getActive" })
	callOptional(MopedController, "init", {
		remotes = netFolder,
		vehicle = vehicleSnapshot,
		onFuelEmpty = function()
			requestViaRouter(netFolder, "FuelRefill", { action = "requestRescue" })
		end,
	})
	bicycleController:Start()
	callOptional(MopedController, "start")
	grassController:Start()
end

-- Laptop-Terminal: nur Katalog/Bestellung, kein Einbau oder Lackierung.
local function setupShopTerminal(netFolder: Folder): ()
	callOptional(ShopTerminal, "init", {
		onCatalog = function()
			return requestViaRouter(netFolder, "ShopCatalog", { action = "list" })
		end,
		onBuy = function(partId: string)
			return requestViaRouter(netFolder, "ShopBuy", { action = "buy", partId = partId })
		end,
	})
end

-- Döner-Lieferprompt: kleine, kontrastreiche UI ohne E-Tastenbindung.
local function setupDeliveryPrompt(netFolder: Folder): ()
	local client = {
		request = function(_self: any, action: string, payload: any): any
			return requestViaRouter(netFolder, action, payload)
		end,
		getVehicleType = function(): string
			if bicycleController.IsMounted and bicycleController:IsMounted() then
				return "bicycle"
			end
			return "moped"
		end,
	}
	deliveryPrompt = DeliveryPrompt.new(client)
	local playerGui: Instance? = nil
	if localPlayer ~= nil then
		local player = localPlayer :: Player
		playerGui = player:FindFirstChild("PlayerGui")
		if playerGui == nil then
			playerGui = player:WaitForChild("PlayerGui", 10)
		end
	end
	if playerGui ~= nil then
		callOptional(deliveryPrompt, "buildGui", playerGui)
	end
	callOptional(deliveryPrompt, "open")
end

local function onCharacterAdded(character: Model): ()
	-- Spawn: Controller an neuem Charakter einhängen, UI-Zustand zurücksetzen.
	bicycleController:OnCharacterAdded(character)
	callOptional(MopedController, "onCharacterAdded", character)
	callOptional(ShopTerminal, "onCharacterAdded", character)
	if deliveryPrompt ~= nil then
		callOptional(deliveryPrompt, "onCharacterAdded", character)
	end
end

local function watchSpawn(): ()
	if localPlayer == nil then
		return
	end
	local player = localPlayer :: Player
	local existing = player.Character
	if existing then
		task.spawn(onCharacterAdded, existing)
	end
	table.insert(connections, player.CharacterAdded:Connect(onCharacterAdded))
end

local function shutdown(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	callOptional(ShopTerminal, "destroy")
	if deliveryPrompt ~= nil then
		callOptional(deliveryPrompt, "destroy")
	end
	callOptional(MopedController, "stop")
	grassController:Stop()
	bicycleController:Stop()
end

local function init(): ()
	local netFolder = waitForRemotes()
	setupControllers(netFolder)
	setupShopTerminal(netFolder)
	setupDeliveryPrompt(netFolder)
	watchSpawn()
	if localPlayer then
		-- Sauberes Verlassen: Controller stoppen, keine offenen Requests.
		table.insert(
			connections,
			(localPlayer :: Player).AncestryChanged:Connect(function()
				if not (localPlayer :: Player):IsDescendantOf(game) then
					shutdown()
				end
			end)
		)
	end
	local name = "unknown"
	if localPlayer then
		name = (localPlayer :: Player).Name
	end
	print("[ToeffliTal][Client] Bootstrap ready for " .. name .. ": controllers + terminal wired")
end

init()
