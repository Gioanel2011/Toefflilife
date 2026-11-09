--!strict
-- WaterBuilder: See und drei Bergbaeche als Roblox-Terrain-Wasser.
-- Erzeugt genau einen See und drei durchgehende Baeche von den Bergquellen
-- bis zur Muendung in den See. Keine Strassen, Bruecken oder Schilder.
-- Keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local WorldZones = requireSibling("WorldZones")
local TerrainHeight = requireSibling("TerrainHeight")

local WaterBuilder = {}

local CELL_SIZE = 4
local LAKE_DEPTH = 12
local STREAM_DEPTH = 3

local function fillColumn(terrain: Terrain, cx: number, cz: number, bottomY: number, topY: number)
	if topY <= bottomY then
		return
	end
	local height = topY - bottomY
	local center = Vector3.new(cx, bottomY + height / 2, cz)
	local size = Vector3.new(CELL_SIZE, height, CELL_SIZE)
	terrain:FillBlock(CFrame.new(center), size, Enum.Material.Water)
end

function WaterBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Water"

	local terrain = workspace.Terrain

	-- See: kreisfoermige Wasserflaeche, Oberflaeche auf Uferhoehe.
	local lake = WorldZones.LAKE
	local lakeCx = lake.center.x
	local lakeCz = lake.center.z
	local lakeRadius = lake.radius
	local shoreSurface = TerrainHeight.heightAt(lakeCx, lakeCz + lakeRadius)

	local minX = lakeCx - lakeRadius - CELL_SIZE
	local maxX = lakeCx + lakeRadius + CELL_SIZE
	local minZ = lakeCz - lakeRadius - CELL_SIZE
	local maxZ = lakeCz + lakeRadius + CELL_SIZE

	local x = minX
	while x < maxX do
		local cx = x + CELL_SIZE / 2
		local z = minZ
		while z < maxZ do
			local cz = z + CELL_SIZE / 2
			local dist = math.sqrt((cx - lakeCx) ^ 2 + (cz - lakeCz) ^ 2)
			if dist <= lakeRadius then
				fillColumn(terrain, cx, cz, shoreSurface - LAKE_DEPTH, shoreSurface)
			end
			z += CELL_SIZE
		end
		x += CELL_SIZE
	end

	-- Drei Baeche: durchgehende Wasserstreifen entlang der definierten Punkte.
	for _, stream in WorldZones.STREAMS do
		local halfWidth = stream.width / 2
		for segIndex = 1, #stream.points - 1 do
			local a = stream.points[segIndex]
			local b = stream.points[segIndex + 1]

			local minSegX = math.min(a.x, b.x) - halfWidth - CELL_SIZE
			local maxSegX = math.max(a.x, b.x) + halfWidth + CELL_SIZE
			local minSegZ = math.min(a.z, b.z) - halfWidth - CELL_SIZE
			local maxSegZ = math.max(a.z, b.z) + halfWidth + CELL_SIZE

			local segDx = b.x - a.x
			local segDz = b.z - a.z
			local lenSq = segDx * segDx + segDz * segDz

			local sx = minSegX
			while sx < maxSegX do
				local cx = sx + CELL_SIZE / 2
				local sz = minSegZ
				while sz < maxSegZ do
					local cz = sz + CELL_SIZE / 2
					local t = 0
					if lenSq > 0 then
						t = ((cx - a.x) * segDx + (cz - a.z) * segDz) / lenSq
						if t < 0 then
							t = 0
						elseif t > 1 then
							t = 1
						end
					end
					local projX = a.x + segDx * t
					local projZ = a.z + segDz * t
					local d = math.sqrt((cx - projX) ^ 2 + (cz - projZ) ^ 2)
					if d <= halfWidth then
						local surfaceY = TerrainHeight.heightAt(cx, cz)
						fillColumn(terrain, cx, cz, surfaceY - STREAM_DEPTH, surfaceY)
					end
					sz += CELL_SIZE
				end
				sx += CELL_SIZE
			end
		end
	end

	folder.Parent = parent
	return folder
end

return WaterBuilder