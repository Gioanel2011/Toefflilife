--!strict
-- BridgeBuilder: flache Bruecken an allen Wasserquerungen (BRIDGE_CROSSINGS).
-- Jede Bruecke verbindet die Fahrbahn stufenlos, besitzt sichtbare seitliche
-- Begrenzungen und liegt vollstaendig ueber dem Wasser. Das Deck ist horizontal
-- (nur Yaw), damit Auffahrten mit Fahrrad und Mofa flach befahrbar bleiben.
-- Keine Schilder, keine Kollision mit Bachufern.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")

local BridgeBuilder = {}

local DECK_THICKNESS = 1
local DECK_Y_OFFSET = 0.6
local RAIL_WIDTH = 0.6
local RAIL_HEIGHT = 1.2
local DECK_COLOR = Color3.fromRGB(70, 70, 75)
local RAIL_COLOR = Color3.fromRGB(180, 180, 185)

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
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Erzeugt alle Bruecken unter `parent` und gibt den Ordner zurueck.
function BridgeBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Bridges"

	for _, crossing in WorldZones.BRIDGE_CROSSINGS do
		local position = crossing.position
		local yaw = math.rad(crossing.yaw)
		local deckY = TerrainHeight.heightAt(position.x, position.z) + DECK_Y_OFFSET
		local base = CFrame.new(Vector3.new(position.x, deckY, position.z)) * CFrame.Angles(0, yaw, 0)

		local deck = makePart(
			root,
			crossing.id,
			Vector3.new(crossing.width, DECK_THICKNESS, crossing.length),
			base,
			DECK_COLOR,
			true
		)
		deck:SetAttribute("BridgeId", crossing.id)
		deck:SetAttribute("RoadId", crossing.roadId)
		deck:SetAttribute("WaterId", crossing.waterId)

		local railOffsetX = crossing.width / 2 - RAIL_WIDTH / 2
		local railLift = DECK_THICKNESS / 2 + RAIL_HEIGHT / 2
		for _, side in { -1, 1 } do
			local rail = makePart(
				root,
				string.format("%s_Rail_%s", crossing.id, if side < 0 then "A" else "B"),
				Vector3.new(RAIL_WIDTH, RAIL_HEIGHT, crossing.length),
				base * CFrame.new(railOffsetX * side, railLift, 0),
				RAIL_COLOR,
				true
			)
			rail:SetAttribute("BridgeId", crossing.id)
			rail:SetAttribute("RoadId", crossing.roadId)
			rail:SetAttribute("WaterId", crossing.waterId)
		end
	end

	root.Parent = parent
	return root
end

return BridgeBuilder
