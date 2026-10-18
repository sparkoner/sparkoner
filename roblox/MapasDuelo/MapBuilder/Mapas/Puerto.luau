-- Puerto de contenedores a mediodía. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local CONCRETE = { 162, 160, 154 }
	local LANE = { 236, 196, 40 }
	local RED = { 176, 58, 46 }
	local BLUE = { 48, 92, 150 }
	local GREEN = { 60, 120, 80 }
	local ORANGE = { 214, 120, 40 }
	local GREY = { 130, 134, 140 }
	local CRANE = { 236, 186, 36 }

	b.model:SetAttribute("Nombre", "Puerto de Contenedores")

	-- Mar y muelle
	b:box({ name = "Mar", size = { 800, 1, 800 }, pos = { 0, -8, 0 }, color = { 54, 98, 124 }, reflectance = 0.2, folder = "Decoracion" })
	b:box({ name = "Muelle", size = { 156, 1, 108 }, pos = { 0, -0.5, 0 }, color = CONCRETE, mat = "Concrete" })
	for _, z in ipairs({ -54.5, 54.5 }) do
		b:box({ name = "Borde", size = { 158, 8, 1 }, pos = { 0, -4, z }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
	end
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 150, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = LANE, folder = "Decoracion" })
	end

	-- Centro: dos contenedores y una pila de cajas en medio
	P.container(b, { 0, 0, 34 }, 0, GREY)
	P.container(b, { 0, 0, -34 }, 0, ORANGE)

	-- Grúa pórtico con un contenedor colgando (decoración)
	for _, x in ipairs({ -11, 11 }) do
		b:box({ name = "Viga", size = { 2.5, 3, 94.5 }, pos = { x, 35.5, 0 }, color = CRANE, mat = "Metal" })
	end
	for _, z in ipairs({ -46, 46 }) do
		b:box({ name = "Viga", size = { 24.5, 3, 2.5 }, pos = { 0, 35.5, z }, color = CRANE, mat = "Metal" })
	end
	b:box({ name = "Carro", size = { 24, 3, 6 }, pos = { 0, 32.5, -4 }, color = CRANE, mat = "Metal" })
	b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 6, 29, -4 }, color = { 200, 205, 210 }, mat = "Metal" })
	for _, x in ipairs({ -3, 3 }) do
		b:cylinder({ name = "Cable", length = 7, diameter = 0.3, pos = { x, 27.5, -4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	end
	P.container(b, { 0, 15, -4 }, 0, BLUE)

	b:symmetric(function(b)
		-- Patas de la grúa
		for _, z in ipairs({ -46, 46 }) do
			b:box({ name = "Pata", size = { 2.5, 34, 2.5 }, pos = { -11, 17, z }, color = CRANE, mat = "Metal" })
		end
		b:box({ name = "Borde", size = { 1, 8, 108 }, pos = { -78.5, -4, 0 }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 0.6, 0.12, 100 }, pos = { -40, 0.06, 0 }, color = LANE, folder = "Decoracion" })

		-- Pila de cajas en el centro
		P.crate(b, { -3, 0, 1 }, 5)
		P.crate(b, { -3, 5, 1 }, 5, 10)

		-- Muro de contenedores que protege el spawn (se sale por los huecos)
		P.container(b, { -58, 0, -26 }, 90, BLUE)
		P.container(b, { -58, 0, 26 }, 90, RED)
		P.container(b, { -46, 0, 0 }, 90, b.mirrored and GREEN or ORANGE)

		-- Contenedor abierto (túnel) y pila de dos
		P.container(b, { -28, 0, 0 }, 0, GREEN, true)
		P.container(b, { -34, 0, -30 }, 0, RED)
		P.container(b, { -34, 9, -30 }, 0, b.mirrored and ORANGE or BLUE)

		-- Contenedor con rampa para ganar altura
		P.container(b, { -34, 0, 30 }, 0, GREEN)
		b:wedge({ name = "Rampa", size = { 8.5, 9, 12 }, pos = { -17.5, 4.5, 30 }, rot = { 0, -90, 0 }, color = { 120, 116, 110 }, mat = "DiamondPlate" })

		-- Contenedor a media distancia
		P.container(b, { -12, 0, -16 }, 90, GREY)

		-- Bidones, palés y carretilla elevadora
		P.drum(b, { -24, 0, 12 }, BLUE)
		P.drum(b, { -21.4, 0, 12.6 }, RED)
		P.drum(b, { -23, 0, 14.9 }, BLUE)
		P.pallet(b, { -48, 0, 40 }, 0)
		P.crate(b, { -48, 0.8, 40 }, 3.5)
		P.pallet(b, { -42, 0, 42 }, 30)

		local f = b:at({ -50, 0, -42 }, 0)
		f:box({ name = "Carretilla", size = { 4.5, 3.5, 6 }, pos = { 0, 2.2, 0 }, color = ORANGE })
		f:box({ name = "Mastil", size = { 3.4, 9, 0.6 }, pos = { 0, 4.8, -3.4 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Horquilla", size = { 0.5, 0.3, 4 }, pos = { -1, 0.4, -5.6 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Horquilla", size = { 0.5, 0.3, 4 }, pos = { 1, 0.4, -5.6 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Techo", size = { 4.2, 0.3, 3.6 }, pos = { 0, 7, 0.8 }, color = { 60, 60, 66 }, mat = "Metal" })
		for _, w in ipairs({ { -2.3, -2 }, { 2.3, -2 }, { -2.3, 2 }, { 2.3, 2 } }) do
			f:cylinder({ name = "Rueda", axis = "x", length = 0.8, diameter = 1.8, pos = { w[1], 0.9, w[2] }, color = { 30, 30, 32 } })
		end

		-- Farolas y bolardos del borde del muelle
		for _, z in ipairs({ -46, 46 }) do
			b:cylinder({ name = "Farola", length = 24, diameter = 1, pos = { -70, 12, z }, color = { 90, 94, 100 }, mat = "Metal" })
			b:box({ name = "Lampara", size = { 3, 0.6, 1.5 }, pos = { -69, 24, z }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for x = -66, -6, 12 do
			b:cylinder({ name = "Bolardo", length = 1.6, diameter = 1.2, pos = { x, 0.8, -52.5 }, color = { 40, 40, 46 }, mat = "Metal" })
		end

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -68, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -52, 52, 40)

	b:lighting({
		lighting = {
			ClockTime = 13.2,
			Brightness = 2.2,
			Ambient = { 120, 125, 130 },
			OutdoorAmbient = { 140, 145, 150 },
			ShadowSoftness = 0.25,
		},
		atmosphere = { density = 0.3, color = { 200, 212, 222 }, decay = { 122, 132, 152 }, haze = 1.2, glare = 0.2 },
		colorCorrection = { contrast = 0.05, saturation = -0.05, tint = { 246, 248, 255 } },
		clouds = { cover = 0.78, density = 0.5, color = { 226, 230, 236 } },
	})
end
