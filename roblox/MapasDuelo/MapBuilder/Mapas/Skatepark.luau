-- SK8 OR DIE: skatepark cubierto. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 204, 170, 200 }
	local FLOOR_DARK = { 186, 148, 184 }
	local TILE = { 238, 226, 224 }
	local YELLOW = { 242, 202, 66 }
	local WALL = { 240, 232, 230 }
	local SKIRT = { 232, 196, 206 }
	local PILLAR = { 62, 60, 76 }
	local BEAM = { 56, 54, 68 }
	local TEAL = { 112, 206, 186 }
	local WOOD = { 230, 196, 144 }
	local DARK = { 40, 38, 50 }
	local PINK = { 245, 122, 192 }
	local CEILING = { 182, 158, 180 }
	local LEDGE = { 244, 220, 204 }

	b.model:SetAttribute("Nombre", "Skatepark SK8 OR DIE")

	-- =================================================================
	--  Exterior (se ve por los ventanales)
	-- =================================================================
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 108, 146, 78 }, mat = "Grass", folder = "Decoracion" })
	b:box({ name = "Acera", size = { 160, 0.6, 100 }, pos = { 0, -0.9, 0 }, color = { 190, 186, 180 }, mat = "Pavement", folder = "Decoracion" })
	local trees = { { -50, 64 }, { -18, 74 }, { 16, 66 }, { 48, 74 }, { 80, 62 }, { -82, 70 }, { -42, -68 }, { 6, -76 }, { 40, -66 }, { 76, -72 }, { -78, -64 } }
	for _, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, 1.25)
	end
	for _, z in ipairs({ -54, 54 }) do
		for x = -66, 66, 22 do
			P.bush(b, { x, -0.6, z }, 1.3)
		end
	end

	-- =================================================================
	--  Nave
	-- =================================================================
	b:box({ name = "Suelo", size = { 140, 1, 80 }, pos = { 0, -0.5, 0 }, color = FLOOR, mat = "SmoothPlastic" })
	b:box({ name = "Techo", size = { 144, 1, 84 }, pos = { 0, 26.5, 0 }, color = CEILING, mat = "Plaster" })
	for _, z in ipairs({ -41, 41 }) do
		b:box({ name = "Zocalo", size = { 144, 5, 2 }, pos = { 0, 2.5, z }, color = SKIRT, mat = "Plaster" })
		b:box({ name = "Muro", size = { 144, 6, 2 }, pos = { 0, 23, z }, color = WALL, mat = "Plaster" })
		b:box({ name = "Neon", size = { 140, 0.3, 0.3 }, pos = { 0, 5.15, z > 0 and 39.9 or -39.9 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end
	-- Ventanales con marco y travesaños
	for _, x in ipairs({ -56, -42, -28, -14, 0, 14, 28, 42, 56 }) do
		P.window(b, { x, 12.5, 41 }, 0, 11.2, 14.6, PILLAR, { 200, 222, 236 })
		P.window(b, { x, 12.5, -41 }, 180, 11.2, 14.6, PILLAR, { 200, 222, 236 })
	end

	-- Suelo: pasillos de baldosa, zonas y líneas amarillas
	for _, z in ipairs({ -34.5, 34.5 }) do
		b:box({ name = "Pasillo", size = { 140, 0.1, 9 }, pos = { 0, 0.05, z }, color = TILE, mat = "CeramicTiles", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 140, 0.12, 0.5 }, pos = { 0, 0.06, z > 0 and 29.8 or -29.8 }, color = YELLOW, folder = "Decoracion" })
	end
	b:box({ name = "Zona", size = { 60, 0.1, 34 }, pos = { 0, 0.05, 0 }, color = FLOOR_DARK, folder = "Decoracion" })
	for _, x in ipairs({ -30, 30 }) do
		b:box({ name = "Linea", size = { 0.5, 0.12, 34 }, pos = { x, 0.07, 0 }, color = YELLOW, folder = "Decoracion" })
	end

	-- Techo: vigas, tragaluces, conductos y lámparas
	for _, z in ipairs({ -32, -16, 0, 16, 32 }) do
		b:box({ name = "Viga", size = { 140, 1.6, 1.2 }, pos = { 0, 24.6, z }, color = BEAM, mat = "Metal", folder = "Decoracion" })
	end
	for _, x in ipairs({ -60, -40, -20, 0, 20, 40, 60 }) do
		b:box({ name = "Viga", size = { 1.2, 1.4, 80 }, pos = { x, 23.6, 0 }, color = BEAM, mat = "Metal", folder = "Decoracion" })
	end
	for _, z in ipairs({ -24, -8, 8, 24 }) do
		b:box({ name = "Tubo", size = { 140, 0.7, 0.7 }, pos = { 0, 22.6, z }, color = TEAL, folder = "Decoracion" })
		b:box({ name = "Tragaluz", size = { 30, 0.3, 10 }, pos = { 0, 26, z }, color = { 220, 236, 248 }, mat = "Neon", transparency = 0.3, folder = "Decoracion" })
	end
	for _, x in ipairs({ -50, -30, -10, 10, 30, 50 }) do
		b:box({ name = "Tubo", size = { 0.7, 0.7, 80 }, pos = { x, 22, 0 }, color = TEAL, folder = "Decoracion" })
	end
	for _, z in ipairs({ -20, 20 }) do
		b:cylinder({ name = "Conducto", axis = "x", length = 140, diameter = 2.6, pos = { 0, 21, z }, color = { 200, 204, 212 }, mat = "Metal", folder = "Decoracion" })
	end
	for _, x in ipairs({ -45, -15, 15, 45 }) do
		for _, z in ipairs({ -12, 12 }) do
			P.ceilingLight(b, { x, 21.4, z }, true)
		end
	end

	-- =================================================================
	--  Centro: bloque SK8 OR DIE con plataforma alta
	-- =================================================================
	local block = b:box({ name = "Sk8OrDie", size = { 34, 8, 10 }, pos = { 0, 4, 0 }, color = DARK })
	local dots = {
		{ 0.08, 0.3, 0.55, PINK }, { 0.2, 0.8, 0.4, PINK }, { 0.36, 0.2, 0.3, PINK }, { 0.52, 0.85, 0.5, PINK },
		{ 0.66, 0.25, 0.45, PINK }, { 0.82, 0.7, 0.6, PINK }, { 0.94, 0.2, 0.35, PINK },
	}
	for _, face in ipairs({ "Front", "Back" }) do
		MB.sign(block, "SK8 OR DIE", { face = face, font = "LuckiestGuy", color = { 226, 244, 248 }, stroke = { 24, 40, 60 }, dots = dots, width = 0.9, height = 0.78 })
	end
	b:box({ name = "Cubierta", size = { 34, 0.3, 10 }, pos = { 0, 8.15, 0 }, color = { 88, 86, 100 }, mat = "DiamondPlate" })
	for _, z in ipairs({ -5, 5 }) do
		b:cylinder({ name = "Coping", axis = "x", length = 34, diameter = 0.5, pos = { 0, 8.1, z }, color = { 200, 202, 210 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 34.1, 0.6, 0.1 }, pos = { 0, 0.3, z * 1.01 }, color = PINK, folder = "Decoracion" })
	end
	P.railing(b, { -16.5, 8.3, -4.6 }, { 16.5, 8.3, -4.6 }, 3)
	P.railing(b, { -16.5, 8.3, 4.6 }, { 16.5, 8.3, 4.6 }, 3)

	-- Fondo: cuarto de tubo, plataforma y letrero de neón
	P.quarterPipe(b, { 0, 0, 24 }, 0, 44, 10, WOOD, DARK)
	b:box({ name = "Plataforma", size = { 44, 10, 6 }, pos = { 0, 5, 37 }, color = DARK })
	b:box({ name = "Plataforma", size = { 44, 0.4, 6 }, pos = { 0, 10.2, 37 }, color = WOOD, mat = "WoodPlanks" })
	P.railing(b, { -22, 10.4, 39.6 }, { 22, 10.4, 39.6 }, 3)
	P.neonSign(b, { 0, 17.4, 39.4 }, 0, { 22, 4.6 }, "SK8 OR DIE", PINK, "LuckiestGuy")

	-- Frente: funbox con rail
	b:box({ name = "Funbox", size = { 14, 3, 8 }, pos = { 0, 1.5, -27 }, color = LEDGE })
	b:box({ name = "Borde", size = { 14, 0.2, 8 }, pos = { 0, 3.1, -27 }, color = YELLOW, folder = "Decoracion" })
	P.skateRail(b, { -6, 3, -27 }, { 6, 3, -27 }, 1.4)

	b:symmetric(function(b)
		-- Muro lateral con mural pintado
		b:box({ name = "Muro", size = { 2, 26, 84 }, pos = { -71, 13, 0 }, color = WALL, mat = "Plaster" })
		local mural = b:box({ name = "Mural", size = { 40, 12, 0.2 }, pos = { -69.85, 14, 0 }, rot = { 0, -90, 0 }, color = WALL, transparency = 1, folder = "Decoracion" })
		MB.sign(mural, b.mirrored and "SKATE · OR · DIE" or "NO RULES JUST SK8", {
			face = "Front", font = "LuckiestGuy", color = { 255, 255, 255 }, stroke = DARK, bg = { 112, 206, 186 },
			dots = { { 0.1, 0.25, 0.7, PINK }, { 0.3, 0.85, 0.5, YELLOW }, { 0.55, 0.15, 0.4, PINK }, { 0.75, 0.8, 0.6, { 120, 140, 240 } }, { 0.92, 0.3, 0.5, YELLOW } },
			width = 0.9, height = 0.6,
		})
		for x = -63, -7, 14 do
			for _, z in ipairs({ -40.2, 40.2 }) do
				b:box({ name = "Pilar", size = { 2.4, 26, 2.4 }, pos = { x, 13, z }, color = PILLAR, mat = "Metal" })
				b:box({ name = "Base", size = { 3, 1.2, 3 }, pos = { x, 0.6, z }, color = BEAM, mat = "Metal", folder = "Decoracion" })
			end
		end

		-- Rampa a la plataforma central, con rail
		b:wedge({ name = "Rampa", size = { 10, 8, 10 }, pos = { -22, 4, 0 }, rot = { 0, 90, 0 }, color = WOOD, mat = "WoodPlanks" })
		for _, z in ipairs({ -5, 5 }) do
			b:wedge({ name = "LateralRampa", size = { 0.4, 8, 10 }, pos = { -22, 4, z }, rot = { 0, 90, 0 }, color = DARK, folder = "Decoracion" })
		end

		-- Escaleras al fondo y lateral del tubo
		P.stairs(b, { -24.5, 0, 24 }, 0, 8, 1.25, 1.25, 5, LEDGE, YELLOW)
		b:box({ name = "Lateral", size = { 0.4, 10, 10 }, pos = { -22.2, 5, 29 }, color = DARK })
		P.poster(b, { -22.45, 5, 29 }, 90, { 8, 4 }, PINK, "SK8 JAM", { 255, 255, 255 }, "LuckiestGuy")
		P.speaker(b, { -18, 10.4, 38.2 }, 0)

		-- Rampas del funbox y conos
		b:wedge({ name = "Rampa", size = { 8, 3, 6 }, pos = { -10, 1.5, -27 }, rot = { 0, 90, 0 }, color = WOOD, mat = "WoodPlanks" })
		P.cone(b, { -16, 0, -31 })
		P.cone(b, { -17.5, 0, -29.5 })

		-- Cajas de madera (cobertura)
		P.crate(b, { -30, 0, -10 }, 5)
		P.crate(b, { -30, 0, -4.8 }, 5)
		P.crate(b, { -30, 5, -7.4 }, 5, 15)
		P.crate(b, { -42, 0, 14 }, 5, 10)
		P.crate(b, { -42, 0, 19.5 }, 4)
		P.cardboard(b, { -38.6, 0, 18 }, { 2.6, 2, 2.4 }, 20)

		-- Ledge con borde amarillo y kicker
		b:box({ name = "Ledge", size = { 14, 2, 4 }, pos = { -44, 1, -22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 14, 0.2, 4 }, pos = { -44, 2.1, -22 }, color = YELLOW, folder = "Decoracion" })
		b:wedge({ name = "Kicker", size = { 4, 2, 4 }, pos = { -35, 1, -22 }, rot = { 0, -90, 0 }, color = WOOD, mat = "WoodPlanks" })

		-- Pirámide de escalones
		b:box({ name = "Escalon", size = { 12, 1.5, 10 }, pos = { -52, 0.75, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 8, 3, 10 }, pos = { -52, 1.5, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 4, 4.5, 10 }, pos = { -52, 2.25, 22 }, color = LEDGE })
		for _, d in ipairs({ { 12, 1.6 }, { 8, 3.1 }, { 4, 4.6 } }) do
			b:box({ name = "Borde", size = { d[1], 0.2, 10 }, pos = { -52, d[2], 22 }, color = YELLOW, folder = "Decoracion" })
		end

		-- Gradas frente a la pared delantera
		P.bleachers(b, { -46, 0, -31 }, 180, 3, 14, { PINK, TEAL, YELLOW })

		-- Zona de spawn: muro, taquillas, expositor de tablas y máquina de bebidas
		b:box({ name = "MuroSpawn", size = { 2, 7, 26 }, pos = { -58, 3.5, 0 }, color = DARK })
		b:box({ name = "MuroSpawn", size = { 2.4, 0.4, 26.4 }, pos = { -58, 7.2, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, -20 }, color = LEDGE })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, 20 }, color = LEDGE })
		P.lockers(b, { -68.6, 0, -26 }, -90, 4)
		P.skateboardRack(b, { -69.6, 0, 24 }, -90)
		P.vending(b, { -68.2, 0, 33 }, -90, { 210, 50, 60 }, "COLA")
		P.trashCan(b, { -66, 0, 36.5 }, { 64, 62, 76 })
		P.pottedPlant(b, { -66, 0, -36.5 }, 1.2)
		P.bench(b, { -33, 0, 37.4 }, 0)
		P.bench(b, { -33, 0, -37.4 }, 180)
		P.pottedPlant(b, { -24, 0, -37.6 }, 1)

		-- Luces de ambiente de colores
		local accent = b:box({ name = "Acento", size = { 0.4, 0.4, 0.4 }, pos = { -50, 6, 0 }, color = TEAL, mat = "Neon", folder = "Decoracion", transparency = 1 })
		MB.light(accent, "Point", { color = b.mirrored and PINK or TEAL, brightness = 1.2, range = 30 })

		for _, z in ipairs({ -10, 0, 10 }) do
			b:spawn("A", { -65, 0.5, z }, -90)
		end
	end)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 14.5,
			Brightness = 2.2,
			Ambient = { 128, 112, 132 },
			OutdoorAmbient = { 156, 144, 166 },
			ExposureCompensation = 0.2,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.25, color = { 232, 204, 222 }, decay = { 150, 120, 150 }, haze = 0.6, glare = 0 },
		colorCorrection = { brightness = 0.02, contrast = 0.08, saturation = 0.14, tint = { 255, 242, 250 } },
		clouds = { cover = 0.5, density = 0.4, color = { 255, 236, 245 } },
		bloom = { intensity = 0.5, size = 24, threshold = 0.92 },
		sunRays = { intensity = 0.06, spread = 0.5 },
	})
end
