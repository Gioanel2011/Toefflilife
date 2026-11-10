--!strict
-- MopedController: Arcade-realistische PC-Steuerung fuer Puch Maxi S und Piaggio Ciao.
-- Die Steuerung liest ausschliesslich serverseitig gelieferte Fahrzeugwerte
-- (via SetStats / ApplyServerStats) und nutzt keine hartcodierte Modellphysik.
-- Bietet Hooks fuer Treibstoff (SetFuelLevel / OnOutOfFuel / OnFuelConsumed)
-- sowie Start/Stop (StartEngine / StopEngine / OnEngineChanged).

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local VehiclePhysics = require(script.Parent.VehiclePhysics)

export type VehicleStats = {
	modelId: string,
	acceleration: number,
	topSpeed: number,
	brakeForce: number,
	turnRate: number,
	reverseSpeed: number?,
	dragCoefficient: number?,
	rollingResistance: number?,
	fuelConsumptionPerSecond: number?,
}

export type InputState = {
	throttle: number,
	brake: number,
	steer: number,
	handbrake: boolean,
}

local DEFAULT_STATS: VehicleStats = {
	modelId = "unknown",
	acceleration = 12,
	topSpeed = 28,
	brakeForce = 30,
	turnRate = 1.8,
	reverseSpeed = 4,
	dragCoefficient = 0.35,
	rollingResistance = 2.0,
	fuelConsumptionPerSecond = 0.02,
}

local function clampNumber(value: number, minValue: number, maxValue: number): number
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	else
		return value
	end
end

-- Arcade-Physik: kraeftig genug, um Steigungen zu erklimmen.
local ENGINE_ACCELERATION = 180
local ENGINE_BRAKE = 14
local ENGINE_GRIP = 9

local function sanitizeStats(raw: VehicleStats?): VehicleStats
	if raw == nil then
		return table.clone(DEFAULT_STATS)
	end
	local stats: VehicleStats = table.clone(DEFAULT_STATS)
	if typeof(raw.modelId) == "string" and raw.modelId ~= "" then
		stats.modelId = raw.modelId
	end
	if typeof(raw.acceleration) == "number" and raw.acceleration > 0 then
		stats.acceleration = clampNumber(raw.acceleration, 1, 120)
	end
	if typeof(raw.topSpeed) == "number" and raw.topSpeed > 0 then
		stats.topSpeed = clampNumber(raw.topSpeed, 1, 150)
	end
	if typeof(raw.brakeForce) == "number" and raw.brakeForce > 0 then
		stats.brakeForce = clampNumber(raw.brakeForce, 1, 200)
	end
	if typeof(raw.turnRate) == "number" and raw.turnRate > 0 then
		stats.turnRate = clampNumber(raw.turnRate, 0.1, 6)
	end
	if typeof(raw.reverseSpeed) == "number" and (raw.reverseSpeed :: number) >= 0 then
		stats.reverseSpeed = clampNumber(raw.reverseSpeed :: number, 0, 20)
	end
	if typeof(raw.dragCoefficient) == "number" and (raw.dragCoefficient :: number) >= 0 then
		stats.dragCoefficient = clampNumber(raw.dragCoefficient :: number, 0, 5)
	end
	if typeof(raw.rollingResistance) == "number" and (raw.rollingResistance :: number) >= 0 then
		stats.rollingResistance = clampNumber(raw.rollingResistance :: number, 0, 30)
	end
	if typeof(raw.fuelConsumptionPerSecond) == "number" and (raw.fuelConsumptionPerSecond :: number) >= 0 then
		stats.fuelConsumptionPerSecond = clampNumber(raw.fuelConsumptionPerSecond :: number, 0, 1)
	end
	return stats
end

local MopedController = {}
MopedController.__index = MopedController

