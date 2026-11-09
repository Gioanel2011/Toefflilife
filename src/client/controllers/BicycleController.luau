--!strict
-- BicycleController: Arcade-PC-Steuerung fuer das kostenlose Startfahrrad.
-- Kein Motor, kein Treibstoff, keine Tuning-Schnittstelle.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local BicycleController = {}
BicycleController.__index = BicycleController

export type BicycleController = typeof(setmetatable(
	{} :: {
		_mounted: boolean,
		_speed: number,
		_bike: Model?,
		_seat: Seat?,
		_throttle: number,
		_steer: number,
		_brake: boolean,
		_mountDebounceUntil: number,
		_inputBegan: RBXScriptConnection?,
		_inputEnded: RBXScriptConnection?,
		_stepped: RBXScriptConnection?,
		_keys: { [Enum.KeyCode]: boolean },
	},
	BicycleController
))

-- Fahrwerte (studs/s, Arcade-Abstimmung).
local MAX_SPEED = 18
local MAX_REVERSE_SPEED = 4
local ACCELERATION = 12
local BRAKE_DECELERATION = 22
local COAST_FRICTION = 6
local TURN_RATE = 1.9
local MOUNT_DISTANCE = 10
local MOUNT_COOLDOWN = 0.5

-- Auf-/Absteigen per PC-Taste. Es wird nur das eigene Startfahrrad gewaehlt.
local BICYCLE_TAG = "ToeffliBicycle"
local MOUNT_KEY = Enum.KeyCode.E

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getCharacterHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function findSeat(bike: Model): Seat?
	local seat = bike:FindFirstChild("Seat", true)
	if seat ~= nil and seat:IsA("Seat") then
		return seat
	end
	return nil
end

local function findDrivePart(bike: Model): BasePart?
	local primary = bike.PrimaryPart
	if primary ~= nil then
		return primary
	end
	local root = bike:FindFirstChild("Drive", true)
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return bike:FindFirstChildWhichIsA("BasePart", true)
end

