-- Cantera: gran agujero de roca en terrazas (el relieve se hace en Terreno.luau) con charca en el fondo,
-- cintas transportadoras, camiones volquete, excavadora y planta de machaqueo.
return function(b, MB, W)
	local P = MB.Props
	local q = W.quarry
	-- Altura del suelo dentro de la cantera según el radio
	local function pitY(x, z)
		local r = math.sqrt((x - q.x) ^ 2 + (z - q.z) ^ 2)
		if r < 55 then
			return -48
		elseif r < 90 then
			return -36
		elseif r < 130 then
			return -24
		elseif r < 170 then
			return -12
		end
		return 0
	end
	local function at(angle, r)
		local a = math.rad(angle)
		local x, z = q.x + math.cos(a) * r, q.z + math.sin(a) * r
		return x, pitY(x, z), z
	end

	-- Planta de machaqueo y cinta que sube desde la primera terraza
	P.house(b, { 1110, 0, -1500 }, 0, { w = 30, h = 16, d = 20, color = { 150, 150, 146 }, mat = "CorrodedMetal", trim = { 200, 160, 50 }, floors = 1, ruined = true })
	local ax, ay, az = at(129, 150)
	local a, c = { ax, ay + 2, az }, { 1118, 12, -1512 }
	P.segment(b, a, c, 2.4, { 60, 60, 62 }, "Rubber")
	for i = 1, 3 do
		local t = i / 4
		local x, z = a[1] + (c[1] - a[1]) * t, a[3] + (c[3] - a[3]) * t
		local y = a[2] + (c[2] - a[2]) * t
		local g = pitY(x, z)
		b:box({ name = "Pata", size = { 1, y - g, 1 }, pos = { x, (y + g) / 2, z }, color = { 200, 160, 50 }, mat = "Metal" })
	end
	-- Montones de grava
	for i, p in ipairs({ { 1080, -1560 }, { 1095, -1590 }, { 1420, -1560 } }) do
		for k, d in ipairs({ 22, 15, 8 }) do
			b:cylinder({ name = "Grava", length = 4, diameter = d, pos = { p[1], 2 + (k - 1) * 4, p[2] }, color = (i % 2 == 0) and { 150, 146, 138 } or { 170, 160, 140 }, mat = "Pebble" })
		end
	end
	-- Camiones volquete en las terrazas y excavadora en el fondo
	for _, t in ipairs({ { 30, 110 }, { 200, 150 }, { 300, 72 } }) do
		local x, y, z = at(t[1], t[2])
		P.truck(b, { x, y, z }, -t[1], { 230, 180, 40 })
	end
	local ex, ey, ez = at(160, 46)
	local exc = b:at({ ex, ey, ez }, 30)
	for _, side in ipairs({ -1, 1 }) do
		exc:box({ name = "Oruga", size = { 2.4, 2.4, 12 }, pos = { side * 3.4, 1.2, 0 }, color = { 40, 40, 42 }, mat = "Rubber" })
	end
	exc:box({ name = "Cuerpo", size = { 8, 5, 9 }, pos = { 0, 5, 1 }, color = { 230, 180, 40 }, mat = "Metal" })
	exc:box({ name = "Cabina", size = { 3.4, 4, 3.4 }, pos = { -2, 9, -1.4 }, color = { 50, 60, 66 }, mat = "Glass", transparency = 0.3 })
	P.segment(exc, { 1.6, 7, -3 }, { 1.6, 14, -11 }, 1.4, { 230, 180, 40 }, "Metal")
	P.segment(exc, { 1.6, 14, -11 }, { 1.6, 4, -16 }, 1.2, { 230, 180, 40 }, "Metal")
	exc:box({ name = "Pala", size = { 3, 2.4, 2.4 }, pos = { 1.6, 3, -16.4 }, color = { 90, 90, 90 }, mat = "Metal" })
	-- Rocas sueltas, valla del borde y caseta
	for i = 0, 9 do
		local x, y, z = at(i * 36 + 10, 60 + (i % 4) * 35)
		b:ball({ name = "Roca", diameter = 4 + (i % 3) * 2, pos = { x, y + 1, z }, color = { 120, 118, 112 }, mat = "Rock" })
	end
	for i = 0, 11 do
		if i ~= 3 and i ~= 4 then
			local a1, a2 = math.rad(i * 30), math.rad((i + 1) * 30)
			W.fence({ q.x + math.cos(a1) * 198, q.z + math.sin(a1) * 198 }, { q.x + math.cos(a2) * 198, q.z + math.sin(a2) * 198 }, 4, { 200, 160, 50 })
		end
	end
	P.container(b, { 1160, 0, -1490 }, 0, { 240, 240, 236 }, false, "OFICINA")
	P.poster(b, { 1085, 6, -1525 }, -120, { 12, 3 }, { 240, 200, 40 }, "PELIGRO · CANTERA", { 30, 30, 30 }, "GothamBlack")
end
