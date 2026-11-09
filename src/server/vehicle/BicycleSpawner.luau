--!strict
-- BicycleSpawner: erzeugt pro Spieler genau ein kostenloses Startfahrrad.
-- Kein Motor, kein Treibstoff, kein Tuning, keine Preise, keine Gameplay-Logik.

local CollectionService = game:GetService("CollectionService")

local BicycleSpawner = {}

local FOLDER_NAME = "ToeffliTalVehicles"
local TAG_NAME = "ToeffliBicycle"
local DEFAULT_SPAWN = CFrame.new(0, 5, 0)

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

	local base = spawnCFrame or DEFAULT_SPAWN
	local folder = getFolder()

	local model = Instance.new("Model")
	model.Name = string.format("StarterBicycle_%d", player.UserId)

	local drive = makePart("Part", "Drive", Vector3.new(1.2, 0.4, 3.2), Color3.fromRGB(180, 180, 180))
	drive.CFrame = base * CFrame.new(0, 1.0, 0)

	local seat = makePart("Seat", "Seat", Vector3.new(1.0, 0.5, 1.0), Color3.fromRGB(40, 40, 40))
	seat.CanCollide = false
	seat.CFrame = base * CFrame.new(0, 1.6, -0.6)

	local wheelFront = makePart("Part", "WheelFront", Vector3.new(0.4, 1.4, 1.4), Color3.fromRGB(25, 25, 25))
	wheelFront.Shape = Enum.PartType.Cylinder
	wheelFront.CFrame = base * CFrame.new(0, 0.7, 1.6)

	local wheelRear = makePart("Part", "WheelRear", Vector3.new(0.4, 1.4, 1.4), Color3.fromRGB(25, 25, 25))
	wheelRear.Shape = Enum.PartType.Cylinder
	wheelRear.CFrame = base * CFrame.new(0, 0.7, -1.6)

	-- Lenker.
	local handlebar = makePart("Part", "Handlebar", Vector3.new(1.2, 0.3, 0.3), Color3.fromRGB(90, 90, 90))
	handlebar.CanCollide = false
	handlebar.CFrame = base * CFrame.new(0, 1.7, 1.2)

	for _, part in { drive, seat, wheelFront, wheelRear, handlebar } do
		part.Parent = model
	end
	model.PrimaryPart = drive

	for _, part in { seat, wheelFront, wheelRear, handlebar } do
		weldTo(drive, part, model)
	end

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("IsStarterBicycle", true)
	CollectionService:AddTag(model, TAG_NAME)

	model.Parent = folder
	model:PivotTo(base)

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
