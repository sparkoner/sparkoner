-- Rusia: aldea nevada con casas de troncos, iglesia de cúpulas y abetos. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SNOW = { 236, 240, 248 }
	local PATH = { 204, 208, 218 }
	local LOG = { 150, 104, 66 }
	local WHITE = { 244, 244, 240 }
	local BLUE = { 46, 92, 186 }
	local GOLD = { 226, 186, 72 }
	local IZBAS = {
		{ w = 13, h = 9, color = LOG, mat = "Wood", trim = WHITE, logs = true, roof = "gable", roofColor = SNOW, roofMat = "Snow", shutters = BLUE, floors = 1 },
		{ w = 12, h = 10, color = { 132, 92, 60 }, mat = "Wood", trim = { 220, 200, 120 }, logs = true, roof = "gable", roofColor = { 70, 120, 92 }, roofMat = "Metal", shutters = WHITE, floors = 1, shop = "ХЛЕБ", shopColor = { 170, 50, 40 } },
		{ w = 14, h = 9, color = { 160, 112, 72 }, mat = "Wood", trim = WHITE, logs = true, roof = "gable", roofColor = SNOW, roofMat = "Snow", shutters = { 60, 140, 110 }, floors = 1 },
		{ w = 12, h = 10, color = { 140, 98, 64 }, mat = "Wood", trim = { 230, 230, 240 }, logs = true, roof = "gable", roofColor = { 150, 56, 48 }, roofMat = "Metal", shutters = BLUE, floors = 1, shop = "ЧАЙ", shopColor = { 40, 90, 160 } },
	}

	b.model:SetAttribute("Nombre", "Rusia")

	-- =================================================================
	--  Paisaje nevado con bosque de abetos
	-- =================================================================
	b:box({ name = "Nieve", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = SNOW, mat = "Snow", folder = "Decoracion" })
	for _, h in ipairs({ { -180, 160, 180 }, { 180, 160, 180 }, { 0, 230, 200 }, { -170, -160, 170 }, { 170, -160, 170 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.3, h[2] }, color = { 230, 236, 246 }, mat = "Snow", folder = "Decoracion" })
	end
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2 + 0.17
		local r = 112 + (i % 3) * 16
		P.pineTree(b, { math.cos(a) * r * 1.25, 0, math.sin(a) * r }, 1.6 + (i % 4) * 0.25, true)
	end

	-- =================================================================
	--  Plaza nevada, abeto de Año Nuevo e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = SNOW, mat = "Snow" })
	b:box({ name = "Camino", size = { 164, 0.1, 14 }, pos = { 0, 0.05, 0 }, color = PATH, mat = "Snow", folder = "Decoracion" })

	P.pineTree(b, { 0, 0, 0 }, 1.5, true)
	local tiers = { { 6, 13.5 }, { 9.9, 11.1 }, { 13.5, 8.7 }, { 16.8, 6 } }
	local balls = { { 220, 40, 40 }, { 240, 200, 60 }, { 60, 120, 230 }, { 230, 230, 240 } }
	for k, t in ipairs(tiers) do
		for i = 0, 3 do
			local a = math.rad(i * 90 + k * 30)
			local r = t[2] / 2 - 0.2
			b:ball({ name = "Bola", diameter = 1, pos = { math.cos(a) * r, t[1] - 0.6, math.sin(a) * r }, color = balls[((i + k) % 4) + 1], mat = (i % 2 == 0) and "Neon" or "Metal", folder = "Decoracion" })
		end
	end
	local star = b:ball({ name = "Estrella", diameter = 1.8, pos = { 0, 23, 0 }, color = { 255, 60, 60 }, mat = "Neon", folder = "Decoracion" })
	MB.light(star, "Point", { color = { 255, 120, 100 }, brightness = 2, range = 18 })
	for _, f in ipairs({ { { -9, 0, -5 }, { -9, 0, 5 } }, { { 9, 0, -5 }, { 9, 0, 5 } }, { { -5, 0, -9 }, { 5, 0, -9 } }, { { -5, 0, 9 }, { 5, 0, 9 } } }) do
		P.woodFence(b, f[1], f[2], 3, { 120, 86, 56 })
	end

	b:box({ name = "Iglesia", size = { 22, 16, 18 }, pos = { 0, 8, 62 }, color = WHITE, mat = "Plaster" })
	b:box({ name = "Zocalo", size = { 22.4, 1.6, 18.4 }, pos = { 0, 0.8, 62 }, color = { 200, 196, 186 }, mat = "Concrete" })
	b:box({ name = "Cornisa", size = { 23, 1, 19 }, pos = { 0, 16.5, 62 }, color = BLUE, mat = "Metal" })
	b:box({ name = "Portico", size = { 8, 10, 3 }, pos = { 0, 5, 51.8 }, color = WHITE, mat = "Plaster" })
	b:box({ name = "Tejadillo", size = { 9, 0.8, 4 }, pos = { 0, 10.4, 51.8 }, color = BLUE, mat = "Metal" })
	b:box({ name = "Puerta", size = { 4, 6.5, 0.4 }, pos = { 0, 3.25, 50.2 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 4, pos = { 0, 6.5, 50.2 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:box({ name = "Icono", size = { 3, 3.6, 0.3 }, pos = { 0, 12.8, 52.9 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Icono", size = { 2.2, 2.8, 0.35 }, pos = { 0, 12.8, 52.9 }, color = BLUE, folder = "Decoracion" })
	P.onionDome(b, { 0, 17, 62 }, 9, BLUE)

	-- Nevada
	P.snowfall(b, { 0, 60, 0 }, { 170, 120 }, 150)

	b:symmetric(function(b)
		-- Casas de troncos (izbas)
		P.houseRow(b, 57, 0, -84, -12, IZBAS, 10)
		P.houseRow(b, -57, 180, -84, 0, IZBAS, 10)

		-- Cúpulas doradas de la iglesia y ventanas
		P.onionDome(b, { -8, 17, 56 }, 4.4, GOLD)
		P.onionDome(b, { -8, 17, 68 }, 4.4, GOLD)
		for _, x in ipairs({ -8, -4.4 }) do
			b:box({ name = "Ventana", size = { 1.6, 4, 0.3 }, pos = { x, 9, 52.9 }, color = { 255, 214, 140 }, mat = "Neon", transparency = 0.3, folder = "Decoracion" })
		end

		-- Leña, montones de nieve y muñeco de nieve
		P.logPile(b, { -30, 0, -18 }, 0, 10)
		P.logPile(b, { -52, 0, 22 }, 90, 8)
		P.snowPile(b, { -20, 0, 14 }, 1.2)
		P.snowPile(b, { -42, 0, -34 }, 1.4)
		P.snowman(b, { -16, 0, -24 })

		-- Lada aparcado con nieve encima
		P.car(b, { -44, 0, 0 }, 80, { 196, 60, 50 })
		local lada = b:at({ -44, 0, 0 }, 80)
		lada:box({ name = "Nieve", size = { 4.8, 0.6, 3.4 }, pos = { 0, 5.55, 1.3 }, color = SNOW, mat = "Snow", folder = "Decoracion" })
		lada:box({ name = "Nieve", size = { 5, 0.4, 3.2 }, pos = { 0, 3.2, -3.7 }, color = SNOW, mat = "Snow", folder = "Decoracion" })

		-- Puestos del mercado
		P.marketStall(b, { -30, 0, 26 }, 0, { 180, 40, 40 }, "ЧАЙ", { { 200, 160, 90 }, { 230, 200, 140 }, { 160, 60, 40 } })
		P.marketStall(b, { -28, 0, -36 }, 180, { 40, 90, 170 }, "БЛИНЫ", { { 240, 200, 120 }, { 200, 60, 60 }, { 250, 240, 220 } })

		-- Abetos, valla y farolas
		P.pineTree(b, { -62, 0, -42 }, 1.2, true)
		P.pineTree(b, { -18, 0, 40 }, 1, true)
		P.pineTree(b, { -70, 0, 42 }, 1.3, true)
		P.woodFence(b, { -78, 0, 30 }, { -62, 0, 30 }, 4, { 120, 86, 56 })
		P.streetLight(b, { -20, 0, 10 }, 0, 16)
		P.streetLight(b, { -50, 0, -10 }, 180, 16)

		-- Empalizada que protege el spawn
		for i = 0, 28 do
			local z = -16.8 + i * 1.2
			local h = 10 + (i % 3) * 0.5
			b:cylinder({ name = "Empalizada", length = h, diameter = 1.25, pos = { -60, h / 2, z }, color = (i % 2 == 0) and { 126, 90, 58 } or { 112, 80, 52 }, mat = "Wood" })
			b:cylinder({ name = "Punta", length = 1, diameter = 0.7, pos = { -60, h + 0.5, z }, color = { 112, 80, 52 }, mat = "Wood", folder = "Decoracion" })
			b:ball({ name = "Nieve", diameter = 1.1, pos = { -60, h, z }, color = SNOW, mat = "Snow", folder = "Decoracion" })
		end
		for _, y in ipairs({ 3, 8 }) do
			b:box({ name = "Travesano", size = { 0.6, 0.8, 34 }, pos = { -59.3, y, 0 }, color = { 100, 72, 48 }, mat = "Wood", folder = "Decoracion" })
		end
		P.poster(b, { -58.9, 5.5, 0 }, -90, { 11, 2.2 }, { 170, 40, 40 }, "ДОБРО ПОЖАЛОВАТЬ", WHITE, "GothamBlack")
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 14,
			Brightness = 1.7,
			Ambient = { 120, 128, 146 },
			OutdoorAmbient = { 160, 170, 190 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.6,
			EnvironmentDiffuseScale = 0.7,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.42, offset = 0.2, color = { 214, 224, 240 }, decay = { 160, 172, 196 }, glare = 0, haze = 2.6 },
		colorCorrection = { contrast = 0.06, saturation = -0.05, tint = { 236, 244, 255 } },
		clouds = { cover = 0.88, density = 0.7, color = { 226, 230, 238 } },
		bloom = { intensity = 0.4, size = 24, threshold = 0.9 },
		sunRays = { intensity = 0.03, spread = 0.4 },
	})
end
