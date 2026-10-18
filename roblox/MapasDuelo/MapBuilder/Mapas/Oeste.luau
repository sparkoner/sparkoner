-- Pueblo del Oeste (como en las películas de vaqueros): calle principal polvorienta a mediodía,
-- saloon, banco, sheriff y carretas. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local DIRT = { 196, 160, 112 }
	local BOARD = { 140, 104, 70 }
	local DARK = { 90, 62, 42 }

	b.model:SetAttribute("Nombre", "Pueblo del Oeste")

	-- Edificio de madera con fachada falsa, rótulo y porche (side = 1 norte, -1 sur)
	local function building(x, side, w, h, color, sign, signColor)
		local z = side * 31
		local rot = side > 0 and 0 or 180
		P.house(b, { x, 0, z }, rot, { w = w, h = h, d = 14, color = color, mat = "WoodPlanks", trim = P.darker(color, 50), floors = h >= 14 and 2 or 1, balcony = h >= 14, shutters = h < 14 and P.darker(color, 40) or nil })
		local g = b:at({ x, 0, z }, rot)
		g:box({ name = "Fachada", size = { w, 5, 0.6 }, pos = { 0, h + 2.5, -6.9 }, color = color, mat = "WoodPlanks" })
		g:box({ name = "Remate", size = { w + 0.6, 0.6, 0.9 }, pos = { 0, h + 5.2, -6.9 }, color = P.darker(color, 50), mat = "Wood", folder = "Decoracion" })
		local panel = g:box({ name = "Rotulo", size = { w - 2, 3, 0.2 }, pos = { 0, h + 2.5, -7.3 }, color = signColor, folder = "Decoracion" })
		MB.sign(panel, sign, { font = "Fantasy", color = { 250, 236, 200 }, bg = signColor })
		g:box({ name = "Porche", size = { w, 0.5, 5.4 }, pos = { 0, 8.6, -9.7 }, color = DARK, mat = "WoodPlanks" })
		for _, px in ipairs({ -w / 2 + 0.6, w / 2 - 0.6 }) do
			g:box({ name = "Poste", size = { 0.6, 8.4, 0.6 }, pos = { px, 4.2, -12 }, color = DARK, mat = "Wood" })
		end
	end

	-- =================================================================
	--  Desierto con mesetas, cactus y cielo
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 212, 172, 120 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -200, 170, 130, 46 }, { 150, 220, 170, 60 }, { 300, 60, 110, 40 }, { -320, -40, 130, 50 }, { 20, -230, 160, 44 }, { -180, -200, 110, 36 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 186, 100, 66 }, mat = "Sandstone", folder = "Decoracion" })
		b:box({ name = "Meseta", size = { m[3] * 0.7, 6, m[3] * 0.5 }, pos = { m[1], m[4] + 2, m[2] }, color = { 170, 90, 60 }, mat = "Sandstone", folder = "Decoracion" })
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		P.cactus(b, { math.cos(a) * 120, 0, math.sin(a) * 90 }, 1.4 + (i % 3) * 0.3)
	end

	-- =================================================================
	--  Calle principal, aceras de tablas y carreta central
	-- =================================================================
	b:box({ name = "Calle", size = { 164, 1, 72 }, pos = { 0, -0.5, 0 }, color = DIRT, mat = "Ground" })
	for _, z in ipairs({ -21, 21 }) do
		b:box({ name = "Acera", size = { 152, 0.6, 6 }, pos = { 0, 0.3, z }, color = BOARD, mat = "WoodPlanks" })
	end
	P.wagon(b, { 0, 0, 0 }, 0)
	P.hayBale(b, { -4.4, 0, 7 }, 90)
	P.hayBale(b, { 4.4, 0, -7 }, 90)
	P.waterTank(b, { 0, 0, 30 })
	P.bellTower(b, { 0, 0, -34 }, 180, 24, { 236, 226, 206 }, { 120, 80, 56 })

	b:symmetric(function(b)
		local m = b.mirrored
		-- Edificios: norte y sur
		building(-66, 1, 16, 12, { 150, 110, 80 }, m and "BARBERÍA" or "HOTEL", { 120, 50, 40 })
		building(-49, 1, 18, 16, { 170, 120, 76 }, "SALOON", { 140, 40, 36 })
		building(-31, 1, 14, 12, { 120, 130, 120 }, m and "TELÉGRAFO" or "BANCO", { 40, 80, 60 })
		building(-15, 1, 16, 14, { 160, 140, 110 }, m and "HERRERÍA" or "SHERIFF", { 60, 60, 90 })
		building(-66, -1, 16, 12, { 136, 100, 72 }, m and "ESTABLO" or "ALMACÉN", { 90, 60, 40 })
		building(-49, -1, 18, 14, { 176, 150, 116 }, m and "CORREOS" or "HOTEL", { 50, 70, 120 })
		building(-31, -1, 14, 12, { 150, 96, 70 }, m and "FUNERARIA" or "DOCTOR", { 40, 40, 40 })
		building(-15, -1, 16, 16, { 166, 126, 90 }, "SALOON", { 140, 40, 36 })

		-- Puertas batientes del saloon y carteles de "se busca"
		for _, side in ipairs({ -1, 1 }) do
			for _, dx in ipairs({ -0.9, 0.9 }) do
				b:box({ name = "PuertaBatiente", size = { 1.6, 3, 0.2 }, pos = { (side > 0 and -49 or -15) + dx, 3.5, side * 23.3 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
			end
		end
		for _, p in ipairs({ { -58, 23.7, 0 }, { -24, -23.7, 180 } }) do
			P.poster(b, { p[1], 5, p[2] }, p[3], { 3, 4 }, { 236, 220, 180 }, "SE BUSCA\n$500", { 60, 40, 30 }, "Fantasy")
		end

		-- Postes para atar caballos y abrevaderos
		for _, z in ipairs({ -17.4, 17.4 }) do
			for _, x in ipairs({ -60, -42, -24 }) do
				b:box({ name = "Poste", size = { 0.5, 3.6, 0.5 }, pos = { x - 2.5, 1.8, z }, color = DARK, mat = "Wood" })
				b:box({ name = "Poste", size = { 0.5, 3.6, 0.5 }, pos = { x + 2.5, 1.8, z }, color = DARK, mat = "Wood" })
				b:box({ name = "Barra", size = { 5.6, 0.4, 0.4 }, pos = { x, 3.3, z }, color = DARK, mat = "Wood", folder = "Decoracion" })
			end
		end
		b:box({ name = "Abrevadero", size = { 6, 2.4, 2.4 }, pos = { -34, 1.2, 14 }, color = { 110, 80, 54 }, mat = "WoodPlanks" })
		b:box({ name = "Agua", size = { 5.4, 0.1, 1.8 }, pos = { -34, 2.3, 14 }, color = { 80, 130, 150 }, mat = "Glass", folder = "Decoracion" })
		b:box({ name = "Abrevadero", size = { 6, 2.4, 2.4 }, pos = { -46, 1.2, -14 }, color = { 110, 80, 54 }, mat = "WoodPlanks" })

		-- Carreta, paja, barriles y cajas
		P.wagon(b, { -40, 0, 4 }, 70, { 230, 220, 196 })
		P.hayBale(b, { -24, 0, -8 }, 10)
		P.hayBale(b, { -22, 0, -5 }, -20)
		P.hayBale(b, { -23, 2.6, -6.4 }, 0)
		P.hayBale(b, { -54, 0, 10 }, 80)
		for _, p in ipairs({ { -12, -14 }, { -9.6, -15 }, { -11, 12.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 120, 80, 50 })
		end
		P.crate(b, { -28, 0, 13 }, 4, 20, { 170, 130, 90 })
		b:ball({ name = "Rodamundos", diameter = 2.2, pos = { -36, 1.1, -4 }, color = { 170, 140, 90 }, mat = "Grass", transparency = 0.2, folder = "Decoracion" })
		b:ball({ name = "Rodamundos", diameter = 1.8, pos = { -18, 0.9, 9 }, color = { 160, 130, 84 }, mat = "Grass", transparency = 0.2, folder = "Decoracion" })

		-- Granero al final de la calle que protege el spawn
		b:box({ name = "Granero", size = { 8, 12, 30 }, pos = { -62, 6, 0 }, color = { 170, 50, 40 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 31, 3, 4.6 }, pos = { -64.3, 13.5, 0 }, rot = { 0, 90, 0 }, color = { 80, 60, 50 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 31, 3, 4.6 }, pos = { -59.7, 13.5, 0 }, rot = { 0, -90, 0 }, color = { 80, 60, 50 }, mat = "WoodPlanks" })
		for _, z in ipairs({ -5, 5 }) do
			b:box({ name = "Puerta", size = { 0.3, 9, 8 }, pos = { -57.9, 4.5, z }, color = { 150, 40, 32 }, mat = "WoodPlanks", folder = "Decoracion" })
			P.segment(b, { -57.7, 0.5, z - 3.6 }, { -57.7, 8.5, z + 3.6 }, 0.5, { 240, 236, 226 }, "WoodPlanks", "Decoracion")
			P.segment(b, { -57.7, 0.5, z + 3.6 }, { -57.7, 8.5, z - 3.6 }, 0.5, { 240, 236, 226 }, "WoodPlanks", "Decoracion")
		end
		P.cactus(b, { -74, 0, -26 }, 1)

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -71, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -24, 24, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 12.4,
			Brightness = 3.6,
			Ambient = { 136, 116, 96 },
			OutdoorAmbient = { 180, 150, 120 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.1,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 236, 206, 160 }, decay = { 190, 140, 90 }, glare = 0.5, haze = 2 },
		colorCorrection = { contrast = 0.12, saturation = 0.05, tint = { 255, 238, 214 } },
		clouds = { cover = 0.15, density = 0.3, color = { 255, 246, 230 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
