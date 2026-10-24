-- Refugio: fábrica abandonada junto a la costa, final de la vía del tren, con naves, chimeneas,
-- vagones, contenedores y una grúa.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = 870, 1190, 530, 830
	W.wallRect(x0, x1, z0, z1, { { "N", 1004, 1036 }, { "O", 676, 712 }, { "S", 886, 914 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12, { { 110, 116, 120 }, { 96, 100, 104 }, { 130, 110, 90 } })
	end)
	P.poster(b, { 1020, 10, z0 - 1.2 }, 0, { 26, 4 }, { 50, 54, 60 }, "FÁBRICA DEL REFUGIO", { 230, 226, 210 }, "GothamBlack")
	-- Nave principal con tejado en diente de sierra y chimeneas
	P.house(b, { 1080, 0, 640 }, 180, { w = 120, h = 22, d = 70, color = { 150, 120, 100 }, mat = "Brick", trim = { 90, 80, 70 }, floors = 2, cols = 14, ruined = true })
	for k = 0, 5 do
		b:wedge({ name = "Diente", size = { 20, 6, 70 }, pos = { 1030 + k * 20, 25, 640 }, rot = { 0, 90, 0 }, color = { 110, 116, 120 }, mat = "CorrodedMetal" })
	end
	for k, p in ipairs({ { 1150, 590 }, { 1166, 600 } }) do
		b:cylinder({ name = "Chimenea", length = 64 - k * 8, diameter = 7, pos = { p[1], 32 - k * 4, p[2] }, color = { 140, 100, 80 }, mat = "Brick" })
		for _, y in ipairs({ 40, 50 }) do
			b:cylinder({ name = "Franja", length = 2, diameter = 7.3, pos = { p[1], y - k * 4, p[2] }, color = { 220, 220, 214 }, folder = "Decoracion" })
		end
	end
	P.house(b, { 960, 0, 590 }, 180, { w = 60, h = 16, d = 40, color = { 120, 128, 132 }, mat = "CorrodedMetal", trim = { 80, 86, 90 }, floors = 1, ruined = true })
	P.house(b, { 1150, 0, 790 }, -90, { w = 40, h = 12, d = 20, color = { 196, 190, 176 }, trim = { 90, 90, 96 }, floors = 2, shop = "OFICINAS", shopColor = { 60, 70, 80 }, ruined = true })
	-- Vía interior con vagones y grúa pórtico
	P.rails(b, { 900, 0, 700 }, { 1110, 0, 712 }, false)
	for k, c in ipairs({ { 960, "vagon", { 130, 70, 50 } }, { 992, "vagon", { 70, 90, 110 } }, { 1024, "cisterna", { 220, 220, 214 } }, { 1056, "plataforma", { 90, 90, 90 } } }) do
		local t = (c[1] - 900) / 210
		P.trainCar(b, { c[1], 0.6, 700 + 12 * t }, -3.3, c[2], c[3])
	end
	for _, x in ipairs({ 990, 1030 }) do
		for _, z in ipairs({ 688, 722 }) do
			b:box({ name = "Pata", size = { 2, 26, 2 }, pos = { x, 13, z }, color = { 200, 160, 50 }, mat = "Metal" })
		end
	end
	for _, z in ipairs({ 688, 722 }) do
		b:box({ name = "Viga", size = { 44, 2.4, 2.4 }, pos = { 1010, 26, z }, color = { 200, 160, 50 }, mat = "Metal" })
	end
	b:box({ name = "Carro", size = { 6, 3, 38 }, pos = { 1010, 27, 705 }, color = { 180, 140, 40 }, mat = "Metal", folder = "Decoracion" })
	-- Patio de carga
	for k, c in ipairs({ { 940, 770, 0 }, { 940, 780, 0 }, { 1060, 770, 90 } }) do
		P.container(b, { c[1], (k == 2) and 9 or 0, c[2] }, c[3], ({ { 176, 60, 46 }, { 46, 96, 150 }, { 70, 120, 80 } })[k], false)
	end
	P.forklift(b, { 1000, 0, 760 }, 30, { 240, 190, 40 })
	for k = 0, 3 do
		P.pallet(b, { 1090 + k * 6, 0, 750 }, k * 10)
	end
	for k, p in ipairs({ { 900, 760 }, { 903, 762 }, { 1120, 700 } }) do
		P.drum(b, { p[1], 0, p[2] }, (k % 2 == 0) and { 200, 60, 40 } or { 60, 80, 120 })
	end
	P.floodLight(b, { 880, 0, 540 }, 135, 16)
	P.floodLight(b, { 1180, 0, 820 }, -45, 16)
	W.spawn(960, 790, 0)
end
