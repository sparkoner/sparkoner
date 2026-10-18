-- Japón: calle de Kioto al anochecer con torii, santuario y cerezos. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local STONE = { 128, 124, 118 }
	local PATH = { 178, 170, 154 }
	local WOOD = { 92, 58, 40 }
	local DARK = { 40, 36, 34 }
	local RED = { 196, 48, 38 }
	local PLASTER = { 236, 226, 206 }
	local TILE = { 58, 60, 68 }
	local SAKURA = {
		{ { 255, 183, 197 }, { 246, 160, 184 }, { 255, 208, 218 } },
		{ { 250, 170, 190 }, { 255, 196, 208 }, { 236, 150, 176 } },
	}
	local MACHIYA = {
		{ w = 14, h = 13, color = WOOD, mat = "WoodPlanks", trim = DARK, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "ラーメン RAMEN", shopColor = { 176, 40, 34 } },
		{ w = 12, h = 12, color = PLASTER, trim = WOOD, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shutters = DARK },
		{ w = 14, h = 14, color = { 112, 72, 48 }, mat = "WoodPlanks", trim = DARK, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "寿司 SUSHI", shopColor = { 36, 66, 128 } },
		{ w = 12, h = 12, color = { 226, 212, 186 }, trim = WOOD, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "お茶 TEA", shopColor = { 66, 108, 58 } },
	}

	b.model:SetAttribute("Nombre", "Japón")

	-- Cuerda con farolillos de papel entre dos puntos
	local function lanternLine(a, c, count, sag)
		local prev
		for i = 0, count do
			local t = i / count
			local p = { a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t - sag * 4 * t * (1 - t), a[3] + (c[3] - a[3]) * t }
			if prev then
				P.segment(b, prev, p, 0.1, { 30, 28, 26 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				P.lantern(b, { p[1], p[2] - 1.1, p[3] }, (i % 2 == 0) and { 236, 70, 44 } or { 250, 220, 160 }, i % 4 == 2)
			end
			prev = p
		end
	end

	-- =================================================================
	--  Paisaje: césped, monte Fuji y colinas
	-- =================================================================
	b:box({ name = "Cesped", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 86, 112, 70 }, mat = "Grass", folder = "Decoracion" })
	for i = 0, 11 do
		b:cylinder({ name = "Fuji", length = 20, diameter = 640 - i * 50, pos = { 0, 8 + i * 20, 560 }, color = (i >= 9) and { 244, 246, 252 } or { 88, 100, 128 }, mat = (i >= 9) and "Snow" or "Rock", folder = "Decoracion" })
	end
	for _, h in ipairs({ { -170, 0, 150 }, { 170, 0, 150 }, { -150, -150, 160 }, { 150, -150, 160 }, { 0, -190, 170 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.3, h[2] }, color = { 70, 104, 66 }, mat = "Grass", folder = "Decoracion" })
	end

	-- =================================================================
	--  Calle empedrada, torii y santuario
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = STONE, mat = "Slate" })
	b:box({ name = "Camino", size = { 164, 0.1, 16 }, pos = { 0, 0.05, 0 }, color = PATH, mat = "Pavement", folder = "Decoracion" })
	P.torii(b, { 0, 0, 0 }, 0, 14, 16)

	b:box({ name = "Plataforma", size = { 34, 2, 20 }, pos = { 0, 1, 42 }, color = { 150, 146, 138 }, mat = "Slate" })
	P.stairs(b, { 0, 0, 30 }, 0, 2, 1, 1, 12, { 150, 146, 138 }, { 110, 106, 100 })
	P.house(b, { 0, 2, 45 }, 0, { w = 26, h = 10, d = 14, color = PLASTER, trim = WOOD, roof = "pagoda", roofColor = TILE, roofMat = "Slate", roofHeight = 5, cols = 5, floors = 1, doorColor = RED, lit = true })
	b:box({ name = "Cumbrera", size = { 30, 1, 1 }, pos = { 0, 17.4, 45 }, color = DARK, folder = "Decoracion" })
	b:box({ name = "Ofrendas", size = { 6, 2.4, 3 }, pos = { 0, 3.2, 35.6 }, color = WOOD, mat = "WoodPlanks" })
	b:cylinder({ name = "Shimenawa", axis = "x", length = 16, diameter = 0.9, pos = { 0, 11.2, 37.4 }, color = { 214, 190, 130 }, mat = "Fabric", folder = "Decoracion" })
	local banner = b:box({ name = "Placa", size = { 8, 2, 0.3 }, pos = { 0, 9.6, 37.6 }, color = DARK, folder = "Decoracion" })
	MB.sign(banner, "稲荷神社", { face = "Front", color = { 240, 200, 90 } })

	b:symmetric(function(b)
		-- Casas tradicionales (machiya) a los dos lados de la calle
		P.houseRow(b, 57, 0, -84, -18, MACHIYA, 10)
		P.houseRow(b, -57, 180, -84, 0, MACHIYA, 10)
		for x = -74, -6, 8 do
			P.lantern(b, { x, 10.6, -50.6 }, { 230, 60, 40 }, (x + 74) % 24 == 0)
		end
		lanternLine({ -40, 15, 51.5 }, { -40, 15, -51.5 }, 12, 3)

		-- Farolillos de piedra y cerezos junto al torii
		P.stoneLantern(b, { -10, 0, 12 })
		P.stoneLantern(b, { -10, 0, -12 })
		P.stoneLantern(b, { -12, 2, 40 })
		for i, t in ipairs({ { -28, 28, 1.3 }, { -56, -34, 1.4 }, { -22, -38, 1.2 }, { -66, 34, 1.3 } }) do
			P.tree(b, { t[1], 0, t[2] }, t[3], SAKURA[(i % 2) + 1])
		end
		for i = 1, 14 do
			b:box({ name = "Petalos", size = { 0.6, 0.06, 0.5 }, pos = { -8 - (i * 37) % 64, 0.13, -40 + (i * 23) % 78 }, rot = { 0, i * 33, 0 }, color = { 255, 196, 210 }, folder = "Decoracion", shadow = false })
		end

		-- Puesto de ramen (yatai) y cajas
		P.marketStall(b, { -28, 0, -20 }, 180, { 176, 40, 34 }, "ラーメン", { { 250, 236, 200 }, { 230, 180, 90 }, { 120, 170, 90 } })
		P.lantern(b, { -32, 7.2, -22.6 }, { 236, 70, 44 }, true)
		P.crate(b, { -15, 0, 17 }, 5, 10, { 170, 128, 84 })
		P.crate(b, { -18, 0, 23 }, 4, -8, { 170, 128, 84 })
		P.crate(b, { -15, 5, 17 }, 3.4, 30, { 170, 128, 84 })

		-- Furgoneta kei aparcada
		P.car(b, { -44, 0, 18 }, 90, { 236, 236, 228 })

		-- Barriles de sake apilados
		for _, p in ipairs({ { -58, 1.6, -28 }, { -54.6, 1.6, -28 }, { -56.3, 4.6, -28 } }) do
			b:cylinder({ name = "Sake", axis = "z", length = 3.6, diameter = 3.2, pos = p, color = { 236, 228, 210 }, mat = "WoodPlanks" })
			b:cylinder({ name = "Etiqueta", axis = "z", length = 3.7, diameter = 2, pos = p, color = { 196, 48, 38 }, folder = "Decoracion" })
		end

		-- Muretes de jardín con tejas
		for _, w in ipairs({ { -46, -14, 12 }, { -30, 10, 10 } }) do
			b:box({ name = "Murete", size = { w[3], 4, 1.6 }, pos = { w[1], 2, w[2] }, color = PLASTER, mat = "Plaster" })
			b:box({ name = "Teja", size = { w[3] + 0.8, 0.6, 2.4 }, pos = { w[1], 4.3, w[2] }, color = TILE, mat = "Slate" })
			b:box({ name = "Zocalo", size = { w[3] + 0.1, 1, 1.8 }, pos = { w[1], 0.5, w[2] }, color = { 110, 106, 100 }, mat = "Slate", folder = "Decoracion" })
		end

		-- Máquinas expendedoras
		P.vending(b, { -66, 0, -49.6 }, 180, { 40, 110, 200 }, "お茶 TEA")
		P.vending(b, { -61.6, 0, -49.6 }, 180, { 214, 56, 56 }, "COLA")

		-- Bambú
		for i = 0, 7 do
			local h = 16 + (i % 3) * 3
			b:cylinder({ name = "Bambu", length = h, diameter = 0.7, pos = { -52 - (i % 4) * 1.6, h / 2, 38 + math.floor(i / 4) * 1.8 + (i % 2) * 0.6 }, color = { 122, 164, 76 }, mat = "Wood" })
			b:ball({ name = "Hojas", diameter = 3.4, pos = { -52 - (i % 4) * 1.6, h, 38 + math.floor(i / 4) * 1.8 }, color = { 92, 140, 64 }, mat = "LeafyGrass", folder = "Decoracion" })
		end

		-- Muro de yeso con tejado que protege el spawn
		b:box({ name = "Muro", size = { 2, 10, 34 }, pos = { -60, 5, 0 }, color = PLASTER, mat = "Plaster" })
		b:box({ name = "Zocalo", size = { 2.4, 2.4, 34.4 }, pos = { -60, 1.2, 0 }, color = { 96, 92, 88 }, mat = "Slate" })
		b:wedge({ name = "Tejado", size = { 35, 1.8, 2.6 }, pos = { -61.3, 10.9, 0 }, rot = { 0, 90, 0 }, color = TILE, mat = "Slate" })
		b:wedge({ name = "Tejado", size = { 35, 1.8, 2.6 }, pos = { -58.7, 10.9, 0 }, rot = { 0, -90, 0 }, color = TILE, mat = "Slate" })
		P.poster(b, { -58.9, 7, 0 }, -90, { 10, 2.6 }, RED, "祭り MATSURI", { 255, 240, 220 }, "GothamBlack")
		for _, z in ipairs({ -12, 12 }) do
			P.lantern(b, { -58.4, 8.4, z }, { 236, 70, 44 }, true)
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 18.3,
			Brightness = 2.2,
			Ambient = { 96, 80, 104 },
			OutdoorAmbient = { 134, 112, 142 },
			ExposureCompensation = 0.2,
			ShadowSoftness = 0.3,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.28, offset = 0.15, color = { 236, 172, 190 }, decay = { 122, 92, 150 }, glare = 1, haze = 1.8 },
		colorCorrection = { contrast = 0.1, saturation = 0.15, tint = { 255, 240, 246 } },
		clouds = { cover = 0.55, density = 0.5, color = { 255, 186, 200 } },
		bloom = { intensity = 0.55, size = 26, threshold = 0.85 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
