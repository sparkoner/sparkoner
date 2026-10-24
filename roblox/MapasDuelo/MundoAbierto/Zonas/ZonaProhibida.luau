-- Zona Prohibida: campamento militar de cuarentena junto a la costa, con muros de hormigón,
-- tiendas, camiones y un helicóptero estrellado.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -1600, -1300, 1080, 1320
	local OLIVE = { 84, 94, 70 }

	-- Muros de hormigón en T
	W.wallRect(x0, x1, z0, z1, { { "N", -1476, -1444 } }, function(a, c)
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local n = math.max(1, math.floor(len / 6))
		local g = b:at({ (a[1] + c[1]) / 2, 0, (a[2] + c[2]) / 2 }, yaw)
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			g:box({ name = "MuroT", size = { len / n - 0.3, 10, 1.6 }, pos = { x, 5, 0 }, color = (i % 4 == 0) and { 150, 146, 138 } or { 170, 166, 158 }, mat = "Concrete" })
			g:box({ name = "Pie", size = { len / n - 0.3, 1.2, 4 }, pos = { x, 0.6, 0 }, color = { 150, 146, 138 }, mat = "Concrete" })
		end
	end)
	for _, x in ipairs({ -1560, -1380 }) do
		P.poster(b, { x, 6, z0 - 1 }, 0, { 30, 4 }, { 240, 200, 40 }, "☣ ZONA DE CUARENTENA ☣", { 30, 30, 30 }, "GothamBlack")
	end
	P.poster(b, { x0 - 1, 6, 1200 }, 90, { 30, 4 }, { 240, 200, 40 }, "PROHIBIDO EL PASO", { 30, 30, 30 }, "GothamBlack")

	-- Control de entrada
	b:box({ name = "Garita", size = { 6, 8, 6 }, pos = { -1488, 4, 1092 }, color = OLIVE, mat = "Metal" })
	b:box({ name = "Barrera", size = { 30, 0.6, 0.6 }, pos = { -1460, 4, 1082 }, rot = { 0, 0, 12 }, color = { 220, 60, 50 }, mat = "Metal" })
	for _, x in ipairs({ -1490, -1430 }) do
		P.sandbags(b, { x, 0, 1066 }, 0, 12, 3)
	end

	-- Campamento: tiendas, tienda de descontaminación, camiones, contenedores y focos
	for i = 0, 3 do
		for k = 0, 1 do
			P.tent(b, { -1570 + i * 22, 0, 1130 + k * 26 }, 0, OLIVE, 14, 10, 7)
		end
	end
	P.tent(b, { -1360, 0, 1140 }, 90, { 230, 230, 226 }, 30, 16, 10)
	b:box({ name = "Cruz", size = { 0.4, 4, 8 }, pos = { -1360, 6, 1140 - 8.2 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	P.truck(b, { -1420, 0, 1210 }, 30, OLIVE)
	P.truck(b, { -1330, 0, 1250 }, -10, OLIVE)
	P.container(b, { -1560, 0, 1290 }, 0, { 80, 90, 70 }, true)
	P.container(b, { -1520, 0, 1296 }, 90, { 120, 120, 110 }, false, "MATERIAL")
	P.helicopterWreck(b, { -1460, 0, 1250 }, 40)
	for i, p in ipairs({ { -1500, 1180 }, { -1497, 1183 }, { -1503, 1185 }, { -1380, 1300 }, { -1376, 1302 } }) do
		P.drum(b, { p[1], 0, p[2] }, (i % 2 == 0) and { 230, 190, 40 } or { 60, 70, 60 })
	end
	for _, p in ipairs({ { -1530, 1220 }, { -1410, 1170 } }) do
		P.crate(b, { p[1], 0, p[2] }, 4.5, 10, OLIVE)
		P.crate(b, { p[1] + 5, 0, p[2] + 1 }, 4, -15, OLIVE)
	end
	P.floodLight(b, { -1590, 0, 1090 }, 135, 16)
	P.floodLight(b, { -1310, 0, 1310 }, -45, 16)
	P.watchTower(b, { -1310, 0, 1092 }, 0, 16)
	P.watchTower(b, { -1590, 0, 1310 }, 0, 16)
end
