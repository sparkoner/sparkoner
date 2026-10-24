-- Motel Luna: motel de carretera de dos plantas con pasarela, recepción, aparcamiento y cartel.
return function(b, MB, W)
	local P = MB.Props
	local WALL, TRIM = { 200, 170, 140 }, { 110, 70, 50 }
	W.parking(-740, -622, 20, 108)
	P.house(b, { -690, 0, 125 }, 0, { w = 130, h = 20, d = 18, floors = 2, cols = 10, color = WALL, trim = TRIM, door = false, ruined = true })
	for i = 0, 9 do
		local x = -755 + 6.5 + 13 * i
		for _, y in ipairs({ 3.2, 13.2 }) do
			b:box({ name = "Puerta", size = { 3, 6, 0.3 }, pos = { x + 3, y, 115.8 }, color = (i % 3 == 0) and { 80, 60, 50 } or { 60, 90, 110 }, mat = "WoodPlanks", folder = "Decoracion" })
		end
	end
	-- Pasarela del primer piso con barandilla, pilares y escalera
	b:box({ name = "Pasarela", size = { 130, 0.6, 4 }, pos = { -690, 10, 114 }, color = { 150, 146, 140 }, mat = "Concrete" })
	P.railing(b, { -755, 10.3, 112.2 }, { -634, 10.3, 112.2 }, 3, TRIM)
	for x = -752, -628, 31 do
		b:box({ name = "Pilar", size = { 0.8, 10, 0.8 }, pos = { x, 5, 112.4 }, color = TRIM })
	end
	P.stairs(b, { -630, 0, 99 }, 0, 10, 1, 1.3, 4, { 150, 146, 140 })
	-- Ala lateral y recepción
	P.house(b, { -750, 0, 72 }, -90, { w = 60, h = 10, d = 16, floors = 1, cols = 6, color = WALL, trim = TRIM, ruined = true })
	P.house(b, { -612, 0, 60 }, 90, { w = 24, h = 10, d = 14, floors = 1, color = { 220, 200, 170 }, trim = TRIM, shop = "RECEPCIÓN", shopColor = { 60, 80, 120 }, ruined = true })
	-- Cartel de neón apagado
	b:box({ name = "Poste", size = { 1.4, 24, 1.4 }, pos = { -606, 12, 22 }, color = { 70, 70, 74 }, mat = "Metal" })
	local sign = b:box({ name = "Cartel", size = { 18, 6, 1 }, pos = { -606, 26, 22 }, color = { 40, 40, 50 }, folder = "Decoracion" })
	MB.sign(sign, "MOTEL LUNA", { font = "LuckiestGuy", color = { 160, 120, 150 } })
	b:cylinder({ name = "Luna", axis = "z", length = 0.6, diameter = 5, pos = { -606, 31.6, 22 }, color = { 220, 210, 150 }, folder = "Decoracion" })
	-- Coches, máquinas y basura
	for i, c in ipairs({ { -730, 40, 90 }, { -700, 95, 0 }, { -660, 92, 10 }, { -640, 40, 120 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], ({ { 120, 70, 50 }, { 60, 70, 90 }, { 140, 120, 90 }, { 90, 96, 100 } })[i], true)
	end
	P.vending(b, { -625, 0, 106 }, 180, { 160, 50, 50 }, "COLA")
	P.dumpster(b, { -760, 0, 112 }, 90, { 60, 90, 70 })
	P.debris(b, { -700, 0, 70 }, 0.8)
	W.spawn(-680, 60, 0)
end
