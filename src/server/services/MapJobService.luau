--!strict
-- MapJobService: verarbeitet die ProximityPrompts an allen "JobPoint"-Teilen
-- der gebauten SwissMap. Der Server bleibt alleinige Quelle fuer Distanz,
-- Cooldown und Auszahlung; der Client schickt nur den Prompt-Trigger.
--
-- Bewusst eigenstaendig: keine globale Variable, keine Kopplung an die
-- Delivery-Routen. Die Auszahlung laeuft ueber EconomyService:credit.

local ProximityPromptService = game:GetService("ProximityPromptService")

export type Config = {
	economy: any,
	root: Instance?,
	cooldowns: number?,
	payouts: { [string]: number }?,
	maxDistance: number?,
}

local DEFAULT_PAYOUTS: { [string]: number } = {
	Doener = 9,
	ToeffliLaden = 14,
	Baeckerei = 12,
	Kaeserei = 12,
	Werkstatt = 16,
	Cafe = 11,
}

local DEFAULT_COOLDOWN = 18
local DEFAULT_MAX_DISTANCE = 26

local MapJobService = {}
MapJobService.__index = MapJobService

function MapJobService.new(config: Config): any
	local self = setmetatable({}, MapJobService)
	self._economy = config.economy
	self._root = config.root or workspace
	self._cooldowns = config.cooldowns or DEFAULT_COOLDOWN
	self._payouts = config.payouts or DEFAULT_PAYOUTS
	self._maxDistance = config.maxDistance or DEFAULT_MAX_DISTANCE
	self._last = {}
	self._counter = 0
	self._conn = nil
	return self
end

local function jobPointOf(prompt: ProximityPrompt): BasePart?
	local parent = prompt.Parent
	if parent == nil or not parent:IsA("BasePart") then
		return nil
	end
	if parent.Name ~= "JobPoint" then
		return nil
	end
	return parent
end

function MapJobService:_isInRoot(inst: Instance): boolean
	local node: Instance? = inst
	while node ~= nil do
		if node == self._root then
			return true
		end
		node = node.Parent
	end
	return false
end

function MapJobService:start(): ()
	if self._conn ~= nil then
		return
	end
	self._conn = ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		self:_onPrompt(prompt, player)
	end)
	print("[ToeffliTal][Server] MapJobService aktiv")
end

function MapJobService:_onPrompt(prompt: ProximityPrompt, player: Player): ()
	local part = jobPointOf(prompt)
	if part == nil or not self:_isInRoot(part) then
		return
	end
	local job = part:GetAttribute("Job")
	if type(job) ~= "string" then
		return
	end
	local payout = self._payouts[job]
	if payout == nil or payout <= 0 then
		return
	end

	local now = os.clock()
	local last = self._last[player.UserId]
	if last ~= nil and now - last < self._cooldowns then
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	if (hrp.Position - part.Position).Magnitude > self._maxDistance then
		return
	end

	self._last[player.UserId] = now
	self._counter += 1
	local transactionId = string.format("mapjob:%d:%d", player.UserId, self._counter)
	local ok = self._economy:credit(player.UserId, payout, transactionId)
	if not ok then
		self._last[player.UserId] = nil
		warn(string.format("[ToeffliTal][Server] MapJobService: Auszahlung fuer %s fehlgeschlagen", player.Name))
		return
	end

	-- Rueckmeldung ohne eigenes Remote: Prompt-Text kurz umschalten.
	local oldAction = prompt.ActionText
	prompt.ActionText = string.format("+%d CHF", payout)
	task.delay(1.6, function()
		if prompt.Parent ~= nil then
			prompt.ActionText = oldAction
		end
	end)
end

function MapJobService:destroy(): ()
	if self._conn ~= nil then
		self._conn:Disconnect()
		self._conn = nil
	end
	table.clear(self._last)
end

return MapJobService
