--!strict
-- ConiferFactory: spitzige Low-Poly-Tannen aus einfachen Roblox-Parts.
-- Keine Instanzen ausserhalb des Models, keine Skripte, keine externen Mesh-IDs.
-- Deterministisch aus `seed`; `scale` ist optional (Standard 1).

local ConiferFactory = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, canCollide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	return part
end

function ConiferFactory.create(seed: number, scale: number?): Model
	local rng = Random.new(seed)
	local s = if scale == nil then 1 else scale
	if s <= 0 then
		s = 1
	end

	local model = Instance.new("Model")
	model.Name = "Conifer"

	-- Stamm: schlank, braun, leicht variiert.
	local trunkHeight = (7 + rng:NextNumber() * 5) * s
	local trunkDiameter = (0.5 + rng:NextNumber() * 0.35) * s
	local trunkColor = Color3.fromRGB(
		85 + math.floor(rng:NextNumber() * 25),
		50 + math.floor(rng:NextNumber() * 20),
		25 + math.floor(rng:NextNumber() * 15)
	)
	local trunk = makePart(
		"Trunk",
		Vector3.new(trunkHeight, trunkDiameter, trunkDiameter),
		CFrame.new(0, trunkHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		trunkColor,
		Enum.Material.Wood,
		true
	)
	trunk.Parent = model

	-- Kronen: mehrere gestaffelte, spitz zulaufende Stufen.
	local crownCount = 3 + math.floor(rng:NextNumber() * 2) -- 3 oder 4
	local baseRadius = (1.9 + rng:NextNumber() * 1.1) * s

	for c = 0, crownCount - 1 do
		local t = if crownCount > 1 then c / (crownCount - 1) else 0
		local crownBaseY = trunkHeight * (0.32 + 0.42 * t)
		local crownRadius = baseRadius * (1.05 - 0.62 * t) * (0.88 + rng:NextNumber() * 0.24)
		local tiers = 3 + math.floor(rng:NextNumber() * 2) -- 3 oder 4
		local tierHeight = (0.55 + rng:NextNumber() * 0.3) * s

		for i = 0, tiers - 1 do
			local frac = if tiers > 1 then i / (tiers - 1) else 0
			local halfExtent = crownRadius * (1 - frac * 0.88)
			if halfExtent < 0.15 * s then
				halfExtent = 0.15 * s
			end
			local y = crownBaseY + i * tierHeight
			local rotation = math.rad((i % 2) * 45 + math.floor(rng:NextNumber() * 12))
			local green = Color3.fromRGB(
				28 + math.floor(rng:NextNumber() * 22),
				88 + math.floor(rng:NextNumber() * 52),
				22 + math.floor(rng:NextNumber() * 18)
			)
			local crownPart = makePart(
				"Crown",
				Vector3.new(halfExtent * 2, tierHeight, halfExtent * 2),
				CFrame.new(0, y, 0) * CFrame.Angles(0, rotation, 0),
				green,
				Enum.Material.SmoothPlastic,
				false
			)
			crownPart.Parent = model
		end
	end

	model.PrimaryPart = trunk
	return model
end

return ConiferFactory