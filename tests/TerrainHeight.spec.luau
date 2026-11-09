--!strict
-- TerrainHeight.spec: Lune-Pruefung fuer Task 09.
-- Prueft Determinismus, endliche Werte, flache Bauzonen, maximale
-- Strassensteigung und flache Seeufer.

local function tryRequire(names: { string }): any
	local lastError: string? = nil
	for _, name in names do
		local ok, module = pcall(require, name)
		if ok then
			return module
		else
			lastError = tostring(module)
		end
	end
	error("require fehlgeschlagen: " .. tostring(lastError), 2)
end

local TerrainHeight: any = tryRequire({
	"../src/server/world/TerrainHeight",
	"./../src/server/world/TerrainHeight",
	"src/server/world/TerrainHeight",
})
local WorldLayout: any = tryRequire({
	"../src/server/world/WorldLayout",
	"./../src/server/world/WorldLayout",
	"src/server/world/WorldLayout",
})
local WorldZones: any = tryRequire({
	"../src/server/world/WorldZones",
	"./../src/server/world/WorldZones",
	"src/server/world/WorldZones",
})

local passed = 0

local function check(condition: boolean, message: string)
	if not condition then
		error("FAIL: " .. message, 2)
	end
	passed += 1
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) < 1000000
end

local function point(x: number, z: number): { x: number, y: number, z: number }
	return { x = x, y = 0, z = z }
end

-- 1. Determinismus ----------------------------------------------------------
local deterministicPoints = {
	{ 0, 0 },
	{ 10, 20 },
	{ -320, -280 },
	{ 500, -430 },
	{ 0, -480 },
}
for _, entry in deterministicPoints do
	local x: number = entry[1]
	local z: number = entry[2]
	check(TerrainHeight.heightAt(x, z) == TerrainHeight.heightAt(x, z), "heightAt deterministisch")
	check(TerrainHeight.slopeAt(x, z) == TerrainHeight.slopeAt(x, z), "slopeAt deterministisch")
end

-- 2. Endliche Werte ----------------------------------------------------------
for x = -600, 600, 200 do
	for z = -600, 600, 200 do
		local height: number = TerrainHeight.heightAt(x, z)
		local slope: number = TerrainHeight.slopeAt(x, z)
		check(isFinite(height), "heightAt endlich")
		check(isFinite(slope) and slope >= 0, "slopeAt endlich und nicht negativ")
	end
end

-- Berge als Wasserquellen hoch, Tal flach ------------------------------------
local mountainHeight: number = TerrainHeight.heightAt(560, 560)
check(mountainHeight > 30, "Berge an den Raendern hoch")
local valleyHeight: number = TerrainHeight.heightAt(0, 0)
check(math.abs(valleyHeight) < 8, "Tal flach")
local lakeBottom: number = TerrainHeight.heightAt(WorldZones.LAKE.center.x, WorldZones.LAKE.center.z)
check(lakeBottom < -2, "See liegt vertieft")

-- 3. Flache Bauzonen ----------------------------------------------------------
local function spreadAt(cx: number, cz: number, radius: number): number
	local minimum = math.huge
	local maximum = -math.huge
	for dx = -radius, radius, radius do
		for dz = -radius, radius, radius do
			local height: number = TerrainHeight.heightAt(cx + dx, cz + dz)
			if height < minimum then
				minimum = height
			end
			if height > maximum then
				maximum = height
			end
		end
	end
	return maximum - minimum
end

check(
	spreadAt(WorldLayout.DONER.position.x, WorldLayout.DONER.position.z, 20) < 0.5,
	"Doenerplatz flach"
)
check(
	spreadAt(WorldLayout.VILLAGES[1].center.x, WorldLayout.VILLAGES[1].center.z, 40) < 0.5,
	"Dorfzentrum flach"
)
local firstSlot = WorldLayout.VILLAGES[1].slots[1]
check(
	spreadAt(firstSlot.position.x, firstSlot.position.z, 5) < 0.6,
	"Haus-Slot flach"
)
local firstGarage = WorldLayout.GARAGES[1]
check(
	spreadAt(firstGarage.position.x, firstGarage.position.z, 8) < 0.6,
	"Garage flach"
)

