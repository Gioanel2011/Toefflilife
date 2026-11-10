--!strict
-- VehiclePhysics: echte Roblox-Physik fuer Fahrrad und Mofa.
-- Das Modell bleibt ein zusammenhaengendes, entankertes Assembly; Gravitation,
-- Kollisionen und Steigungen uebernimmt die Engine. Der Client steuert nur
-- Ausrichtung (AlignOrientation, starr) und Antrieb (VectorForce).
-- Es werden ausschliesslich eigene Modelle bewegt; Preise/Besitz bleiben
-- serverseitig.

local Players = game:GetService("Players")

local VehiclePhysics = {}
VehiclePhysics.__index = VehiclePhysics

export type Config = {
	maxSpeed: number,
	reverseSpeed: number,
	acceleration: number,
	brake: number,
	coast: number,
	turnRate: number,
	grip: number,
}

export type Input = {
	throttle: number,
	steer: number,
	brake: boolean,
}

export type VehiclePhysics = typeof(setmetatable(
	{} :: {
		_model: Model,
		_primary: BasePart,
		_attachment: Attachment,
		_align: AlignOrientation,
		_force: VectorForce,
		_config: Config,
		_params: RaycastParams,
		_yaw: number,
		_grounded: boolean,
		_lastGroundTime: number,
		_destroyed: boolean,
	},
	VehiclePhysics
))

local GROUND_PROBE_UP = 5
local GROUND_PROBE_DOWN = 11
local PITCH_DISTANCE = 2.4
local MAX_PITCH = 0.55

local function readYaw(part: BasePart): number
	local _, yaw, _ = part.CFrame:ToEulerAnglesYXZ()
	return yaw
end

local function buildRayParams(model: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local filters: { Instance } = { model }
	local player = Players.LocalPlayer
	if player ~= nil and player.Character ~= nil then
		table.insert(filters, player.Character)
	end
	params.FilterDescendantsInstances = filters
	return params
end

function VehiclePhysics.new(model: Model, config: Config): VehiclePhysics
	local primary: BasePart? = model.PrimaryPart
	if primary == nil then
		primary = model:FindFirstChildWhichIsA("BasePart", true)
	end
	assert(primary ~= nil, "vehicle needs a primary part")
	local drive = primary :: BasePart

	local attachmentInstance = drive:FindFirstChild("ToeffliDriveAttachment")
	local attachment: Attachment
	if attachmentInstance ~= nil and attachmentInstance:IsA("Attachment") then
		attachment = attachmentInstance
	else
		attachment = Instance.new("Attachment")
		attachment.Name = "ToeffliDriveAttachment"
		attachment.Parent = drive
	end

	-- Serverseitige Stabilisierung wiederverwenden, damit das Fahrzeug auch
	-- ohne Client-Besitz nicht umfaellt.
	local alignInstance = drive:FindFirstChild("ToeffliAlign")
	local align: AlignOrientation
	if alignInstance ~= nil and alignInstance:IsA("AlignOrientation") then
		align = alignInstance
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
	else
		align = Instance.new("AlignOrientation")
		align.Name = "ToeffliAlign"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Parent = drive
	end

	local force = Instance.new("VectorForce")
	force.Name = "ToeffliForce"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = drive

	local self = setmetatable({
		_model = model,
		_primary = drive,
		_attachment = attachment,
		_align = align,
		_force = force,
		_config = config,
		_params = buildRayParams(model),
		_yaw = readYaw(drive),
		_grounded = false,
		_lastGroundTime = 0,
		_destroyed = false,
	}, VehiclePhysics)
	self:_applyOrientation(0)
	return self
end

-- Bodenhoehe bei einem Versatz entlang der Fahrzeugfront (nil = kein Boden).
function VehiclePhysics._groundAt(self: VehiclePhysics, forward: Vector3, offset: number): number?
	local origin = self._primary.Position + forward * offset + Vector3.new(0, GROUND_PROBE_UP, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -(GROUND_PROBE_UP + GROUND_PROBE_DOWN), 0), self._params)
	if hit ~= nil then
		return hit.Position.Y
	end
	return nil
end

function VehiclePhysics._applyOrientation(self: VehiclePhysics, pitch: number): ()
	if self._destroyed then
		return
	end
	local position = self._primary.Position
	self._align.CFrame = CFrame.new(position) * CFrame.fromEulerAnglesYXZ(pitch, self._yaw, 0)
end

function VehiclePhysics.getSpeed(self: VehiclePhysics): number
	if self._destroyed then
		return 0
	end
	local velocity = self._primary.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function VehiclePhysics.isGrounded(self: VehiclePhysics): boolean
	return self._grounded
end

function VehiclePhysics.update(self: VehiclePhysics, dt: number, input: Input): ()
	if self._destroyed then
		return
	end
	local primary = self._primary
	local config = self._config

	local velocity = primary.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local flatFrame = CFrame.Angles(0, self._yaw, 0)
	local forward = flatFrame.LookVector
	local right = flatFrame.RightVector
	local along = flatVelocity:Dot(forward)

	-- Lenkung nur bei echter Fahrt, damit das Fahrzeug im Stand nicht dreht.
	if input.steer ~= 0 and math.abs(along) > 0.6 then
		local direction = if along >= 0 then 1 else -1
		local speedFactor = math.clamp(math.abs(along) / math.max(config.maxSpeed, 1), 0, 1)
		self._yaw += -input.steer * config.turnRate * direction * (0.35 + 0.65 * speedFactor) * dt
		flatFrame = CFrame.Angles(0, self._yaw, 0)
		forward = flatFrame.LookVector
		right = flatFrame.RightVector
	end

	-- Steigung: vorne/hinten messen und das Modell neigen.
	local front = self:_groundAt(forward, PITCH_DISTANCE / 2)
	local rear = self:_groundAt(forward, -PITCH_DISTANCE / 2)
	local center = self:_groundAt(forward, 0)
	local pitch = 0
	if front ~= nil and rear ~= nil then
		pitch = math.clamp(math.atan2(front - rear, PITCH_DISTANCE), -MAX_PITCH, MAX_PITCH)
	end
	local now = os.clock()
	if center ~= nil then
		self._lastGroundTime = now
	end
	-- Kurze Nachsicht (Coyote): kurze Bodenwellen unterbrechen den Schub nicht.
	self._grounded = center ~= nil or (now - self._lastGroundTime) < 0.2
	self:_applyOrientation(pitch)

	local mass = primary.AssemblyMass
	local forceVector = Vector3.zero
	if self._grounded then
		local throttle = input.throttle
		local forwardAllowed = throttle > 0 and along < config.maxSpeed
		local reverseAllowed = throttle < 0 and along > -config.reverseSpeed
		if forwardAllowed or reverseAllowed then
			forceVector += forward * (config.acceleration * mass * throttle)
		end
		if input.brake or throttle == 0 then
			local rate = if input.brake then config.brake else config.coast
			forceVector += -flatVelocity * (rate * mass)
		end
		local lateral = flatVelocity:Dot(right)
		forceVector += -right * (lateral * config.grip * mass)
	end

	forceVector = Vector3.new(forceVector.X, 0, forceVector.Z)
	self._force.Force = forceVector
end

function VehiclePhysics.destroy(self: VehiclePhysics): ()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._force.Force = Vector3.zero
	self._force.Enabled = false
	self._force:Destroy()
	-- Attachment und AlignOrientation bleiben: sie halten das Fahrzeug im
	-- Stand aufrecht und werden beim naechsten Aufsteigen wiederverwendet.
end

return VehiclePhysics
