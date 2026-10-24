-- Penal: prisión con doble valla, torres, dos pabellones de celdas en los que se puede entrar, patio y oficinas.
return function(b, MB, W)
	local P = MB.Props
	local CONCRETE = { 168, 166, 158 }

	-- Pabellón de celdas: pasillo central con celdas a los dos lados (largo a lo largo de X local)
	local function cellBlock(cx, cz)
		local g = b:at({ cx, 0, cz }, 0)
		local L, D, H = 64, 26, 12
		g:box({ name = "Suelo", size = { L, 0.4, D }, pos = { 0, 0.2, 0 }, color = { 140, 138, 132 }, mat = "Concrete" })
		local windows = {}
		for x = -26, 26, 13 do
			table.insert(windows, { x - 2, x + 2, 8, 10 })
		end
		P.wallWithHoles(g, -L / 2, L / 2, -D / 2 + 0.5, 0, H, 1, windows, CONCRETE, "Concrete")
		P.wallWithHoles(g, -L / 2, L / 2, D / 2 - 0.5, 0, H, 1, windows, CONCRETE, "Concrete")
		for _, x in ipairs({ -L / 2 + 0.5, L / 2 - 0.5 }) do
			P.wallWithHolesZ(g, -D / 2 + 1, D / 2 - 1, x, 0, H, 1, { { -3, 3, 0, 8 } }, CONCRETE, "Concrete")
		end
		g:box({ name = "Techo", size = { L + 1, 1, D + 1 }, pos = { 0, H + 0.5, 0 }, color = { 130, 128, 122 }, mat = "Concrete" })
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 7 do
				local x = -L / 2 + 1 + k * 8
				g:box({ name = "Tabique", size = { 0.6, H, 8 }, pos = { x, H / 2, side * 8.5 }, color = CONCRETE, mat = "Concrete" })
				for _, bx in ipairs({ 1.6, 3.2, 6.4 }) do
					g:cylinder({ name = "Barrote", length = H - 1, diameter = 0.25, pos = { x + bx, (H - 1) / 2 + 0.4, side * 4.5 }, color = { 80, 80, 84 }, mat = "Metal" })
				end
				g:box({ name = "Litera", size = { 2.4, 1.6, 5 }, pos = { x + 5.8, 1.2, side * 9.8 }, color = { 110, 110, 104 }, mat = "Metal" })
			end
		end
		for x = -20, 20, 20 do
			g:box({ name = "Lampara", size = { 6, 0.3, 1 }, pos = { x, H - 0.3, 0 }, color = { 230, 236, 220 }, mat = "Neon", folder = "Decoracion" })
		end
		P.overgrowth(g, L, H, -D / 2 - 0.2)
	end

	-- Doble valla con alambre de espino y puertas norte y sur
	for _, inset in ipairs({ 0, 8 }) do
		W.wallRect(-1690 + inset, -1410 - inset, 420 + inset, 660 - inset, { { "N", -1556, -1524 }, { "S", -1556, -1524 } }, function(a, c)
			P.chainFence(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12)
			P.rod(b, { a[1], 12.6, a[2] }, { c[1], 12.6, c[2] }, 1, { 90, 90, 92 }, "Metal", "Decoracion")
		end)
	end
	for _, c in ipairs({ { -1678, 432 }, { -1422, 432 }, { -1678, 648 }, { -1422, 648 } }) do
		P.watchTower(b, { c[1], 0, c[2] }, 0, 16)
	end
	W.road({ { -1540, 410 }, { -1540, 670 } }, 18)

	-- Pabellones, oficinas y patio
	cellBlock(-1620, 480)
	cellBlock(-1620, 600)
	P.house(b, { -1462, 0, 470 }, 90, { w = 40, h = 14, d = 24, color = { 150, 150, 146 }, trim = { 90, 96, 104 }, floors = 2, shop = "PENITENCIARÍA", shopColor = { 60, 70, 80 }, ruined = true })
	b:box({ name = "Pista", size = { 44, 0.2, 28 }, pos = { -1470, 0.1, 585 }, color = { 120, 96, 80 }, mat = "Concrete" })
	for _, x in ipairs({ -1490, -1450 }) do
		b:box({ name = "Poste", size = { 0.6, 10, 0.6 }, pos = { x, 5, 585 }, color = { 80, 80, 84 }, mat = "Metal" })
		b:box({ name = "Tablero", size = { 0.3, 3, 5 }, pos = { x + (x < -1470 and 0.6 or -0.6), 10, 585 }, color = { 230, 230, 226 }, folder = "Decoracion" })
	end
	P.bleachers(b, { -1470, 0, 610 }, 180, 3, 30, { { 120, 120, 120 } })
	for _, x in ipairs({ -1560, -1520 }) do
		b:box({ name = "Garita", size = { 5, 8, 5 }, pos = { x, 4, 430 }, color = { 140, 140, 136 }, mat = "Concrete" })
	end

	-- Autobús de presos estrellado en la entrada
	P.bus(b, { -1590, 0.2, 395 }, 80, { 220, 220, 214 }, "TRASLADOS")
	P.sandbags(b, { -1500, 0, 398 }, 0, 10, 3)
	P.debris(b, { -1520, 0, 445 }, 1.2)
	W.spawn(-1515, 380, 180)
end
