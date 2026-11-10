--!strict
-- PlayerIds: kanonische serverseitige Spieler-IDs.
-- Studio-Mehrclient vergibt negative UserIds (-1..-8). Alle Services arbeiten
-- mit positiven Ganzzahlen; darum werden simulierte IDs ausschliesslich in
-- Studio auf einen reservierten positiven Bereich abgebildet. Keine
-- Roblox-Laufzeit, damit die Logik mit `lune run` testbar bleibt.
-- Keine globalen Variablen.

local PlayerIds = {}

-- Reservierter Bereich oberhalb realistischer Roblox-UserIds.
PlayerIds.SIMULATED_OFFSET = 9_000_000_000

local function isInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local number = value :: number
	if number ~= number then
		return false
	end
	if number == math.huge or number == -math.huge then
		return false
	end
	return math.floor(number) == number
end

-- Simulierte Studio-Clients erkennt man an der negativen UserId.
function PlayerIds.isSimulated(userId: any): boolean
	return isInteger(userId) and (userId :: number) < 0
end

-- `allowSimulated` darf nur in Studio (`RunService:IsStudio()`) true sein.
-- Liefert `nil` fuer IDs, die serverseitig nicht zulaessig sind.
function PlayerIds.canonical(userId: any, allowSimulated: boolean?): number?
	if not isInteger(userId) then
		return nil
	end
	local number = userId :: number
	if number > 0 then
		return number
	end
	if number < 0 and allowSimulated == true then
		return PlayerIds.SIMULATED_OFFSET + math.abs(number)
	end
	return nil
end

return PlayerIds
