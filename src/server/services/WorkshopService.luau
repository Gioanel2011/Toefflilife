--!strict
-- WorkshopService: Server-validierte Werkstattaktionen (Einbau, Ausbau, Lackierung).
-- Nur bei aktivem Werkstattzustand. Laptop-Quellen werden grundsaetzlich abgewiesen.

export type VehicleRecord = {
	modelId: string,
	parts: { [string]: string },
	colors: { [string]: string },
	stats: any?,
}

export type ProfileRecord = {
	vehicles: { [string]: VehicleRecord },
	inventory: { [string]: number },
}

export type PartInfo = {
	slot: string,
	models: { string }?,
}

export type WorkshopDeps = {
	profiles: { [string]: ProfileRecord },
	parts: { [string]: PartInfo }?,
	isWorkshopActive: ((playerId: string) -> boolean)?,
	computeStats: ((modelId: string, parts: { [string]: string }) -> any)?,
}

local WorkshopService = {}
WorkshopService.__index = WorkshopService

export type WorkshopService = typeof(setmetatable(
	{} :: {
		_profiles: { [string]: ProfileRecord },
		_parts: { [string]: PartInfo },
		_isWorkshopActive: (playerId: string) -> boolean,
		_computeStats: ((modelId: string, parts: { [string]: string }) -> any)?,
	},
	WorkshopService
))

local function defaultInactive(_playerId: string): boolean
	return false
end

function WorkshopService.new(deps: WorkshopDeps)
	local self = setmetatable({}, WorkshopService)
	self._profiles = deps.profiles
	self._parts = deps.parts or ({} :: { [string]: PartInfo })
	if deps.isWorkshopActive ~= nil then
		self._isWorkshopActive = deps.isWorkshopActive :: (playerId: string) -> boolean
	else
		self._isWorkshopActive = defaultInactive
	end
	self._computeStats = deps.computeStats
	return self
end

function WorkshopService:_checkSource(source: string?): (boolean, string?)
	if source == "laptop" then
		return false, "LaptopNotAllowed"
	end
	return true, nil
end

function WorkshopService:_checkWorkshop(playerId: string): (boolean, string?)
	local ok, _err = self:_checkSource(nil)
	if not ok then
		return false, _err
	end
	local active = self._isWorkshopActive(playerId)
	if not active then
		return false, "WorkshopInactive"
	end
	return true, nil
end

function WorkshopService:_getVehicle(playerId: string, vehicleId: string): (ProfileRecord?, VehicleRecord?, string?)
	local profile = self._profiles[playerId]
	if profile == nil then
		return nil, nil, "ProfileNotFound"
	end
	local vehicle = profile.vehicles[vehicleId]
	if vehicle == nil then
		return profile, nil, "VehicleNotOwned"
	end
	return profile, vehicle, nil
end

local function isModelAllowed(part: PartInfo, modelId: string): boolean
	if part.models == nil then
		return true
	end
	local models = part.models :: { string }
	if #models == 0 then
		return true
	end
	for _, m in models do
		if m == modelId then
			return true
		end
	end
	return false
end

function WorkshopService:_refreshStats(vehicle: VehicleRecord)
	if self._computeStats ~= nil then
		local fn = self._computeStats :: (modelId: string, parts: { [string]: string }) -> any
		vehicle.stats = fn(vehicle.modelId, vehicle.parts)
	end
end

-- Baut ein Teil aus dem Inventar in das Fahrzeug ein.
-- opts: { source: string? } ("workshop" erwartet, "laptop" wird abgewiesen)
function WorkshopService:installPart(playerId: string, vehicleId: string, partId: string, opts: { source: string? }?): (boolean, string?)
	local source: string? = nil
	if opts ~= nil then
		source = opts.source
	end
	local okSource, errSource = self:_checkSource(source)
	if not okSource then
		return false, errSource
	end
	local okShop, errShop = self:_checkWorkshop(playerId)
	if not okShop then
		return false, errShop
	end
	local profile, vehicle, errVehicle = self:_getVehicle(playerId, vehicleId)
	if errVehicle ~= nil then
		return false, errVehicle
	end
	local part = self._parts[partId]
	if part == nil then
		return false, "PartNotFound"
	end
	local ownedVehicle = vehicle :: VehicleRecord
	if not isModelAllowed(part, ownedVehicle.modelId) then
		return false, "IncompatiblePart"
	end
	local ownedProfile = profile :: ProfileRecord
	local count = ownedProfile.inventory[partId] or 0
	if count <= 0 then
		return false, "PartNotInInventory"
	end
	-- Atomares Update: erst hier mutieren.
	ownedProfile.inventory[partId] = count - 1
	ownedVehicle.parts[part.slot] = partId
	self:_refreshStats(ownedVehicle)
	return true, nil
end

-- Baut ein Teil aus und legt es ins Inventar zurueck.
function WorkshopService:removePart(playerId: string, vehicleId: string, slot: string, opts: { source: string? }?): (boolean, string?)
	local source: string? = nil
	if opts ~= nil then
		source = opts.source
	end
	local okSource, errSource = self:_checkSource(source)
	if not okSource then
		return false, errSource
	end
	local okShop, errShop = self:_checkWorkshop(playerId)
	if not okShop then
		return false, errShop
	end
	local profile, vehicle, errVehicle = self:_getVehicle(playerId, vehicleId)
	if errVehicle ~= nil then
		return false, errVehicle
	end
	local ownedVehicle = vehicle :: VehicleRecord
	local installed = ownedVehicle.parts[slot]
	if installed == nil then
		return false, "SlotEmpty"
	end
	local ownedProfile = profile :: ProfileRecord
	-- Atomares Update.
	ownedVehicle.parts[slot] = nil
	ownedProfile.inventory[installed] = (ownedProfile.inventory[installed] or 0) + 1
	self:_refreshStats(ownedVehicle)
	return true, nil
end

local function isHexColor(value: string): boolean
	if #value ~= 7 then
		return false
	end
	if string.sub(value, 1, 1) ~= "#" then
		return false
	end
	local hex = string.sub(value, 2, 7)
	return string.match(hex, "^%x%x%x%x%x%x$") ~= nil
end

-- Lackiert eine Flaeche des Fahrzeugs.
-- paint: { surface: string, color: string } mit Hex-Farbe wie "#FF0000".
function WorkshopService:paint(
	playerId: string,
	vehicleId: string,
	paint: { surface: string, color: string },
	opts: { source: string? }?
): (boolean, string?)
	local source: string? = nil
	if opts ~= nil then
		source = opts.source
	end
	local okSource, errSource = self:_checkSource(source)
	if not okSource then
		return false, errSource
	end
	local okShop, errShop = self:_checkWorkshop(playerId)
	if not okShop then
		return false, errShop
	end
	local _profile, vehicle, errVehicle = self:_getVehicle(playerId, vehicleId)
	if errVehicle ~= nil then
		return false, errVehicle
	end
	if paint.surface == "" then
		return false, "InvalidSurface"
	end
	if not isHexColor(paint.color) then
		return false, "InvalidColor"
	end
	local ownedVehicle = vehicle :: VehicleRecord
	-- Atomares Update.
	ownedVehicle.colors[paint.surface] = paint.color
	self:_refreshStats(ownedVehicle)
	return true, nil
end

return WorkshopService
