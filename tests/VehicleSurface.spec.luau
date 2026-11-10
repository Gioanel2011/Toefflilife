--!strict
-- VehicleSurface.spec: prueft die reinen Strassen- und Fahrregeln. Keine
-- Roblox-Laufzeit. Laeuft mit `lune run tests/VehicleSurface.spec.luau`.

local RoadSurface = require("../src/server/world/RoadSurface")
local VehicleMotion = require("../src/client/controllers/VehicleMotion")

local passed = 0
local function check(condition: boolean, label: string)
	assert(condition, "FAIL: " .. label)
	passed += 1
	print("PASS: " .. label)
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- 1. Oberste Terrainvoxelreihe: Asphalt wird exakt dort eingefaerbt.
check(approx(RoadSurface.cellTop(8), 8), "CellTopOnBoundary")
check(approx(RoadSurface.cellTop(8.1), 12), "CellTopRoundsUp")
check(approx(RoadSurface.cellTop(7.9), 8), "CellTopBelowBoundary")
check(approx(RoadSurface.cellTop(0), 0), "CellTopZero")
check(approx(RoadSurface.cellTop(-5), -4), "CellTopNegative")
check(approx(RoadSurface.cellTop(-4.1), -4), "CellTopNegativeBoundary")

-- 2. Stempel liegt mittig in der obersten Voxelreihe.
check(approx(RoadSurface.paintCenterY(8.1), 12 - RoadSurface.VOXEL / 2), "PaintCenterTopBand")
check(approx(RoadSurface.paintCenterY(7.9), 8 - RoadSurface.VOXEL / 2), "PaintCenterLowerBand")
check(RoadSurface.paintSize() < RoadSurface.VOXEL, "PaintSmallerThanVoxel")
check(RoadSurface.paintSize() > RoadSurface.VOXEL - 1, "PaintNearlyVoxel")

-- 3. Abschnitte fuer Linien.
check(RoadSurface.stepsFor(0) == 1, "StepsZero")
check(RoadSurface.stepsFor(RoadSurface.STEP_LENGTH) == 1, "StepsOne")
check(RoadSurface.stepsFor(RoadSurface.STEP_LENGTH + 0.1) == 2, "StepsTwo")
check(RoadSurface.stepsFor(1e9) == RoadSurface.MAX_STEPS, "StepsCapped")
check(RoadSurface.validate(), "RoadSurfaceValidationPasses")

-- 4. Bodenverfolgung (VehicleMotion bleibt fuer die Physik-Huelle).
check(approx(VehicleMotion.groundPivotY(5, 0.7), 5.7), "GroundPivotAddsHeight")
local flat = VehicleMotion.nextPivotY(5.7, 5.7, 0.7)
check(not flat.blocked and approx(flat.y, 6.4), "FlatGroundFollows")
local downhill = VehicleMotion.nextPivotY(5.7, 4.0, 0.7)
check(not downhill.blocked and approx(downhill.y, 4.7), "DownhillFollows")
local wall = VehicleMotion.nextPivotY(5.7, 8.0, 0.7)
check(wall.blocked and approx(wall.y, 5.7), "HighStepBlocks")
local steap = VehicleMotion.nextPivotY(5.7, 6.5, 0.7, 0.5)
check(steap.blocked, "CustomStepLimitBlocks")
local gentle = VehicleMotion.nextPivotY(5.7, 5.4, 0.7, 0.5)
check(not gentle.blocked and approx(gentle.y, 6.1), "CustomStepLimitAllows")

-- 5. Wandsonde und Bewegungsgrenze.
check(approx(VehicleMotion.probeDistance(2), 2 + VehicleMotion.FRONT_PROBE), "ProbeAddsStep")
check(approx(VehicleMotion.probeDistance(-1), VehicleMotion.FRONT_PROBE), "ProbeNeverNegative")
check(approx(VehicleMotion.probeDistance(2, 0.5), 2.5), "ProbeCustom")
check(not VehicleMotion.isMoving(0.005), "IdleIgnored")
check(VehicleMotion.isMoving(0.02), "ForwardDetected")
check(VehicleMotion.isMoving(-0.02), "ReverseDetected")
check(VehicleMotion.validate(), "VehicleMotionValidationPasses")

print(string.format("VehicleSurface.spec: %d checks passed", passed))
