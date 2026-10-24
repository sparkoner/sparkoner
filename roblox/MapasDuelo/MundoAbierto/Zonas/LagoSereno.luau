-- Lago Sereno: urbanización en círculo junto al lago, con casas abandonadas (algunas se pueden recorrer).
return function(b, MB, W)
	local P = MB.Props
	local cx, cz = -960, 60
	-- Calle de entrada desde la carretera y anillo
	W.road({ { cx, -100 }, { cx, cz - 100 } }, 18)
	local ring = {}
	for i = 0, 16 do
		local a = math.rad(i * 22.5)
		table.insert(ring, { cx + math.cos(a) * 100, cz + math.sin(a) * 100 })
	end
	W.road(ring, 18)
	-- Casas alrededor mirando al centro
	local COLORS = { { 210, 196, 170 }, { 160, 180, 196 }, { 196, 160, 140 }, { 180, 190, 160 }, { 220, 214, 200 }, { 170, 150, 170 } }
	for i, deg in ipairs({ 0, 45, 90, 135, 225, 315 }) do
		local a = math.rad(deg)
		local x, z = cx + math.cos(a) * 150, cz + math.sin(a) * 150
		local yaw = math.deg(math.atan2(math.cos(a), math.sin(a)))
		local color = COLORS[i]
		if i % 2 == 1 then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 240, 238, 230 }, roofColor = { 90, 80, 76 }, ruined = true })
		else
			P.house(b, { x, 0, z }, yaw, { w = 22, h = 16, d = 16, color = color, trim = { 240, 238, 230 }, roof = "gable", roofColor = { 90, 80, 76 }, roofMat = "RoofShingles", floors = 2, ruined = true })
		end
		-- Coche en la entrada de cada casa
		local g = b:at({ x, 0, z }, yaw)
		P.car(g, { 16, 0.2, -16 }, 0, ({ { 120, 70, 50 }, { 90, 96, 100 }, { 60, 70, 90 } })[(i % 3) + 1], true)
		P.mannequin(g, { -10, 0, -18 }, 30, { 90, 80, 70 })
	end
	-- Parque en el centro del anillo
	b:cylinder({ name = "Cesped", length = 0.3, diameter = 170, pos = { cx, 0.1, cz }, color = { 84, 110, 62 }, mat = "LeafyGrass", folder = "Decoracion" })
	for i, t in ipairs({ { -30, -20 }, { 25, 30 }, { 40, -35 }, { -40, 40 } }) do
		W.tree(cx + t[1], cz + t[2], (i % 2 == 0) and "roble" or "muerto", 1.2)
	end
	for _, z in ipairs({ -6, 6 }) do
		P.segment(b, { cx - 3, 0, cz + z }, { cx, 9, cz + z }, 0.4, { 160, 60, 50 }, "Metal")
		P.segment(b, { cx + 3, 0, cz + z }, { cx, 9, cz + z }, 0.4, { 160, 60, 50 }, "Metal")
	end
	b:cylinder({ name = "Barra", axis = "z", length = 12, diameter = 0.4, pos = { cx, 9, cz }, color = { 160, 60, 50 }, mat = "Metal", folder = "Decoracion" })
	P.car(b, { cx + 70, 0.2, cz - 50 }, 30, { 40, 40, 42 }, true)
	P.bench(b, { cx + 20, 0, cz + 10 }, 90, { 110, 90, 70 })
	P.campfire(b, { cx - 20, 0, cz + 10 }, true)
	W.spawn(cx + 10, cz - 20, 0)
end