export type MopedController = typeof(setmetatable(
	{} :: {
		_stats: VehicleStats,
		_input: InputState,
		_engineOn: boolean,
		_fuelLevel: number,
		_speed: number,
		_seat: VehicleSeat?,
		_vehicleRoot: BasePart?,
		_vehicleModel: Model?,
		_physics: any?,
		_physicsError: boolean,
		_mountedAt: number,
		_connections: { RBXScriptConnection },
		_onEngineChanged: ((boolean) -> ())?,
		_onOutOfFuel: (() -> ())?,
		_onFuelConsumed: ((number) -> ())?,
		_destroyed: boolean,
	},
	MopedController
))

function MopedController.new(initialStats: VehicleStats?): MopedController
	local self = setmetatable({
		_stats = sanitizeStats(initialStats),
		_input = {
			throttle = 0,
			brake = 0,
			steer = 0,
			handbrake = false,
		},
		_engineOn = false,
		_fuelLevel = 1,
		_speed = 0,
		_seat = nil,
		_vehicleRoot = nil,
		_vehicleModel = nil,
		_physics = nil,
		_physicsError = false,
		_mountedAt = 0,
		_connections = {},
		_onEngineChanged = nil,
		_onOutOfFuel = nil,
		_onFuelConsumed = nil,
		_destroyed = false,
	}, MopedController)
	return self
end

function MopedController.SetStats(self: MopedController, stats: VehicleStats)
	self._stats = sanitizeStats(stats)
	self:_applyStatsToSeat()
end

function MopedController.ApplyServerStats(self: MopedController, stats: VehicleStats)
	self:SetStats(stats)
end

function MopedController.GetStats(self: MopedController): VehicleStats
	return table.clone(self._stats)
end

function MopedController.GetModelId(self: MopedController): string
	return self._stats.modelId
end

function MopedController.SetFuelLevel(self: MopedController, level01: number)
	self._fuelLevel = clampNumber(level01, 0, 1)
	if self._fuelLevel <= 0 and self._engineOn then
		self:StopEngine()
	end
end

function MopedController.GetFuelLevel(self: MopedController): number
	return self._fuelLevel
end

function MopedController.OnOutOfFuel(self: MopedController, callback: (() -> ())?)
	self._onOutOfFuel = callback
end

function MopedController.OnFuelConsumed(self: MopedController, callback: ((number) -> ())?)
	self._onFuelConsumed = callback
end

function MopedController.OnEngineChanged(self: MopedController, callback: ((boolean) -> ())?)
	self._onEngineChanged = callback
end

function MopedController.IsEngineOn(self: MopedController): boolean
	return self._engineOn
end

function MopedController.CanDrive(self: MopedController): boolean
	return self._engineOn and self._fuelLevel > 0
end

function MopedController.StartEngine(self: MopedController): boolean
	if self._destroyed then
		return false
	end
	if self._engineOn then
		return true
	end
	if self._fuelLevel <= 0 then
		return false
	end
	self._engineOn = true
	if self._onEngineChanged ~= nil then
		(self._onEngineChanged :: (boolean) -> ())(true)
	end
	return true
end

function MopedController.StopEngine(self: MopedController)
	if not self._engineOn then
		return
	end
	self._engineOn = false
	self._input.throttle = 0
	self:_applyInputToSeat()
	if self._onEngineChanged ~= nil then
		(self._onEngineChanged :: (boolean) -> ())(false)
	end
end

function MopedController.ToggleEngine(self: MopedController): boolean
	if self._engineOn then
		self:StopEngine()
		return false
	else
		return self:StartEngine()
	end
end

function MopedController.IsRiding(self: MopedController): boolean
	return self._seat ~= nil
end

function MopedController.GetSpeed(self: MopedController): number
	return self._speed
end

function MopedController.GetInput(self: MopedController): InputState
	return table.clone(self._input)
end

