-- Ciudad del Condado: ciudad en ruinas con hospital (planta baja recorrible), oficinas rotas,
-- gasolinera, campamento militar y un control de cuarentena amurallado en la entrada sur.
return function(b, MB, W)
	local P = MB.Props
	local AVENUES = { -1260, -1500, -1720 }
	local STREETS = { 360, 520, 680, 840 }
	local OLIVE = { 84, 94, 70 }
	local SHOPS = {
		{ w = 22, h = 14, color = { 176, 150, 120 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "FARMACIA", shopColor = { 40, 120, 70 }, ruined = true },
		{ w = 20, h = 16, color = { 150, 160, 170 }, trim = { 90, 96, 104 }, shop = "LIBRERÍA", shopColor = { 90, 60, 50 }, ruined = true },
		{ w = 24, h = 12, color = { 196, 186, 160 }, trim = { 120, 90, 60 }, shop = "CAFETERÍA", shopColor = { 110, 70, 40 }, ruined = true },
		{ w = 22, h = 18, color = { 160, 110, 90 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "ARMERÍA", shopColor = { 50, 50, 56 }, ruined = true },
	}
	local APTS = {
		{ w = 34, h = 30, color = { 170, 120, 96 }, mat = "Brick", trim = { 230, 224, 210 }, fireEscape = true, ruined = true },
		{ w = 30, h = 24, color = { 150, 146, 140 }, mat = "Concrete", trim = { 100, 100, 104 }, fireEscape = true, ruined = true },
		{ w = 36, h = 34, color = { 186, 150, 120 }, mat = "Brick", trim = { 236, 230, 220 }, fireEscape = true, ruined = true },
	}
	local OFFICES = {
		{ w = 40, h = 48, color = { 130, 140, 150 }, mat = "Concrete", trim = { 80, 86, 96 }, ruined = true },
		{ w = 36, h = 56, color = { 170, 166, 156 }, mat = "Concrete", trim = { 110, 106, 100 }, ruined = true },
		{ w = 40, h = 40, color = { 120, 126, 136 }, mat = "Concrete", trim = { 70, 76, 86 }, ruined = true },
	}
	local SMALL = {
		{ w = 20, h = 12, color = { 196, 176, 150 }, trim = { 110, 80, 60 }, roof = "gable", roofColor = { 80, 70, 64 }, roofMat = "RoofShingles", ruined = true },
		{ w = 18, h = 10, color = { 160, 170, 160 }, trim = { 236, 232, 222 }, roof = "gable", roofColor = { 90, 80, 76 }, roofMat = "RoofShingles", ruined = true },
	}

	-- Calles
	for _, z in ipairs(AVENUES) do
		W.road({ { 300, z }, { 990, z } }, 22)
	end
	for _, x in ipairs(STREETS) do
		W.road({ { x, -1780 }, { x, (x == 520) and -1180 or -1215 } }, 22)
	end

	-- Aceras y suelo pavimentado en las manzanas (la plaza tiene el suyo)
	local XB = { { 300, 349 }, { 371, 509 }, { 531, 669 }, { 691, 829 }, { 851, 990 } }
	local ZB = { { -1790, -1731 }, { -1709, -1511 }, { -1489, -1271 }, { -1249, -1210 } }
	for _, xb in ipairs(XB) do
		for _, zb in ipairs(ZB) do
			if not (xb[1] == 531 and zb[1] == -1709) then
				b:box({ name = "Acera", size = { xb[2] - xb[1], 0.3, zb[2] - zb[1] }, pos = { (xb[1] + xb[2]) / 2, 0.15, (zb[1] + zb[2]) / 2 }, color = { 146, 142, 136 }, mat = "Pavement" })
			end
		end
	end

	-- Bordes rotos en lo alto de un edificio
	local function brokenTop(x, z, w, d, h, yaw)
		local g = b:at({ x, h, z }, yaw)
		for k, s in ipairs({ { -0.3, 0.4, 6 }, { 0.1, 0.5, 3 }, { 0.35, 0.3, 8 } }) do
			g:box({ name = "Ruina", size = { w * 0.3, s[3], d * s[2] }, pos = { w * s[1], s[3] / 2, (k - 2) * d * 0.2 }, color = { 140, 136, 130 }, mat = "Concrete" })
		end
	end

	-- =================================================================
	--  Hospital (x 385..495, z -1420..-1300): planta baja abierta y plantas altas
	-- =================================================================
	local hx0, hx1, hz0, hz1, H = 385, 495, -1420, -1300, 10
	local HW = { 220, 220, 214 }
	b:box({ name = "Suelo", size = { hx1 - hx0, 0.4, hz1 - hz0 }, pos = { (hx0 + hx1) / 2, 0.2, (hz0 + hz1) / 2 }, color = { 200, 204, 200 }, mat = "Marble" })
	P.wallWithHoles(b, hx0, hx1, hz1 - 0.75, 0, H, 1.5, { { 425, 455, 0, 8 }, { 395, 415, 3, 7 }, { 465, 485, 3, 7 } }, HW, "Concrete")
	P.wallWithHoles(b, hx0, hx1, hz0 + 0.75, 0, H, 1.5, { { 430, 450, 0, 8 } }, HW, "Concrete")
	for _, x in ipairs({ hx0 + 0.75, hx1 - 0.75 }) do
		P.wallWithHolesZ(b, hz0 + 1.5, hz1 - 1.5, x, 0, H, 1.5, { { -1370, -1350, 0, 8 } }, HW, "Concrete")
	end
	b:box({ name = "Plantas", size = { hx1 - hx0, 30, hz1 - hz0 }, pos = { (hx0 + hx1) / 2, H + 15, (hz0 + hz1) / 2 }, color = HW, mat = "Concrete" })
	for f = 0, 3 do
		for k = 0, 9 do
			b:box({ name = "Ventana", size = { 6, 4, 0.3 }, pos = { hx0 + 8 + k * 10.5, H + 4 + f * 7, hz1 + 0.1 }, color = { 40, 46, 50 }, mat = "Glass", folder = "Decoracion" })
		end
	end
	P.overgrowth(b:at({ (hx0 + hx1) / 2, 0, hz1 }, 180), hx1 - hx0, H + 30, -0.3)
	local sign = b:box({ name = "Rotulo", size = { 40, 5, 0.4 }, pos = { 440, H + 31, hz1 + 0.4 }, color = HW, folder = "Decoracion" })
	MB.sign(sign, "HOSPITAL", { face = "Back", font = "GothamBlack", color = { 180, 40, 40 } })
	b:box({ name = "Cruz", size = { 8, 2.4, 0.5 }, pos = { 476, H + 31, hz1 + 0.4 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 2.4, 8, 0.5 }, pos = { 476, H + 31, hz1 + 0.4 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	b:cylinder({ name = "Helipuerto", length = 0.3, diameter = 30, pos = { 440, H + 30.2, -1360 }, color = { 70, 74, 78 }, mat = "Concrete" })
	-- Recepción, camas, cortinas y escombros
	b:box({ name = "Recepcion", size = { 16, 3.4, 3 }, pos = { 440, 2.1, -1318 }, color = { 180, 190, 200 }, mat = "Marble" })
	for row = 0, 1 do
		for k = 0, 5 do
			local x, z = 400 + k * 14, -1345 - row * 40
			b:box({ name = "Cama", size = { 4, 2, 7 }, pos = { x, 1.4, z }, rot = { 0, (k % 3) * 8, 0 }, color = { 230, 230, 226 }, mat = "Fabric" })
			b:box({ name = "Cortina", size = { 0.2, 7, 8 }, pos = { x + 5, 3.9, z }, color = { 140, 180, 170 }, mat = "Fabric", transparency = 0.2, folder = "Decoracion" })
		end
	end
	for x = 405, 475, 35 do
		for _, z in ipairs({ -1330, -1390 }) do
			b:box({ name = "Pilar", size = { 1.6, H, 1.6 }, pos = { x, H / 2, z }, color = HW, mat = "Concrete" })
		end
	end
	P.debris(b, { 470, 0.4, -1400 }, 1.6)
	for k, x in ipairs({ 410, 470 }) do
		local amb = P.truck(b, { x, 0.2, -1285 }, 90 + k * 8, { 236, 236, 232 })
		MB.sign(amb, "AMBULANCIA", { face = "Left", font = "GothamBlack", color = { 200, 40, 40 }, height = 0.3 })
	end

	-- =================================================================
	--  Tiendas, gasolinera, apartamentos, oficinas, campamento y almacenes
	-- =================================================================
	P.houseRow(b, -1279, 180, 531, 669, SHOPS, 16)
	P.houseRow(b, -1481, 0, 531, 669, SHOPS, 16)
	P.houseRow(b, -1281, 180, 851, 990, APTS, 20)
	P.houseRow(b, -1479, 0, 851, 990, APTS, 20)
	P.houseRow(b, -1521, 180, 371, 509, OFFICES, 20)
	P.houseRow(b, -1699, 0, 371, 509, OFFICES, 20)
	brokenTop(391, -1521, 40, 20, 48, 180)
	brokenTop(489, -1699, 40, 20, 40, 0)
	P.houseRow(b, -1521, 180, 691, 829, APTS, 20)
	P.houseRow(b, -1699, 0, 691, 829, APTS, 20)
	for _, r in ipairs({ { 371, 509 }, { 531, 669 }, { 691, 829 }, { 851, 980 } }) do
		P.houseRow(b, -1738, 180, r[1], r[2], SMALL, 14)
	end
	-- Edificio derrumbado
	for k, d in ipairs({ { 740, -1610, 3 }, { 770, -1590, 2.4 }, { 720, -1580, 2 } }) do
		P.debris(b, { d[1], 0, d[2] }, d[3])
	end
	b:box({ name = "Forjado", size = { 40, 2, 24 }, pos = { 760, 10, -1610 }, rot = { 0, 15, 24 }, color = { 150, 146, 140 }, mat = "Concrete" })

	-- Gasolinera
	for _, x in ipairs({ 742, 778 }) do
		for _, z in ipairs({ -1395, -1365 }) do
			b:box({ name = "Pilar", size = { 1.4, 10, 1.4 }, pos = { x, 5, z }, color = { 220, 220, 226 }, mat = "Metal" })
		end
	end
	b:box({ name = "Marquesina", size = { 46, 1.4, 38 }, pos = { 760, 10.7, -1380 }, rot = { 4, 0, 3 }, color = { 226, 226, 230 }, mat = "Metal" })
	for _, x in ipairs({ 750, 770 }) do
		P.pump(b, { x, 0, -1380 }, 0)
	end
	P.house(b, { 760, 0, -1460 }, 180, { w = 34, h = 10, d = 14, color = { 236, 236, 230 }, trim = { 40, 120, 70 }, floors = 1, shop = "24 HORAS", shopColor = { 40, 120, 70 }, ruined = true })
	P.pricePylon(b, { 820, 0, -1285 }, 0, "GAS", { 40, 120, 70 })
	P.car(b, { 745, 0.2, -1350 }, 10, { 40, 40, 42 }, true)

	-- Plaza con campamento militar
	b:box({ name = "Plaza", size = { 138, 0.4, 198 }, pos = { 600, 0.2, -1610 }, color = { 150, 146, 138 }, mat = "Pavement" })
	P.fountain(b, { 600, 0.4, -1610 }, 8)
	for k = 0, 5 do
		P.tent(b, { 550 + (k % 3) * 50, 0.4, -1660 + math.floor(k / 3) * 100 }, 0, OLIVE, 16, 10, 7)
	end
	P.truck(b, { 640, 0.4, -1560 }, 90, OLIVE)
	P.truck(b, { 560, 0.4, -1570 }, 80, OLIVE)
	for k = 0, 3 do
		local a = math.rad(k * 90 + 45)
		P.sandbags(b, { 600 + math.cos(a) * 26, 0.4, -1610 + math.sin(a) * 26 }, -k * 90 - 45 + 90, 12, 3)
	end
	P.floodLight(b, { 540, 0.4, -1530 }, 160, 16)
	P.floodLight(b, { 660, 0.4, -1690 }, -20, 16)
	P.container(b, { 640, 0.4, -1690 }, 0, OLIVE, true)

	-- Almacenes
	P.house(b, { 920, 0, -1560 }, 180, { w = 110, h = 16, d = 40, color = { 130, 136, 140 }, mat = "CorrodedMetal", trim = { 80, 86, 90 }, floors = 1, ruined = true })
	P.house(b, { 920, 0, -1665 }, 0, { w = 110, h = 14, d = 36, color = { 150, 120, 100 }, mat = "Brick", trim = { 90, 80, 70 }, floors = 1, ruined = true })
	P.container(b, { 900, 0, -1610 }, 0, { 176, 60, 46 }, false)
	P.forklift(b, { 940, 0, -1606 }, 30, { 240, 190, 40 })

	-- =================================================================
	--  Control de cuarentena en la entrada sur
	-- =================================================================
	W.wallRect(300, 990, -1205, -1195, { { "N", 504, 536 }, { "S", 504, 536 } }, function(a, c)
		if math.abs(a[2] - c[2]) < 1 and a[2] < -1200 then
			P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 14, { { 110, 116, 104 }, { 96, 100, 94 }, { 120, 110, 90 } })
		end
	end)
	P.poster(b, { 470, 11, -1206.4 }, 180, { 40, 4 }, { 240, 200, 40 }, "ZONA DE CUARENTENA · CONTROL MILITAR", { 30, 30, 30 }, "GothamBlack")
	for _, x in ipairs({ 490, 550 }) do
		P.watchTower(b, { x, 0, -1225 }, 0, 16)
	end
	for _, x in ipairs({ 470, 570 }) do
		P.sandbags(b, { x, 0, -1235 }, 0, 14, 3)
	end
	P.truck(b, { 600, 0, -1230 }, 90, OLIVE)
	b:box({ name = "Barrera", size = { 30, 0.6, 0.6 }, pos = { 520, 4, -1190 }, color = { 220, 60, 50 }, mat = "Metal" })
	P.floodLight(b, { 440, 0, -1222 }, 180, 14)

	-- Coches, autobús volcado, barreras y árboles que crecen entre las ruinas
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 60, 70, 90 }, { 40, 40, 42 } }
	for k, c in ipairs({ { 420, -1262, 80 }, { 600, -1255, 100 }, { 760, -1505, 85 }, { 900, -1495, 95 }, { 362, -1600, 10 }, { 678, -1650, 170 }, { 842, -1350, 5 }, { 470, -1722, 92 }, { 522, -1420, 20 }, { 610, -1718, 70 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], RUST[(k % #RUST) + 1], true)
	end
	P.bus(b, { 700, 0.2, -1720 }, 60, { 200, 170, 60 }, "LÍNEA 3")
	for _, p in ipairs({ { 360, -1500 }, { 680, -1260 }, { 840, -1720 } }) do
		P.barrier(b, { p[1], 0.2, p[2] }, 45)
	end
	for k, t in ipairs({ { 320, -1300 }, { 330, -1450 }, { 325, -1650 }, { 600, -1380 }, { 620, -1420 }, { 900, -1380 }, { 940, -1390 }, { 440, -1600 }, { 800, -1640 }, { 330, -1760 } }) do
		W.tree(t[1], t[2], (k % 3 == 0) and "muerto" or "roble", 1.2)
	end
	W.spawn(520, -1230, 180)
	W.spawn(600, -1600, 0)
end
