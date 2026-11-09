--!strict
-- TrafficSignBuilder: Schweizer Verkehrszeichen als Roblox-Modelle.
-- Keine Platzierung, keine externen Assets, keine Gameplay-Logik.

local TrafficSignBuilder = {}

local SIGN_DIAMETER = 4.0
local SIGN_THICKNESS = 0.25
local BORDER_WIDTH = 0.25
local POLE_HEIGHT = 6.0
local POLE_DIAMETER = 0.25

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	return part
end

local function makeCylinder(
	name: string,
	diameter: number,
	height: number,
	cframe: CFrame,
	color: Color3
): Part
	-- Roblox-Zylinderachse liegt auf X; Rotation bringt die Kreisflaechen
	-- in die Front/Back-Richtung (Z).
	local part = makePart(name, Vector3.new(height, diameter, diameter), cframe, color, nil, false)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeSurfaceText(parent: Part, text: string, color: Color3): ()
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(300, 300)
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function makePole(mountCFrame: CFrame): Part
	local pole = makePart(
		"Pole",
		Vector3.new(POLE_DIAMETER, POLE_HEIGHT, POLE_DIAMETER),
		mountCFrame * CFrame.new(0, -POLE_HEIGHT / 2, 0),
		Color3.fromRGB(120, 120, 125),
		nil,
		true
	)
	pole.Shape = Enum.PartType.Cylinder
	return pole
end

local function makeOctagon(size: number, thickness: number, color: Color3): Part
	local base = makePart("OctagonBase", Vector3.new(size, size, thickness), CFrame.new(), color, nil, false)
	local cut = size * 0.293
	local half = size / 2
	local positions = {
		Vector3.new(half, half, 0),
		Vector3.new(half, -half, 0),
		Vector3.new(-half, half, 0),
		Vector3.new(-half, -half, 0),
	}
	local cutters: { Part } = {}
	for _, pos in positions do
		local cutter = makePart("Cutter", Vector3.new(cut * 1.5, cut * 1.5, thickness + 1), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(45)), Color3.new(1, 0, 0), nil, false)
		table.insert(cutters, cutter)
	end
	local ok, result = pcall(function()
		return base:SubtractAsync(cutters)
	end)
	for _, cutter in cutters do
		cutter:Destroy()
	end
	if ok and result ~= nil then
		base:Destroy()
		local part = result :: Part
		part.Name = "Octagon"
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		return part
	end
	base:Destroy()
	local fallback = makePart("Octagon", Vector3.new(size, size, thickness), CFrame.new(), color, nil, false)
	return fallback
end

function TrafficSignBuilder.createSpeedLimit(limit: number): Model
	local model = Instance.new("Model")
	model.Name = "SpeedLimitSign"

	local center = CFrame.new(0, POLE_HEIGHT + SIGN_DIAMETER / 2 + 0.5, 0)
	local orientation = CFrame.Angles(0, math.rad(90), 0)

	-- Roter Rand (hinter der weissen Scheibe).
	local redDiameter = SIGN_DIAMETER + BORDER_WIDTH * 2
	local redDisc = makeCylinder(
		"RedBorder",
		redDiameter,
		SIGN_THICKNESS + 0.05,
		center * orientation * CFrame.new(-0.05, 0, 0),
		Color3.fromRGB(220, 30, 30)
	)
	redDisc.Parent = model

	-- Weisse Scheibe.
	local whiteDisc = makeCylinder(
		"WhiteFace",
		SIGN_DIAMETER,
		SIGN_THICKNESS,
		center * orientation,
		Color3.fromRGB(250, 250, 250)
	)
	whiteDisc.Parent = model

	makeSurfaceText(whiteDisc, tostring(limit), Color3.fromRGB(20, 20, 20))

	-- Befestigungspunkt.
	local mount = makePart(
		"Attachment",
		Vector3.new(0.4, 0.4, 0.4),
		center * CFrame.new(0, -SIGN_DIAMETER / 2 - 0.2, 0),
		Color3.fromRGB(180, 180, 180),
		nil,
		false
	)
	mount.Parent = model

	local pole = makePole(CFrame.new(0, 0, 0))
	pole.Parent = model

	model.PrimaryPart = whiteDisc
	model:SetAttribute("SignType", "SpeedLimit")
	model:SetAttribute("SpeedLimit", limit)

	return model
end

function TrafficSignBuilder.createStopSign(): Model
	local model = Instance.new("Model")
	model.Name = "StopSign"

	local size = SIGN_DIAMETER + 0.5
	local center = CFrame.new(0, POLE_HEIGHT + size / 2 + 0.5, 0)

	-- Weisser Rand (groesseres Oktogon hinten).
	local whiteOctagon = makeOctagon(size + BORDER_WIDTH * 2, SIGN_THICKNESS + 0.05, Color3.fromRGB(250, 250, 250))
	whiteOctagon.CFrame = center
	whiteOctagon.Parent = model

	-- Rotes Oktogon (vorne).
	local redOctagon = makeOctagon(size, SIGN_THICKNESS, Color3.fromRGB(220, 30, 30))
	redOctagon.CFrame = center * CFrame.new(0, 0, (SIGN_THICKNESS + 0.05) / 2 + SIGN_THICKNESS / 2 + 0.02)
	redOctagon.Parent = model

	makeSurfaceText(redOctagon, "STOP", Color3.fromRGB(250, 250, 250))

	-- Befestigungspunkt.
	local mount = makePart(
		"Attachment",
		Vector3.new(0.4, 0.4, 0.4),
		center * CFrame.new(0, -size / 2 - 0.2, 0),
		Color3.fromRGB(180, 180, 180),
		nil,
		false
	)
	mount.Parent = model

	local pole = makePole(CFrame.new(0, 0, 0))
	pole.Parent = model

	model.PrimaryPart = redOctagon
	model:SetAttribute("SignType", "Stop")

	return model
end

return TrafficSignBuilder