--[[
	Terreno realista del mundo abierto.
	El relieve se calcula con ruido (colinas suaves, montañas nevadas en los bordes norte y oeste),
	se aplana bajo carreteras y zonas, se excavan los valles de los ríos y los lagos, la cantera
	y la meseta tienen su forma, y la costa baja en playa hasta el mar.
	El suelo cambia según el sitio: césped corto (Grass), maleza alta (LeafyGrass), tierra, barro en
	las orillas, arena en la playa, roca en las pendientes fuertes y nieve en las cumbres.
	Las rocas sueltas también se esculpen en el terreno (Rock, Slate, Basalt) con formas irregulares.
	Se escribe con Terrain:WriteVoxels en bloques de 256 x 256 studs.
]]
return function(W)
	local T = {}
	local S = W.SIZE

	-- =================================================================
	--  Ruido Perlin propio (da el mismo mundo en Studio y en las pruebas)
	-- =================================================================
	local perm = {}
	do
		local p = {}
		for i = 0, 255 do
			p[i] = i
		end
		local seed = 1337
		for i = 255, 1, -1 do
			seed = (seed * 16807) % 2147483647
			local j = seed % (i + 1)
			p[i], p[j] = p[j], p[i]
		end
		for i = 0, 511 do
			perm[i] = p[i % 256]
		end
	end
	local GX = { 1, -1, 1, -1, 1, -1, 0, 0 }
	local GZ = { 1, 1, -1, -1, 0, 0, 1, -1 }
	local function grad(h, x, z)
		local g = h % 8 + 1
		return GX[g] * x + GZ[g] * z
	end
	local function noise(x, z)
		local xi, zi = math.floor(x), math.floor(z)
		local xf, zf = x - xi, z - zi
		xi, zi = xi % 256, zi % 256
		local u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
		local v = zf * zf * zf * (zf * (zf * 6 - 15) + 10)
		local a, b = perm[xi] + zi, perm[xi + 1] + zi
		local g00 = grad(perm[a], xf, zf)
		local g10 = grad(perm[b], xf - 1, zf)
		local g01 = grad(perm[a + 1], xf, zf - 1)
		local g11 = grad(perm[b + 1], xf - 1, zf - 1)
		local x1 = g00 + u * (g10 - g00)
		local x2 = g01 + u * (g11 - g01)
		return (x1 + v * (x2 - x1)) * 0.75
	end
	local function fbm(x, z, octaves)
		local sum, amp, freq, norm = 0, 1, 1, 0
		for _ = 1, octaves do
			sum = sum + noise(x * freq, z * freq) * amp
			norm = norm + amp
			amp = amp * 0.5
			freq = freq * 2.03
		end
		return sum / norm
	end
	T.noise, T.fbm = noise, fbm

	local function smooth01(t)
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		end
		return t * t * (3 - 2 * t)
	end
	-- 1 si d <= a, 0 si d >= b, suave en medio
	local function near(d, a, b)
		return 1 - smooth01((d - a) / (b - a))
	end

	-- =================================================================
	--  Campos de distancia en una rejilla de 16 studs (carreteras, ríos, zonas y costa)
	-- =================================================================
	local STEP = 16
	local NG = math.floor(2 * S / STEP) + 1
	local fRoad, fRiver, fZone, fCoast = {}, {}, {}, {}
	local segDist = W.segDist

	local roadSegs, riverSegs = {}, {}
	local function addSegs(list, points, half)
		for i = 1, #points - 1 do
			local a, c = points[i], points[i + 1]
			table.insert(list, { a[1], a[2], c[1], c[2], math.min(a[1], c[1]), math.max(a[1], c[1]), math.min(a[2], c[2]), math.max(a[2], c[2]), half })
		end
	end
	for _, road in ipairs(W.roads) do
		addSegs(roadSegs, road, 0)
	end
	addSegs(roadSegs, W.rail, 0)
	for _, river in ipairs(W.rivers) do
		addSegs(riverSegs, river.points, river.width / 2)
	end
	local zoneRects = {}
	for name, r in pairs(W.zones) do
		if not W.zoneNoFlat[name] then
			table.insert(zoneRects, r)
		end
	end

	local CAP = 200
	for iz = 0, NG - 1 do
		local z = -S + iz * STEP
		for ix = 0, NG - 1 do
			local x = -S + ix * STEP
			local i = iz * NG + ix + 1
			local best = CAP
			for _, s in ipairs(roadSegs) do
				if x > s[5] - best and x < s[6] + best and z > s[7] - best and z < s[8] + best then
					local d = segDist(x, z, s[1], s[2], s[3], s[4])
					if d < best then
						best = d
					end
				end
			end
			fRoad[i] = best
			best = CAP
			for _, s in ipairs(riverSegs) do
				local reach = best + s[9]
				if x > s[5] - reach and x < s[6] + reach and z > s[7] - reach and z < s[8] + reach then
					local d = segDist(x, z, s[1], s[2], s[3], s[4]) - s[9]
					if d < best then
						best = d
					end
				end
			end
			for _, l in ipairs(W.lakes) do
				local d = math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) - l[3]
				if d < best then
					best = d
				end
			end
			fRiver[i] = best
			best = CAP
			for _, r in ipairs(zoneRects) do
				local dx = math.max(r[1] - x, 0, x - r[2])
				local dz = math.max(r[3] - z, 0, z - r[4])
				local d = math.sqrt(dx * dx + dz * dz)
				if d < best then
					best = d
				end
			end
			fZone[i] = best
			local dc = math.min(W.polylineDist(x, z, W.coast), 600)
			-- En el borde oeste y norte el punto se mira un poco hacia dentro para no confundirlo con el mar
			fCoast[i] = W.inLandPoly(math.max(x, -S + 1), math.max(z, -S + 1)) and dc or -dc
		end
		if iz % 32 == 0 then
			task.wait()
		end
	end

	-- Interpolación bilineal de los cuatro campos
	local function fields(x, z)
		local fx = math.min(math.max((x + S) / STEP, 0), NG - 1.0001)
		local fz = math.min(math.max((z + S) / STEP, 0), NG - 1.0001)
		local ix, iz = math.floor(fx), math.floor(fz)
		local tx, tz = fx - ix, fz - iz
		local i = iz * NG + ix + 1
		local j = i + NG
		local function lerp(f)
			local a = f[i] + (f[i + 1] - f[i]) * tx
			local c = f[j] + (f[j + 1] - f[j]) * tx
			return a + (c - a) * tz
		end
		return lerp(fRoad), lerp(fRiver), lerp(fZone), lerp(fCoast)
	end
	T.fields = fields

	-- =================================================================
	--  Cantera y meseta
	-- =================================================================
	local Q, PL = W.quarry, W.plateau
	local LEVELS = { { 170, -12 }, { 130, -24 }, { 90, -36 }, { 55, -48 } }
	local function quarry(x, z)
		local dx, dz = x - Q.x, z - Q.z
		local r = math.sqrt(dx * dx + dz * dz)
		if r >= 196 then
			return nil, r
		end
		if r < 40 then
			return -56, r
		end
		local h, outer = 0, 0
		for _, lv in ipairs(LEVELS) do
			if r < lv[1] then
				outer, h = h, lv[2]
			end
		end
		-- Rampas para bajar de una terraza a otra
		local a = math.deg(math.atan2(dz, dx)) % 360
		for i, lv in ipairs(LEVELS) do
			local diff = math.abs(((a - i * 95) + 180) % 360 - 180)
			if diff < 8 and r > lv[1] - 34 and r < lv[1] + 4 then
				local upper = (i == 1) and 0 or LEVELS[i - 1][2]
				h = lv[2] + (upper - lv[2]) * smooth01((r - (lv[1] - 34)) / 38)
			end
		end
		return h, r
	end

	-- =================================================================
	--  Altura del suelo
	-- =================================================================
	function T.heightAt(x, z, road, river, zone, coast)
		-- Colinas y ondulación suave
		local h = math.max(0, fbm(x / 650 + 11.3, z / 650 - 7.1, 4)) * 95 + fbm(x / 170 + 3.1, z / 170 + 1.7, 2) * 2.5
		-- Montañas en los bordes norte y oeste
		local edge = math.min(x + S, z + S)
		if edge < 560 then
			local e = smooth01(1 - edge / 560)
			local ridge = 1 - math.abs(fbm(x / 360 - 3.7, z / 360 + 9.2, 4))
			h = h + e * (50 + ridge * ridge * 240)
		end
		-- Explanadas bajo carreteras y zonas
		local flat = math.max(near(road, 14, 90), near(zone, 4, 120))
		h = h * (1 - flat)
		-- Meseta de la Colina Alta
		local dp = math.sqrt((x - PL.x) ^ 2 + (z - PL.z) ^ 2)
		if dp < PL.rBase + 40 then
			h = h + (PL.top - h) * near(dp, PL.rTop, PL.rBase + 40)
		end
		-- Cantera
		local qh = quarry(x, z)
		if qh then
			h = qh
		end
		-- Valles de ríos y lagos: talud suave y cauce
		if river < 80 then
			local bank = (river < 0) and (-4 - 7 * math.min(1, -river / 10)) or (-4 + river * 0.35)
			if bank < h then
				h = bank
			end
		end
		-- Playa y fondo del mar (tierra adentro la costa deja de influir)
		local beach = -4 + coast * 0.12 + math.max(0, coast - 50) ^ 1.5 * 0.2
		if beach < h then
			h = beach
		end
		if coast < 0 and h < -34 then
			h = -34 + fbm(x / 90, z / 90, 2) * 2
		end
		return h
	end

	function T.height(x, z)
		return T.heightAt(x, z, fields(x, z))
	end
	W.groundY = T.height

	-- Nivel del agua en un punto (nil si no hay agua)
	function T.waterAt(x, z, river, coast)
		local _, r = quarry(x, z)
		if r < 40 then
			return -46
		end
		if river < 1 or coast < 6 then
			return -4
		end
		return nil
	end

	-- Densidad de vegetación (la usa también el bosque): alta = maleza y bosque
	function T.veg(x, z)
		return fbm(x / 230 + 5.5, z / 230 - 2.2, 3)
	end

	-- Material de la superficie
	local function zoneGround(x, z)
		for name, r in pairs(W.zones) do
			if x > r[1] - 3 and x < r[2] + 3 and z > r[3] - 3 and z < r[4] + 3 then
				return W.zoneGround[name] or "Grass"
			end
		end
		return "Grass"
	end
	function T.surfaceAt(x, z, h, slope, road, river, zone, coast)
		local _, qr = quarry(x, z)
		if qr < 196 then
			return (qr < 42) and "Mud" or "Rock"
		end
		if coast < 46 and h < 3.5 then
			return "Sand"
		end
		if h > 175 + fbm(x / 80, z / 80, 2) * 25 then
			return "Snow"
		end
		if slope > 0.95 or h > 125 then
			return "Rock"
		end
		if river < 9 then
			return "Mud"
		end
		if road < 13.5 then
			return "Ground"
		end
		if zone < 3 then
			return zoneGround(x, z)
		end
		if fbm(x / 55 - 9.1, z / 55 + 4.4, 2) > 0.42 then
			return "Ground"
		end
		if T.veg(x, z) > 0.02 then
			return "LeafyGrass"
		end
		return "Grass"
	end

	function T.surface(x, z)
		local road, river, zone, coast = fields(x, z)
		local h = T.heightAt(x, z, road, river, zone, coast)
		local sx = (T.height(x + 4, z) - T.height(x - 4, z)) / 8
		local sz = (T.height(x, z + 4) - T.height(x, z - 4)) / 8
		return T.surfaceAt(x, z, h, math.sqrt(sx * sx + sz * sz), road, river, zone, coast), h
	end

	-- =================================================================
	--  Rocas esculpidas en el propio terreno: elipsoides deformados con ruido, de Rock, Slate o Basalt.
	--  Así tienen la textura real de roca de Roblox y formas irregulares, sin ser piezas.
	-- =================================================================
	T.boulders = {}
	local ROCK_MATS = { "Rock", "Rock", "Rock", "Slate", "Slate", "Basalt" }
	function T.addBoulder(x, z, size, mat)
		local rx, ry, rz = size * W.range(0.95, 1.3), size * W.range(0.55, 0.85), size * W.range(0.7, 1)
		local yaw = math.rad(W.range(0, 180))
		table.insert(T.boulders, {
			x = x, z = z, y = T.height(x, z) - ry * 0.35,
			rx = rx, ry = ry, rz = rz, c = math.cos(yaw), s = math.sin(yaw),
			mat = mat or ROCK_MATS[math.floor(W.rand() * #ROCK_MATS) + 1],
			seed = W.range(0, 200), reach = math.max(rx, rz) * 1.6,
		})
	end

	-- Ocupación (0 a 1) de la roca en un punto
	function T.boulderOcc(bd, px, py, pz)
		local dx, dy, dz = px - bd.x, py - bd.y, pz - bd.z
		local u = dx * bd.c + dz * bd.s
		local w = -dx * bd.s + dz * bd.c
		local q = math.sqrt((u / bd.rx) ^ 2 + (dy / bd.ry) ^ 2 + (w / bd.rz) ^ 2)
		-- Bultos y aristas con ruido para que no sea un huevo perfecto
		local bump = noise(u * 0.17 + bd.seed, w * 0.17 + dy * 0.23) * 0.34 + noise(u * 0.43 - bd.seed, dy * 0.41 + w * 0.11) * 0.14
		q = q * (1 - bump)
		local sd = (1 - q) * math.min(bd.rx, bd.ry, bd.rz)
		return math.clamp(0.5 + sd / 4, 0, 1)
	end

	-- =================================================================
	--  Escribir el terreno en Roblox
	-- =================================================================
	local MATS = {}
	for _, m in ipairs({ "Grass", "LeafyGrass", "Ground", "Mud", "Rock", "Slate", "Basalt", "Sand", "Snow", "Water", "Air" }) do
		MATS[m] = Enum.Material[m]
	end

	-- progress(hechos, total) se llama tras cada bloque
	function T.generate(terrain, progress, only)
		local CH, V = 64, 4
		local n = math.floor(2 * S / (CH * V))
		local done = 0
		for bz = 0, n - 1 do
			for bx = 0, n - 1 do
				if not only or only[bz * n + bx + 1] then
					local x0, z0 = -S + bx * CH * V, -S + bz * CH * V
					local H, F = {}, {}
					for i = 0, CH + 1 do
						H[i], F[i] = {}, {}
						for k = 0, CH + 1 do
							local x, z = x0 + (i - 0.5) * V, z0 + (k - 0.5) * V
							local road, river, zone, coast = fields(x, z)
							H[i][k] = T.heightAt(x, z, road, river, zone, coast)
							F[i][k] = { road, river, zone, coast }
						end
					end
					local top, wat = {}, {}
					local hmin, hmax = math.huge, -math.huge
					for i = 1, CH do
						top[i], wat[i] = {}, {}
						for k = 1, CH do
							local x, z = x0 + (i - 0.5) * V, z0 + (k - 0.5) * V
							local h, f = H[i][k], F[i][k]
							local sx = (H[i + 1][k] - H[i - 1][k]) / (2 * V)
							local sz = (H[i][k + 1] - H[i][k - 1]) / (2 * V)
							top[i][k] = T.surfaceAt(x, z, h, math.sqrt(sx * sx + sz * sz), f[1], f[2], f[3], f[4])
							local wl = T.waterAt(x, z, f[2], f[4])
							if wl and wl > h then
								wat[i][k] = wl
								if wl > hmax then
									hmax = wl
								end
							end
							if h < hmin then
								hmin = h
							end
							if h > hmax then
								hmax = h
							end
						end
					end
					-- Rocas que tocan este bloque
					local rocks = {}
					local x1, z1 = x0 + CH * V, z0 + CH * V
					for _, bd in ipairs(T.boulders) do
						if bd.x + bd.reach > x0 and bd.x - bd.reach < x1 and bd.z + bd.reach > z0 and bd.z - bd.reach < z1 then
							table.insert(rocks, bd)
							hmax = math.max(hmax, bd.y + bd.ry * 1.6)
						end
					end
					local y0 = math.floor((hmin - 12) / V) * V
					local y1 = math.ceil((hmax + 2) / V) * V
					local ny = (y1 - y0) / V
					local mats, occs = {}, {}
					for i = 1, CH do
						local mi, oi = {}, {}
						mats[i], occs[i] = mi, oi
						for j = 1, ny do
							mi[j], oi[j] = {}, {}
						end
						for k = 1, CH do
							local h, wl, m0 = H[i][k], wat[i][k], top[i][k]
							local surf = MATS[m0]
							local under = (m0 == "Rock" or m0 == "Snow") and MATS.Rock or ((m0 == "Sand") and MATS.Sand or MATS.Ground)
							for j = 1, ny do
								local vy = y0 + (j - 1) * V
								local m, o = MATS.Air, 0
								if vy < h then
									local depth = h - (vy + V)
									o = math.min(1, (h - vy) / V)
									if depth < 4 then
										m = surf
									elseif depth < 14 then
										m = under
									else
										m = MATS.Rock
									end
								elseif wl and vy < wl then
									m, o = MATS.Water, math.min(1, (wl - vy) / V)
								end
								mi[j][k], oi[j][k] = m, o
							end
						end
					end
					for _, bd in ipairs(rocks) do
						local m = MATS[bd.mat]
						local i0 = math.max(1, math.floor((bd.x - bd.reach - x0) / V) + 1)
						local i1 = math.min(CH, math.floor((bd.x + bd.reach - x0) / V) + 1)
						local k0 = math.max(1, math.floor((bd.z - bd.reach - z0) / V) + 1)
						local k1 = math.min(CH, math.floor((bd.z + bd.reach - z0) / V) + 1)
						local j0 = math.max(1, math.floor((bd.y - bd.ry * 1.6 - y0) / V) + 1)
						local j1 = math.min(ny, math.floor((bd.y + bd.ry * 1.6 - y0) / V) + 1)
						for i = i0, i1 do
							for j = j0, j1 do
								local mj, oj = mats[i][j], occs[i][j]
								for k = k0, k1 do
									local o = T.boulderOcc(bd, x0 + (i - 0.5) * V, y0 + (j - 0.5) * V, z0 + (k - 0.5) * V)
									if o > oj[k] and (o >= 0.5 or mj[k] ~= MATS.Water) then
										mj[k], oj[k] = m, o
									end
								end
							end
						end
					end
					terrain:WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + CH * V, y1, z0 + CH * V)), V, mats, occs)
					task.wait()
				end
				done = done + 1
				if progress then
					progress(done, n * n)
				end
			end
		end
	end

	return T
end
