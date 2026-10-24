-- Colina Alta: comunidad en lo alto de una meseta, con empalizada, mansión, huertos, herrería y caravanas.
return function(b, MB, W)
	local P = MB.Props
	local p = W.plateau
	local cx, cz, y = p.x, p.z, p.top
	-- Empalizada octogonal con puertas al oeste y al sur
	for k = 0, 7 do
		local a1, a2 = math.rad(22.5 + k * 45), math.rad(67.5 + k * 45)
		local A = { cx + math.cos(a1) * 110, y, cz + math.sin(a1) * 110 }
		local C = { cx + math.cos(a2) * 110, y, cz + math.sin(a2) * 110 }
		local center = (45 + k * 45) % 360
		if center == 180 or center == 90 then
			local mx, mz = (A[1] + C[1]) / 2, (A[3] + C[3]) / 2
			local dx, dz = C[1] - A[1], C[3] - A[3]
			local len = math.sqrt(dx * dx + dz * dz)
			local ux, uz = dx / len, dz / len
			P.plankWall(b, A, { mx - ux * 9, y, mz - uz * 9 }, 10)
			P.plankWall(b, { mx + ux * 9, y, mz + uz * 9 }, C, 10)
		else
			P.plankWall(b, A, C, 10)
		end
	end
	P.watchTower(b, { cx - 92, y, cz + 22 }, 90, 12)
	P.watchTower(b, { cx + 20, y, cz + 92 }, 0, 12)

	-- Mansión con porche de columnas mirando a la puerta oeste
	P.house(b, { cx + 22, y, cz }, 90, { w = 44, h = 26, d = 28, floors = 3, color = { 236, 232, 222 }, trim = { 120, 110, 100 }, roof = "gable", roofColor = { 70, 66, 64 }, roofMat = "Slate", shutters = { 60, 70, 60 }, lit = true })
	for _, dz in ipairs({ -15, -5, 5, 15 }) do
		P.column(b, { cx + 3, y, cz + dz }, 16, 1.6, { 240, 236, 228 }, "Plaster")
	end
	b:box({ name = "Porche", size = { 6, 1, 36 }, pos = { cx + 4, y + 19.2, cz }, color = { 236, 232, 222 }, mat = "Plaster" })
	P.stairs(b, { cx - 4, y, cz }, 90, 2, 0.6, 1.4, 14, { 200, 196, 190 })

	-- Huertos, herrería, caravanas, tiendas, pozo y corral
	for i = 0, 7 do
		P.gardenBed(b, { cx - 60 + (i % 4) * 16, y, cz + 40 + math.floor(i / 4) * 12 }, 0, 12, 5)
	end
	local fx, fz = cx - 40, cz - 60
	b:box({ name = "Forja", size = { 8, 4, 6 }, pos = { fx, y + 2, fz }, color = { 90, 80, 74 }, mat = "Brick" })
	b:cylinder({ name = "Chimenea", length = 12, diameter = 2, pos = { fx + 2, y + 10, fz }, color = { 90, 80, 74 }, mat = "Brick" })
	local fire = b:box({ name = "Brasas", size = { 4, 0.6, 3 }, pos = { fx - 1, y + 4.3, fz }, color = { 255, 120, 40 }, mat = "Neon", folder = "Decoracion" })
	MB.fire(fire, { size = 3, smoke = false, range = 16, brightness = 1.5 })
	b:box({ name = "Yunque", size = { 2.4, 2, 1.2 }, pos = { fx - 8, y + 1, fz + 2 }, color = { 50, 50, 54 }, mat = "Metal" })
	b:box({ name = "Tejadillo", size = { 16, 0.6, 12 }, pos = { fx - 3, y + 9, fz + 1 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	for i, t in ipairs({ { cx - 10, cz - 80 }, { cx + 15, cz - 84 }, { cx + 40, cz - 76 } }) do
		b:box({ name = "Caravana", size = { 16, 7, 7 }, pos = { t[1], y + 4, t[2] }, rot = { 0, i * 12, 0 }, color = { 236, 230, 214 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 16.1, 1, 7.1 }, pos = { t[1], y + 4, t[2] }, rot = { 0, i * 12, 0 }, color = ({ { 160, 80, 50 }, { 70, 110, 140 }, { 90, 120, 70 } })[i], folder = "Decoracion" })
	end
	for i, t in ipairs({ { cx - 70, cz - 20 }, { cx - 76, cz - 40 } }) do
		P.tent(b, { t[1], y, t[2] }, 90, { 120, 110, 86 })
	end
	P.campfire(b, { cx - 55, y, cz - 30 }, true)
	b:cylinder({ name = "Pozo", length = 3, diameter = 5, pos = { cx - 30, y + 1.5, cz + 10 }, color = { 130, 126, 120 }, mat = "Cobblestone" })
	b:wedge({ name = "Tejadillo", size = { 6, 2, 3 }, pos = { cx - 30, y + 7, cz + 8.5 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:wedge({ name = "Tejadillo", size = { 6, 2, 3 }, pos = { cx - 30, y + 7, cz + 11.5 }, rot = { 0, 180, 0 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	local pen = { { cx + 50, cz + 40 }, { cx + 80, cz + 40 }, { cx + 80, cz + 70 }, { cx + 50, cz + 70 }, { cx + 50, cz + 40 } }
	for i = 1, 4 do
		W.fence(pen[i], pen[i + 1], 4, nil, y)
	end
	W.spawn(cx - 30, cz - 10, -90)
end
