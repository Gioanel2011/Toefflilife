--!strict
-- SpawnBuilder: setzt genau einen Start-Spawnpunkt am Doenerplatz auf den
-- tatsaechlichen Boden. Ohne SpawnLocation setzt Roblox Charaktere hoch in
-- der Luft ab; Fahrzeuge wuerden dann ebenfalls in der Luft spawnen.
-- Keine Preise, keine Gameplay-Logik, keine globalen Variablen.

local function requireSibling(name: string): any
	local ok, module = pcall(require, "./" .. name)
	if ok then
		return module
	end
	return require(script.Parent[name])
end

local TerrainHeight = requireSibling("TerrainHeight")
local BuildingPlacement = requireSibling("BuildingPlacement")

local SpawnBuilder = {}

SpawnBuilder.SPAWN_X = 0
SpawnBuilder.SPAWN_Z = 26

function SpawnBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Spawns"

	local x = SpawnBuilder.SPAWN_X
	local z = SpawnBuilder.SPAWN_Z
	local groundY = BuildingPlacement.surfaceAt(x, z) or TerrainHeight.heightAt(x, z)

	local pad = Instance.new("SpawnLocation")
	pad.Name = "StartSpawn"
	pad.Size = Vector3.new(12, 0.4, 12)
	pad.CFrame = CFrame.new(x, groundY + 0.2, z)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Neutral = true
	pad.Duration = 0
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Color = Color3.fromRGB(245, 245, 245)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Parent = folder

	folder.Parent = parent
	return folder
end

return SpawnBuilder
