--!strict
-- ShopTerminal: PC-Laptop-Terminal fuer Teilebestellungen.
-- Sendet ausschliesslich Shop-Anfragen (Katalog, Inventar, Bestellung).
-- Kein Einbau, keine Lackierung, keine Werkstattfunktionen.

export type PartEntry = {
	id: string,
	name: string,
	category: string,
	price: number,
	compatibleModels: { string },
	mountPoint: string?,
}

export type ShopClient = {
	request: (self: ShopClient, action: string, payload: any) -> any,
}

export type ShopTerminal = {
	_shopClient: ShopClient,
	_catalog: { PartEntry },
	_inventory: { [string]: number },
	_modelFilter: string?,
	_categoryFilter: string?,
	_pendingConfirmation: string?,
	_isOpen: boolean,
	_gui: GuiObject?,
	open: (self: ShopTerminal) -> (),
	close: (self: ShopTerminal) -> (),
	isOpen: (self: ShopTerminal) -> boolean,
	setCatalog: (self: ShopTerminal, catalog: { PartEntry }) -> (),
	setInventory: (self: ShopTerminal, inventory: { [string]: number }) -> (),
	setModelFilter: (self: ShopTerminal, modelId: string?) -> (),
	setCategoryFilter: (self: ShopTerminal, category: string?) -> (),
	getCategories: (self: ShopTerminal) -> { string },
	getVisibleParts: (self: ShopTerminal) -> { PartEntry },
	requestOrder: (self: ShopTerminal, partId: string) -> (boolean, string),
	confirmOrder: (self: ShopTerminal) -> (boolean, string),
	cancelConfirmation: (self: ShopTerminal) -> (),
	refreshCatalog: (self: ShopTerminal) -> (),
	refreshInventory: (self: ShopTerminal) -> (),
	buildGui: (self: ShopTerminal, parent: Instance) -> GuiObject,
}

local ShopTerminal = {} :: any
ShopTerminal.__index = ShopTerminal

local ALLOWED_SHOP_ACTIONS: { [string]: boolean } = {
	GetCatalog = true,
	GetInventory = true,
	OrderPart = true,
}

local function isCompatible(part: PartEntry, modelId: string?): boolean
	if modelId == nil or modelId == "" then
		return true
	end
	for _, model in ipairs(part.compatibleModels) do
		if model == modelId then
			return true
		end
	end
	return false
end

local function findPart(catalog: { PartEntry }, partId: string): PartEntry?
	for _, part in ipairs(catalog) do
		if part.id == partId then
			return part
		end
	end
	return nil
end

function ShopTerminal.new(shopClient: ShopClient): ShopTerminal
	assert(shopClient ~= nil, "ShopTerminal.new benoetigt einen ShopClient")
	assert(type(shopClient.request) == "function", "ShopClient muss request(action, payload) anbieten")
	local self: ShopTerminal = setmetatable({}, ShopTerminal) :: ShopTerminal
	self._shopClient = shopClient
	self._catalog = {}
	self._inventory = {}
	self._modelFilter = nil
	self._categoryFilter = nil
	self._pendingConfirmation = nil
	self._isOpen = false
	self._gui = nil
	return self
end

function ShopTerminal:open()
	self._isOpen = true
	self:refreshCatalog()
	self:refreshInventory()
	local gui = self._gui
	if gui ~= nil then
		gui.Visible = true
	end
end

function ShopTerminal:close()
	self._isOpen = false
	self._pendingConfirmation = nil
	local gui = self._gui
	if gui ~= nil then
		gui.Visible = false
	end
end

function ShopTerminal:isOpen(): boolean
	return self._isOpen
end

function ShopTerminal:setCatalog(catalog: { PartEntry })
	assert(type(catalog) == "table", "Katalog muss eine Liste sein")
	self._catalog = catalog
end

function ShopTerminal:setInventory(inventory: { [string]: number })
	assert(type(inventory) == "table", "Inventar muss eine Map sein")
	self._inventory = inventory
