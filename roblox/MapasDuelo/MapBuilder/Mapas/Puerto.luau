-- Puerto de contenedores a mediodía. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local CONCRETE = { 164, 162, 156 }
	local LANE = { 236, 196, 40 }
	local RED = { 176, 58, 46 }
	local BLUE = { 48, 92, 150 }
	local GREEN = { 60, 120, 80 }
	local ORANGE = { 214, 120, 40 }
	local GREY = { 130, 134, 140 }
	local TEAL = { 40, 130, 140 }
	local CRANE = { 236, 186, 36 }
	local STACK_COLORS = { RED, BLUE, GREEN, ORANGE, GREY, TEAL, { 230, 230, 226 } }

	b.model:SetAttribute("Nombre", "Puerto de Contenedores")

	-- =================================================================
	--  Mar, barco atracado y grúas al fondo
	-- =================================================================
	b:box({ name = "Mar", size = { 900, 1, 900 }, pos = { 0, -8, 0 }, color = { 50, 96, 122 }, reflectance = 0.25, folder = "Decoracion" })
	-- Casco
	b:box({ name = "Casco", size = { 150, 20, 30 }, pos = { 0, -3, -84 }, color = { 40, 52, 70 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Linea", size = { 150.4, 3, 30.4 }, pos = { 0, -6, -84 }, color = { 170, 40, 36 }, mat = "Metal", folder = "Decoracion" })
	b:wedge({ name = "Proa", size = { 30, 20, 18 }, pos = { 84, -3, -84 }, rot = { 0, -90, 0 }, color = { 40, 52, 70 }, mat = "Metal", folder = "Decoracion" })
	local hull = b:box({ name = "Nombre", size = { 40, 4, 0.2 }, pos = { -20, 3, -68.9 }, color = { 40, 52, 70 }, transparency = 1, folder = "Decoracion" })
	MB.sign(hull, "OCEANIX", { face = "Back", font = "GothamBlack", color = { 240, 240, 236 } })
	b:box({ name = "Puente", size = { 16, 18, 22 }, pos = { -60, 16, -84 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })
	for y = 10, 22, 4 do
		b:box({ name = "Ventanas", size = { 16.2, 1.4, 22.2 }, pos = { -60, y, -84 }, color = { 40, 60, 80 }, mat = "Glass", folder = "Decoracion" })
	end
	b:cylinder({ name = "Chimenea", length = 8, diameter = 5, pos = { -64, 29, -84 }, color = { 170, 40, 36 }, mat = "Metal", folder = "Decoracion" })
	local i = 0
	for x = -42, 66, 9 do
		for row = 0, 2 do
			local height = 1 + ((x + row) % 3)
			for level = 0, height - 1 do
				i = i + 1
				local c = STACK_COLORS[(i % #STACK_COLORS) + 1]
				b:box({ name = "Carga", size = { 8.5, 8.5, 9 }, pos = { x, 11.25 + level * 8.6, -94 + row * 9.4 }, color = c, mat = "Metal", folder = "Decoracion" })
			end
		end
	end
	-- Grúas portacontenedores (silueta)
	for _, x in ipairs({ -95, 95 }) do
		for _, z in ipairs({ -60, -40 }) do
			b:box({ name = "PataGrua", size = { 3, 60, 3 }, pos = { x - 10, 30, z }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
			b:box({ name = "PataGrua", size = { 3, 60, 3 }, pos = { x + 10, 30, z }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Pluma", size = { 4, 4, 90 }, pos = { x, 62, -70 }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Viga", size = { 24, 4, 4 }, pos = { x, 58, -50 }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
	end
	-- Pilas de contenedores al norte (fuera del área de juego)
	for x = -70, 70, 22 do
		for level = 0, 2 do
			if not (level == 2 and x % 44 == 4) then
				i = i + 1
				b:box({ name = "Pila", size = { 21, 9, 8.5 }, pos = { x, 4.5 + level * 9, 62 }, color = STACK_COLORS[(i % #STACK_COLORS) + 1], mat = "Metal", folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Muelle
	-- =================================================================
	b:box({ name = "Muelle", size = { 156, 1, 108 }, pos = { 0, -0.5, 0 }, color = CONCRETE, mat = "Concrete" })
	for _, z in ipairs({ -54.5, 54.5 }) do
		b:box({ name = "Borde", size = { 158, 8, 1 }, pos = { 0, -4, z }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Cantil", size = { 156, 0.5, 1.2 }, pos = { 0, 0.25, z > 0 and 53.6 or -53.6 }, color = LANE, mat = "Concrete", folder = "Decoracion" })
	end
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 150, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = LANE, folder = "Decoracion" })
	end

	-- Centro: contenedores rotulados y pila de cajas
	P.container(b, { 0, 0, 34 }, 0, GREY, false, "TRANSATLAS")
	P.container(b, { 0, 0, -34 }, 0, ORANGE, false, "OCEANIX")

	-- Grúa pórtico con celosía y contenedor colgando
	for _, x in ipairs({ -11, 11 }) do
		b:box({ name = "Viga", size = { 2.5, 3, 94.5 }, pos = { x, 35.5, 0 }, color = CRANE, mat = "Metal" })
	end
	for _, z in ipairs({ -46, 46 }) do
		b:box({ name = "Viga", size = { 24.5, 3, 2.5 }, pos = { 0, 35.5, z }, color = CRANE, mat = "Metal" })
		P.segment(b, { -11, 23, z }, { 0, 34, z }, 0.8, CRANE, "Metal", "Decoracion")
		P.segment(b, { 11, 23, z }, { 0, 34, z }, 0.8, CRANE, "Metal", "Decoracion")
	end
	b:box({ name = "Carro", size = { 24, 3, 6 }, pos = { 0, 32.5, -4 }, color = CRANE, mat = "Metal" })
	b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 6, 29, -4 }, color = { 200, 205, 210 }, mat = "Metal" })
	b:box({ name = "Cristal", size = { 5.1, 1.6, 5.1 }, pos = { 6, 29.4, -4 }, color = { 40, 60, 80 }, mat = "Glass", folder = "Decoracion" })
	for _, x in ipairs({ -3, 3 }) do
		b:cylinder({ name = "Cable", length = 7, diameter = 0.3, pos = { x, 27.5, -4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	end
	P.container(b, { 0, 15, -4 }, 0, BLUE, false, "NAVIERA SUR")

	b:symmetric(function(b)
		-- Patas de la grúa con franjas de peligro
		for _, z in ipairs({ -46, 46 }) do
			b:box({ name = "Pata", size = { 2.5, 34, 2.5 }, pos = { -11, 17, z }, color = CRANE, mat = "Metal" })
			b:box({ name = "Base", size = { 5, 1.4, 5 }, pos = { -11, 0.7, z }, color = { 70, 72, 78 }, mat = "Metal" })
			for k = 0, 4 do
				b:box({ name = "Peligro", size = { 1.1, 0.06, 7 }, pos = { -13.6 + k * 1.3, 0.04, z }, rot = { 0, 30, 0 }, color = (k % 2 == 0) and LANE or { 30, 30, 32 }, folder = "Decoracion" })
			end
			P.segment(b, { -11, 2, z }, { -11, 20, z > 0 and z - 10 or z + 10 }, 0.8, CRANE, "Metal", "Decoracion")
		end
		b:box({ name = "Borde", size = { 1, 8, 108 }, pos = { -78.5, -4, 0 }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 0.6, 0.12, 100 }, pos = { -40, 0.06, 0 }, color = LANE, folder = "Decoracion" })

		-- Pila de cajas en el centro
		P.crate(b, { -3, 0, 1 }, 5)
		P.crate(b, { -3, 5, 1 }, 5, 10)

		-- Muro de contenedores que protege el spawn (se sale por los huecos)
		P.container(b, { -58, 0, -26 }, 90, BLUE, false, "OCEANIX")
		P.container(b, { -58, 0, 26 }, 90, RED, false, "TRANSATLAS")
		P.container(b, { -46, 0, 0 }, 90, b.mirrored and GREEN or ORANGE)

		-- Contenedor abierto (túnel) y pila de dos
		P.container(b, { -28, 0, 0 }, 0, GREEN, true)
		P.container(b, { -34, 0, -30 }, 0, RED)
		P.container(b, { -34, 9, -30 }, 0, b.mirrored and ORANGE or BLUE, false, "NAVIERA SUR")

		-- Contenedor con rampa para ganar altura
		P.container(b, { -34, 0, 30 }, 0, GREEN)
		b:wedge({ name = "Rampa", size = { 8.5, 9, 12 }, pos = { -17.5, 4.5, 30 }, rot = { 0, -90, 0 }, color = { 120, 116, 110 }, mat = "DiamondPlate" })
		for _, z in ipairs({ 25.6, 34.4 }) do
			b:wedge({ name = "Lateral", size = { 0.4, 9.2, 12 }, pos = { -17.5, 4.6, z }, rot = { 0, -90, 0 }, color = LANE, folder = "Decoracion" })
		end

		-- Contenedor a media distancia
		P.container(b, { -12, 0, -16 }, 90, GREY)

		-- Bidones, palés, bobinas y carretilla elevadora
		P.drum(b, { -24, 0, 12 }, BLUE)
		P.drum(b, { -21.4, 0, 12.6 }, RED)
		P.drum(b, { -23, 0, 14.9 }, BLUE)
		P.pallet(b, { -48, 0, 40 }, 0)
		P.crate(b, { -48, 0.8, 40 }, 3.5)
		P.pallet(b, { -42, 0, 42 }, 30)
		P.cardboard(b, { -42, 0.8, 42 }, { 3.4, 2.4, 3 }, 30)
		P.cableReel(b, { -22, 0, -40 }, 0)
		P.forklift(b, { -50, 0, -42 }, 0, b.mirrored and { 230, 160, 30 } or { 214, 120, 40 })
		P.cone(b, { -40, 0, -14 })
		P.cone(b, { -38, 0, -14.6 })
		P.barrier(b, { -30, 0, 14 }, 0)

		-- Caseta de control junto al spawn
		local booth = b:at({ -70, 0, -42 }, 0)
		booth:box({ name = "Caseta", size = { 7, 7, 6 }, pos = { 0, 3.5, 0 }, color = { 230, 230, 226 }, mat = "Plaster" })
		booth:box({ name = "Cristal", size = { 7.1, 2.2, 6.1 }, pos = { 0, 4.6, 0 }, color = { 60, 90, 120 }, mat = "Glass", transparency = 0.2, folder = "Decoracion" })
		booth:box({ name = "Tejado", size = { 8.4, 0.6, 7.4 }, pos = { 0, 7.3, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		P.poster(booth, { 0, 6.3, -3.06 }, 0, { 4, 0.9 }, { 40, 90, 160 }, "CONTROL", { 255, 255, 255 }, "GothamBlack")

		-- Torres de focos y bolardos con defensas en el borde del muelle
		P.floodLight(b, { -70, 0, 46 }, 180, 22)
		for x = -66, -6, 12 do
			b:cylinder({ name = "Bolardo", length = 1.6, diameter = 1.2, pos = { x, 0.8, -52.6 }, color = { 40, 40, 46 }, mat = "Metal" })
			b:ball({ name = "Cabeza", diameter = 1.5, pos = { x, 1.7, -52.6 }, color = { 40, 40, 46 }, mat = "Metal", folder = "Decoracion" })
			b:cylinder({ name = "Defensa", axis = "x", length = 1.2, diameter = 3, pos = { x + 6, -1.6, -54.7 }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
		end

		-- Números de las calles pintados en el suelo
		for k, pos in ipairs({ { -36, -14 }, { -36, 14 }, { -8, 8 } }) do
			local mark = b:box({ name = "Marca", size = { 6, 0.05, 3 }, pos = { pos[1], 0.03, pos[2] + 4 }, color = CONCRETE, transparency = 1, folder = "Decoracion" })
			MB.sign(mark, (b.mirrored and "B" or "A") .. k, { face = "Top", font = "GothamBlack", color = LANE })
		end
		P.stain(b, { -26, 0, -6 }, 5)
		P.puddle(b, { -48, 0, -20 }, 7)
		P.manhole(b, { -20, 0, 22 })

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -68, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 13.2,
			Brightness = 2.4,
			Ambient = { 122, 127, 132 },
			OutdoorAmbient = { 142, 147, 152 },
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, color = { 200, 212, 222 }, decay = { 122, 132, 152 }, haze = 1.2, glare = 0.3 },
		colorCorrection = { contrast = 0.08, saturation = 0.02, tint = { 246, 248, 255 } },
		clouds = { cover = 0.7, density = 0.5, color = { 226, 230, 236 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.5 },
	})
end
