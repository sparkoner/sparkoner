-- Antena: puesto de comunicaciones con torre de radio, antenas parabólicas, búnker y generador.
return function(b, MB, W)
	local P = MB.Props
	W.road({ { 300, -560 }, { 300, -431 } }, 16)
	W.wallRect(230, 400, -550, -445, { { "S", 288, 312 }, { "N", 288, 312 } }, function(a, c)
		P.chainFence(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 9)
	end)
	P.radioTower(b, { 355, 0, -500 }, 120)
	for i, p in ipairs({ { 250, -470 }, { 258, -530 }, { 380, -460 } }) do
		P.satelliteDish(b, { p[1], 0, p[2] }, i * 70)
	end
	P.house(b, { 255, 0, -505 }, -90, { w = 26, h = 9, d = 20, color = { 140, 140, 132 }, mat = "Concrete", trim = { 90, 96, 90 }, floors = 1, shop = "COMUNICACIONES", shopColor = { 60, 80, 70 }, ruined = true })
	P.sandbags(b, { 278, 0, -476 }, 90, 10, 3)
	b:box({ name = "Generador", size = { 8, 5, 5 }, pos = { 330, 2.5, -465 }, color = { 80, 100, 80 }, mat = "Metal" })
	b:cylinder({ name = "Escape", length = 4, diameter = 0.6, pos = { 333, 7, -465 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
	for i, p in ipairs({ { 340, -456 }, { 343, -456 }, { 341.5, -453.4 } }) do
		P.drum(b, { p[1], 0, p[2] }, (i == 3) and { 200, 60, 40 } or { 60, 80, 60 })
	end
	for i = 0, 3 do
		P.solarPanel(b, { 370 + (i % 2) * 8, 0, -535 + math.floor(i / 2) * 8 }, 180)
	end
	for _, p in ipairs({ { 240, -540 }, { 392, -540 } }) do
		b:cylinder({ name = "Mastil", length = 30, diameter = 0.4, pos = { p[1], 15, p[2] }, color = { 200, 200, 206 }, mat = "Metal" })
	end
	P.truck(b, { 320, 0, -520 }, 0, { 84, 94, 70 })
	W.spawn(300, -470, 180)
end
