--!strict
-- VehicleAssembly: serverautoritative Physik-Huelle fuer Fahrrad und Mofa.
-- Im Stand bleibt das Modell verankert (stabil, kein Wegrollen). Sobald der
-- Spieler auf dem Sitz Platz nimmt, wird das gesamte Assembly entankert und
-- der Engine-Physik uebergeben; beim Absteigen wird es an der aktuellen
-- Position wieder verankert.
-- Eine serverseitige AlignOrientation haelt das Fahrzeug IMMER aufrecht –
-- auch falls der Client (noch) keinen Netzwerkbesitz hat.
-- Keine Preise, kein Besitz, keine Clientwerte.

local VehicleAssembly = {}

function VehicleAssembly.setAnchored(model: Model, anchored: boolean): ()
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = anchored
		end
	end
end

-- Aufrechte Stabilisierung, repliziert vom Server. Der Client darf die
-- Zielausrichtung lokal nachfuehren (Gier/Pitch), wenn er die Assembly besitzt.
function VehicleAssembly.setupStabilizer(drive: BasePart): ()
	if drive:FindFirstChild("ToeffliDriveAttachment") ~= nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ToeffliDriveAttachment"
	attachment.Parent = drive

	local yaw = 0
	local ok, _, yawValue = pcall(function()
		return drive.CFrame:ToEulerAnglesYXZ()
	end)
	if ok and typeof(yawValue) == "number" then
		yaw = yawValue
	end

	local align = Instance.new("AlignOrientation")
	align.Name = "ToeffliAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = true
	align.CFrame = CFrame.new(drive.Position) * CFrame.Angles(0, yaw, 0)
	align.Parent = drive
end

-- Beobachtet den Sitz und schaltet die Physik nur waehrend der Fahrt frei.
function VehicleAssembly.watch(player: Player, model: Model, drive: BasePart, seat: VehicleSeat): ()
	VehicleAssembly.setupStabilizer(drive)
	VehicleAssembly.setAnchored(model, true)

	local active = false
	local function setActive(occupied: boolean): ()
		if occupied == active then
			return
		end
		active = occupied
		if occupied then
			-- Zielausrichtung auf die aktuelle Gier setzen, damit das Fahrzeug
			-- beim Entankern nicht auf die Spawn-Richtung zurueckschnappt.
			local align = drive:FindFirstChild("ToeffliAlign")
			if align ~= nil and align:IsA("AlignOrientation") then
				local ok, _, yaw = pcall(function()
					return drive.CFrame:ToEulerAnglesYXZ()
				end)
				if ok and typeof(yaw) == "number" then
					align.CFrame = CFrame.new(drive.Position) * CFrame.Angles(0, yaw, 0)
				end
			end
			VehicleAssembly.setAnchored(model, false)
			-- Eigentuemer der Physik-Assembly: der aufgesessene Spieler.
			pcall(function()
				drive:SetNetworkOwner(player)
			end)
		else
			VehicleAssembly.setAnchored(model, true)
		end
	end

	local function bindCharacter(character: Model): ()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid == nil or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.Seated:Connect(function(occupied: boolean, seatPart: BasePart?)
			if not model:IsDescendantOf(workspace) then
				return
			end
			if occupied and seatPart == seat then
				setActive(true)
			elseif not occupied and seat.Occupant == nil then
				setActive(false)
			end
		end)
	end

	if player.Character ~= nil then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
end

return VehicleAssembly