-- 4. Maximale Strassensteigung --------------------------------------------------
local function midpoint(from: any, to: any, t: number): (number, number)
	return from.x + (to.x - from.x) * t, from.z + (to.z - from.z) * t
end

local function checkRoads(roads: any, label: string)
	for _, road in roads do
		for _, t in { 0.25, 0.5, 0.75 } do
			local x, z = midpoint(road.from, road.to, t)
			local slope: number = TerrainHeight.slopeAt(x, z)
			check(isFinite(slope) and slope < 0.35, label .. " Steigung begrenzt")
		end
	end
end

checkRoads(WorldZones.ROAD_SEGMENTS, "Hauptstrasse")
checkRoads(WorldZones.STOP_ROADS, "Stopstrasse")

-- 5. Flache Seeufer --------------------------------------------------------------
local shoreHeights: { number } = {}
for index = 0, 7 do
	local angle = math.rad(index * 45)
	local x = WorldZones.LAKE.center.x + math.cos(angle) * (WorldZones.LAKE.radius + 12)
	local z = WorldZones.LAKE.center.z + math.sin(angle) * (WorldZones.LAKE.radius + 12)
	local height: number = TerrainHeight.heightAt(x, z)
	table.insert(shoreHeights, height)
	local slope: number = TerrainHeight.slopeAt(x, z)
	check(isFinite(slope) and slope < 0.35, "Seeufer flach")
end
local shoreMin = math.huge
local shoreMax = -math.huge
for _, height in shoreHeights do
	if height < shoreMin then
		shoreMin = height
	end
	if height > shoreMax then
		shoreMax = height
	end
end
check(shoreMax - shoreMin < 1.2, "Seeufer einheitlich flach")

-- Brueckenauffahrten flach ---------------------------------------------------------
for _, bridge in WorldZones.BRIDGE_CROSSINGS do
	local slope: number = TerrainHeight.slopeAt(bridge.position.x, bridge.position.z)
	check(isFinite(slope) and slope < 0.35, "Bruecke flach")
	check(
		spreadAt(bridge.position.x, bridge.position.z, 5) < 1.0,
		"Brueckenauffahrt eben"
	)
end

-- 6. Bauplaetze --------------------------------------------------------------------
check(TerrainHeight.isBuildPad(point(WorldLayout.DONER.position.x, WorldLayout.DONER.position.z)), "Doener ist Bauplatz")
check(TerrainHeight.isBuildPad(point(firstSlot.position.x, firstSlot.position.z)), "Haus-Slot ist Bauplatz")
check(TerrainHeight.isBuildPad(point(firstGarage.position.x, firstGarage.position.z)), "Garage ist Bauplatz")
check(
	not TerrainHeight.isBuildPad(point(WorldZones.LAKE.center.x, WorldZones.LAKE.center.z)),
	"See ist kein Bauplatz"
)
check(not TerrainHeight.isBuildPad(point(0, 400)), "Wildnis ist kein Bauplatz")

-- 7. Keine Mutation der Layoutdaten ----------------------------------------------------
local donerXBefore: number = WorldLayout.DONER.position.x
local garageXBefore: number = WorldLayout.GARAGES[1].position.x
TerrainHeight.heightAt(123, -321)
TerrainHeight.slopeAt(-200, 150)
TerrainHeight.isBuildPad(point(0, 0))
check(WorldLayout.DONER.position.x == donerXBefore, "Layoutdaten unveraendert")
check(WorldLayout.GARAGES[1].position.x == garageXBefore, "Garagendaten unveraendert")

print(string.format("TerrainHeight.spec: %d Checks bestanden", passed))