function MopedController.CanMount(self: MopedController, seat: VehicleSeat?, maxDistanceStuds: number?): boolean
	assert(self ~= nil, "controller required")
	if seat == nil then
		return false
	end
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not (root :: Instance):IsA("BasePart") then
		return false
	end
	local limit = maxDistanceStuds or 10
	local seatPart = seat :: VehicleSeat
	local distance = (seatPart.Position - (root :: BasePart).Position).Magnitude
	return distance <= limit
end

-- Baut die Physik-Huelle fuer das aktuell gebundene Modell (idempotent).
function MopedController._ensurePhysics(self: MopedController): ()
	if self._physics ~= nil then
		return
	end
	local model = self._vehicleModel
	if model == nil then
		return
	end
	local ok, result = pcall(VehiclePhysics.new, model, {
		maxSpeed = self._stats.topSpeed,
		reverseSpeed = self._stats.reverseSpeed or 4,
		acceleration = ENGINE_ACCELERATION,
		brake = ENGINE_BRAKE,
		coast = 3,
		turnRate = self._stats.turnRate,
		grip = ENGINE_GRIP,
	})
	if ok then
		self._physics = result
		return
	end
	if not self._physicsError then
		self._physicsError = true
		warn("[ToeffliTal][Physik] Mofa: " .. tostring(result))
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Töffli Tal",
				Text = "Mofa-Physikfehler – bitte Output melden.",
				Duration = 8,
			})
		end)
	end
end

function MopedController.Mount(self: MopedController, seat: VehicleSeat, vehicleRoot: BasePart?, vehicleModel: Model?)
	if self._destroyed then
		return false
	end
	if seat == nil or not seat:IsA("VehicleSeat") then
		return false
	end
	self:Dismount()
	self._seat = seat
	self._vehicleRoot = vehicleRoot
	self._vehicleModel = vehicleModel
	self._mountedAt = os.clock()
	self:_ensurePhysics()
	self:_applyStatsToSeat()
	self:_bindInput()
	self:_bindPhysics()
	return true
end

function MopedController.GetVehicleModel(self: MopedController): Model?
	return self._vehicleModel
end

function MopedController.Dismount(self: MopedController)
	local seat = self._seat
	local player = Players.LocalPlayer
	if player ~= nil then
		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil and humanoid.SeatPart == seat then
				humanoid.Sit = false
			end
		end
	end
	-- Erst nach dem Aufstehen wieder fuer Auto-Aufsitzen sperren.
	if seat ~= nil then
		seat.Disabled = true
	end
	if self._physics ~= nil then
		self._physics:destroy()
		self._physics = nil
	end
	self._seat = nil
	self._vehicleRoot = nil
	self._vehicleModel = nil
	self._speed = 0
	self._input.throttle = 0
	self._input.brake = 0
	self._input.steer = 0
	self._input.handbrake = false
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

function MopedController.Destroy(self: MopedController)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:StopEngine()
	self:Dismount()
	self._onEngineChanged = nil
	self._onOutOfFuel = nil
	self._onFuelConsumed = nil
end

function MopedController._applyStatsToSeat(self: MopedController)
	local seat = self._seat
	if seat == nil then
		return
	end
	seat.MaxSpeed = self._stats.topSpeed
	seat.TurnSpeed = self._stats.turnRate * 20
end

function MopedController._applyInputToSeat(self: MopedController)
	local seat = self._seat
	if seat == nil then
		return
	end
	local throttleValue = 0
	if self:CanDrive() then
		throttleValue = self._input.throttle - self._input.brake
		if self._input.handbrake then
			throttleValue = -math.sign(self._speed)
		end
	end
	seat.ThrottleFloat = clampNumber(throttleValue, -1, 1)
	seat.SteerFloat = clampNumber(self._input.steer, -1, 1)
end

