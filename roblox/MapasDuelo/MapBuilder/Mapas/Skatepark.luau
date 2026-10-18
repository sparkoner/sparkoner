-- SK8 OR DIE: skatepark cubierto. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 200, 166, 196 }
	local FLOOR_DARK = { 184, 146, 182 }
	local PATH = { 236, 222, 220 }
	local YELLOW = { 242, 202, 66 }
	local WALL = { 236, 228, 226 }
	local SKIRT = { 232, 200, 206 }
	local PILLAR = { 64, 62, 76 }
	local BEAM = { 58, 56, 70 }
	local TEAL = { 112, 206, 186 }
	local WOOD = { 228, 194, 142 }
	local DARK = { 40, 38, 50 }
	local PINK = { 245, 122, 192 }
	local CEILING = { 178, 152, 174 }
	local LEDGE = { 242, 218, 200 }

	b.model:SetAttribute("Nombre", "Skatepark SK8 OR DIE")

	-- Exterior (se ve por los ventanales)
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 108, 142, 76 }, mat = "Grass", folder = "Decoracion" })
	local trees = { { -50, 64 }, { -18, 72 }, { 16, 66 }, { 48, 74 }, { -42, -68 }, { 6, -76 }, { 40, -66 }, { -96, 20 }, { 96, -18 } }
	for _, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, 1.3)
	end

	-- Nave
	b:box({ name = "Suelo", size = { 140, 1, 80 }, pos = { 0, -0.5, 0 }, color = FLOOR })
	b:box({ name = "Techo", size = { 144, 1, 84 }, pos = { 0, 26.5, 0 }, color = CEILING })
	for _, z in ipairs({ -41, 41 }) do
		b:box({ name = "Zocalo", size = { 144, 4, 2 }, pos = { 0, 2, z }, color = SKIRT })
		b:box({ name = "Ventanal", size = { 144, 17, 1 }, pos = { 0, 12.5, z }, color = { 210, 226, 236 }, mat = "Glass", transparency = 0.45 })
		b:box({ name = "Muro", size = { 144, 5, 2 }, pos = { 0, 23.5, z }, color = WALL })
	end

	-- Suelo: pasillos claros y líneas amarillas
	for _, z in ipairs({ -34.5, 34.5 }) do
		b:box({ name = "Pasillo", size = { 140, 0.1, 9 }, pos = { 0, 0.05, z }, color = PATH, folder = "Decoracion" })
		b:box({ name = "Linea", size = { 140, 0.12, 0.5 }, pos = { 0, 0.06, z > 0 and 29.8 or -29.8 }, color = YELLOW, folder = "Decoracion" })
	end
	b:box({ name = "Zona", size = { 60, 0.1, 34 }, pos = { 0, 0.05, 0 }, color = FLOOR_DARK, folder = "Decoracion" })

	-- Estructura del techo: vigas oscuras y tubos turquesa
	for _, z in ipairs({ -32, -16, 0, 16, 32 }) do
		b:box({ name = "Viga", size = { 140, 1.4, 1.4 }, pos = { 0, 24.6, z }, color = BEAM, folder = "Decoracion" })
	end
	for _, x in ipairs({ -60, -40, -20, 0, 20, 40, 60 }) do
		b:box({ name = "Viga", size = { 1.4, 1.4, 80 }, pos = { x, 23.6, 0 }, color = BEAM, folder = "Decoracion" })
	end
	for _, z in ipairs({ -24, -8, 8, 24 }) do
		b:box({ name = "Tubo", size = { 140, 0.7, 0.7 }, pos = { 0, 22.6, z }, color = TEAL, folder = "Decoracion" })
	end
	for _, x in ipairs({ -50, -30, -10, 10, 30, 50 }) do
		b:box({ name = "Tubo", size = { 0.7, 0.7, 80 }, pos = { x, 22, 0 }, color = TEAL, folder = "Decoracion" })
	end
	for _, x in ipairs({ -45, -15, 15, 45 }) do
		for _, z in ipairs({ -16, 16 }) do
			P.ceilingLight(b, { x, 23.4, z }, true)
		end
	end

	-- Centro: bloque SK8 OR DIE con plataforma alta y rampas a los lados
	local block = b:box({ name = "Sk8OrDie", size = { 34, 8, 10 }, pos = { 0, 4, 0 }, color = DARK })
	local dots = {
		{ 0.08, 0.3, 0.55, PINK }, { 0.2, 0.8, 0.4, PINK }, { 0.36, 0.2, 0.3, PINK }, { 0.52, 0.85, 0.5, PINK },
		{ 0.66, 0.25, 0.45, PINK }, { 0.82, 0.7, 0.6, PINK }, { 0.94, 0.2, 0.35, PINK },
	}
	for _, face in ipairs({ "Front", "Back" }) do
		MB.sign(block, "SK8 OR DIE", { face = face, font = "LuckiestGuy", color = { 226, 244, 248 }, stroke = { 24, 40, 60 }, dots = dots, width = 0.9, height = 0.78 })
	end
	b:box({ name = "Cubierta", size = { 34, 0.3, 10 }, pos = { 0, 8.15, 0 }, color = { 88, 86, 100 } })
	P.railing(b, { -16.5, 8.3, -4.8 }, { 16.5, 8.3, -4.8 }, 3)
	P.railing(b, { -16.5, 8.3, 4.8 }, { 16.5, 8.3, 4.8 }, 3)

	-- Fondo: gran cuarto de tubo con plataforma
	P.quarterPipe(b, { 0, 0, 24 }, 0, 44, 10, WOOD, DARK)
	b:box({ name = "Plataforma", size = { 44, 10, 6 }, pos = { 0, 5, 37 }, color = DARK })
	b:box({ name = "Plataforma", size = { 44, 0.4, 6 }, pos = { 0, 10.2, 37 }, color = WOOD, mat = "WoodPlanks" })

	-- Frente: funbox central
	b:box({ name = "Funbox", size = { 14, 3, 8 }, pos = { 0, 1.5, -27 }, color = LEDGE })
	b:box({ name = "Borde", size = { 14, 0.2, 8 }, pos = { 0, 3.1, -27 }, color = YELLOW, folder = "Decoracion" })

	b:symmetric(function(b)
		-- Muro lateral (detrás de los spawns) y pilares de los ventanales
		b:box({ name = "Muro", size = { 2, 26, 84 }, pos = { -71, 13, 0 }, color = WALL })
		for x = -63, -7, 14 do
			for _, z in ipairs({ -40.2, 40.2 }) do
				b:box({ name = "Pilar", size = { 2.4, 26, 2.4 }, pos = { x, 13, z }, color = PILLAR })
			end
		end

		-- Rampa de subida a la plataforma central
		b:wedge({ name = "Rampa", size = { 10, 8, 10 }, pos = { -22, 4, 0 }, rot = { 0, 90, 0 }, color = WOOD })

		-- Escaleras a la plataforma del fondo y lateral del tubo
		P.stairs(b, { -24.5, 0, 24 }, 0, 8, 1.25, 1.25, 5, LEDGE)
		b:box({ name = "Lateral", size = { 0.4, 10, 10 }, pos = { -22.2, 5, 29 }, color = DARK })

		-- Rampas del funbox
		b:wedge({ name = "Rampa", size = { 8, 3, 6 }, pos = { -10, 1.5, -27 }, rot = { 0, 90, 0 }, color = WOOD })

		-- Cajas de madera (cobertura)
		P.crate(b, { -30, 0, -10 }, 5)
		P.crate(b, { -30, 0, -5 }, 5)
		P.crate(b, { -30, 5, -7.5 }, 5, 15)
		P.crate(b, { -42, 0, 14 }, 5, 10)
		P.crate(b, { -42, 0, 19.5 }, 4)

		-- Ledge con borde amarillo
		b:box({ name = "Ledge", size = { 14, 2, 4 }, pos = { -44, 1, -22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 14, 0.2, 4 }, pos = { -44, 2.1, -22 }, color = YELLOW, folder = "Decoracion" })

		-- Pirámide de escalones
		b:box({ name = "Escalon", size = { 12, 1.5, 10 }, pos = { -52, 0.75, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 8, 3, 10 }, pos = { -52, 1.5, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 4, 4.5, 10 }, pos = { -52, 2.25, 22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 4, 0.2, 10 }, pos = { -52, 4.6, 22 }, color = YELLOW, folder = "Decoracion" })

		-- Muro de protección del spawn y bancos
		b:box({ name = "MuroSpawn", size = { 2, 7, 26 }, pos = { -58, 3.5, 0 }, color = DARK })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, -20 }, color = LEDGE })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, 20 }, color = LEDGE })

		-- Detalles: papelera y fuente de agua
		b:cylinder({ name = "Papelera", length = 3, diameter = 2.2, pos = { -66, 1.5, 34 }, color = { 50, 50, 58 } })
		b:box({ name = "Fuente", size = { 2.4, 3.6, 3 }, pos = { -68.6, 1.8, -26 }, color = { 80, 150, 210 } })

		-- Spawns del equipo A (el reflejo crea los del B)
		for _, z in ipairs({ -10, 0, 10 }) do
			b:spawn("A", { -65, 0.5, z }, -90)
		end
	end)

	b:lighting({
		lighting = {
			ClockTime = 14.5,
			Brightness = 2,
			Ambient = { 124, 108, 128 },
			OutdoorAmbient = { 150, 140, 160 },
			ExposureCompensation = 0.15,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.3,
		},
		atmosphere = { density = 0.25, color = { 232, 204, 222 }, decay = { 150, 120, 150 }, haze = 0.6, glare = 0 },
		colorCorrection = { brightness = 0.02, contrast = 0.06, saturation = 0.12, tint = { 255, 242, 250 } },
		clouds = { cover = 0.5, density = 0.4, color = { 255, 236, 245 } },
	})
end
