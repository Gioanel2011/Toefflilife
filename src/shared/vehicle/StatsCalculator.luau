--!strict
-- StatsCalculator: gemeinsamer, deterministischer Fahrzeugstatistik-Rechner.
-- Versorgt Fahrphysik (Client) und Pruefstand (Server) mit identischen Werten.
-- Rein datengetrieben: nimmt Basiswerte + Teile entgegen, keine Katalog-Imports,
-- keine globalen Variablen, keine Mutation der Eingaben.

local StatsCalculator = {}

-- Slots mit Motorbezug: duerfen nicht an ein Fahrrad verbaut werden.
StatsCalculator.MOTOR_SLOTS = {
	cylinder = true,
	cylinderHead = true,
	carburetor = true,
	exhaust = true,
	airFilter = true,
	intakeManifold = true,
}

-- Slots, in denen hoechstens ein Teil pro Setup sitzen darf (alle bekannten Slots).
-- Unbekannte Slots werden akzeptiert, solange sie nicht doppelt belegt sind.
StatsCalculator.KNOWN_SLOTS = {
	cylinder = true,
	cylinderHead = true,
	carburetor = true,
	exhaust = true,
	airFilter = true,
	intakeManifold = true,
	handlebar = true,
	brakes = true,
	wheels = true,
	rims = true,
	lamp = true,
}

-- Plausible Arcade-Clamps (deterministisch, Dyno + Physik teilen sie).
StatsCalculator.LIMITS = {
	powerKw = { min = 0.1, max = 30 },
	torqueNm = { min = 0, max = 60 },
	topSpeedKmh = { min = 5, max = 120 },
	acceleration = { min = 0.5, max = 15 },
	braking = { min = 1, max = 30 },
	grip = { min = 0.1, max = 3 },
	consumption = { min = 0, max = 10 },
	weightKg = { min = 5, max = 300 },
}

export type TorquePoint = { rpm: number, torqueNm: number }
export type StatDeltas = {
	powerKw: number?,
	torqueNm: number?,
	topSpeedKmh: number?,
	acceleration: number?,
	braking: number?,
	grip: number?,
	consumption: number?,
	weightKg: number?,
}
export type BaseVehicle = {
	id: string,
	modelId: string?,
	powerKw: number,
	torqueNm: number,
	topSpeedKmh: number,
	acceleration: number,
	braking: number,
	grip: number,
	consumption: number,
	weightKg: number?,
}
export type Part = {
	id: string,
	slot: string,
	compatibleModels: { string }?,
	statDeltas: StatDeltas?,
}
export type VehicleStats = {
	vehicleId: string,
	powerKw: number,
	peakTorqueNm: number,
	torqueCurve: { TorquePoint },
	topSpeedKmh: number,
	acceleration: number,
	braking: number,
	grip: number,
	consumptionPer100Km: number,
	weightKg: number,
	partCount: number,
}

local function round3(value: number): number
	if value >= 0 then
		return math.floor(value * 1000 + 0.5) / 1000
	else
		return math.ceil(value * 1000 - 0.5) / 1000
	end
end

local function clamp(value: number, minValue: number, maxValue: number): number
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	else
		return value
	end
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function modelKeyOf(base: BaseVehicle): string
	if type(base.modelId) == "string" and (base.modelId :: string) ~= "" then
		return base.modelId :: string
	end
	return base.id
end

local function isBicycle(base: BaseVehicle): boolean
	local key = string.lower(modelKeyOf(base))
	return key == "bicycle" or key == "bike" or key == "fahrrad" or key == "startfahrrad"
end

