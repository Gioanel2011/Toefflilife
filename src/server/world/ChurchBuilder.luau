--!strict
-- ChurchBuilder: genau eine dekorierte Dorfkirche.
-- Position, Drehung und Grundflaeche stammen aus WorldLayout.CHURCH,
-- die Bodenhoehe aus TerrainHeight. Keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local TerrainHeight = requireSibling("TerrainHeight")

local ChurchBuilder = {}

local WALL_COLOR = Color3.fromRGB(235, 230, 220)
local ROOF_COLOR = Color3.fromRGB(140, 60, 50)
local TRIM_COLOR = Color3.fromRGB(170, 170, 165)
local DOOR_COLOR = Color3.fromRGB(110, 70, 40)
local WINDOW_COLOR = Color3.fromRGB(170, 210, 230)
local CROSS_COLOR = Color3.fromRGB(210, 180, 80)

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = canCollide
	part.Parent = parent
	return part
end

-- Erzeugt genau ein Kirchen-Model an der vorgesehenen Position.
function ChurchBuilder.build(parent: Instance): Model
	local church = WorldLayout.CHURCH
	local groundY = TerrainHeight.heightAt(church.position.x, church.position.z)
	local base = CFrame.new(Vector3.new(church.position.x, groundY, church.position.z))
		* CFrame.Angles(0, math.rad(church.yaw), 0)

	local model = Instance.new("Model")
	model.Name = church.id

	-- Hauptschiff (12 x 7 x 20), leicht nach hinten versetzt fuer den Turm.
	local nave = makePart(model, "Nave", Vector3.new(12, 7, 20), base * CFrame.new(0, 3.5, 2), WALL_COLOR, true)

	-- Eigenstaendiges Satteldach: zwei geneigte Platten plus Firstbalken.
	local roofAngle = math.rad(35)
	makePart(model, "RoofLeft", Vector3.new(7, 0.4, 21), base * (CFrame.new(-2.9, 8.7, 2) * CFrame.Angles(0, 0, roofAngle)), ROOF_COLOR, true)
	makePart(model, "RoofRight", Vector3.new(7, 0.4, 21), base * (CFrame.new(2.9, 8.7, 2) * CFrame.Angles(0, 0, -roofAngle)), ROOF_COLOR, true)
	makePart(model, "RoofRidge", Vector3.new(0.6, 0.6, 21), base * CFrame.new(0, 10.3, 2), ROOF_COLOR, true)

	-- Turm an der Vorderseite mit eigenstaendigem Zeltdach.
	makePart(model, "Tower", Vector3.new(6, 14, 6), base * CFrame.new(0, 7, -10), WALL_COLOR, true)
	makePart(model, "TowerRoof", Vector3.new(7, 2.5, 7), base * CFrame.new(0, 15.2, -10), ROOF_COLOR, true)
	makePart(model, "TowerSpire", Vector3.new(4, 2, 4), base * CFrame.new(0, 17.4, -10), ROOF_COLOR, true)

	-- Zurueckhaltender Fassadenschmuck: goldenes Kreuz auf der Spitze.
	makePart(model, "CrossVertical", Vector3.new(0.4, 2.2, 0.4), base * CFrame.new(0, 19.5, -10), CROSS_COLOR, false)
	makePart(model, "CrossHorizontal", Vector3.new(1.4, 0.4, 0.4), base * CFrame.new(0, 19.7, -10), CROSS_COLOR, false)

	-- Klar erkennbares Portal: Pfosten, Sturz, Stufe und Eingangstuer.
	makePart(model, "PortalFrameLeft", Vector3.new(1, 6, 1), base * CFrame.new(-2, 3, -13), TRIM_COLOR, true)
	makePart(model, "PortalFrameRight", Vector3.new(1, 6, 1), base * CFrame.new(2, 3, -13), TRIM_COLOR, true)
	makePart(model, "PortalLintel", Vector3.new(5, 1, 1), base * CFrame.new(0, 6, -13), TRIM_COLOR, true)
	makePart(model, "PortalSteps", Vector3.new(6, 0.4, 3), base * CFrame.new(0, 0.2, -14.5), TRIM_COLOR, true)
	local door = makePart(model, "EntranceDoor", Vector3.new(3, 5, 0.6), base * CFrame.new(0, 2.5, -13), DOOR_COLOR, false)
	door:SetAttribute("IsChurchEntrance", true)

	-- Zurueckhaltende Fenster: Rosette ueber dem Portal, je zwei Seitenfenster.
	makePart(model, "RoseWindow", Vector3.new(2.4, 2.4, 0.4), base * CFrame.new(0, 8.5, -13.1), WINDOW_COLOR, false)
	makePart(model, "WindowLeft1", Vector3.new(0.4, 2.5, 2), base * CFrame.new(-6.1, 4, -2), WINDOW_COLOR, false)
	makePart(model, "WindowLeft2", Vector3.new(0.4, 2.5, 2), base * CFrame.new(-6.1, 4, 5), WINDOW_COLOR, false)
	makePart(model, "WindowRight1", Vector3.new(0.4, 2.5, 2), base * CFrame.new(6.1, 4, -2), WINDOW_COLOR, false)
	makePart(model, "WindowRight2", Vector3.new(0.4, 2.5, 2), base * CFrame.new(6.1, 4, 5), WINDOW_COLOR, false)

	model:SetAttribute("IsChurch", true)
	model:SetAttribute("ChurchId", church.id)
	model:SetAttribute("PoiKind", "church")
	model.PrimaryPart = nave
	model.Parent = parent
	return model
end

return ChurchBuilder
