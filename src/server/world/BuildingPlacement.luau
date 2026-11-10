--!strict
-- BuildingPlacement: gemeinsames Vergroessern und Aufsetzen von Gebaeuden.
-- Modelle werden um einen einheitlichen Faktor skaliert und so verschoben,
-- dass ihre tiefste Stelle exakt auf dem Boden liegt. Keine Preise, keine
-- Gameplay-Logik, keine globalen Variablen.

local BuildingPlacement = {}

-- Tatsaechliche Bodenhoehe an (x, z) per Raycast (Terrain, Wasser, Parts).
-- Zur Bauzeit gibt es noch keine Fahrzeuge/Charaktere, daher ohne Filter.
function BuildingPlacement.surfaceAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 512, z), Vector3.new(0, -1024, 0), params)
	if hit ~= nil then
		return hit.Position.Y
	end
	return nil
end

-- Tiefste Stelle des Modells in Weltkoordinaten.
function BuildingPlacement.lowestY(model: Model): number?
	local lowest: number? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local bottom = (part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)).Position.Y
			if lowest == nil or bottom < lowest then
				lowest = bottom
			end
		end
	end
	return lowest
end

-- Skaliert das Modell einheitlich (idempotent genug fuer den Weltaufbau).
function BuildingPlacement.scale(model: Model, factor: number): ()
	if factor ~= 1 then
		model:ScaleTo(factor)
	end
end

-- Verschiebt das Modell vertikal so, dass die tiefste Stelle auf `groundY` liegt.
function BuildingPlacement.ground(model: Model, groundY: number): ()
	local lowest = BuildingPlacement.lowestY(model)
	if lowest == nil then
		return
	end
	model:TranslateBy(Vector3.new(0, groundY - lowest, 0))
end

-- Setzt ein am Ursprung gebautes Modell auf `groundY` an (x, z) mit Yaw.
-- Der Pivot-Abstand des Modells bleibt erhalten, damit die Basis bündig ist.
function BuildingPlacement.placeOnGround(
	model: Model,
	x: number,
	z: number,
	groundY: number,
	yawDegrees: number
): ()
	local pivot = model:GetPivot()
	local target = CFrame.new(x, groundY, z) * CFrame.Angles(0, math.rad(yawDegrees), 0)
	model:PivotTo(target * pivot)
end

return BuildingPlacement
