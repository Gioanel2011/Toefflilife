--!strict
-- MopedMountController: findet das eigene serverseitig gespawnte Mofa,
-- steuert Auf-/Absteigen per E und uebergibt Fahrwerte an den MopedController.
-- Es werden nur Modelle mit Tag `ToeffliMoped` und passendem Besitzer bewegt.
-- Preise, Besitz und Spawnposition bleiben serverseitig.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MopedController = require(script.Parent.MopedController)

local MopedMountController = {}
MopedMountController.__index = MopedMountController

local TAG_NAME = "ToeffliMoped"
local MOUNT_KEY = Enum.KeyCode.E
local MOUNT_DISTANCE = 10
local MOUNT_COOLDOWN = 0.5

export type Options = {
	onOutOfFuel: (() -> ())?,
	bicycle: any?,
}

export type MopedMountController = typeof(setmetatable(
	{} :: {
		_controller: any,
		_model: Model?,
		_seat: VehicleSeat?,
		_mountDebounceUntil: number,
		_inputBegan: RBXScriptConnection?,
		_stepped: RBXScriptConnection?,
		_destroyed: boolean,
		_onOutOfFuel: (() -> ())?,
		_bicycle: any?,
	},
	MopedMountController
))

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function findSeat(model: Model): VehicleSeat?
	local seat = model:FindFirstChild("Seat", true)
	if seat ~= nil and seat:IsA("VehicleSeat") then
		return seat
	end
	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function findDrive(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary ~= nil then
		return primary
	end
	local drive = model:FindFirstChild("Drive", true)
	if drive ~= nil and drive:IsA("BasePart") then
		return drive
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function isOwnedBy(model: Model, player: Player): boolean
	local ownerPlayer = model:GetAttribute("OwnerPlayerUserId")
	if typeof(ownerPlayer) == "number" then
		return ownerPlayer == player.UserId
	end
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function findNearestOwnedMoped(player: Player, maxDistance: number): Model?
	local root = getCharacterRoot(player)
	if root == nil then
		return nil
	end
	local nearest: Model? = nil
	local nearestDistance = maxDistance
	for _, instance in CollectionService:GetTagged(TAG_NAME) do
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
			local moped = instance :: Model
			if isOwnedBy(moped, player) then
				local drive = findDrive(moped)
				if drive ~= nil then
					local distance = (drive.Position - root.Position).Magnitude
					if distance <= nearestDistance then
						nearest = moped
						nearestDistance = distance
					end
				end
			end
		end
	end
	return nearest
end

local function attributeNumber(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

-- Fahrwerte stammen aus den serverseitig gesetzten Attributen des Modells.
-- Die Umrechnung ist reine Darstellung; keine Preise oder Besitzentscheidung.
local function buildStats(model: Model): any
	local vehicleId = model:GetAttribute("VehicleId")
	local modelId = if typeof(vehicleId) == "string" then vehicleId else "moped"
	local topSpeedKmh = attributeNumber(model, "TopSpeedKmh", 45)
	local acceleration = attributeNumber(model, "Acceleration", 6.5)
	local braking = attributeNumber(model, "Braking", 7)
	local handling = attributeNumber(model, "Handling", 7.5)
	local fuelRate = attributeNumber(model, "FuelConsumptionPerSecond", 0.005)
	return {
		modelId = modelId,
		acceleration = acceleration * 1.6,
		topSpeed = topSpeedKmh * 0.72,
		brakeForce = braking * 3,
		turnRate = handling * 0.25,
		reverseSpeed = 4,
		dragCoefficient = 0.28,
		rollingResistance = 1.6,
		fuelConsumptionPerSecond = fuelRate,
	}
end

function MopedMountController.new(options: Options?): MopedMountController
	local self = setmetatable({
		_controller = MopedController.new(),
		_model = nil,
		_seat = nil,
		_mountDebounceUntil = 0,
		_inputBegan = nil,
		_stepped = nil,
		_destroyed = false,
		_onOutOfFuel = if options ~= nil then options.onOutOfFuel else nil,
		_bicycle = if options ~= nil then options.bicycle else nil,
	}, MopedMountController)
	if self._onOutOfFuel ~= nil then
		self._controller:OnOutOfFuel(self._onOutOfFuel)
	end
	return self
end

function MopedMountController.IsMounted(self: MopedMountController): boolean
	return self._model ~= nil
end

function MopedMountController.GetSpeed(self: MopedMountController): number
	return self._controller:GetSpeed()
end

function MopedMountController.Mount(self: MopedMountController, model: Model): boolean
	local player = Players.LocalPlayer
	if player == nil or self._destroyed then
		return false
	end
	if self._model ~= nil then
		return false
	end
	if os.clock() < self._mountDebounceUntil then
		return false
	end
	local humanoid = getHumanoid(player)
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	-- Kein Doppel-Mount, wenn bereits ein Fahrrad oder Mofa kontrolliert.
	if humanoid.SeatPart ~= nil then
		return false
	end
	local root = getCharacterRoot(player)
	local drive = findDrive(model)
	local seat = findSeat(model)
	if root == nil or drive == nil or seat == nil then
		return false
	end
	if (drive.Position - root.Position).Magnitude > MOUNT_DISTANCE then
		return false
	end
	if seat.Occupant ~= nil then
		return false
	end

	self._controller:SetStats(buildStats(model))
	self._controller:SetFuelLevel(1)
	-- Sitz ist fuer Auto-Aufsitzen deaktiviert. Fuer den expliziten E-Mount
	-- freigeben und erst nach dem Absteigen wieder sperren (waehrend des
	-- Sitzens darf `Disabled` nicht umgeschaltet werden).
	seat.Disabled = false
	seat:Sit(humanoid)
	if not self._controller:Mount(seat, drive, model) then
		return false
	end
	self._controller:StartEngine()
	self._model = model
	self._seat = seat
	self._mountDebounceUntil = os.clock() + MOUNT_COOLDOWN
	return true
end

function MopedMountController.Dismount(self: MopedMountController): ()
	if self._model == nil and self._seat == nil then
		return
	end
	self._controller:Dismount()
	self._model = nil
	self._seat = nil
	self._mountDebounceUntil = os.clock() + MOUNT_COOLDOWN
end

function MopedMountController.ToggleMount(self: MopedMountController): boolean
	if self._model ~= nil then
		self:Dismount()
		return false
	end
	if os.clock() < self._mountDebounceUntil then
		return false
	end
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	local humanoid = getHumanoid(player)
	if humanoid ~= nil and humanoid.SeatPart ~= nil then
		return false
	end
	-- Der Fahrrad-Controller laeuft zuerst. Nach dessen Absteigen darf
	-- derselbe E-Druck nicht sofort das danebenstehende Mofa uebernehmen.
	if self._bicycle ~= nil and self._bicycle:IsMountCoolingDown() then
		return false
	end
	local moped = findNearestOwnedMoped(player, MOUNT_DISTANCE)
	if moped == nil then
		return false
	end
	return self:Mount(moped)
end

-- Roblox setzt Charaktere beim Beruehren automatisch auf Sitze. Uebernimmt
-- dieser Sitz zum eigenen getaggten Mofa, gilt das als aufgestiegen.
function MopedMountController._adoptAutoSeat(self: MopedMountController): ()
	-- Externes Absteigen (Sprung, Sitz zerstört) sauber übernehmen.
	if self._model ~= nil and not self._controller:IsRiding() then
		local seat = self._seat
		if seat ~= nil then
			seat.Disabled = true
		end
		self._model = nil
		self._seat = nil
	end
	if self._model ~= nil then
		return
	end
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local humanoid = getHumanoid(player)
	if humanoid == nil then
		return
	end
	local seat = humanoid.SeatPart
	if seat == nil or not seat:IsA("VehicleSeat") then
		return
	end
	local vehicleSeat = seat :: VehicleSeat
	local model = vehicleSeat:FindFirstAncestorOfClass("Model")
	if model == nil then
		return
	end
	if not isOwnedBy(model, player) or not CollectionService:HasTag(model, TAG_NAME) then
		return
	end
	local drive = findDrive(model)
	if drive == nil then
		return
	end

	self._controller:SetStats(buildStats(model))
	self._controller:SetFuelLevel(1)
	if not self._controller:Mount(vehicleSeat, drive, model) then
		return
	end
	self._controller:StartEngine()
	self._model = model
	self._seat = vehicleSeat
end

function MopedMountController.OnCharacterAdded(self: MopedMountController, _character: Model?): ()
	self:Dismount()
end

function MopedMountController.Start(self: MopedMountController): ()
	if self._inputBegan ~= nil or self._destroyed then
		return
	end

	self._inputBegan = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == MOUNT_KEY then
			self:ToggleMount()
		end
	end)

	self._stepped = RunService.Heartbeat:Connect(function()
		self:_adoptAutoSeat()
	end)
end

function MopedMountController.Stop(self: MopedMountController): ()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._inputBegan ~= nil then
		self._inputBegan:Disconnect()
		self._inputBegan = nil
	end
	if self._stepped ~= nil then
		self._stepped:Disconnect()
		self._stepped = nil
	end
	self:Dismount()
	self._controller:Destroy()
end

return MopedMountController