-- Drehmomentverlauf aus Spitzenleistung/-moment. Fixe 5-Punkt-Kurve,
-- damit Dyno-Anzeige und Physik exakt dieselbe Kurve sehen.
function StatsCalculator.calculateTorqueCurve(powerKw: number, peakTorqueNm: number): { TorquePoint }
	if not isFiniteNumber(powerKw) or not isFiniteNumber(peakTorqueNm) then
		return {}
	end
	if peakTorqueNm <= 0 or powerKw <= 0 then
		return {}
	end
	local shape = {
		{ rpm = 2000, factor = 0.55 },
		{ rpm = 4000, factor = 0.8 },
		{ rpm = 6000, factor = 1.0 },
		{ rpm = 7500, factor = 0.9 },
		{ rpm = 9000, factor = 0.7 },
	}
	local curve: { TorquePoint } = {}
	for _, point in ipairs(shape) do
		table.insert(curve, {
			rpm = point.rpm,
			torqueNm = round3(peakTorqueNm * point.factor),
		})
	end
	return curve
end

-- Prueft nur die Setup-Gueltigkeit (Slots, Kompatibilitaet), ohne zu rechnen.
function StatsCalculator.validateSetup(base: any, parts: any): (boolean, string?)
	if type(base) ~= "table" then
		return false, "base must be a table"
	end
	local baseVehicle = base :: BaseVehicle
	if type(baseVehicle.id) ~= "string" or baseVehicle.id == "" then
		return false, "base.id must be a non-empty string"
	end
	for _, field in ipairs({ "powerKw", "torqueNm", "topSpeedKmh", "acceleration", "braking", "grip", "consumption" }) do
		local value = (baseVehicle :: any)[field]
		if not isFiniteNumber(value) then
			return false, "base." .. field .. " must be a finite number"
		end
	end
	if baseVehicle.powerKw <= 0 then
		return false, "base.powerKw must be positive"
	end
	if baseVehicle.topSpeedKmh <= 0 then
		return false, "base.topSpeedKmh must be positive"
	end
	if parts ~= nil and type(parts) ~= "table" then
		return false, "parts must be an array table or nil"
	end
	local seenSlots: { [string]: boolean } = {}
	local modelKey = modelKeyOf(baseVehicle)
	local bicycle = isBicycle(baseVehicle)
	for index, partAny in ipairs((parts or {}) :: any) do
		if type(partAny) ~= "table" then
			return false, "parts[" .. tostring(index) .. "] must be a table"
		end
		local part = partAny :: Part
		if type(part.id) ~= "string" or part.id == "" then
			return false, "parts[" .. tostring(index) .. "].id must be a non-empty string"
		end
		if type(part.slot) ~= "string" or part.slot == "" then
			return false, "parts[" .. tostring(index) .. "].slot must be a non-empty string"
		end
		if seenSlots[part.slot] then
			return false, "duplicate slot: " .. part.slot
		end
		seenSlots[part.slot] = true
		if bicycle and StatsCalculator.MOTOR_SLOTS[part.slot] then
			return false, "bicycle has no motor slot: " .. part.slot
		end
		if part.compatibleModels ~= nil then
			if type(part.compatibleModels) ~= "table" then
				return false, "parts[" .. tostring(index) .. "].compatibleModels must be an array"
			end
			local compatible = false
			for _, model in ipairs(part.compatibleModels) do
				if model == modelKey or model == baseVehicle.id then
					compatible = true
					break
				end
			end
			if not compatible then
				return false, "part " .. part.id .. " incompatible with " .. modelKey
			end
		end
		if part.statDeltas ~= nil then
			if type(part.statDeltas) ~= "table" then
				return false, "parts[" .. tostring(index) .. "].statDeltas must be a table"
			end
			for deltaKey, deltaValue in pairs(part.statDeltas :: any) do
				if deltaValue ~= nil and not isFiniteNumber(deltaValue) then
					return false,
						"parts["
							.. tostring(index)
							.. "].statDeltas."
							.. tostring(deltaKey)
							.. " must be a finite number"
				end
			end
		end
	end
	return true, nil
end

