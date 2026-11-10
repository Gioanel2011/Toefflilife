--!strict
-- VehicleMotion: reine Rechenregeln fuer die clientseitige Arcade-Fahrt.
-- Keine Roblox-Instanzen, keine Raycasts, damit die Regeln mit `lune run`
-- geprueft werden koennen. Die Controller liefern nur die Messwerte.
-- Keine Preise, kein Besitz, keine Serverentscheidung.

export type GroundStep = {
	y: number,
	blocked: boolean,
}

local VehicleMotion = {}

-- Maximale Stufe, die ein Fahrzeug in einem Frame hochklettern darf.
VehicleMotion.MAX_STEP_UP = 1.5
-- Vorausschau vor dem Modellmittelpunkt, damit Waende nicht durchfahren werden.
VehicleMotion.FRONT_PROBE = 1.35
-- Start- und Suchtiefe des Boden-Raycasts.
VehicleMotion.GROUND_RAY_UP = 8
VehicleMotion.GROUND_RAY_DOWN = 12
-- Ab dieser horizontalen Geschwindigkeit wird der Boden verfolgt.
VehicleMotion.MOVE_EPSILON = 0.01

-- Zielhoehe des Model-Pivots aus einem Bodentreffer.
function VehicleMotion.groundPivotY(groundY: number, pivotHeight: number): number
	return groundY + pivotHeight
end

-- Naechste Pivot-Hoehe inklusive Steigungslimit. `blocked` bedeutet, dass die
-- Stufe zu hoch ist und die Bewegung verworfen werden soll.
function VehicleMotion.nextPivotY(
	currentPivotY: number,
	groundY: number,
	pivotHeight: number,
	maxStepUp: number?
): GroundStep
	local limit = maxStepUp or VehicleMotion.MAX_STEP_UP
	local target = VehicleMotion.groundPivotY(groundY, pivotHeight)
	if target - currentPivotY > limit then
		return { y = currentPivotY, blocked = true }
	end
	return { y = target, blocked = false }
end

-- Laenge des Wand-Raycasts: gefahrene Strecke plus Vorausschau.
function VehicleMotion.probeDistance(stepDistance: number, probe: number?): number
	local forward = math.max(stepDistance, 0)
	return forward + (probe or VehicleMotion.FRONT_PROBE)
end

-- Nur bei echter Bewegung Boden und Waende pruefen.
function VehicleMotion.isMoving(speed: number): boolean
	return math.abs(speed) > VehicleMotion.MOVE_EPSILON
end

function VehicleMotion.validate(): boolean
	assert(VehicleMotion.MAX_STEP_UP > 0, "MAX_STEP_UP must be positive")
	assert(VehicleMotion.FRONT_PROBE > 0, "FRONT_PROBE must be positive")
	assert(VehicleMotion.GROUND_RAY_UP > 0, "GROUND_RAY_UP must be positive")
	assert(VehicleMotion.GROUND_RAY_DOWN > 0, "GROUND_RAY_DOWN must be positive")
	assert(VehicleMotion.MOVE_EPSILON >= 0, "MOVE_EPSILON must not be negative")
	return true
end

assert(VehicleMotion.validate(), "VehicleMotion failed validation on load")

return VehicleMotion
