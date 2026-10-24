-- Datos y utilidades del mundo abierto: costa, ríos, lagos, carreteras, vía del tren, zonas y
-- coches abandonados. X crece hacia el este y Z hacia el sur; el mundo va de -2048 a 2048.
-- El relieve (colinas, montañas, valles y playas) se calcula en Terreno.luau a partir de estos datos.
return function(b, MB)
	local P = MB.Props
	local W = {}
	W.SIZE = 2048

	-- =================================================================
	--  Datos del mapa
	-- =================================================================
	-- Costa de norte a sur por el este y luego hacia el oeste por el sur (el mar queda al este y al sur)
	W.coast = {
		{ 1500, -2048 }, { 1490, -1700 }, { 1460, -1350 }, { 1500, -1000 }, { 1450, -700 }, { 1380, -420 },
		{ 1420, -150 }, { 1380, 150 }, { 1300, 420 }, { 1340, 650 }, { 1200, 880 }, { 1000, 1080 }, { 820, 1300 },
		{ 560, 1390 }, { 300, 1420 }, { 0, 1440 }, { -300, 1420 }, { -560, 1440 }, { -820, 1400 }, { -1080, 1460 },
		{ -1300, 1420 }, { -1500, 1500 }, { -1700, 1480 }, { -2048, 1500 },
	}

	-- Ríos (los puntos van de la fuente a la desembocadura)
	W.rivers = {
		{ name = "RioNorte", width = 44, points = { { -290, -2100 }, { -260, -1800 }, { -200, -1500 }, { -120, -1260 }, { 20, -1150 }, { 240, -1060 }, { 420, -900 }, { 650, -680 }, { 900, -640 }, { 1150, -560 }, { 1300, -520 }, { 1410, -500 } }, mouth = true },
		{ name = "Arroyo", width = 26, points = { { -120, -1260 }, { -140, -1080 }, { -150, -960 } } },
		{ name = "RioOeste", width = 36, points = { { -1700, -2100 }, { -1680, -1700 }, { -1600, -1350 }, { -1520, -1080 }, { -1380, -900 }, { -1240, -700 }, { -1200, -400 }, { -1230, -180 }, { -1200, -30 } } },
		{ name = "Riachuelo", width = 26, points = { { -1200, 40 }, { -1230, 200 }, { -1250, 280 } } },
		{ name = "RioPenal", width = 36, points = { { -1190, 420 }, { -1080, 560 }, { -1000, 620 }, { -900, 860 }, { -950, 1100 }, { -1000, 1300 }, { -1050, 1452 } }, mouth = true },
		{ name = "RioSur", width = 40, points = { { -1000, 620 }, { -720, 740 }, { -480, 560 }, { -250, 380 }, { 0, 420 }, { 180, 560 }, { 330, 800 }, { 420, 1040 }, { 520, 1260 }, { 570, 1386 } }, mouth = true },
	}
	W.lakes = { { -1200, -30, 70 }, { -1250, 340, 90 }, { -150, -900, 100 } }

	-- Meseta de la Colina Alta y cantera
	W.plateau = { x = 1072, z = -228, top = 16, rTop = 120, rBase = 260 }
	W.quarry = { x = 1250, z = -1670 }

	-- Carreteras (ancho 22)
	W.roads = {
		{ { -900, -1640 }, { -940, -1450 }, { -930, -1260 }, { -880, -1150 }, { -800, -950 }, { -700, -760 } },
		{ { -1470, -640 }, { -1300, -640 }, { -1100, -620 }, { -900, -600 }, { -780, -600 } },
		{ { -1470, -640 }, { -1440, -400 }, { -1400, -160 }, { -1390, 40 }, { -1420, 200 }, { -1480, 330 }, { -1540, 410 } },
		{ { -1540, 670 }, { -1500, 880 }, { -1460, 1070 } },
		{ { -1400, -160 }, { -1250, -170 }, { -1100, -140 }, { -960, -110 }, { -800, -60 }, { -640, -60 }, { -480, -120 }, { -330, -100 }, { -180, -180 }, { 0, -260 }, { 200, -380 }, { 300, -420 }, { 500, -420 }, { 700, -380 }, { 820, -280 } },
		{ { -640, -440 }, { -640, -60 }, { -660, 30 } },
		{ { 300, -560 }, { 330, -760 }, { 400, -960 }, { 470, -1100 }, { 520, -1180 } },
		{ { 990, -1500 }, { 1080, -1520 } },
		{ { 1100, 40 }, { 1060, 300 }, { 1020, 530 } },
		{ { -420, -120 }, { -420, 200 }, { -360, 450 }, { -260, 690 } },
		{ { 90, 920 }, { 300, 900 }, { 500, 900 }, { 780, 900 }, { 900, 820 } },
		{ { -680, 150 }, { -720, 420 }, { -640, 640 }, { -560, 900 }, { -430, 920 } },
		{ { -1460, 1070 }, { -1300, 980 }, { -1100, 960 }, { -900, 960 }, { -700, 960 }, { -560, 900 } },
		{ { -1440, -1560 }, { -1560, -1200 }, { -1650, -900 }, { -1700, -780 } },
	}
	W.rail = { { -330, -700 }, { -330, 200 }, { 100, 420 }, { 650, 600 }, { 900, 700 } }

	-- Zonas: rectángulos { x0, x1, z0, z1 } donde no crecen árboles ni se dejan coches
	W.zones = {
		Granjas = { -1500, -700, -1880, -1360 },
		Pista = { -1200, -840, -1220, -860 },
		Villamuro = { -1830, -1470, -780, -500 },
		Comisaria = { -1480, -1300, -160, 20 },
		LagoSereno = { -1120, -800, -100, 220 },
		Penal = { -1700, -1400, 410, 670 },
		ZonaProhibida = { -1610, -1290, 1070, 1330 },
		Motel = { -770, -600, 10, 150 },
		Megatienda = { -780, -480, -740, -440 },
		Estacion = { -440, -200, -720, -120 },
		Antena = { 220, 410, -560, -380 },
		Condado = { 290, 990, -1790, -1170 },
		Cantera = { 1050, 1450, -1870, -1470 },
		ColinaAlta = { 800, 1345, -500, 45 },
		Ciudadela = { -430, 90, 690, 1160 },
		Ladera = { 500, 780, 790, 1070 },
		Refugio = { 870, 1190, 530, 830 },
	}

	-- Suelo de cada zona (material del terreno): Grass = césped corto, LeafyGrass = maleza alta,
	-- Ground = tierra, Mud = barro. Las zonas que no aparecen usan césped corto.
	W.zoneGround = {
		Granjas = "Grass", Penal = "Ground", ZonaProhibida = "Mud", Antena = "Ground", Estacion = "Ground",
		Refugio = "Ground", Cantera = "Rock", Megatienda = "Ground", Motel = "LeafyGrass", Ladera = "LeafyGrass",
		LagoSereno = "LeafyGrass", Comisaria = "Grass",
	}
	-- Zonas que no se aplanan a altura 0 (la meseta y la cantera tienen su propio relieve)
	W.zoneNoFlat = { ColinaAlta = true }

	-- =================================================================
	--  Utilidades
	-- =================================================================
	local seed = 20241
	-- Números pseudoaleatorios repetibles (el mismo mundo cada vez)
	function W.rand()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	function W.range(a, c)
		return a + (c - a) * W.rand()
	end

	local function segDist(px, pz, ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local l2 = dx * dx + dz * dz
		local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / l2)) or 0
		local qx, qz = ax + dx * t - px, az + dz * t - pz
		return math.sqrt(qx * qx + qz * qz)
	end
	W.segDist = segDist
	function W.polylineDist(px, pz, pts)
		local best = math.huge
		for i = 1, #pts - 1 do
			best = math.min(best, segDist(px, pz, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
		end
		return best
	end

	function W.inZone(x, z, margin)
		margin = margin or 0
		for _, r in pairs(W.zones) do
			if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
				return true
			end
		end
		return false
	end

	function W.nearRoad(x, z, margin)
		for _, road in ipairs(W.roads) do
			if W.polylineDist(x, z, road) < 11 + margin then
				return true
			end
		end
		return W.polylineDist(x, z, W.rail) < 6 + margin
	end

	function W.nearWater(x, z, margin)
		for _, river in ipairs(W.rivers) do
			if W.polylineDist(x, z, river.points) < river.width / 2 + margin then
				return true
			end
		end
		for _, l in ipairs(W.lakes) do
			if math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) < l[3] + margin then
				return true
			end
		end
		return false
	end

	-- ¿Está en tierra firme y a más de margin de la costa?
	local landPoly = { { -2048, -2048 } }
	for _, p in ipairs(W.coast) do
		table.insert(landPoly, p)
	end
	-- ¿Está dentro del contorno de tierra (sin contar la distancia a la costa)?
	function W.inLandPoly(x, z)
		local inside = false
		local j = #landPoly
		for i = 1, #landPoly do
			local xi, zi, xj, zj = landPoly[i][1], landPoly[i][2], landPoly[j][1], landPoly[j][2]
			if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
				inside = not inside
			end
			j = i
		end
		return inside
	end
	function W.isLand(x, z, margin)
		local inside = false
		local j = #landPoly
		for i = 1, #landPoly do
			local xi, zi, xj, zj = landPoly[i][1], landPoly[i][2], landPoly[j][1], landPoly[j][2]
			if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
				inside = not inside
			end
			j = i
		end
		return inside and W.polylineDist(x, z, W.coast) > (margin or 0) and math.abs(x) < W.SIZE - 20 and math.abs(z) < W.SIZE - 20
	end

	local function eachSegment(points, fn)
		for i = 1, #points - 1 do
			local a, c = points[i], points[i + 1]
			local dx, dz = c[1] - a[1], c[2] - a[2]
			local len = math.sqrt(dx * dx + dz * dz)
			fn(a, c, len, math.deg(math.atan2(-dz, dx)), (a[1] + c[1]) / 2, (a[2] + c[2]) / 2, dx / len, dz / len, i)
		end
	end
	W.eachSegment = eachSegment

	-- =================================================================
	--  Carreteras con puentes, vía del tren y límites
	-- =================================================================
	local ROAD = { 66, 66, 68 }
	function W.buildRoads()
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				b:box({ name = "Carretera", size = { len, 0.4, 22 }, pos = { mx, 0, mz }, rot = { 0, yaw, 0 }, color = ROAD, mat = "Asphalt" })
				-- Línea central borrada a trozos y hierba que se come el asfalto
				for d = 12, len - 12, 24 do
					if W.rand() > 0.35 then
						b:box({ name = "Linea", size = { 8, 0.12, 0.5 }, pos = { a[1] + ux * d, 0.22, a[2] + uz * d }, rot = { 0, yaw, 0 }, color = { 170, 150, 92 }, folder = "Decoracion", shadow = false })
					end
				end
				for d = 30, len - 10, 70 do
					if W.rand() > 0.45 then
						local off = W.range(-8, 8)
						b:box({ name = "Hierba", size = { W.range(6, 14), 0.14, W.range(3, 8) }, pos = { a[1] + ux * d - uz * off, 0.23, a[2] + uz * d + ux * off }, rot = { 0, yaw + W.range(-20, 20), 0 }, color = { 78, 104, 58 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
					end
				end
			end)
			for _, pt in ipairs(road) do
				b:cylinder({ name = "Cruce", length = 0.4, diameter = 22, pos = { pt[1], 0, pt[2] }, color = ROAD, mat = "Asphalt" })
			end
		end
		eachSegment(W.rail, function(a, c)
			P.rails(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, false)
		end)
		for _, pt in ipairs(W.rail) do
			b:cylinder({ name = "Balasto", length = 0.6, diameter = 10, pos = { pt[1], 0.3, pt[2] }, color = { 110, 104, 96 }, mat = "Pebble" })
		end
	end

	-- Puentes donde una carretera cruza un río (se calculan solos)
	function W.buildBridges()
		local count = 0
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				for _, river in ipairs(W.rivers) do
					eachSegment(river.points, function(ra, rc, rlen, ryaw, rmx, rmz, rux, ruz)
						local den = ux * ruz - uz * rux
						if math.abs(den) < 1e-6 then
							return
						end
						local wx, wz = ra[1] - a[1], ra[2] - a[2]
						local t = (wx * ruz - wz * rux) / den
						local s = (wx * uz - wz * ux) / den
						if t < 0 or t > len or s < 0 or s > rlen then
							return
						end
						count = count + 1
						local ix, iz = a[1] + ux * t, a[2] + uz * t
						local span = river.width / math.max(0.35, math.abs(den)) + 34
						local g = b:at({ ix, 0, iz }, yaw)
						g:box({ name = "Puente", size = { span, 1.6, 26 }, pos = { 0, -0.6, 0 }, color = { 150, 146, 140 }, mat = "Concrete" })
						for _, side in ipairs({ -1, 1 }) do
							g:box({ name = "Pretil", size = { span, 2.6, 1 }, pos = { 0, 1.2, side * 12.5 }, color = { 160, 156, 150 }, mat = "Concrete" })
							g:box({ name = "Musgo", size = { span * 0.3, 0.8, 1.1 }, pos = { span * (count % 2 == 0 and 0.2 or -0.25), 2, side * 12.5 }, color = { 74, 100, 56 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
						end
						for _, off in ipairs({ -river.width / 4, river.width / 4 }) do
							g:cylinder({ name = "Pilar", length = 16, diameter = 3, pos = { off / math.max(0.35, math.abs(den)), -9, 0 }, color = { 130, 128, 122 }, mat = "Concrete", folder = "Decoracion" })
						end
					end)
				end
			end)
		end
		return count
	end

	-- Paredes invisibles alrededor del mundo (en trozos, una pieza no puede medir más de 2048)
	function W.buildBounds()
		local S, H = W.SIZE, 400
		for i = 0, 3 do
			local c = -S + 512 + i * 1024
			for _, wall in ipairs({ { { 1024, H, 4 }, { c, H / 2 - 40, -S - 2 } }, { { 1024, H, 4 }, { c, H / 2 - 40, S + 2 } }, { { 4, H, 1024 }, { -S - 2, H / 2 - 40, c } }, { { 4, H, 1024 }, { S + 2, H / 2 - 40, c } } }) do
				b:part("Part", { name = "Limite", size = wall[1], pos = wall[2], transparency = 1, shadow = false, folder = "Limites" })
			end
		end
	end

	-- =================================================================
	--  Coches abandonados en las carreteras
	-- =================================================================
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 70, 80, 70 }, { 150, 60, 50 }, { 60, 70, 90 }, { 40, 40, 42 } }
	function W.buildCars()
		local count = 0
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				for d = 40, len - 40, 150 do
					local x, z = a[1] + ux * d, a[2] + uz * d
					if W.rand() < 0.5 and not W.inZone(x, z, 20) and not W.nearWater(x, z, 30) then
						local off = (W.rand() < 0.5) and -5 or 5
						P.car(b, { x - uz * off, 0.2, z + ux * off }, yaw + 90 + W.range(-30, 30), RUST[math.floor(W.rand() * #RUST) + 1], true)
						count = count + 1
					end
				end
			end)
		end
		return count
	end

	-- =================================================================
	--  Utilidades para las zonas
	-- =================================================================
	-- Calle de una zona (por defecto asfalto de 22 de ancho) a la altura y
	function W.road(points, width, color, mat, y)
		width, y = width or 22, y or 0
		eachSegment(points, function(a, c, len, yaw, mx, mz)
			b:box({ name = "Calle", size = { len, 0.4, width }, pos = { mx, y, mz }, rot = { 0, yaw, 0 }, color = color or ROAD, mat = mat or "Asphalt" })
		end)
		for i = 2, #points - 1 do
			b:cylinder({ name = "Cruce", length = 0.4, diameter = width, pos = { points[i][1], y, points[i][2] }, color = color or ROAD, mat = mat or "Asphalt" })
		end
	end

	-- Valla de postes y dos travesaños (barata en piezas)
	function W.fence(a, c, height, color, y)
		local wood = color or { 120, 96, 70 }
		y = y or 0
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local n = math.max(1, math.floor(len / 10))
		for i = 0, n do
			b:box({ name = "Poste", size = { 0.6, height, 0.6 }, pos = { a[1] + dx * i / n, y + height / 2, a[2] + dz * i / n }, color = wood, mat = "Wood" })
		end
		for _, h in ipairs({ 0.45, 0.85 }) do
			b:box({ name = "Travesano", size = { len, 0.4, 0.3 }, pos = { (a[1] + c[1]) / 2, y + height * h, (a[2] + c[2]) / 2 }, rot = { 0, yaw, 0 }, color = wood, mat = "Wood" })
		end
	end

	-- Recorre el borde de un rectángulo dejando puertas. gates = { { "N" | "S" | "E" | "O", desde, hasta }, ... }
	-- N es el lado z0, S el lado z1, O el lado x0 y E el lado x1. build(a, c) recibe cada tramo { x, z }.
	function W.wallRect(x0, x1, z0, z1, gates, build)
		local sides = { N = { { x0, z0 }, { x1, z0 }, 1 }, E = { { x1, z0 }, { x1, z1 }, 2 }, S = { { x1, z1 }, { x0, z1 }, 1 }, O = { { x0, z1 }, { x0, z0 }, 2 } }
		for _, name in ipairs({ "N", "E", "S", "O" }) do
			local s = sides[name]
			local axis = s[3]
			local from, to = s[1][axis], s[2][axis]
			local cuts = {}
			for _, g in ipairs(gates or {}) do
				if g[1] == name then
					table.insert(cuts, { math.min(g[2], g[3]), math.max(g[2], g[3]) })
				end
			end
			local lo, hi = math.min(from, to), math.max(from, to)
			table.sort(cuts, function(a, c)
				return a[1] < c[1]
			end)
			local cursor = lo
			local function emit(a, c)
				if c - a > 1 then
					local pa, pc = { s[1][1], s[1][2] }, { s[1][1], s[1][2] }
					pa[axis], pc[axis] = a, c
					build(pa, pc)
				end
			end
			for _, cut in ipairs(cuts) do
				emit(cursor, cut[1])
				cursor = cut[2]
			end
			emit(cursor, hi)
		end
	end

	-- Coche de policía abandonado
	function W.policeCar(x, y, z, yaw)
		P.car(b, { x, y, z }, yaw, { 30, 32, 36 }, true)
		local g = b:at({ x, y, z }, yaw)
		g:box({ name = "Puerta", size = { 5.5, 1.6, 4 }, pos = { 0, 2.4, 0.4 }, color = { 230, 230, 226 }, folder = "Decoracion" })
		g:box({ name = "Sirena", size = { 3, 0.5, 0.8 }, pos = { -0.8, 5.55, 1.3 }, color = { 60, 80, 160 }, mat = "Glass", folder = "Decoracion" })
		g:box({ name = "Sirena", size = { 1.5, 0.5, 0.8 }, pos = { 1.4, 5.55, 1.3 }, color = { 160, 50, 50 }, mat = "Glass", folder = "Decoracion" })
	end

	-- Aparcamiento con líneas
	function W.parking(x0, x1, z0, z1, y)
		y = y or 0
		b:box({ name = "Aparcamiento", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, y, (z0 + z1) / 2 }, color = { 72, 72, 74 }, mat = "Asphalt" })
		for x = x0 + 8, x1 - 8, 10 do
			for _, z in ipairs({ z0 + 9, z1 - 9 }) do
				b:box({ name = "Linea", size = { 0.4, 0.12, 14 }, pos = { x, y + 0.22, z }, color = { 180, 176, 160 }, folder = "Decoracion", shadow = false })
			end
		end
	end

	-- Punto de aparición sobre el suelo
	function W.spawn(x, z, yaw, y)
		b:spawnLocation({ x, (y or W.groundY(x, z)) + 0.5, z }, yaw)
	end

	return W
end