end

function ShopTerminal:setModelFilter(modelId: string?)
	self._modelFilter = modelId
	self._pendingConfirmation = nil
end

function ShopTerminal:setCategoryFilter(category: string?)
	self._categoryFilter = category
	self._pendingConfirmation = nil
end

function ShopTerminal:getCategories(): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, part in ipairs(self._catalog) do
		if not seen[part.category] then
			seen[part.category] = true
			table.insert(result, part.category)
		end
	end
	table.sort(result)
	return result
end

function ShopTerminal:getVisibleParts(): { PartEntry }
	local result: { PartEntry } = {}
	for _, part in ipairs(self._catalog) do
		local categoryOk = self._categoryFilter == nil
			or self._categoryFilter == ""
			or part.category == self._categoryFilter
		if categoryOk and isCompatible(part, self._modelFilter) then
			table.insert(result, part)
		end
	end
	table.sort(result, function(a: PartEntry, b: PartEntry): boolean
		if a.category == b.category then
			if a.price == b.price then
				return a.id < b.id
			end
			return a.price < b.price
		end
		return a.category < b.category
	end)
	return result
end

function ShopTerminal:_sendShopRequest(action: string, payload: any): any
	assert(ALLOWED_SHOP_ACTIONS[action] == true, "Nur Shop-Anfragen erlaubt: " .. tostring(action))
	return self._shopClient:request(action, payload)
end

function ShopTerminal:refreshCatalog()
	self:_sendShopRequest("GetCatalog", {
		modelFilter = self._modelFilter,
	})
end

function ShopTerminal:refreshInventory()
	self:_sendShopRequest("GetInventory", {})
end

function ShopTerminal:requestOrder(partId: string): (boolean, string)
	local part = findPart(self._catalog, partId)
	if part == nil then
		return false, "Teil nicht im Katalog."
	end
	if not isCompatible(part, self._modelFilter) then
		return false, "Teil ist mit dem gewaehlten Modell nicht kompatibel."
	end
	self._pendingConfirmation = partId
	return true, ("Bestellung bestaetigen: %s (%d CHF)?"):format(part.name, part.price)
end

function ShopTerminal:confirmOrder(): (boolean, string)
	local partId = self._pendingConfirmation
	if partId == nil or partId == "" then
		return false, "Keine offene Bestellbestaetigung."
	end
	local part = findPart(self._catalog, partId)
	if part == nil then
		self._pendingConfirmation = nil
		return false, "Teil nicht mehr verfuegbar."
	end
	self._pendingConfirmation = nil
	self:_sendShopRequest("OrderPart", {
		partId = part.id,
	})
	return true, ("Bestellt: %s (%d CHF)."):format(part.name, part.price)
end

function ShopTerminal:cancelConfirmation()
	self._pendingConfirmation = nil
end

local function makeLabel(text: string, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Size = size
	label.Font = Enum.Font.SourceSans
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

function ShopTerminal:buildGui(parent: Instance): GuiObject
	local frame = Instance.new("Frame")
	frame.Name = "ShopTerminal"
	frame.Size = UDim2.fromScale(0.6, 0.7)
	frame.Position = UDim2.fromScale(0.2, 0.15)
	frame.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	frame.Visible = self._isOpen
	frame.Parent = parent

	local title = makeLabel("Töffli-Laden: Laptop-Bestellung", UDim2.fromScale(1, 0.08))
	title.Name = "Title"
	title.Parent = frame

	local hint = makeLabel(
		"Kategorien und Modellfilter waehlen, dann bestellen. Kein Einbau hier.",
		UDim2.fromScale(1, 0.06)
	)
	hint.Name = "Hint"
	hint.Position = UDim2.fromScale(0, 0.08)
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(170, 175, 185)
	hint.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Name = "PartsList"
	list.Position = UDim2.fromScale(0, 0.16)
	list.Size = UDim2.fromScale(1, 0.84)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Parent = frame

	self._gui = frame
	return frame
end

return ShopTerminal
