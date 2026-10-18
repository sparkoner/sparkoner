-- Azotea Neón: tejado de noche con un gran cartel luminoso. Equipo A en -X, B en +X.
return function(b, MB)
	local P = MB.Props
	local ROOF = { 84, 82, 94 }
	local PARAPET = { 106, 104, 118 }
	local HUT = { 96, 90, 108 }
	local PINK = { 255, 60, 180 }
	local CYAN = { 40, 230, 255 }
	local PURPLE = { 160, 90, 255 }
	local DARK = { 34, 33, 44 }
	local METAL = { 150, 156, 166 }
	local WINDOWS = { { 196, 146, 88 }, { 38, 38, 50 }, { 170, 150, 118 }, { 38, 38, 50 }, { 96, 136, 186 }, { 38, 38, 50 }, { 38, 38, 50 } }

	b.model:SetAttribute("Nombre", "Azotea Neón")

	-- =================================================================
	--  Ciudad de fondo
	-- =================================================================
	b:box({ name = "Calle", size = { 900, 1, 900 }, pos = { 0, -80.5, 0 }, color = { 26, 26, 32 }, mat = "Asphalt", folder = "Decoracion" })
	b:box({ name = "Edificio", size = { 124, 80, 84 }, pos = { 0, -40.5, 0 }, color = { 50, 48, 62 }, mat = "Concrete" })
	local city = {
		{ -120, -90, 40, 40, 150, "HOTEL", PINK }, { -60, -125, 50, 30, 120 }, { 10, -132, 40, 40, 170, "RAMEN", CYAN }, { 80, -112, 40, 40, 130 },
		{ 132, -40, 40, 50, 160, "24H", PURPLE }, { 136, 50, 40, 40, 110 }, { 72, 120, 50, 40, 140, "BAR", PINK }, { -10, 132, 40, 40, 125 },
		{ -82, 116, 40, 40, 160, "CLUB", CYAN }, { -136, 30, 40, 50, 130 }, { -142, -32, 30, 30, 100 },
	}
	local seed = 0
	for _, c in ipairs(city) do
		local x, z, w, d, h = c[1], c[2], c[3], c[4], c[5]
		b:box({ name = "Rascacielos", size = { w, h, d }, pos = { x, -80 + h / 2, z }, color = { 42, 40, 54 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Remate", size = { w + 1, 1.5, d + 1 }, pos = { x, -80 + h + 0.75, z }, color = { 60, 58, 72 }, mat = "Concrete", folder = "Decoracion" })
		local alongX = math.abs(x) > math.abs(z)
		local facing = alongX and (x > 0 and -1 or 1) or (z > 0 and -1 or 1)
		local faceOffset = alongX and (w / 2 + 0.1) or (d / 2 + 0.1)
		local span = alongX and d or w
		-- Plantas con ventanas de distintos colores y montantes verticales
		for y = -72, -80 + h - 6, 6 do
			seed = seed + 1
			local color = WINDOWS[(seed * 7) % #WINDOWS + 1]
			local size = alongX and { 0.2, 1.6, span - 4 } or { span - 4, 1.6, 0.2 }
			local pos = alongX and { x + facing * faceOffset, y, z } or { x, y, z + facing * faceOffset }
			local lit = color[1] > 60
			b:box({ name = "Ventanas", size = size, pos = pos, color = color, mat = lit and "Neon" or "Glass", transparency = lit and 0.35 or 0, folder = "Decoracion", shadow = false })
		end
		for i = 1, math.floor(span / 5) - 1 do
			local o = -span / 2 + i * 5
			local size = alongX and { 0.4, h - 10, 0.6 } or { 0.6, h - 10, 0.4 }
			local pos = alongX and { x + facing * (faceOffset + 0.1), -80 + h / 2, z + o } or { x + o, -80 + h / 2, z + facing * (faceOffset + 0.1) }
			b:box({ name = "Montante", size = size, pos = pos, color = { 30, 30, 40 }, folder = "Decoracion", shadow = false })
		end
		-- Antena con luz roja en lo alto
		b:cylinder({ name = "Antena", length = 14, diameter = 0.6, pos = { x + w / 4, -80 + h + 8, z }, color = METAL, folder = "Decoracion" })
		b:ball({ name = "Baliza", diameter = 1.2, pos = { x + w / 4, -80 + h + 15.2, z }, color = { 255, 40, 40 }, mat = "Neon", folder = "Decoracion" })
		if c[6] then
			local signPos = alongX and { x + facing * (faceOffset + 0.6), -80 + h - 14, z } or { x, -80 + h - 14, z + facing * (faceOffset + 0.6) }
			local yaw = alongX and (facing > 0 and -90 or 90) or (facing > 0 and 180 or 0)
			P.neonSign(b, signPos, yaw, { span * 0.6, 8 }, c[6], c[7], "Michroma")
		end
	end

	-- =================================================================
	--  Tejado
	-- =================================================================
	b:box({ name = "Tejado", size = { 124, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROOF, mat = "Concrete" })
	for _, g in ipairs({ { -30, -14, 22, 16 }, { 30, -14, 22, 16 }, { 0, 18, 26, 14 } }) do
		b:box({ name = "Grava", size = { g[3], 0.12, g[4] }, pos = { g[1], 0.06, g[2] }, color = { 112, 108, 116 }, mat = "Pebble", folder = "Decoracion" })
	end
	for _, z in ipairs({ -20, 0, 20 }) do
		b:box({ name = "Junta", size = { 120, 0.08, 0.6 }, pos = { 0, 0.04, z }, color = { 40, 38, 46 }, folder = "Decoracion" })
	end
	for _, z in ipairs({ -41.25, 41.25 }) do
		b:box({ name = "Pretil", size = { 124, 3.5, 1.5 }, pos = { 0, 1.75, z }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Albardilla", size = { 124.4, 0.4, 2 }, pos = { 0, 3.7, z }, color = { 130, 128, 140 }, mat = "Concrete" })
		b:box({ name = "Neon", size = { 124, 0.3, 0.3 }, pos = { 0, 3.95, z + (z > 0 and -0.8 or 0.8) }, color = PINK, mat = "Neon", folder = "Decoracion" })
		P.railing(b, { -60, 3.9, z }, { 60, 3.9, z }, 2.6, { 120, 124, 134 })
	end

	-- Zona chill en el centro delantero: tarima, sofá, mesa y guirnalda de luces
	b:box({ name = "Tarima", size = { 22, 0.5, 9 }, pos = { 0, 0.25, -34 }, color = { 140, 100, 70 }, mat = "WoodPlanks" })
	b:box({ name = "Sofa", size = { 10, 1.4, 3 }, pos = { 0, 1.2, -37 }, color = { 120, 60, 140 }, mat = "Fabric" })
	b:box({ name = "Respaldo", size = { 10, 2, 0.9 }, pos = { 0, 2.4, -38.2 }, color = { 120, 60, 140 }, mat = "Fabric" })
	b:box({ name = "Mesa", size = { 4, 1.4, 2.4 }, pos = { 0, 1.2, -32.4 }, color = { 60, 50, 46 }, mat = "Wood" })
	for _, x in ipairs({ -11, 11 }) do
		b:cylinder({ name = "Poste", length = 7, diameter = 0.35, pos = { x, 4, -38.5 }, color = METAL, mat = "Metal" })
	end
	P.stringLights(b, { -11, 7.3, -38.5 }, { 11, 7.3, -38.5 }, 14, 1.4, { { 255, 214, 120 }, { 255, 120, 200 }, { 120, 220, 255 } })
	P.stringLights(b, { -11, 7.3, -38.5 }, { 0, 16, 0 }, 16, 2.4, { { 255, 214, 120 }, { 255, 120, 200 } })
	P.stringLights(b, { 11, 7.3, -38.5 }, { 0, 16, 0 }, 16, 2.4, { { 255, 214, 120 }, { 120, 220, 255 } })
	local chill = b:box({ name = "Luz", size = { 0.4, 0.4, 0.4 }, pos = { 0, 6, -35 }, color = { 255, 214, 120 }, mat = "Neon", transparency = 1, folder = "Decoracion" })
	MB.light(chill, "Point", { color = { 255, 200, 140 }, brightness = 1.2, range = 18 })

	-- =================================================================
	--  Centro: valla publicitaria sobre una pasarela
	-- =================================================================
	b:box({ name = "Pasarela", size = { 28, 0.6, 4 }, pos = { 0, 8, 0 }, color = METAL, mat = "DiamondPlate" })
	P.railing(b, { -14, 8.3, -2 }, { 14, 8.3, -2 }, 3, METAL)
	P.railing(b, { -14, 8.3, 2 }, { 14, 8.3, 2 }, 3, METAL)
	local board = b:box({ name = "Valla", size = { 30, 11, 1 }, pos = { 0, 16.5, 0 }, color = DARK })
	MB.sign(board, "NEO CITY", { face = "Front", font = "Michroma", color = PINK, glow = true, width = 0.88, height = 0.6 })
	MB.sign(board, "MOTEL 24/7", { face = "Back", font = "Michroma", color = CYAN, glow = true, width = 0.88, height = 0.6 })
	for _, y in ipairs({ 10.85, 22.15 }) do
		b:box({ name = "Neon", size = { 30.4, 0.3, 1.2 }, pos = { 0, y, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end
	local glowFront = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, -1.5 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	MB.light(glowFront, "Point", { color = PINK, brightness = 2.2, range = 28 })
	local glowBack = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, 1.5 }, color = CYAN, mat = "Neon", folder = "Decoracion" })
	MB.light(glowBack, "Point", { color = CYAN, brightness = 2.2, range = 28 })

	b:symmetric(function(b)
		b:box({ name = "Pretil", size = { 1.5, 3.5, 81 }, pos = { -61.25, 1.75, 0 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Albardilla", size = { 2, 0.4, 81 }, pos = { -61.25, 3.7, 0 }, color = { 130, 128, 140 }, mat = "Concrete" })
		b:box({ name = "Neon", size = { 0.3, 0.3, 81 }, pos = { -60.45, 3.95, 0 }, color = CYAN, mat = "Neon", folder = "Decoracion" })

		-- Caseta de acceso (sala de spawn con puerta hacia el centro)
		b:box({ name = "Caseta", size = { 1, 10, 14 }, pos = { -57.5, 5, 0 }, color = HUT, mat = "Brick" })
		for _, z in ipairs({ -6.5, 6.5 }) do
			b:box({ name = "Caseta", size = { 11, 10, 1 }, pos = { -52.5, 5, z }, color = HUT, mat = "Brick" })
		end
		for _, z in ipairs({ -4.75, 4.75 }) do
			b:box({ name = "Caseta", size = { 1, 10, 4.5 }, pos = { -47.5, 5, z }, color = HUT, mat = "Brick" })
		end
		b:box({ name = "Dintel", size = { 1, 2.5, 5 }, pos = { -47.5, 8.75, 0 }, color = HUT, mat = "Brick" })
		b:box({ name = "Marco", size = { 1.3, 0.4, 5.6 }, pos = { -47.4, 7.5, 0 }, color = DARK, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "TechoCaseta", size = { 12, 1, 15 }, pos = { -52.5, 10.5, 0 }, color = DARK })
		P.vent(b, { -55, 11, -4 })
		P.vent(b, { -55, 11, 4 })
		local hutColor = b.mirrored and PINK or CYAN
		local hutLight = b:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -52.5, 9.8, 0 }, color = hutColor, mat = "Neon", folder = "Decoracion" })
		MB.light(hutLight, "Point", { color = hutColor, brightness = 1.5, range = 14 })
		P.neonSign(b, { -46.8, 9.2, 0 }, -90, { 4.6, 1.4 }, "ROOF", hutColor, "Michroma")

		-- Soportes de la valla y escaleras de mano
		b:box({ name = "Poste", size = { 1, 22, 1 }, pos = { -12, 11, 0 }, color = METAL, mat = "Metal" })
		for _, z in ipairs({ -1.6, 1.6 }) do
			b:box({ name = "Pata", size = { 0.8, 8, 0.8 }, pos = { -8, 4, z }, color = METAL, mat = "Metal" })
			P.segment(b, { -8, 0.5, z }, { -12, 7.6, z }, 0.3, METAL, "Metal", "Decoracion")
		end
		b:truss({ name = "Escalera", size = { 2, 8, 2 }, pos = { -15, 4, 0 }, color = METAL })
		b:box({ name = "Neon", size = { 0.3, 11, 1.2 }, pos = { -15.15, 16.5, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })

		-- Cobertura
		P.acUnit(b, { -24, 0, -22 }, 0)
		P.acUnit(b, { -40, 0, -26 }, 90)
		P.acUnit(b, { -22, 0, 14 }, 0)
		P.waterTank(b, { -36, 0, 26 })
		b:box({ name = "Tragaluz", size = { 8.6, 1, 8.6 }, pos = { -12, 0.5, -26 }, color = DARK })
		b:box({ name = "Cristal", size = { 8, 0.6, 8 }, pos = { -12, 1.3, -26 }, color = { 150, 180, 230 }, mat = "Glass", transparency = 0.3 })
		P.planter(b, { -28, 0, -4 }, { 10, 3 }, 0)
		P.crate(b, { -8, 0, 22 }, 4.5)
		P.crate(b, { -8, 0, 27 }, 4.5, 12)
		P.crate(b, { -8, 4.5, 24.5 }, 4)
		P.pottedPlant(b, { -13, 0, -31 }, 1.1)

		-- Generador, paneles solares y antena con baliza
		b:box({ name = "Generador", size = { 6, 3.6, 3.4 }, pos = { -50, 1.8, 20 }, color = { 70, 110, 80 }, mat = "Metal" })
		b:box({ name = "Rejilla", size = { 4, 2, 0.2 }, pos = { -50, 1.9, 18.2 }, color = { 40, 50, 44 }, mat = "DiamondPlate", folder = "Decoracion" })
		b:cylinder({ name = "Escape", length = 3, diameter = 0.6, pos = { -52, 5, 21 }, color = { 60, 60, 66 }, mat = "Metal", folder = "Decoracion" })
		for i = 0, 1 do
			local z = -32 + i * 5.5
			b:box({ name = "PanelSolar", size = { 8, 0.3, 4.4 }, pos = { -46, 1.9, z }, rot = { -25, 0, 0 }, color = { 30, 50, 100 }, mat = "Glass", reflectance = 0.2 })
			for _, x in ipairs({ -49.5, -42.5 }) do
				b:box({ name = "Soporte", size = { 0.3, 1.8, 0.3 }, pos = { x, 0.9, z - 1.2 }, color = METAL, mat = "Metal", folder = "Decoracion" })
			end
		end
		b:cylinder({ name = "Antena", length = 14, diameter = 0.5, pos = { -56, 7, -34 }, color = METAL, mat = "Metal" })
		b:ball({ name = "Baliza", diameter = 1, pos = { -56, 14.4, -34 }, color = { 255, 40, 40 }, mat = "Neon", folder = "Decoracion" })
		P.satelliteDish(b, { -55, 0, 33 }, 30)
		P.vent(b, { -30, 0, 34 })
		P.vent(b, { -18, 0, -36 })

		-- Tuberías
		P.rod(b, { -44, 0.9, -24 }, { -44, 0.9, 36 }, 1.4, { 120, 124, 132 }, "Metal")
		P.rod(b, { -44, 0.9, 36 }, { -44, 5, 36 }, 1.4, { 120, 124, 132 }, "Metal")
		b:ball({ name = "Codo", diameter = 1.6, pos = { -44, 0.9, 36 }, color = { 120, 124, 132 }, mat = "Metal", folder = "Decoracion" })
		for z = -20, 32, 8 do
			b:box({ name = "Soporte", size = { 2, 0.4, 0.6 }, pos = { -44, 0.2, z }, color = DARK, folder = "Decoracion" })
		end

		for _, z in ipairs({ -3, 0, 3 }) do
			b:spawn("A", { -54, 0.5, z }, -90)
		end
	end)

	b:bounds(-60, 60, -40, 40, 30)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 0.2,
			Brightness = 1.3,
			Ambient = { 76, 66, 108 },
			OutdoorAmbient = { 86, 76, 128 },
			ExposureCompensation = 0.4,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.32, color = { 112, 82, 162 }, decay = { 62, 42, 112 }, haze = 1.6, glare = 0 },
		colorCorrection = { contrast = 0.12, saturation = 0.25, tint = { 236, 226, 255 } },
		bloom = { intensity = 1, size = 32, threshold = 0.8 },
	})
end
