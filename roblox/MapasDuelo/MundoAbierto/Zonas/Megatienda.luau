-- Megatienda: gran supermercado abandonado en el que se puede entrar (estanterías, cajas,
-- techo hundido) y su aparcamiento lleno de coches.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1, H, T = -730, -530, -730, -650, 20, 1.5
	local WALL = { 176, 174, 168 }
	b:box({ name = "Suelo", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, 0.2, (z0 + z1) / 2 }, color = { 190, 186, 176 }, mat = "Marble" })
	P.wallWithHoles(b, x0, x1, z1 - T / 2, 0, H, T, { { -670, -650, 0, 10 }, { -610, -590, 0, 10 }, { -725, -680, 3, 9 }, { -580, -535, 3, 9 } }, WALL, "Concrete")
	P.wallWithHoles(b, x0, x1, z0 + T / 2, 0, H, T, { { -650, -630, 0, 12 } }, WALL, "Concrete")
	for _, x in ipairs({ x0 + T / 2, x1 - T / 2 }) do
		P.wallWithHolesZ(b, z0 + T, z1 - T, x, 0, H, T, { { -700, -690, 0, 8 } }, WALL, "Concrete")
	end
	-- Techo con una parte hundida
	for _, x in ipairs({ -705, -655, -555 }) do
		b:box({ name = "Techo", size = { 50, 1.5, z1 - z0 }, pos = { x, H + 0.75, (z0 + z1) / 2 }, color = { 140, 140, 136 }, mat = "Concrete" })
	end
	b:box({ name = "Techo", size = { 50, 1.5, 30 }, pos = { -605, H + 0.75, z0 + 15 }, color = { 140, 140, 136 }, mat = "Concrete" })
	P.debris(b, { -605, 0.4, -675 }, 2)
	P.debris(b, { -596, 0.4, -688 }, 1.4)
	P.overgrowth(b:at({ -605, 0, -700 }, 0), 40, H, -15)
	for x = -705, -555, 25 do
		for _, z in ipairs({ -710, -670 }) do
			b:box({ name = "Pilar", size = { 1.6, H, 1.6 }, pos = { x, H / 2, z }, color = { 200, 198, 190 }, mat = "Concrete" })
		end
	end
	-- Estanterías y cajas registradoras
	local goods = { { 200, 60, 50 }, { 60, 120, 200 }, { 240, 200, 60 }, { 80, 160, 90 } }
	for i, z in ipairs({ -722, -712, -702, -692, -682 }) do
		for _, x in ipairs({ -686, -574 }) do
			b:box({ name = "Estanteria", size = { 66, 7, 3 }, pos = { x, 3.9, z }, color = { 150, 150, 156 }, mat = "Metal" })
			for k, y in ipairs({ 2.4, 5 }) do
				b:box({ name = "Productos", size = { 64, 1.2, 3.2 }, pos = { x, y, z }, color = goods[((i + k) % 4) + 1], folder = "Decoracion" })
			end
		end
	end
	for x = -700, -560, 28 do
		b:box({ name = "Caja", size = { 6, 3, 2 }, pos = { x, 1.9, -662 }, color = { 60, 60, 66 }, mat = "Metal" })
	end
	P.poster(b, { -630, 16, z1 + 0.3 }, 180, { 80, 6 }, { 180, 40, 40 }, "MEGATIENDA", { 250, 240, 230 }, "GothamBlack")

	-- Aparcamiento, carritos, farolas y camión en el muelle de carga
	W.parking(-760, -500, -640, -460)
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 60, 70, 90 }, { 40, 40, 42 } }
	for i, c in ipairs({ { -740, -610, 0 }, { -712, -490, 180 }, { -690, -600, 10 }, { -650, -495, 170 }, { -600, -605, 0 }, { -560, -500, 190 }, { -530, -600, 5 }, { -620, -540, 80 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], RUST[(i % #RUST) + 1], true)
	end
	for i = 0, 5 do
		b:box({ name = "Carrito", size = { 2, 2.4, 3 }, pos = { -680 + i * 23, 1.4, -560 + (i % 2) * 14 }, rot = { 0, i * 40, 0 }, color = { 170, 170, 176 }, mat = "Metal", transparency = 0.4 })
	end
	for _, x in ipairs({ -720, -630, -540 }) do
		P.streetLight(b, { x, 0.2, -550 }, 0, 18)
	end
	P.truck(b, { -640, 0, -748 }, 180, { 200, 200, 196 })
	W.spawn(-660, -470, 0)
end
