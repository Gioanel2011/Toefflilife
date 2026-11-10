--!strict
-- RoadSurface: reine Regeln fuer den buendig in das Terrain gemalten Asphalt.
-- Keine Roblox-Instanzen, damit die Werte mit `lune run` geprueft werden.
-- Die Strasse ist die oberste Terrain-Voxelreihe mit Material Asphalt; sie
-- kann dadurch weder schweben noch im Gras verschwinden.

local RoadSurface = {}

-- Terrain-Voxelraster in Studs.
RoadSurface.VOXEL = 4
-- Leichter Innenabstand beim Stempeln, damit keine Nachbarvoxel mitgefaerbt werden.
RoadSurface.PAINT_INSET = 0.05
-- Hoehe der Mittellinie ueber der Asphaltoberflaeche.
RoadSurface.LINE_LIFT = 0.06
-- Sichtbare Dicke des Brueckendecks.
RoadSurface.BRIDGE_THICKNESS = 0.4
-- Abschnittslaenge fuer Mittellinie/Haltelinie (eine Voxelzelle).
RoadSurface.STEP_LENGTH = 4
RoadSurface.MAX_STEPS = 400

-- Obere Kante der Terrain-Voxelreihe, in der analytischen Hoehe `terrainY`.
function RoadSurface.cellTop(terrainY: number): number
	return math.ceil(terrainY / RoadSurface.VOXEL) * RoadSurface.VOXEL
end

function RoadSurface.stepsFor(length2D: number): number
	if length2D < 0.1 then
		return 1
	end
	return math.clamp(math.ceil(length2D / RoadSurface.STEP_LENGTH), 1, RoadSurface.MAX_STEPS)
end

-- Kantenlaenge des Stempelwuerfels (etwas kleiner als eine Voxel).
function RoadSurface.paintSize(): number
	return RoadSurface.VOXEL - RoadSurface.PAINT_INSET * 2
end

-- Y-Mittelpunkt des Stempels fuer die oberste Voxelreihe.
function RoadSurface.paintCenterY(terrainY: number): number
	return RoadSurface.cellTop(terrainY) - RoadSurface.VOXEL / 2
end

function RoadSurface.validate(): boolean
	assert(RoadSurface.VOXEL > 0, "VOXEL must be positive")
	assert(RoadSurface.PAINT_INSET >= 0 and RoadSurface.PAINT_INSET < RoadSurface.VOXEL / 2, "PAINT_INSET invalid")
	assert(RoadSurface.LINE_LIFT >= 0, "LINE_LIFT must not be negative")
	assert(RoadSurface.BRIDGE_THICKNESS > 0, "BRIDGE_THICKNESS must be positive")
	assert(RoadSurface.STEP_LENGTH > 0, "STEP_LENGTH must be positive")
	return true
end

assert(RoadSurface.validate(), "RoadSurface failed validation on load")

return RoadSurface
