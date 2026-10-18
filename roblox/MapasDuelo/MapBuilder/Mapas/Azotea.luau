-- Azotea Neón: tejado de noche con un gran cartel luminoso. Equipo A en -X, B en +X.
return function(b, MB)
	local P = MB.Props
	local ROOF = { 84, 82, 94 }
	local PARAPET = { 106, 104, 118 }
	local HUT = { 92, 88, 104 }
	local PINK = { 255, 60, 180 }
	local CYAN = { 40, 230, 255 }
	local DARK = { 34, 33, 44 }
	local METAL = { 150, 156, 166 }
	local WINDOW = { 255, 204, 130 }

	b.model:SetAttribute("Nombre", "Azotea Neón")

	-- Edificio y ciudad de fondo
	b:box({ name = "Calle", size = { 800, 1, 800 }, pos = { 0, -80.5, 0 }, color = { 28, 28, 34 }, mat = "Asphalt", folder = "Decoracion" })
	b:box({ name = "Edificio", size = { 124, 80, 84 }, pos = { 0, -40.5, 0 }, color = { 50, 48, 62 }, mat = "Concrete" })
	local city = {
		{ -120, -90, 40, 40, 150 }, { -60, -125, 50, 30, 120 }, { 10, -132, 40, 40, 170 }, { 80, -112, 40, 40, 130 },
		{ 132, -40, 40, 50, 160 }, { 136, 50, 40, 40, 110 }, { 72, 120, 50, 40, 140 }, { -10, 132, 40, 40, 125 },
		{ -82, 116, 40, 40, 160 }, { -136, 30, 40, 50, 130 }, { -142, -32, 30, 30, 100 },
	}
	for _, c in ipairs(city) do
		local x, z, w, d, h = c[1], c[2], c[3], c[4], c[5]
		b:box({ name = "Rascacielos", size = { w, h, d }, pos = { x, -80 + h / 2, z }, color = { 44, 42, 56 }, mat = "Concrete", folder = "Decoracion" })
		-- Filas de ventanas encendidas en la cara que mira al tejado
		for y = -72, -80 + h - 6, 7 do
			if math.abs(x) > math.abs(z) then
				local sx = x - (x > 0 and 1 or -1) * (w / 2 + 0.1)
				b:box({ name = "Ventanas", size = { 0.2, 1.4, d - 4 }, pos = { sx, y, z }, color = WINDOW, mat = "Neon", transparency = 0.35, folder = "Decoracion", shadow = false })
			else
				local sz = z - (z > 0 and 1 or -1) * (d / 2 + 0.1)
				b:box({ name = "Ventanas", size = { w - 4, 1.4, 0.2 }, pos = { x, y, sz }, color = WINDOW, mat = "Neon", transparency = 0.35, folder = "Decoracion", shadow = false })
			end
		end
	end

	-- Tejado y pretil con neón
	b:box({ name = "Tejado", size = { 124, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROOF, mat = "Concrete" })
	for _, z in ipairs({ -41.25, 41.25 }) do
		b:box({ name = "Pretil", size = { 124, 3.5, 1.5 }, pos = { 0, 1.75, z }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Neon", size = { 124, 0.3, 0.4 }, pos = { 0, 3.65, z }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end

	-- Centro: valla publicitaria sobre una pasarela (se sube por las escaleras de mano)
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
	MB.light(glowFront, "Point", { color = PINK, brightness = 2, range = 26 })
	local glowBack = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, 1.5 }, color = CYAN, mat = "Neon", folder = "Decoracion" })
	MB.light(glowBack, "Point", { color = CYAN, brightness = 2, range = 26 })

	b:symmetric(function(b)
		b:box({ name = "Pretil", size = { 1.5, 3.5, 81 }, pos = { -61.25, 1.75, 0 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Neon", size = { 0.4, 0.3, 81 }, pos = { -61.25, 3.65, 0 }, color = CYAN, mat = "Neon", folder = "Decoracion" })

		-- Caseta de acceso (sala de spawn con puerta hacia el centro)
		b:box({ name = "Caseta", size = { 1, 10, 14 }, pos = { -57.5, 5, 0 }, color = HUT, mat = "Brick" })
		for _, z in ipairs({ -6.5, 6.5 }) do
			b:box({ name = "Caseta", size = { 11, 10, 1 }, pos = { -52.5, 5, z }, color = HUT, mat = "Brick" })
		end
		for _, z in ipairs({ -4.75, 4.75 }) do
			b:box({ name = "Caseta", size = { 1, 10, 4.5 }, pos = { -47.5, 5, z }, color = HUT, mat = "Brick" })
		end
		b:box({ name = "Dintel", size = { 1, 2.5, 5 }, pos = { -47.5, 8.75, 0 }, color = HUT, mat = "Brick" })
		b:box({ name = "TechoCaseta", size = { 12, 1, 15 }, pos = { -52.5, 10.5, 0 }, color = DARK })
		local hutLight = b:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -52.5, 9.8, 0 }, color = b.mirrored and PINK or CYAN, mat = "Neon", folder = "Decoracion" })
		MB.light(hutLight, "Point", { color = b.mirrored and PINK or CYAN, brightness = 1.5, range = 14 })

		-- Soportes de la valla y escaleras de mano
		b:box({ name = "Poste", size = { 1, 22, 1 }, pos = { -12, 11, 0 }, color = METAL, mat = "Metal" })
		for _, z in ipairs({ -1.6, 1.6 }) do
			b:box({ name = "Pata", size = { 0.8, 8, 0.8 }, pos = { -8, 4, z }, color = METAL, mat = "Metal" })
		end
		b:truss({ name = "Escalera", size = { 2, 8, 2 }, pos = { -15, 4, 0 }, color = METAL })
		b:box({ name = "Neon", size = { 0.3, 11, 1.2 }, pos = { -15.15, 16.5, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })

		-- Cobertura: aires acondicionados, depósito de agua, tragaluz, jardinera
		P.acUnit(b, { -24, 0, -22 }, 0)
		P.acUnit(b, { -40, 0, -26 }, 90)
		P.acUnit(b, { -22, 0, 14 }, 0)
		for _, o in ipairs({ { -3.2, -3.2 }, { 3.2, -3.2 }, { -3.2, 3.2 }, { 3.2, 3.2 } }) do
			b:box({ name = "Pata", size = { 0.8, 6.5, 0.8 }, pos = { -36 + o[1], 3.25, 26 + o[2] }, color = METAL, mat = "Metal" })
		end
		b:box({ name = "Base", size = { 8, 0.5, 8 }, pos = { -36, 6.75, 26 }, color = METAL, mat = "DiamondPlate" })
		b:cylinder({ name = "Deposito", length = 8, diameter = 8.5, pos = { -36, 11, 26 }, color = { 122, 96, 76 }, mat = "WoodPlanks" })
		for _, y in ipairs({ 8.5, 13.5 }) do
			b:cylinder({ name = "Aro", length = 0.3, diameter = 8.7, pos = { -36, y, 26 }, color = { 60, 60, 66 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Tragaluz", size = { 8.6, 1, 8.6 }, pos = { -12, 0.5, -26 }, color = DARK })
		b:box({ name = "Cristal", size = { 8, 0.6, 8 }, pos = { -12, 1.3, -26 }, color = { 150, 180, 230 }, mat = "Glass", transparency = 0.3 })
		b:box({ name = "Jardinera", size = { 10, 3, 3 }, pos = { -28, 1.5, -4 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Plantas", size = { 9.4, 0.5, 2.4 }, pos = { -28, 3.2, -4 }, color = { 70, 110, 70 }, mat = "LeafyGrass" })
		P.crate(b, { -8, 0, 22 }, 4.5)
		P.crate(b, { -8, 0, 27 }, 4.5, 12)
		P.crate(b, { -8, 4.5, 24.5 }, 4)

		-- Tubería en el suelo y antena parabólica
		b:cylinder({ name = "Tuberia", axis = "z", length = 60, diameter = 1.4, pos = { -44, 0.9, 6 }, color = { 120, 124, 132 }, mat = "Metal" })
		b:cylinder({ name = "Antena", length = 3, diameter = 0.6, pos = { -55, 1.5, 33 }, color = METAL, folder = "Decoracion" })
		b:cylinder({ name = "Plato", axis = "x", length = 0.5, diameter = 5, pos = { -55, 3.6, 33 }, rot = { 0, 0, 35 }, color = { 210, 212, 218 }, folder = "Decoracion" })

		for _, z in ipairs({ -3, 0, 3 }) do
			b:spawn("A", { -54, 0.5, z }, -90)
		end
	end)

	b:bounds(-60, 60, -40, 40, 30)

	b:lighting({
		lighting = {
			ClockTime = 0.2,
			Brightness = 1.2,
			Ambient = { 72, 62, 104 },
			OutdoorAmbient = { 82, 72, 124 },
			ExposureCompensation = 0.35,
			EnvironmentDiffuseScale = 0.4,
		},
		atmosphere = { density = 0.3, color = { 112, 82, 162 }, decay = { 62, 42, 112 }, haze = 1.5, glare = 0 },
		colorCorrection = { contrast = 0.1, saturation = 0.2, tint = { 236, 226, 255 } },
	})
end
