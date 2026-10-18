-- Gran Ciudad: mapa inmenso para hasta 50 jugadores (25 contra 25). Cada equipo tiene una base
-- con 25 spawns; entre las dos bases hay una ciudad con oficinas, tiendas, gasolinera, parque,
-- casas en las que se puede entrar, una obra con pisos, un aparcamiento de dos plantas,
-- una zona industrial, una gran plaza, el ayuntamiento y la estación de autobuses.
-- Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SIDEWALK = { 170, 166, 160 }
	local PLAZA = { 198, 192, 182 }
	local LINE = { 236, 232, 220 }
	local GRASS = { 108, 150, 76 }
	local TREES = { { 86, 140, 66 }, { 100, 156, 74 }, { 76, 126, 60 } }
	local OFFICES = {
		{ h = 56, color = { 150, 166, 186 }, mat = "Concrete", trim = { 90, 100, 116 }, glass = { 90, 130, 170 } },
		{ h = 44, color = { 206, 196, 180 }, mat = "Concrete", trim = { 140, 130, 116 }, glass = { 80, 110, 140 } },
		{ h = 64, color = { 120, 130, 146 }, mat = "Concrete", trim = { 70, 76, 90 }, glass = { 110, 150, 190 } },
		{ h = 38, color = { 176, 120, 96 }, mat = "Brick", trim = { 230, 224, 210 } },
	}
	local SHOPS = {
		{ h = 16, color = { 236, 226, 206 }, trim = { 120, 90, 70 }, shop = "PIZZERÍA", shopColor = { 200, 50, 40 }, lit = true },
		{ h = 18, color = { 160, 90, 70 }, mat = "Brick", trim = { 236, 230, 220 }, shop = "CAFÉ", shopColor = { 110, 70, 40 }, lit = true },
		{ h = 14, color = { 120, 170, 200 }, trim = { 245, 245, 240 }, shop = "MODA", shopColor = { 210, 70, 140 }, lit = true },
		{ h = 16, color = { 230, 200, 120 }, trim = { 120, 90, 50 }, shop = "FARMACIA", shopColor = { 40, 150, 80 }, lit = true },
	}

	b.model:SetAttribute("Nombre", "Gran Ciudad")
	b.model:SetAttribute("Jugadores", 50)

	local function copy(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	local function slab(x0, x1, z0, z1, color, mat)
		return b:box({ name = "Manzana", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, 0.2, (z0 + z1) / 2 }, color = color or SIDEWALK, mat = mat or "Pavement" })
	end

	-- Edificios alrededor de una manzana, con un callejón en el centro de cada lado
	local function perimeter(x0, x1, z0, z1, d, sides, styles)
		local i = 0
		local function row(a0, a1, place)
			local mid = (a0 + a1) / 2
			for _, seg in ipairs({ { a0, mid - 4 }, { mid + 4, a1 } }) do
				i = i + 1
				local o = copy(styles[(i - 1) % #styles + 1])
				o.w, o.d = seg[2] - seg[1], d
				place((seg[1] + seg[2]) / 2, o)
			end
		end
		local zs, ze = z0 + (sides.S and d or 0), z1 - (sides.N and d or 0)
		if sides.N then
			row(x0, x1, function(c, o)
				P.house(b, { c, 0.4, z1 - d / 2 }, 180, o)
			end)
		end
		if sides.S then
			row(x0, x1, function(c, o)
				P.house(b, { c, 0.4, z0 + d / 2 }, 0, o)
			end)
		end
		if sides.W then
			row(zs, ze, function(c, o)
				P.house(b, { x0 + d / 2, 0.4, c }, 90, o)
			end)
		end
		if sides.E then
			row(zs, ze, function(c, o)
				P.house(b, { x1 - d / 2, 0.4, c }, -90, o)
			end)
		end
	end

	-- =================================================================
	--  Suelo, calles y ciudad de fondo
	-- =================================================================
	b:box({ name = "Fondo", size = { 2000, 1, 2000 }, pos = { 0, -1.2, 0 }, color = { 120, 120, 118 }, mat = "Concrete", folder = "Decoracion" })
	b:box({ name = "Asfalto", size = { 620, 1, 420 }, pos = { 0, -0.5, 0 }, color = { 68, 68, 72 }, mat = "Asphalt" })
	for i = 0, 23 do
		for _, side in ipairs({ -1, 1 }) do
			local x = -345 + i * 30
			local h = 60 + (i * 41 + (side > 0 and 0 or 23)) % 110
			local w = 22 + (i % 3) * 6
			b:box({ name = "Rascacielos", size = { w, h, w }, pos = { x, h / 2, side * (240 + (i % 2) * 26) }, color = (i % 3 == 0) and { 110, 130, 156 } or { 176, 170, 160 }, mat = (i % 3 == 0) and "Glass" or "Concrete", folder = "Decoracion" })
		end
	end
	for i = 0, 7 do
		for _, side in ipairs({ -1, 1 }) do
			local h = 70 + (i * 37) % 90
			b:box({ name = "Rascacielos", size = { 30, h, 34 }, pos = { side * (340 + (i % 2) * 24), h / 2, -175 + i * 50 }, color = (i % 2 == 0) and { 150, 160, 176 } or { 190, 182, 170 }, mat = "Concrete", folder = "Decoracion" })
		end
	end
	-- Líneas de las avenidas (eje X) y de las calles (eje Z)
	for _, z in ipairs({ -100, 0, 100 }) do
		for x = -296, 296, 16 do
			if z ~= 0 or math.abs(x) > 70 then
				b:box({ name = "Linea", size = { 7, 0.12, 0.5 }, pos = { x, 0.06, z }, color = LINE, folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Centro: gran plaza, ayuntamiento y estación de autobuses
	-- =================================================================
	slab(-65, 65, -88, 88, PLAZA, "Pavement")
	b:cylinder({ name = "Rosa", length = 0.1, diameter = 60, pos = { 0, 0.45, 0 }, color = { 176, 150, 120 }, mat = "Cobblestone", folder = "Decoracion" })
	P.fountain(b, { 0, 0.4, 0 }, 10)
	P.obelisk(b, { 0, 7.4, 0 }, 16, 2)

	slab(-65, 65, 112, 196)
	P.house(b, { 0, 0.4, 140 }, 0, { w = 90, h = 30, d = 40, color = { 236, 228, 210 }, mat = "Limestone", trim = { 180, 168, 150 }, floors = 3, cols = 12, door = false })
	for x = -20, 20, 8 do
		P.column(b, { x, 0.4, 116 }, 14, 2.2, { 240, 234, 220 }, "Limestone")
	end
	b:box({ name = "Friso", size = { 48, 2.4, 6 }, pos = { 0, 18.8, 117 }, color = { 230, 222, 204 }, mat = "Limestone" })
	b:wedge({ name = "Fronton", size = { 48, 5, 3 }, pos = { 0, 22.5, 115.5 }, color = { 230, 222, 204 }, mat = "Limestone" })
	b:cylinder({ name = "Tambor", length = 8, diameter = 18, pos = { 0, 34.4, 140 }, color = { 236, 228, 210 }, mat = "Limestone", folder = "Decoracion" })
	b:ball({ name = "Cupula", diameter = 18, pos = { 0, 38.4, 140 }, color = { 90, 140, 120 }, mat = "Metal", folder = "Decoracion" })
	local cityHall = b:box({ name = "Rotulo", size = { 30, 2.4, 0.3 }, pos = { 0, 26.5, 119.8 }, color = { 236, 228, 210 }, folder = "Decoracion" })
	MB.sign(cityHall, "AYUNTAMIENTO", { font = "Garamond", color = { 90, 70, 50 } })

	slab(-65, 65, -196, -112)
	P.house(b, { 0, 0.4, -186 }, 180, { w = 110, h = 16, d = 20, color = { 200, 204, 210 }, mat = "Concrete", trim = { 60, 90, 140 }, floors = 2, shop = "ESTACIÓN DE AUTOBUSES", shopColor = { 40, 90, 160 }, lit = true })
	b:box({ name = "Marquesina", size = { 104, 1, 44 }, pos = { 0, 12.5, -148 }, color = { 220, 224, 230 }, mat = "Metal" })

	b:symmetric(function(b)
		local mine = not b.mirrored

		-- =============================================================
		--  Base del equipo: muro con dos puertas, torres, tiendas y 25 spawns
		-- =============================================================
		slab(-300, -235, -196, 196, { 150, 146, 136 }, "Concrete")
		local wallColor = { 120, 124, 112 }
		P.wall(b, { -240, 0.4, 0 }, 90, { 80, 12, 2 }, wallColor)
		P.wall(b, { -240, 0.4, -63 }, 90, { 14, 12, 2 }, wallColor)
		P.wall(b, { -240, 0.4, 63 }, 90, { 14, 12, 2 }, wallColor)
		P.wall(b, { -270, 0.4, -70 }, 0, { 60, 12, 2 }, wallColor)
		P.wall(b, { -270, 0.4, 70 }, 0, { 60, 12, 2 }, wallColor)
		P.poster(b, { -238.8, 8, 0 }, -90, { 30, 4 }, mine and { 50, 100, 200 } or { 200, 50, 50 }, mine and "BASE AZUL" or "BASE ROJA", { 255, 255, 255 }, "GothamBlack")
		for _, z in ipairs({ -48, 48 }) do
			P.sandbags(b, { -230, 0.4, z }, 90, 12, 3)
		end
		P.watchTower(b, { -248, 0.4, -62 }, 90, 16)
		P.watchTower(b, { -248, 0.4, 62 }, 90, 16)
		for _, z in ipairs({ -52, 52 }) do
			b:wedge({ name = "Tienda", size = { 14, 6, 5 }, pos = { -288, 3.4, z - 2.5 }, color = { 92, 110, 70 }, mat = "Fabric" })
			b:wedge({ name = "Tienda", size = { 14, 6, 5 }, pos = { -288, 3.4, z + 2.5 }, rot = { 0, 180, 0 }, color = { 92, 110, 70 }, mat = "Fabric" })
		end
		P.truck(b, { -262, 0.4, 44 }, 0, { 92, 110, 70 })
		b:cylinder({ name = "Helipuerto", length = 0.1, diameter = 20, pos = { -272, 0.45, -48 }, color = { 60, 62, 66 }, mat = "Concrete", folder = "Decoracion" })
		local pad = b:box({ name = "H", size = { 8, 0.1, 8 }, pos = { -272, 0.5, -48 }, color = { 60, 62, 66 }, transparency = 1, folder = "Decoracion" })
		MB.sign(pad, "H", { face = "Top", font = "GothamBlack", color = { 245, 245, 240 } })
		b:cylinder({ name = "Mastil", length = 20, diameter = 0.5, pos = { -297, 10.4, 0 }, color = { 200, 200, 206 }, mat = "Metal" })
		b:box({ name = "Bandera", size = { 0.2, 4, 6 }, pos = { -297, 18, 3.2 }, color = mine and { 50, 100, 200 } or { 200, 50, 50 }, mat = "Fabric", folder = "Decoracion" })
		for _, z in ipairs({ -36, 36 }) do
			P.crate(b, { -262, 0.4, z }, 4, 0, { 90, 110, 70 })
			P.crate(b, { -257, 0.4, z }, 4, 15, { 90, 110, 70 })
		end
		for _, x in ipairs({ -290, -282, -274, -266, -258 }) do
			for _, z in ipairs({ -24, -12, 0, 12, 24 }) do
				b:spawn("A", { x, 0.9, z }, -90)
			end
		end
		-- Fuera de la base: contenedores y barreras
		P.container(b, { -268, 0.4, -110 }, 0, { 46, 96, 150 }, false)
		P.container(b, { -268, 0.4, 120 }, 0, { 176, 60, 46 }, true)
		P.barrier(b, { -258, 0.4, -150 }, 90)
		P.barrier(b, { -258, 0.4, 160 }, 90)

		-- =============================================================
		--  Oficinas (x -140..-85, z -196..-112)
		-- =============================================================
		slab(-140, -85, -196, -112)
		perimeter(-140, -85, -196, -112, 18, { N = true, W = true, E = true }, OFFICES)
		P.dumpster(b, { -112, 0.4, -170 }, 0, { 60, 110, 80 })
		P.dumpster(b, { -112, 0.4, -186 }, 0, { 60, 110, 80 })
		P.crate(b, { -116, 0.4, -150 }, 4)

		-- =============================================================
		--  Gasolinera (x -140..-85, z -88..-12)
		-- =============================================================
		slab(-140, -85, -88, -12)
		for _, x in ipairs({ -126, -98 }) do
			for _, z in ipairs({ -60, -40 }) do
				b:box({ name = "Pilar", size = { 1.6, 11, 1.6 }, pos = { x, 5.9, z }, color = { 220, 220, 226 }, mat = "Metal" })
			end
		end
		b:box({ name = "Marquesina", size = { 36, 1.6, 26 }, pos = { -112, 12.2, -50 }, color = { 236, 236, 240 }, mat = "Metal" })
		local band = b:box({ name = "Franja", size = { 36.2, 1, 26.2 }, pos = { -112, 12.2, -50 }, color = { 200, 50, 50 }, folder = "Decoracion" })
		MB.sign(band, "GAS 24H", { face = "Front", font = "GothamBlack" })
		for _, x in ipairs({ -120, -112, -104 }) do
			P.pump(b, { x, 0.4, -50 }, 0)
		end
		P.house(b, { -112, 0.4, -20 }, 180, { w = 30, h = 10, d = 14, color = { 236, 236, 230 }, trim = { 200, 50, 50 }, floors = 1, shop = "MINI MARKET", shopColor = { 200, 50, 50 }, lit = true })
		P.pricePylon(b, { -90, 0.4, -80 }, -90, "GAS", { 200, 50, 50 })
		P.car(b, { -116, 0.4, -64 }, 0, { 60, 120, 200 })
		P.car(b, { -100, 0.4, -36 }, 180, { 230, 230, 226 })

		-- =============================================================
		--  Tiendas y mercadillo (x -140..-85, z 12..88)
		-- =============================================================
		slab(-140, -85, 12, 88)
		perimeter(-140, -85, 12, 88, 14, { N = true, S = true }, SHOPS)
		P.marketStall(b, { -124, 0.4, 44 }, 0, { 200, 60, 80 }, "FRUTA")
		P.marketStall(b, { -100, 0.4, 56 }, 180, { 60, 140, 200 }, "FLORES", { { 240, 80, 120 }, { 250, 220, 80 }, { 160, 90, 220 } })
		P.umbrellaTable(b, { -110, 0.4, 40 }, { 220, 80, 60 })
		P.umbrellaTable(b, { -114, 0.4, 60 }, { 60, 150, 200 })
		P.tree(b, { -132, 0.4, 50 }, 1, TREES)
		P.tree(b, { -92, 0.4, 50 }, 1, TREES)

		-- =============================================================
		--  Parque con estanque y templete (x -140..-85, z 112..196)
		-- =============================================================
		slab(-140, -85, 112, 196, GRASS, "Grass")
		b:cylinder({ name = "Estanque", length = 0.12, diameter = 26, pos = { -112, 0.46, 166 }, color = { 70, 140, 170 }, mat = "Glass", reflectance = 0.2, folder = "Decoracion" })
		P.kiosk(b, { -122, 0.4, 132 }, 7, { 240, 240, 236 }, { 70, 110, 90 })
		for i, t in ipairs({ { -134, 120 }, { -96, 124 }, { -132, 150 }, { -92, 146 }, { -134, 186 }, { -96, 188 }, { -112, 140 } }) do
			P.tree(b, { t[1], 0.4, t[2] }, 1 + (i % 3) * 0.2, TREES)
		end
		for _, z in ipairs({ 130, 154, 180 }) do
			P.bench(b, { -100, 0.4, z }, 90, { 120, 90, 60 })
		end
		for z = 116, 192, 6 do
			P.bush(b, { -88, 0.4, z }, 0.9)
		end

		-- =============================================================
		--  Zona industrial (x -215..-160, z -196..-112)
		-- =============================================================
		slab(-215, -160, -196, -112, { 140, 138, 134 }, "Concrete")
		b:box({ name = "Nave", size = { 40, 20, 30 }, pos = { -192, 10.4, -176 }, color = { 176, 186, 196 }, mat = "Metal" })
		b:box({ name = "Tejado", size = { 41, 1, 31 }, pos = { -192, 20.9, -176 }, color = { 120, 130, 140 }, mat = "CorrodedMetal" })
		for _, x in ipairs({ -202, -182 }) do
			b:box({ name = "Persiana", size = { 9, 10, 0.3 }, pos = { x, 5.4, -160.8 }, color = { 140, 146, 156 }, mat = "DiamondPlate", folder = "Decoracion" })
		end
		P.container(b, { -200, 0.4, -128 }, 0, { 176, 60, 46 }, false, "CARGA")
		P.container(b, { -200, 9.4, -128 }, 0, { 46, 96, 150 }, false)
		P.container(b, { -174, 0.4, -140 }, 90, { 70, 120, 80 }, true)
		P.forklift(b, { -182, 0.4, -126 }, 90, { 240, 190, 40 })
		P.pallet(b, { -166, 0.4, -122 }, 10)
		P.drum(b, { -170, 0.4, -150 }, { 46, 96, 150 })
		P.drum(b, { -167.6, 0.4, -151 }, { 200, 60, 50 })

		-- =============================================================
		--  Casas en las que se puede entrar (x -215..-160, z -88..-12)
		-- =============================================================
		slab(-215, -160, -88, -12, GRASS, "Grass")
		P.openHouse(b, { -198, 0.4, -30 }, 180, { color = { 236, 214, 170 }, trim = { 250, 250, 246 }, roofColor = { 130, 70, 56 } })
		P.openHouse(b, { -177, 0.4, -70 }, 0, { color = { 150, 190, 210 }, trim = { 250, 250, 246 }, roofColor = { 70, 80, 100 }, sofa = { 60, 110, 170 } })
		P.woodFence(b, { -214, 0.4, -50 }, { -190, 0.4, -50 }, 4, { 244, 244, 238 })
		P.car(b, { -170, 0.4, -36 }, 0, { 200, 60, 60 })
		P.tree(b, { -208, 0.4, -76 }, 1.1, TREES)
		P.tree(b, { -166, 0.4, -20 }, 1, TREES)

		-- =============================================================
		--  Obra con un edificio a medio construir (x -215..-160, z 12..88)
		-- =============================================================
		slab(-215, -160, 12, 88, { 150, 120, 90 }, "Ground")
		b:box({ name = "Forjado", size = { 30, 0.8, 24 }, pos = { -195, 10.4, 40 }, color = { 176, 174, 168 }, mat = "Concrete" })
		b:box({ name = "Forjado", size = { 22, 0.8, 24 }, pos = { -199, 20.4, 40 }, color = { 176, 174, 168 }, mat = "Concrete" })
		for _, x in ipairs({ -209, -195, -181 }) do
			for _, z in ipairs({ 29, 51 }) do
				b:box({ name = "Pilar", size = { 1.6, 10, 1.6 }, pos = { x, 5.4, z }, color = { 186, 184, 178 }, mat = "Concrete" })
				if x < -185 then
					b:box({ name = "Pilar", size = { 1.6, 9.2, 1.6 }, pos = { x, 15.4, z }, color = { 186, 184, 178 }, mat = "Concrete" })
				end
			end
		end
		P.stairs(b, { -207, 0.4, 15 }, 0, 10, 1.04, 1.3, 4, { 170, 168, 162 })
		P.stairs(b, { -186, 10.8, 51 }, 180, 10, 1, 1.3, 4, { 170, 168, 162 })
		P.railing(b, { -210, 20.8, 52 }, { -188, 20.8, 52 }, 3, { 240, 190, 40 })
		b:box({ name = "Grua", size = { 3, 64, 3 }, pos = { -170, 32.4, 76 }, color = { 240, 190, 40 }, mat = "Metal" })
		b:box({ name = "Pluma", size = { 50, 2.4, 2.4 }, pos = { -180, 64, 76 }, color = { 240, 190, 40 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Contrapeso", size = { 6, 4, 4 }, pos = { -150, 62, 76 }, color = { 120, 120, 126 }, mat = "Concrete", folder = "Decoracion" })
		for i = 0, 2 do
			b:cylinder({ name = "Tubo", axis = "x", length = 9, diameter = 4, pos = { -172, 2.4 + (i == 2 and 3.4 or 0), 22 + (i == 2 and 2.2 or i * 4.4) }, color = { 170, 168, 160 }, mat = "Concrete" })
		end
		for i = 0, 3 do
			b:box({ name = "Viga", size = { 16, 0.8, 1 }, pos = { -196, 0.8 + i * 0.8, 70 + (i % 2) * 0.5 }, color = { 170, 70, 50 }, mat = "Metal" })
		end
		P.container(b, { -200, 0.4, 82 }, 0, { 240, 240, 236 }, false, "OBRA")
		P.cone(b, { -166, 0.4, 40 })
		P.cone(b, { -166, 0.4, 46 })
		P.barrier(b, { -162, 0.4, 60 }, 90)

		-- =============================================================
		--  Aparcamiento de dos plantas con rampa (x -215..-160, z 112..196)
		-- =============================================================
		slab(-215, -160, 112, 196, { 150, 150, 150 }, "Concrete")
		b:box({ name = "Planta", size = { 50, 1, 50 }, pos = { -187.5, 12, 160 }, color = { 160, 160, 160 }, mat = "Concrete" })
		for _, x in ipairs({ -210, -187.5, -165 }) do
			for _, z in ipairs({ 138, 160, 182 }) do
				b:box({ name = "Pilar", size = { 2, 11.2, 2 }, pos = { x, 6, z }, color = { 186, 186, 186 }, mat = "Concrete" })
			end
		end
		b:wedge({ name = "Rampa", size = { 10, 12, 22 }, pos = { -175, 6.4, 124 }, color = { 150, 150, 150 }, mat = "Concrete" })
		P.wall(b, { -187.5, 12.5, 184.5 }, 0, { 50, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -212, 12.5, 160 }, 90, { 50, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -163, 12.5, 166 }, 90, { 38, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -196, 12.5, 135.5 }, 0, { 32, 3, 1 }, { 200, 200, 196 })
		P.car(b, { -200, 12.5, 170 }, 0, { 230, 230, 226 })
		P.car(b, { -180, 12.5, 150 }, 180, { 40, 40, 46 })
		P.car(b, { -200, 0.4, 150 }, 0, { 200, 160, 40 })
		P.car(b, { -176, 0.4, 176 }, 180, { 120, 40, 40 })

		-- =============================================================
		--  Plaza: árboles, fuentes, bancos, quioscos y paradas de autobús
		-- =============================================================
		for z = -72, 72, 24 do
			if math.abs(z) > 20 then
				b:box({ name = "Alcorque", size = { 5, 0.8, 5 }, pos = { -54, 0.8, z }, color = { 170, 164, 154 }, mat = "Concrete" })
				P.tree(b, { -54, 1.2, z }, 0.9, TREES)
			end
		end
		P.fountain(b, { -32, 0.4, -54 }, 6)
		P.fountain(b, { -32, 0.4, 54 }, 6)
		P.planter(b, { -36, 0.4, -20 }, { 3, 12 }, 0)
		P.planter(b, { -36, 0.4, 20 }, { 3, 12 }, 0)
		P.bench(b, { -20, 0.4, -30 }, 0, { 120, 90, 60 })
		P.bench(b, { -20, 0.4, 30 }, 180, { 120, 90, 60 })
		P.newspaperBox(b, { -60, 0.4, -6 }, -90, { 40, 90, 170 })
		P.marketStall(b, { -46, 0.4, -82 }, 0, { 230, 120, 40 }, "CHURROS")
		P.hotdogCart(b, { -44, 0.4, 80 }, 180)
		P.mannequin(b, { -14, 7.4, -48 }, 30, { 200, 170, 80 })
		b:box({ name = "Pedestal", size = { 4, 7, 4 }, pos = { -14, 3.9, -48 }, color = { 200, 196, 186 }, mat = "Marble" })

		-- =============================================================
		--  Tráfico en las calles: coches, taxis, autobuses y barreras
		-- =============================================================
		P.taxi(b, { -150, 0, -40 }, 0)
		P.car(b, { -75, 0, 30 }, 180, { 60, 120, 200 })
		P.car(b, { -225, 0, 100 }, 0, { 90, 90, 96 })
		P.taxi(b, { -190, 0, 104 }, 90)
		P.car(b, { -120, 0, -96 }, 92, { 230, 230, 226 })
		P.bus(b, { -100, 0, 4 }, 90, { 200, 50, 50 }, "LÍNEA 50")
		P.truck(b, { -40, 0, -104 }, 90, { 236, 236, 232 })
		P.car(b, { -170, 0, -4 }, 75, { 200, 160, 40 })
		P.barrier(b, { -150, 0, 60 }, 0)
		P.barrier(b, { -75, 0, -60 }, 0)
		P.barrier(b, { -225, 0, -100 }, 90)
		for _, p in ipairs({ { -150, 140 }, { -75, 150 }, { -225, 30 } }) do
			P.cone(b, { p[1] - 3, 0, p[2] })
			P.cone(b, { p[1] + 3, 0, p[2] })
		end
		for _, z in ipairs({ -36, -24 }) do
			P.bus(b, { z, 0.4, -150 }, 0, { 240, 240, 236 }, "TERMINAL")
		end
		for x = -48, -8, 20 do
			b:box({ name = "Pilar", size = { 1.4, 11.6, 1.4 }, pos = { x, 6.2, -128 }, color = { 200, 204, 210 }, mat = "Metal" })
			b:box({ name = "Pilar", size = { 1.4, 11.6, 1.4 }, pos = { x, 6.2, -168 }, color = { 200, 204, 210 }, mat = "Metal" })
		end

		-- Farolas a lo largo de las avenidas
		for _, x in ipairs({ -260, -190, -120, -45 }) do
			P.streetLight(b, { x, 0.4, 87 }, 0, 18)
			P.streetLight(b, { x + 30, 0.4, -87 }, 180, 18)
		end
	end)

	b:bounds(-300, 300, -200, 200, 150)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 15.2,
			Brightness = 3,
			Ambient = { 120, 118, 116 },
			OutdoorAmbient = { 164, 160, 156 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.2,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, offset = 0.05, color = { 214, 214, 220 }, decay = { 150, 156, 170 }, glare = 0.5, haze = 1.6 },
		colorCorrection = { contrast = 0.08, saturation = 0.1, tint = { 255, 252, 246 } },
		clouds = { cover = 0.45, density = 0.45, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
