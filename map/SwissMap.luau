--[[
	SCHWEIZER TOEFFLI-MAP  v3  (8000 x 8000 Studs)
	-------------------------------------------------------------
	Berge, Tal, See (flach),
	3 Doerfer (jedes Haus anders), 1 Kirche, 2 Kreisel,
	zweispurige Hauptstrassen mit Mittelstrich, Stop-Strassen,
	Schweizer Tempo-/Stopschilder, Kuhweiden (umzaeunt),
	Doener Laden (Start / Geld verdienen) + 15 identische Garagen,
	Low-Poly-Tannen, Sonne + Wolken.

	BENUTZUNG (Roblox Studio, NICHT im Play-Modus):
	View -> Command Bar -> ganzen Code einfuegen -> Enter.
	Dauer: ca. 5-10 Minuten. Fortschritt im Output-Fenster.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local terrain = Workspace.Terrain
local E = Enum.Material
local V2, V3 = Vector2.new, Vector3.new

----------------------------------------------------------------
-- EINSTELLUNGEN
----------------------------------------------------------------
local WS = 4                     -- Weltmassstab: 2000 -> 8000
local SIZE, HALF, VOX = 2000 * WS, 1000 * WS, 4
local N = SIZE / VOX             -- 2000 Zellen
local BASEY, NY = -32, 104       -- Terrain geht von y=-32 bis y=384
local WL = 4                     -- Wasserspiegel (See)
local BLEND = 34                 -- Boeschungsbreite neben Strassen
local TREE_COUNT = 3900          -- Anzahl Tannen (3x)
local GARAGE_COUNT = 15          -- 1 Garage pro Spieler
local GARAGE_NUMBERS = true      -- kleine Nummernschilder an den Garagen
local PASTURE_COUNT = 15         -- Anzahl Kuhweiden (3x)
local SEED = 11.37               -- anderer Wert = andere Berge/Huegel
math.randomseed(2026)

----------------------------------------------------------------
-- HILFSFUNKTIONEN
----------------------------------------------------------------
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function sstep(a, b, x)
	local t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local function nz(x, z, s) return math.noise(x + 0.37, z + 0.71, SEED + (s or 0)) * 2 end
local function rnd(a, b) return a + math.random() * (b - a) end
local function pick(t) return t[math.random(1, #t)] end
local function dist2(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
local paceCount = 0
local function pace(n)
	paceCount = paceCount + 1
	if paceCount % n == 0 then task.wait() end
end
local function COL(r, g, b) return Color3.fromRGB(r, g, b) end

print("[Swiss Map] Start ...")
terrain:Clear()
do
	local o = Workspace:FindFirstChild("SwissMap")
	if o then o:Destroy() end
end
local map = Instance.new("Folder")
map.Name = "SwissMap"
map.Parent = Workspace
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or map
	return f
end

----------------------------------------------------------------
-- HOEHENFORMEL
----------------------------------------------------------------
local LAKE = { x = -430 * WS, z = -130 * WS, rx = 300 * WS, rz = 170 * WS }

local function lakeD(x, z)
	local dx = (x - LAKE.x) / LAKE.rx
	local dz = (z - LAKE.z) / LAKE.rz
	return math.sqrt(dx * dx + dz * dz) + nz(x / (120 * WS), z / (120 * WS), 10) * 0.10
end

local function baseHeight(x, z)
	local d = lakeD(x, z)
	-- Mittelland + flache Senke rund um den See
	local mid = 34 + nz(x / (420 * WS), z / (420 * WS), 1) * 18 + nz(x / (140 * WS), z / (140 * WS), 2) * 4
	local basin = (1 - sstep(1.0, 2.3, d)) * 0.88
	mid = lerp(mid, WL + 2.2 + nz(x / (90 * WS), z / (90 * WS), 11) * 0.7, basin)
	-- Alpen im Sueden
	local alp = sstep(150 * WS, 450 * WS, z)
	local r = (1 - math.abs(nz(x / (330 * WS), z / (330 * WS), 3))) ^ 2 * 0.75
		+ (1 - math.abs(nz(x / (150 * WS), z / (150 * WS), 4))) ^ 2 * 0.25
	local mtn = 60 + r * 230 + nz(x / (70 * WS), z / (70 * WS), 5) * 10
	local h = lerp(mid, mtn, alp)
	-- Haupttal
	local vz = 430 * WS + 60 * WS * math.sin(x / (260 * WS))
	local carve = 1 - sstep(60 * WS, 240 * WS, math.abs(z - vz))
	local floor = 24 + (x + 1000 * WS) * (0.012 / WS) + nz(x / (200 * WS), z / (200 * WS), 6) * 4
	h = lerp(h, floor, carve)
	-- Bergkranz am Rand
	local e = sstep(760 * WS, 990 * WS, math.max(math.abs(x), math.abs(z)))
	h = h + e * (110 + 110 * r)
	-- See: sehr flaches Ufer
	local w = sstep(1.6, 1.0, d)
	local tgt = WL + 1.2 - 9 * sstep(1.0, 0.35, d)
	h = lerp(h, tgt, w)
	if h > 280 then h = 280 + (h - 280) * 0.35 end
	return math.min(h, 376)
end

----------------------------------------------------------------
-- DOERFER / FLACHE ZONEN
----------------------------------------------------------------
local VILLAGES = {
	{ name = "Hauptdorf", x = 60, z = -260, rf = 165, rb = 250, rs = 190, count = 36 },
	{ name = "Seedorf", x = -250, z = -390, rf = 110, rb = 185, rs = 145, count = 22 },
	{ name = "Talort", x = 130, z = 455, rf = 115, rb = 190, rs = 140, count = 20 },
}
local FLATS = {}
for _, v in ipairs(VILLAGES) do
	v.x *= WS
	v.z *= WS
	v.rf *= WS
	v.rb *= WS
	v.rs *= WS
	v.count *= 3
	v.h = baseHeight(v.x, v.z)
	FLATS[#FLATS + 1] = v
end

local function terrainH(x, z)
	local h = baseHeight(x, z)
	for _, f in ipairs(FLATS) do
		local dx, dz = x - f.x, z - f.z
		if math.abs(dx) < f.rb and math.abs(dz) < f.rb then
			local d = math.sqrt(dx * dx + dz * dz)
			if d < f.rb then h = lerp(h, f.h, 1 - sstep(f.rf, f.rb, d)) end
		end
	end
	return h
end

local RBS = {
	{ c = V2(60 * WS, -260 * WS), Rin = 12, Rout = 27, h = VILLAGES[1].h },
	{ c = V2(130 * WS, 455 * WS), Rin = 12, Rout = 27, h = VILLAGES[3].h },
}
local RB1, RB2 = RBS[1].c, RBS[2].c

----------------------------------------------------------------
-- SPLINE / SMOOTH / RAEUMLICHER HASH
----------------------------------------------------------------
local function smooth(a, r, passes)
	for _ = 1, passes do
		local new = {}
		for i = 1, #a do
			local s, c = 0, 0
			for j = math.max(1, i - r), math.min(#a, i + r) do
				s = s + a[j]
				c = c + 1
			end
			new[i] = s / c
		end
		a = new
	end
	return a
end

local function spline(pts, step)
	local out, n = {}, #pts
	for i = 1, n - 1 do
		local p0 = pts[math.max(i - 1, 1)]
		local p1, p2 = pts[i], pts[i + 1]
		local p3 = pts[math.min(i + 2, n)]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / step))
		for s = 0, steps - 1 do
			local t = s / steps
			out[#out + 1] = 0.5 * ((2 * p1) + (p2 - p0) * t
				+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
				+ (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
		end
	end
	out[#out + 1] = pts[n]
	return out
end

local CELL = 256
local HASH_OFFSET = HALF + 100
local function hadd(H, x, z, rec)
	local cx = math.floor((x + HASH_OFFSET) / CELL)
	local cz = math.floor((z + HASH_OFFSET) / CELL)
	local k = cx * 64 + cz
	local t = H[k]
	if not t then t = {}; H[k] = t end
	t[#t + 1] = rec
end
local function hnearest(H, x, z)
	local cx = math.floor((x + HASH_OFFSET) / CELL)
	local cz = math.floor((z + HASH_OFFSET) / CELL)
	local best, bd = nil, math.huge
	for a = cx - 1, cx + 1 do
		for b = cz - 1, cz + 1 do
			local t = H[a * 64 + b]
			if t then
				for _, p in ipairs(t) do
					local d = (p[1] - x) ^ 2 + (p[2] - z) ^ 2
					if d < bd then bd = d; best = p end
				end
			end
		end
	end
	if best then return best, math.sqrt(bd), cx, cz end
	return nil
end

----------------------------------------------------------------
-- STRASSEN
----------------------------------------------------------------
local ROADS = {
	-- Hauptstrassen (2 Spuren, Mittelstrich)
	{ name = "Hauptstrasse West", kind = "main", hw = 9, pts = {
		V2(-740, -430), V2(-540, -450), V2(-360, -422), V2(-210, -335), V2(-70, -292), RB1 } },
	{ name = "Hauptstrasse Ost", kind = "main", hw = 9, pts = {
		RB1, V2(180, -283), V2(330, -310), V2(520, -350), V2(660, -310), V2(740, -270) } },
	{ name = "Verbindung", kind = "main", hw = 9, pts = {
		RB1, V2(82, -205), V2(80, -130), V2(65, 20), V2(90, 170), V2(125, 310), RB2 } },
	{ name = "Talstrasse West", kind = "main", hw = 9, pts = {
		V2(-740, 413), V2(-560, 380), V2(-370, 372), V2(-220, 385), V2(-60, 418), V2(30, 436), RB2 } },
	{ name = "Talstrasse Ost", kind = "main", hw = 9, pts = {
		RB2, V2(210, 468), V2(290, 482), V2(500, 486), V2(740, 447) } },
	-- Dorfstrassen (muessen bei Hauptstrassen STOP halten)
	{ name = "Bahnhofstrasse", kind = "minor", hw = 6.5, tStart = true, tEnd = true, pts = {
		V2(-70, -292), V2(-82, -230), V2(-60, -170), V2(0, -136), V2(80, -130) } },
	{ name = "Kirchweg", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(180, -283), V2(185, -370), V2(160, -440) } },
	{ name = "Moosweg", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(80, -130), V2(190, -118), V2(290, -140) } },
	{ name = "Seestrasse", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(-360, -422), V2(-335, -350), V2(-305, -300) } },
	{ name = "Muehlegasse", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(-210, -335), V2(-215, -420), V2(-190, -500) } },
	{ name = "Talweg", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(30, 436), V2(22, 385), V2(40, 335) } },
	{ name = "Bachstrasse", kind = "minor", hw = 6.5, tStart = true, pts = {
		V2(210, 468), V2(222, 410), V2(205, 352) } },
	-- Passstrasse mit Kehren
	{ name = "Passstrasse", kind = "pass", hw = 7.5, tStart = true, topH = 215, pts = {
		V2(500, 486), V2(455, 545), V2(380, 590), V2(455, 650), V2(355, 705), V2(440, 765), V2(350, 815) } },
}

-- Alle Strassenpunkte auf die 4x-Welt skalieren (Breiten bleiben realistisch).
-- RB1/RB2 sind bereits skaliert und werden nicht doppelt skaliert.
for _, def in ipairs(ROADS) do
	for i, p in ipairs(def.pts) do
		if p ~= RB1 and p ~= RB2 then
			def.pts[i] = V2(p.X * WS, p.Y * WS)
		end
	end
end

local ROADLIST, ALLPTS, rdhash = {}, {}, {}
local TJ = {}   -- Einmuendungen (damit dort keine Randlinien durchlaufen)

local function roadQuery(x, z)
	local best, bd, cx, cz = hnearest(rdhash, x, z)
	if not best then return nil end
	local sw, sh = 0, 0
	for a = cx - 1, cx + 1 do
		for b = cz - 1, cz + 1 do
			local t = rdhash[a * 64 + b]
			if t then
				for _, p in ipairs(t) do
					local d = math.sqrt((p[1] - x) ^ 2 + (p[2] - z) ^ 2)
					if d < bd + 12 then
						local w = 1 - (d - bd) / 12
						sw = sw + w
						sh = sh + w * p[3]
					end
				end
			end
		end
	end
	return bd, sh / sw, best[4]
end
local function roadDist(x, z)
	local d = roadQuery(x, z)
	return d or math.huge
end

local function addRoad(def)
	local pts = {}
	for i, p in ipairs(def.pts) do pts[i] = p end
	local n0 = #pts
	for _, rb in ipairs(RBS) do
		if pts[1] == rb.c then
			pts[1] = rb.c + (pts[2] - rb.c).Unit * (rb.Rout - 1.5)
			def.rbStart = rb
		end
		if pts[n0] == rb.c then
			pts[n0] = rb.c + (pts[n0 - 1] - rb.c).Unit * (rb.Rout - 1.5)
			def.rbEnd = rb
		end
	end
	local startH
	local endH = def.endH
	def.stops = {}
	if def.tStart then
		local d, h, hw0 = roadQuery(pts[1].X, pts[1].Y)
		if d then
			TJ[#TJ + 1] = { pts[1].X, pts[1].Y }
			local dir = (pts[2] - pts[1]).Unit
			pts[1] = pts[1] + dir * (hw0 - 0.5)
			startH = h
			def.stops[#def.stops + 1] = { pos = pts[1], dir = dir, which = "start" }
		end
	end
	if def.tEnd then
		local n = #pts
		local d, h, hw0 = roadQuery(pts[n].X, pts[n].Y)
		if d then
			TJ[#TJ + 1] = { pts[n].X, pts[n].Y }
			local dir = (pts[n - 1] - pts[n]).Unit
			pts[n] = pts[n] + dir * (hw0 - 0.5)
			endH = h
			def.stops[#def.stops + 1] = { pos = pts[n], dir = dir, which = "end" }
		end
	end
	local P = spline(pts, def.step or 6)
	local hs = {}
	for i, p in ipairs(P) do hs[i] = terrainH(p.X, p.Y) end
	if def.topH then
		local len = { 0 }
		for i = 2, #P do len[i] = len[i - 1] + (P[i] - P[i - 1]).Magnitude end
		local h0 = startH or hs[1]
		for i = 1, #P do hs[i] = lerp(h0, def.topH, len[i] / len[#P]) end
	else
		hs = smooth(hs, 6, 10)
	end
	if startH then
		local k = math.min(8, #hs)
		for j = 0, k - 1 do hs[1 + j] = lerp(hs[1 + j], startH, 1 - j / k) end
	end
	if endH then
		local n = #hs
		local k = math.min(8, n)
		for j = 0, k - 1 do hs[n - j] = lerp(hs[n - j], endH, 1 - j / k) end
	end
	for i, p in ipairs(P) do
		hadd(rdhash, p.X, p.Y, { p.X, p.Y, hs[i], def.hw })
		ALLPTS[#ALLPTS + 1] = { p.X, p.Y, hs[i], def.hw }
	end
	ROADLIST[#ROADLIST + 1] = { def = def, P = P, hs = hs }
end

for _, def in ipairs(ROADS) do addRoad(def) end
print("[Swiss Map] Strassen geplant")

----------------------------------------------------------------
-- DOENER LADEN + 15 GARAGEN (Planung, vor dem Terrain!)
----------------------------------------------------------------
local DONER = { x = 140 * WS, z = -205 * WS, yaw = -math.pi / 2, h = VILLAGES[1].h }
local GW, GD, GH = 32, 26, 14      -- Garage: Breite, Tiefe, Hoehe (viel Platz fuer Toeffli, Laptop, Hebebuehne)
local GARAGE_APRON_END = GD / 2 + 0.8 + 20  -- Vorplatzende = Beginn der Zufahrt

local function nearestRoadPt(x, z)
	local best, bd = nil, math.huge
	for _, p in ipairs(ALLPTS) do
		local d = (p[1] - x) ^ 2 + (p[2] - z) ^ 2
		if d < bd then bd = d; best = p end
	end
	return best, math.sqrt(bd)
end

local function validGarageSite(x, z)
	if math.abs(x) > HALF - 400 or math.abs(z) > HALF - 400 then return false end
	if dist2(x, z, RB1.X, RB1.Y) < 110 then return false end
	for vi, v in ipairs(VILLAGES) do
		if vi > 1 and dist2(x, z, v.x, v.z) < v.rf + 30 then return false end
	end
	if lakeD(x, z) < 1.5 then return false end
	local h = terrainH(x, z)
	if h < WL + 8 or h > 100 then return false end
	for _, o in ipairs({ { 10, 0 }, { -10, 0 }, { 0, 10 }, { 0, -10 } }) do
		if math.abs(terrainH(x + o[1], z + o[2]) - h) / 10 > 0.2 then return false end
	end
	local rp, rd = nearestRoadPt(x, z)
	if not rp or rd < 50 or rd > 210 then return false end
	return true
end

local GARAGES = {}
do
	local cands, tries = {}, 0
	while #cands < 500 and tries < 14000 do
		tries = tries + 1
		local a = math.random() * 2 * math.pi
		local r = 90 * WS + math.random() * (160 * WS + tries * 0.02 * WS)
		local x, z = DONER.x + math.cos(a) * r, DONER.z + math.sin(a) * r
		if validGarageSite(x, z) then cands[#cands + 1] = { x = x, z = z } end
	end
	-- "Farthest point": moeglichst weit auseinander, aber nah am Doener
	table.sort(cands, function(p, q)
		return dist2(p.x, p.z, DONER.x, DONER.z) < dist2(q.x, q.z, DONER.x, DONER.z)
	end)
	local chosen = {}
	if #cands > 0 then chosen[1] = table.remove(cands, 1) end
	local minSep = 120     -- gewuenschter Mindestabstand zwischen den groesseren Garagen
	while #chosen < GARAGE_COUNT and #cands > 0 do
		local bi = nil   -- naechster zum Doener, der noch genug Abstand zu allen anderen hat
		for i, c in ipairs(cands) do
			local md = math.huge
			for _, s in ipairs(chosen) do md = math.min(md, dist2(c.x, c.z, s.x, s.z)) end
			if md >= minSep then bi = i; break end
		end
		if bi then
			chosen[#chosen + 1] = table.remove(cands, bi)
		else
			minSep = minSep - 6
			if minSep < 80 then break end
		end
	end
	for i, c in ipairs(chosen) do
		local rp = nearestRoadPt(c.x, c.z)
		local nx, nz2 = rp[1] - c.x, rp[2] - c.z
		local len = math.sqrt(nx * nx + nz2 * nz2)
		nx, nz2 = nx / len, nz2 / len
		local g = { idx = i, x = c.x, z = c.z, h = terrainH(c.x, c.z), nx = nx, nz = nz2,
			yaw = math.atan2(nx, nz2), road = rp }
		GARAGES[i] = g
		FLATS[#FLATS + 1] = { x = g.x, z = g.z, h = g.h, rf = 24, rb = 46 }
	end
	if #GARAGES < GARAGE_COUNT then
		warn(("[Swiss Map] Nur %d von %d Garagen-Plaetzen gefunden!"):format(#GARAGES, GARAGE_COUNT))
	end
end
-- Zufahrten (Mini-Strassen von der Garage zur naechsten Strasse)
for _, g in ipairs(GARAGES) do
	local a0 = V2(g.x + g.nx * GARAGE_APRON_END, g.z + g.nz * GARAGE_APRON_END)
	local rp = g.road
	local ex = V2(rp[1], rp[2]) + (V2(g.x, g.z) - V2(rp[1], rp[2])).Unit * (rp[4] + 0.5)
	TJ[#TJ + 1] = { ex.X, ex.Y }
	addRoad({ name = "Zufahrt " .. g.idx, kind = "drive", hw = 4.5, step = 5, endH = rp[3], pts = { a0, ex } })
end
print(("[Swiss Map] %d Garagen geplant"):format(#GARAGES))

----------------------------------------------------------------
-- HOEHEN-GITTER
----------------------------------------------------------------
local H, ROADF, WLV = {}, {}, {}
for i = 1, N do
	local Hi, Ri, Wi = {}, {}, {}
	local x = -HALF + (i - 0.5) * VOX
	for k = 1, N do
		local z = -HALF + (k - 0.5) * VOX
		local h = terrainH(x, z)
		local d, rh, hw = roadQuery(x, z)
		if d and d < hw + BLEND then
			h = lerp(h, rh, 1 - sstep(hw, hw + BLEND, d))
			if d <= hw + 0.5 then Ri[k] = 1
			elseif d <= hw + 3.5 then Ri[k] = 2 end
		end
		for _, rb in ipairs(RBS) do
			local dx, dz = x - rb.c.X, z - rb.c.Y
			if math.abs(dx) < rb.Rout + 4 and math.abs(dz) < rb.Rout + 4 then
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= rb.Rout + 0.5 then
					if d >= rb.Rin - 0.5 then Ri[k] = 1 else Ri[k] = nil end
				elseif d <= rb.Rout + 3.5 and not Ri[k] then
					Ri[k] = 2
				end
			end
		end
		Hi[k] = h
	end
	H[i], ROADF[i], WLV[i] = Hi, Ri, Wi
	if i % 5 == 0 then task.wait() end
end
print("[Swiss Map] Hoehen fertig")

----------------------------------------------------------------
-- MATERIAL-GITTER (nur Gras / Fels / Schnee - keine braunen Flecken!)
----------------------------------------------------------------
local MAT = {}
for i = 1, N do
	local Mi = {}
	local x = -HALF + (i - 0.5) * VOX
	for k = 1, N do
		local z = -HALF + (k - 0.5) * VOX
		local h = H[i][k]
		local rf = ROADF[i][k]
		local m
		if rf == 1 then m = E.Asphalt
		elseif rf == 2 then m = E.Pavement
		elseif h < WL - 0.3 then m = E.Sand       -- nur unter Wasser
		else
			local sl = math.max(
				math.abs(H[math.min(i + 1, N)][k] - H[math.max(i - 1, 1)][k]),
				math.abs(H[i][math.min(k + 1, N)] - H[i][math.max(k - 1, 1)])) / (2 * VOX)
			local snow = 170 + nz(x / (90 * WS), z / (90 * WS), 7) * 25
			if h > snow and sl < 1.4 then m = E.Snow
			elseif h > 150 or (sl > 0.8 and h > 40) then m = E.Rock
			else
				local f = nz(x / (60 * WS), z / (60 * WS), 8)
				if h < 70 and f > 0.35 then m = E.LeafyGrass else m = E.Grass end
			end
		end
		Mi[k] = m
	end
	MAT[i] = Mi
	if i % 25 == 0 then task.wait() end
end
print("[Swiss Map] Materialien fertig")

----------------------------------------------------------------
-- TERRAIN SCHREIBEN
----------------------------------------------------------------
local CH = 50
local AIR = E.Air
for ci = 0, N / CH - 1 do
	for ck = 0, N / CH - 1 do
		local x0 = -HALF + ci * CH * VOX
		local z0 = -HALF + ck * CH * VOX
		local region = Region3.new(
			V3(x0, BASEY, z0),
			V3(x0 + CH * VOX, BASEY + NY * VOX, z0 + CH * VOX))
		local mats, occs = {}, {}
		for a = 1, CH do
			local ma, oa = {}, {}
			for b = 1, NY do
				ma[b] = table.create(CH, AIR)
				oa[b] = table.create(CH, 0)
			end
			mats[a], occs[a] = ma, oa
		end
		for a = 1, CH do
			for c = 1, CH do
				local i, k = ci * CH + a, ck * CH + c
				local h, surf = H[i][k], MAT[i][k]
				local deep = E.Rock
				local top = clamp((h - BASEY) / VOX, 0, NY - 1)
				local full = math.floor(top)
				local frac = top - full
				local ma, oa = mats[a], occs[a]
				for b = 1, full do
					ma[b][c] = (top - b < 3) and surf or deep
					oa[b][c] = 1
				end
				local nextFree = full + 1
				if frac > 0.02 then
					ma[full + 1][c] = surf
					oa[full + 1][c] = frac
					nextFree = full + 2
				end
				local lv = ((WLV[i][k] or WL) - BASEY) / VOX
				if top < lv - 0.02 then
					local fl = math.floor(lv)
					for b = nextFree, math.min(fl, NY) do
						ma[b][c] = E.Water
						oa[b][c] = 1
					end
					local fr = lv - fl
					if fr > 0.05 and fl + 1 <= NY and nextFree <= fl + 1 then
						ma[fl + 1][c] = E.Water
						oa[fl + 1][c] = fr
					end
				end
			end
		end
		terrain:WriteVoxels(region, VOX, mats, occs)
		task.wait()
	end
	print(("[Swiss Map] Terrain %d%%"):format(math.floor((ci + 1) / (N / CH) * 100)))
end

----------------------------------------------------------------
-- STIL: Farben, Gras, Wasser, Sonne, Wolken
----------------------------------------------------------------
pcall(function()
	terrain:SetMaterialColor(E.Grass, COL(76, 132, 62))
	terrain:SetMaterialColor(E.LeafyGrass, COL(88, 142, 66))
	terrain:SetMaterialColor(E.Rock, COL(122, 124, 132))
	terrain:SetMaterialColor(E.Sand, COL(190, 180, 140))
	terrain:SetMaterialColor(E.Snow, COL(242, 246, 250))
	terrain:SetMaterialColor(E.Asphalt, COL(62, 64, 70))
	terrain:SetMaterialColor(E.Pavement, COL(150, 150, 154))
end)
terrain.WaterColor = COL(40, 125, 170)
terrain.WaterTransparency = 0.55
terrain.WaterReflectance = 0.25
terrain.WaterWaveSize = 0.12
-- Gras wiegt sich im Wind, aber kurz (nur auf Gras-Material, nie auf der Strasse)
pcall(function() terrain.Decoration = true end)
-- Kurzes, tiefes Gras: nur auf Gras-Material, nie auf Asphalt/Pavement.
pcall(function() terrain.GrassLength = 0.05 end)

Lighting.ClockTime = 14
Lighting.GeographicLatitude = 46.8
Lighting.Brightness = 2.4
Lighting.Ambient = COL(95, 105, 125)
Lighting.GlobalShadows = true
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
atm.Density = 0.26
atm.Offset = 0.25
atm.Color = COL(172, 198, 228)
atm.Decay = COL(108, 142, 196)
atm.Glare = 0.4
atm.Haze = 1.2
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
sky.CelestialBodiesShown = true
sky.SunAngularSize = 14
local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds", terrain)
clouds.Cover = 0.62
clouds.Density = 0.6
clouds.Color = COL(255, 255, 255)
clouds.Enabled = true
local function fx(class, props)
	local o = Lighting:FindFirstChildOfClass(class) or Instance.new(class, Lighting)
	for k, v in pairs(props) do o[k] = v end
end
fx("SunRaysEffect", { Intensity = 0.16, Spread = 0.8 })
fx("BloomEffect", { Intensity = 0.25, Size = 24, Threshold = 1.6 })
fx("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.06, TintColor = COL(255, 250, 242) })
pcall(function() Workspace.StreamingEnabled = true end)
print("[Swiss Map] Terrain + Licht fertig")

----------------------------------------------------------------
-- BAU-HILFSFUNKTIONEN
----------------------------------------------------------------
local function idxOf(x, z)
	return clamp(math.floor((x + HALF) / VOX) + 1, 1, N), clamp(math.floor((z + HALF) / VOX) + 1, 1, N)
end
local function heightAt(x, z)
	local i, k = idxOf(x, z)
	return H[i][k]
end
local function matAt(x, z)
	local i, k = idxOf(x, z)
	return MAT[i][k]
end

local function part(parent, size, cf, color, material, shape, collide, transp)
	local p = Instance.new("Part")
	p.Anchored = true
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or E.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide == false then p.CanCollide = false end
	if transp then p.Transparency = transp end
	p.Parent = parent
	pace(400)
	return p
end
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, math.pi / 2)   -- Zylinder aufrecht stellen

-- aufrechter Zylinder, pos = Mitte Unterkante
local function upright(parent, pos, h, d, color, material, collide)
	return part(parent, V3(h, d, d), CFrame.new(pos.X, pos.Y + h / 2, pos.Z) * UP, color, material, CYL, collide)
end

local function textOn(p, face, text, color, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.3
	sg.Parent = p
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Size = UDim2.fromScale(1, 1)
	lb.Text = text
	lb.TextColor3 = color or COL(255, 255, 255)
	lb.TextScaled = true
	lb.Font = font or Enum.Font.GothamBlack
	lb.Parent = sg
	return lb
end

local OCC = {}
local function occAdd(x, z, r) OCC[#OCC + 1] = { x = x, z = z, r = r } end
local function occAddRect(x, z, hx, hz, yaw) OCC[#OCC + 1] = { x = x, z = z, hx = hx, hz = hz, yaw = yaw } end
-- Kreis (cx,cz,r) gegen Eintrag
local function circleHits(o, cx, cz, r)
	if o.hx then
		local dx, dz = cx - o.x, cz - o.z
		local c, s = math.cos(o.yaw), math.sin(o.yaw)
		local lx, lz = dx * c - dz * s, dx * s + dz * c
		local px, pz = clamp(lx, -o.hx, o.hx), clamp(lz, -o.hz, o.hz)
		return (lx - px) ^ 2 + (lz - pz) ^ 2 < r * r
	end
	return (o.x - cx) ^ 2 + (o.z - cz) ^ 2 < (o.r + r) ^ 2
end
local function occFree(x, z, r)
	for _, o in ipairs(OCC) do
		if circleHits(o, x, z, r) then return false end
	end
	return true
end
-- Rechteck (gedreht) gegen alle Eintraege
local function occFreeRect(x, z, hx, hz, yaw)
	local c, s = math.cos(yaw), math.sin(yaw)
	local axx, axz, bxx, bxz = c, -s, s, c   -- Achsen des Rechtecks
	for _, o in ipairs(OCC) do
		if o.hx then
			local c2, s2 = math.cos(o.yaw), math.sin(o.yaw)
			local cxx, cxz, dxx, dxz = c2, -s2, s2, c2
			local dx, dz = o.x - x, o.z - z
			local hit = true
			for _, u in ipairs({ { axx, axz }, { bxx, bxz }, { cxx, cxz }, { dxx, dxz } }) do
				local rA = hx * math.abs(u[1] * axx + u[2] * axz) + hz * math.abs(u[1] * bxx + u[2] * bxz)
				local rB = o.hx * math.abs(u[1] * cxx + u[2] * cxz) + o.hz * math.abs(u[1] * dxx + u[2] * dxz)
				if math.abs(dx * u[1] + dz * u[2]) > rA + rB then hit = false; break end
			end
			if hit then return false end
		else
			-- Kreisentry gegen unser Rechteck
			local dx, dz = o.x - x, o.z - z
			local lx, lz = dx * c - dz * s, dx * s + dz * c
			local px, pz = clamp(lx, -hx, hx), clamp(lz, -hz, hz)
			if (lx - px) ^ 2 + (lz - pz) ^ 2 < o.r * o.r then return false end
		end
	end
	return true
end
for _, rb in ipairs(RBS) do occAdd(rb.c.X, rb.c.Y, rb.Rout + 16) end

local GRAY = COL(120, 122, 128)
local WHITE = COL(240, 240, 235)
local RED = COL(206, 28, 36)

----------------------------------------------------------------
-- SCHILDER
----------------------------------------------------------------
local function speedSign(parent, x, z, y, face, text)
	upright(parent, V3(x, y, z), 9, 0.6, GRAY, E.Metal)
	local c = CFrame.lookAt(V3(x, y + 8.2, z), V3(x + face.X, y + 8.2, z + face.Y)) * CFrame.Angles(0, math.pi / 2, 0)
	part(parent, V3(0.35, 4.8, 4.8), c, RED, E.SmoothPlastic, CYL, false)
	local w = part(parent, V3(0.4, 3.4, 3.4), c * CFrame.new(0.06, 0, 0), WHITE, E.SmoothPlastic, CYL, false)
	textOn(w, Enum.NormalId.Right, text, COL(20, 20, 20))
end

local function stopSign(parent, x, z, y, face)
	upright(parent, V3(x, y, z), 9, 0.6, GRAY, E.Metal)
	local c = CFrame.lookAt(V3(x, y + 8.4, z), V3(x + face.X, y + 8.4, z + face.Y))
	local a = 2.4
	local t8 = math.tan(math.pi / 8)
	for k = 0, 3 do
		local r = CFrame.Angles(0, 0, k * math.pi / 4)
		part(parent, V3(2 * (a + 0.3), 2 * (a + 0.3) * t8, 0.3), c * r * CFrame.new(0, 0, 0.1), WHITE, E.SmoothPlastic, nil, false)
	end
	local first
	for k = 0, 3 do
		local r = CFrame.Angles(0, 0, k * math.pi / 4)
		local thick = (k == 0) and 0.4 or 0.3
		local p = part(parent, V3(2 * a, 2 * a * t8, thick), c * CFrame.new(0, 0, (k == 0) and -0.25 or -0.2) * r, RED, E.SmoothPlastic, nil, false)
		if k == 0 then first = p end
	end
	textOn(first, Enum.NormalId.Front, "STOP", WHITE)
end

local function swissFlag(parent, x, y, z, height, yaw)
	upright(parent, V3(x, y, z), height, 0.5, COL(200, 200, 205), E.Metal)
	local c = CFrame.new(x, y + height - 2.6, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(2.7, 0, 0)
	part(parent, V3(5, 4.6, 0.15), c, RED, E.Fabric, nil, false)
	part(parent, V3(2.8, 0.9, 0.2), c, WHITE, E.Fabric, nil, false)
	part(parent, V3(0.9, 2.8, 0.2), c, WHITE, E.Fabric, nil, false)
end

local function lampPost(parent, x, y, z, towards)
	upright(parent, V3(x, y, z), 11, 0.5, COL(50, 54, 60), E.Metal)
	local dx, dz = towards.X - x, towards.Y - z
	local l = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / l, dz / l
	part(parent, V3(0.35, 0.35, 3.2), CFrame.lookAt(V3(x + dx * 1.5, y + 10.8, z + dz * 1.5), V3(x + dx * 3, y + 10.8, z + dz * 3)), COL(50, 54, 60), E.Metal, nil, false)
	part(parent, V3(1.5, 0.5, 1.5), CFrame.new(x + dx * 3, y + 10.4, z + dz * 3), COL(255, 226, 160), E.Neon, nil, false)
end

----------------------------------------------------------------
-- STRASSEN (Asphalt, Mittelstrich, Randlinien, Stop)
----------------------------------------------------------------
local roadsF = folder("Strassen")
local signsF = folder("Schilder")
local lampsF = folder("Laternen")
local ASPH = COL(62, 64, 70)
local CONC = COL(158, 158, 154)

local function lineSeg(parent, a, b, y, w, color)
	local pa, pb = V3(a.X, y, a.Y), V3(b.X, y, b.Y)
	local len = (pb - pa).Magnitude
	if len < 0.2 then return end
	part(parent, V3(w, 0.12, len), CFrame.lookAt((pa + pb) / 2, pb), color, E.SmoothPlastic, nil, false)
end

local function nearRB(x, z, extra)
	for _, rb in ipairs(RBS) do
		if dist2(x, z, rb.c.X, rb.c.Y) < rb.Rout + extra then return true end
	end
	return false
end
local function nearTJ(x, z, r)
	for _, t in ipairs(TJ) do
		if dist2(x, z, t[1], t[2]) < r then return true end
	end
	return false
end
local function inVillage(x, z)
	for _, v in ipairs(VILLAGES) do
		if dist2(x, z, v.x, v.z) < v.rs then return true end
	end
	return false
end
local function tangent(P, i)
	local a, b = P[math.max(i - 1, 1)], P[math.min(i + 1, #P)]
	return (b - a).Unit
end

for _, R in ipairs(ROADLIST) do
	local def, P, hs = R.def, R.P, R.hs
	local hw, n = def.hw, #R.P
	local F = folder(def.name, roadsF)
	-- Asphalt
	for i = 1, n - 1 do
		local a = V3(P[i].X, hs[i], P[i].Y)
		local b = V3(P[i + 1].X, hs[i + 1], P[i + 1].Y)
		local len = (b - a).Magnitude
		if len > 0.1 then
			part(F, V3(2 * hw, 0.8, len + 1.0), CFrame.lookAt((a + b) / 2, b), ASPH, E.Asphalt)
		end
	end
	-- Markierungen
	if def.kind == "main" or def.kind == "pass" then
		for i = 3, n - 3, 2 do   -- gestrichelter Mittelstrich
			if not nearRB(P[i].X, P[i].Y, 8) then
				lineSeg(F, P[i], P[i + 1], (hs[i] + hs[i + 1]) / 2 + 0.46, 0.45, WHITE)
			end
		end
		for i = 2, n - 2, 2 do   -- durchgezogene Randlinien
			local mid = P[i]
			if not nearRB(mid.X, mid.Y, 6) and not nearTJ(mid.X, mid.Y, 13) then
				local t1, t2 = tangent(P, i), tangent(P, i + 2)
				local n1, n2 = V2(-t1.Y, t1.X), V2(-t2.Y, t2.X)
				local y = (hs[i] + hs[i + 2]) / 2 + 0.46
				for _, s in ipairs({ -1, 1 }) do
					lineSeg(F, P[i] + n1 * s * (hw - 1.1), P[i + 2] + n2 * s * (hw - 1.1), y, 0.35, WHITE)
				end
			end
		end
	end
	-- Stop-Linie + Stopschild an Einmuendungen
	for _, st in ipairs(def.stops or {}) do
		local d = st.dir
		local right = V2(d.Y, -d.X)           -- rechte Seite des anfahrenden Fahrzeugs
		local s0 = st.pos + d * 3.2
		local yy = hs[(st.which == "start") and 1 or n]
		lineSeg(F, s0, s0 + right * hw, yy + 0.46, 0.9, WHITE)
		local sp = s0 + right * (hw + 2.6)
		stopSign(signsF, sp.X, sp.Y, yy, d)
	end
	-- Strassenlaternen im Dorf
	if def.kind == "main" or def.kind == "minor" then
		local side = 1
		for s = 8, n - 8, 8 do
			local p = P[s]
			if inVillage(p.X, p.Y) and not nearRB(p.X, p.Y, 14) and not nearTJ(p.X, p.Y, 16) then
				local t = tangent(P, s)
				local nr = V2(-t.Y, t.X) * side
				local lp = p + nr * (hw + 1.8)
				lampPost(lampsF, lp.X, hs[s], lp.Y, p)
				side = -side
			end
		end
	end
	pace(1)
end
print("[Swiss Map] Strassen gebaut")

-- Tempo-Schilder: 50 im Dorf, 80 ausserorts (Schweiz!)
for _, R in ipairs(ROADLIST) do
	local def, P, hs = R.def, R.P, R.hs
	if def.kind == "main" then
		local n, hw = #P, def.hw
		local acc = 0
		for i = 2, n - 2 do
			acc = acc + (P[i] - P[i - 1]).Magnitude
			local a, b = inVillage(P[i].X, P[i].Y), inVillage(P[i + 1].X, P[i + 1].Y)
			local f = (P[i + 1] - P[i]).Unit
			local place = nil
			if a ~= b then
				place = b and { "50", "80" } or { "80", "50" }
			elseif not a and acc > 320 and not nearRB(P[i].X, P[i].Y, 40) and not nearTJ(P[i].X, P[i].Y, 40) then
				place = { "80", "80" }
				acc = 0
			end
			if place then
				if a ~= b then acc = 0 end
				if not nearRB(P[i].X, P[i].Y, 30) and not nearTJ(P[i].X, P[i].Y, 25) then
					local rPlus = V2(-f.Y, f.X)            -- rechts bei Fahrt in + Richtung
					local pp = P[i] + rPlus * (hw + 2.6)
					speedSign(signsF, pp.X, pp.Y, hs[i], -f, place[1])
					local pm = P[i] - rPlus * (hw + 2.6)   -- Gegenrichtung
					speedSign(signsF, pm.X, pm.Y, hs[i], f, place[2])
				end
			end
		end
	end
end
print("[Swiss Map] Schilder gebaut")

----------------------------------------------------------------
-- KREISEL
----------------------------------------------------------------
local rbF = folder("Kreisel")
for _, rb in ipairs(RBS) do
	local cx, cz, h = rb.c.X, rb.c.Y, rb.h
	local Rm = (rb.Rin + rb.Rout) / 2
	local SEG = 48
	for k = 0, SEG - 1 do
		local th = k * 2 * math.pi / SEG
		local pos = V3(cx + math.cos(th) * Rm, h, cz + math.sin(th) * Rm)
		local tan = V3(-math.sin(th), 0, math.cos(th))
		part(rbF, V3(rb.Rout - rb.Rin, 0.8, 2 * math.pi * Rm / SEG * 1.4), CFrame.lookAt(pos, pos + tan), ASPH, E.Asphalt)
	end
	-- Insel
	part(rbF, V3(1.0, 2 * (rb.Rin + 0.8), 2 * (rb.Rin + 0.8)), CFrame.new(cx, h + 0.5, cz) * UP, COL(176, 176, 172), E.Concrete, CYL)
	part(rbF, V3(1.2, 2 * (rb.Rin - 0.3), 2 * (rb.Rin - 0.3)), CFrame.new(cx, h + 0.55, cz) * UP, COL(86, 150, 68), E.Grass, CYL)
	swissFlag(rbF, cx, h + 1, cz, 15, 0.6)
	for k = 0, 13 do
		local th = k * 2 * math.pi / 14
		part(rbF, V3(1.1, 1.1, 1.1), CFrame.new(cx + math.cos(th) * 7.5, h + 1.4, cz + math.sin(th) * 7.5),
			pick({ COL(230, 60, 70), COL(250, 210, 70), COL(245, 245, 245), COL(240, 130, 190) }), E.SmoothPlastic, BALL, false)
	end
end
print("[Swiss Map] Kreisel gebaut")

----------------------------------------------------------------
-- HAEUSER (5 Typen, alles zufaellig variiert -> keine zwei gleich)
----------------------------------------------------------------
local STONE = COL(150, 148, 142)
local GLASSC = COL(150, 195, 220)
local WALLS = { COL(236, 222, 190), COL(245, 240, 225), COL(232, 205, 160), COL(210, 226, 205),
	COL(228, 200, 196), COL(200, 214, 230), COL(240, 226, 150), COL(222, 214, 200), COL(250, 236, 214) }
local WOODS = { COL(150, 100, 62), COL(120, 80, 50), COL(176, 128, 80), COL(96, 64, 44), COL(190, 150, 100) }
local ROOFS = { COL(96, 62, 48), COL(150, 74, 60), COL(80, 84, 92), COL(70, 92, 70), COL(122, 60, 48), COL(62, 58, 56), COL(168, 96, 64) }
local SHUTS = { COL(178, 52, 48), COL(58, 110, 72), COL(60, 92, 150), COL(240, 240, 235), COL(226, 180, 60), COL(120, 70, 46) }
local DOORS = { COL(60, 100, 70), COL(150, 40, 40), COL(40, 60, 110), COL(120, 80, 50), COL(210, 160, 50), COL(70, 70, 76), COL(36, 90, 96) }
local TRIMS = { COL(245, 240, 230), COL(120, 84, 56), COL(230, 226, 214), COL(90, 64, 48) }
local FLOWERS = { COL(220, 60, 70), COL(250, 200, 60), COL(240, 120, 180), COL(250, 250, 250), COL(150, 90, 200) }
local SHOPS = { "B" .. utf8.char(228) .. "ckerei", "Metzgerei", "K" .. utf8.char(228) .. "serei", "Post", "Caf" .. utf8.char(233),
	"Blumen", "Apotheke", "Velo & Toeffli" }

local function sideFrames(base, W, D)
	return {
		front = base * CFrame.new(0, 0, D / 2) * CFrame.Angles(0, math.pi, 0),
		back = base * CFrame.new(0, 0, -D / 2),
		right = base * CFrame.new(W / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		left = base * CFrame.new(-W / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	}
end

local function darker(c, f)
	f = f or 0.78
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function windowAt(m, sc, u, v, ww, wh, S)
	part(m, V3(ww + 0.9, wh + 0.9, 0.5), sc * CFrame.new(u, v, -0.25), S.trimC)
	part(m, V3(ww, wh, 0.3), sc * CFrame.new(u, v, -0.42), GLASSC, E.Glass, nil, nil, 0.25)
	part(m, V3(0.25, wh, 0.2), sc * CFrame.new(u, v, -0.62), S.trimC)
	part(m, V3(ww, 0.25, 0.2), sc * CFrame.new(u, v, -0.62), S.trimC)
	if S.shutC then
		for _, sx in ipairs({ -1, 1 }) do
			part(m, V3(ww * 0.5, wh + 0.5, 0.35), sc * CFrame.new(u + sx * (ww / 2 + ww * 0.25 + 0.45), v, -0.2), S.shutC, E.Wood)
		end
	end
	if S.flowers then
		part(m, V3(ww + 1.2, 0.9, 1.0), sc * CFrame.new(u, v - wh / 2 - 0.5, -0.7), COL(110, 76, 50), E.Wood)
		part(m, V3(ww + 0.6, 0.8, 0.8), sc * CFrame.new(u, v - wh / 2 + 0.2, -0.7), pick(FLOWERS), E.Grass)
	end
end

local function windowSimple(m, sc, u, v, S)
	part(m, V3(3.6, 4.0, 0.4), sc * CFrame.new(u, v, -0.2), S.trimC)
	part(m, V3(2.9, 3.3, 0.3), sc * CFrame.new(u, v, -0.38), GLASSC, E.Glass, nil, nil, 0.25)
	part(m, V3(0.22, 3.3, 0.2), sc * CFrame.new(u, v, -0.55), S.trimC)
end

local function doorAt(m, sc, u, S)
	part(m, V3(4.8, 7.6, 0.7), sc * CFrame.new(u, 4.8, -0.35), S.trimC, E.Concrete)
	part(m, V3(3.6, 6.6, 0.5), sc * CFrame.new(u, 4.3, -0.78), S.doorC, E.Wood)
	part(m, V3(1.6, 2.2, 0.2), sc * CFrame.new(u, 5.7, -1.08), GLASSC, E.Glass, nil, nil, 0.3)
	part(m, V3(3.0, 0.2, 0.2), sc * CFrame.new(u, 3.2, -1.1), darker(S.doorC), E.Wood)
	part(m, V3(0.35, 1.0, 0.35), sc * CFrame.new(u + 1.3, 4.1, -1.15), COL(205, 175, 70), E.Metal)
	part(m, V3(5.8, 0.8, 2.6), sc * CFrame.new(u, 0.6, -1.7), STONE, E.Concrete)
	part(m, V3(3.4, 0.12, 1.8), sc * CFrame.new(u, 1.06, -1.65), COL(120, 40, 40), E.Fabric, nil, false)
	part(m, V3(0.6, 1.0, 0.6), sc * CFrame.new(u + 3.4, 6.8, -0.6), COL(255, 222, 150), E.Neon, nil, false)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(1.3, 1.5, 1.5), sc * CFrame.new(u + sx * 3.7, 1.65, -2.0) * UP, COL(176, 96, 64), E.Concrete, CYL)
		part(m, V3(1.7, 1.7, 1.7), sc * CFrame.new(u + sx * 3.7, 3.0, -2.0), COL(70, 130, 60), E.Grass, BALL, false)
	end
	if S.porch then
		part(m, V3(6.8, 0.5, 3.6), sc * CFrame.new(u, 8.6, -2.0), S.roofC, S.roofMat)
		for _, sx in ipairs({ -1, 1 }) do
			part(m, V3(0.5, 7.6, 0.5), sc * CFrame.new(u + sx * 3.0, 4.8, -3.5), S.wood, E.Wood)
		end
	end
end

local function balcony(m, sc, u, width, y, S)
	part(m, V3(width, 0.6, 3.4), sc * CFrame.new(u, y, -1.9), S.wood, E.Wood)
	part(m, V3(width, 0.3, 0.3), sc * CFrame.new(u, y + 2.4, -3.5), S.wood, E.Wood)
	local n = math.floor(width / 1.3)
	for j = 0, n do
		part(m, V3(0.25, 2.2, 0.25), sc * CFrame.new(u - width / 2 + j * width / n, y + 1.3, -3.5), S.wood, E.Wood)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(0.3, 2.4, 3.2), sc * CFrame.new(u + sx * width / 2, y + 1.3, -1.9), S.wood, E.Wood)
	end
end

local function timberWall(m, sc, len, H, floors, FH, color)
	local n = math.max(2, math.floor(len / 3.6))
	local segw = len / n
	for j = 0, n do
		part(m, V3(0.5, H, 0.35), sc * CFrame.new(-len / 2 + j * segw, 1 + H / 2, -0.18), color, E.Wood)
	end
	for f = 0, floors do
		part(m, V3(len, 0.5, 0.35), sc * CFrame.new(0, 1 + f * FH + ((f == floors) and -0.25 or 0.25), -0.18), color, E.Wood)
	end
	for f = 1, floors do
		for j = 0, n - 1, 2 do
			local ang = math.atan2(FH - 1, segw)
			local sgn = (j % 4 == 0) and 1 or -1
			part(m, V3(math.sqrt(segw ^ 2 + (FH - 1) ^ 2), 0.35, 0.3),
				sc * CFrame.new(-len / 2 + (j + 0.5) * segw, 1 + (f - 1) * FH + FH / 2, -0.2) * CFrame.Angles(0, 0, sgn * ang), color, E.Wood)
		end
	end
end

local function gableRoof(parent, base, rb, span, len, pitch, roofC, roofMat, fillC, over)
	local a = math.rad(pitch)
	local half = span / 2 + over
	local L = half / math.cos(a)
	local ridge = rb + (span / 2) * math.tan(a)
	local drop = half * math.tan(a)
	local cy = ridge - drop / 2
	part(parent, V3(L, 0.9, len + over * 2), base * CFrame.new(half / 2, cy, 0) * CFrame.Angles(0, 0, -a), roofC, roofMat)
	part(parent, V3(L, 0.9, len + over * 2), base * CFrame.new(-half / 2, cy, 0) * CFrame.Angles(0, 0, a), roofC, roofMat)
	part(parent, V3(1.1, 0.9, len + over * 2), base * CFrame.new(0, ridge + 0.1, 0), darker(roofC), roofMat)
	local nS, hr = 5, (span / 2) * math.tan(a) - 0.6
	for s = 0, nS - 1 do
		local sw = span * (1 - (s + 0.5) / nS)
		local sh = hr / nS
		part(parent, V3(sw, sh + 0.05, len), base * CFrame.new(0, rb + s * sh + sh / 2, 0), fillC)
	end
	return ridge - rb
end

local function gardenTree(parent, pos)
	local s = rnd(0.85, 1.3)
	upright(parent, pos, 5 * s, 1.1 * s, COL(100, 72, 52), E.Wood)
	local c = pick({ COL(70, 130, 60), COL(90, 150, 60), COL(224, 140, 60), COL(236, 170, 190), COL(60, 120, 70) })
	part(parent, V3(6.6 * s, 6.6 * s, 6.6 * s), CFrame.new(pos.X, pos.Y + 7.6 * s, pos.Z), c, E.Grass, BALL, false)
	part(parent, V3(4.6 * s, 4.6 * s, 4.6 * s), CFrame.new(pos.X + 1.5 * s, pos.Y + 9.6 * s, pos.Z - 0.6 * s), c, E.Grass, BALL, false)
end

local function fenceLine(m, sc, u0, u1, z, color)
	local len = u1 - u0
	if len < 1 then return end
	local n = math.max(1, math.floor(len / 3.2))
	for j = 0, n do
		part(m, V3(0.5, 2.4, 0.5), sc * CFrame.new(u0 + j * len / n, 0.9, z), color, E.Wood)
	end
	for _, yy in ipairs({ 0.8, 1.7 }) do
		part(m, V3(len, 0.3, 0.3), sc * CFrame.new((u0 + u1) / 2, yy, z), color, E.Wood)
	end
end

----------------------------------------------------------------
-- Grundflaeche der Haeuser; Hoehe waechst ueber FH, Tueren bleiben menschlich.
local HOUSE_SCALE = 1.8
local usedHouse = {}
local function rollHouse()
	for _ = 1, 20 do
		local r = math.random()
		local kind = (r < 0.34 and "chalet") or (r < 0.49 and "bauern") or (r < 0.64 and "stadt")
			or (r < 0.84 and "riegel") or "villa"
		local S = { kind = kind }
		S.doorC, S.trimC, S.wood = pick(DOORS), pick(TRIMS), pick(WOODS)
		S.flowers = math.random() < 0.6
		S.shutC = (math.random() < 0.7) and pick(SHUTS) or nil
		S.roofC, S.roofMat = pick(ROOFS), pick({ E.Slate, E.Wood, E.Brick, E.Concrete })
		S.wallC, S.wallMat = pick(WALLS), E.SmoothPlastic
		S.chimney = math.random() < 0.7
		S.fence = math.random() < 0.45
		S.hedge = (not S.fence) and math.random() < 0.5
		S.tree = math.random() < 0.5
		S.bench = math.random() < 0.3
		S.mailbox = math.random() < 0.6
		S.porch = math.random() < 0.3
		S.over = 2.6
		if kind == "chalet" then
			S.W, S.D, S.floors = rnd(11, 16), rnd(13, 19), math.random(2, 3)
			S.upperWood = true
			S.roofType, S.pitch, S.over = "gableZ", rnd(20, 26), 3.2
			S.balcony = true
		elseif kind == "bauern" then
			S.W, S.D, S.floors = rnd(18, 26), rnd(12, 16), 2
			S.roofType, S.pitch, S.over = "gableX", rnd(26, 32), 3.6
			S.timber = true
			S.barn = true
			S.shutC = S.shutC or pick(SHUTS)
		elseif kind == "stadt" then
			S.W, S.D, S.floors = rnd(10, 14), rnd(11, 15), 3
			S.roofType = (math.random() < 0.7) and "gableX" or "flat"
			S.pitch, S.over = rnd(34, 42), 2
			S.awning = math.random() < 0.55
			S.shop = (math.random() < 0.4) and pick(SHOPS) or nil
			S.porch = false
		elseif kind == "riegel" then
			S.W, S.D, S.floors = rnd(12, 17), rnd(12, 16), 2
			S.roofType, S.pitch, S.over = "gableZ", rnd(38, 44), 2
			S.timber = true
			S.wallC = pick({ COL(245, 240, 228), COL(238, 230, 205), COL(236, 214, 190) })
		else -- villa
			S.W, S.D, S.floors = rnd(14, 20), rnd(12, 16), math.random(1, 2)
			S.roofType = "flat"
			S.shutC = nil
			S.big = true
			S.wallC = pick({ COL(240, 240, 236), COL(205, 208, 212), COL(88, 92, 98), COL(226, 214, 196) })
			S.roofC, S.roofMat = COL(60, 62, 66), E.Concrete
			S.trimC = pick({ COL(40, 44, 50), COL(230, 230, 226) })
			S.chimney = false
			S.porch = false
			S.terrace = true
		end
		S.W = math.floor(S.W * HOUSE_SCALE * 2 + 0.5) / 2
		S.D = math.floor(S.D * HOUSE_SCALE * 2 + 0.5) / 2
		local key = table.concat({ kind, S.W, S.D, S.floors, tostring(S.wallC), tostring(S.roofC), tostring(S.doorC) }, "|")
		if not usedHouse[key] then
			usedHouse[key] = true
			return S
		end
	end
	return nil
end

local function buildHouse(parent, pos, yaw, S)
	local m = Instance.new("Model")
	m.Name = "Haus_" .. S.kind
	m.Parent = parent
	local W, D, floors = S.W, S.D, S.floors
	local FH = 12.0
	local H = floors * FH
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local fr = sideFrames(base, W, D)
	part(m, V3(W + 1.2, 5, D + 1.2), base * CFrame.new(0, -1.5, 0), STONE, E.Concrete)
	if S.upperWood and floors >= 2 then
		part(m, V3(W, FH, D), base * CFrame.new(0, 1 + FH / 2, 0), S.wallC, S.wallMat)
		part(m, V3(W + 0.4, H - FH, D + 0.4), base * CFrame.new(0, 1 + FH + (H - FH) / 2, 0), S.wood, E.Wood)
	else
		part(m, V3(W, H, D), base * CFrame.new(0, 1 + H / 2, 0), S.wallC, S.wallMat)
	end
	if S.timber then
		timberWall(m, fr.front, W, H, floors, FH, S.kind == "bauern" and S.wood or COL(70, 48, 36))
		if S.kind == "riegel" then timberWall(m, fr.back, W, H, floors, FH, COL(70, 48, 36)) end
	end
	-- Eingang
	local doorU = rnd(-W * 0.15, W * 0.15)
	if S.kind == "bauern" then doorU = W * 0.16 end
	doorAt(m, fr.front, doorU, S)
	local barnU
	if S.barn then
		barnU = -W * 0.28
		part(m, V3(6.4, 7.4, 0.6), fr.front * CFrame.new(barnU, 4.7, -0.3), S.trimC, E.Wood)
		part(m, V3(5.6, 6.8, 0.5), fr.front * CFrame.new(barnU, 4.4, -0.7), darker(S.wood, 0.7), E.Wood)
		for _, sg in ipairs({ -1, 1 }) do
			part(m, V3(7.4, 0.3, 0.2), fr.front * CFrame.new(barnU, 4.4, -1.0) * CFrame.Angles(0, 0, sg * 0.72), S.trimC, E.Wood)
		end
	end
	-- Fenster Front (Fensterlaeden, Blumen)
	local ww, wh = 3.0, 3.4
	if S.big then ww, wh = 5.4, 4.4 end
	local nf = math.max(2, math.floor(W / (S.big and 9 or 8)))
	for f = 1, floors do
		local vy = 1 + (f - 1) * FH + 4.8
		for j = 1, nf do
			local u = -W / 2 + (j - 0.5) * W / nf
			local skip = (f == 1 and math.abs(u - doorU) < ww / 2 + 3.6)
			if barnU and f == 1 and math.abs(u - barnU) < 5 then skip = true end
			if not skip then windowAt(m, fr.front, u, vy, ww, wh, S) end
		end
	end
	-- Seiten + Rueckwand (einfache Fenster)
	for _, sd in ipairs({ { fr.back, W }, { fr.left, D }, { fr.right, D } }) do
		local n = math.max(1, math.floor(sd[2] / 10))
		for f = 1, floors do
			for j = 1, n do
				if math.random() < 0.6 then
					windowSimple(m, sd[1], -sd[2] / 2 + (j - 0.5) * sd[2] / n, 1 + (f - 1) * FH + 4.8, S)
				end
			end
		end
	end
	-- Dach
	local rise = 0
	if S.roofType == "gableZ" then
		rise = gableRoof(m, base, 1 + H, W, D, S.pitch, S.roofC, S.roofMat, S.wallC, S.over)
	elseif S.roofType == "gableX" then
		rise = gableRoof(m, base * CFrame.Angles(0, math.pi / 2, 0), 1 + H, D, W, S.pitch, S.roofC, S.roofMat, S.wallC, S.over)
	else
		part(m, V3(W + 2, 0.8, D + 2), base * CFrame.new(0, 1 + H + 0.4, 0), S.roofC, S.roofMat)
		for _, e in ipairs({ { 0, D / 2 + 0.9, W + 2, 0.5 }, { 0, -D / 2 - 0.9, W + 2, 0.5 }, { W / 2 + 0.9, 0, 0.5, D + 2 }, { -W / 2 - 0.9, 0, 0.5, D + 2 } }) do
			part(m, V3(e[3], 1.0, e[4]), base * CFrame.new(e[1], 1 + H + 1.2, e[2]), darker(S.roofC, 0.9), S.roofMat)
		end
		-- Dachterrasse-Details: Klimaanlage + Solarpanels
		part(m, V3(2.6, 1.8, 2.2), base * CFrame.new(-W * 0.3, 1 + H + 1.7, -D * 0.2), COL(200, 204, 208), E.Metal)
		for q = 0, 2 do
			part(m, V3(3.6, 0.2, 2.2), base * CFrame.new(W * 0.1 + q * 4, 1 + H + 1.6, -D * 0.15) * CFrame.Angles(0.35, 0, 0), COL(30, 44, 80), E.Glass)
		end
	end
	if S.chimney and S.roofType ~= "flat" then
		local span = (S.roofType == "gableZ") and W or D
		local off = span * 0.22
		local ry = 1 + H + (span / 2 - off) * math.tan(math.rad(S.pitch))
		local cx, cz = off, -D * 0.22
		if S.roofType == "gableX" then cx, cz = -W * 0.25, off end
		part(m, V3(2, 5.6, 2), base * CFrame.new(cx, ry + 1.4, cz), COL(130, 120, 112), E.Brick)
		part(m, V3(2.6, 0.5, 2.6), base * CFrame.new(cx, ry + 4.4, cz), COL(90, 88, 86), E.Concrete)
	end
	-- Details je Typ
	if S.balcony then balcony(m, fr.front, 0, W * 0.7, 1 + FH, S) end
	if S.awning then
		local ns = 6
		for j = 1, ns do
			part(m, V3(W / ns, 0.3, 3.4), fr.front * CFrame.new(-W / 2 + (j - 0.5) * W / ns, 8.0, -1.8) * CFrame.Angles(-0.35, 0, 0),
				(j % 2 == 0) and COL(200, 40, 40) or WHITE, E.Fabric)
		end
	end
	if S.shop then
		local b = part(m, V3(W * 0.62, 1.7, 0.3), fr.front * CFrame.new(0, 10.3, -0.3), COL(40, 44, 52), E.SmoothPlastic)
		textOn(b, Enum.NormalId.Front, S.shop, COL(255, 214, 90))
	end
	if S.terrace then
		part(m, V3(W * 0.5, 0.4, 5.6), fr.front * CFrame.new(-W * 0.22, 0.4, -3.2), COL(170, 130, 96), E.WoodPlanks)
		part(m, V3(W * 0.5, 1.6, 0.15), fr.front * CFrame.new(-W * 0.22, 1.4, -5.9), GLASSC, E.Glass, nil, nil, 0.5)
		part(m, V3(2.6, 0.5, 1.0), fr.front * CFrame.new(-W * 0.22, 0.9, -3.6), COL(240, 240, 236), E.Fabric)
	end
	-- Hausnummer
	local plate = part(m, V3(1.5, 1.0, 0.2), fr.front * CFrame.new(doorU + 3.3, 5.2, -0.45), WHITE)
	textOn(plate, Enum.NormalId.Front, tostring(math.random(1, 99)), COL(20, 20, 20), Enum.Font.GothamBold)
	-- Garten
	part(m, V3(3.6, 0.2, 5.4), fr.front * CFrame.new(doorU, 0.1, -5.4), STONE, E.Cobblestone)
	if S.fence then
		fenceLine(m, fr.front, -W / 2 - 4, doorU - 2.4, -7.6, S.wood)
		fenceLine(m, fr.front, doorU + 2.4, W / 2 + 4, -7.6, S.wood)
	elseif S.hedge then
		part(m, V3(doorU - 2.4 + W / 2 + 4, 1.8, 1.2), fr.front * CFrame.new((doorU - 2.4 - W / 2 - 4) / 2, 0.9, -7.6), COL(58, 116, 54), E.Grass)
		part(m, V3(W / 2 + 4 - doorU - 2.4, 1.8, 1.2), fr.front * CFrame.new((doorU + 2.4 + W / 2 + 4) / 2, 0.9, -7.6), COL(58, 116, 54), E.Grass)
	end
	if S.bench then
		part(m, V3(3.2, 0.35, 1.2), fr.front * CFrame.new(doorU - 5.2, 1.3, -2.6), S.wood, E.Wood)
		part(m, V3(3.2, 1.0, 0.25), fr.front * CFrame.new(doorU - 5.2, 1.9, -2.0), S.wood, E.Wood)
	end
	if S.mailbox then
		part(m, V3(0.4, 1.8, 0.4), fr.front * CFrame.new(doorU + 4.6, 0.9, -7.2), COL(70, 70, 74), E.Metal)
		part(m, V3(1.2, 0.9, 0.8), fr.front * CFrame.new(doorU + 4.6, 2.1, -7.2), COL(255, 204, 0), E.SmoothPlastic)
	end
	if S.tree then
		local side = pick({ -1, 1 })
		local tp = (base * CFrame.new(side * (W / 2 + 6), 0, rnd(-D / 4, D / 4))).Position
		gardenTree(m, V3(tp.X, pos.Y, tp.Z))
	end
	return m
end

----------------------------------------------------------------
-- CSG-SPITZPYRAMIDEN (fuer Tannen + Kirchturm). Fallback falls CSG fehlt.
----------------------------------------------------------------
local ORG = V3(0, 4000, 0)
local csgOK = true
local csgTemp = {}

local function csgPyramid(a, h, sides, rot)
	local L = math.max(a, h) * 6
	local b = Instance.new("Part")
	b.Anchored = true
	b.Size = V3(L, h, L)
	b.CFrame = CFrame.new(ORG.X, ORG.Y + h / 2, ORG.Z)
	b.Parent = Workspace
	local cuts = {}
	for k = 0, sides - 1 do
		local th = rot + k * 2 * math.pi / sides
		local u = V3(math.cos(th), 0, math.sin(th))
		local n = (u * h + V3(0, a, 0)).Unit
		local t = V3(-math.sin(th), 0, math.cos(th))
		local x = n:Cross(t)
		local c = Instance.new("Part")
		c.Anchored = true
		c.Size = V3(L, L, L)
		c.CFrame = CFrame.fromMatrix(ORG + V3(0, h, 0) - n * (L / 2), x, n, t)
		c.Parent = Workspace
		cuts[#cuts + 1] = c
	end
	local ok, res = pcall(function()
		return b:IntersectAsync(cuts, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	end)
	b:Destroy()
	for _, c in ipairs(cuts) do c:Destroy() end
	if not ok then error(res, 0) end
	return res
end

local function measureBottom(u)
	local ok, off = pcall(function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { u }
		local hit = Workspace:Raycast(u.Position - V3(0, u.Size.Y * 2 + 50, 0), V3(0, u.Size.Y * 4 + 100, 0), rp)
		if hit then return u.Position.Y - hit.Position.Y end
		return nil
	end)
	if ok and off and off > 0.1 and off < u.Size.Y then return off end
	return u.Size.Y / 2
end

-- Spitze Pyramide platzieren (Boden bei y). Bewusst ohne CSG: die CSG-Spitze
-- erzeugte in Studio einen riesigen flachen Block.
local spireTemplate
local function placeSpire(parent, x, y, z, a, h, color, yaw)
	local n = 9
	for i = 0, n - 1 do
		local sw = 2 * a * (1 - i / n) + 0.3
		part(parent, V3(sw, h / n + 0.05, sw),
			CFrame.new(x, y + i * h / n + h / n / 2, z) * CFrame.Angles(0, yaw or 0, 0),
			color, E.Slate)
	end
end

----------------------------------------------------------------
-- KIRCHE (nur eine!)
----------------------------------------------------------------
local function buildChurch(parent, x, y, z, yaw)
	local m = Instance.new("Model")
	m.Name = "Kirche"
	m.Parent = parent
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local WALL, ROOF, TRIM = COL(238, 232, 218), COL(112, 58, 50), COL(176, 170, 160)
	local BLUE = COL(96, 140, 200)
	-- Kirche 1.5x; das Portal bleibt bewusst gross, wird aber nicht mit-skaliert.
	local NW, ND, NH = 22, 39, 19
	local TW, TH = 13.5, 48
	part(m, V3(NW + 2, 3, ND + 2), base * CFrame.new(0, -0.5, 0), STONE, E.Concrete)
	part(m, V3(NW, NH, ND), base * CFrame.new(0, 1 + NH / 2, 0), WALL)
	gableRoof(m, base, 1 + NH, NW, ND, 38, ROOF, E.Slate, WALL, 3.0)
	-- Chor hinten
	part(m, V3(13.5, 12, 7.5), base * CFrame.new(0, 7.5, -ND / 2 - 3.75), WALL)
	part(m, V3(15, 1.2, 9), base * CFrame.new(0, 14.1, -ND / 2 - 3.75), ROOF, E.Slate)
	-- Seitenfenster + Strebepfeiler
	local sf = sideFrames(base, NW, ND)
	for _, sc in ipairs({ sf.left, sf.right }) do
		for j = 0, 3 do
			local u = -ND / 2 + (j + 0.5) * ND / 4
			part(m, V3(4.2, 9.6, 0.6), sc * CFrame.new(u, 10.4, -0.3), TRIM, E.Concrete)
			part(m, V3(3.0, 8.4, 0.4), sc * CFrame.new(u, 10.4, -0.5), BLUE, E.Glass, nil, nil, 0.2)
			part(m, V3(3.0, 3.0, 0.4), sc * CFrame.new(u, 15.4, -0.5) * CFrame.Angles(0, 0, math.pi / 4), BLUE, E.Glass, nil, nil, 0.2)
		end
		for j = 0, 4 do
			part(m, V3(1.8, 15, 2.1), sc * CFrame.new(-ND / 2 + 1.5 + j * (ND - 3) / 4, 8.5, -1.0), TRIM, E.Concrete)
		end
	end
	-- Turm
	local TZ = ND / 2 + 3.5
	local topY = 1 + TH
	part(m, V3(TW + 3, 4.5, TW + 3), base * CFrame.new(0, -0.75, TZ), STONE, E.Concrete)
	part(m, V3(TW, TH, TW), base * CFrame.new(0, 1 + TH / 2, TZ), WALL)
	part(m, V3(TW + 2.1, 1.5, TW + 2.1), base * CFrame.new(0, topY + 0.75, TZ), TRIM, E.Concrete)
	local tf = sideFrames(base * CFrame.new(0, 0, TZ), TW, TW)
	for _, sc in ipairs({ tf.front, tf.back, tf.left, tf.right }) do
		part(m, V3(0.45, 7.2, 7.2), sc * CFrame.new(0, topY - 5, -0.25) * CFrame.Angles(0, math.pi / 2, 0), WHITE, E.SmoothPlastic, CYL)
		part(m, V3(0.3, 3.2, 0.25), sc * CFrame.new(0, topY - 4, -0.6), COL(20, 20, 20), E.Metal, nil, false)
		part(m, V3(2.2, 0.3, 0.25), sc * CFrame.new(0.9, topY - 5, -0.6), COL(20, 20, 20), E.Metal, nil, false)
		part(m, V3(4.8, 7.5, 0.7), sc * CFrame.new(0, topY - 10, -0.35), TRIM, E.Concrete)
		part(m, V3(3.6, 6.3, 0.4), sc * CFrame.new(0, topY - 10, -0.5), COL(30, 30, 36), E.Slate)
	end
	-- Spitzer Turmhelm
	local tp = (base * CFrame.new(0, 0, TZ)).Position
	placeSpire(m, tp.X, y + topY + 1, tp.Z, 8.1, 27, COL(70, 80, 92), yaw)
	part(m, V3(0.6, 3.8, 0.6), CFrame.new(tp.X, y + topY + 29.2, tp.Z), COL(230, 190, 60), E.Metal)
	part(m, V3(2.6, 0.6, 0.6), CFrame.new(tp.X, y + topY + 29.6, tp.Z) * CFrame.Angles(0, yaw, 0), COL(230, 190, 60), E.Metal)
	-- Eingang (grosses Portal)
	local ft = tf.front
	part(m, V3(7.2, 9.4, 0.9), ft * CFrame.new(0, 5.7, -0.45), TRIM, E.Concrete)
	part(m, V3(5.0, 5.0, 0.9), ft * CFrame.new(0, 10.0, -0.45) * CFrame.Angles(0, 0, math.pi / 4), TRIM, E.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(2.9, 8.2, 0.5), ft * CFrame.new(sx * 1.5, 5.1, -0.95), COL(88, 56, 38), E.Wood)
		part(m, V3(0.3, 1.2, 0.3), ft * CFrame.new(sx * 0.4, 5.0, -1.3), COL(40, 40, 44), E.Metal)
		part(m, V3(0.8, 1.6, 0.6), ft * CFrame.new(sx * 4.6, 4.5, -1.3), COL(255, 222, 150), E.Neon, nil, false)
	end
	part(m, V3(0.3, 3.4, 3.4), ft * CFrame.new(0, 16, -0.2) * CFrame.Angles(0, math.pi / 2, 0), BLUE, E.Glass, CYL, nil, 0.2)
	part(m, V3(3.4, 0.2, 0.3), ft * CFrame.new(0, 16, -0.4), TRIM, E.Concrete)
	part(m, V3(0.2, 3.4, 0.3), ft * CFrame.new(0, 16, -0.4), TRIM, E.Concrete)
	for s = 1, 3 do
		part(m, V3(11 - s * 0.9, 0.5, 2.6 - 0.0), ft * CFrame.new(0, 1.0 - s * 0.35, -(0.9 + s * 0.8)), STONE, E.Concrete)
	end
	-- Weg + Friedhof + Baeume
	part(m, V3(12, 0.25, 40), base * CFrame.new(0, 0.1, TZ + 4.5 + 20), COL(176, 172, 164), E.Cobblestone)
	for i = 0, 7 do
		local gx = -24 - (i % 4) * 5.4
		local gz = -9 + math.floor(i / 4) * 9
		part(m, V3(2.1, 3.3, 0.75), base * CFrame.new(gx, 1.65, gz), COL(130, 130, 136), E.Slate)
		part(m, V3(0.6, 1.5, 0.6), base * CFrame.new(gx, 3.9, gz), COL(130, 130, 136), E.Slate)
	end
	part(m, V3(27, 1.2, 0.9), base * CFrame.new(-33.75, 0.6, -16.5), STONE, E.Cobblestone)
	part(m, V3(27, 1.2, 0.9), base * CFrame.new(-33.75, 0.6, 10.5), STONE, E.Cobblestone)
	for _, sx in ipairs({ -1, 1 }) do
		local p = (base * CFrame.new(sx * 18, 0, TZ + 12)).Position
		gardenTree(m, V3(p.X, y, p.Z))
	end
	return m
end

----------------------------------------------------------------
-- DOENER LADEN (Start-Ort: hier verdient man Geld)
----------------------------------------------------------------
local function buildDoener(parent, x, y, z, yaw)
	local m = Instance.new("Model")
	m.Name = "DoenerLaden"
	m.Parent = parent
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local W, D, H = 30, 21, 13.5
	local fr = sideFrames(base, W, D).front
	local wallC, red, dark = COL(240, 232, 214), COL(190, 36, 40), COL(40, 42, 48)
	local oe, ue = utf8.char(246), utf8.char(252)
	-- Boden + Platz
	part(m, V3(W + 1.5, 8, D + 1.5), base * CFrame.new(0, -3, 0), STONE, E.Concrete)
	part(m, V3(W - 1.6, 0.2, D - 1.6), base * CFrame.new(0, 1.1, 0), COL(226, 220, 208), E.Marble)
	part(m, V3(W + 20, 3.0, 30), base * CFrame.new(0, -0.5, D / 2 + 0.75 + 15), COL(170, 166, 160), E.Cobblestone)
	-- Waende
	part(m, V3(W, H, 0.8), base * CFrame.new(0, 1 + H / 2, -D / 2 + 0.4), wallC)
	part(m, V3(0.8, H, D), base * CFrame.new(-W / 2 + 0.4, 1 + H / 2, 0), wallC)
	part(m, V3(0.8, H, D), base * CFrame.new(W / 2 - 0.4, 1 + H / 2, 0), wallC)
	local dw = 5.6
	local fw = (W - dw) / 2
	part(m, V3(dw, H - 7.4, 0.8), base * CFrame.new(0, 1 + 7.4 + (H - 7.4) / 2, D / 2 - 0.4), wallC)
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * (dw / 2 + fw / 2)
		part(m, V3(fw, 2, 0.8), base * CFrame.new(cx, 2, D / 2 - 0.4), wallC)
		part(m, V3(fw, H - 6, 0.8), base * CFrame.new(cx, 7 + (H - 6) / 2, D / 2 - 0.4), wallC)
		for _, ss in ipairs({ -1, 1 }) do
			part(m, V3(1.0, 4, 0.8), base * CFrame.new(cx + ss * (fw / 2 - 0.5), 5, D / 2 - 0.4), wallC)
		end
		part(m, V3(fw - 2, 4, 0.2), base * CFrame.new(cx, 5, D / 2 - 0.4), GLASSC, E.Glass, nil, false, 0.45)
		part(m, V3(fw - 1.6, 0.3, 0.5), base * CFrame.new(cx, 3.05, D / 2 + 0.1), red, E.SmoothPlastic)
	end
	-- Tuer: Rahmen + zwei offene Glasfluegel
	part(m, V3(0.5, 7.4, 1.0), base * CFrame.new(-dw / 2 - 0.25, 4.7, D / 2 - 0.4), red)
	part(m, V3(0.5, 7.4, 1.0), base * CFrame.new(dw / 2 + 0.25, 4.7, D / 2 - 0.4), red)
	part(m, V3(dw + 1, 0.5, 1.0), base * CFrame.new(0, 8.65, D / 2 - 0.4), red)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(0.25, 6.8, 2.7), base * CFrame.new(sx * (dw / 2 - 0.1), 4.5, D / 2 + 1.5), GLASSC, E.Glass, nil, false, 0.4)
		part(m, V3(0.35, 0.5, 0.5), base * CFrame.new(sx * (dw / 2 - 0.1), 4.4, D / 2 + 2.6), COL(200, 200, 205), E.Metal, nil, false)
	end
	local sign0 = part(m, V3(2.6, 0.9, 0.2), fr * CFrame.new(0, 6.2, -0.9), COL(30, 120, 60), E.Neon, nil, false)
	textOn(sign0, Enum.NormalId.Front, "OFFEN", WHITE)
	-- Dach + grosses Schild
	part(m, V3(W + 1.6, 0.8, D + 1.6), base * CFrame.new(0, 1 + H + 0.4, 0), dark, E.Concrete)
	for _, e in ipairs({ { 0, D / 2 + 0.8, W + 1.6, 0.5 }, { 0, -D / 2 - 0.8, W + 1.6, 0.5 }, { W / 2 + 0.8, 0, 0.5, D + 1.6 }, { -W / 2 - 0.8, 0, 0.5, D + 1.6 } }) do
		part(m, V3(e[3], 1.0, e[4]), base * CFrame.new(e[1], 1 + H + 1.3, e[2]), red, E.SmoothPlastic)
	end
	local board = part(m, V3(17, 4.6, 0.7), fr * CFrame.new(0, 1 + H + 1.8 + 2.3, -0.6), red, E.SmoothPlastic)
	textOn(board, Enum.NormalId.Front, "D" .. oe .. "ner Laden", COL(255, 220, 90))
	part(m, V3(17.6, 0.3, 0.9), fr * CFrame.new(0, 1 + H + 1.8 + 4.75, -0.6), COL(255, 230, 120), E.Neon, nil, false)
	part(m, V3(17.6, 0.3, 0.9), fr * CFrame.new(0, 1 + H + 1.8 - 0.05, -0.6), COL(255, 230, 120), E.Neon, nil, false)
	for _, sx in ipairs({ -7, 7 }) do
		part(m, V3(0.6, 2.2, 0.6), fr * CFrame.new(sx, 1 + H + 1.9, -0.6), dark, E.Metal)
	end
	local sub = part(m, V3(13, 1.2, 0.3), fr * CFrame.new(0, 1 + H - 1.0, -0.3), dark, E.SmoothPlastic)
	textOn(sub, Enum.NormalId.Front, "KEBAB  -  FALAFEL  -  D" .. ue .. "R" .. ue .. "M", COL(255, 220, 90), Enum.Font.GothamBold)
	-- Streifen-Markise
	for j = 1, 10 do
		part(m, V3(W / 10, 0.3, 4.4), fr * CFrame.new(-W / 2 + (j - 0.5) * W / 10, 8.0, -2.4) * CFrame.Angles(-0.33, 0, 0),
			(j % 2 == 0) and red or WHITE, E.Fabric)
	end
	-- Haengeschild (von der Strasse gut sichtbar)
	part(m, V3(0.3, 0.3, 3.4), fr * CFrame.new(W / 2 + 0.2, 1 + H - 2.2, -1.9), dark, E.Metal)
	local blade = part(m, V3(0.4, 3.2, 3.0), fr * CFrame.new(W / 2 + 0.2, 1 + H - 4.0, -2.5), red, E.SmoothPlastic)
	textOn(blade, Enum.NormalId.Right, "D" .. oe .. "NER", COL(255, 220, 90))
	textOn(blade, Enum.NormalId.Left, "D" .. oe .. "NER", COL(255, 220, 90))
	-- Innenraum
	part(m, V3(12, 3.4, 2.4), base * CFrame.new(0, 2.7, -0.8), red, E.SmoothPlastic)
	part(m, V3(12.6, 0.3, 3.0), base * CFrame.new(0, 4.55, -0.8), COL(232, 232, 228), E.Marble)
	part(m, V3(1.6, 1.0, 1.3), base * CFrame.new(3.8, 5.2, -0.8), dark, E.Metal)
	part(m, V3(1.2, 0.9, 0.15), base * CFrame.new(3.8, 6.0, -1.2) * CFrame.Angles(0.4, 0, 0), COL(90, 200, 120), E.Neon, nil, false)
	-- Doener-Spiess
	local sp = base * CFrame.new(0, 1, -D / 2 + 2.6)
	part(m, V3(0.3, 5, 2.8), base * CFrame.new(0, 6.0, -D / 2 + 0.85), COL(255, 120, 30), E.Neon, nil, false)
	local spos = sp.Position
	upright(m, V3(spos.X, spos.Y, spos.Z), 2.6, 1.2, dark, E.Metal)
	local dias = { 2.6, 3.0, 3.4, 3.7, 3.5, 3.1, 2.6 }
	for k, dd in ipairs(dias) do
		upright(m, V3(spos.X, spos.Y + 2.6 + (k - 1) * 0.9, spos.Z), 0.9, dd, (k % 2 == 0) and COL(150, 86, 52) or COL(124, 66, 40), E.Fabric, false)
	end
	upright(m, V3(spos.X, spos.Y + 2.6 + 7 * 0.9, spos.Z), 1.2, 0.3, COL(200, 200, 205), E.Metal, false)
	-- Menutafel, Regal, Kuehlschrank
	local menu = part(m, V3(8, 4.4, 0.2), base * CFrame.new(5.8, 7.0, -D / 2 + 0.95) * CFrame.Angles(0, math.pi, 0), dark, E.SmoothPlastic)
	textOn(menu, Enum.NormalId.Front, "MEN" .. ue .. "\nD" .. oe .. "ner  9.50 Fr\nD" .. ue .. "r" .. ue .. "m  10.50 Fr\nFalafel  8.50 Fr\nAyran  3.00 Fr", COL(255, 220, 90), Enum.Font.GothamBold)
	for q = 0, 2 do
		part(m, V3(6, 0.3, 1.2), base * CFrame.new(-6, 3 + q * 1.7, -D / 2 + 1.2), COL(150, 100, 62), E.Wood)
		for b2 = 0, 3 do
			part(m, V3(0.7, 1.0, 0.7), base * CFrame.new(-8 + b2 * 1.5, 3.65 + q * 1.7, -D / 2 + 1.2), pick({ COL(200, 60, 50), COL(60, 120, 200), COL(240, 200, 60), COL(70, 160, 90) }), E.SmoothPlastic, nil, false)
		end
	end
	part(m, V3(3, 5.4, 2.4), base * CFrame.new(-8.2, 3.7, 2.5), COL(236, 238, 240), E.Metal)
	part(m, V3(0.25, 2.0, 0.3), base * CFrame.new(-6.6, 4.2, 3.8), COL(120, 120, 126), E.Metal, nil, false)
	local lamp = part(m, V3(2.6, 0.4, 2.6), base * CFrame.new(0, 1 + H - 0.4, 1), COL(255, 236, 190), E.Neon, nil, false)
	local pl = Instance.new("PointLight")
	pl.Range, pl.Brightness, pl.Color = 28, 1.4, COL(255, 226, 180)
	pl.Parent = lamp
	-- Job-Punkt (Geld verdienen)
	local job = part(m, V3(4, 3, 4), base * CFrame.new(0, 2.8, -3.6), COL(255, 255, 255), E.SmoothPlastic, nil, false, 1)
	job.Name = "JobPoint"
	job:SetAttribute("Job", "Doener")
	part(m, V3(0.15, 4, 4), base * CFrame.new(0, 1.25, -3.6) * UP, COL(60, 230, 120), E.Neon, CYL, false, 0.2)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "D" .. oe .. "ner machen (Geld verdienen)"
	pp.ObjectText = "D" .. oe .. "ner Laden"
	pp.HoldDuration = 0.4
	pp.MaxActivationDistance = 12
	pp.Parent = job
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 56)
	bb.StudsOffset = V3(0, 3.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.Parent = job
	local bl = Instance.new("TextLabel")
	bl.Size = UDim2.fromScale(1, 1)
	bl.BackgroundColor3 = COL(30, 120, 60)
	bl.BackgroundTransparency = 0.15
	bl.TextColor3 = WHITE
	bl.Font = Enum.Font.GothamBold
	bl.TextScaled = true
	bl.Text = "Hier Geld verdienen!"
	bl.Parent = bb
	-- Aussenbereich: Tische mit Sonnenschirmen
	local function tablePos(u, t) return (fr * CFrame.new(u, 1, -t)).Position end
	for _, tb in ipairs({ { -8, 9 }, { 8, 9 }, { -8, 18 }, { 8, 18 } }) do
		local p = tablePos(tb[1], tb[2])
		upright(m, p, 3.2, 0.5, COL(90, 90, 96), E.Metal)
		part(m, V3(0.3, 3.8, 3.8), CFrame.new(p.X, p.Y + 3.3, p.Z) * UP, WHITE, E.SmoothPlastic, CYL)
		upright(m, p, 8, 0.3, COL(200, 200, 205), E.Metal, false)
		part(m, V3(0.3, 8.4, 8.4), CFrame.new(p.X, p.Y + 8.1, p.Z) * UP, (math.random() < 0.5) and red or COL(240, 200, 60), E.Fabric, CYL, false)
		for c = 0, 2 do
			local ang = c * 2.1 + 0.5
			local cx, cz = p.X + math.cos(ang) * 3.2, p.Z + math.sin(ang) * 3.2
			part(m, V3(1.4, 0.25, 1.4), CFrame.new(cx, p.Y + 1.9, cz), COL(60, 66, 74), E.Metal)
			upright(m, V3(cx, p.Y, cz), 1.8, 0.35, COL(60, 66, 74), E.Metal, false)
			part(m, V3(1.4, 1.3, 0.2), CFrame.new(cx + math.cos(ang) * 0.6, p.Y + 2.6, cz + math.sin(ang) * 0.6) * CFrame.Angles(0, -ang + math.pi / 2, 0), COL(60, 66, 74), E.Metal, nil, false)
		end
	end
	-- Kundenstopper, Muelleimer, Flagge, Lichterkette
	local ap = fr * CFrame.new(5.5, 2.6, -4.5)
	local aboard = part(m, V3(2.6, 3.4, 0.25), ap * CFrame.Angles(0.18, 0, 0), dark, E.SmoothPlastic, nil, false)
	textOn(aboard, Enum.NormalId.Front, "Heute:\nD" .. oe .. "ner 9.50", COL(255, 220, 90), Enum.Font.GothamBold)
	for _, u in ipairs({ -3.8, 3.8 }) do
		upright(m, tablePos(u, 22), 2.4, 1.5, COL(40, 100, 60), E.Metal)
	end
	local fp = tablePos(15, 4)
	swissFlag(m, fp.X, fp.Y, fp.Z, 14, yaw)
	for _, sx in ipairs({ -17, 17 }) do
		local p = tablePos(sx, 24)
		upright(m, p, 8, 0.4, COL(90, 90, 96), E.Metal)
	end
	for b2 = 0, 12 do
		local u = -17 + b2 * 34 / 12
		local p = tablePos(u, 24)
		part(m, V3(0.7, 0.7, 0.7), CFrame.new(p.X, p.Y + 7.4 - 0.9 * math.sin(b2 / 12 * math.pi), p.Z), COL(255, 230, 140), E.Neon, BALL, false)
	end
	for _, bpos in ipairs({ { -4, 30 }, { 4, 30 } }) do
		local p = tablePos(bpos[1], bpos[2])
		part(m, V3(3.2, 0.35, 1.2), CFrame.new(p.X, p.Y + 1.6, p.Z) * CFrame.Angles(0, yaw + math.pi / 2, 0), COL(150, 100, 62), E.Wood)
	end
	return m, base
end

----------------------------------------------------------------
-- GARAGE (alle 15 exakt gleich!)
----------------------------------------------------------------
local GS0 = { trimC = COL(190, 192, 196) }
local function buildGarage(parent, g)
	local m = Instance.new("Model")
	m.Name = "Garage_" .. g.idx
	m:SetAttribute("GarageNumber", g.idx)
	m.Parent = parent
	local base = CFrame.new(g.x, g.h, g.z) * CFrame.Angles(0, g.yaw, 0)
	local W, D, H = GW, GD, GH
	local fr = sideFrames(base, W, D).front
	local BODY, PLINTH, ORANGE, DARKR = COL(54, 58, 66), COL(92, 96, 102), COL(240, 130, 30), COL(36, 38, 44)
	local YEL, BLK = COL(250, 200, 30), COL(24, 24, 28)
	local UD = -2.2   -- Position des Rolltors
	-- Fundament, Koerper, Sockel, Zierband
	part(m, V3(W + 2, 1.2, D + 2), base, COL(130, 130, 126), E.Concrete)
	part(m, V3(W, H, D), base * CFrame.new(0, 0.6 + H / 2, 0), BODY, E.Concrete)
	part(m, V3(W + 0.25, 1.2, D + 0.25), base * CFrame.new(0, 1.2, 0), PLINTH, E.Concrete)
	part(m, V3(W + 0.3, 0.9, D + 0.3), base * CFrame.new(0, 0.6 + H - 0.45, 0), ORANGE)
	-- Flachdach mit Rand
	part(m, V3(W + 2.4, 0.8, D + 2.4), base * CFrame.new(0, 0.6 + H + 0.4, 0), DARKR, E.Concrete)
	for _, e in ipairs({ { 0, D / 2 + 1.1, W + 2.4, 0.5 }, { 0, -D / 2 - 1.1, W + 2.4, 0.5 }, { W / 2 + 1.1, 0, 0.5, D + 2.4 }, { -W / 2 - 1.1, 0, 0.5, D + 2.4 } }) do
		part(m, V3(e[3], 0.9, e[4]), base * CFrame.new(e[1], 0.6 + H + 1.2, e[2]), PLINTH, E.Concrete)
	end
	-- Rolltor
	part(m, V3(11.2, 7.2, 0.5), fr * CFrame.new(UD, 0.6 + 3.6, -0.25), ORANGE)
	part(m, V3(10.4, 6.6, 0.4), fr * CFrame.new(UD, 0.6 + 3.3, -0.45), COL(205, 208, 212), E.Metal)
	for i = 1, 7 do
		part(m, V3(10.4, 0.14, 0.18), fr * CFrame.new(UD, 0.6 + 0.9 * i, -0.7), COL(150, 154, 160), E.Metal)
	end
	for i = 0, 3 do
		part(m, V3(2.0, 0.8, 0.12), fr * CFrame.new(UD - 3.9 + i * 2.6, 0.6 + 6.2, -0.72), COL(70, 100, 140), E.Glass, nil, false, 0.3)
	end
	part(m, V3(11.2, 0.9, 0.7), fr * CFrame.new(UD, 0.6 + 7.65, -0.35), DARKR, E.Metal)
	for i = 0, 9 do
		part(m, V3(1.04, 0.45, 0.3), fr * CFrame.new(UD - 4.68 + i * 1.04, 0.6 + 0.25, -0.65), (i % 2 == 0) and YEL or BLK)
	end
	part(m, V3(10.4, 0.15, 0.15), fr * CFrame.new(UD, 0.6 + 7.12, -0.85), COL(255, 244, 220), E.Neon, nil, false)
	-- Seitentuer
	part(m, V3(3.6, 6.4, 0.5), fr * CFrame.new(5.8, 0.6 + 3.2, -0.25), COL(190, 192, 196), E.Metal)
	part(m, V3(2.9, 5.9, 0.4), fr * CFrame.new(5.8, 0.6 + 2.95, -0.5), COL(214, 70, 40), E.Metal)
	part(m, V3(1.3, 1.6, 0.12), fr * CFrame.new(5.8, 0.6 + 4.6, -0.74), GLASSC, E.Glass, nil, false, 0.3)
	part(m, V3(0.3, 1.0, 0.3), fr * CFrame.new(4.7, 0.6 + 3.0, -0.8), COL(210, 210, 215), E.Metal, nil, false)
	part(m, V3(4.2, 0.6, 1.8), fr * CFrame.new(5.8, 0.3, -1.2), COL(140, 140, 136), E.Concrete)
	part(m, V3(0.5, 0.9, 0.5), fr * CFrame.new(3.55, 0.6 + 5.9, -0.45), COL(255, 226, 160), E.Neon, nil, false)
	local plate = part(m, V3(2.6, 1.2, 0.25), fr * CFrame.new(5.8, 0.6 + 7.55, -0.15), DARKR, E.SmoothPlastic)
	if GARAGE_NUMBERS then textOn(plate, Enum.NormalId.Front, tostring(g.idx), WHITE, Enum.Font.GothamBlack) end
	-- Dachschild "GARAGE"
	local sign = part(m, V3(9, 2.0, 0.5), fr * CFrame.new(UD, 0.6 + H + 0.8 + 1.4, -0.5), ORANGE)
	textOn(sign, Enum.NormalId.Front, "GARAGE", WHITE)
	part(m, V3(9.2, 0.2, 0.7), fr * CFrame.new(UD, 0.6 + H + 0.8 + 0.4, -0.5), COL(255, 244, 220), E.Neon, nil, false)
	for _, sx in ipairs({ -3.6, 3.6 }) do
		part(m, V3(0.5, 1.0, 0.5), fr * CFrame.new(UD + sx, 0.6 + H + 1.2, -0.5), DARKR, E.Metal)
	end
	-- Dach: Solarpanels, Klimageraet, Antenne
	for q = 0, 2 do
		part(m, V3(3.8, 0.2, 2.4), base * CFrame.new(-4.6 + q * 4.4, 0.6 + H + 1.5, -2.6) * CFrame.Angles(-0.35, 0, 0), COL(28, 40, 78), E.Glass)
	end
	part(m, V3(2.6, 1.6, 2.2), base * CFrame.new(5.2, 0.6 + H + 1.6, 2.2), COL(200, 204, 208), E.Metal)
	part(m, V3(1.6, 0.2, 1.6), base * CFrame.new(5.2, 0.6 + H + 2.5, 2.2), COL(60, 64, 70), E.Metal)
	upright(m, (base * CFrame.new(-6.4, 0.6 + H + 0.8, 4.2)).Position, 5, 0.3, COL(190, 192, 196), E.Metal, false)
	-- Seitenwand: Fenster, Lueftung, Regenrohr
	local sf = sideFrames(base, W, D)
	for _, u in ipairs({ -3.2, 3.2 }) do
		windowSimple(m, sf.left, u, 0.6 + 5.2, GS0)
	end
	part(m, V3(3.2, 2.2, 0.3), sf.right * CFrame.new(0, 0.6 + 5.0, -0.15), COL(190, 192, 196), E.Metal)
	for i = 0, 3 do
		part(m, V3(3.0, 0.12, 0.25), sf.right * CFrame.new(0, 0.6 + 4.2 + i * 0.55, -0.3), DARKR, E.Metal, nil, false)
	end
	upright(m, (base * CFrame.new(-W / 2 - 0.3, 0.6, D / 2 + 0.2)).Position, H, 0.45, COL(150, 154, 160), E.Metal, false)
	-- Vorplatz + Markierungen + Velo/Toeffli-Abstellplatz
	part(m, V3(W + 4, 1.2, 20), base * CFrame.new(0, -0.3, D / 2 + 0.8 + 10), COL(176, 176, 170), E.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(0.3, 0.1, 20), base * CFrame.new(sx * (W / 2 + 1.5), 0.33, D / 2 + 0.8 + 10), YEL, E.SmoothPlastic, nil, false)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(m, V3(0.25, 0.1, 7), fr * CFrame.new(UD + sx * 1.5, 0.33, -9), WHITE, E.SmoothPlastic, nil, false)
	end
	for _, tz in ipairs({ -5.5, -12.5 }) do
		part(m, V3(3.2, 0.1, 0.25), fr * CFrame.new(UD, 0.33, tz), WHITE, E.SmoothPlastic, nil, false)
	end
	local spawn = part(m, V3(2.6, 0.2, 6.4), fr * CFrame.new(UD, 0.4, -9), WHITE, E.SmoothPlastic, nil, false, 1)
	spawn.Name = "BikeSpawn"
	spawn:SetAttribute("GarageNumber", g.idx)
	-- Deko: Reifenstapel, Oelfaesser, Pflanzkuebel
	local tp = (fr * CFrame.new(-9.9, 0, -2.4)).Position
	for i = 0, 2 do
		upright(m, V3(tp.X, g.h + 0.3 + i * 0.9, tp.Z), 0.9, 2.4, BLK, E.Fabric, false)
	end
	for k, c in ipairs({ COL(190, 40, 40), COL(50, 90, 170) }) do
		local bp = (fr * CFrame.new(9.9, 0, -2.2 - (k - 1) * 2.4)).Position
		upright(m, V3(bp.X, g.h + 0.3, bp.Z), 3, 1.8, c, E.Metal)
		upright(m, V3(bp.X, g.h + 1.3, bp.Z), 0.3, 1.9, BLK, E.Metal, false)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local pp = (fr * CFrame.new(sx * (W / 2 + 1.2), 0.9, -19)).Position
		part(m, V3(2.4, 1.2, 2.4), CFrame.new(pp) * CFrame.Angles(0, g.yaw, 0), COL(110, 76, 50), E.Wood)
		part(m, V3(2.8, 2.8, 2.8), CFrame.new(pp.X, pp.Y + 1.5, pp.Z), COL(70, 130, 60), E.Grass, BALL, false)
	end
	return m
end

----------------------------------------------------------------
-- ALLES BAUEN: Doener, Kirche, Garagen
----------------------------------------------------------------
local buildingsF = folder("Gebaeude")
local CHURCH = { x = -10 * WS, z = -345 * WS, yaw = 0 }
-- Der Doener liegt am Rand der Dorfflaeche; die Strasse hebt den Boden davor an.
-- Basis auf die hoechste Stelle von Gebaeude + Vorplatz setzen, sonst versinkt
-- der Vorplatz im Gras.
do
	local cf = CFrame.new(DONER.x, 0, DONER.z) * CFrame.Angles(0, DONER.yaw, 0)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local maxY = -math.huge
	for ix = -25, 25, 2.5 do
		for iz = -12, 42, 2.5 do
			local p = (cf * CFrame.new(ix, 0, iz)).Position
			local hit = workspace:Raycast(Vector3.new(p.X, 512, p.Z), Vector3.new(0, -1024, 0), rp)
			if hit then
				maxY = math.max(maxY, hit.Position.Y)
			end
		end
	end
	if maxY == -math.huge then
		maxY = heightAt(DONER.x, DONER.z)
	end
	DONER.h = maxY + 0.1
	print(("[Swiss Map] Doener-Boden: %.2f"):format(DONER.h))
end
buildDoener(buildingsF, DONER.x, DONER.h, DONER.z, DONER.yaw)
occAdd(DONER.x, DONER.z, 24)
occAddRect(DONER.x - 26.25, DONER.z, 25, 15, DONER.yaw)
do
	local sp = Instance.new("SpawnLocation")
	sp.Anchored = true
	sp.Neutral = true
	sp.Size = V3(8, 1, 8)
	sp.Position = V3(DONER.x - 18.5, DONER.h + 0.5, DONER.z)
	sp.Transparency = 1
	sp.Parent = map
end
buildChurch(buildingsF, CHURCH.x, VILLAGES[1].h, CHURCH.z, CHURCH.yaw)
occAdd(CHURCH.x, CHURCH.z + 8, 50)
print("[Swiss Map] Doener + Kirche fertig")

local garF = folder("Garagen")
for _, g in ipairs(GARAGES) do
	buildGarage(garF, g)
	occAdd(g.x + g.nx * 10, g.z + g.nz * 10, 48)
	task.wait()
end
print(("[Swiss Map] %d Garagen fertig"):format(#GARAGES))

----------------------------------------------------------------
-- HAEUSER entlang der Dorfstrassen
----------------------------------------------------------------
local housesF = folder("Haeuser")
local nHouses = 0
for _, v in ipairs(VILLAGES) do
	local vf = folder("Haeuser_" .. v.name, housesF)
	local slots = {}
	for _, R in ipairs(ROADLIST) do
		local def = R.def
		if def.kind == "main" or def.kind == "minor" then
			local P = R.P
			for i = 3, #P - 3, 2 do
				local p = P[i]
				if dist2(p.X, p.Y, v.x, v.z) < v.rs then
					local f = (P[i + 1] - P[i - 1]).Unit
					local nr = V2(-f.Y, f.X)
					slots[#slots + 1] = { p = p, nr = nr, side = 1, hw = def.hw }
					slots[#slots + 1] = { p = p, nr = nr, side = -1, hw = def.hw }
				end
			end
		end
	end
	for _, s in ipairs(slots) do
		s.key = dist2(s.p.X, s.p.Y, v.x, v.z) + math.random() * 28
	end
	table.sort(slots, function(a, b) return a.key < b.key end)
	local placed = 0
	for _, s in ipairs(slots) do
		if placed >= v.count then break end
		local S = rollHouse()
		if not S then break end
		local off = s.hw + 6 + S.D / 2
		local x = s.p.X + s.nr.X * s.side * off
		local z = s.p.Y + s.nr.Y * s.side * off
		local yaw = math.atan2(-s.nr.X * s.side, -s.nr.Y * s.side)
		local ok = dist2(x, z, v.x, v.z) < v.rf + 12 * WS
			and occFreeRect(x, z, S.W / 2 + 1.0, S.D / 2 + 1.0, yaw)
			and lakeD(x, z) > 1.1
		if ok then
			local d, _, hw = roadQuery(x, z)
			if d and d - hw < S.D / 2 + 2.5 then ok = false end
		end
		if ok then
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
			local hmin, hmax = math.huge, -math.huge
			for _, q in ipairs({ { 0, 0 }, { S.W / 2, S.D / 2 }, { -S.W / 2, S.D / 2 }, { S.W / 2, -S.D / 2 }, { -S.W / 2, -S.D / 2 } }) do
				local wp = (cf * CFrame.new(q[1], 0, q[2])).Position
				local hh = heightAt(wp.X, wp.Z)
				hmin, hmax = math.min(hmin, hh), math.max(hmax, hh)
			end
			if hmax - hmin <= 3.2 then
				buildHouse(vf, V3(x, hmin + 0.6, z), yaw, S)
				occAddRect(x, z, S.W / 2 + 1.0, S.D / 2 + 1.0, yaw)
				placed = placed + 1
				nHouses = nHouses + 1
				task.wait()
			end
		end
	end
	print(("[Swiss Map] %s: %d Haeuser"):format(v.name, placed))
end

----------------------------------------------------------------
-- KUHWEIDEN (umzaeunt, ohne Kuehe)
----------------------------------------------------------------
local pastF = folder("Kuhweiden")
local function pastureOK(cx, cz, PW, PD)
	local hmin, hmax = math.huge, -math.huge
	for ix = 0, 4 do
		for iz = 0, 3 do
			local sx, sz = cx - PW / 2 + ix * PW / 4, cz - PD / 2 + iz * PD / 3
			local hh = heightAt(sx, sz)
			hmin, hmax = math.min(hmin, hh), math.max(hmax, hh)
			local m = matAt(sx, sz)
			if m ~= E.Grass and m ~= E.LeafyGrass then return false end
			local d, _, hw = roadQuery(sx, sz)
			if d and d - hw < 24 then return false end
			if lakeD(sx, sz) < 1.2 then return false end
		end
	end
	return hmin > WL + 8 and hmax < 90 and (hmax - hmin) < 7
end

local function fenceRun(parent, ax, az, bx, bz)
	local n = math.max(1, math.floor(dist2(ax, az, bx, bz) / 6))
	local prev
	for i = 0, n do
		local t = i / n
		local x, z = lerp(ax, bx, t), lerp(az, bz, t)
		local y = heightAt(x, z)
		part(parent, V3(0.8, 3.4, 0.8), CFrame.new(x, y + 1.1, z), COL(112, 80, 54), E.Wood)
		if prev then
			for _, dy in ipairs({ 1.3, 2.3 }) do
				local a, b = V3(prev[1], prev[3] + dy, prev[2]), V3(x, y + dy, z)
				part(parent, V3(0.35, 0.35, (b - a).Magnitude + 0.2), CFrame.lookAt((a + b) / 2, b), COL(140, 104, 70), E.Wood)
			end
		end
		prev = { x, z, y }
	end
end

local nPast, tries = 0, 0
while nPast < PASTURE_COUNT and tries < 5000 do
	tries = tries + 1
	local v = pick(VILLAGES)
	local a = math.random() * 2 * math.pi
	local r = v.rs + 70 + math.random() * 240
	local cx, cz = v.x + math.cos(a) * r, v.z + math.sin(a) * r
	local PW, PD = math.floor(rnd(80, 120)), math.floor(rnd(55, 80))
	local rad = math.sqrt(PW ^ 2 + PD ^ 2) / 2 + 4
	if math.abs(cx) < 700 and math.abs(cz) < 700 and occFree(cx, cz, rad) and pastureOK(cx, cz, PW, PD) then
		nPast = nPast + 1
		occAdd(cx, cz, rad)
		local F = folder("Weide " .. nPast, pastF)
		local x0, x1, z0, z1 = cx - PW / 2, cx + PW / 2, cz - PD / 2, cz + PD / 2
		fenceRun(F, x0, z0, x1, z0)
		fenceRun(F, x1, z0, x1, z1)
		fenceRun(F, x0, z0, x0, z1)
		fenceRun(F, x0, z1, cx - 4, z1)
		fenceRun(F, cx + 4, z1, x1, z1)
		-- Weidetor
		for _, sx in ipairs({ -4, 4 }) do
			part(F, V3(1.2, 4.2, 1.2), CFrame.new(cx + sx, heightAt(cx + sx, z1) + 1.5, z1), COL(90, 64, 44), E.Wood)
		end
		local gy = heightAt(cx, z1)
		for _, dy in ipairs({ 1.0, 2.0, 3.0 }) do
			part(F, V3(7.4, 0.35, 0.35), CFrame.new(cx, gy + dy, z1), COL(160, 120, 80), E.Wood)
		end
		part(F, V3(8.4, 0.3, 0.3), CFrame.new(cx, gy + 2.0, z1) * CFrame.Angles(0, 0, 0.5), COL(160, 120, 80), E.Wood)
		local sg = part(F, V3(4.4, 1.4, 0.3), CFrame.new(cx - 7, heightAt(cx - 7, z1 + 1.5) + 3.0, z1 + 1.5), COL(120, 84, 56), E.Wood)
		upright(F, V3(cx - 7, heightAt(cx - 7, z1 + 1.5) - 0.3, z1 + 1.5), 3.3, 0.4, COL(90, 64, 44), E.Wood)
		textOn(sg, Enum.NormalId.Front, "Weide", COL(250, 240, 220))
		-- Traenke, Heuballen, Unterstand
		local tx, tz = cx + PW * 0.2, cz - PD * 0.15
		part(F, V3(6, 1.2, 1.8), CFrame.new(tx, heightAt(tx, tz) + 0.9, tz), COL(130, 94, 62), E.Wood)
		part(F, V3(5.4, 0.2, 1.2), CFrame.new(tx, heightAt(tx, tz) + 1.5, tz), COL(80, 160, 210), E.Glass, nil, false, 0.3)
		for q = 1, 3 do
			local hx, hz = cx - PW * 0.12 + q * 4.4, cz + PD * 0.1 + (q % 2) * 3
			part(F, V3(3.2, 3.4, 3.4), CFrame.new(hx, heightAt(hx, hz) + 1.5, hz), COL(214, 188, 90), E.Fabric, CYL)
		end
		local ux, uz = cx - PW * 0.3, cz - PD * 0.28
		local uy = heightAt(ux, uz)
		part(F, V3(9, 5, 0.6), CFrame.new(ux, uy + 2.5, uz - 2), COL(130, 94, 62), E.Wood)
		for _, sx in ipairs({ -4.2, 4.2 }) do
			part(F, V3(0.6, 5, 4), CFrame.new(ux + sx, uy + 2.5, uz), COL(130, 94, 62), E.Wood)
		end
		part(F, V3(10, 0.5, 5.6), CFrame.new(ux, uy + 5.3, uz) * CFrame.Angles(0.12, 0, 0), COL(96, 62, 48), E.Wood)
		task.wait()
	end
end
print(("[Swiss Map] %d Kuhweiden fertig"):format(nPast))

----------------------------------------------------------------
-- LOW-POLY TANNEN (spitz, kantig, mehrstufig)
----------------------------------------------------------------
local treesF = folder("Baeume")
local TREE_SPECS = {
	{ { y = 3, a = 7.0, h = 10, sides = 6, rot = 0 }, { y = 8.6, a = 5.6, h = 9.6, sides = 6, rot = 0.35 },
		{ y = 13.8, a = 4.3, h = 9.2, sides = 6, rot = 0 }, { y = 18.6, a = 3.0, h = 8.4, sides = 6, rot = 0.35 },
		{ y = 22.8, a = 1.7, h = 7.2, sides = 6, rot = 0 } },
	{ { y = 3, a = 6.0, h = 11, sides = 5, rot = 0 }, { y = 9.8, a = 4.6, h = 10.5, sides = 5, rot = 0.63 },
		{ y = 15.6, a = 3.3, h = 9.6, sides = 5, rot = 0 }, { y = 20.5, a = 2.0, h = 9, sides = 5, rot = 0.63 } },
	{ { y = 3, a = 8, h = 9, sides = 6, rot = 0.2 }, { y = 7.8, a = 6.4, h = 8.8, sides = 6, rot = 0.55 },
		{ y = 12.2, a = 4.6, h = 8.4, sides = 6, rot = 0.2 }, { y = 16, a = 2.8, h = 8, sides = 6, rot = 0.55 } },
}
local treeT = {}
local function makeTreeTemplate(spec)
	local parts = {}
	for _, t in ipairs(spec) do
		local p = csgPyramid(t.a, t.h, t.sides, t.rot)
		p.Parent = Workspace
		p.CFrame = p.CFrame + V3(0, t.y, 0)
		parts[#parts + 1] = p
	end
	local first = table.remove(parts, 1)
	local u = first
	if #parts > 0 then
		local ok, res = pcall(function()
			return first:UnionAsync(parts, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
		end)
		first:Destroy()
		for _, p in ipairs(parts) do p:Destroy() end
		if not ok then error(res, 0) end
		u = res
	end
	u.Anchored = true
	u.CanCollide = false
	u.UsePartColor = true
	u.Material = E.SmoothPlastic
	u.Parent = Workspace
	local off = measureBottom(u)
	u.Parent = nil
	return { part = u, off = off }
end
if csgOK then
	for vi, spec in ipairs(TREE_SPECS) do
		local ok, res = pcall(makeTreeTemplate, spec)
		if ok and res then
			treeT[#treeT + 1] = res
		else
			warn("[Swiss Map] Tannen-Vorlage " .. vi .. " fehlgeschlagen: " .. tostring(res))
			break
		end
		task.wait()
	end
end
print(("[Swiss Map] %d Tannen-Vorlagen (CSG)"):format(#treeT))

local function plantTree(parent, x, y, z, s)
	local g = math.random() * 22
	upright(parent, V3(x, y - 0.5, z), 7.5 * s, 1.6 * s, COL(92, 64, 46), E.Wood)
	if #treeT > 0 then
		local T = pick(treeT)
		local c = T.part:Clone()
		local sx = s * rnd(0.92, 1.08)
		c.Size = T.part.Size * V3(sx, s, sx)
		c.CFrame = CFrame.new(x, y + (3 + T.off) * s, z) * CFrame.Angles(0, math.random() * 6.28, 0)
		c.Color = COL(32 + g, 98 + g * 1.4, 58)
		c.Parent = parent
	else
		local rot = math.random() * 6.28
		for i = 0, 6 do
			local w = (13 - i * 1.8) * s
			part(parent, V3(w, 0.9 * s, w), CFrame.new(x, y + (4 + i * 3.6) * s, z) * CFrame.Angles(0, rot + i * 0.6, 0),
				COL(32 + g, 98 + g * 1.4, 58), E.SmoothPlastic, nil, false)
		end
		part(parent, V3(1.2 * s, 3 * s, 1.2 * s), CFrame.new(x, y + 29 * s, z), COL(32 + g, 98 + g * 1.4, 58), E.SmoothPlastic, nil, false)
	end
end

local placedTrees, attempts = 0, 0
while placedTrees < TREE_COUNT and attempts < TREE_COUNT * 16 do
	attempts = attempts + 1
	local x = (math.random() * 2 - 1) * (HALF - 30)
	local z = (math.random() * 2 - 1) * (HALF - 30)
	local h, m = heightAt(x, z), matAt(x, z)
	if (m == E.Grass or m == E.LeafyGrass) and h > WL + 4 and h < 150 and nz(x / (180 * WS), z / (180 * WS), 9) > -0.15 then
		local d, _, hw = roadQuery(x, z)
		local ok = (not d) or (d - hw > 10)
		if ok then
			for _, v in ipairs(VILLAGES) do
				if dist2(x, z, v.x, v.z) < v.rf * 0.85 then ok = false; break end
			end
		end
		if ok and occFree(x, z, 6) then
			plantTree(treesF, x, h, z, rnd(0.75, 1.35))
			placedTrees = placedTrees + 1
		end
	end
	if attempts % 300 == 0 then task.wait() end
end

for _, T in ipairs(treeT) do T.part:Destroy() end
if spireTemplate then spireTemplate.part:Destroy() end

print(("[Swiss Map] FERTIG!  %d Haeuser, %d Garagen, %d Tannen, %d Weiden. Gras %.2f. Viel Spass mit dem Toeffli-Spiel!")
	:format(nHouses, #GARAGES, placedTrees, nPast, terrain.GrassLength))
