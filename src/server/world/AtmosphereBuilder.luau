--!strict
-- AtmosphereBuilder: freundliche Tagesbeleuchtung mit Sonne, Wolken und Atmosphaere.
-- Kein Tag/Nacht-Kreislauf, keine Ueberblendung, keine Gameplay-Aenderungen.
-- Keine globalen Variablen, keine externen Assets.

local AtmosphereBuilder = {}

local function clearChildrenOfType(parent: Instance, className: string): ()
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			child:Destroy()
		end
	end
end

function AtmosphereBuilder.apply(): ()
	local Lighting = game:GetService("Lighting")

	-- Feste, freundliche Tageszeit: kein automatischer Tag/Nacht-Kreislauf.
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 46.8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(145, 155, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 185, 200)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 235)
	Lighting.ColorShift_Bottom = Color3.fromRGB(190, 210, 230)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4

	-- Weicher, nicht uebermaessiger Nebel fuer Lesbarkeit in der Ferne.
	Lighting.FogColor = Color3.fromRGB(205, 220, 235)
	Lighting.FogStart = 600
	Lighting.FogEnd = 2200

	-- Atmosphaere: sanfter Dunst, geringe Blendung.
	clearChildrenOfType(Lighting, "Atmosphere")
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(205, 225, 255)
	atmosphere.Decay = Color3.fromRGB(190, 210, 240)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 0.45
	atmosphere.Parent = Lighting

	-- Sanfte Sonnenstrahlen, ohne Ueberblendung.
	clearChildrenOfType(Lighting, "SunRaysEffect")
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.12
	sunRays.Spread = 0.55
	sunRays.Parent = Lighting

	-- Wolken ueber dem Terrain (sichtbar, aber nicht zu dicht).
	local terrain = workspace:FindFirstChild("Terrain")
	if terrain ~= nil then
		clearChildrenOfType(terrain, "Clouds")
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.38
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

return AtmosphereBuilder