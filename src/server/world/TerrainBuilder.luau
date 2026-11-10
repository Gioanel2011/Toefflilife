--!strict
-- TerrainBuilder: begrenztes Gras-Terrain entlang TerrainHeight, mit sanften
-- Randbergen, See- und Bachbetten. Nutzt die Roblox-Terrain-API (keine Parts
-- als Bodenplatte). Keine braunen Materialien, kein Sand, keine offenen
-- unendlichen Flächen, keine globalen Variablen.
-- Strassen werden nicht mehr ausgestanzt: der Asphalt wird in RoadBuilder auf
-- die tatsaechliche Terrainoberflaeche gelegt.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldLayout = requireSibling("WorldLayout")
local TerrainHeight = requireSibling("TerrainHeight")

local TerrainBuilder = {}

-- Rasterzelle in Studs (Roblox-Terrain-Voxelraster).
local CELL_SIZE = 4
-- Untere Basis, ab der Terrain-Säulen gefüllt werden.
local BASE_Y = -12

function TerrainBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Terrain"

	local terrain = workspace.Terrain

	local bounds = WorldLayout.BOUNDS
	local minX = bounds.minX
	local maxX = bounds.maxX
	local minZ = bounds.minZ
	local maxZ = bounds.maxZ

	-- Altes Terrain im Zielbereich entfernen, damit der Aufbau reproduzierbar ist.
	terrain:Clear()

	-- Säulenweise Füllung entlang des Höhenmodells.
	local x = minX
	while x < maxX do
		local cx = x + CELL_SIZE / 2
		local z = minZ
		while z < maxZ do
			local cz = z + CELL_SIZE / 2
			local h = TerrainHeight.heightAt(cx, cz)
			local columnHeight = h - BASE_Y
			if columnHeight > 0.1 then
				local center = Vector3.new(cx, BASE_Y + columnHeight / 2, cz)
				local size = Vector3.new(CELL_SIZE, columnHeight, CELL_SIZE)
				terrain:FillBlock(CFrame.new(center), size, Enum.Material.Grass)
			end
			z += CELL_SIZE
		end
		x += CELL_SIZE
	end

	folder.Parent = parent
	return folder
end

return TerrainBuilder
