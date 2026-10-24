-- Villamuro: pueblo de supervivientes rodeado por una muralla de chapas y camiones, con torres de vigilancia.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -1810, -1490, -770, -510
	local STYLES = {
		{ w = 16, h = 12, color = { 196, 176, 150 }, trim = { 110, 80, 60 }, shop = "TIENDA", shopColor = { 140, 60, 40 }, lit = true },
		{ w = 14, h = 14, color = { 150, 160, 150 }, trim = { 240, 236, 226 }, shutters = { 80, 60, 50 }, lit = true },
		{ w = 18, h = 13, color = { 176, 120, 90 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "BAR", shopColor = { 60, 90, 60 }, lit = true },
		{ w = 14, h = 12, color = { 210, 200, 180 }, trim = { 90, 100, 110 }, shop = "ENFERMERÍA", shopColor = { 180, 40, 40 }, lit = true },
		{ w = 16, h = 16, color = { 160, 150, 136 }, trim = { 236, 230, 220 }, shop = "ARMERÍA", shopColor = { 50, 50, 56 }, lit = true },
	}

	-- Muralla con puertas al este y al norte
	W.wallRect(x0, x1, z0, z1, { { "E", -660, -620 }, { "N", -1716, -1684 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12)
	end)
	for _, c in ipairs({ { x0 + 8, z0 + 8 }, { x1 - 8, z0 + 8 }, { x0 + 8, z1 - 8 }, { x1 - 8, z1 - 8 }, { x1 - 10, -676 }, { -1730, z0 + 10 } }) do
		P.watchTower(b, { c[1], 0, c[2] }, 0, 14)
	end
	-- Camiones atravesados reforzando la muralla
	P.truck(b, { x1 - 6, 0, -560 }, 0, { 90, 96, 90 })
	P.truck(b, { -1600, 0, z0 + 6 }, 90, { 120, 80, 60 })
	P.poster(b, { x1 + 0.6, 10, -640 }, -90, { 20, 3 }, { 40, 40, 40 }, "VILLAMURO · BIENVENIDOS", { 230, 220, 190 }, "GothamBlack")

	-- Calle mayor y casas
	W.road({ { x1 + 20, -640 }, { -1766, -640 } }, 22)
	W.road({ { -1700, z0 }, { -1700, -651 } }, 16)
	P.houseRow(b, -662, 180, -1750, -1720, STYLES, 14)
	P.houseRow(b, -662, 180, -1680, -1520, STYLES, 14)
	P.houseRow(b, -618, 0, -1750, -1520, STYLES, 14)
	for _, x in ipairs({ -1740, -1640, -1560 }) do
		P.streetLight(b, { x, 0, -627 }, 180, 14)
	end

	-- Ayuntamiento al fondo de la calle
	P.house(b, { -1785, 0, -640 }, -90, { w = 34, h = 18, d = 18, color = { 220, 210, 190 }, trim = { 120, 90, 70 }, floors = 2, shop = "AYUNTAMIENTO", shopColor = { 60, 70, 90 }, lit = true })

	-- Patios: huertos, tiendas de campaña, hogueras y la arena de neumáticos
	for i = 0, 5 do
		if i ~= 3 then
			P.gardenBed(b, { -1780 + i * 24, 0, -740 }, 0, 14, 5)
		end
	end
	for _, t in ipairs({ { -1610, -720 }, { -1560, -730 }, { -1520, -700 } }) do
		P.tent(b, { t[1], 0, t[2] }, 15, { 92, 110, 70 })
	end
	P.campfire(b, { -1590, 0, -700 }, true)
	local ax, az = -1650, -555
	for i = 0, 23 do
		local a = math.rad(i * 15)
		P.tires(b, { ax + math.cos(a) * 26, 0, az + math.sin(a) * 26 }, 3)
	end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		b:box({ name = "Grada", size = { 10, 3, 3 }, pos = { ax + math.cos(a) * 32, 1.5, az + math.sin(a) * 32 }, rot = { 0, -i * 45 + 90, 0 }, color = { 110, 90, 70 }, mat = "WoodPlanks" })
	end
	P.waterTank(b, { -1760, 0, -545 })
	P.solarPanel(b, { -1530, 0, -540 }, 180)
	P.solarPanel(b, { -1530, 0, -556 }, 180)

	W.spawn(-1600, -640, -90)
end
