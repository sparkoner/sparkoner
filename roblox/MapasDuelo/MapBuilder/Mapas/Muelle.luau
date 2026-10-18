-- Muelle (estilo GTA V): muelle de madera sobre el mar al atardecer, con noria, tiovivo, puestos
-- y la ciudad al fondo. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local DECK = 8
	local WOOD = { 150, 116, 84 }
	local WHITE = { 244, 242, 236 }
	local PALMS = { { 260, 1.2 }, { 300, 1.4 } }

	b.model:SetAttribute("Nombre", "Muelle")

	-- =================================================================
	--  Mar, playa, ciudad y colina con letrero
	-- =================================================================
	b:box({ name = "Mar", size = { 1600, 2, 1600 }, pos = { 0, 0, 0 }, color = { 40, 112, 150 }, mat = "Glass", reflectance = 0.25, folder = "Decoracion" })
	b:box({ name = "Playa", size = { 1600, 4, 300 }, pos = { 0, 0, 230 }, color = { 232, 212, 160 }, mat = "Sand", folder = "Decoracion" })
	for i = 0, 15 do
		local x = -300 + i * 40
		P.palmTree(b, { x, 2, 120 + (i % 2) * 18 }, PALMS[(i % 2) + 1][2])
	end
	for i = 0, 19 do
		local x = -380 + i * 40
		local h = 50 + (i * 53) % 120
		local w = 26 + (i % 3) * 8
		b:box({ name = "Edificio", size = { w, h, w }, pos = { x, 2 + h / 2, 300 + (i % 3) * 30 }, color = (i % 2 == 0) and { 220, 210, 196 } or { 120, 150, 176 }, mat = (i % 2 == 0) and "Concrete" or "Glass", folder = "Decoracion" })
	end
	b:ball({ name = "Colina", diameter = 360, pos = { -120, -40, 560 }, color = { 140, 140, 90 }, mat = "Grass", folder = "Decoracion" })
	b:ball({ name = "Colina", diameter = 320, pos = { 180, -50, 580 }, color = { 130, 132, 86 }, mat = "Grass", folder = "Decoracion" })
	for i, letter in ipairs({ "P", "L", "A", "Y", "A", " ", "D", "E", "L", " ", "S", "O", "L" }) do
		if letter ~= " " then
			local panel = b:box({ name = "Letra", size = { 9, 14, 1 }, pos = { -190 + i * 11, 118, 420 }, rot = { -12, 0, 0 }, color = WHITE, folder = "Decoracion" })
			MB.sign(panel, letter, { font = "GothamBlack", color = { 40, 40, 40 }, bg = WHITE })
		end
	end

	-- =================================================================
	--  Tablero del muelle, pilotes, barandillas y zona de feria
	-- =================================================================
	b:box({ name = "Tablero", size = { 152, 1, 62 }, pos = { 0, DECK - 0.5, 0 }, color = WOOD, mat = "WoodPlanks" })
	b:box({ name = "Feria", size = { 84, 1, 34 }, pos = { 0, DECK - 0.5, 47 }, color = WOOD, mat = "WoodPlanks", folder = "Decoracion" })
	b:box({ name = "Pasarela", size = { 24, 1, 120 }, pos = { 0, DECK - 0.5, 120 }, color = WOOD, mat = "WoodPlanks", folder = "Decoracion" })
	P.ferrisWheel(b, { 0, DECK, 38 }, 0, 24, { 255, 90, 170 })
	local arch = b:box({ name = "Arco", size = { 26, 4, 1 }, pos = { 0, DECK + 14, 62 }, color = { 30, 30, 40 }, folder = "Decoracion" })
	MB.sign(arch, "MUELLE DEL SOL", { font = "LuckiestGuy", color = { 255, 120, 200 }, glow = true })
	for _, x in ipairs({ -12, 12 }) do
		b:box({ name = "Poste", size = { 1, 14, 1 }, pos = { x, DECK + 7, 62 }, color = { 30, 30, 40 }, folder = "Decoracion" })
	end

	-- Tiovivo en el centro
	b:cylinder({ name = "Plataforma", length = 1.2, diameter = 18, pos = { 0, DECK + 0.6, 0 }, color = { 240, 232, 220 }, mat = "WoodPlanks" })
	b:cylinder({ name = "Columna", length = 10, diameter = 3, pos = { 0, DECK + 6, 0 }, color = { 230, 190, 80 }, mat = "Metal" })
	for i, d in ipairs({ 21, 17, 12, 7, 2.6 }) do
		b:cylinder({ name = "Toldo", length = 1, diameter = d, pos = { 0, DECK + 10.6 + i, 0 }, color = (i % 2 == 1) and { 220, 50, 60 } or WHITE, mat = "Fabric" })
	end
	local crown = b:ball({ name = "Remate", diameter = 1.6, pos = { 0, DECK + 16.6, 0 }, color = { 250, 210, 80 }, mat = "Neon", folder = "Decoracion" })
	MB.light(crown, "Point", { color = { 255, 210, 140 }, brightness = 1.4, range = 24 })
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local x, z = math.cos(a) * 6.5, math.sin(a) * 6.5
		b:cylinder({ name = "Barra", length = 10, diameter = 0.35, pos = { x, DECK + 6.2, z }, color = { 230, 190, 80 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Caballo", size = { 1.2, 2.2, 3.6 }, pos = { x, DECK + 3.4, z }, rot = { 0, -i * 45 - 22.5, 0 }, color = ({ { 250, 250, 246 }, { 120, 80, 50 }, { 60, 60, 66 }, { 220, 170, 90 } })[(i % 4) + 1] })
	end

	b:symmetric(function(b)
		-- Pilotes y barandillas
		for x = -72, -6, 11 do
			for _, z in ipairs({ -30, 30 }) do
				b:cylinder({ name = "Pilote", length = 10, diameter = 1.6, pos = { x, 2.5, z }, color = { 96, 76, 58 }, mat = "Wood", folder = "Decoracion" })
			end
		end
		P.railing(b, { -76, DECK, -30.4 }, { 0, DECK, -30.4 }, 3.5, WHITE)
		P.railing(b, { -76, DECK, 30.4 }, { -42, DECK, 30.4 }, 3.5, WHITE)
		for x = -60, -10, 25 do
			b:cylinder({ name = "Salvavidas", axis = "z", length = 0.5, diameter = 2.4, pos = { x, DECK + 2.2, -30.8 }, color = { 240, 100, 40 }, folder = "Decoracion" })
		end

		-- Bar del muelle que protege el spawn
		P.house(b, { -60, DECK, 0 }, -90, { w = 30, h = 12, d = 10, color = { 60, 140, 160 }, trim = WHITE, floors = 1, cols = 4, shop = "BAR DEL MUELLE", shopColor = { 230, 70, 120 }, lit = true })
		P.neonSign(b, { -54.6, DECK + 15, 0 }, -90, { 14, 3 }, "COCTELES", { 120, 255, 230 }, "LuckiestGuy")

		-- Puestos, carrito, mesas y bancos mirando al mar
		P.marketStall(b, { -36, DECK, -20 }, 180, { 230, 70, 120 }, "HOT DOGS", { { 200, 120, 60 }, { 240, 200, 80 }, { 200, 60, 50 } })
		P.marketStall(b, { -22, DECK, 20 }, 0, { 60, 150, 220 }, "HELADOS", { { 250, 200, 220 }, { 240, 240, 230 }, { 140, 90, 60 } })
		P.hotdogCart(b, { -44, DECK, 14 }, 90)
		P.umbrellaTable(b, { -30, DECK, -6 }, { 230, 70, 120 })
		P.umbrellaTable(b, { -46, DECK, -10 }, { 60, 150, 220 })
		for _, x in ipairs({ -66, -24 }) do
			P.bench(b, { x, DECK, -27 }, 180, { 120, 90, 60 })
		end
		local truck = P.truck(b, { -18, DECK, -14 }, 90, { 250, 200, 70 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(truck, "TACOS · FOOD TRUCK", { face = face, font = "LuckiestGuy", color = { 200, 50, 60 }, height = 0.35 })
		end
		P.crate(b, { -50, DECK, 22 }, 4.5, 10)
		P.crate(b, { -54, DECK, 25 }, 3.5, -15)
		P.mannequin(b, { -40, DECK, -28.6 }, 180, { 80, 120, 200 })
		P.segment(b, { -40, DECK + 4.6, -29 }, { -40, DECK + 8, -36 }, 0.15, { 60, 50, 40 }, "Wood", "Decoracion")

		-- Farolas
		for _, x in ipairs({ -64, -34, -8 }) do
			P.streetLight(b, { x, DECK, 28.6 }, 0, 14)
		end
		P.streetLight(b, { -50, DECK, -28.6 }, 180, 14)

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, DECK + 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -30, 30, 60)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 17.9,
			Brightness = 2.4,
			Ambient = { 120, 92, 96 },
			OutdoorAmbient = { 160, 120, 120 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.7,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 255, 176, 140 }, decay = { 170, 96, 110 }, glare = 1.6, haze = 2 },
		colorCorrection = { contrast = 0.1, saturation = 0.22, tint = { 255, 236, 226 } },
		clouds = { cover = 0.5, density = 0.5, color = { 255, 150, 130 } },
		bloom = { intensity = 0.55, size = 28, threshold = 0.86 },
		sunRays = { intensity = 0.14, spread = 0.7 },
	})
end
