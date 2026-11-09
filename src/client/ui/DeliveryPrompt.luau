--!strict
-- DeliveryPrompt: kleines PC-Lieferprompt für Döner-Aufträge.
-- Sendet ausschliesslich die versionierten Delivery-Remote-Anfragen.
-- Keine Preise, Distanzen, Belohnungen oder Erfolge werden clientseitig entschieden.
-- Keine Tastenbindung für E, damit das Fahrrad-Aufsteigen ungestört bleibt.

export type DeliveryClient = {
	request: (self: DeliveryClient, action: string, payload: any) -> any,
	getVehicleType: (() -> string)?,
}

export type DeliveryPrompt = {
	_client: DeliveryClient?,
	_getVehicleType: (() -> string)?,
	_remotes: Instance?,
	_vehicleType: string,
	_state: string,
	_orderId: string?,
	_addressId: string?,
	_isOpen: boolean,
	_gui: GuiObject?,
	_statusLabel: TextLabel?,
	_actionButton: TextButton?,
	open: (self: DeliveryPrompt) -> (),
	close: (self: DeliveryPrompt) -> (),
	isOpen: (self: DeliveryPrompt) -> boolean,
	setStatus: (self: DeliveryPrompt, text: string) -> (),
	reset: (self: DeliveryPrompt) -> (),
	onCharacterAdded: (self: DeliveryPrompt, character: Model?) -> (),
	destroy: (self: DeliveryPrompt) -> (),
	buildGui: (self: DeliveryPrompt, parent: Instance) -> GuiObject,
}

local DeliveryPrompt = {} :: any
DeliveryPrompt.__index = DeliveryPrompt

local STATE_NONE = "none"
local STATE_ACCEPTED = "accepted"
local STATE_PICKED_UP = "pickedUp"

local function getClientRequest(self: any): ((string, any) -> any)?
	if self._client ~= nil then
		local client: any = self._client
		if type(client.request) == "function" then
			return function(action: string, payload: any): any
				local ok, result = pcall(function()
					return client.request(client, action, payload)
				end)
				if ok then
					return result
				end
				return nil
			end
		end
	end
	if self._remotes ~= nil then
		local remotes: Instance = self._remotes :: Instance
		return function(action: string, payload: any): any
			local remote = remotes:FindFirstChild(action)
			if remote ~= nil and remote:IsA("RemoteFunction") then
				local ok, result = pcall(function()
					return (remote :: RemoteFunction):InvokeServer(payload)
				end)
				if ok then
					return result
				end
			end
			return nil
		end
	end
	return nil
end

local function unwrap(result: any): ({ [string]: any }?, string?)
	if type(result) ~= "table" then
		return nil, "noResponse"
	end
	local t = result :: { [string]: any }
	if t.ok == false then
		local code = t.code
		if type(code) ~= "string" then
			code = t.message
		end
		if type(code) ~= "string" then
			code = "requestFailed"
		end
		return nil, code :: string
	end
	local data = t.data
	if type(data) == "table" then
		local dt = data :: { [string]: any }
		if dt.ok == false then
			local code = dt.code
			if type(code) ~= "string" then
				code = "requestFailed"
			end
			return nil, code :: string
		end
		return dt, nil
	end
	return t, nil
end

local function currentVehicleType(self: any): string
	if self._getVehicleType ~= nil then
		local ok, value = pcall(self._getVehicleType)
		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end
	if type(self._vehicleType) == "string" and self._vehicleType ~= "" then
		return self._vehicleType
	end
	return "bicycle"
end

local function refreshUi(self: any): ()
	local button = self._actionButton
	local status = self._statusLabel
	if self._state == STATE_ACCEPTED then
		if button ~= nil then
			button.Text = "Döner abholen"
		end
		if status ~= nil then
			status.Text = "Auftrag angenommen. Döner abholen."
		end
	elseif self._state == STATE_PICKED_UP then
		if button ~= nil then
			button.Text = "Ausliefern"
		end
		if status ~= nil then
			status.Text = "Döner abgeholt. Ziel anfahren."
		end
	else
		if button ~= nil then
			button.Text = "Auftrag annehmen"
		end
		if status ~= nil then
			status.Text = "Kein aktiver Auftrag"
		end
	end
end

