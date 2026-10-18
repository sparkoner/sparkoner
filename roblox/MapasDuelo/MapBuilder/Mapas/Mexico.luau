-- México: plaza de pueblo con quiosco, iglesia, casas de colores y papel picado. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local PLAZA = { 182, 156, 128 }
	local ADOBE = { 210, 150, 104 }
	local IGLESIA = { 236, 214, 172 }
	local PICADO = { { 236, 64, 122 }, { 255, 196, 40 }, { 56, 190, 180 }, { 140, 80, 200 }, { 250, 120, 40 }, { 90, 190, 90 } }
	local CASAS = {
		{ w = 12, h = 11, color = { 236, 116, 160 }, trim = { 255, 236, 200 }, shop = "TACOS EL GÜERO", shopColor = { 200, 40, 60 }, shopFont = "LuckiestGuy" },
		{ w = 14, h = 13, color = { 250, 200, 70 }, trim = { 200, 80, 60 }, shutters = { 40, 120, 160 }, balcony = true, flowers = { 230, 60, 90 } },
		{ w = 12, h = 10, color = { 64, 186, 178 }, trim = { 255, 244, 220 }, shop = "PANADERÍA", shopColor = { 210, 120, 40 }, shopFont = "LuckiestGuy" },
		{ w = 13, h = 13, color = { 240, 132, 62 }, trim = { 255, 236, 200 }, shutters = { 30, 90, 150 }, balcony = true, flowers = { 250, 220, 80 } },
		{ w = 12, h = 11, color = { 128, 100, 204 }, trim = { 255, 236, 200 }, shop = "ABARROTES", shopColor = { 40, 140, 70 }, shopFont = "LuckiestGuy" },
	}

	b.model:SetAttribute("Nombre", "México")

	-- =================================================================
	--  Paisaje: desierto y mesetas rojizas
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 212, 178, 128 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -210, 230, 120, 34 }, { 160, 260, 160, 40 }, { 300, 110, 100, 28 }, { -320, 60, 110, 36 }, { 40, -260, 140, 30 }, { -230, -220, 100, 26 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 196, 104, 70 }, mat = "Sandstone", folder = "Decoracion" })
		b:box({ name = "Meseta", size = { m[3] * 0.7, 6, m[3] * 0.5 }, pos = { m[1], m[4] + 2, m[2] }, color = { 176, 98, 66 }, mat = "Sandstone", folder = "Decoracion" })
	end

	-- =================================================================
	--  Plaza, quiosco e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = PLAZA, mat = "Cobblestone" })
	b:cylinder({ name = "Glorieta", length = 0.1, diameter = 34, pos = { 0, 0.05, 0 }, color = { 206, 180, 146 }, mat = "Pavement", folder = "Decoracion" })
	P.kiosk(b, { 0, 0, 0 }, 9, { 46, 120, 84 }, { 200, 56, 46 })

	b:box({ name = "Iglesia", size = { 30, 20, 18 }, pos = { 0, 10, 61 }, color = IGLESIA, mat = "Plaster" })
	b:box({ name = "Zocalo", size = { 30.2, 1.6, 18.2 }, pos = { 0, 0.8, 61 }, color = { 176, 140, 104 }, mat = "Sandstone" })
	b:box({ name = "Portada", size = { 12, 16, 1 }, pos = { 0, 8, 51.6 }, color = { 214, 186, 140 }, mat = "Sandstone" })
	b:box({ name = "Puerta", size = { 5, 8, 0.4 }, pos = { 0, 4, 51 }, color = { 110, 66, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 5, pos = { 0, 8, 51 }, color = { 110, 66, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Roseton", axis = "z", length = 0.4, diameter = 3.6, pos = { 0, 13.4, 51 }, color = { 80, 150, 210 }, mat = "Glass", folder = "Decoracion" })
	b:box({ name = "Espadana", size = { 12, 6, 1.6 }, pos = { 0, 23, 52.6 }, color = IGLESIA, mat = "Plaster" })
	b:box({ name = "Hueco", size = { 3, 3.4, 1.7 }, pos = { 0, 23, 52.6 }, color = { 40, 30, 26 }, folder = "Decoracion" })
	b:ball({ name = "Campana", diameter = 2, pos = { 0, 22.8, 52.6 }, color = { 190, 150, 60 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 0.5, 3, 0.5 }, pos = { 0, 27.5, 52.6 }, color = { 80, 70, 60 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 1.8, 0.5, 0.5 }, pos = { 0, 28.2, 52.6 }, color = { 80, 70, 60 }, mat = "Metal", folder = "Decoracion" })
	local cartel = b:box({ name = "Cartel", size = { 10, 1.4, 0.3 }, pos = { 0, 17.2, 51 }, color = IGLESIA, folder = "Decoracion" })
	MB.sign(cartel, "PARROQUIA SAN JUAN", { font = "Garamond", color = { 120, 80, 50 } })

	b:symmetric(function(b)
		-- Casas de colores y campanarios
		P.houseRow(b, 57, 0, -84, -23, CASAS, 10)
		P.houseRow(b, -57, 180, -84, 0, CASAS, 10)
		P.bellTower(b, { -19, 0, 60 }, 0, 30, IGLESIA, { 200, 90, 56 })

		-- Papel picado desde el quiosco y cruzando la plaza
		P.bunting(b, { -5, 12.6, 3 }, { -46, 12, 51.6 }, 18, 1.4, PICADO)
		P.bunting(b, { -5, 12.6, -3 }, { -46, 12, -51.6 }, 18, 1.4, PICADO)
		P.bunting(b, { -28, 12, 51.6 }, { -28, 12, -51.6 }, 26, 2, PICADO)

		-- Piñata colgada
		P.segment(b, { -28, 10, 0 }, { -28, 9.6, 0 }, 0.08, { 40, 40, 40 }, "Plastic", "Decoracion")
		b:ball({ name = "Pinata", diameter = 2.4, pos = { -28, 8.4, 0 }, color = { 240, 80, 150 }, mat = "Fabric", folder = "Decoracion" })
		for i, d in ipairs({ { 1.7, 0, 0 }, { -1.7, 0, 0 }, { 0, 1.7, 0 }, { 0, -1.7, 0 }, { 0, 0, 1.7 }, { 0, 0, -1.7 } }) do
			P.rod(b, { -28, 8.4, 0 }, { -28 + d[1], 8.4 + d[2], d[3] }, 0.7, PICADO[i], "Fabric", "Decoracion")
		end

		-- Puestos del mercado
		P.marketStall(b, { -30, 0, -22 }, 180, { 220, 50, 90 }, "TACOS", { { 240, 200, 120 }, { 120, 170, 70 }, { 200, 60, 40 } })
		P.marketStall(b, { -36, 0, 26 }, 0, { 40, 150, 170 }, "ELOTES", { { 250, 210, 80 }, { 240, 190, 60 }, { 120, 170, 70 } })

		-- Vocho aparcado
		P.car(b, { -46, 0, 4 }, 90, { 70, 170, 200 })

		-- Muretes de adobe
		P.wall(b, { -16, 0, -15 }, 0, { 10, 4, 1.6 }, ADOBE, { 150, 100, 70 }, { 196, 90, 60 }, "Plaster")
		P.wall(b, { -18, 0, 16 }, 0, { 10, 4, 1.6 }, ADOBE, { 150, 100, 70 }, { 196, 90, 60 }, "Plaster")

		-- Barriles, nopales, macetas y árboles
		for _, p in ipairs({ { -52, -32 }, { -49.4, -33.4 }, { -51, -35.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 150, 96, 56 })
		end
		P.cactus(b, { -60, 0, -44 }, 1.1)
		P.cactus(b, { -22, 0, 42 }, 0.9)
		P.cactus(b, { -68, 0, 36 }, 1.2)
		P.pottedPlant(b, { -40, 0, -42 }, 1.3)
		P.pottedPlant(b, { -12, 0, 30 }, 1.3)
		P.palmTree(b, { -40, 0, 44 }, 1)
		P.tree(b, { -58, 0, 22 }, 1.2, { { 150, 110, 210 }, { 170, 130, 225 }, { 130, 96, 190 } })
		P.bench(b, { -14, 0, -8 }, 0, { 46, 120, 84 })
		P.bench(b, { -14, 0, 8 }, 180, { 46, 120, 84 })

		-- Muro de adobe que protege el spawn
		P.wall(b, { -60, 0, 0 }, 90, { 34, 10, 2 }, { 200, 118, 80 }, { 150, 86, 60 }, IGLESIA, "Plaster")
		P.poster(b, { -58.9, 7, 0 }, -90, { 12, 2.6 }, IGLESIA, "¡BIENVENIDOS!", { 200, 50, 70 }, "LuckiestGuy")
		P.bunting(b, { -58.8, 9.6, -16 }, { -58.8, 9.6, 16 }, 14, 1.2, PICADO)
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 15.6,
			Brightness = 3.2,
			Ambient = { 124, 104, 92 },
			OutdoorAmbient = { 168, 140, 118 },
			ExposureCompensation = 0.05,
			ShadowSoftness = 0.15,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.26, offset = 0.05, color = { 240, 210, 170 }, decay = { 170, 120, 90 }, glare = 0.6, haze = 1.4 },
		colorCorrection = { contrast = 0.08, saturation = 0.25, tint = { 255, 246, 232 } },
		clouds = { cover = 0.35, density = 0.4, color = { 255, 250, 240 } },
		bloom = { intensity = 0.35, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
