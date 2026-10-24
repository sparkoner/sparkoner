-- Ladera: barrio de casas abandonadas a lo largo de la carretera de la costa, con una calle sin salida.
return function(b, MB, W)
	local P = MB.Props
	local COLORS = { { 200, 186, 160 }, { 160, 176, 190 }, { 190, 160, 150 }, { 170, 186, 150 }, { 210, 204, 190 } }
	local i = 0
	local function home(x, z, yaw, open)
		i = i + 1
		local color = COLORS[(i % #COLORS) + 1]
		if open then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 236, 232, 222 }, roofColor = { 86, 80, 76 }, ruined = true })
		else
			P.house(b, { x, 0, z }, yaw, { w = 24, h = 15, d = 16, color = color, trim = { 236, 232, 222 }, roof = "gable", roofColor = { 86, 80, 76 }, roofMat = "RoofShingles", floors = 2, ruined = true })
		end
		local g = b:at({ x, 0, z }, yaw)
		g:box({ name = "Buzon", size = { 1.2, 4.4, 1.2 }, pos = { 11, 2.2, -18 }, color = { 70, 70, 74 }, mat = "Metal" })
	end
	-- Casas al norte y al sur de la carretera (z = 900)
	for k, x in ipairs({ 530, 575, 620, 665, 710, 755 }) do
		local open = (k % 3 == 2)
		home(x, open and 873 or 877, 180, open)
	end
	for k, x in ipairs({ 530, 575, 705, 750 }) do
		local open = (k % 2 == 1)
		home(x, open and 927 or 923, 0, open)
	end
	-- Calle sin salida hacia el sur
	W.road({ { 640, 911 }, { 640, 1046 } }, 16)
	b:cylinder({ name = "Rotonda", length = 0.4, diameter = 34, pos = { 640, 0, 1050 }, color = { 66, 66, 68 }, mat = "Asphalt" })
	for _, z in ipairs({ 975, 1025 }) do
		home(620, z, -90, false)
		home(660, z, 90, z == 975)
	end
	-- Coches quemados, columpio, canasta y valla
	for k, c in ipairs({ { 600, 905, 95 }, { 690, 893, 80 }, { 640, 1000, 10 }, { 520, 960, 40 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], (k % 2 == 0) and { 40, 40, 42 } or { 120, 70, 50 }, true)
	end
	for _, z in ipairs({ 1060, 1066 }) do
		P.segment(b, { 700, 0, z }, { 703, 8, z }, 0.4, { 60, 120, 160 }, "Metal")
		P.segment(b, { 706, 0, z }, { 703, 8, z }, 0.4, { 60, 120, 160 }, "Metal")
	end
	b:box({ name = "Canasta", size = { 0.5, 10, 0.5 }, pos = { 590, 5, 1040 }, color = { 80, 80, 84 }, mat = "Metal" })
	b:box({ name = "Tablero", size = { 5, 3, 0.3 }, pos = { 590, 10, 1039 }, color = { 230, 230, 226 }, folder = "Decoracion" })
	W.fence({ 505, 1065 }, { 600, 1065 }, 4, { 230, 228, 220 })
	W.fence({ 680, 1065 }, { 775, 1065 }, 4, { 230, 228, 220 })
	W.spawn(600, 900, 90)
end
