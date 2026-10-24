-- Ciudadela: barrio residencial amurallado donde viven supervivientes. Tiene luz, huertos,
-- placas solares, iglesia, torres de vigilancia y casas (algunas se pueden recorrer).
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -420, 80, 700, 1150
	local COLORS = { { 220, 210, 190 }, { 180, 196, 210 }, { 210, 186, 160 }, { 196, 210, 180 }, { 230, 224, 214 }, { 200, 180, 196 } }

	W.wallRect(x0, x1, z0, z1, { { "N", -276, -244 }, { "O", 904, 936 }, { "E", 904, 936 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 14)
	end)
	for _, t in ipairs({ { x0 + 8, z0 + 8 }, { x1 - 8, z0 + 8 }, { x0 + 8, z1 - 8 }, { x1 - 8, z1 - 8 }, { -232, z0 + 10 }, { x0 + 10, 950 }, { x1 - 10, 890 } }) do
		P.watchTower(b, { t[1], 0, t[2] }, 0, 16)
	end
	P.poster(b, { -260, 12, z0 - 1.2 }, 0, { 30, 4 }, { 60, 70, 60 }, "CIUDADELA", { 236, 230, 200 }, "GothamBlack")

	-- Calles
	W.road({ { x0 - 10, 920 }, { x1 + 10, 920 } }, 20)
	W.road({ { -260, z0 - 10 }, { -260, z1 } }, 18)
	for _, p in ipairs({ { -330, 909 }, { -150, 909 }, { 0, 931 }, { -272, 800 }, { -248, 1060 } }) do
		P.streetLight(b, { p[1], 0, p[2] }, 0, 14)
	end

	-- Casas a lo largo de las calles (las de openHouse se pueden recorrer)
	local i = 0
	local function home(x, z, yaw)
		i = i + 1
		local color = COLORS[(i % #COLORS) + 1]
		if i % 3 == 1 then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 248, 246, 240 }, roofColor = { 80, 76, 74 } })
		else
			P.house(b, { x, 0, z }, yaw, { w = 24, h = 16, d = 16, color = color, trim = { 248, 246, 240 }, roof = "gable", roofColor = { 80, 76, 74 }, roofMat = "RoofShingles", floors = 2, lit = true })
		end
	end
	for _, x in ipairs({ -390, -340, -200, -150, -100, -50, 0, 50 }) do
		home(x, 894, 180)
		home(x, 946, 0)
	end
	for _, z in ipairs({ 760, 820, 1030, 1090 }) do
		home(-292, z, -90)
		home(-228, z, 90)
	end

	-- Iglesia, huertos, placas solares, invernadero y obras de ampliación de la muralla
	P.house(b, { -60, 0, 780 }, 0, { w = 24, h = 16, d = 36, color = { 236, 230, 220 }, trim = { 120, 100, 80 }, roof = "gable", roofColor = { 90, 70, 60 }, floors = 1, cols = 3, lit = true })
	P.bellTower(b, { -60, 0, 760 }, 0, 26, { 236, 230, 220 }, { 90, 70, 60 })
	for k = 0, 9 do
		P.gardenBed(b, { -200 + (k % 5) * 16, 0, 740 + math.floor(k / 5) * 10 }, 0, 12, 5)
	end
	for k = 0, 11 do
		P.solarPanel(b, { 20 + (k % 4) * 9, 0, 1000 + math.floor(k / 4) * 9 }, 180)
	end
	b:box({ name = "Invernadero", size = { 30, 8, 14 }, pos = { -120, 4, 1050 }, color = { 200, 220, 210 }, mat = "Glass", transparency = 0.5 })
	for k = 0, 3 do
		P.gardenBed(b, { -130 + k * 7, 0, 1050 }, 90, 12, 3)
	end
	P.waterTank(b, { -380, 0, 1110 })
	P.crate(b, { -360, 0, 760 }, 5, 10)
	P.pallet(b, { -350, 0, 770 }, 20)
	b:box({ name = "Chapas", size = { 10, 2, 8 }, pos = { -370, 1, 780 }, color = { 120, 90, 70 }, mat = "CorrodedMetal" })
	P.campfire(b, { -150, 0, 1100 }, true)
	P.fireBarrel(b, { -141, 0, 1093 })
	P.tiendaCaza(b, { -152, 0, 1119 }, 0, "Tienda de caza de la Ciudadela")
	for k = 0, 3 do
		P.bench(b, { -170 + k * 9, 0, 1090 }, 0, { 120, 90, 60 })
	end
	W.spawn(-240, 920, 90)
	W.spawn(-100, 920, -90)
end
