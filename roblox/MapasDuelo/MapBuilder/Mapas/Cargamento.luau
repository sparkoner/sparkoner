-- Cargamento (estilo Shipment de Call of Duty): patio de contenedores muy pequeño para duelos rápidos
-- y caóticos, al amanecer con lluvia. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 112, 112, 116 }
	local YELLOW = { 236, 190, 40 }
	local COLORS = { { 176, 60, 46 }, { 46, 96, 150 }, { 70, 120, 80 }, { 200, 130, 40 }, { 120, 120, 128 }, { 150, 70, 110 } }

	b.model:SetAttribute("Nombre", "Cargamento")

	-- =================================================================
	--  Puerto al fondo: agua, grúas y barco
	-- =================================================================
	b:box({ name = "Agua", size = { 900, 1, 900 }, pos = { 0, -3, 0 }, color = { 50, 80, 96 }, mat = "Glass", reflectance = 0.2, folder = "Decoracion" })
	b:box({ name = "Muelle", size = { 260, 3, 200 }, pos = { 0, -1.5, 20 }, color = { 96, 96, 100 }, mat = "Concrete", folder = "Decoracion" })
	for _, x in ipairs({ -90, -30, 30, 90 }) do
		for _, z in ipairs({ 110, 140 }) do
			b:box({ name = "Grua", size = { 3, 60, 3 }, pos = { x, 30, z }, color = { 210, 80, 50 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Grua", size = { 4, 4, 90 }, pos = { x, 62, 120 }, color = { 210, 80, 50 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Cabina", size = { 6, 5, 6 }, pos = { x, 57, 126 }, color = { 230, 230, 226 }, mat = "Metal", folder = "Decoracion" })
	end
	b:box({ name = "Barco", size = { 220, 18, 36 }, pos = { 0, 6, 150 }, color = { 40, 50, 66 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Puente", size = { 24, 26, 30 }, pos = { 90, 28, 150 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })

	-- =================================================================
	--  Suelo del patio y contenedor central
	-- =================================================================
	b:box({ name = "Suelo", size = { 76, 1, 64 }, pos = { 0, -0.5, 0 }, color = FLOOR, mat = "Concrete" })
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 76, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = YELLOW, folder = "Decoracion" })
	end
	P.container(b, { 0, 0, 0 }, 90, { 176, 60, 46 }, false, "CARGO 07")

	b:symmetric(function(b)
		-- Contenedores del patio (uno abierto se puede atravesar)
		P.container(b, { -14, 0, -21 }, 0, COLORS[2], false, "NAVIERA")
		P.container(b, { -14, 0, 21 }, 0, COLORS[3], true, "TUNEL")
		P.container(b, { -25, 0, 0 }, 90, COLORS[4], false, "EXPORT")

		-- Cobertura pequeña
		P.crate(b, { -13, 0, -6 }, 4.5, 15)
		P.crate(b, { -10, 0, 8 }, 4, -20)
		P.crate(b, { -10, 4, 8 }, 3, 10)
		P.drum(b, { -6, 0, -13 }, { 46, 96, 150 })
		P.drum(b, { -3.6, 0, -12.2 }, { 200, 60, 50 })
		P.pallet(b, { -18, 0, 12 }, 20)
		P.cardboard(b, { -18, 0.6, 12 }, { 3, 2.4, 2.6 }, 20)
		P.puddle(b, { -20, 0, -8 }, 5)
		P.puddle(b, { -6, 0, 18 }, 4)
		P.manhole(b, { -30, 0, -20 })

		-- Muro de contenedores apilados alrededor (fuera de los límites)
		for i, x in ipairs({ -31.5, -10.5 }) do
			for _, z in ipairs({ -36.5, 36.5 }) do
				P.container(b, { x, 0, z }, 0, COLORS[(i + (z > 0 and 2 or 0)) % 6 + 1], false)
				P.container(b, { x + 6, 9, z }, 0, COLORS[(i + (z > 0 and 3 or 1)) % 6 + 1], false)
			end
		end
		for i, z in ipairs({ -21, 0, 21 }) do
			P.container(b, { -42.5, 0, z }, 90, COLORS[(i + 3) % 6 + 1], false)
		end
		for i, z in ipairs({ -10.5, 10.5 }) do
			P.container(b, { -42.5, 9, z }, 90, COLORS[(i + 1) % 6 + 1], false)
		end

		-- Focos en las esquinas
		P.floodLight(b, { -36, 0, -31 }, 45, 18)
		P.floodLight(b, { -36, 0, 31 }, 135, 18)

		for _, z in ipairs({ -5, 0, 5 }) do
			b:spawn("A", { -33, 0.5, z }, -90)
		end
	end)

	b:bounds(-37, 37, -31, 31, 30)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 6.3,
			Brightness = 1.4,
			Ambient = { 92, 98, 112 },
			OutdoorAmbient = { 120, 128, 146 },
			ExposureCompensation = 0.3,
			ShadowSoftness = 0.5,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.7,
		},
		atmosphere = { density = 0.4, offset = 0.15, color = { 170, 180, 196 }, decay = { 100, 110, 130 }, glare = 0.3, haze = 2.4 },
		colorCorrection = { contrast = 0.1, saturation = -0.1, tint = { 236, 242, 255 } },
		clouds = { cover = 0.9, density = 0.75, color = { 170, 176, 190 } },
		bloom = { intensity = 0.5, size = 24, threshold = 0.88 },
		sunRays = { intensity = 0.04, spread = 0.4 },
	})
end
