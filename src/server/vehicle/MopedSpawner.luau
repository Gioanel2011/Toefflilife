--!strict
-- MopedSpawner: erzeugt pro Spieler und gekauftem Mofa genau ein verankertes
-- Model in Workspace.ToeffliTalVehicles. Preise, Besitz und Auswahl bleiben
-- serverseitig; dieses Modul baut nur Geometrie und Attribute.
-- Keine Roblox-Simulation, keine Wheel-Drives und keine Clientwerte.

local CollectionService = game:GetService("CollectionService")

local VehicleCatalog = require("../../shared/data/VehicleCatalog")
local MopedLayout = require(script.Parent.MopedLayout)
local TerrainHeight = require("../world/TerrainHeight")
local VehicleAssembly = require(script.Parent.VehicleAssembly)

local MopedSpawner = {}

local FOLDER_NAME = "ToeffliTalVehicles"
local DEFAULT_SPAWN = CFrame.new(0, 5, 0)
local SPAWN_SIDE_OFFSET = 3
local SPAWN_BACK_OFFSET = 3
local SPAWN_RAY_UP = 512
local SPAWN_RAY_DOWN = 1024

local function getFolder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function makePart(spec: MopedLayout.PartSpec, base: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z)
	part.CFrame = base * CFrame.new(spec.offset.x, spec.offset.y, spec.offset.z)
	part.Color = Color3.fromRGB(spec.color.r, spec.color.g, spec.color.b)
	part.Transparency = spec.transparency
	part.Anchored = true
	part.CanCollide = spec.canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

local function makeSeat(spec: MopedLayout.PartSpec, base: CFrame): VehicleSeat
	local seat = Instance.new("VehicleSeat")
	seat.Name = spec.name
	seat.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z)
	seat.CFrame = base * CFrame.new(spec.offset.x, spec.offset.y, spec.offset.z)
	seat.Color = Color3.fromRGB(spec.color.r, spec.color.g, spec.color.b)
	seat.Transparency = spec.transparency
	seat.Anchored = true
	seat.CanCollide = false
	-- Nur E darf aufsteigen; kein automatisches Aufsitzen beim Beruehren.
	seat.Disabled = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	return seat
end

local function weldTo(main: BasePart, other: BasePart, parent: Model): ()
	if other == main then
		return
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = string.format("Weld_%s", other.Name)
	weld.Part0 = main
	weld.Part1 = other
	weld.Parent = parent
end

local function flatForward(look: Vector3): Vector3
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- Setzt das Mofa seitlich hinter den Spieler auf den tatsaechlichen Boden.
-- Der Strahl startet bewusst sehr hoch, damit er unabhaengig davon trifft,
-- wo der Charakter gerade schwebt oder faellt.
local function resolveSpawnCFrame(player: Player, spec: MopedLayout.MopedSpec): CFrame
	local character = player.Character
	local ref = DEFAULT_SPAWN
	if character ~= nil then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			ref = (root :: BasePart).CFrame
		end
	end
	local forward = flatForward(ref.LookVector)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local parking = MopedLayout.parkingOffsetFor(spec.vehicleId)
	local sideways = SPAWN_SIDE_OFFSET
	if parking ~= nil then
		sideways += parking.x
	end
	local target = ref.Position + right * sideways + forward * -SPAWN_BACK_OFFSET

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	local filters: { Instance } = {}
	if character ~= nil then
		table.insert(filters, character)
	end
	if folder ~= nil then
		table.insert(filters, folder)
	end
	params.FilterDescendantsInstances = filters

	local origin = Vector3.new(target.X, SPAWN_RAY_UP, target.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -SPAWN_RAY_DOWN, 0), params)
	local groundY = if hit ~= nil then hit.Position.Y else TerrainHeight.heightAt(target.X, target.Z)
	local pivot = Vector3.new(target.X, groundY + MopedLayout.PIVOT_HEIGHT + 0.5, target.Z)
	return CFrame.lookAt(pivot, pivot + forward)
end

local function matchesOwner(child: Instance, player: Player): boolean
	if child:GetAttribute("OwnerPlayerUserId") == player.UserId then
		return true
	end
	if child:GetAttribute("OwnerUserId") == player.UserId then
		return true
	end
	local suffix = "_" .. tostring(player.UserId)
	return string.sub(child.Name, -#suffix) == suffix
end

local function releaseVehicle(player: Player, vehicleId: string): ()
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if matchesOwner(child, player) and child:GetAttribute("VehicleId") == vehicleId then
			child:Destroy()
		end
	end
end

function MopedSpawner.createForPlayer(
	player: Player,
	vehicleId: string,
	ownerUserId: number?
): Model?
	local definition = VehicleCatalog.get(vehicleId)
	local spec = MopedLayout.get(vehicleId)
	if definition == nil or spec == nil or definition.Class ~= "moped" then
		return nil
	end

	releaseVehicle(player, vehicleId)
	local folder = getFolder()
	local base = resolveSpawnCFrame(player, spec)

	local model = Instance.new("Model")
	model.Name = string.format("Moped_%s_%d", vehicleId, player.UserId)

	local drive: BasePart? = nil
	local seat: VehicleSeat? = nil
	for _, entry in ipairs(spec.parts) do
		local part: BasePart
		if entry.name == spec.seatName then
			local vehicleSeat = makeSeat(entry, base)
			seat = vehicleSeat
			part = vehicleSeat
		else
			part = makePart(entry, base)
		end
		part.Parent = model
		if entry.name == spec.primaryPart then
			drive = part
		else
			part.Massless = true
		end
	end

	if drive == nil or seat == nil then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = drive

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			weldTo(drive, child, model)
		end
	end

	model:SetAttribute("VehicleId", vehicleId)
	model:SetAttribute("ModelId", vehicleId)
	model:SetAttribute("OwnerUserId", ownerUserId or player.UserId)
	model:SetAttribute("OwnerPlayerUserId", player.UserId)
	model:SetAttribute("IsMoped", true)
	model:SetAttribute("TopSpeedKmh", definition.Physics.TopSpeedKmh)
	model:SetAttribute("Acceleration", definition.Physics.Acceleration)
	model:SetAttribute("Braking", definition.Physics.Braking)
	model:SetAttribute("Handling", definition.Physics.Handling)
	model:SetAttribute("TankLiters", definition.Fuel.TankLiters)
	model:SetAttribute("FuelConsumptionPerSecond", 0.005)
	CollectionService:AddTag(model, MopedLayout.TAG_NAME)

	model.Parent = folder
	VehicleAssembly.watch(player, model, drive, seat)

	print(string.format(
		"[ToeffliTal][Spawn] %s bei %.1f/%.1f/%.1f",
		model.Name,
		base.X,
		base.Y,
		base.Z
	))

	return model
end

function MopedSpawner.releaseForPlayer(player: Player): ()
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("IsMoped") == true and matchesOwner(child, player) then
			child:Destroy()
		end
	end
end

return MopedSpawner
