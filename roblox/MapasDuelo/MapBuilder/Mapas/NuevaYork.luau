-- Nueva York: avenida al anochecer con edificios de ladrillo, taxis amarillos y metro. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ROAD = { 62, 62, 66 }
	local LINE = { 236, 232, 220 }
	local YELLOW = { 246, 196, 40 }
	local CREAM = { 230, 224, 210 }
	local LADRILLO = { { 150, 70, 56 }, { 122, 64, 52 }, { 176, 112, 82 }, { 104, 96, 92 }, { 160, 86, 64 } }
	-- x, ancho, alto, color, tienda norte, tienda sur
	local EDIFICIOS = {
		{ -76, 16, 34, 1, { "PIZZA", { 200, 40, 40 } }, { "LAUNDRY", { 60, 120, 200 } } },
		{ -61, 14, 40, 2, nil, { "NAILS", { 220, 80, 150 } } },
		{ -45, 18, 30, 3, { "DELI 24H", { 40, 120, 70 } }, nil },
		{ -29, 14, 38, 4, nil, { "COFFEE", { 120, 76, 46 } } },
		{ -11, 22, 32, 5, { "BODEGA", { 230, 160, 30 } }, { "BAGELS", { 200, 60, 40 } } },
	}

	b.model:SetAttribute("Nombre", "Nueva York")

	-- =================================================================
	--  Fondo: rascacielos y Empire State
	-- =================================================================
	b:box({ name = "Ciudad", size = { 1000, 1, 1000 }, pos = { 0, -1.2, 0 }, color = { 70, 72, 78 }, mat = "Concrete", folder = "Decoracion" })
	for i = 0, 13 do
		for _, side in ipairs({ 1, -1 }) do
			local w = 24 + (i % 4) * 5
			local h = 70 + (i * 37 + (side > 0 and 0 or 19)) % 80
			local x = -200 + i * 31
			local z = side * (100 + ((i + (side > 0 and 0 or 1)) % 3) * 22)
			local glass = (i % 3 == 0)
			b:box({ name = "Rascacielos", size = { w, h, w }, pos = { x, h / 2, z }, color = glass and { 96, 116, 146 } or { 120, 116, 112 }, mat = glass and "Glass" or "Concrete", reflectance = glass and 0.15 or nil, folder = "Decoracion" })
			b:box({ name = "Remate", size = { w * 0.7, 6, w * 0.7 }, pos = { x, h + 3, z }, color = { 90, 92, 100 }, mat = "Concrete", folder = "Decoracion" })
			for k = 1, 3 do
				b:box({ name = "Planta", size = { w + 0.2, 1.2, w + 0.2 }, pos = { x, h * k / 4, z }, color = { 64, 72, 92 }, folder = "Decoracion", shadow = false })
			end
		end
	end
	local EMPIRE = { 176, 172, 160 }
	for _, s in ipairs({ { 50, 140, 70 }, { 36, 40, 160 }, { 26, 30, 195 }, { 16, 20, 220 } }) do
		b:box({ name = "EmpireState", size = { s[1], s[2], s[1] }, pos = { 40, s[3], 260 }, color = EMPIRE, mat = "Limestone", folder = "Decoracion" })
	end
	b:cylinder({ name = "Aguja", length = 34, diameter = 3, pos = { 40, 247, 260 }, color = { 200, 200, 210 }, mat = "Metal", folder = "Decoracion" })
	local beacon = b:ball({ name = "Baliza", diameter = 3, pos = { 40, 265, 260 }, color = { 255, 80, 80 }, mat = "Neon", folder = "Decoracion" })
	MB.light(beacon, "Point", { color = { 255, 80, 80 }, brightness = 3, range = 30 })

	-- =================================================================
	--  Avenida, aceras y obras en el centro
	-- =================================================================
	b:box({ name = "Asfalto", size = { 164, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROAD, mat = "Asphalt" })
	for _, z in ipairs({ -0.4, 0.4 }) do
		b:box({ name = "Linea", size = { 164, 0.12, 0.35 }, pos = { 0, 0.06, z }, color = YELLOW, folder = "Decoracion" })
	end
	P.sidewalk(b, { 0, 0, 35 }, { 164, 10 })
	P.sidewalk(b, { 0, 0, -35 }, { 164, 10 }, 180)
	for _, p in ipairs({ { 0, -7, 0 }, { 0, 7, 0 }, { -7, 0, 90 }, { 7, 0, 90 } }) do
		P.barrier(b, { p[1], 0, p[2] }, p[3])
	end
	for i = 0, 7 do
		b:cylinder({ name = "Chimenea", length = 1, diameter = 2.6, pos = { 0, 0.5 + i, 0 }, color = (i % 2 == 0) and { 240, 110, 30 } or { 245, 245, 240 } })
	end
	for _, s in ipairs({ { 0, 9.6, 0, 3 }, { 0.6, 11.8, 0.3, 4 }, { -0.4, 14.4, -0.2, 5.2 } }) do
		b:ball({ name = "Vapor", diameter = s[4], pos = { s[1], s[2], s[3] }, color = { 236, 236, 240 }, transparency = 0.45, folder = "Decoracion", shadow = false })
	end

	b:symmetric(function(b)
		-- Edificios de ladrillo con escaleras de incendios y tiendas
		for i, e in ipairs(EDIFICIOS) do
			for _, side in ipairs({ 1, -1 }) do
				local shop = (side > 0) and e[5] or e[6]
				P.house(b, { e[1], 0, side * 47 }, side > 0 and 0 or 180, {
					w = e[2], h = e[3], d = 14, color = LADRILLO[side > 0 and e[4] or (e[4] % 5) + 1], mat = "Brick", trim = CREAM,
					floors = math.floor(e[3] / 6.5), fireEscape = true, lit = true, shop = shop and shop[1], shopColor = shop and shop[2],
				})
			end
			if i == 2 or i == 4 then
				P.waterTank(b, { e[1], e[3] + 0.8, 49 })
				P.acUnit(b, { e[1] - 3, e[3] + 0.8, -50 }, 0)
			end
		end

		-- Líneas de carril y paso de cebra
		for x = -74, -6, 12 do
			for _, z in ipairs({ -15, 15 }) do
				b:box({ name = "Linea", size = { 6, 0.12, 0.4 }, pos = { x, 0.06, z }, color = LINE, folder = "Decoracion" })
			end
		end
		for z = -28, 28, 2.4 do
			b:box({ name = "Cebra", size = { 6, 0.12, 1.2 }, pos = { -34, 0.08, z }, color = LINE, folder = "Decoracion" })
		end

		-- Mobiliario urbano
		P.streetLight(b, { -50, 0.6, 31.4 }, 0, 18)
		P.streetLight(b, { -18, 0.6, -31.4 }, 180, 18)
		P.trafficLight(b, { -38, 0.6, 31 }, 0)
		P.trafficLight(b, { -30, 0.6, -31 }, 180)
		P.hydrant(b, { -44, 0.6, 32 })
		P.hydrant(b, { -24, 0.6, -32 })
		P.newspaperBox(b, { -22, 0.6, 32 }, 0, { 40, 90, 170 })
		P.newspaperBox(b, { -19.6, 0.6, 32 }, 0, { 200, 40, 40 })
		P.trashCan(b, { -64, 0.6, -32 }, { 60, 66, 60 })
		P.trashCan(b, { -8, 0.6, 33 }, { 60, 66, 60 })
		P.hotdogCart(b, { -12, 0.6, -34 }, 180)
		P.subwayEntrance(b, { -56, 0.6, 35 }, 90)
		P.manhole(b, { -48, 0, -8 })
		P.manhole(b, { -16, 0, 14 })

		-- Taxis y camión de reparto
		P.taxi(b, { -22, 0, -6 }, 90)
		P.taxi(b, { -46, 0, 14 }, 80)
		local truck = P.truck(b, { -40, 0, -21 }, 90, { 240, 240, 236 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(truck, "NYC DELIVERY", { face = face, font = "GothamBlack", color = { 40, 90, 170 }, height = 0.4 })
		end
		for _, x in ipairs({ -54, -26 }) do
			P.cone(b, { x, 0, -26 })
		end

		-- Valla de obra con carteles que protege el spawn
		b:box({ name = "Valla", size = { 1, 9, 34 }, pos = { -60, 4.5, 0 }, color = { 150, 116, 80 }, mat = "WoodPlanks" })
		for z = -16, 16, 4 do
			b:box({ name = "Poste", size = { 1.4, 9.4, 0.6 }, pos = { -60, 4.7, z }, color = { 110, 84, 58 }, mat = "Wood", folder = "Decoracion" })
		end
		P.poster(b, { -59.4, 5, -11 }, -90, { 6, 7 }, { 226, 60, 60 }, "ROCK\nNIGHT", { 255, 240, 200 }, "LuckiestGuy")
		P.poster(b, { -59.4, 6, -3.5 }, -90, { 6, 3 }, { 40, 40, 46 }, "POST NO BILLS", { 240, 240, 240 }, "GothamBlack")
		P.poster(b, { -59.4, 5, 4 }, -90, { 6, 7 }, { 60, 120, 220 }, "I LOVE\nNY", { 255, 255, 255 }, "GothamBlack")
		P.poster(b, { -59.4, 5.5, 11.5 }, -90, { 6, 6 }, YELLOW, "BROAD\nWAY", { 30, 30, 34 }, "LuckiestGuy")
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -40, 40, 50)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 18.7,
			Brightness = 1.8,
			Ambient = { 92, 96, 118 },
			OutdoorAmbient = { 120, 124, 150 },
			ExposureCompensation = 0.25,
			ShadowSoftness = 0.3,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 200, 180, 190 }, decay = { 110, 100, 130 }, glare = 0.8, haze = 2 },
		colorCorrection = { contrast = 0.12, saturation = 0.1, tint = { 246, 244, 255 } },
		clouds = { cover = 0.6, density = 0.5, color = { 230, 170, 160 } },
		bloom = { intensity = 0.55, size = 26, threshold = 0.85 },
		sunRays = { intensity = 0.06, spread = 0.5 },
	})
end
