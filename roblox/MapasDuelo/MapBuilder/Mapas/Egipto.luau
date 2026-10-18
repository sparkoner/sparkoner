-- Egipto: ruinas de un templo en el desierto con pirámides al fondo. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SAND = { 226, 196, 146 }
	local STONE = { 214, 186, 136 }
	local STONE_DARK = { 186, 156, 110 }
	local BLUE = { 40, 90, 160 }
	local GOLD = { 226, 182, 80 }
	local RED = { 170, 64, 44 }

	b.model:SetAttribute("Nombre", "Egipto")

	-- Estatua sentada de faraón (mira hacia -Z local)
	local function pharaoh(pos, rotY)
		local s = b:at(pos, rotY)
		s:box({ name = "Pedestal", size = { 7, 2, 9 }, pos = { 0, 1, 0 }, color = STONE_DARK, mat = "Sandstone" })
		s:box({ name = "Trono", size = { 6, 9, 4 }, pos = { 0, 6.5, 2 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Piernas", size = { 4.6, 2.4, 5 }, pos = { 0, 6.2, -1.8 }, color = STONE, mat = "Sandstone" })
		for _, x in ipairs({ -1.2, 1.2 }) do
			s:box({ name = "Pierna", size = { 1.8, 5, 1.8 }, pos = { x, 4.5, -3.4 }, color = STONE, mat = "Sandstone" })
			s:box({ name = "Brazo", size = { 1.3, 1.1, 4 }, pos = { x * 1.75, 7.9, -1.6 }, color = STONE, mat = "Sandstone", folder = "Decoracion" })
		end
		s:box({ name = "Torso", size = { 4.4, 6, 2.6 }, pos = { 0, 10.4, 0.8 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Cabeza", size = { 2.4, 2.8, 2.4 }, pos = { 0, 14.8, 0.6 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Nemes", size = { 3.6, 3.4, 2.6 }, pos = { 0, 15.2, 1.2 }, color = GOLD, mat = "Sandstone", folder = "Decoracion" })
		for i = 0, 2 do
			s:box({ name = "Franja", size = { 3.7, 0.4, 2.7 }, pos = { 0, 14 + i, 1.2 }, color = BLUE, folder = "Decoracion" })
		end
		for _, x in ipairs({ -1.5, 1.5 }) do
			s:box({ name = "Nemes", size = { 1, 3.4, 1.2 }, pos = { x, 12.4, -0.2 }, color = GOLD, folder = "Decoracion" })
		end
		s:box({ name = "Barba", size = { 0.7, 1.6, 0.7 }, pos = { 0, 12.6, -0.4 }, color = STONE_DARK, folder = "Decoracion" })
		s:box({ name = "Cobra", size = { 0.5, 0.8, 0.4 }, pos = { 0, 16.8, -0.6 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	end

	-- Relieves pintados en una pared (figuras de colores sobre la cara -Z local)
	local function reliefs(g, x0, count, y, z)
		local colors = { BLUE, RED, GOLD }
		for k = 0, count - 1 do
			local x = x0 + k * 3
			g:box({ name = "Relieve", size = { 1.4, 4.4, 0.2 }, pos = { x, y, z }, color = colors[(k % 3) + 1], folder = "Decoracion" })
			g:box({ name = "Relieve", size = { 1.2, 1.2, 0.2 }, pos = { x, y + 3, z }, color = (k % 2 == 0) and GOLD or BLUE, folder = "Decoracion" })
		end
	end

	-- =================================================================
	--  Desierto, dunas y pirámides
	-- =================================================================
	b:box({ name = "Desierto", size = { 1000, 1, 1000 }, pos = { 0, -1.2, 0 }, color = SAND, mat = "Sand", folder = "Decoracion" })
	for _, d in ipairs({ { -190, 120, 120 }, { 200, 110, 140 }, { -190, -100, 150 }, { 180, -120, 130 }, { 0, -170, 160 } }) do
		b:ball({ name = "Duna", diameter = d[3], pos = { d[1], -d[3] * 0.36, d[2] }, color = { 222, 188, 136 }, mat = "Sand", folder = "Decoracion" })
	end
	P.pyramid(b, { -120, 0, 300 }, 220, 140, 20, { 214, 184, 128 })
	P.pyramid(b, { 80, 0, 360 }, 260, 166, 24, { 206, 176, 122 })
	P.pyramid(b, { 250, 0, 260 }, 140, 90, 14, { 214, 186, 132 })

	-- =================================================================
	--  Suelo del templo, obelisco y puerta monumental
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = SAND, mat = "Sand" })
	b:box({ name = "Losas", size = { 70, 0.4, 44 }, pos = { 0, 0.2, 0 }, color = { 200, 176, 132 }, mat = "Sandstone" })
	P.obelisk(b, { 0, 0.4, 0 }, 28, 3.2)
	b:box({ name = "Dintel", size = { 12, 6, 9 }, pos = { 0, 23, 58 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Portal", size = { 12, 20, 0.4 }, pos = { 0, 10, 57 }, color = { 70, 54, 40 }, folder = "Decoracion" })
	b:cylinder({ name = "Disco", axis = "z", length = 0.4, diameter = 4, pos = { 0, 23, 53.4 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	for _, x in ipairs({ -1, 1 }) do
		b:box({ name = "Ala", size = { 4, 1, 0.3 }, pos = { x * 4, 23, 53.4 }, color = BLUE, folder = "Decoracion" })
	end

	-- Esfinge entre el obelisco y el templo (mira hacia el centro)
	b:box({ name = "Pedestal", size = { 12, 2, 24 }, pos = { 0, 1, 36 }, color = STONE_DARK, mat = "Sandstone" })
	b:box({ name = "Cuerpo", size = { 7, 6, 14 }, pos = { 0, 5, 40 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Patas", size = { 8, 4, 6 }, pos = { 0, 4, 45 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Pecho", size = { 6, 6, 3 }, pos = { 0, 5, 32.4 }, color = STONE, mat = "Sandstone" })
	for _, x in ipairs({ -2.2, 2.2 }) do
		b:box({ name = "Garra", size = { 2, 1.6, 7 }, pos = { x, 2.8, 28.4 }, color = STONE, mat = "Sandstone" })
		b:box({ name = "Nemes", size = { 1.2, 4, 1.4 }, pos = { x * 1.1, 9, 31.8 }, color = GOLD, folder = "Decoracion" })
	end
	b:box({ name = "Cabeza", size = { 4, 4.4, 4 }, pos = { 0, 11, 32.4 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Nemes", size = { 5.6, 5, 3.6 }, pos = { 0, 11.6, 33.6 }, color = GOLD, mat = "Sandstone", folder = "Decoracion" })
	for i = 0, 3 do
		b:box({ name = "Franja", size = { 5.7, 0.45, 3.7 }, pos = { 0, 9.8 + i * 1.2, 33.6 }, color = BLUE, folder = "Decoracion" })
	end
	b:box({ name = "Barba", size = { 0.8, 2, 0.8 }, pos = { 0, 8, 30.6 }, color = STONE_DARK, folder = "Decoracion" })

	b:symmetric(function(b)
		-- Estandartes delante del pilono
		for i, x in ipairs({ -23, -7 }) do
			b:cylinder({ name = "Mastil", length = 32, diameter = 0.6, pos = { x, 16, 52.6 }, color = { 120, 90, 60 }, mat = "Wood" })
			b:box({ name = "Estandarte", size = { 3, 8, 0.15 }, pos = { x + 1.7, 27, 52.6 }, color = (i == 1) and BLUE or RED, mat = "Fabric", folder = "Decoracion" })
		end

		-- Braseros con fuego
		for _, z in ipairs({ -20, 20 }) do
			b:cylinder({ name = "Pie", length = 3.6, diameter = 0.6, pos = { -33, 2.2, z }, color = { 70, 60, 50 }, mat = "Metal" })
			b:cylinder({ name = "Cuenco", length = 0.8, diameter = 2.4, pos = { -33, 4.2, z }, color = { 120, 90, 50 }, mat = "Metal" })
			local fire = b:ball({ name = "Fuego", diameter = 1.6, pos = { -33, 4.9, z }, color = { 255, 140, 40 }, mat = "Neon", folder = "Decoracion" })
			MB.light(fire, "Point", { color = { 255, 150, 70 }, brightness = 1.6, range = 16 })
		end

		-- Tienda de campaña del bazar
		for _, x in ipairs({ -42, -34 }) do
			for _, z in ipairs({ -50, -42 }) do
				b:cylinder({ name = "Poste", length = 4, diameter = 0.4, pos = { x, 2, z }, color = { 120, 90, 60 }, mat = "Wood" })
			end
		end
		b:wedge({ name = "Lona", size = { 9, 3, 4.4 }, pos = { -38, 5.5, -48.2 }, color = RED, mat = "Fabric" })
		b:wedge({ name = "Lona", size = { 9, 3, 4.4 }, pos = { -38, 5.5, -43.8 }, rot = { 0, 180, 0 }, color = { 236, 220, 190 }, mat = "Fabric" })
		b:box({ name = "Alfombra", size = { 7, 0.08, 7 }, pos = { -38, 0.04, -46 }, color = BLUE, mat = "Fabric", folder = "Decoracion" })
		b:box({ name = "Cojin", size = { 2, 0.8, 1.4 }, pos = { -36, 0.4, -48 }, color = GOLD, mat = "Fabric", folder = "Decoracion" })

		-- Pilono del templo al fondo
		b:box({ name = "Pilono", size = { 18, 26, 9 }, pos = { -15, 13, 58 }, color = STONE, mat = "Sandstone" })
		b:box({ name = "Cornisa", size = { 19, 1.6, 10 }, pos = { -15, 26.8, 58 }, color = STONE_DARK, mat = "Sandstone" })
		reliefs(b, -21, 5, 9, 53.4)
		b:cylinder({ name = "Disco", axis = "z", length = 0.4, diameter = 4, pos = { -15, 20, 53.4 }, color = GOLD, mat = "Metal", folder = "Decoracion" })

		-- Muralla en ruinas al sur
		for i, h in ipairs({ 9, 6, 11, 5, 8, 12, 7 }) do
			b:box({ name = "Muralla", size = { 12, h, 4 }, pos = { -82 + i * 12, h / 2, -56 }, color = (i % 2 == 0) and STONE or STONE_DARK, mat = "Sandstone" })
		end

		-- Columnata norte con dintel
		for _, x in ipairs({ -40, -32, -24, -16 }) do
			P.column(b, { x, 0, 26 }, 16, 3, STONE, "Sandstone")
			for k, y in ipairs({ 13.6, 14.6, 15.6 }) do
				b:cylinder({ name = "Pintura", length = 0.5, diameter = 3.1, pos = { x, y, 26 }, color = (k == 2) and GOLD or BLUE, folder = "Decoracion" })
			end
		end
		b:box({ name = "Dintel", size = { 29, 2.4, 4.4 }, pos = { -28, 19.4, 26 }, color = STONE_DARK, mat = "Sandstone" })
		for k = 0, 8 do
			b:box({ name = "Friso", size = { 1.4, 1, 0.2 }, pos = { -40 + k * 3, 19.4, 23.7 }, color = (k % 2 == 0) and BLUE or GOLD, folder = "Decoracion" })
		end

		-- Columnata sur en ruinas y columna caída
		P.column(b, { -40, 0, -26 }, 16, 3, STONE, "Sandstone")
		P.column(b, { -32, 0, -26 }, 7, 3, STONE, "Sandstone", true)
		P.column(b, { -24, 0, -26 }, 16, 3, STONE, "Sandstone")
		P.column(b, { -16, 0, -26 }, 4, 3, STONE, "Sandstone", true)
		b:cylinder({ name = "Columna", axis = "x", length = 10, diameter = 3, pos = { -28, 1.5, -16 }, rot = { 0, 25, 0 }, color = STONE, mat = "Sandstone" })

		-- Bloques de piedra sueltos
		for _, k in ipairs({ { -48, -10, 5, 5, 5, 10 }, { -44, -4, 4, 3, 4, 30 }, { -20, 12, 6, 3.5, 4, -15 }, { -56, 14, 6, 4, 5, 5 }, { -12, -38, 5, 4, 5, 20 } }) do
			b:box({ name = "Bloque", size = { k[3], k[4], k[5] }, pos = { k[1], k[4] / 2, k[2] }, rot = { 0, k[6], 0 }, color = STONE_DARK, mat = "Sandstone" })
		end

		-- Pared con jeroglíficos
		b:box({ name = "Pared", size = { 14, 8, 2.4 }, pos = { -36, 4, -42 }, color = STONE, mat = "Sandstone" })
		reliefs(b, -42, 5, 3.6, -40.7)

		-- Oasis con palmeras
		b:cylinder({ name = "Agua", length = 0.12, diameter = 16, pos = { -56, 0.06, 34 }, color = { 60, 150, 170 }, mat = "Glass", transparency = 0.2, reflectance = 0.25, folder = "Decoracion" })
		b:cylinder({ name = "Orilla", length = 0.1, diameter = 18, pos = { -56, 0.04, 34 }, color = { 150, 150, 90 }, mat = "Grass", folder = "Decoracion" })
		P.palmTree(b, { -62, 0, 40 }, 1.1)
		P.palmTree(b, { -50, 0, 42 }, 0.9)
		P.palmTree(b, { -64, 0, 27 }, 1)
		P.palmTree(b, { -10, 0, 42 }, 1)
		for i = 0, 5 do
			b:cylinder({ name = "Junco", length = 3, diameter = 0.3, pos = { -48.5 + (i % 3) * 0.6, 1.5, 30 + i * 0.7 }, color = { 110, 140, 70 }, mat = "Grass", folder = "Decoracion" })
		end

		-- Bazar con alfombras y ánforas
		P.marketStall(b, { -50, 0, -38 }, 180, BLUE, "BAZAR", { { 200, 80, 40 }, { 230, 180, 60 }, { 160, 60, 40 }, { 220, 140, 60 } })
		b:box({ name = "Alfombra", size = { 6, 0.08, 4 }, pos = { -50, 0.04, -31 }, color = RED, mat = "Fabric", folder = "Decoracion" })
		b:box({ name = "Alfombra", size = { 4.4, 0.1, 2.6 }, pos = { -50, 0.06, -31 }, color = GOLD, mat = "Fabric", folder = "Decoracion" })
		for _, p in ipairs({ { -57, -40 }, { -58.4, -37.6 }, { -56, -35.8 } }) do
			b:ball({ name = "Anfora", diameter = 2, pos = { p[1], 1.1, p[2] }, color = { 190, 110, 70 }, mat = "Plaster" })
			b:cylinder({ name = "Cuello", length = 1, diameter = 0.8, pos = { p[1], 2.4, p[2] }, color = { 190, 110, 70 }, mat = "Plaster", folder = "Decoracion" })
		end

		-- Estatuas de faraón junto al spawn
		pharaoh({ -68, 0, 34 }, -90)
		pharaoh({ -68, 0, -34 }, -90)

		-- Muro del templo que protege el spawn
		P.wall(b, { -60, 0, 0 }, 90, { 34, 11, 2.6 }, STONE, STONE_DARK, STONE_DARK, "Sandstone")
		b:box({ name = "Franja", size = { 0.2, 1.2, 30 }, pos = { -58.6, 8.6, 0 }, color = BLUE, folder = "Decoracion" })
		b:cylinder({ name = "Disco", axis = "x", length = 0.4, diameter = 3.4, pos = { -58.5, 5.6, 0 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
		for _, z in ipairs({ -1, 1 }) do
			b:box({ name = "Ala", size = { 0.3, 0.9, 4 }, pos = { -58.5, 5.6, z * 3.6 }, color = BLUE, folder = "Decoracion" })
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 16.9,
			Brightness = 3,
			Ambient = { 130, 104, 80 },
			OutdoorAmbient = { 176, 140, 104 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.2,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.34, offset = 0.1, color = { 244, 206, 156 }, decay = { 190, 130, 80 }, glare = 1.2, haze = 2.4 },
		colorCorrection = { contrast = 0.1, saturation = 0.12, tint = { 255, 240, 220 } },
		clouds = { cover = 0.2, density = 0.3, color = { 255, 230, 200 } },
		bloom = { intensity = 0.4, size = 26, threshold = 0.92 },
		sunRays = { intensity = 0.14, spread = 0.7 },
	})
end