-- Hauptfunktion: Basis + Teile -> abgeleitete Stats. Gibt (nil, Fehler) bei
-- ungueltigen oder inkompatiblen Setups zurueck; sonst (Stats, nil).
function StatsCalculator.calculate(base: any, parts: any): (VehicleStats?, string?)
	local ok, err = StatsCalculator.validateSetup(base, parts)
	if not ok then
		return nil, err
	end
	local baseVehicle = base :: BaseVehicle
	local partList: { Part } = (parts or {}) :: { Part }

	local sumPower = 0
	local sumTorque = 0
	local sumTopSpeed = 0
	local sumAccel = 0
	local sumBraking = 0
	local sumGrip = 0
	local sumConsumption = 0
	local sumWeight = 0
	for _, part in ipairs(partList) do
		local deltas: any = part.statDeltas or {}
		if deltas.powerKw ~= nil then
			sumPower += deltas.powerKw
		end
		if deltas.torqueNm ~= nil then
			sumTorque += deltas.torqueNm
		end
		if deltas.topSpeedKmh ~= nil then
			sumTopSpeed += deltas.topSpeedKmh
		end
		if deltas.acceleration ~= nil then
			sumAccel += deltas.acceleration
		end
		if deltas.braking ~= nil then
			sumBraking += deltas.braking
		end
		if deltas.grip ~= nil then
			sumGrip += deltas.grip
		end
		if deltas.consumption ~= nil then
			sumConsumption += deltas.consumption
		end
		if deltas.weightKg ~= nil then
			sumWeight += deltas.weightKg
		end
	end

	local limits = StatsCalculator.LIMITS
	local power = baseVehicle.powerKw + sumPower
	local torque = baseVehicle.torqueNm + sumTorque
	local topSpeed = baseVehicle.topSpeedKmh + sumTopSpeed
	local accel = baseVehicle.acceleration + sumAccel
	local braking = baseVehicle.braking + sumBraking
	local grip = baseVehicle.grip + sumGrip
	local consumption = baseVehicle.consumption + sumConsumption
	local baseWeight = baseVehicle.weightKg or 80
	if not isFiniteNumber(baseWeight) then
		return nil, "base.weightKg must be a finite number"
	end
	local weight = baseWeight + sumWeight

	-- Harte Ablehnung vor dem Clampen: physikalisch unsinnige Ergebnisse.
	if power <= 0 then
		return nil, "resulting power must be positive"
	end
	if topSpeed <= 0 then
		return nil, "resulting topSpeed must be positive"
	end
	if torque < 0 or braking <= 0 or grip <= 0 or weight <= 0 then
		return nil, "resulting stats implausible"
	end
	if consumption < 0 then
		return nil, "resulting consumption must not be negative"
	end
	-- Fahrrad: kein Treibstoff, kein Motordrehmoment.
	if isBicycle(baseVehicle) then
		if consumption ~= 0 then
			return nil, "bicycle must not consume fuel"
		end
		if torque ~= 0 then
			return nil, "bicycle has no engine torque"
		end
	end

	power = clamp(power, limits.powerKw.min, limits.powerKw.max)
	torque = clamp(torque, limits.torqueNm.min, limits.torqueNm.max)
	topSpeed = clamp(topSpeed, limits.topSpeedKmh.min, limits.topSpeedKmh.max)
	accel = clamp(accel, limits.acceleration.min, limits.acceleration.max)
	braking = clamp(braking, limits.braking.min, limits.braking.max)
	grip = clamp(grip, limits.grip.min, limits.grip.max)
	consumption = clamp(consumption, limits.consumption.min, limits.consumption.max)
	weight = clamp(weight, limits.weightKg.min, limits.weightKg.max)

	local stats: VehicleStats = {
		vehicleId = baseVehicle.id,
		powerKw = round3(power),
		peakTorqueNm = round3(torque),
		torqueCurve = StatsCalculator.calculateTorqueCurve(power, torque),
		topSpeedKmh = round3(topSpeed),
		acceleration = round3(accel),
		braking = round3(braking),
		grip = round3(grip),
		consumptionPer100Km = round3(consumption),
		weightKg = round3(weight),
		partCount = #partList,
	}
	return stats, nil
end

return StatsCalculator