function MopedController._consumeFuel(self: MopedController, dt: number)
	if not self._engineOn then
		return
	end
	local rate = self._stats.fuelConsumptionPerSecond or 0
	local burn = (0.2 + 0.8 * self._input.throttle) * rate * dt
	if burn <= 0 then
		return
	end
	self._fuelLevel = math.max(0, self._fuelLevel - burn)
	if self._onFuelConsumed ~= nil then
		(self._onFuelConsumed :: (number) -> ())(self._fuelLevel)
	end
	if self._fuelLevel <= 0 then
		self:StopEngine()
		if self._onOutOfFuel ~= nil then
			(self._onOutOfFuel :: () -> ())()
		end
	end
end

function MopedController._stepSpeed(self: MopedController, dt: number): number
	local stats = self._stats
	local reverseSpeed = stats.reverseSpeed or DEFAULT_STATS.reverseSpeed :: number
	local drag = stats.dragCoefficient or 0
	local rolling = stats.rollingResistance or 0

	local driveAccel = 0
	if self:CanDrive() then
		driveAccel = stats.acceleration * self._input.throttle
	end

	local brakeDecel = stats.brakeForce * self._input.brake
	if self._input.handbrake then
		brakeDecel += stats.brakeForce * 0.8
	end

	local direction = 1
	if self._speed < 0 then
		direction = -1
	end

	local dragForce = self._speed * drag + direction * rolling * math.min(1, math.abs(self._speed) / 2)
	local nextSpeed = self._speed + (driveAccel - direction * brakeDecel - dragForce) * dt

	if self._input.brake <= 0 and self._input.throttle <= 0 and math.abs(nextSpeed) < 0.4 then
		nextSpeed = 0
	end

	if nextSpeed > 0 and self._input.brake > 0 and driveAccel <= 0 then
		nextSpeed = math.max(0, nextSpeed)
	end

	self._speed = clampNumber(nextSpeed, -1 * (reverseSpeed :: number), stats.topSpeed)
	return self._speed
end

function MopedController._bindInput(self: MopedController)
	local began = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			self._input.throttle = 1
		elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			self._input.brake = 1
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			self._input.steer = -1
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			self._input.steer = 1
		elseif input.KeyCode == Enum.KeyCode.Space then
			self._input.handbrake = true
		elseif input.KeyCode == Enum.KeyCode.F then
			self:ToggleEngine()
			return
		else
			return
		end
		self:_applyInputToSeat()
	end)
	table.insert(self._connections, began)

	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			self._input.throttle = 0
		elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			self._input.brake = 0
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			if self._input.steer < 0 then
				self._input.steer = 0
			end
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			if self._input.steer > 0 then
				self._input.steer = 0
			end
		elseif input.KeyCode == Enum.KeyCode.Space then
			self._input.handbrake = false
		else
			return
		end
		self:_applyInputToSeat()
	end)
	table.insert(self._connections, ended)
end

-- Fahrt laeuft vollstaendig ueber VehiclePhysics (VectorForce + AlignOrientation).

function MopedController._bindPhysics(self: MopedController)
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if self._seat == nil then
			return
		end
		local player = Players.LocalPlayer
		local character = if player ~= nil then player.Character else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil or humanoid.SeatPart ~= self._seat then
			-- Kurz nach dem Aufsteigen Nachsicht, bis Roblox den Sitz zuweist.
			if os.clock() - self._mountedAt < 0.75 then
				return
			end
			self:Dismount()
			return
		end
		-- Space ist Bremse, nicht Sprung.
		if humanoid.Jump then
			humanoid.Jump = false
		end

		local clampedDt = clampNumber(dt, 0, 1 / 20)
		self:_consumeFuel(clampedDt)
		self:_ensurePhysics()
		local physics = self._physics
		if physics ~= nil then
			local throttle = if self:CanDrive() then self._input.throttle else 0
			physics:update(clampedDt, {
				throttle = throttle,
				steer = self._input.steer,
				brake = self._input.brake > 0 or self._input.handbrake,
			})
			self._speed = physics:getSpeed()
		end
		self:_applyInputToSeat()
	end)
	table.insert(self._connections, heartbeat)
end

return MopedController