-- Naechstes eigenes Fahrrad in Reichweite; fremde Fahrzeuge bleiben unberuehrt.
local function findNearestOwnedBicycle(player: Player, maxDistance: number): Model?
	local root = getCharacterRoot(player)
	if root == nil then
		return nil
	end

	local nearest: Model? = nil
	local nearestDistance = maxDistance
	for _, instance in CollectionService:GetTagged(BICYCLE_TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
			local bike = instance :: Model
			if bike:GetAttribute("OwnerUserId") == player.UserId then
				local drive = findDrivePart(bike)
				if drive ~= nil then
					local distance = (drive.Position - root.Position).Magnitude
					if distance <= nearestDistance then
						nearest = bike
						nearestDistance = distance
					end
				end
			end
		end
	end
	return nearest
end

function BicycleController.new(): BicycleController
	local self = setmetatable({
		_mounted = false,
		_speed = 0,
		_bike = nil,
		_seat = nil,
		_throttle = 0,
		_steer = 0,
		_brake = false,
		_mountDebounceUntil = 0,
		_inputBegan = nil,
		_inputEnded = nil,
		_stepped = nil,
		_keys = {},
	}, BicycleController)
	return self
end

function BicycleController.IsMounted(self: BicycleController): boolean
	return self._mounted
end

function BicycleController.GetSpeed(self: BicycleController): number
	return self._speed
end

function BicycleController.GetBike(self: BicycleController): Model?
	return self._bike
end

-- Stabile Aufstiegslogik: Naehe, freier Sitz, lebender Humanoid, Entprellung.
function BicycleController.Mount(self: BicycleController, bike: Model): boolean
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	if self._mounted then
		return false
	end
	if os.clock() < self._mountDebounceUntil then
		return false
	end

	local root = getCharacterRoot(player)
	if root == nil then
		return false
	end
	local drive = findDrivePart(bike)
	if drive == nil then
		return false
	end
	if (drive.Position - root.Position).Magnitude > MOUNT_DISTANCE then
		return false
	end

	local seat = findSeat(bike)
	if seat == nil then
		return false
	end
	if seat.Occupant ~= nil then
		return false
	end

	local character = player.Character
	local humanoid: Humanoid? = nil
	if character ~= nil then
		humanoid = character:FindFirstChildOfClass("Humanoid")
	end
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end

	self._bike = bike
	self._seat = seat
	self._mounted = true
	self._speed = 0
	self._mountDebounceUntil = os.clock() + MOUNT_COOLDOWN
	seat:Sit(humanoid)
	return true
end

function BicycleController.Dismount(self: BicycleController): ()
	if not self._mounted then
		return
	end
	self._mounted = false
	self._speed = 0
	self._throttle = 0
	self._steer = 0
	self._brake = false
	self._mountDebounceUntil = os.clock() + MOUNT_COOLDOWN

	local seat = self._seat
	if seat ~= nil then
		seat.Disabled = true
		seat.Disabled = false
	end
	self._bike = nil
	self._seat = nil

	local player = Players.LocalPlayer
	local character: Model? = nil
	if player ~= nil then
		character = player.Character
	end
	if character ~= nil then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil and humanoid.SeatPart ~= nil then
			humanoid.Jump = true
		end
	end
end

-- E-Verhalten: aufsteigen, wenn nicht gefahren wird; sonst absteigen.
function BicycleController.ToggleMount(self: BicycleController): boolean
	if self._mounted then
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
	local bike = findNearestOwnedBicycle(player, MOUNT_DISTANCE)
	if bike == nil then
		return false
	end
	return self:Mount(bike)
end

-- Gemeinsamer Ruecksetzpfad ohne Sprung (Respawn, externes Absteigen).
function BicycleController._resetMountState(self: BicycleController, cooldown: boolean): ()
	self._mounted = false
	self._speed = 0
	self._throttle = 0
	self._steer = 0
	self._brake = false
	self._bike = nil
	self._seat = nil
	if cooldown then
		self._mountDebounceUntil = os.clock() + MOUNT_COOLDOWN
	end
end

-- Neuer Charakter: alten Sitzbezug loesen, ohne Sprung zu erzwingen.
function BicycleController.OnCharacterAdded(self: BicycleController, _character: Model?): ()
	if not self._mounted then
		return
	end
	self:_resetMountState(true)
end

-- Roblox setzt Charaktere automatisch auf Sitze. Uebernimmt dieser Sitz zum
-- eigenen getaggten Fahrrad, gilt das als aufgestiegen (sonst blockiert
-- `Mount` wegen belegtem Sitz und E wuerde nie absteigen).
function BicycleController._adoptAutoSeat(self: BicycleController): ()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local seat = humanoid.SeatPart
	if seat == nil or not seat:IsA("Seat") then
		return
	end
	local bike = seat:FindFirstAncestorOfClass("Model")
	if bike == nil then
		return
	end
	if bike:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if not CollectionService:HasTag(bike, BICYCLE_TAG) then
		return
	end
	if findDrivePart(bike) == nil then
		return
	end

	self._bike = bike
	self._seat = seat
	self._mounted = true
	self._speed = 0
end

local function readKeys(self: BicycleController): (number, number, boolean)
	local throttle = 0
	local steer = 0

	if self._keys[Enum.KeyCode.W] or self._keys[Enum.KeyCode.Up] then
		throttle += 1
	end
	if self._keys[Enum.KeyCode.S] or self._keys[Enum.KeyCode.Down] then
		throttle -= 1
	end
	if self._keys[Enum.KeyCode.A] or self._keys[Enum.KeyCode.Left] then
		steer -= 1
	end
	if self._keys[Enum.KeyCode.D] or self._keys[Enum.KeyCode.Right] then
		steer += 1
	end

	local brake = self._keys[Enum.KeyCode.Space] == true
	return throttle, steer, brake
end

function BicycleController._step(self: BicycleController, dt: number): ()
	if not self._mounted then
		self:_adoptAutoSeat()
	end
	if not self._mounted then
		return
	end
	local bike = self._bike
	if bike == nil then
		self:Dismount()
		return
	end
	local drive = findDrivePart(bike)
	if drive == nil then
		self:Dismount()
		return
	end

	-- Sitzbezug pruefen: externes Absteigen (z. B. Sprung) sauber uebernehmen.
	local player = Players.LocalPlayer
	local humanoid = if player ~= nil then getCharacterHumanoid(player) else nil
	if humanoid == nil or humanoid.SeatPart ~= self._seat then
		self:_resetMountState(true)
		return
	end
	-- Space ist Bremse, nicht Sprung: Absprung waehrend der Fahrt unterdruecken.
	if humanoid.Jump then
		humanoid.Jump = false
	end

	local throttle, steer, brake = readKeys(self)
	self._throttle = throttle
	self._steer = steer
	self._brake = brake

	-- Beschleunigung / Bremsen / Ausrollen. Fahrrad: reine Tretphysik.
	if brake then
		if self._speed > 0 then
			self._speed = math.max(0, self._speed - BRAKE_DECELERATION * dt)
		elseif self._speed < 0 then
			self._speed = math.min(0, self._speed + BRAKE_DECELERATION * dt)
		end
	elseif throttle > 0 then
		self._speed = math.min(MAX_SPEED, self._speed + ACCELERATION * throttle * dt)
	elseif throttle < 0 then
		self._speed = math.max(-MAX_REVERSE_SPEED, self._speed + ACCELERATION * throttle * dt)
	else
		-- Ausrollen: Reibung zieht Geschwindigkeit gegen null.
		if self._speed > 0 then
			self._speed = math.max(0, self._speed - COAST_FRICTION * dt)
		elseif self._speed < 0 then
			self._speed = math.min(0, self._speed + COAST_FRICTION * dt)
		end
	end

	-- Lenkung und Vortrieb wirken auf das ganze Model, nicht nur auf `Drive`.
	-- Anchored Parts folgen keinen Welds; erst PivotTo bewegt Sitz, Raeder und
	-- den aufgesessenen Charakter gemeinsam.
	local pivot = bike:GetPivot()
	local rotated = pivot
	local speedFactor = math.clamp(math.abs(self._speed) / MAX_SPEED, 0, 1)
	if speedFactor > 0.01 and steer ~= 0 then
		local direction = if self._speed >= 0 then 1 else -1
		local yaw = -steer * TURN_RATE * (0.35 + 0.65 * speedFactor) * direction * dt
		rotated = pivot * CFrame.Angles(0, yaw, 0)
	end

	local translation = Vector3.zero
	if math.abs(self._speed) > 0.01 then
		local forward = rotated.LookVector
		-- Vertikale Komponente ignorieren, damit das Rad nicht abhebt.
		local flat = Vector3.new(forward.X, 0, forward.Z)
		if flat.Magnitude > 0.001 then
			translation = flat.Unit * self._speed * dt
		end
	end

	if rotated ~= pivot or translation.Magnitude > 0 then
		bike:PivotTo(rotated + translation)
	end
end

function BicycleController.Start(self: BicycleController): ()
	if self._stepped ~= nil then
		return
	end

	self._inputBegan = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		self._keys[input.KeyCode] = true
		if input.KeyCode == MOUNT_KEY then
			self:ToggleMount()
		end
	end)

	self._inputEnded = UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		self._keys[input.KeyCode] = false
	end)

	self._stepped = RunService.RenderStepped:Connect(function(dt: number)
		-- RenderStepped kann im Studio pausieren; dt clampen.
		local clamped = math.clamp(dt, 0, 1 / 20)
		self:_step(clamped)
	end)
end

function BicycleController.Stop(self: BicycleController): ()
	if self._inputBegan ~= nil then
		self._inputBegan:Disconnect()
		self._inputBegan = nil
	end
	if self._inputEnded ~= nil then
		self._inputEnded:Disconnect()
		self._inputEnded = nil
	end
	if self._stepped ~= nil then
		self._stepped:Disconnect()
		self._stepped = nil
	end
	table.clear(self._keys)
	if self._mounted then
		self:Dismount()
	end
end

return BicycleController
