--!strict
-- BicycleSpawner: erzeugt pro Spieler genau ein kostenloses Startfahrrad.
-- Kein Motor, kein Treibstoff, kein Tuning, keine Preise, keine Gameplay-Logik.
-- Das Fahrrad wird seitlich hinter dem Charakter auf den echten Boden gesetzt
-- (Raycast) und nur per E bestiegen; der Sitz ist dauerhaft deaktiviert.

local CollectionService = game:GetService("CollectionService")

local TerrainHeight = require("../world/TerrainHeight")
local VehicleAssembly = require(script.Parent.VehicleAssembly)

local BicycleSpawner = {}

local FOLDER_NAME = "ToeffliTalVehicles"
local TAG_NAME = "ToeffliBicycle"
local DEFAULT_SPAWN = CFrame.new(0, 5, 0)
-- Links neben dem Charakter und leicht hinter ihm, damit niemand beim Spawn
-- automatisch im Sitz landet.
local SPAWN_SIDE_OFFSET = -2.5
local SPAWN_BACK_OFFSET = 2
local SPAWN_RAY_UP = 512
local SPAWN_RAY_DOWN = 1024
-- Abstand Model-Pivot zu den Radunterseiten (siehe Bauteile unten).
local PIVOT_HEIGHT = 1.0

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

local function flatForward(look: Vector3): Vector3
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- Setzt das Fahrrad auf den tatsaechlichen Boden. Rein serverseitig, ohne
-- Clientwerte. Der Strahl startet bewusst sehr hoch, damit er unabhaengig
-- davon trifft, wo der Charakter gerade schwebt oder faellt.
local function resolveSpawnCFrame(player: Player, reference: CFrame?): CFrame
	local ref = reference or DEFAULT_SPAWN
	local character = player.Character
	if character ~= nil then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			ref = (root :: BasePart).CFrame
		end
	end

	local forward = flatForward(ref.LookVector)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local target = ref.Position + right * SPAWN_SIDE_OFFSET + forward * -SPAWN_BACK_OFFSET

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
	local pivot = Vector3.new(target.X, groundY + PIVOT_HEIGHT + 0.5, target.Z)
	return CFrame.lookAt(pivot, pivot + forward)
end

local function makePart(className: string, name: string, size: Vector3, color: Color3): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
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

function BicycleSpawner.createForPlayer(player: Player, spawnCFrame: CFrame?): Model
	BicycleSpawner.releaseForPlayer(player)

	local base = resolveSpawnCFrame(player, spawnCFrame)
	local folder = getFolder()

	local model = Instance.new("Model")
	model.Name = string.format("StarterBicycle_%d", player.UserId)

	-- Die sichtbare Front liegt auf lokal -Z und damit in Richtung
	-- `CFrame.LookVector`; so faehrt das Rad vorwaerts, nicht rueckwaerts.
	local drive = makePart("Part", "Drive", Vector3.new(1.2, 0.4, 3.2), Color3.fromRGB(180, 180, 180))
	drive.CFrame = base

	local seat = makePart("Seat", "Seat", Vector3.new(1.0, 0.5, 1.0), Color3.fromRGB(40, 40, 40))
	seat.CanCollide = false
	seat.CFrame = base * CFrame.new(0, 0.55, 0.6)

	local wheelFront = makePart("Part", "WheelFront", Vector3.new(0.4, 1.4, 1.4), Color3.fromRGB(25, 25, 25))
	wheelFront.Shape = Enum.PartType.Cylinder
	wheelFront.CFrame = base * CFrame.new(0, -0.3, -1.6)

	local wheelRear = makePart("Part", "WheelRear", Vector3.new(0.4, 1.4, 1.4), Color3.fromRGB(25, 25, 25))
	wheelRear.Shape = Enum.PartType.Cylinder
	wheelRear.CFrame = base * CFrame.new(0, -0.3, 1.6)

	-- Lenker.
	local handlebar = makePart("Part", "Handlebar", Vector3.new(1.2, 0.3, 0.3), Color3.fromRGB(90, 90, 90))
	handlebar.CanCollide = false
	handlebar.CFrame = base * CFrame.new(0, 0.85, -1.2)

	for _, part in { drive, seat, wheelFront, wheelRear, handlebar } do
		part.Parent = model
		if part ~= drive then
			part.Massless = true
		end
	end
	model.PrimaryPart = drive

	for _, part in { seat, wheelFront, wheelRear, handlebar } do
		weldTo(drive, part, model)
	end

	-- Nur E darf aufsteigen: Roblox sitzt Spieler sonst beim Beruehren auf.
	seat.Disabled = true

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("IsStarterBicycle", true)
	CollectionService:AddTag(model, TAG_NAME)

	model.Parent = folder
	model:PivotTo(base)
	VehicleAssembly.watch(player, model, drive, seat :: VehicleSeat)

	print(string.format(
		"[ToeffliTal][Spawn] %s bei %.1f/%.1f/%.1f",
		model.Name,
		base.X,
		base.Y,
		base.Z
	))

	return model
end

function BicycleSpawner.releaseForPlayer(player: Player): ()
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		local matchesAttribute = child:GetAttribute("OwnerUserId") == player.UserId
		local matchesName = child.Name == string.format("StarterBicycle_%d", player.UserId)
		if matchesAttribute or matchesName then
			child:Destroy()
		end
	end
end

return BicycleSpawner