local function doAction(self: any): ()
	local req = getClientRequest(self)
	if req == nil then
		local status = self._statusLabel
		if status ~= nil then
			status.Text = "Keine Verbindung"
		end
		return
	end

	if self._state == STATE_NONE then
		local result = req("DeliveryOrder", { vehicleType = currentVehicleType(self) })
		local data, err = unwrap(result)
		if data ~= nil then
			self._state = STATE_ACCEPTED
			self._orderId = data.orderId
			self._addressId = data.addressId
			refreshUi(self)
		else
			local status = self._statusLabel
			if status ~= nil then
				status.Text = "Fehler: " .. tostring(err)
			end
		end
	elseif self._state == STATE_ACCEPTED then
		local payload: { [string]: any } = {}
		if type(self._orderId) == "string" and self._orderId ~= "" then
			payload.orderId = self._orderId
		end
		local result = req("DeliveryPickup", payload)
		local data, err = unwrap(result)
		if data ~= nil then
			self._state = STATE_PICKED_UP
			refreshUi(self)
		else
			local status = self._statusLabel
			if status ~= nil then
				status.Text = "Fehler: " .. tostring(err)
			end
		end
	elseif self._state == STATE_PICKED_UP then
		local payload: { [string]: any } = {}
		if type(self._orderId) == "string" and self._orderId ~= "" then
			payload.orderId = self._orderId
		end
		local result = req("DeliveryDeliver", payload)
		local data, err = unwrap(result)
		if data ~= nil then
			self._state = STATE_NONE
			self._orderId = nil
			self._addressId = nil
			refreshUi(self)
			local status = self._statusLabel
			if status ~= nil then
				local payoutText = ""
				if type(data.payout) == "number" then
					payoutText = " (+" .. tostring(data.payout) .. ")"
				end
				status.Text = "Ausgeliefert" .. payoutText
			end
		else
			local status = self._statusLabel
			if status ~= nil then
				status.Text = "Fehler: " .. tostring(err)
			end
		end
	end
end

function DeliveryPrompt.new(...): DeliveryPrompt
	local args = { ... }
	local self = setmetatable({
		_client = nil,
		_getVehicleType = nil,
		_remotes = nil,
		_vehicleType = "bicycle",
		_state = STATE_NONE,
		_orderId = nil,
		_addressId = nil,
		_isOpen = false,
		_gui = nil,
		_statusLabel = nil,
		_actionButton = nil,
	}, DeliveryPrompt)

	local first = args[1]
	if type(first) == "table" then
		local t: any = first
		if type(t.request) == "function" then
			self._client = t :: DeliveryClient
		elseif t.remotes ~= nil then
			self._remotes = t.remotes
		elseif t.netFolder ~= nil then
			self._remotes = t.netFolder
		end
		if type(t.getVehicleType) == "function" then
			self._getVehicleType = t.getVehicleType
		end
		if type(t.vehicleType) == "string" then
			self._vehicleType = t.vehicleType
		end
	elseif type(first) == "userdata" then
		self._remotes = first
	end

	local second = args[2]
	if type(second) == "string" then
		self._vehicleType = second
	elseif type(second) == "function" then
		self._getVehicleType = second
	end

	local third = args[3]
	if type(third) == "string" then
		self._vehicleType = third
	end

	return self :: DeliveryPrompt
end

function DeliveryPrompt:open()
	self._isOpen = true
	local gui = self._gui
	if gui ~= nil then
		gui.Visible = true
	end
end

function DeliveryPrompt:close()
	self._isOpen = false
	local gui = self._gui
	if gui ~= nil then
		gui.Visible = false
	end
end

function DeliveryPrompt:isOpen(): boolean
	return self._isOpen
end

function DeliveryPrompt:setStatus(text: string)
	local label = self._statusLabel
	if label ~= nil then
		label.Text = text
	end
end

function DeliveryPrompt:reset()
	self._state = STATE_NONE
	self._orderId = nil
	self._addressId = nil
	refreshUi(self)
end

function DeliveryPrompt:onCharacterAdded(_character: Model?)
	self:reset()
end

function DeliveryPrompt:destroy()
	self:close()
	self._gui = nil
	self._statusLabel = nil
	self._actionButton = nil
end

function DeliveryPrompt:buildGui(parent: Instance): GuiObject
	if self._gui ~= nil then
		return self._gui :: GuiObject
	end

	local frame = Instance.new("Frame")
	frame.Name = "DeliveryPrompt"
	frame.Size = UDim2.fromOffset(220, 96)
	frame.Position = UDim2.new(1, -236, 1, -112)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Visible = self._isOpen
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -12, 0, 36)
	status.Position = UDim2.fromOffset(6, 6)
	status.BackgroundTransparency = 1
	status.Text = "Kein aktiver Auftrag"
	status.TextColor3 = Color3.fromRGB(235, 235, 235)
	status.TextSize = 14
	status.Font = Enum.Font.Gotham
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.Size = UDim2.new(1, -12, 0, 34)
	button.Position = UDim2.fromOffset(6, 52)
	button.BackgroundColor3 = Color3.fromRGB(200, 60, 40)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 15
	button.Font = Enum.Font.GothamBold
	button.Text = "Auftrag annehmen"
	button.AutoButtonColor = true
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	button.Activated:Connect(function()
		doAction(self)
	end)

	self._gui = frame
	self._statusLabel = status
	self._actionButton = button
	refreshUi(self)
	return frame
end

return DeliveryPrompt