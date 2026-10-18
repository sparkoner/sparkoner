-- Pueblo Nuclear (estilo Nuketown de Call of Duty): dos casas enfrentadas en un pueblo de pruebas
-- en el desierto. Se puede entrar en las casas y subir al balcón. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local LAWN = { 118, 168, 80 }
	local WHITE = { 244, 244, 238 }
	local GREEN_TREES = { { 86, 140, 66 }, { 100, 156, 74 }, { 76, 126, 60 } }

	b.model:SetAttribute("Nombre", "Pueblo Nuclear")

	-- =================================================================
	--  Desierto, mesetas y torre de pruebas
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 214, 184, 134 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -220, 200, 140, 34 }, { 200, 240, 160, 40 }, { 320, 40, 110, 28 }, { -330, -40, 120, 36 }, { 60, -250, 150, 30 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 196, 120, 82 }, mat = "Sandstone", folder = "Decoracion" })
	end
	local steel = { 120, 124, 132 }
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		P.segment(b, { c[1] * 9, 0, 230 + c[2] * 9 }, { c[1] * 2.5, 90, 230 + c[2] * 2.5 }, 1.2, steel, "Metal", "Decoracion")
	end
	for _, y in ipairs({ 20, 40, 60, 80 }) do
		local half = 9 - (6.5 * y / 90)
		for _, c in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
			P.segment(b, { c[1] * half, y, 230 + c[2] * half }, { c[3] * half, y, 230 + c[4] * half }, 0.6, steel, "Metal", "Decoracion")
		end
	end
	b:box({ name = "Cabina", size = { 9, 8, 9 }, pos = { 0, 94, 230 }, color = { 200, 196, 186 }, mat = "Metal", folder = "Decoracion" })
	local warn = b:box({ name = "Aviso", size = { 30, 8, 1 }, pos = { 40, 10, 190 }, color = { 250, 210, 40 }, folder = "Decoracion" })
	MB.sign(warn, "☢ ZONA DE PRUEBAS ☢", { font = "GothamBlack", color = { 30, 30, 30 }, bg = { 250, 210, 40 } })

	-- =================================================================
	--  Césped, calle, autobús, camión y cartel de bienvenida
	-- =================================================================
	b:box({ name = "Cesped", size = { 152, 1, 92 }, pos = { 0, -0.5, 0 }, color = LAWN, mat = "Grass" })
	b:box({ name = "Calle", size = { 34, 0.1, 92 }, pos = { 0, 0.05, 0 }, color = { 82, 82, 86 }, mat = "Asphalt", folder = "Decoracion" })
	for z = -42, 42, 8 do
		b:box({ name = "Linea", size = { 0.5, 0.12, 4 }, pos = { 0, 0.07, z }, color = { 246, 200, 50 }, folder = "Decoracion" })
	end
	P.bus(b, { 1.45, 0, 24 }, 90, { 246, 190, 30 }, "ESCUELA")
	local cargo = P.truck(b, { -2.4, 0, -24 }, 90, { 236, 236, 232 })
	for _, face in ipairs({ "Left", "Right" }) do
		MB.sign(cargo, "LECHE FRESCA", { face = face, font = "LuckiestGuy", color = { 60, 120, 200 }, height = 0.4 })
	end
	for _, x in ipairs({ -10, 10 }) do
		b:box({ name = "Poste", size = { 1, 14, 1 }, pos = { x, 7, 44 }, color = { 110, 84, 60 }, mat = "Wood", folder = "Decoracion" })
	end
	local welcome = b:box({ name = "Cartel", size = { 24, 6, 0.6 }, pos = { 0, 11, 44 }, color = { 240, 236, 220 }, folder = "Decoracion" })
	MB.sign(welcome, "PUEBLO NUCLEAR · POBLACIÓN 50", { font = "LuckiestGuy", color = { 200, 60, 50 }, bg = { 240, 236, 220 }, width = 0.9, height = 0.6 })
	P.mannequin(b, { -4, 0, 10 }, 30, { 220, 70, 70 })
	P.mannequin(b, { 6, 0, -12 }, -150, { 70, 150, 90 })

	b:symmetric(function(b)
		local mine = not b.mirrored
		-- Casa (se puede entrar, con escalera y balcón)
		P.openHouse(b, { -42, 0, 0 }, -90, {
			color = mine and { 112, 170, 210 } or { 236, 200, 96 },
			trim = WHITE,
			roofColor = mine and { 70, 90, 120 } or { 150, 70, 50 },
			sofa = mine and { 200, 80, 70 } or { 60, 110, 170 },
		})
		P.sidewalk(b, { -18.5, 0, 0 }, { 92, 3 }, -90)

		-- Entrada de coches con coche y caravana
		b:box({ name = "Entrada", size = { 30, 0.1, 10 }, pos = { -35, 0.06, 20 }, color = { 176, 172, 166 }, mat = "Concrete", folder = "Decoracion" })
		P.car(b, { -36, 0, 20 }, -90, mine and { 210, 60, 60 } or { 60, 160, 150 })
		b:box({ name = "Caravana", size = { 16, 7, 7 }, pos = { -48, 4.4, 36 }, color = { 240, 236, 226 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 16.1, 1, 7.1 }, pos = { -48, 4.4, 36 }, color = mine and { 80, 140, 200 } or { 220, 150, 50 }, folder = "Decoracion" })
		for _, x in ipairs({ -52, -44 }) do
			b:cylinder({ name = "Rueda", axis = "z", length = 7.4, diameter = 2, pos = { x, 1, 36 }, color = { 30, 30, 32 }, mat = "Rubber" })
		end

		-- Cobertizo y cajas al sur
		b:box({ name = "Cobertizo", size = { 10, 8, 8 }, pos = { -48, 4, -36 }, color = { 150, 110, 76 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 11, 2, 4.6 }, pos = { -48, 9, -38.3 }, color = { 90, 70, 60 }, mat = "RoofShingles" })
		b:wedge({ name = "Tejado", size = { 11, 2, 4.6 }, pos = { -48, 9, -33.7 }, rot = { 0, 180, 0 }, color = { 90, 70, 60 }, mat = "RoofShingles" })
		P.crate(b, { -36, 0, -34 }, 4.5, 15)
		P.crate(b, { -33, 0, -40 }, 4, -10)

		-- Jardín delantero: maniquíes, buzón y árbol
		P.mannequin(b, { -24, 0, -8 }, -90, mine and { 60, 110, 180 } or { 220, 120, 40 })
		P.mannequin(b, { -26, 0, 7 }, -120, mine and { 230, 230, 230 } or { 170, 60, 140 })
		b:box({ name = "Buzon", size = { 0.4, 4, 0.4 }, pos = { -21, 2, -16 }, color = { 80, 80, 86 }, mat = "Metal" })
		b:box({ name = "Buzon", size = { 1.4, 1.2, 2.2 }, pos = { -21, 4.4, -16 }, color = mine and { 60, 110, 180 } or { 200, 60, 50 }, mat = "Metal" })
		P.tree(b, { -26, 0, -28 }, 1.1, GREEN_TREES)
		P.bush(b, { -30, 0, -14 }, 1.1)
		P.bush(b, { -30, 0, 14 }, 1.1)

		-- Patio trasero: valla blanca, columpio, barbacoa y caseta del perro
		P.woodFence(b, { -76, 0, -30 }, { -52, 0, -30 }, 4, WHITE)
		P.woodFence(b, { -76, 0, 30 }, { -54, 0, 30 }, 4, WHITE)
		for _, z in ipairs({ -24, -16 }) do
			P.segment(b, { -66, 0, z }, { -64, 9, z }, 0.4, { 200, 60, 60 }, "Metal")
			P.segment(b, { -62, 0, z }, { -64, 9, z }, 0.4, { 200, 60, 60 }, "Metal")
		end
		b:cylinder({ name = "Barra", axis = "z", length = 9, diameter = 0.4, pos = { -64, 9, -20 }, color = { 200, 60, 60 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Columpio", size = { 1.6, 0.3, 1 }, pos = { -64, 2.4, -20 }, color = { 60, 60, 66 }, folder = "Decoracion" })
		b:box({ name = "Barbacoa", size = { 3, 3, 2 }, pos = { -58, 1.5, 22 }, color = { 40, 40, 44 }, mat = "Metal" })
		b:box({ name = "Caseta", size = { 4, 3.6, 4 }, pos = { -70, 1.8, 22 }, color = { 180, 80, 60 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 4.6, 1.4, 2.3 }, pos = { -70, 4.3, 20.85 }, color = { 80, 60, 50 }, folder = "Decoracion" })
		b:wedge({ name = "Tejado", size = { 4.6, 1.4, 2.3 }, pos = { -70, 4.3, 23.15 }, rot = { 0, 180, 0 }, color = { 80, 60, 50 }, folder = "Decoracion" })

		for _, z in ipairs({ -3.5, 0, 3.5 }) do
			b:spawn("A", { -66, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -46, 46, 45)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 10.5,
			Brightness = 3,
			Ambient = { 128, 120, 110 },
			OutdoorAmbient = { 170, 160, 140 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.15,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.25, offset = 0.05, color = { 232, 216, 190 }, decay = { 170, 140, 110 }, glare = 0.4, haze = 1.4 },
		colorCorrection = { contrast = 0.08, saturation = 0.2, tint = { 255, 250, 240 } },
		clouds = { cover = 0.3, density = 0.4, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
