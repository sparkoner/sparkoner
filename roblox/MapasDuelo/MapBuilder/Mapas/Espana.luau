-- España: plaza andaluza con casas encaladas, fuente, naranjos y terrazas. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local WHITE = { 246, 244, 238 }
	local TEJA = { 186, 94, 62 }
	local ALBERO = { 214, 186, 140 }
	local NARANJO = { { 64, 116, 60 }, { 82, 132, 66 }, { 56, 104, 54 } }
	local OLIVO = { { 120, 130, 90 }, { 136, 146, 104 }, { 106, 118, 82 } }
	local CASAS = {
		{ w = 13, h = 13, color = WHITE, trim = { 214, 170, 90 }, roof = "gable", roofColor = TEJA, shutters = { 52, 112, 76 }, balcony = true, flowers = { 220, 50, 70 } },
		{ w = 12, h = 12, color = WHITE, trim = { 60, 100, 170 }, roof = "gable", roofColor = TEJA, shop = "BAR PACO · TAPAS", shopColor = { 150, 30, 40 } },
		{ w = 14, h = 14, color = { 250, 236, 200 }, trim = { 190, 140, 70 }, roof = "gable", roofColor = TEJA, shutters = { 60, 96, 160 }, balcony = true, flowers = { 240, 120, 160 } },
		{ w = 12, h = 12, color = WHITE, trim = { 214, 170, 90 }, roof = "gable", roofColor = TEJA, shop = "PANADERÍA", shopColor = { 196, 130, 50 } },
		{ w = 13, h = 13, color = { 248, 222, 160 }, trim = WHITE, roof = "gable", roofColor = TEJA, shutters = { 110, 70, 44 }, balcony = true, flowers = { 220, 50, 70 } },
	}

	b.model:SetAttribute("Nombre", "España")

	-- =================================================================
	--  Paisaje: colinas secas con olivos
	-- =================================================================
	b:box({ name = "Campo", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 178, 160, 108 }, mat = "Grass", folder = "Decoracion" })
	for _, h in ipairs({ { -170, 150, 170 }, { 170, 150, 170 }, { 0, 210, 190 }, { -160, -150, 160 }, { 160, -150, 160 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.32, h[2] }, color = { 160, 146, 98 }, mat = "Grass", folder = "Decoracion" })
	end
	for i = 0, 11 do
		local x = -110 + (i % 6) * 44
		local z = (i < 6) and 92 or -92
		P.tree(b, { x, 0, z + (i % 2) * 10 }, 0.9, OLIVO)
	end

	-- =================================================================
	--  Plaza empedrada, fuente e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = { 206, 190, 166 }, mat = "Cobblestone" })
	b:cylinder({ name = "Albero", length = 0.1, diameter = 30, pos = { 0, 0.05, 0 }, color = ALBERO, mat = "Sand", folder = "Decoracion" })
	P.fountain(b, { 0, 0, 0 }, 7)

	P.house(b, { 0, 0, 61 }, 0, { w = 26, h = 18, d = 18, color = WHITE, trim = { 214, 190, 150 }, roof = "gable", roofColor = TEJA, floors = 1, cols = 3, doorColor = { 100, 60, 36 } })
	P.bellTower(b, { 0, 0, 68 }, 0, 38, WHITE, TEJA)
	b:box({ name = "Portada", size = { 9, 12, 0.6 }, pos = { 0, 6, 51.9 }, color = { 214, 190, 150 }, mat = "Limestone" })
	b:box({ name = "Puerta", size = { 4.4, 7.6, 0.4 }, pos = { 0, 3.8, 51.5 }, color = { 100, 60, 36 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 4.4, pos = { 0, 7.6, 51.5 }, color = { 100, 60, 36 }, mat = "WoodPlanks", folder = "Decoracion" })
	P.poster(b, { 0, 14.4, 51.8 }, 0, { 13, 1.8 }, { 40, 80, 170 }, "IGLESIA DE SANTA ANA", WHITE, "Garamond")

	b:symmetric(function(b)
		-- Casas encaladas con balcones y flores
		P.houseRow(b, 57, 0, -84, -13, CASAS, 10)
		P.houseRow(b, -57, 180, -84, 0, CASAS, 10)

		-- Naranjos en alcorques
		for _, t in ipairs({ { -22, -20 }, { -24, 22 }, { -52, -28 }, { -50, 34 } }) do
			b:box({ name = "Alcorque", size = { 5, 0.8, 5 }, pos = { t[1], 0.4, t[2] }, color = { 170, 150, 120 }, mat = "Limestone" })
			P.tree(b, { t[1], 0.4, t[2] }, 0.85, NARANJO)
			for k = 0, 5 do
				local a = k * 1.05
				b:ball({ name = "Naranja", diameter = 0.8, pos = { t[1] + math.cos(a) * 3.2, 9.6 + (k % 2) * 1.4, t[2] + math.sin(a) * 3.2 }, color = { 250, 140, 30 }, folder = "Decoracion" })
			end
		end

		-- Terrazas del bar
		for _, t in ipairs({ { -66, -43 }, { -56, -41 }, { -38, 42 }, { -48, 40 } }) do
			P.umbrellaTable(b, { t[1], 0, t[2] }, { 200, 40, 40 })
		end

		-- Soportales con columnas
		for _, x in ipairs({ -44, -38, -32 }) do
			for _, z in ipairs({ -29.6, -35.2 }) do
				P.column(b, { x, 0, z }, 8, 1.4, WHITE, "Plaster")
			end
		end
		b:box({ name = "Soportal", size = { 14.4, 1.2, 7.2 }, pos = { -38, 10.8, -32.4 }, color = WHITE, mat = "Plaster" })
		b:box({ name = "Tejadillo", size = { 15.4, 0.8, 8.2 }, pos = { -38, 11.8, -32.4 }, color = TEJA, mat = "ClayRoofTiles" })

		-- Seiscientos aparcado, jardinera y barriles de vino
		P.car(b, { -44, 0, 8 }, 90, { 210, 40, 40 })
		P.planter(b, { -20, 0, 0 }, { 3, 10 }, 0)
		for _, p in ipairs({ { -70, -34 }, { -67.4, -35.2 }, { -69, -37.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 120, 70, 40 })
		end
		P.bench(b, { -12, 0, -10 }, 0, { 120, 80, 50 })
		P.bench(b, { -12, 0, 10 }, 180, { 120, 80, 50 })
		P.pottedPlant(b, { -30, 0, 44 }, 1.2)
		P.pottedPlant(b, { -26, 0, -44 }, 1.2)

		-- Muro encalado que protege el spawn, con macetas de geranios
		P.wall(b, { -60, 0, 0 }, 90, { 34, 10, 2 }, WHITE, { 196, 170, 130 }, TEJA, "Plaster")
		P.poster(b, { -58.9, 7, 0 }, -90, { 11, 2.6 }, { 40, 80, 170 }, "PLAZA MAYOR", WHITE, "Garamond")
		for _, z in ipairs({ -14, -10, 10, 14 }) do
			b:box({ name = "Maceta", size = { 0.8, 1, 1.2 }, pos = { -58.6, 5.6, z }, color = { 40, 90, 170 }, folder = "Decoracion" })
			b:ball({ name = "Geranio", diameter = 1.3, pos = { -58.6, 6.4, z }, color = { 220, 40, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 13.4,
			Brightness = 3.4,
			Ambient = { 130, 120, 110 },
			OutdoorAmbient = { 170, 160, 146 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.12,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.22, offset = 0.05, color = { 240, 226, 200 }, decay = { 170, 150, 130 }, glare = 0.4, haze = 1.2 },
		colorCorrection = { contrast = 0.1, saturation = 0.2, tint = { 255, 250, 240 } },
		clouds = { cover = 0.25, density = 0.35, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
