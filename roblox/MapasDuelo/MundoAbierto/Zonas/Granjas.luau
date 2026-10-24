-- Granjas del Norte: granja con casa, granero, silos y molino, campos de cultivo y una pista de aterrizaje.
return function(b, MB, W)
	local P = MB.Props
	local DIRT = { 118, 100, 76 }

	-- Caminos de tierra entre los campos
	W.road({ { -1440, -1560 }, { -1200, -1600 }, { -900, -1640 } }, 14, DIRT, "Ground")
	W.road({ { -900, -1640 }, { -900, -1780 } }, 12, DIRT, "Ground")

	-- Campos de cultivo con valla
	local fields = {
		{ -1480, -1260, -1860, -1680, { 176, 156, 84 } },
		{ -1240, -1080, -1860, -1700, { 96, 132, 62 } },
		{ -1480, -1260, -1540, -1380, { 120, 144, 70 } },
		{ -1180, -960, -1580, -1380, { 170, 150, 80 } },
		{ -860, -720, -1580, -1380, { 104, 136, 64 } },
	}
	for _, f in ipairs(fields) do
		P.cropField(b, f[1], f[2], f[3], f[4], 0, f[5])
		W.fence({ f[1], f[3] }, { f[2], f[3] }, 4)
		W.fence({ f[1], f[4] }, { f[2], f[4] }, 4)
		W.fence({ f[1], f[3] }, { f[1], f[4] }, 4)
	end
	-- Espantapájaros, tractor y balas de paja
	for _, s in ipairs({ { -1370, -1770 }, { -1070, -1480 } }) do
		b:box({ name = "Palo", size = { 0.5, 9, 0.5 }, pos = { s[1], 4.5, s[2] }, color = { 110, 84, 60 }, mat = "Wood" })
		P.mannequin(b, { s[1], 3, s[2] }, 20, { 120, 90, 70 })
		b:box({ name = "Sombrero", size = { 2.4, 0.3, 2.4 }, pos = { s[1], 10.4, s[2] }, color = { 170, 140, 80 }, mat = "Fabric", folder = "Decoracion" })
	end
	P.tractor(b, { -1150, 0, -1790 }, 70, { 60, 120, 60 })
	for i, p in ipairs({ { -1300, -1450 }, { -1290, -1456 }, { -1100, -1500 }, { -800, -1450 }, { -820, -1470 }, { -960, -1700 } }) do
		P.hayBale(b, { p[1], 0, p[2] }, i * 37)
	end

	-- Casa de la granja (se puede entrar), granero, silos, molino y depósito de agua
	P.openHouse(b, { -840, 0, -1740 }, 180, { color = { 236, 228, 210 }, trim = { 150, 60, 50 }, roofColor = { 90, 70, 60 }, ruined = true })
	local barn = { 170, 50, 40 }
	local bx, bz = -1000, -1760
	P.wallWithHoles(b, bx - 18, bx + 18, bz - 25, 0, 16, 1, { { bx - 6, bx + 6, 0, 12 } }, barn, "WoodPlanks")
	P.wallWithHoles(b, bx - 18, bx + 18, bz + 25, 0, 16, 1, { { bx - 6, bx + 6, 0, 12 } }, barn, "WoodPlanks")
	for _, x in ipairs({ bx - 18, bx + 18 }) do
		P.wallWithHolesZ(b, bz - 24.5, bz + 24.5, x, 0, 16, 1, { { bz - 4, bz + 4, 6, 10 } }, barn, "WoodPlanks")
	end
	b:box({ name = "Suelo", size = { 36, 0.4, 50 }, pos = { bx, 0.2, bz }, color = { 120, 96, 70 }, mat = "WoodPlanks" })
	b:box({ name = "Pajar", size = { 34, 0.8, 16 }, pos = { bx, 9, bz + 16 }, color = { 120, 90, 60 }, mat = "WoodPlanks" })
	b:truss({ name = "Escalera", size = { 2, 10, 2 }, pos = { bx, 5, bz + 7 }, color = { 110, 80, 54 } })
	b:wedge({ name = "Tejado", size = { 52, 9, 19.6 }, pos = { bx - 9.8, 20.5, bz }, rot = { 0, 90, 0 }, color = { 90, 70, 60 }, mat = "CorrodedMetal" })
	b:wedge({ name = "Tejado", size = { 52, 9, 19.6 }, pos = { bx + 9.8, 20.5, bz }, rot = { 0, -90, 0 }, color = { 90, 70, 60 }, mat = "CorrodedMetal" })
	for i, p in ipairs({ { bx - 10, bz + 20 }, { bx - 6, bz + 19 }, { bx + 12, bz - 16 }, { bx - 8, bz + 16 } }) do
		P.hayBale(b, { p[1], (i == 4) and 9.4 or 0.4, p[2] }, i * 30)
	end
	P.silo(b, { -1060, 0, -1820 }, 8, 40, { 176, 178, 180 })
	P.silo(b, { -1060, 0, -1795 }, 7, 34, { 160, 150, 140 })
	P.windmill(b, { -780, 0, -1820 }, 30)
	P.waterTank(b, { -780, 0, -1690 })
	P.car(b, { -880, 0.2, -1680 }, 100, { 120, 70, 50 }, true)
	P.campfire(b, { -930, 0, -1700 }, true)
	W.fence({ -880, -1800 }, { -780, -1800 }, 4)

	-- Pista de aterrizaje con hangar y avioneta estrellada
	local yaw = -45
	local strip = b:at({ -1020, 0, -1040 }, yaw)
	strip:box({ name = "Pista", size = { 420, 0.4, 40 }, pos = { 0, 0, 0 }, color = { 120, 118, 112 }, mat = "Concrete" })
	for x = -190, 190, 30 do
		strip:box({ name = "Marca", size = { 14, 0.12, 1.4 }, pos = { x, 0.22, 0 }, color = { 220, 218, 210 }, folder = "Decoracion", shadow = false })
	end
	for i = 0, 3 do
		strip:box({ name = "Hierba", size = { 30, 0.15, 8 + i * 3 }, pos = { -150 + i * 95, 0.24, (i % 2 == 0) and 10 or -12 }, color = { 80, 106, 60 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
	end
	P.planeWreck(strip, { 60, 0.2, 6 }, 20)
	local hangar = strip:at({ -60, 0, 52 }, 0)
	hangar:box({ name = "Suelo", size = { 40, 0.4, 30 }, pos = { 0, 0.2, 0 }, color = { 110, 110, 106 }, mat = "Concrete" })
	P.wallWithHoles(hangar, -20, 20, 15, 0, 14, 1, {}, { 140, 146, 150 }, "CorrodedMetal")
	P.wallWithHolesZ(hangar, -15, 15, -20, 0, 14, 1, { { -6, 6, 0, 10 } }, { 140, 146, 150 }, "CorrodedMetal")
	P.wallWithHolesZ(hangar, -15, 15, 20, 0, 14, 1, {}, { 140, 146, 150 }, "CorrodedMetal")
	hangar:box({ name = "Techo", size = { 42, 1, 32 }, pos = { 0, 14.5, 0 }, color = { 120, 124, 128 }, mat = "CorrodedMetal" })
	hangar:box({ name = "Puerta", size = { 18, 12, 0.4 }, pos = { -8, 6, -15 }, color = { 120, 124, 128 }, mat = "CorrodedMetal" })
	for i, x in ipairs({ -12, -9, 10 }) do
		P.drum(hangar, { x, 0.4, 10 - i }, { 180, 60, 40 })
	end
	local tower = strip:at({ 120, 0, 48 }, 0)
	P.watchTower(tower, { 0, 0, 0 }, 0, 14)
	tower:cylinder({ name = "Manga", axis = "x", length = 4, diameter = 1.4, pos = { 6, 20, -4 }, color = { 240, 120, 40 }, mat = "Fabric", folder = "Decoracion" })

	W.spawn(-920, -1690, 180)
end
