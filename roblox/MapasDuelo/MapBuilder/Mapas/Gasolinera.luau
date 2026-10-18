-- Gasolinera al atardecer. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ASPHALT = { 98, 86, 88 }
	local ROAD = { 70, 62, 66 }
	local LINE = { 236, 230, 220 }
	local STORE = { 62, 94, 76 }
	local BRICK = { 150, 82, 68 }
	local TRIM = { 40, 44, 48 }
	local WHITE = { 240, 238, 234 }
	local RED = { 205, 45, 45 }
	local YELLOW = { 245, 200, 40 }
	local AUTUMN = {
		{ { 198, 122, 60 }, { 170, 108, 52 }, { 136, 128, 62 } },
		{ { 176, 132, 58 }, { 204, 150, 72 }, { 122, 120, 58 } },
		{ { 150, 104, 50 }, { 188, 112, 56 }, { 146, 138, 70 } },
	}

	b.model:SetAttribute("Nombre", "Gasolinera")

	-- =================================================================
	--  Paisaje: césped, colinas, árboles de otoño y valla publicitaria
	-- =================================================================
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 112, 148, 72 }, mat = "Grass", folder = "Decoracion" })
	local hills = { { 0, -40, 140, 150 }, { -115, -32, 100, 120 }, { 115, -32, 100, 120 }, { -160, -42, 0, 140 }, { 160, -42, 0, 140 }, { -70, -48, -128, 130 }, { 70, -48, -128, 130 } }
	for _, h in ipairs(hills) do
		b:ball({ name = "Colina", diameter = h[4], pos = { h[1], h[2], h[3] }, color = { 114, 152, 76 }, mat = "Grass", folder = "Decoracion" })
	end
	local trees = {
		{ -70, 70, 1.4 }, { -42, 78, 1.6 }, { -14, 72, 1.3 }, { 16, 80, 1.7 }, { 46, 70, 1.4 }, { 74, 78, 1.5 },
		{ -100, 40, 1.5 }, { -104, 4, 1.7 }, { -98, -34, 1.4 }, { 100, 34, 1.6 }, { 104, -2, 1.4 }, { 98, -38, 1.7 },
		{ -62, -76, 1.5 }, { -22, -82, 1.3 }, { 24, -80, 1.6 }, { 62, -74, 1.4 }, { -88, 62, 1.2 }, { 90, 60, 1.3 },
	}
	for i, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, t[3], AUTUMN[(i % 3) + 1])
	end
	for x = -70, 70, 14 do
		P.bush(b, { x, -0.7, 61 }, 1.2, { 98, 128, 64 })
	end
	-- Valla publicitaria en la colina
	for _, x in ipairs({ -10, 10 }) do
		b:box({ name = "Poste", size = { 1.2, 22, 1.2 }, pos = { x, 11, 96 }, color = { 80, 70, 64 }, mat = "Wood", folder = "Decoracion" })
	end
	local billboard = b:box({ name = "Valla", size = { 34, 12, 1 }, pos = { 0, 24, 96 }, color = { 250, 240, 220 }, folder = "Decoracion" })
	MB.sign(billboard, "MOTEL EL OASIS · 5 KM", { font = "LuckiestGuy", color = { 210, 70, 50 }, bg = { 250, 236, 206 }, width = 0.9, height = 0.6 })

	-- =================================================================
	--  Carretera y acera
	-- =================================================================
	b:box({ name = "Asfalto", size = { 164, 1, 116 }, pos = { 0, -0.5, 0 }, color = ASPHALT, mat = "Asphalt" })
	b:box({ name = "Carretera", size = { 164, 0.1, 22 }, pos = { 0, 0.05, -44 }, color = ROAD, mat = "Asphalt", folder = "Decoracion" })
	for x = -78, 78, 12 do
		b:box({ name = "Linea", size = { 6, 0.12, 0.6 }, pos = { x, 0.07, -44 }, color = LINE, folder = "Decoracion" })
	end
	b:box({ name = "Linea", size = { 164, 0.12, 0.5 }, pos = { 0, 0.07, -54 }, color = LINE, folder = "Decoracion" })
	P.sidewalk(b, { 0, 0, -30.8 }, { 164, 4.4 })
	P.guardrail(b, { -82, 0, -55.6 }, { 82, 0, -55.6 })
	P.woodFence(b, { -80, 0, 55.6 }, { 80, 0, 55.6 }, 4)

	-- Poste de precios en el centro
	P.pricePylon(b, { 0, 0, -25 }, 0, "GASOLINA 24H", RED)

	-- =================================================================
	--  Tienda (centro, con puerta delantera y dos laterales)
	-- =================================================================
	b:box({ name = "ParedTrasera", size = { 36, 14, 1.5 }, pos = { 0, 7, 39.25 }, color = STORE, mat = "Slate" })
	b:box({ name = "Zocalo", size = { 36.4, 3, 1.8 }, pos = { 0, 1.5, 39.25 }, color = BRICK, mat = "Brick" })
	b:box({ name = "Zocalo", size = { 36, 2, 1.2 }, pos = { 0, 1, 20.6 }, color = BRICK, mat = "Brick" })
	b:box({ name = "Fachada", size = { 36, 4, 1.5 }, pos = { 0, 12, 20.75 }, color = STORE, mat = "Slate" })
	b:box({ name = "Cornisa", size = { 38.4, 0.8, 23.4 }, pos = { 0, 14.4, 30 }, color = TRIM, mat = "Concrete" })
	b:box({ name = "Tejado", size = { 37, 0.6, 21 }, pos = { 0, 14.9, 30 }, color = { 70, 70, 76 }, mat = "Concrete" })
	P.neonSign(b, { 0, 12.7, 19.7 }, 0, { 22, 2.4 }, "MINI MARKET 24H", { 255, 214, 90 }, "GothamBlack")
	b:box({ name = "SueloTienda", size = { 34, 0.1, 18 }, pos = { 0, 0.06, 30 }, color = { 226, 224, 218 }, mat = "CeramicTiles", folder = "Decoracion" })
	b:box({ name = "Mostrador", size = { 8, 3.5, 2.4 }, pos = { 0, 1.75, 35 }, color = { 120, 80, 56 }, mat = "WoodPlanks" })
	b:box({ name = "Encimera", size = { 8.4, 0.3, 2.8 }, pos = { 0, 3.6, 35 }, color = { 230, 228, 222 }, mat = "Marble" })
	b:box({ name = "Cafetera", size = { 1.4, 1.6, 1.2 }, pos = { 2.6, 4.5, 35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
	local lamp = b:box({ name = "LuzTienda", size = { 10, 0.2, 2 }, pos = { 0, 13.9, 30 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
	MB.light(lamp, "Surface", { face = "Bottom", brightness = 1.4, range = 20, angle = 120 })
	-- Carteles de los escaparates
	P.poster(b, { -11, 8, 19.85 }, 0, { 5, 2.2 }, { 214, 120, 40 }, "CAFÉ")
	P.poster(b, { -5.5, 6, 19.85 }, 0, { 5, 2.2 }, { 245, 245, 245 }, "HELADO", { 40, 110, 200 })
	P.poster(b, { 9, 7, 19.85 }, 0, { 5, 3 }, YELLOW, "OFERTA 2x1", { 200, 30, 30 })
	P.neonSign(b, { 13.5, 4, 19.9 }, 0, { 4, 1.4 }, "ABIERTO", { 90, 255, 120 })
	-- Toldo a rayas sobre el escaparate
	for i = 0, 8 do
		b:wedge({ name = "Toldo", size = { 4, 1.6, 3 }, pos = { -16 + i * 4, 10.6, 18.6 }, color = (i % 2 == 0) and RED or WHITE, mat = "Fabric" })
	end

	-- =================================================================
	--  Marquesina con surtidores
	-- =================================================================
	b:box({ name = "Marquesina", size = { 44, 1.6, 18 }, pos = { 0, 16.8, -7 }, color = WHITE })
	b:box({ name = "FranjaRoja", size = { 44.6, 1.1, 18.6 }, pos = { 0, 15.9, -7 }, color = RED, folder = "Decoracion" })
	b:box({ name = "Filete", size = { 44.7, 0.2, 18.7 }, pos = { 0, 16.6, -7 }, color = WHITE, folder = "Decoracion" })
	local canopySign = b:box({ name = "Rotulo", size = { 20, 1.4, 0.2 }, pos = { 0, 16.8, -16.15 }, color = WHITE, folder = "Decoracion" })
	MB.sign(canopySign, "GASOLINA 24H", { font = "GothamBlack", color = RED })

	-- Cables entre postes
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -30.6 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -29.4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

	b:symmetric(function(b)
		-- Paredes laterales de la tienda con puerta
		b:box({ name = "Pared", size = { 1.5, 14, 6 }, pos = { -17.25, 7, 23 }, color = STORE, mat = "Slate" })
		b:box({ name = "Pared", size = { 1.5, 14, 8 }, pos = { -17.25, 7, 36 }, color = STORE, mat = "Slate" })
		b:box({ name = "Dintel", size = { 1.5, 5, 6 }, pos = { -17.25, 11.5, 29 }, color = STORE, mat = "Slate" })
		for _, z in ipairs({ 23, 36 }) do
			b:box({ name = "Zocalo", size = { 1.9, 3, z == 23 and 6 or 8 }, pos = { -17.25, 1.5, z }, color = BRICK, mat = "Brick" })
		end
		-- Escaparate y marcos
		b:box({ name = "Escaparate", size = { 13.4, 8, 0.4 }, pos = { -10.2, 6, 20.4 }, color = { 170, 200, 210 }, mat = "Glass", transparency = 0.45 })
		for _, x in ipairs({ -3.6, -10.2, -16.9 }) do
			b:box({ name = "Marco", size = { 1, 10, 1 }, pos = { x, 5, 20.6 }, color = TRIM, mat = "Metal" })
		end
		-- Interior
		for _, x in ipairs({ -12.5, -7 }) do
			b:box({ name = "Estanteria", size = { 1.6, 5, 9 }, pos = { x, 2.5, 29.5 }, color = { 210, 210, 214 }, mat = "Metal" })
			local colors = { { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } }
			for i = 0, 3 do
				b:box({ name = "Productos", size = { 1.9, 0.8, 8.2 }, pos = { x, 0.9 + i * 1.2, 29.5 }, color = colors[((i + (x < -10 and 1 or 0)) % 4) + 1], folder = "Decoracion" })
			end
		end
		local fridge = b:box({ name = "Nevera", size = { 9, 8, 1.6 }, pos = { -11, 4, 37.6 }, color = { 205, 225, 238 }, mat = "Glass", transparency = 0.2 })
		MB.light(fridge, "Surface", { face = "Front", brightness = 0.7, range = 10, color = { 200, 230, 255 } })
		P.acUnit(b, { -9, 15.2, 33 }, 0)
		P.vent(b, { -14, 15.2, 25 })

		-- Entrada: cajero, banco, periódicos, hielo y papelera
		P.atm(b, { -15.5, 0, 18.4 }, 0)
		P.bench(b, { -9.5, 0, 16.8 }, 0)
		P.newspaperBox(b, { -5.2, 0, 17.8 }, 0)
		local iceBox = b:box({ name = "Hielo", size = { 4.4, 3.6, 2.4 }, pos = { -21.5, 1.8, 18 }, color = { 240, 244, 248 } })
		MB.sign(iceBox, "HIELO", { color = { 40, 110, 200 }, font = "GothamBlack" })
		P.trashCan(b, { -26.2, 0, 18 })
		P.propaneCage(b, { -19.8, 0, 36.5 }, 90)
		P.dumpster(b, { -25, 0, 45 }, 0)
		P.pallet(b, { -32, 0, 46 }, 15)
		P.cardboard(b, { -32, 0.8, 46 }, { 3, 2.4, 2.6 }, 10)

		-- Pilares de la marquesina, luces, isla y surtidores
		for _, z in ipairs({ -14, 0 }) do
			b:box({ name = "Pilar", size = { 2, 15, 2 }, pos = { -18, 7.5, z }, color = BRICK, mat = "Brick" })
			b:box({ name = "Peana", size = { 3, 1, 3 }, pos = { -18, 0.5, z }, color = { 190, 186, 180 }, mat = "Concrete" })
		end
		b:cylinder({ name = "Extintor", length = 1.6, diameter = 0.7, pos = { -16.7, 2, 0 }, color = RED, mat = "Metal" })
		for _, z in ipairs({ -12, -2 }) do
			local panel = b:box({ name = "LuzMarquesina", size = { 8, 0.2, 3 }, pos = { -9, 15.9, z }, color = { 255, 246, 226 }, mat = "Neon", folder = "Decoracion" })
			if z == -12 then
				MB.light(panel, "Surface", { face = "Bottom", brightness = 1.4, range = 24, angle = 120 })
			end
		end
		b:box({ name = "Isla", size = { 3.4, 0.6, 14 }, pos = { -8, 0.3, -7 }, color = YELLOW, mat = "Concrete" })
		for i = 0, 6 do
			b:box({ name = "Raya", size = { 3.45, 0.62, 0.8 }, pos = { -8, 0.3, -13.4 + i * 2.1 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		P.pump(b, { -8, 0.6, -10.5 }, 0)
		P.pump(b, { -8, 0.6, -3.5 }, 0)
		for _, z in ipairs({ -14.6, 0.6 }) do
			b:cylinder({ name = "Bolardo", length = 3, diameter = 1, pos = { -8, 1.5, z }, color = YELLOW, mat = "Metal" })
		end
		P.stain(b, { -13, 0, -8 }, 5)
		P.stain(b, { -3.5, 0, -5 }, 3.6)

		-- Taller mecánico (se puede entrar por el portón)
		local SHOP = { 176, 112, 92 }
		b:box({ name = "Taller", size = { 18, 12, 1 }, pos = { -53, 6, 47.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 1, 12, 18 }, pos = { -61.5, 6, 39 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 1, 12, 18 }, pos = { -44.5, 6, 39 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 4, 12, 1 }, pos = { -60, 6, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 4, 12, 1 }, pos = { -46, 6, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Dintel", size = { 10, 3, 1 }, pos = { -53, 10.5, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Porton", size = { 10, 2.6, 0.4 }, pos = { -53, 7.7, 30.6 }, color = { 150, 156, 164 }, mat = "DiamondPlate" })
		b:box({ name = "TechoTaller", size = { 19, 0.8, 19 }, pos = { -53, 12.4, 39 }, color = { 70, 70, 76 }, mat = "Concrete" })
		P.poster(b, { -53, 10.6, 29.95 }, 0, { 9, 2 }, { 30, 34, 40 }, "TALLER", YELLOW, "GothamBlack")
		P.car(b, { -53, 0, 40 }, 0, b.mirrored and { 60, 120, 90 } or { 220, 160, 40 })
		b:box({ name = "Banco", size = { 2.4, 3.6, 5 }, pos = { -59.6, 1.8, 43 }, color = { 190, 50, 46 }, mat = "Metal" })
		P.tires(b, { -46.6, 0, 45.4 }, 4)
		P.drum(b, { -59.4, 0, 34 }, { 60, 90, 160 })
		local shopLamp = b:box({ name = "Lampara", size = { 6, 0.2, 1 }, pos = { -53, 11.8, 39 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
		MB.light(shopLamp, "Point", { brightness = 1, range = 16 })

		-- Coches
		P.car(b, { -40, 0, 30 }, 0, b.mirrored and { 50, 100, 190 } or { 190, 50, 50 })
		P.car(b, { -29, 0, -44 }, 70, b.mirrored and { 220, 220, 220 } or { 90, 90, 96 })
		P.cone(b, { -21, 0, -40 })
		P.cone(b, { -22.5, 0, -47 })

		-- Barreras, jardineras y cajas
		P.barrier(b, { -50, 0, -22 }, 0)
		P.barrier(b, { -30, 0, -18 }, 20)
		P.barrier(b, { -50, 0, 14 }, 90)
		P.barrier(b, { -38, 0, 6 }, 90)
		P.planter(b, { -34, 0, -26 }, { 10, 3 }, 0)
		P.crate(b, { -32, 0, 21 }, 4)
		P.crate(b, { -60, 0, -37 }, 4.5, 25)
		P.puddle(b, { -44, 0, -10 }, 6)
		P.manhole(b, { -20, 0.1, -44 })

		-- Plazas de aparcamiento
		for _, x in ipairs({ -43, -37, -31 }) do
			b:box({ name = "Plaza", size = { 0.4, 0.12, 10 }, pos = { x, 0.07, 29 }, color = LINE, folder = "Decoracion" })
		end
		-- Paso de cebra
		for z = -52, -36, 2.4 do
			b:box({ name = "Cebra", size = { 6, 0.12, 1.2 }, pos = { -42, 0.08, z }, color = LINE, folder = "Decoracion" })
		end

		-- Farolas, postes eléctricos y valla lateral
		P.streetLight(b, { -50, 0.6, -29.4 }, 0, 18)
		P.streetLight(b, { -22, 0.6, -29.4 }, 0, 18)
		P.pole(b, { -66, 0, -30 }, 28)
		P.pole(b, { -66, 0, 50 }, 28)
		b:box({ name = "Cable", size = { 0.15, 0.15, 80 }, pos = { -66.6, 27.2, 10 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
		P.chainFence(b, { -80.6, 0, -28 }, { -80.6, 0, 55 }, 7)

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
		technology = "Future",
		lighting = {
			ClockTime = 17.7,
			Brightness = 2.8,
			Ambient = { 112, 82, 82 },
			OutdoorAmbient = { 156, 108, 104 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.32, offset = 0.1, color = { 255, 162, 142 }, decay = { 152, 82, 92 }, glare = 1.4, haze = 2.2 },
		colorCorrection = { contrast = 0.08, saturation = 0.18, tint = { 255, 236, 228 } },
		clouds = { cover = 0.72, density = 0.6, color = { 255, 132, 122 } },
		bloom = { intensity = 0.45, size = 28, threshold = 0.9 },
		sunRays = { intensity = 0.12, spread = 0.7 },
	})
end
