-- Gasolinera al atardecer. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ASPHALT = { 96, 84, 86 }
	local ROAD = { 72, 64, 68 }
	local LINE = { 236, 230, 220 }
	local STORE = { 62, 92, 74 }
	local TRIM = { 40, 44, 48 }
	local WHITE = { 238, 236, 232 }
	local RED = { 205, 45, 45 }
	local BRICK = { 150, 82, 68 }
	local YELLOW = { 245, 200, 40 }
	local AUTUMN = {
		{ { 198, 122, 60 }, { 170, 108, 52 }, { 136, 128, 62 } },
		{ { 176, 132, 58 }, { 204, 150, 72 }, { 122, 120, 58 } },
		{ { 150, 104, 50 }, { 188, 112, 56 }, { 146, 138, 70 } },
	}

	b.model:SetAttribute("Nombre", "Gasolinera")

	-- Terreno de alrededor: césped, colinas y árboles de otoño
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 110, 146, 72 }, mat = "Grass", folder = "Decoracion" })
	local hills = { { 0, -40, 140, 150 }, { -115, -32, 100, 120 }, { 115, -32, 100, 120 }, { -160, -42, 0, 140 }, { 160, -42, 0, 140 }, { -70, -48, -125, 130 }, { 70, -48, -125, 130 } }
	for _, h in ipairs(hills) do
		b:ball({ name = "Colina", diameter = h[4], pos = { h[1], h[2], h[3] }, color = { 112, 150, 74 }, mat = "Grass", folder = "Decoracion" })
	end
	local trees = {
		{ -70, 72, 1.5 }, { -40, 80, 1.7 }, { -12, 74, 1.4 }, { 18, 82, 1.8 }, { 46, 72, 1.5 }, { 74, 80, 1.6 },
		{ -100, 40, 1.6 }, { -104, 0, 1.8 }, { -98, -36, 1.5 }, { 100, 36, 1.7 }, { 104, -4, 1.5 }, { 98, -40, 1.8 },
		{ -60, -78, 1.6 }, { -20, -82, 1.4 }, { 24, -80, 1.7 }, { 62, -76, 1.5 },
	}
	for i, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, t[3], AUTUMN[(i % 3) + 1])
	end

	-- Aparcamiento y carretera
	b:box({ name = "Asfalto", size = { 164, 1, 116 }, pos = { 0, -0.5, 0 }, color = ASPHALT, mat = "Asphalt" })
	b:box({ name = "Carretera", size = { 164, 0.1, 22 }, pos = { 0, 0.05, -44 }, color = ROAD, mat = "Asphalt", folder = "Decoracion" })
	for x = -78, 78, 12 do
		b:box({ name = "Linea", size = { 6, 0.12, 0.6 }, pos = { x, 0.07, -44 }, color = LINE, folder = "Decoracion" })
	end
	b:box({ name = "Linea", size = { 164, 0.12, 0.5 }, pos = { 0, 0.07, -32.8 }, color = LINE, folder = "Decoracion" })

	-- Tienda (centro, con puerta delantera y dos laterales)
	b:box({ name = "ParedTrasera", size = { 36, 14, 1.5 }, pos = { 0, 7, 39.25 }, color = STORE, mat = "Slate" })
	b:box({ name = "Zocalo", size = { 36, 2, 1.2 }, pos = { 0, 1, 20.6 }, color = TRIM })
	b:box({ name = "Fachada", size = { 36, 4, 1.5 }, pos = { 0, 12, 20.75 }, color = STORE, mat = "Slate" })
	local header = b:box({ name = "Rotulo", size = { 22, 2.6, 0.3 }, pos = { 0, 12, 19.85 }, color = { 30, 34, 38 } })
	MB.sign(header, "MINI MARKET 24H", { font = "GothamBlack", color = { 255, 214, 90 }, glow = true })
	b:box({ name = "Tejado", size = { 38, 1, 22 }, pos = { 0, 14.5, 30 }, color = TRIM })
	b:box({ name = "SueloTienda", size = { 34, 0.1, 18 }, pos = { 0, 0.06, 30 }, color = { 222, 220, 214 }, folder = "Decoracion" })
	b:box({ name = "Mostrador", size = { 8, 3.5, 2.4 }, pos = { 0, 1.75, 35 }, color = { 120, 80, 56 }, mat = "WoodPlanks" })
	local lamp = b:box({ name = "LuzTienda", size = { 10, 0.2, 2 }, pos = { 0, 13.9, 30 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
	MB.light(lamp, "Surface", { face = "Bottom", brightness = 1.2, range = 20, angle = 120 })

	-- Carteles de los escaparates
	local cafe = b:box({ name = "Cartel", size = { 5, 2.2, 0.1 }, pos = { -11, 8, 19.9 }, color = { 214, 120, 40 } })
	MB.sign(cafe, "CAFÉ", { bg = { 214, 120, 40 }, color = { 255, 255, 255 } })
	local ice = b:box({ name = "Cartel", size = { 5, 2.2, 0.1 }, pos = { -5.5, 6, 19.9 }, color = { 245, 245, 245 } })
	MB.sign(ice, "HELADO", { bg = { 245, 245, 245 }, color = { 40, 110, 200 } })
	local offer = b:box({ name = "Cartel", size = { 5, 3, 0.1 }, pos = { 9, 7, 19.9 }, color = YELLOW })
	MB.sign(offer, "OFERTA 2x1", { bg = YELLOW, color = { 200, 30, 30 } })

	-- Marquesina con surtidores
	b:box({ name = "Marquesina", size = { 44, 1.6, 18 }, pos = { 0, 16.8, -7 }, color = WHITE })
	b:box({ name = "FranjaRoja", size = { 44.6, 0.8, 18.6 }, pos = { 0, 15.8, -7 }, color = RED, folder = "Decoracion" })
	local canopySign = b:box({ name = "Rotulo", size = { 20, 1.6, 0.2 }, pos = { 0, 16.8, -16.15 }, color = WHITE })
	MB.sign(canopySign, "GASOLINA 24H", { font = "GothamBlack", color = RED })

	-- Cables entre postes
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -30.6 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -29.4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

	b:symmetric(function(b)
		-- Pared lateral de la tienda con puerta
		b:box({ name = "Pared", size = { 1.5, 14, 6 }, pos = { -17.25, 7, 23 }, color = STORE, mat = "Slate" })
		b:box({ name = "Pared", size = { 1.5, 14, 8 }, pos = { -17.25, 7, 36 }, color = STORE, mat = "Slate" })
		b:box({ name = "Dintel", size = { 1.5, 5, 6 }, pos = { -17.25, 11.5, 29 }, color = STORE, mat = "Slate" })
		-- Escaparate y puerta central
		b:box({ name = "Escaparate", size = { 13.4, 8, 0.4 }, pos = { -10.2, 6, 20.4 }, color = { 170, 200, 210 }, mat = "Glass", transparency = 0.45 })
		b:box({ name = "Marco", size = { 1.2, 10, 1.2 }, pos = { -3.6, 5, 20.6 }, color = TRIM })
		-- Interior: estantería y neveras
		b:box({ name = "Estanteria", size = { 1.6, 5, 9 }, pos = { -9, 2.5, 30 }, color = { 210, 210, 214 }, mat = "Metal" })
		for i = 0, 3 do
			local colors = { { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } }
			b:box({ name = "Productos", size = { 1.9, 0.8, 8 }, pos = { -9, 0.9 + i * 1.2, 30 }, color = colors[i + 1], folder = "Decoracion" })
		end
		local fridge = b:box({ name = "Nevera", size = { 7, 8, 1.6 }, pos = { -11, 4, 37.6 }, color = { 205, 225, 238 } })
		MB.light(fridge, "Surface", { face = "Front", brightness = 0.6, range = 8, color = { 200, 230, 255 } })
		P.acUnit(b, { -9, 15, 33 }, 0)

		-- Arcón de hielo y banco en la entrada
		local iceBox = b:box({ name = "Hielo", size = { 4.4, 3.6, 2.4 }, pos = { -21.5, 1.8, 18 }, color = { 240, 244, 248 } })
		MB.sign(iceBox, "HIELO", { color = { 40, 110, 200 }, font = "GothamBlack" })
		P.bench(b, { -9, 0, 16.5 }, 0)

		-- Pilares de la marquesina, isla y surtidores
		for _, z in ipairs({ -14, 0 }) do
			b:box({ name = "Pilar", size = { 2, 15, 2 }, pos = { -18, 7.5, z }, color = BRICK, mat = "Brick" })
		end
		local light = b:box({ name = "LuzMarquesina", size = { 8, 0.2, 3 }, pos = { -9, 15.9, -7 }, color = { 255, 246, 226 }, mat = "Neon", folder = "Decoracion" })
		MB.light(light, "Surface", { face = "Bottom", brightness = 1.3, range = 24, angle = 120 })
		b:box({ name = "Isla", size = { 3, 0.6, 13 }, pos = { -8, 0.3, -7 }, color = YELLOW, mat = "Concrete" })
		P.pump(b, { -8, 0.6, -10.5 }, 0)
		P.pump(b, { -8, 0.6, -3.5 }, 0)
		for _, z in ipairs({ -14.2, 0.2 }) do
			b:cylinder({ name = "Bolardo", length = 3, diameter = 1, pos = { -8, 1.5, z }, color = YELLOW })
		end

		-- Coches
		P.car(b, { -40, 0, 30 }, 0, b.mirrored and { 50, 100, 190 } or { 190, 50, 50 })
		P.car(b, { -29, 0, -44 }, 70, b.mirrored and { 220, 220, 220 } or { 90, 90, 96 })

		-- Barreras, setos y contenedor de basura
		P.barrier(b, { -50, 0, -22 }, 0)
		P.barrier(b, { -30, 0, -18 }, 20)
		P.barrier(b, { -62, 0, 12 }, 90)
		P.barrier(b, { -38, 0, 6 }, 90)
		b:box({ name = "Seto", size = { 22, 3, 3 }, pos = { -52, 1.5, 44 }, color = { 92, 124, 62 }, mat = "LeafyGrass" })
		b:box({ name = "Contenedor", size = { 6, 4.5, 3.5 }, pos = { -26, 2.25, 42 }, color = { 60, 110, 70 }, mat = "Metal" })
		P.crate(b, { -52, 0, 26 }, 4)
		P.crate(b, { -60, 0, -38 }, 4.5, 25)

		-- Plazas de aparcamiento
		for _, x in ipairs({ -46, -40, -34 }) do
			b:box({ name = "Plaza", size = { 0.4, 0.12, 10 }, pos = { x - 3, 0.07, 30 }, color = LINE, folder = "Decoracion" })
		end

		-- Postes eléctricos
		P.pole(b, { -66, 0, -30 }, 28)
		P.pole(b, { -66, 0, 48 }, 28)
		b:box({ name = "Cable", size = { 0.15, 0.15, 78 }, pos = { -66.6, 27.2, 9 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

		-- Camión de reparto que tapa la visión de los spawns
		local cargo = P.truck(b, { -63, 0, 4 }, 0, b.mirrored and { 236, 236, 232 } or { 250, 214, 90 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(cargo, "REPARTO 24H", { face = face, font = "GothamBlack", color = { 200, 40, 40 }, height = 0.4 })
		end

		for _, z in ipairs({ 0, 6, 12 }) do
			b:spawn("A", { -72, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -56, 56, 45)

	b:lighting({
		lighting = {
			ClockTime = 17.7,
			Brightness = 2.6,
			Ambient = { 112, 82, 82 },
			OutdoorAmbient = { 152, 106, 102 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.3,
		},
		atmosphere = { density = 0.32, offset = 0.1, color = { 255, 162, 142 }, decay = { 152, 82, 92 }, glare = 1.2, haze = 2.2 },
		colorCorrection = { contrast = 0.05, saturation = 0.15, tint = { 255, 236, 228 } },
		clouds = { cover = 0.72, density = 0.6, color = { 255, 132, 122 } },
	})
end
