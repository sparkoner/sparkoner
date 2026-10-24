-- Biblioteca de piezas detalladas. Cada función recibe g (constructor o grupo) y crea el objeto.
return function(MB)
	local P = MB.Props

	local function darker(c, k)
		k = k or 40
		return { math.max(c[1] - k, 0), math.max(c[2] - k, 0), math.max(c[3] - k, 0) }
	end
	local function lighter(c, k)
		k = k or 40
		return { math.min(c[1] + k, 255), math.min(c[2] + k, 255), math.min(c[3] + k, 255) }
	end
	P.darker, P.lighter = darker, lighter

	-- Barra (caja) entre dos puntos locales
	function P.segment(g, a, b, thickness, color, mat, folder)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local pitch = -math.deg(math.asin(dy / len))
		local yaw = math.deg(math.atan2(dx, dz))
		return g:box({ name = "Barra", size = { thickness, thickness, len }, pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, rot = { pitch, yaw, 0 }, color = color, mat = mat or "Metal", folder = folder })
	end

	-- Tubo (cilindro) entre dos puntos locales
	function P.rod(g, a, b, diameter, color, mat, folder)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local roll = math.deg(math.asin(dy / len))
		local yaw = math.deg(math.atan2(-dz, dx))
		return g:cylinder({ name = "Tubo", axis = "x", length = len, diameter = diameter, pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, rot = { 0, yaw, roll }, color = color, mat = mat or "Metal", folder = folder })
	end

	-- =================================================================
	--  Mobiliario urbano
	-- =================================================================
	function P.crate(g, pos, size, rotY, color)
		local c = g:at(pos, rotY)
		local s = size or 5
		local wood = color or { 206, 160, 104 }
		local frame = darker(wood, 45)
		c:box({ name = "Caja", size = { s - 0.3, s - 0.3, s - 0.3 }, pos = { 0, s / 2, 0 }, color = wood, mat = "WoodPlanks" })
		local e = 0.45
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				c:box({ name = "Canto", size = { e, s, e }, pos = { x * (s - e) / 2, s / 2, z * (s - e) / 2 }, color = frame, mat = "Wood" })
			end
		end
		for _, y in ipairs({ e / 2, s - e / 2 }) do
			for _, z in ipairs({ -1, 1 }) do
				c:box({ name = "Marco", size = { s, e, e }, pos = { 0, y, z * (s - e) / 2 }, color = frame, mat = "Wood" })
				c:box({ name = "Marco", size = { e, e, s }, pos = { z * (s - e) / 2, y, 0 }, color = frame, mat = "Wood" })
			end
		end
		local diag = math.sqrt(2) * (s - 2 * e)
		for _, z in ipairs({ -1, 1 }) do
			c:box({ name = "Riostra", size = { diag, e * 0.8, 0.2 }, pos = { 0, s / 2, z * (s / 2 - 0.05) }, rot = { 0, 0, 45 }, color = frame, mat = "Wood", folder = "Decoracion" })
		end
	end

	function P.cardboard(g, pos, size, rotY)
		local c = g:at(pos, rotY)
		local s = size or { 3, 2.4, 2.6 }
		c:box({ name = "Carton", size = s, pos = { 0, s[2] / 2, 0 }, color = { 186, 146, 98 }, mat = "Cardboard" })
		c:box({ name = "Cinta", size = { 0.6, 0.05, s[3] + 0.02 }, pos = { 0, s[2] + 0.02, 0 }, color = { 214, 190, 140 }, folder = "Decoracion" })
	end

	function P.tree(g, pos, scale, palette)
		local t = g:at(pos, 0)
		local s = scale or 1
		local leaves = palette or { { 196, 120, 58 }, { 168, 108, 50 }, { 134, 128, 62 } }
		local bark = { 92, 66, 48 }
		t:cylinder({ name = "Tronco", length = 5 * s, diameter = 1.8 * s, pos = { 0, 2.5 * s, 0 }, color = bark, mat = "Wood" })
		t:cylinder({ name = "Tronco", length = 5 * s, diameter = 1.3 * s, pos = { 0, 7 * s, 0 }, color = bark, mat = "Wood", folder = "Decoracion" })
		P.rod(t, { 0, 6 * s, 0 }, { 2.6 * s, 9 * s, 0.6 * s }, 0.7 * s, bark, "Wood", "Decoracion")
		P.rod(t, { 0, 6.5 * s, 0 }, { -2.4 * s, 9.4 * s, -0.8 * s }, 0.6 * s, bark, "Wood", "Decoracion")
		local blobs = {
			{ 0, 11 * s, 0, 8.5, 1 }, { 3 * s, 9.6 * s, 0.8 * s, 6.5, 2 }, { -2.8 * s, 10 * s, -1 * s, 6.8, 3 },
			{ 0.6 * s, 13.6 * s, -0.6 * s, 6, 2 }, { -1.2 * s, 9 * s, 2.6 * s, 6, 1 }, { 1.6 * s, 9.4 * s, -2.6 * s, 5.6, 3 },
			{ -2.2 * s, 12.6 * s, 1.4 * s, 4.8, 1 }, { 2.6 * s, 12.4 * s, 1.8 * s, 4.4, 3 },
		}
		for _, b in ipairs(blobs) do
			t:ball({ name = "Copa", diameter = b[4] * s, pos = { b[1], b[2], b[3] }, color = leaves[b[5]], mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.bush(g, pos, scale, color)
		local b = g:at(pos, 0)
		local s = scale or 1
		local c = color or { 88, 122, 62 }
		for _, o in ipairs({ { 0, 1.4, 0, 3.4 }, { 1.4, 1.1, 0.6, 2.6 }, { -1.3, 1.0, -0.5, 2.6 }, { 0.3, 1.0, 1.4, 2.2 } }) do
			b:ball({ name = "Arbusto", diameter = o[4] * s, pos = { o[1] * s, o[2] * s, o[3] * s }, color = (o[4] > 3) and c or lighter(c, 14), mat = "LeafyGrass" })
		end
	end

	function P.pottedPlant(g, pos, scale)
		local p = g:at(pos, 0)
		local s = scale or 1
		p:cylinder({ name = "Maceta", length = 1.8 * s, diameter = 2 * s, pos = { 0, 0.9 * s, 0 }, color = { 182, 96, 64 }, mat = "Plaster" })
		p:cylinder({ name = "Tierra", length = 0.1, diameter = 1.8 * s, pos = { 0, 1.82 * s, 0 }, color = { 70, 50, 40 }, mat = "Ground", folder = "Decoracion" })
		for _, o in ipairs({ { 0, 3, 0, 2.2 }, { 0.6, 2.6, 0.4, 1.6 }, { -0.6, 2.5, -0.3, 1.6 }, { 0, 3.8, 0.2, 1.4 } }) do
			p:ball({ name = "Hojas", diameter = o[4] * s, pos = { o[1] * s, o[2] * s, o[3] * s }, color = { 76, 128, 66 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.planter(g, pos, size, rotY)
		local p = g:at(pos, rotY)
		local w, d = size[1], size[2]
		p:box({ name = "Jardinera", size = { w, 2.4, d }, pos = { 0, 1.2, 0 }, color = { 158, 152, 146 }, mat = "Concrete" })
		p:box({ name = "Borde", size = { w + 0.4, 0.3, d + 0.4 }, pos = { 0, 2.55, 0 }, color = { 184, 178, 170 }, mat = "Concrete" })
		p:box({ name = "Tierra", size = { w - 0.6, 0.2, d - 0.6 }, pos = { 0, 2.5, 0 }, color = { 74, 56, 44 }, mat = "Ground", folder = "Decoracion" })
		local n = math.max(1, math.floor(w / 3.5))
		for i = 1, n do
			local x = -w / 2 + (i - 0.5) * w / n
			P.bush(p, { x, 2.2, 0 }, math.min(d / 4, 0.9))
		end
	end

	function P.bench(g, pos, rotY, color)
		local b = g:at(pos, rotY)
		local wood = color or { 150, 100, 60 }
		for i = 0, 2 do
			b:box({ name = "Listón", size = { 6, 0.25, 0.45 }, pos = { 0, 1.7, -0.55 + i * 0.55 }, color = wood, mat = "WoodPlanks" })
		end
		for i = 0, 1 do
			b:box({ name = "Respaldo", size = { 6, 0.45, 0.2 }, pos = { 0, 2.4 + i * 0.6, 0.85 }, rot = { -10, 0, 0 }, color = wood, mat = "WoodPlanks" })
		end
		for _, x in ipairs({ -2.6, 2.6 }) do
			b:box({ name = "Pata", size = { 0.3, 1.6, 1.6 }, pos = { x, 0.8, 0 }, color = { 50, 50, 56 }, mat = "Metal" })
			b:box({ name = "Pata", size = { 0.3, 1.6, 0.3 }, pos = { x, 2.4, 0.95 }, color = { 50, 50, 56 }, mat = "Metal" })
		end
	end

	function P.trashCan(g, pos, color)
		local t = g:at(pos, 0)
		local c = color or { 52, 98, 70 }
		t:cylinder({ name = "Papelera", length = 3, diameter = 2.2, pos = { 0, 1.5, 0 }, color = c, mat = "Metal" })
		t:cylinder({ name = "Aro", length = 0.3, diameter = 2.4, pos = { 0, 2.9, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		t:cylinder({ name = "Tapa", length = 0.4, diameter = 2.3, pos = { 0, 3.2, 0 }, color = darker(c, 15), mat = "Metal", folder = "Decoracion" })
		t:cylinder({ name = "Base", length = 0.3, diameter = 2.4, pos = { 0, 0.15, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
	end

	function P.dumpster(g, pos, rotY, color)
		local d = g:at(pos, rotY)
		local c = color or { 58, 108, 72 }
		d:box({ name = "Contenedor", size = { 7, 4, 4 }, pos = { 0, 2.4, 0 }, color = c, mat = "Metal" })
		d:wedge({ name = "Tapa", size = { 7.1, 0.8, 4.1 }, pos = { 0, 4.8, 0 }, rot = { 0, 180, 0 }, color = darker(c, 20), mat = "Rubber" })
		for _, x in ipairs({ -2.8, 2.8 }) do
			for _, z in ipairs({ -1.4, 1.4 }) do
				d:cylinder({ name = "Rueda", axis = "x", length = 0.4, diameter = 0.9, pos = { x, 0.45, z }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
			end
		end
		d:box({ name = "Asa", size = { 6, 0.25, 0.25 }, pos = { 0, 3.6, -2.15 }, color = darker(c, 40), mat = "Metal", folder = "Decoracion" })
	end

	function P.cone(g, pos)
		local c = g:at(pos, 0)
		c:box({ name = "Base", size = { 1.6, 0.25, 1.6 }, pos = { 0, 0.12, 0 }, color = { 30, 30, 32 }, mat = "Rubber" })
		local sizes = { { 1.2, 0.6 }, { 0.95, 1.1 }, { 0.7, 1.6 }, { 0.45, 2.1 } }
		for i, s in ipairs(sizes) do
			c:cylinder({ name = "Cono", length = 0.55, diameter = s[1], pos = { 0, s[2] - 0.05, 0 }, color = (i == 3) and { 240, 240, 240 } or { 245, 110, 30 }, mat = "Rubber" })
		end
	end

	function P.tires(g, pos, count)
		local t = g:at(pos, 0)
		for i = 1, count or 3 do
			t:cylinder({ name = "Neumatico", length = 1, diameter = 3, pos = { (i % 2) * 0.2, 0.5 + (i - 1) * 1, 0 }, color = { 32, 32, 34 }, mat = "Rubber" })
			t:cylinder({ name = "Llanta", length = 1.02, diameter = 1.6, pos = { (i % 2) * 0.2, 0.5 + (i - 1) * 1, 0 }, color = { 60, 60, 64 }, mat = "Rubber", folder = "Decoracion" })
		end
	end

	function P.hydrant(g, pos)
		local h = g:at(pos, 0)
		h:cylinder({ name = "Hidrante", length = 2.2, diameter = 1, pos = { 0, 1.1, 0 }, color = { 200, 40, 36 }, mat = "Metal" })
		h:ball({ name = "Cabeza", diameter = 1.05, pos = { 0, 2.25, 0 }, color = { 200, 40, 36 }, mat = "Metal", folder = "Decoracion" })
		h:cylinder({ name = "Boca", axis = "x", length = 1.6, diameter = 0.45, pos = { 0, 1.5, 0 }, color = { 220, 200, 60 }, mat = "Metal", folder = "Decoracion" })
	end

	function P.streetLight(g, pos, rotY, height, color)
		local s = g:at(pos, rotY)
		local h = height or 18
		s:cylinder({ name = "Base", length = 1.2, diameter = 1.4, pos = { 0, 0.6, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		s:cylinder({ name = "Farola", length = h, diameter = 0.7, pos = { 0, h / 2, 0 }, color = { 74, 76, 84 }, mat = "Metal" })
		s:box({ name = "Brazo", size = { 0.4, 0.4, 5 }, pos = { 0, h - 0.4, -2.3 }, color = { 74, 76, 84 }, mat = "Metal", folder = "Decoracion" })
		s:box({ name = "Cabeza", size = { 1.6, 0.6, 3 }, pos = { 0, h - 0.6, -4.6 }, color = { 60, 62, 70 }, mat = "Metal", folder = "Decoracion" })
		local lamp = s:box({ name = "Bombilla", size = { 1.2, 0.15, 2.4 }, pos = { 0, h - 0.95, -4.6 }, color = color or { 255, 226, 170 }, mat = "Neon", folder = "Decoracion" })
		MB.light(lamp, "Spot", { face = "Bottom", color = color or { 255, 220, 160 }, brightness = 2, range = 40, angle = 100 })
	end

	function P.vending(g, pos, rotY, color, text)
		local v = g:at(pos, rotY)
		local c = color or { 200, 40, 50 }
		v:box({ name = "Maquina", size = { 4, 7, 3 }, pos = { 0, 3.5, 0 }, color = c })
		local front = v:box({ name = "Escaparate", size = { 2.6, 4.4, 0.1 }, pos = { -0.5, 4, -1.55 }, color = { 220, 236, 250 }, mat = "Neon", transparency = 0.15, folder = "Decoracion" })
		MB.light(front, "Surface", { face = "Front", color = { 210, 230, 255 }, brightness = 0.6, range = 8 })
		for i = 0, 3 do
			v:box({ name = "Latas", size = { 2.2, 0.5, 0.2 }, pos = { -0.5, 2.5 + i * 1, -1.5 }, color = ({ { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } })[i + 1], folder = "Decoracion" })
		end
		v:box({ name = "Botones", size = { 0.8, 3, 0.15 }, pos = { 1.45, 4.2, -1.55 }, color = { 40, 40, 46 }, folder = "Decoracion" })
		local top = v:box({ name = "Marca", size = { 4, 1.2, 0.1 }, pos = { 0, 6.6, -1.55 }, color = c, folder = "Decoracion" })
		MB.sign(top, text or "COLA", { font = "GothamBlack", color = { 255, 255, 255 }, glow = true })
	end

	function P.atm(g, pos, rotY)
		local a = g:at(pos, rotY)
		a:box({ name = "Cajero", size = { 3, 6, 2.4 }, pos = { 0, 3, 0 }, color = { 70, 80, 96 }, mat = "Metal" })
		local screen = a:box({ name = "Pantalla", size = { 1.6, 1.2, 0.1 }, pos = { 0, 4.4, -1.25 }, color = { 90, 200, 255 }, mat = "Neon", folder = "Decoracion" })
		MB.sign(screen, "ATM", { font = "GothamBlack", color = { 20, 40, 80 } })
		a:box({ name = "Teclado", size = { 1.6, 0.6, 0.6 }, pos = { 0, 3.2, -1.4 }, rot = { 20, 0, 0 }, color = { 40, 40, 46 }, folder = "Decoracion" })
	end

	function P.newspaperBox(g, pos, rotY, color)
		local n = g:at(pos, rotY)
		local c = color or { 40, 90, 170 }
		n:box({ name = "Periodicos", size = { 2, 3.4, 1.8 }, pos = { 0, 1.9, 0 }, color = c, mat = "Metal" })
		n:box({ name = "Ventana", size = { 1.4, 1, 0.1 }, pos = { 0, 2.6, -0.92 }, color = { 220, 230, 235 }, mat = "Glass", transparency = 0.2, folder = "Decoracion" })
		n:box({ name = "Pata", size = { 0.3, 0.2, 1.8 }, pos = { 0, 0.1, 0 }, color = { 40, 40, 44 }, folder = "Decoracion" })
	end

	-- Cartel plano (póster o señal) con fondo y texto
	function P.poster(g, pos, rotY, size, bg, text, textColor, font)
		local p = g:at(pos, rotY)
		local part = p:box({ name = "Poster", size = { size[1], size[2], 0.1 }, pos = { 0, 0, 0 }, color = bg, folder = "Decoracion" })
		MB.sign(part, text, { bg = bg, color = textColor or { 255, 255, 255 }, font = font or "FredokaOne" })
		return part
	end

	-- Letrero de neón: texto brillante sobre un panel oscuro con borde luminoso
	function P.neonSign(g, pos, rotY, size, text, color, font)
		local n = g:at(pos, rotY)
		local panel = n:box({ name = "Letrero", size = { size[1], size[2], 0.4 }, pos = { 0, 0, 0 }, color = { 24, 22, 30 }, folder = "Decoracion" })
		MB.sign(panel, text, { font = font or "FredokaOne", color = color, glow = true, width = 0.86, height = 0.72 })
		for _, y in ipairs({ -1, 1 }) do
			n:box({ name = "Borde", size = { size[1] + 0.3, 0.2, 0.5 }, pos = { 0, y * size[2] / 2, 0 }, color = color, mat = "Neon", folder = "Decoracion" })
		end
		for _, x in ipairs({ -1, 1 }) do
			n:box({ name = "Borde", size = { 0.2, size[2], 0.5 }, pos = { x * size[1] / 2, 0, 0 }, color = color, mat = "Neon", folder = "Decoracion" })
		end
		MB.light(panel, "Point", { color = color, brightness = 1.6, range = math.max(size[1], 10) })
		return panel
	end

	-- Guirnalda de bombillas colgando entre dos puntos
	function P.stringLights(g, a, b, count, sag, colors)
		local prev = nil
		for i = 0, count do
			local t = i / count
			local x = a[1] + (b[1] - a[1]) * t
			local z = a[3] + (b[3] - a[3]) * t
			local y = a[2] + (b[2] - a[2]) * t - sag * 4 * t * (1 - t)
			local point = { x, y, z }
			if prev then
				P.segment(g, prev, point, 0.08, { 30, 30, 30 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				local c = colors[(i % #colors) + 1]
				g:ball({ name = "Bombilla", diameter = 0.45, pos = { x, y - 0.25, z }, color = c, mat = "Neon", folder = "Decoracion" })
			end
			prev = point
		end
	end

	function P.chainFence(g, a, b, height)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local posts = math.max(2, math.floor(len / 8) + 1)
		local metal = { 140, 144, 150 }
		for i = 0, posts - 1 do
			local t = i / (posts - 1)
			g:cylinder({ name = "Poste", length = height, diameter = 0.35, pos = { a[1] + dx * t, height / 2, a[3] + dz * t }, color = metal, mat = "Metal" })
		end
		P.rod(g, { a[1], height, a[3] }, { b[1], height, b[3] }, 0.25, metal, "Metal")
		local yaw = math.deg(math.atan2(-dz, dx))
		g:box({ name = "Malla", size = { len, height - 0.4, 0.05 }, pos = { (a[1] + b[1]) / 2, height / 2, (a[3] + b[3]) / 2 }, rot = { 0, yaw, 0 }, color = { 120, 124, 130 }, mat = "DiamondPlate", transparency = 0.55 })
	end

	function P.woodFence(g, a, b, height, color)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local wood = color or { 168, 128, 88 }
		local yaw = math.deg(math.atan2(-dz, dx))
		local mid = { (a[1] + b[1]) / 2, 0, (a[3] + b[3]) / 2 }
		local f = g:at(mid, yaw)
		local n = math.floor(len / 1.1)
		for i = 0, n do
			local x = -len / 2 + i * len / n
			f:box({ name = "Tabla", size = { 0.8, height, 0.25 }, pos = { x, height / 2, 0 }, color = (i % 3 == 0) and darker(wood, 15) or wood, mat = "WoodPlanks" })
		end
		for _, y in ipairs({ height * 0.3, height * 0.8 }) do
			f:box({ name = "Travesano", size = { len, 0.4, 0.3 }, pos = { 0, y, 0.25 }, color = darker(wood, 25), mat = "Wood", folder = "Decoracion" })
		end
	end

	-- Muro con zócalo y remate superior
	function P.wall(g, pos, rotY, size, color, baseColor, capColor, mat)
		local w = g:at(pos, rotY)
		w:box({ name = "Muro", size = size, pos = { 0, size[2] / 2, 0 }, color = color, mat = mat or "Plaster" })
		w:box({ name = "Zocalo", size = { size[1] + 0.1, 1.2, size[3] + 0.3 }, pos = { 0, 0.6, 0 }, color = baseColor or darker(color, 50), mat = "Concrete" })
		w:box({ name = "Remate", size = { size[1] + 0.3, 0.6, size[3] + 0.5 }, pos = { 0, size[2] - 0.3, 0 }, color = capColor or lighter(color, 20), mat = "Concrete" })
	end

	-- Ventana con marco, travesaños, cristal y alféizar (centrada en pos, mirando a -Z)
	function P.window(g, pos, rotY, w, h, frameColor, glassColor)
		local v = g:at(pos, rotY)
		local f = frameColor or { 60, 60, 70 }
		v:box({ name = "Cristal", size = { w, h, 0.2 }, pos = { 0, 0, 0 }, color = glassColor or { 168, 198, 214 }, mat = "Glass", transparency = 0.45 })
		for _, x in ipairs({ -w / 2, w / 2 }) do
			v:box({ name = "Marco", size = { 0.5, h + 0.5, 0.6 }, pos = { x, 0, 0 }, color = f, mat = "Metal" })
		end
		for _, y in ipairs({ -h / 2, h / 2 }) do
			v:box({ name = "Marco", size = { w + 0.5, 0.5, 0.6 }, pos = { 0, y, 0 }, color = f, mat = "Metal" })
		end
		v:box({ name = "Travesano", size = { 0.25, h, 0.4 }, pos = { 0, 0, 0 }, color = f, mat = "Metal", folder = "Decoracion" })
		v:box({ name = "Travesano", size = { w, 0.25, 0.4 }, pos = { 0, h * 0.15, 0 }, color = f, mat = "Metal", folder = "Decoracion" })
		v:box({ name = "Alfeizar", size = { w + 1, 0.35, 1.2 }, pos = { 0, -h / 2 - 0.4, -0.4 }, color = { 210, 206, 200 }, mat = "Concrete", folder = "Decoracion" })
	end

	-- Acera con bordillo (pos = centro, size = { largo X, ancho Z })
	function P.sidewalk(g, pos, size, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Acera", size = { size[1], 0.6, size[2] }, pos = { 0, 0.3, 0 }, color = { 176, 172, 166 }, mat = "Pavement" })
		s:box({ name = "Bordillo", size = { size[1], 0.7, 0.6 }, pos = { 0, 0.35, -size[2] / 2 + 0.3 }, color = { 206, 202, 196 }, mat = "Concrete" })
		local n = math.floor(size[1] / 6)
		for i = 1, n - 1 do
			s:box({ name = "Junta", size = { 0.12, 0.62, size[2] - 0.8 }, pos = { -size[1] / 2 + i * size[1] / n, 0.3, 0.3 }, color = { 140, 136, 130 }, mat = "Concrete", folder = "Decoracion" })
		end
	end

	function P.puddle(g, pos, diameter)
		g:cylinder({ name = "Charco", length = 0.06, diameter = diameter, pos = { pos[1], pos[2] + 0.03, pos[3] }, color = { 60, 66, 78 }, mat = "Glass", transparency = 0.25, reflectance = 0.3, folder = "Decoracion" })
	end

	function P.stain(g, pos, diameter)
		g:cylinder({ name = "Mancha", length = 0.04, diameter = diameter, pos = { pos[1], pos[2] + 0.02, pos[3] }, color = { 40, 36, 38 }, transparency = 0.5, folder = "Decoracion" })
	end

	function P.manhole(g, pos)
		g:cylinder({ name = "Alcantarilla", length = 0.08, diameter = 3, pos = { pos[1], pos[2] + 0.04, pos[3] }, color = { 64, 62, 60 }, mat = "DiamondPlate", folder = "Decoracion" })
	end

	-- =================================================================
	--  Vehículos
	-- =================================================================
	-- wrecked = true: coche abandonado (oxidado, con musgo, cristales sucios y luces apagadas)
	function P.car(g, pos, rotY, color, wrecked)
		local c = g:at(pos, rotY)
		local paint = color or { 190, 50, 50 }
		local trim = { 34, 34, 38 }
		c:box({ name = "Chasis", size = { 5.4, 1.4, 11.2 }, pos = { 0, 1.5, 0 }, color = paint, reflectance = 0.06 })
		c:box({ name = "Paragolpes", size = { 5.6, 0.9, 0.6 }, pos = { 0, 1.1, -5.7 }, color = trim })
		c:box({ name = "Paragolpes", size = { 5.6, 0.9, 0.6 }, pos = { 0, 1.1, 5.7 }, color = trim })
		c:box({ name = "Capo", size = { 5.2, 0.8, 3.4 }, pos = { 0, 2.6, -3.7 }, color = paint, reflectance = 0.06 })
		c:box({ name = "Maletero", size = { 5.2, 0.8, 2.2 }, pos = { 0, 2.6, 4.3 }, color = paint, reflectance = 0.06 })
		c:wedge({ name = "Parabrisas", size = { 4.9, 2, 1.8 }, pos = { 0, 4, -1.1 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:box({ name = "Habitaculo", size = { 4.9, 2, 3.2 }, pos = { 0, 4, 1.4 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:wedge({ name = "Luneta", size = { 4.9, 2, 1.2 }, pos = { 0, 4, 3.6 }, rot = { 0, 180, 0 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:box({ name = "Techo", size = { 4.9, 0.3, 3.4 }, pos = { 0, 5.1, 1.3 }, color = paint, reflectance = 0.06 })
		for _, x in ipairs({ -2.5, 2.5 }) do
			c:box({ name = "Pilar", size = { 0.2, 2, 0.3 }, pos = { x, 4, 0.2 }, color = paint, folder = "Decoracion" })
			c:box({ name = "Retrovisor", size = { 0.5, 0.4, 0.3 }, pos = { x * 1.12, 3.3, -1.6 }, color = paint, folder = "Decoracion" })
			for _, z in ipairs({ -3.6, 3.6 }) do
				c:box({ name = "Paso", size = { 0.3, 1.9, 3.3 }, pos = { x * 1.02, 1.6, z }, color = trim, folder = "Decoracion" })
				c:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 2.6, pos = { x * 0.98, 1.3, z }, color = { 28, 28, 30 }, mat = "Rubber" })
				c:cylinder({ name = "Llanta", axis = "x", length = 1.04, diameter = 1.4, pos = { x * 0.98, 1.3, z }, color = { 180, 182, 188 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		for _, x in ipairs({ -1.9, 1.9 }) do
			c:box({ name = "Faro", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, -5.62 }, color = wrecked and { 120, 120, 110 } or { 255, 244, 214 }, mat = wrecked and "Glass" or "Neon", folder = "Decoracion" })
			c:box({ name = "Piloto", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, 5.62 }, color = wrecked and { 90, 30, 30 } or { 210, 30, 30 }, mat = wrecked and "Glass" or "Neon", folder = "Decoracion" })
		end
		if wrecked then
			c:box({ name = "Musgo", size = { 4.4, 0.25, 2.6 }, pos = { 0.3, 5.3, 1.6 }, color = { 74, 104, 56 }, mat = "LeafyGrass", folder = "Decoracion" })
			c:box({ name = "Musgo", size = { 3.6, 0.25, 2 }, pos = { -0.4, 3.05, -3.8 }, color = { 84, 110, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
			c:box({ name = "Oxido", size = { 5.45, 0.8, 4 }, pos = { 0, 1.2, 2 }, color = { 120, 70, 44 }, mat = "CorrodedMetal", folder = "Decoracion" })
		end
		c:box({ name = "Matricula", size = { 1.8, 0.6, 0.1 }, pos = { 0, 1.2, 6.03 }, color = { 240, 240, 236 }, folder = "Decoracion" })
	end

	function P.truck(g, pos, rotY, color)
		local t = g:at(pos, rotY)
		local paint = color or { 236, 236, 232 }
		t:box({ name = "Chasis", size = { 7, 1.2, 22 }, pos = { 0, 1.6, 2 }, color = { 46, 46, 52 }, mat = "Metal" })
		local cargo = t:box({ name = "Caja", size = { 8, 8.5, 15 }, pos = { 0, 6.45, 5.5 }, color = paint })
		for i = 0, 4 do
			t:box({ name = "Nervio", size = { 8.1, 0.25, 0.25 }, pos = { 0, 2.6 + i * 2, -2.05 }, color = darker(paint, 30), folder = "Decoracion" })
		end
		t:box({ name = "Cabina", size = { 7.6, 4.2, 5.5 }, pos = { 0, 4.3, -5.3 }, color = { 200, 60, 50 } })
		t:wedge({ name = "Parabrisas", size = { 7.4, 2.2, 2.2 }, pos = { 0, 7.5, -6.95 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		t:box({ name = "TechoCabina", size = { 7.6, 2.2, 3.3 }, pos = { 0, 7.5, -4.2 }, color = { 200, 60, 50 } })
		t:box({ name = "Rejilla", size = { 5, 1.6, 0.15 }, pos = { 0, 3.4, -8.1 }, color = { 50, 50, 56 }, mat = "DiamondPlate", folder = "Decoracion" })
		for _, x in ipairs({ -2.9, 2.9 }) do
			t:box({ name = "Faro", size = { 1.2, 0.7, 0.15 }, pos = { x, 3.4, -8.12 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for _, w in ipairs({ { -3.6, -5.5 }, { 3.6, -5.5 }, { -3.6, 4 }, { 3.6, 4 }, { -3.6, 9 }, { 3.6, 9 } }) do
			t:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3, pos = { w[1], 1.5, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
			t:cylinder({ name = "Llanta", axis = "x", length = 1.04, diameter = 1.5, pos = { w[1], 1.5, w[2] }, color = { 170, 172, 178 }, mat = "Metal", folder = "Decoracion" })
		end
		return cargo
	end

	function P.forklift(g, pos, rotY, color)
		local f = g:at(pos, rotY)
		local c = color or { 230, 160, 30 }
		f:box({ name = "Carretilla", size = { 4.4, 2.6, 6 }, pos = { 0, 2, 0.4 }, color = c })
		f:box({ name = "Contrapeso", size = { 4.4, 2.2, 1.4 }, pos = { 0, 2.6, 3.4 }, color = darker(c, 40) })
		f:box({ name = "Asiento", size = { 1.8, 1.2, 1.6 }, pos = { 0, 3.9, 1.4 }, color = { 30, 30, 32 }, mat = "Leather", folder = "Decoracion" })
		for _, x in ipairs({ -1.9, 1.9 }) do
			for _, z in ipairs({ -1.4, 2.4 }) do
				f:box({ name = "Pilar", size = { 0.25, 4, 0.25 }, pos = { x, 5.3, z }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
			end
			f:box({ name = "Mastil", size = { 0.4, 9, 0.6 }, pos = { x * 0.8, 4.8, -2.9 }, color = { 50, 50, 56 }, mat = "Metal" })
			f:box({ name = "Horquilla", size = { 0.5, 0.25, 4 }, pos = { x * 0.5, 0.5, -4.9 }, color = { 50, 50, 56 }, mat = "Metal" })
		end
		f:box({ name = "Techo", size = { 4.2, 0.25, 4.2 }, pos = { 0, 7.4, 0.5 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
		for _, w in ipairs({ { -2.2, -1.6 }, { 2.2, -1.6 }, { -2.2, 2.6 }, { 2.2, 2.6 } }) do
			f:cylinder({ name = "Rueda", axis = "x", length = 0.9, diameter = 1.9, pos = { w[1], 0.95, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
		end
	end

	-- =================================================================
	--  Industrial y tejados
	-- =================================================================
	function P.container(g, pos, rotY, color, open, label)
		local c = g:at(pos, rotY)
		local L, H, W = 21, 9, 8.5
		local dark = darker(color, 45)
		if open then
			c:box({ name = "Suelo", size = { L, 0.6, W }, pos = { 0, 0.3, 0 }, color = { 70, 64, 58 }, mat = "WoodPlanks" })
			c:box({ name = "Techo", size = { L, 0.6, W }, pos = { 0, H - 0.3, 0 }, color = color, mat = "Metal" })
			c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, -W / 2 + 0.3 }, color = color, mat = "Metal" })
			c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, W / 2 - 0.3 }, color = color, mat = "Metal" })
			local lamp = c:box({ name = "Lampara", size = { 4, 0.2, 0.6 }, pos = { 0, H - 0.7, 0 }, color = { 255, 236, 200 }, mat = "Neon", folder = "Decoracion" })
			MB.light(lamp, "Point", { color = { 255, 226, 180 }, brightness = 1.2, range = 14 })
		else
			c:box({ name = "Contenedor", size = { L, H, W }, pos = { 0, H / 2, 0 }, color = color, mat = "Metal" })
			for _, z in ipairs({ -W / 4, W / 4 }) do
				c:box({ name = "Puerta", size = { 0.3, H - 0.8, W / 2 - 0.3 }, pos = { L / 2 + 0.12, H / 2, z }, color = dark, mat = "Metal", folder = "Decoracion" })
				for _, dz in ipairs({ -0.9, 0.9 }) do
					c:box({ name = "Cierre", size = { 0.25, H - 1.4, 0.2 }, pos = { L / 2 + 0.3, H / 2, z + dz }, color = { 150, 150, 156 }, mat = "Metal", folder = "Decoracion" })
				end
			end
		end
		-- Esquinas reforzadas
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				for _, y in ipairs({ 0.35, H - 0.35 }) do
					c:box({ name = "Esquina", size = { 0.8, 0.7, 0.8 }, pos = { x * (L / 2 - 0.3), y, z * (W / 2 - 0.3) }, color = darker(color, 60), mat = "Metal", folder = "Decoracion" })
				end
			end
		end
		for i = 0, 8 do
			local x = -L / 2 + 1.5 + i * 2.25
			for _, side in ipairs({ -1, 1 }) do
				c:box({ name = "Nervio", size = { 0.6, H - 0.9, 0.25 }, pos = { x, H / 2, side * (W / 2 + 0.1) }, color = dark, mat = "Metal", folder = "Decoracion" })
			end
		end
		if label then
			for _, side in ipairs({ -1, 1 }) do
				local panel = c:box({ name = "Rotulo", size = { 9, 1.8, 0.1 }, pos = { 0, H - 1.6, side * (W / 2 + 0.3) }, rot = { 0, side > 0 and 180 or 0, 0 }, color = color, transparency = 1, folder = "Decoracion" })
				MB.sign(panel, label, { font = "GothamBlack", color = { 240, 240, 236 } })
			end
		end
	end

	function P.acUnit(g, pos, rotY)
		local a = g:at(pos, rotY)
		local body = { 186, 190, 196 }
		a:box({ name = "AireAcondicionado", size = { 7, 4.5, 5 }, pos = { 0, 2.55, 0 }, color = body, mat = "Metal" })
		a:box({ name = "Patas", size = { 6.6, 0.3, 4.6 }, pos = { 0, 0.15, 0 }, color = { 80, 82, 88 }, mat = "Metal" })
		for i = 0, 7 do
			a:box({ name = "Aleta", size = { 0.12, 3, 0.25 }, pos = { -2.4 + i * 0.7, 2.6, -2.55 }, color = { 120, 124, 132 }, mat = "Metal", folder = "Decoracion" })
		end
		a:cylinder({ name = "Ventilador", length = 0.3, diameter = 3.6, pos = { 0, 4.95, 0.4 }, color = { 60, 62, 70 }, mat = "DiamondPlate", folder = "Decoracion" })
		a:cylinder({ name = "Rejilla", length = 0.32, diameter = 1, pos = { 0, 4.97, 0.4 }, color = { 140, 144, 150 }, mat = "Metal", folder = "Decoracion" })
		P.rod(a, { 3.5, 1.2, 1 }, { 4.6, 1.2, 1 }, 0.5, { 120, 124, 132 }, "Metal", "Decoracion")
	end

	function P.vent(g, pos)
		local v = g:at(pos, 0)
		v:cylinder({ name = "Chimenea", length = 2.6, diameter = 1.2, pos = { 0, 1.3, 0 }, color = { 150, 154, 160 }, mat = "Metal" })
		v:cylinder({ name = "Sombrero", length = 0.4, diameter = 2, pos = { 0, 3, 0 }, color = { 120, 124, 130 }, mat = "Metal", folder = "Decoracion" })
	end

	function P.waterTank(g, pos)
		local w = g:at(pos, 0)
		local metal = { 90, 92, 100 }
		for _, o in ipairs({ { -3.2, -3.2 }, { 3.2, -3.2 }, { -3.2, 3.2 }, { 3.2, 3.2 } }) do
			w:box({ name = "Pata", size = { 0.8, 6.5, 0.8 }, pos = { o[1], 3.25, o[2] }, color = metal, mat = "Metal" })
		end
		P.segment(w, { -3.2, 0.5, -3.2 }, { 3.2, 6, -3.2 }, 0.3, metal, "Metal", "Decoracion")
		P.segment(w, { 3.2, 0.5, 3.2 }, { -3.2, 6, 3.2 }, 0.3, metal, "Metal", "Decoracion")
		w:box({ name = "Base", size = { 8, 0.5, 8 }, pos = { 0, 6.75, 0 }, color = metal, mat = "DiamondPlate" })
		w:cylinder({ name = "Deposito", length = 8, diameter = 8.5, pos = { 0, 11, 0 }, color = { 122, 94, 72 }, mat = "WoodPlanks" })
		for _, y in ipairs({ 8, 10.6, 13.2 }) do
			w:cylinder({ name = "Aro", length = 0.3, diameter = 8.7, pos = { 0, y, 0 }, color = { 56, 56, 62 }, mat = "Metal", folder = "Decoracion" })
		end
		for i, d in ipairs({ 8.8, 6.6, 4.2, 1.8 }) do
			w:cylinder({ name = "Tejadillo", length = 0.7, diameter = d, pos = { 0, 15 + i * 0.6, 0 }, color = { 70, 66, 70 }, mat = "RoofShingles", folder = "Decoracion" })
		end
		w:truss({ name = "Escalera", size = { 2, 10, 2 }, pos = { 0, 11, 5.3 }, color = metal })
	end

	function P.satelliteDish(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:cylinder({ name = "Mastil", length = 3, diameter = 0.5, pos = { 0, 1.5, 0 }, color = { 140, 144, 150 }, mat = "Metal" })
		s:cylinder({ name = "Plato", axis = "z", length = 0.4, diameter = 5, pos = { 0, 3.6, -0.4 }, rot = { 25, 0, 0 }, color = { 220, 222, 226 }, folder = "Decoracion" })
		P.rod(s, { 0, 3.6, -0.6 }, { 0, 3.2, -2.6 }, 0.15, { 120, 124, 130 }, "Metal", "Decoracion")
	end

	function P.floodLight(g, pos, rotY, height)
		local f = g:at(pos, rotY)
		f:box({ name = "Torre", size = { 1.4, height, 1.4 }, pos = { 0, height / 2, 0 }, color = { 150, 154, 160 }, mat = "Metal" })
		for _, x in ipairs({ -1, 1 }) do
			P.segment(f, { x * 2.5, 0, 0 }, { 0, height * 0.45, 0 }, 0.4, { 150, 154, 160 }, "Metal")
		end
		f:box({ name = "Soporte", size = { 6, 0.4, 0.6 }, pos = { 0, height + 0.2, 0 }, color = { 70, 72, 80 }, mat = "Metal" })
		for _, x in ipairs({ -2, 0, 2 }) do
			local lamp = f:box({ name = "Foco", size = { 1.6, 1.2, 0.5 }, pos = { x, height + 0.9, -0.3 }, rot = { -20, 0, 0 }, color = { 255, 248, 230 }, mat = "Neon", folder = "Decoracion" })
			if x == 0 then
				MB.light(lamp, "Spot", { face = "Front", brightness = 2, range = 60, angle = 70, color = { 255, 246, 226 } })
			end
		end
	end

	function P.pallet(g, pos, rotY)
		local p = g:at(pos, rotY)
		for _, z in ipairs({ -1.6, 0, 1.6 }) do
			p:box({ name = "Taco", size = { 4.4, 0.5, 0.6 }, pos = { 0, 0.25, z }, color = { 150, 110, 70 }, mat = "Wood" })
		end
		for i = 0, 4 do
			p:box({ name = "Tabla", size = { 0.7, 0.25, 4 }, pos = { -1.8 + i * 0.9, 0.62, 0 }, color = { 182, 136, 88 }, mat = "WoodPlanks" })
		end
	end

	function P.drum(g, pos, color)
		local d = g:at(pos, 0)
		local c = color or { 48, 92, 150 }
		d:cylinder({ name = "Bidon", length = 3.4, diameter = 2.4, pos = { 0, 1.7, 0 }, color = c, mat = "Metal" })
		for _, y in ipairs({ 1.1, 2.3 }) do
			d:cylinder({ name = "Aro", length = 0.15, diameter = 2.5, pos = { 0, y, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		end
		d:cylinder({ name = "Tapon", length = 0.1, diameter = 0.4, pos = { 0.6, 3.45, 0 }, color = { 200, 200, 200 }, folder = "Decoracion" })
	end

	function P.cableReel(g, pos, rotY)
		local r = g:at(pos, rotY)
		for _, x in ipairs({ -1.6, 1.6 }) do
			r:cylinder({ name = "Bobina", axis = "x", length = 0.5, diameter = 6, pos = { x, 3, 0 }, color = { 176, 132, 86 }, mat = "WoodPlanks" })
		end
		r:cylinder({ name = "Cable", axis = "x", length = 2.8, diameter = 4.2, pos = { 0, 3, 0 }, color = { 30, 30, 34 }, mat = "Rubber" })
	end

	function P.railing(g, from, to, height, color)
		local dx, dz = to[1] - from[1], to[3] - from[3]
		local length = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (from[1] + to[1]) / 2, from[2], (from[3] + to[3]) / 2 }, yaw)
		local metal = color or { 186, 188, 196 }
		local posts = math.max(2, math.floor(length / 4) + 1)
		for i = 0, posts - 1 do
			local x = -length / 2 + i * length / (posts - 1)
			r:cylinder({ name = "Poste", length = height, diameter = 0.3, pos = { x, height / 2, 0 }, color = metal, mat = "Metal" })
		end
		r:cylinder({ name = "Pasamanos", axis = "x", length = length, diameter = 0.35, pos = { 0, height, 0 }, color = metal, mat = "Metal" })
		r:cylinder({ name = "Barra", axis = "x", length = length, diameter = 0.18, pos = { 0, height / 2, 0 }, color = metal, mat = "Metal", folder = "Decoracion" })
	end

	-- Barandilla de skate (rail) sobre postes
	function P.skateRail(g, from, to, height)
		local metal = { 200, 202, 210 }
		P.rod(g, { from[1], from[2] + height, from[3] }, { to[1], to[2] + height, to[3] }, 0.45, metal, "Metal")
		for _, p in ipairs({ from, to }) do
			g:cylinder({ name = "Poste", length = height, diameter = 0.35, pos = { p[1], p[2] + height / 2, p[3] }, color = { 60, 62, 70 }, mat = "Metal" })
		end
	end

	function P.stairs(g, pos, rotY, steps, stepHeight, stepDepth, width, color, nosing)
		local s = g:at(pos, rotY)
		for i = 1, steps do
			local h = i * stepHeight
			s:box({ name = "Escalon", size = { width, h, stepDepth }, pos = { 0, h / 2, (i - 0.5) * stepDepth }, color = color, mat = "Concrete" })
			if nosing then
				s:box({ name = "Canto", size = { width, 0.12, 0.35 }, pos = { 0, h + 0.03, (i - 1) * stepDepth + 0.2 }, color = nosing, folder = "Decoracion" })
			end
		end
	end

	function P.quarterPipe(g, pos, rotY, width, radius, surface, side)
		local q = g:at(pos, rotY)
		local segments = 10
		local prevZ, prevY = 0, 0
		for i = 1, segments do
			local phi = math.rad(90 * i / segments)
			local z, y = radius * math.sin(phi), radius - radius * math.cos(phi)
			local dz, dy = z - prevZ, y - prevY
			local len = math.sqrt(dz * dz + dy * dy)
			local angle = math.deg(math.atan2(dy, dz))
			q:box({ name = "Curva", size = { width, 0.6, len + 0.15 }, pos = { 0, (y + prevY) / 2, (z + prevZ) / 2 }, rot = { -angle, 0, 0 }, color = surface, mat = "WoodPlanks" })
			local fill = math.min(y, prevY) - 0.3
			if fill > 0.2 then
				q:box({ name = "Relleno", size = { width - 0.2, fill, dz }, pos = { 0, fill / 2, (z + prevZ) / 2 }, color = side })
			end
			prevZ, prevY = z, y
		end
		q:cylinder({ name = "Coping", axis = "x", length = width, diameter = 0.7, pos = { 0, radius, radius }, color = { 200, 202, 210 }, mat = "Metal" })
	end

	-- Gradas para el público
	function P.bleachers(g, pos, rotY, rows, width, colors)
		local b = g:at(pos, rotY)
		for i = 1, rows do
			local h = i * 1.6
			b:box({ name = "Grada", size = { width, h, 2.4 }, pos = { 0, h / 2, (i - 0.5) * 2.4 }, color = { 70, 70, 82 }, mat = "Concrete" })
			b:box({ name = "Asiento", size = { width - 0.4, 0.3, 1.2 }, pos = { 0, h + 0.15, (i - 0.5) * 2.4 - 0.4 }, color = colors[(i % #colors) + 1], folder = "Decoracion" })
		end
	end

	function P.skateboardRack(g, pos, rotY)
		local r = g:at(pos, rotY)
		r:box({ name = "Panel", size = { 12, 6, 0.4 }, pos = { 0, 4, 0 }, color = { 60, 58, 70 }, mat = "WoodPlanks" })
		local colors = { { 245, 122, 192 }, { 112, 206, 186 }, { 242, 202, 66 }, { 120, 140, 240 }, { 240, 110, 80 } }
		for i = 1, 5 do
			local x = -5 + (i - 1) * 2.5
			r:box({ name = "Tabla", size = { 1.6, 5, 0.2 }, pos = { x, 4, -0.35 }, color = colors[i], folder = "Decoracion" })
			for _, y in ipairs({ 2.2, 5.8 }) do
				r:cylinder({ name = "Rueda", axis = "x", length = 1.2, diameter = 0.45, pos = { x, y, -0.6 }, color = { 240, 240, 236 }, folder = "Decoracion" })
			end
		end
	end

	function P.speaker(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Altavoz", size = { 3, 5, 2.6 }, pos = { 0, 2.5, 0 }, color = { 30, 30, 34 }, mat = "Fabric" })
		for _, y in ipairs({ 1.6, 3.6 }) do
			s:cylinder({ name = "Cono", axis = "z", length = 0.2, diameter = (y > 2) and 1.4 or 2.2, pos = { 0, y, -1.32 }, color = { 60, 60, 66 }, mat = "Rubber", folder = "Decoracion" })
		end
	end

	function P.lockers(g, pos, rotY, count, color)
		local l = g:at(pos, rotY)
		local c = color or { 112, 206, 186 }
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 2.1
			l:box({ name = "Taquilla", size = { 2, 7, 2.4 }, pos = { x, 3.5, 0 }, color = (i % 2 == 0) and c or darker(c, 18), mat = "Metal" })
			for j = 0, 2 do
				l:box({ name = "Rejilla", size = { 1.2, 0.15, 0.1 }, pos = { x, 5.8 + j * 0.35, -1.22 }, color = darker(c, 60), folder = "Decoracion" })
			end
			l:box({ name = "Tirador", size = { 0.15, 0.8, 0.15 }, pos = { x + 0.6, 3.6, -1.25 }, color = { 200, 200, 206 }, mat = "Metal", folder = "Decoracion" })
		end
	end

	function P.umbrellaTable(g, pos, color)
		local u = g:at(pos, 0)
		u:cylinder({ name = "Mesa", length = 0.3, diameter = 4, pos = { 0, 2.6, 0 }, color = { 236, 236, 232 } })
		u:cylinder({ name = "Pie", length = 2.6, diameter = 0.4, pos = { 0, 1.3, 0 }, color = { 60, 60, 66 }, mat = "Metal" })
		u:cylinder({ name = "Palo", length = 5, diameter = 0.25, pos = { 0, 5.1, 0 }, color = { 200, 200, 206 }, mat = "Metal", folder = "Decoracion" })
		for i, d in ipairs({ 8, 6, 3.6 }) do
			u:cylinder({ name = "Sombrilla", length = 0.4, diameter = d, pos = { 0, 7.2 + i * 0.35, 0 }, color = (i % 2 == 1) and color or { 245, 245, 240 }, mat = "Fabric", folder = "Decoracion" })
		end
		for _, a in ipairs({ 0, 120, 240 }) do
			local r = math.rad(a)
			u:box({ name = "Silla", size = { 1.6, 1.8, 1.6 }, pos = { math.cos(r) * 3, 0.9, math.sin(r) * 3 }, color = { 240, 240, 236 }, folder = "Decoracion" })
		end
	end

	function P.propaneCage(g, pos, rotY)
		local c = g:at(pos, rotY)
		c:box({ name = "Jaula", size = { 6, 5, 2.6 }, pos = { 0, 2.5, 0 }, color = { 150, 154, 160 }, mat = "DiamondPlate", transparency = 0.55 })
		c:box({ name = "Techo", size = { 6.2, 0.3, 2.8 }, pos = { 0, 5.15, 0 }, color = { 60, 110, 170 }, mat = "Metal" })
		for i = 0, 3 do
			c:cylinder({ name = "Bombona", length = 2.4, diameter = 1.2, pos = { -2.1 + i * 1.4, 1.3, 0 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })
		end
		local sign = c:box({ name = "Cartel", size = { 3, 0.8, 0.1 }, pos = { 0, 4.2, -1.36 }, color = { 60, 110, 170 }, folder = "Decoracion" })
		MB.sign(sign, "PROPANO", { bg = { 60, 110, 170 }, font = "GothamBlack" })
	end

	-- Poste con cartel de precios
	function P.pricePylon(g, pos, rotY, brand, color)
		local p = g:at(pos, rotY)
		p:box({ name = "Peana", size = { 6, 1.4, 3 }, pos = { 0, 0.7, 0 }, color = { 180, 176, 170 }, mat = "Concrete" })
		for _, x in ipairs({ -2, 2 }) do
			p:box({ name = "Pilar", size = { 0.8, 14, 0.8 }, pos = { x, 7, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		end
		local top = p:box({ name = "Marca", size = { 7, 3.4, 1.2 }, pos = { 0, 15.5, 0 }, color = color })
		for _, face in ipairs({ "Front", "Back" }) do
			MB.sign(top, brand, { face = face, font = "GothamBlack", color = { 255, 255, 255 } })
		end
		local prices = p:box({ name = "Precios", size = { 6, 5.4, 1 }, pos = { 0, 11, 0 }, color = { 30, 30, 34 } })
		for _, face in ipairs({ "Front", "Back" }) do
			MB.sign(prices, "95  1.89\nDIESEL  1.74", { face = face, font = "Arcade", color = { 255, 210, 60 }, glow = true, height = 0.9 })
		end
	end

	function P.guardrail(g, a, b)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (a[1] + b[1]) / 2, 0, (a[3] + b[3]) / 2 }, yaw)
		r:box({ name = "Bionda", size = { len, 1, 0.3 }, pos = { 0, 2, 0 }, color = { 190, 194, 200 }, mat = "Metal" })
		for i = 0, math.floor(len / 6) do
			r:box({ name = "Poste", size = { 0.4, 2.4, 0.4 }, pos = { -len / 2 + i * 6, 1.2, 0.3 }, color = { 120, 124, 130 }, mat = "Metal" })
		end
	end

	-- Barrera de hormigón tipo New Jersey (a lo largo de X local)
	function P.barrier(g, pos, rotY)
		local b = g:at(pos, rotY)
		local concrete = { 226, 224, 218 }
		b:box({ name = "Barrera", size = { 8, 1.4, 2.6 }, pos = { 0, 0.7, 0 }, color = concrete, mat = "Concrete" })
		b:wedge({ name = "Barrera", size = { 8, 1.2, 0.7 }, pos = { 0, 2, -0.95 }, color = concrete, mat = "Concrete" })
		b:wedge({ name = "Barrera", size = { 8, 1.2, 0.7 }, pos = { 0, 2, 0.95 }, rot = { 0, 180, 0 }, color = concrete, mat = "Concrete" })
		b:box({ name = "Barrera", size = { 8, 2.2, 1.2 }, pos = { 0, 2.5, 0 }, color = concrete, mat = "Concrete" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			b:box({ name = "Franja", size = { 1.6, 0.9, 2.7 }, pos = { x, 0.75, 0 }, color = { 205, 45, 45 }, folder = "Decoracion" })
		end
	end

	-- Poste eléctrico de ladrillo con travesaño (devuelve la altura de los cables)
	function P.pole(g, pos, height)
		local p = g:at(pos, 0)
		p:box({ name = "Poste", size = { 1.8, height, 1.8 }, pos = { 0, height / 2, 0 }, color = { 150, 82, 66 }, mat = "Brick" })
		p:box({ name = "Remate", size = { 2.2, 0.6, 2.2 }, pos = { 0, height + 0.3, 0 }, color = { 120, 70, 58 }, mat = "Concrete", folder = "Decoracion" })
		p:box({ name = "Travesano", size = { 9, 0.6, 0.6 }, pos = { 0, height - 1.5, 0 }, color = { 90, 70, 55 }, mat = "Wood", folder = "Decoracion" })
		for _, x in ipairs({ -3.5, 0, 3.5 }) do
			p:cylinder({ name = "Aislante", length = 0.8, diameter = 0.4, pos = { x, height - 0.8, 0 }, color = { 200, 200, 190 }, folder = "Decoracion" })
		end
		p:box({ name = "Transformador", size = { 1.6, 2.6, 1.6 }, pos = { 0, height - 5, -1.6 }, color = { 120, 124, 130 }, mat = "Metal", folder = "Decoracion" })
		return height - 0.6
	end

	-- Lámpara de techo con panel de neón y luz hacia abajo
	function P.ceilingLight(g, pos, withLight, color)
		local l = g:at(pos, 0)
		l:box({ name = "Carcasa", size = { 10, 0.6, 3 }, pos = { 0, 0, 0 }, color = { 50, 48, 60 }, folder = "Decoracion" })
		local panel = l:box({ name = "Panel", size = { 9, 0.2, 2.4 }, pos = { 0, -0.4, 0 }, color = color or { 255, 238, 214 }, mat = "Neon", folder = "Decoracion" })
		for _, x in ipairs({ -4, 4 }) do
			l:box({ name = "Cable", size = { 0.1, 2.2, 0.1 }, pos = { x, 1.4, 0 }, color = { 30, 30, 30 }, folder = "Decoracion" })
		end
		if withLight then
			MB.light(panel, "Surface", { face = "Bottom", brightness = 1.5, range = 40, angle = 120, color = color or { 255, 236, 210 } })
		end
	end

	-- Surtidor de gasolina
	function P.pump(g, pos, rotY)
		local p = g:at(pos, rotY)
		p:box({ name = "Surtidor", size = { 2.6, 5.4, 1.8 }, pos = { 0, 2.7, 0 }, color = { 236, 232, 228 } })
		p:box({ name = "Base", size = { 2.8, 0.6, 2 }, pos = { 0, 0.3, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		p:box({ name = "Cabezal", size = { 2.8, 1.2, 2 }, pos = { 0, 5.9, 0 }, color = { 205, 45, 45 } })
		for _, z in ipairs({ -0.95, 0.95 }) do
			p:box({ name = "Pantalla", size = { 1.8, 1, 0.1 }, pos = { 0, 4, z }, color = { 120, 230, 140 }, mat = "Neon", folder = "Decoracion" })
			p:box({ name = "Teclado", size = { 1.2, 0.8, 0.1 }, pos = { 0, 2.8, z }, color = { 40, 40, 46 }, folder = "Decoracion" })
		end
		for _, x in ipairs({ -1.45, 1.45 }) do
			p:box({ name = "Pistola", size = { 0.3, 1, 0.5 }, pos = { x, 3.4, 0 }, color = ({ { 40, 160, 60 }, { 30, 30, 30 } })[x < 0 and 1 or 2], folder = "Decoracion" })
			P.rod(p, { x, 3, 0 }, { x * 1.1, 0.6, 0.6 }, 0.2, { 30, 30, 30 }, "Rubber", "Decoracion")
		end
	end


	-- =================================================================
	--  Edificios configurables por país
	-- =================================================================
	local function copyTable(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	-- Casa con la fachada hacia -Z local. o: w, h, d, color, mat, trim, floors, cols, roof ("flat", "gable", "pagoda"),
	-- roofColor, roofMat, door, doorColor, shutters, balcony, flowers, shop (texto), shopColor, logs, fireEscape, lit
	function P.house(g, pos, rotY, o)
		local h = g:at(pos, rotY)
		local w, H, d = o.w or 12, o.h or 14, o.d or 10
		local wall = o.color or { 240, 236, 228 }
		local trim = o.trim or darker(wall, 60)
		h:box({ name = "Casa", size = { w, H, d }, pos = { 0, H / 2, 0 }, color = wall, mat = o.mat or "Plaster" })
		h:box({ name = "Zocalo", size = { w + 0.1, 1.4, d + 0.3 }, pos = { 0, 0.7, 0 }, color = o.base or darker(wall, 70), mat = "Concrete" })
		if o.roof == "gable" or o.roof == "pagoda" then
			local rh = o.roofHeight or 4
			local over = o.roof == "pagoda" and 2.6 or 0.9
			local rc = o.roofColor or { 176, 82, 56 }
			local rmat = o.roofMat or "ClayRoofTiles"
			h:wedge({ name = "Tejado", size = { w + over * 2, rh, d / 2 + over }, pos = { 0, H + rh / 2, -d / 4 - over / 2 }, color = rc, mat = rmat })
			h:wedge({ name = "Tejado", size = { w + over * 2, rh, d / 2 + over }, pos = { 0, H + rh / 2, d / 4 + over / 2 }, rot = { 0, 180, 0 }, color = rc, mat = rmat })
			h:box({ name = "Alero", size = { w + over * 2, 0.5, 0.5 }, pos = { 0, H + 0.1, -d / 2 - over + 0.25 }, color = o.eaveColor or darker(rc, 40), folder = "Decoracion" })
		else
			h:box({ name = "Cornisa", size = { w + 0.6, 0.8, d + 0.6 }, pos = { 0, H + 0.4, 0 }, color = trim, mat = "Concrete" })
		end
		local floors = o.floors or math.max(1, math.floor(H / 6.5))
		local fh = H / floors
		local cols = o.cols or math.max(1, math.floor(w / 5))
		local front = -d / 2
		local doorCol = math.ceil(cols / 2)
		for f = 1, floors do
			local y = (f - 1) * fh + fh * 0.55
			for c = 1, cols do
				local x = -w / 2 + (c - 0.5) * w / cols
				if f == 1 and o.shop and c == doorCol then
					-- Tienda: escaparate ancho, toldo y rótulo
					h:box({ name = "Escaparate", size = { math.min(w - 2, 8), 4.6, 0.3 }, pos = { 0, 3.3, front - 0.1 }, color = o.lit and { 255, 214, 150 } or { 70, 90, 110 }, mat = o.lit and "Neon" or "Glass", transparency = o.lit and 0.35 or 0.1, folder = "Decoracion" })
					h:wedge({ name = "Toldo", size = { math.min(w - 1, 9), 1.2, 2.4 }, pos = { 0, 6.4, front - 1.2 }, color = o.shopColor or { 200, 50, 50 }, mat = "Fabric", folder = "Decoracion" })
					local sign = h:box({ name = "Rotulo", size = { math.min(w - 2, 9), 1.6, 0.3 }, pos = { 0, 7.9, front - 0.2 }, color = o.shopColor or { 200, 50, 50 }, folder = "Decoracion" })
					MB.sign(sign, o.shop, { font = o.shopFont or "GothamBlack", color = { 255, 255, 255 }, glow = o.lit })
				elseif f == 1 and o.door ~= false and c == doorCol then
					h:box({ name = "Puerta", size = { 3, 6, 0.3 }, pos = { x, 3, front - 0.1 }, color = o.doorColor or { 120, 72, 42 }, mat = "WoodPlanks", folder = "Decoracion" })
					h:box({ name = "Dintel", size = { 3.8, 0.5, 0.45 }, pos = { x, 6.25, front - 0.15 }, color = trim, folder = "Decoracion" })
				else
					h:box({ name = "Marco", size = { 2.8, 3.4, 0.3 }, pos = { x, y, front - 0.1 }, color = trim, folder = "Decoracion" })
					h:box({ name = "Ventana", size = { 2.2, 2.8, 0.34 }, pos = { x, y, front - 0.12 }, color = o.ruined and { 28, 32, 30 } or o.lit and ((f + c) % 3 == 0 and { 50, 56, 70 } or { 255, 206, 140 }) or (o.glass or { 66, 86, 108 }), mat = (o.lit and not o.ruined and (f + c) % 3 ~= 0) and "Neon" or "Glass", transparency = (o.lit and not o.ruined) and 0.3 or 0.1, folder = "Decoracion" })
					if o.ruined and (f * 5 + c * 3) % 4 == 0 then
						for _, r in ipairs({ 35, -35 }) do
							h:box({ name = "Tablon", size = { 3.4, 0.5, 0.15 }, pos = { x, y, front - 0.35 }, rot = { 0, 0, r }, color = { 120, 96, 70 }, mat = "WoodPlanks", folder = "Decoracion" })
						end
					end
					if o.shutters then
						for _, sx in ipairs({ -1.85, 1.85 }) do
							h:box({ name = "Contraventana", size = { 0.9, 3.2, 0.2 }, pos = { x + sx, y, front - 0.15 }, color = o.shutters, mat = "WoodPlanks", folder = "Decoracion" })
						end
					end
					if o.balcony and f > 1 then
						h:box({ name = "Balcon", size = { 3.6, 0.3, 1.4 }, pos = { x, y - 1.8, front - 0.7 }, color = trim, folder = "Decoracion" })
						h:box({ name = "Baranda", size = { 3.6, 0.15, 0.15 }, pos = { x, y - 0.7, front - 1.35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
						for _, bx in ipairs({ -1.7, 0, 1.7 }) do
							h:box({ name = "Barrote", size = { 0.12, 1.1, 0.12 }, pos = { x + bx, y - 1.2, front - 1.35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
						end
						if o.flowers then
							h:ball({ name = "Flores", diameter = 0.9, pos = { x - 1, y - 1.3, front - 0.8 }, color = o.flowers, mat = "LeafyGrass", folder = "Decoracion" })
						end
					end
				end
			end
		end
		if o.logs then
			for y = 1.8, H - 0.6, 1.25 do
				h:cylinder({ name = "Tronco", axis = "x", length = w + 0.6, diameter = 0.9, pos = { 0, y, front + 0.3 }, color = darker(wall, 10), mat = "Wood", folder = "Decoracion" })
			end
		end
		if o.ruined then
			P.overgrowth(h, w, H, front - 0.2)
		end
		if o.fireEscape and floors > 1 then
			for f = 2, floors do
				local y = (f - 1) * fh
				h:box({ name = "Escape", size = { w * 0.55, 0.25, 2.2 }, pos = { 0, y, front - 1.1 }, color = { 40, 40, 44 }, mat = "DiamondPlate", folder = "Decoracion" })
				h:box({ name = "Baranda", size = { w * 0.55, 0.15, 0.15 }, pos = { 0, y + 2.4, front - 2.15 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
				if f < floors then
					P.segment(h, { -w * 0.2, y + 0.2, front - 1.1 }, { w * 0.2, y + fh, front - 1.1 }, 0.5, { 40, 40, 44 }, "Metal", "Decoracion")
				end
			end
		end
	end

	-- Fila de casas a lo largo de X (de x0 a x1) con estilos que se van alternando
	function P.houseRow(g, z, rotY, x0, x1, styles, depth)
		local x, i = x0, 0
		while x < x1 - 3 do
			i = i + 1
			local o = copyTable(styles[(i - 1) % #styles + 1])
			o.w = math.min(o.w or 12, x1 - x)
			o.d = depth or o.d
			P.house(g, { x + o.w / 2, 0, z }, rotY, o)
			x = x + o.w
		end
	end

	-- =================================================================
	--  Vegetación y naturaleza
	-- =================================================================
	function P.pineTree(g, pos, scale, snowy)
		local t = g:at(pos, 0)
		local s = scale or 1
		t:cylinder({ name = "Tronco", length = 4 * s, diameter = 1.2 * s, pos = { 0, 2 * s, 0 }, color = { 90, 64, 46 }, mat = "Wood" })
		local tiers = { { 9, 4 }, { 7.4, 6.6 }, { 5.8, 9 }, { 4, 11.2 }, { 2.2, 13.2 } }
		for _, tier in ipairs(tiers) do
			t:cylinder({ name = "Ramas", length = 2.6 * s, diameter = tier[1] * s, pos = { 0, tier[2] * s, 0 }, color = { 46, 92, 62 }, mat = "LeafyGrass", folder = "Decoracion" })
			if snowy then
				t:cylinder({ name = "Nieve", length = 0.5 * s, diameter = tier[1] * 0.85 * s, pos = { 0, (tier[2] + 1.4) * s, 0 }, color = { 244, 248, 252 }, mat = "Snow", folder = "Decoracion" })
			end
		end
	end

	function P.palmTree(g, pos, scale)
		local t = g:at(pos, 0)
		local s = scale or 1
		local prev = { 0, 0, 0 }
		for i = 1, 6 do
			local nextPoint = { math.sin(i * 0.35) * 1.4 * s, i * 2.6 * s, 0 }
			P.rod(t, prev, nextPoint, (1.5 - i * 0.08) * s, { 150, 116, 78 }, "Wood")
			prev = nextPoint
		end
		local top = prev
		for k = 0, 7 do
			local a = k * 45
			local leaf = t:at(top, a)
			leaf:box({ name = "Hoja", size = { 1.6 * s, 0.25 * s, 7 * s }, pos = { 0, -0.6 * s, -3.2 * s }, rot = { -22, 0, 0 }, color = (k % 2 == 0) and { 76, 140, 62 } or { 96, 156, 70 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
		for k = 0, 2 do
			t:ball({ name = "Coco", diameter = 0.9 * s, pos = { top[1] + math.cos(k * 2.1) * 0.7 * s, top[2] - 0.6 * s, math.sin(k * 2.1) * 0.7 * s }, color = { 110, 80, 50 }, folder = "Decoracion" })
		end
	end

	function P.cactus(g, pos, scale)
		local c = g:at(pos, 0)
		local s = scale or 1
		local green = { 70, 130, 72 }
		c:cylinder({ name = "Cactus", length = 7 * s, diameter = 1.4 * s, pos = { 0, 3.5 * s, 0 }, color = green, mat = "Grass" })
		c:ball({ name = "Punta", diameter = 1.4 * s, pos = { 0, 7 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
		for _, side in ipairs({ -1, 1 }) do
			local y = (side > 0 and 3.2 or 4.2) * s
			c:cylinder({ name = "Brazo", axis = "x", length = 1.6 * s, diameter = 0.9 * s, pos = { side * 1.2 * s, y, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
			c:cylinder({ name = "Brazo", length = 2.4 * s, diameter = 0.9 * s, pos = { side * 1.9 * s, y + 1.1 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
			c:ball({ name = "Punta", diameter = 0.9 * s, pos = { side * 1.9 * s, y + 2.3 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
		end
	end

	function P.snowPile(g, pos, scale)
		local s = scale or 1
		for _, o in ipairs({ { 0, 0, 0, 5 }, { 1.8, 0, 0.8, 3.6 }, { -1.6, 0, -0.6, 3.4 } }) do
			g:ball({ name = "Nieve", diameter = o[4] * s, pos = { pos[1] + o[1] * s, pos[2] - o[4] * s * 0.25, pos[3] + o[3] * s }, color = { 242, 246, 252 }, mat = "Snow" })
		end
	end

	-- =================================================================
	--  Monumentos y estructuras
	-- =================================================================
	-- Puerta torii (se atraviesa a lo largo de X local)
	function P.torii(g, pos, rotY, width, height)
		local t = g:at(pos, rotY)
		local red = { 200, 46, 36 }
		for _, z in ipairs({ -width / 2, width / 2 }) do
			t:cylinder({ name = "Pilar", length = height, diameter = 1.4, pos = { 0, height / 2, z }, color = red, mat = "WoodPlanks" })
			t:cylinder({ name = "Base", length = 1, diameter = 1.9, pos = { 0, 0.5, z }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		t:box({ name = "Nuki", size = { 1, 1, width + 2 }, pos = { 0, height * 0.72, 0 }, color = red, mat = "WoodPlanks" })
		t:box({ name = "Kasagi", size = { 1.6, 1.2, width + 6 }, pos = { 0, height + 0.6, 0 }, color = { 30, 30, 32 }, mat = "WoodPlanks" })
		t:box({ name = "Shimaki", size = { 1.3, 0.9, width + 4.6 }, pos = { 0, height - 0.3, 0 }, color = red, mat = "WoodPlanks" })
		for _, z in ipairs({ -1, 1 }) do
			t:wedge({ name = "Punta", size = { 1.6, 1, 1.6 }, pos = { 0, height + 1.7, z * (width / 2 + 2.2) }, rot = { 0, z > 0 and 0 or 180, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		local plaque = t:box({ name = "Placa", size = { 0.4, 2.2, 1.8 }, pos = { 0, height * 0.86, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		MB.sign(plaque, "神社", { face = "Left", color = { 240, 200, 90 } })
		MB.sign(plaque, "神社", { face = "Right", color = { 240, 200, 90 } })
	end

	function P.lantern(g, pos, color, withLight)
		local l = g:at(pos, 0)
		local c = color or { 230, 60, 40 }
		local body = l:ball({ name = "Farolillo", diameter = 1.6, pos = { 0, 0, 0 }, color = c, mat = "Neon", transparency = 0.15, folder = "Decoracion" })
		l:cylinder({ name = "Tapa", length = 0.25, diameter = 0.9, pos = { 0, 0.8, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		l:cylinder({ name = "Tapa", length = 0.25, diameter = 0.9, pos = { 0, -0.8, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		if withLight then
			MB.light(body, "Point", { color = c, brightness = 1.2, range = 14 })
		end
	end

	-- Farolillo de piedra japonés (tōrō)
	function P.stoneLantern(g, pos)
		local t = g:at(pos, 0)
		local stone = { 150, 148, 140 }
		t:box({ name = "Base", size = { 2.4, 0.8, 2.4 }, pos = { 0, 0.4, 0 }, color = stone, mat = "Slate" })
		t:cylinder({ name = "Fuste", length = 2.6, diameter = 0.9, pos = { 0, 2.1, 0 }, color = stone, mat = "Slate" })
		t:box({ name = "Plataforma", size = { 2.2, 0.5, 2.2 }, pos = { 0, 3.6, 0 }, color = stone, mat = "Slate" })
		local light = t:box({ name = "Fuego", size = { 1.4, 1.3, 1.4 }, pos = { 0, 4.5, 0 }, color = { 255, 200, 120 }, mat = "Neon", folder = "Decoracion" })
		t:box({ name = "Techo", size = { 2.8, 0.6, 2.8 }, pos = { 0, 5.45, 0 }, color = stone, mat = "Slate" })
		t:ball({ name = "Remate", diameter = 0.8, pos = { 0, 6, 0 }, color = stone, mat = "Slate", folder = "Decoracion" })
		MB.light(light, "Point", { color = { 255, 196, 120 }, brightness = 1, range = 12 })
	end

	-- Guirnalda de banderines (papel picado)
	function P.bunting(g, a, b, count, sag, colors)
		local prev = nil
		for i = 0, count do
			local t = i / count
			local point = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t - sag * 4 * t * (1 - t), a[3] + (b[3] - a[3]) * t }
			if prev then
				P.segment(g, prev, point, 0.08, { 40, 40, 40 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				local yaw = math.deg(math.atan2(-(b[3] - a[3]), b[1] - a[1]))
				g:box({ name = "Banderin", size = { 1.1, 1.3, 0.05 }, pos = { point[1], point[2] - 0.7, point[3] }, rot = { 0, yaw, 0 }, color = colors[(i % #colors) + 1], mat = "Fabric", folder = "Decoracion", shadow = false })
			end
			prev = point
		end
	end

	function P.fountain(g, pos, radius, waterColor)
		local f = g:at(pos, 0)
		local stone = { 206, 200, 186 }
		local water = waterColor or { 90, 160, 200 }
		f:cylinder({ name = "Pileta", length = 2.4, diameter = radius * 2, pos = { 0, 1.2, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Agua", length = 0.2, diameter = radius * 2 - 1.2, pos = { 0, 2.35, 0 }, color = water, mat = "Glass", transparency = 0.3, reflectance = 0.2, folder = "Decoracion" })
		f:cylinder({ name = "Columna", length = 5, diameter = 1.6, pos = { 0, 4.5, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Taza", length = 0.8, diameter = radius, pos = { 0, 6.8, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Agua", length = 0.15, diameter = radius - 0.6, pos = { 0, 7.25, 0 }, color = water, mat = "Glass", transparency = 0.3, folder = "Decoracion" })
		f:ball({ name = "Remate", diameter = 1.2, pos = { 0, 7.9, 0 }, color = stone, mat = "Limestone", folder = "Decoracion" })
	end

	-- Quiosco abierto con columnas y tejado cónico
	function P.kiosk(g, pos, radius, color, roofColor)
		local k = g:at(pos, 0)
		k:cylinder({ name = "Plataforma", length = 1.4, diameter = radius * 2, pos = { 0, 0.7, 0 }, color = { 210, 204, 192 }, mat = "Limestone" })
		for i = 0, 7 do
			local a = math.rad(i * 45 + 22.5)
			k:cylinder({ name = "Columna", length = 8, diameter = 0.7, pos = { math.cos(a) * (radius - 1), 5.4, math.sin(a) * (radius - 1) }, color = color, mat = "Metal" })
		end
		for i, d in ipairs({ radius * 2 + 1.5, radius * 1.6, radius * 1.1, radius * 0.6 }) do
			k:cylinder({ name = "Tejado", length = 1, diameter = d, pos = { 0, 9.4 + i * 0.95, 0 }, color = (i % 2 == 1) and roofColor or { 245, 245, 240 }, mat = "Metal" })
		end
		k:ball({ name = "Remate", diameter = 1.2, pos = { 0, 14.6, 0 }, color = { 220, 180, 60 }, mat = "Metal", folder = "Decoracion" })
		-- Barandilla entre columnas, con entradas en los lados +X y -X
		for i = 0, 7 do
			if i ~= 3 and i ~= 7 then
				local a1, a2 = math.rad(i * 45 + 22.5), math.rad(i * 45 + 67.5)
				local r = radius - 1
				for _, y in ipairs({ 2.2, 3.6 }) do
					P.segment(k, { math.cos(a1) * r, y, math.sin(a1) * r }, { math.cos(a2) * r, y, math.sin(a2) * r }, 0.3, color, "Metal")
				end
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			k:box({ name = "Escalon", size = { 2, 0.7, 5 }, pos = { side * (radius + 0.9), 0.35, 0 }, color = { 190, 184, 172 }, mat = "Limestone" })
		end
	end

	-- Puesto de mercado con toldo de tela (frente hacia -Z local)
	function P.marketStall(g, pos, rotY, color, text, goods)
		local m = g:at(pos, rotY)
		local wood = { 150, 108, 70 }
		m:box({ name = "Mostrador", size = { 8, 3.4, 3 }, pos = { 0, 1.7, 0 }, color = wood, mat = "WoodPlanks" })
		for _, x in ipairs({ -3.8, 3.8 }) do
			for _, z in ipairs({ -1.4, 1.4 }) do
				m:box({ name = "Poste", size = { 0.4, 7.4, 0.4 }, pos = { x, 3.7, z }, color = darker(wood, 30), mat = "Wood" })
			end
		end
		for i = 0, 3 do
			m:box({ name = "Toldo", size = { 2.1, 0.25, 4.4 }, pos = { -3.15 + i * 2.1, 7.6, -0.3 }, rot = { 12, 0, 0 }, color = (i % 2 == 0) and color or { 245, 240, 230 }, mat = "Fabric" })
		end
		local palette = goods or { { 230, 60, 50 }, { 250, 190, 60 }, { 110, 180, 80 }, { 240, 130, 40 } }
		for i = 0, 5 do
			m:ball({ name = "Producto", diameter = 0.9, pos = { -3 + i * 1.2, 3.75, -0.6 }, color = palette[(i % #palette) + 1], folder = "Decoracion" })
		end
		if text then
			local sign = m:box({ name = "Rotulo", size = { 6, 1.2, 0.2 }, pos = { 0, 6.6, -1.6 }, color = color, folder = "Decoracion" })
			MB.sign(sign, text, { font = "LuckiestGuy", color = { 255, 255, 255 }, bg = color })
		end
	end

	function P.trafficLight(g, pos, rotY)
		local t = g:at(pos, rotY)
		t:cylinder({ name = "Poste", length = 12, diameter = 0.6, pos = { 0, 6, 0 }, color = { 40, 42, 46 }, mat = "Metal" })
		t:box({ name = "Brazo", size = { 0.4, 0.4, 6 }, pos = { 0, 11.6, -3 }, color = { 40, 42, 46 }, mat = "Metal", folder = "Decoracion" })
		t:box({ name = "Semaforo", size = { 1.4, 3.8, 1.2 }, pos = { 0, 10.2, -5.6 }, color = { 30, 30, 34 }, mat = "Metal", folder = "Decoracion" })
		local colors = { { 230, 40, 40 }, { 245, 190, 40 }, { 60, 220, 90 } }
		for i, c in ipairs(colors) do
			t:cylinder({ name = "Luz", axis = "z", length = 0.15, diameter = 0.8, pos = { 0, 11.4 - i * 1.15, -6.25 }, color = c, mat = (i == 3) and "Neon" or "SmoothPlastic", folder = "Decoracion" })
		end
	end

	-- Columna clásica (rota = más baja y sin capitel)
	function P.column(g, pos, height, diameter, color, mat, broken)
		local c = g:at(pos, 0)
		local m = mat or "Sandstone"
		c:box({ name = "Basa", size = { diameter + 1, 1, diameter + 1 }, pos = { 0, 0.5, 0 }, color = color, mat = m })
		c:cylinder({ name = "Fuste", length = height, diameter = diameter, pos = { 0, 1 + height / 2, 0 }, color = color, mat = m })
		if not broken then
			c:box({ name = "Capitel", size = { diameter + 1.2, 1.2, diameter + 1.2 }, pos = { 0, 1.6 + height, 0 }, color = color, mat = m })
		end
	end

	function P.obelisk(g, pos, height, width, color)
		local o = g:at(pos, 0)
		local c = color or { 214, 186, 132 }
		o:box({ name = "Pedestal", size = { width + 3, 2, width + 3 }, pos = { 0, 1, 0 }, color = darker(c, 20), mat = "Sandstone" })
		local segments = 4
		for i = 1, segments do
			local w = width * (1 - (i - 1) * 0.08)
			o:box({ name = "Obelisco", size = { w, height / segments, w }, pos = { 0, 2 + (i - 0.5) * height / segments, 0 }, color = c, mat = "Sandstone" })
		end
		for _, r in ipairs({ 0, 90, 180, 270 }) do
			o:wedge({ name = "Piramidion", size = { width * 0.68, 2.4, width * 0.34 }, pos = { 0, 3.2 + height, 0 }, rot = { 0, r, 0 }, color = { 230, 196, 90 }, mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Pirámide escalonada (decoración de fondo)
	function P.pyramid(g, pos, base, height, steps, color)
		local p = g:at(pos, 0)
		for i = 1, steps do
			local size = base * (1 - (i - 1) / steps)
			local h = height / steps
			p:box({ name = "Piramide", size = { size, h, size }, pos = { 0, (i - 0.5) * h, 0 }, color = color, mat = "Sandstone", folder = "Decoracion" })
		end
	end

	function P.onionDome(g, pos, diameter, color)
		local o = g:at(pos, 0)
		o:cylinder({ name = "Tambor", length = diameter * 0.6, diameter = diameter * 0.8, pos = { 0, diameter * 0.3, 0 }, color = { 240, 236, 228 }, mat = "Plaster" })
		o:ball({ name = "Cupula", diameter = diameter, pos = { 0, diameter * 0.95, 0 }, color = color, mat = "Metal", reflectance = 0.15 })
		o:ball({ name = "Punta", diameter = diameter * 0.45, pos = { 0, diameter * 1.5, 0 }, color = color, mat = "Metal" })
		o:cylinder({ name = "Aguja", length = diameter * 0.7, diameter = 0.3, pos = { 0, diameter * 1.95, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
		o:box({ name = "Cruz", size = { 0.25, 1.6, 0.25 }, pos = { 0, diameter * 2.4, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
		o:box({ name = "Cruz", size = { 1, 0.25, 0.25 }, pos = { 0, diameter * 2.5, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Campanario (frente hacia -Z local)
	function P.bellTower(g, pos, rotY, height, color, roofColor)
		local t = g:at(pos, rotY)
		t:box({ name = "Torre", size = { 7, height, 7 }, pos = { 0, height / 2, 0 }, color = color, mat = "Plaster" })
		t:box({ name = "Cornisa", size = { 7.8, 0.8, 7.8 }, pos = { 0, height - 4.6, 0 }, color = darker(color, 40), mat = "Concrete" })
		for _, r in ipairs({ 0, 90, 180, 270 }) do
			local face = t:at({ 0, 0, 0 }, r)
			face:box({ name = "Arco", size = { 2.6, 3.4, 0.4 }, pos = { 0, height - 2.4, -3.45 }, color = { 30, 26, 24 }, folder = "Decoracion" })
		end
		t:ball({ name = "Campana", diameter = 1.6, pos = { 0, height - 2.4, -2.6 }, color = { 190, 150, 60 }, mat = "Metal", folder = "Decoracion" })
		for i, w in ipairs({ 7.6, 5.4, 3.2, 1.2 }) do
			t:box({ name = "Chapitel", size = { w, 1.2, w }, pos = { 0, height + (i - 0.5) * 1.2, 0 }, color = roofColor or { 176, 82, 56 }, mat = "ClayRoofTiles" })
		end
		t:box({ name = "Cruz", size = { 0.3, 2.2, 0.3 }, pos = { 0, height + 5.9, 0 }, color = { 60, 56, 52 }, mat = "Metal", folder = "Decoracion" })
		t:box({ name = "Cruz", size = { 1.3, 0.3, 0.3 }, pos = { 0, height + 6.3, 0 }, color = { 60, 56, 52 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Nieve que cae: emisor de partículas en una pieza invisible (size = { X, Z })
	function P.snowfall(g, pos, size, rate)
		local part = g:box({ name = "Nevada", size = { size[1], 1, size[2] }, pos = pos, transparency = 1, folder = "Decoracion", shadow = false })
		part.CanQuery = false
		part.CanTouch = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Nieve"
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Rate = rate or 120
		emitter.Lifetime = NumberRange.new(9, 12)
		emitter.Speed = NumberRange.new(5, 7)
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-40, 40)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		emitter.LightEmission = 0.2
		emitter.Parent = part
		return emitter
	end

	function P.snowman(g, pos)
		local s = g:at(pos, 0)
		for _, b in ipairs({ { 0, 2, 4 }, { 0, 5.1, 3 }, { 0, 7.4, 2.1 } }) do
			s:ball({ name = "Nieve", diameter = b[3], pos = { 0, b[2], 0 }, color = { 246, 248, 252 }, mat = "Snow" })
		end
		s:cylinder({ name = "Nariz", axis = "z", length = 1, diameter = 0.3, pos = { 0, 7.4, -1.3 }, color = { 240, 130, 40 }, folder = "Decoracion" })
		s:cylinder({ name = "Sombrero", length = 1.6, diameter = 1.4, pos = { 0, 9.1, 0 }, color = { 30, 30, 34 }, mat = "Fabric", folder = "Decoracion" })
		s:cylinder({ name = "Ala", length = 0.2, diameter = 2.2, pos = { 0, 8.35, 0 }, color = { 30, 30, 34 }, mat = "Fabric", folder = "Decoracion" })
		s:cylinder({ name = "Bufanda", length = 0.6, diameter = 2.3, pos = { 0, 6.4, 0 }, color = { 200, 40, 40 }, mat = "Fabric", folder = "Decoracion" })
	end

	function P.logPile(g, pos, rotY, length)
		local l = g:at(pos, rotY)
		local rows = { { 4, 0.9 }, { 3, 2.5 }, { 2, 4.1 }, { 1, 5.7 } }
		for _, r in ipairs(rows) do
			for i = 1, r[1] do
				local z = (i - (r[1] + 1) / 2) * 1.8
				l:cylinder({ name = "Tronco", axis = "x", length = length, diameter = 1.8, pos = { 0, r[2], z }, color = { 140, 100, 66 }, mat = "Wood" })
			end
		end
	end

	function P.taxi(g, pos, rotY)
		P.car(g, pos, rotY, { 250, 200, 30 })
		local t = g:at(pos, rotY)
		local sign = t:box({ name = "Taxi", size = { 1.8, 0.7, 0.8 }, pos = { 0, 5.6, 1.3 }, color = { 250, 250, 240 }, mat = "Neon", folder = "Decoracion" })
		MB.sign(sign, "TAXI", { face = "Front", font = "GothamBlack", color = { 30, 30, 30 } })
		t:box({ name = "Franja", size = { 5.45, 0.4, 6 }, pos = { 0, 2.3, 0.6 }, color = { 30, 30, 30 }, folder = "Decoracion" })
	end

	function P.hotdogCart(g, pos, rotY)
		local c = g:at(pos, rotY)
		c:box({ name = "Carrito", size = { 6, 3, 3 }, pos = { 0, 2.4, 0 }, color = { 220, 220, 216 }, mat = "Metal" })
		for _, x in ipairs({ -2, 2 }) do
			c:cylinder({ name = "Rueda", axis = "z", length = 0.4, diameter = 1.8, pos = { x, 0.9, -1.6 }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
		end
		local sign = c:box({ name = "Rotulo", size = { 5, 1, 0.1 }, pos = { 0, 3, -1.56 }, color = { 200, 40, 40 }, folder = "Decoracion" })
		MB.sign(sign, "HOT DOGS", { bg = { 200, 40, 40 }, font = "GothamBlack", color = { 255, 230, 120 } })
		c:cylinder({ name = "Palo", length = 4, diameter = 0.2, pos = { 0, 5.9, 0 }, color = { 180, 180, 186 }, folder = "Decoracion" })
		for i, d in ipairs({ 6.5, 4.4, 2.2 }) do
			c:cylinder({ name = "Sombrilla", length = 0.35, diameter = d, pos = { 0, 7.6 + i * 0.3, 0 }, color = (i % 2 == 1) and { 40, 120, 200 } or { 250, 200, 40 }, mat = "Fabric", folder = "Decoracion" })
		end
	end

	-- Boca de metro con barandilla y farolas verdes
	function P.subwayEntrance(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Hueco", size = { 6, 0.2, 10 }, pos = { 0, 0.05, 0 }, color = { 20, 20, 24 }, folder = "Decoracion" })
		for i = 1, 5 do
			s:box({ name = "Escalon", size = { 5.6, 0.1, 1.6 }, pos = { 0, 0.2, -4 + i * 1.6 }, color = { 90, 90, 96 }, mat = "Concrete", folder = "Decoracion" })
		end
		for _, x in ipairs({ -3, 3 }) do
			P.railing(s, { x, 0, -5 }, { x, 0, 5 }, 3.2, { 40, 80, 50 })
			s:cylinder({ name = "Farola", length = 4.4, diameter = 0.35, pos = { x, 2.2, -5 }, color = { 40, 80, 50 }, mat = "Metal" })
			local globe = s:ball({ name = "Globo", diameter = 1.1, pos = { x, 4.8, -5 }, color = { 120, 240, 140 }, mat = "Neon", folder = "Decoracion" })
			if x < 0 then
				MB.light(globe, "Point", { color = { 140, 255, 160 }, brightness = 1, range = 10 })
			end
		end
		P.railing(s, { -3, 0, 5 }, { 3, 0, 5 }, 3.2, { 40, 80, 50 })
		local sign = s:box({ name = "Cartel", size = { 5.4, 1, 0.2 }, pos = { 0, 3.8, 5 }, color = { 30, 30, 34 }, folder = "Decoracion" })
		MB.sign(sign, "SUBWAY", { face = "Front", font = "GothamBlack", color = { 255, 255, 255 } })
	end
	-- =================================================================
	--  Edificios en los que se puede entrar
	-- =================================================================
	-- Pared a lo largo de X local (de x0 a x1, centrada en z) con huecos { xa, xb, ya, yb } (y relativa a y0)
	function P.wallWithHoles(g, x0, x1, z, y0, h, t, holes, color, mat)
		local sorted = {}
		for i, hole in ipairs(holes) do
			sorted[i] = hole
		end
		table.sort(sorted, function(a, c)
			return a[1] < c[1]
		end)
		local function piece(xa, xb, ya, yb)
			if xb - xa > 0.01 and yb - ya > 0.01 then
				g:box({ name = "Pared", size = { xb - xa, yb - ya, t }, pos = { (xa + xb) / 2, y0 + (ya + yb) / 2, z }, color = color, mat = mat or "Plaster" })
			end
		end
		local cursor = x0
		for _, hole in ipairs(sorted) do
			piece(cursor, hole[1], 0, h)
			piece(hole[1], hole[2], 0, hole[3])
			piece(hole[1], hole[2], hole[4], h)
			cursor = hole[2]
		end
		piece(cursor, x1, 0, h)
	end

	-- Igual, pero a lo largo de Z local (de z0 a z1, centrada en x); los huecos usan coordenadas Z
	function P.wallWithHolesZ(g, z0, z1, x, y0, h, t, holes, color, mat)
		P.wallWithHoles(g:at({ x, 0, 0 }, -90), z0, z1, 0, y0, h, t, holes, color, mat)
	end

	-- Casa de dos plantas con escalera interior, puertas y ventanas abiertas y balcón (fachada hacia -Z local).
	-- o: w, d, color, trim, roofColor, floor, wallMat, furniture
	function P.openHouse(g, pos, rotY, o)
		local h = g:at(pos, rotY)
		local W, D, FH, T = o.w or 26, o.d or 20, 9, 1
		local wall = o.color or { 200, 200, 200 }
		local trim = o.trim or { 245, 245, 240 }
		local mat = o.wallMat or "Plaster"
		local floorColor = o.floor or { 150, 110, 76 }
		local front, back = -D / 2 + T / 2, D / 2 - T / 2
		local function win(x, y)
			return { x - 2, x + 2, (y or 0) + 3, (y or 0) + 6.5 }
		end
		h:box({ name = "Suelo", size = { W, 0.6, D }, pos = { 0, 0.3, 0 }, color = floorColor, mat = "WoodPlanks" })
		-- Planta baja: puerta delantera, puerta trasera y ventanas
		P.wallWithHoles(h, -W / 2, W / 2, front, 0, FH, T, { { -2, 2, 0, 7 }, win(-7), win(7) }, wall, mat)
		P.wallWithHoles(h, -W / 2, W / 2, back, 0, FH, T, { win(-7), { 6, 10, 0, 7 } }, wall, mat)
		for _, x in ipairs({ -W / 2 + T / 2, W / 2 - T / 2 }) do
			P.wallWithHolesZ(h, -D / 2 + T, D / 2 - T, x, 0, FH, T, { { -3, 3, 3, 6.5 } }, wall, mat)
		end
		-- Escalera junto a la pared derecha (sube hacia +Z) y hueco en el suelo de arriba
		local sx = W / 2 - T - 2.2
		local z0 = -D / 2 + T + 1
		P.stairs(h, { sx, 0.6, z0 }, 0, 9, 1, 1.3, 4, floorColor)
		local hx = W / 2 - T - 4.4
		local hz = z0 + 9 * 1.3
		h:box({ name = "Piso", size = { hx + W / 2, 0.6, D }, pos = { (hx - W / 2) / 2, FH + 0.3, 0 }, color = floorColor, mat = "WoodPlanks" })
		h:box({ name = "Piso", size = { W / 2 - hx, 0.6, D / 2 - hz }, pos = { (hx + W / 2) / 2, FH + 0.3, (hz + D / 2) / 2 }, color = floorColor, mat = "WoodPlanks" })
		P.railing(h, { hx, FH + 0.6, -D / 2 + T }, { hx, FH + 0.6, hz }, 3, trim)
		-- Planta alta: puerta al balcón y ventanas
		P.wallWithHoles(h, -W / 2, W / 2, front, FH + 0.6, FH - 0.6, T, { { -2, 2, 0, 7 }, win(-7), win(7) }, wall, mat)
		P.wallWithHoles(h, -W / 2, W / 2, back, FH + 0.6, FH - 0.6, T, { win(-7), win(7) }, wall, mat)
		for _, x in ipairs({ -W / 2 + T / 2, W / 2 - T / 2 }) do
			P.wallWithHolesZ(h, -D / 2 + T, D / 2 - T, x, FH + 0.6, FH - 0.6, T, { { -3, 3, 3, 6.5 } }, wall, mat)
		end
		-- Techo a dos aguas
		local top = 2 * FH
		h:box({ name = "Techo", size = { W, 0.6, D }, pos = { 0, top + 0.3, 0 }, color = trim, mat = "Concrete" })
		local rc = o.roofColor or { 120, 70, 60 }
		h:wedge({ name = "Tejado", size = { W + 1.6, 4, D / 2 + 1 }, pos = { 0, top + 2.6, -D / 4 - 0.5 }, color = rc, mat = "RoofShingles" })
		if o.ruined then
			-- Media cubierta hundida: escombros en el piso de arriba
			h:wedge({ name = "Tejado", size = { W / 2 + 0.8, 4, D / 2 + 1 }, pos = { -W / 4 - 0.4, top + 2.6, D / 4 + 0.5 }, rot = { 0, 180, 0 }, color = rc, mat = "RoofShingles" })
			P.debris(h, { W / 4, FH + 0.6, D / 4 }, 1.2)
			P.overgrowth(h, W, top, -D / 2 - 0.2)
			P.overgrowth(h:at({ 0, 0, 0 }, 180), W, top, -D / 2 - 0.2)
		else
			h:wedge({ name = "Tejado", size = { W + 1.6, 4, D / 2 + 1 }, pos = { 0, top + 2.6, D / 4 + 0.5 }, rot = { 0, 180, 0 }, color = rc, mat = "RoofShingles" })
		end
		-- Molduras
		for _, z in ipairs({ -D / 2 - 0.1, D / 2 + 0.1 }) do
			h:box({ name = "Moldura", size = { W + 0.4, 0.6, 0.3 }, pos = { 0, FH + 0.3, z }, color = trim, folder = "Decoracion" })
		end
		for _, x in ipairs({ -W / 2, W / 2 }) do
			for _, z in ipairs({ -D / 2, D / 2 }) do
				h:box({ name = "Esquina", size = { 0.8, top, 0.8 }, pos = { x, top / 2, z }, color = trim, folder = "Decoracion" })
			end
		end
		-- Porche con balcón encima
		h:box({ name = "Balcon", size = { 12, 0.6, 4 }, pos = { 0, FH + 0.3, -D / 2 - 2 }, color = floorColor, mat = "WoodPlanks" })
		P.railing(h, { -6, FH + 0.6, -D / 2 - 3.8 }, { 6, FH + 0.6, -D / 2 - 3.8 }, 3, trim)
		for _, x in ipairs({ -5.6, 5.6 }) do
			h:box({ name = "Columna", size = { 0.8, FH, 0.8 }, pos = { x, FH / 2, -D / 2 - 3.6 }, color = trim })
		end
		h:box({ name = "Escalon", size = { 6, 0.6, 2 }, pos = { 0, 0.3, -D / 2 - 1 }, color = { 180, 176, 170 }, mat = "Concrete" })
		if o.furniture ~= false then
			-- Sofá, mesa, cocina y nevera abajo; cama y cómoda arriba
			h:box({ name = "Sofa", size = { 7, 2.2, 2.6 }, pos = { -6, 1.7, -3 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric" })
			h:box({ name = "Respaldo", size = { 7, 2, 0.8 }, pos = { -6, 2.6, -1.9 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric" })
			h:box({ name = "Mesa", size = { 4, 0.4, 3 }, pos = { -6, 2.6, 3 }, color = { 120, 80, 50 }, mat = "WoodPlanks" })
			h:box({ name = "Patas", size = { 3.4, 2, 2.4 }, pos = { -6, 1.6, 3 }, color = { 100, 66, 42 }, mat = "WoodPlanks", transparency = 0.6, folder = "Decoracion" })
			h:box({ name = "Cocina", size = { 8, 3.2, 2.4 }, pos = { 0, 2.2, D / 2 - T - 1.2 }, color = { 236, 236, 230 }, mat = "Marble" })
			h:box({ name = "Nevera", size = { 2.6, 6, 2.4 }, pos = { -5.4, 3.6, D / 2 - T - 1.2 }, color = { 230, 230, 226 }, mat = "Metal" })
			h:box({ name = "Cama", size = { 5, 1.6, 7 }, pos = { -7, FH + 1.4, 4 }, color = { 236, 230, 220 }, mat = "Fabric" })
			h:box({ name = "Manta", size = { 5.1, 0.3, 4.4 }, pos = { -7, FH + 2.3, 5 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric", folder = "Decoracion" })
			h:box({ name = "Comoda", size = { 5, 3.6, 2 }, pos = { 0, FH + 2.4, D / 2 - T - 1 }, color = { 140, 96, 60 }, mat = "WoodPlanks" })
		end
		local lamp = h:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -4, FH - 0.2, 0 }, color = { 255, 240, 214 }, mat = "Neon", folder = "Decoracion" })
		MB.light(lamp, "Point", { color = { 255, 230, 200 }, brightness = 0.8, range = 16 })
	end

	-- =================================================================
	--  Más vehículos, gente y feria
	-- =================================================================
	function P.bus(g, pos, rotY, color, text)
		local u = g:at(pos, rotY)
		local paint = color or { 246, 190, 30 }
		local body = u:box({ name = "Autobus", size = { 8, 7, 30 }, pos = { 0, 5, 1 }, color = paint })
		u:box({ name = "Capo", size = { 7.4, 3.4, 5 }, pos = { 0, 3.2, -16.4 }, color = paint })
		u:box({ name = "Techo", size = { 7.6, 0.6, 29.6 }, pos = { 0, 8.8, 1 }, color = { 240, 240, 236 }, folder = "Decoracion" })
		u:box({ name = "Franja", size = { 8.06, 0.5, 30 }, pos = { 0, 4.2, 1 }, color = { 30, 30, 30 }, folder = "Decoracion" })
		for i = 0, 6 do
			for _, side in ipairs({ -1, 1 }) do
				u:box({ name = "Ventana", size = { 0.2, 2.4, 3 }, pos = { side * 4.02, 6.6, -10 + i * 3.8 }, color = { 50, 60, 76 }, mat = "Glass", folder = "Decoracion" })
			end
		end
		u:box({ name = "Parabrisas", size = { 7, 3, 0.2 }, pos = { 0, 6.4, -14.05 }, color = { 50, 60, 76 }, mat = "Glass", folder = "Decoracion" })
		u:box({ name = "Paragolpes", size = { 8.2, 1, 0.6 }, pos = { 0, 1.8, -19.1 }, color = { 40, 40, 44 }, mat = "Metal" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			u:box({ name = "Faro", size = { 1.2, 0.8, 0.15 }, pos = { x, 3.4, -18.95 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for _, w in ipairs({ { -3.6, -13 }, { 3.6, -13 }, { -3.6, 10 }, { 3.6, 10 } }) do
			u:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3, pos = { w[1], 1.5, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
		end
		if text then
			for _, face in ipairs({ "Left", "Right" }) do
				MB.sign(body, text, { face = face, font = "GothamBlack", color = { 30, 30, 30 }, height = 0.22, width = 0.6 })
			end
		end
		return body
	end

	-- Maniquí de pie (clothes = color de la ropa)
	function P.mannequin(g, pos, rotY, clothes)
		local m = g:at(pos, rotY)
		local skin = { 236, 214, 190 }
		local c = clothes or { 60, 110, 180 }
		for _, x in ipairs({ -0.5, 0.5 }) do
			m:box({ name = "Pierna", size = { 0.8, 3, 0.8 }, pos = { x, 1.5, 0 }, color = (c[1] + c[2] + c[3] > 400) and { 60, 60, 70 } or c, folder = "Decoracion" })
			m:box({ name = "Brazo", size = { 0.6, 2.8, 0.6 }, pos = { x * 3.2, 4.4, 0 }, rot = { 0, 0, x * 16 }, color = skin, folder = "Decoracion" })
		end
		m:box({ name = "Torso", size = { 2.2, 2.8, 1.1 }, pos = { 0, 4.4, 0 }, color = c, mat = "Fabric" })
		m:cylinder({ name = "Cuello", length = 0.5, diameter = 0.5, pos = { 0, 6, 0 }, color = skin, folder = "Decoracion" })
		m:ball({ name = "Cabeza", diameter = 1.3, pos = { 0, 6.6, 0 }, color = skin, folder = "Decoracion" })
	end

	-- Noria (la rueda está en el plano XY local)
	function P.ferrisWheel(g, pos, rotY, radius, rimColor)
		local f = g:at(pos, rotY)
		local r = radius or 24
		local hub = r + 4
		local steel = { 236, 236, 240 }
		local neon = rimColor or { 255, 80, 160 }
		local cabins = { { 230, 60, 60 }, { 250, 200, 60 }, { 60, 140, 230 }, { 80, 190, 110 } }
		f:box({ name = "Base", size = { r * 1.3, 1.5, 9 }, pos = { 0, 0.75, 0 }, color = { 120, 120, 128 }, mat = "Concrete" })
		for _, z in ipairs({ -3, 3 }) do
			P.segment(f, { -r * 0.55, 1.5, z }, { 0, hub, z }, 1, steel, "Metal")
			P.segment(f, { r * 0.55, 1.5, z }, { 0, hub, z }, 1, steel, "Metal")
		end
		local hubPart = f:cylinder({ name = "Eje", axis = "z", length = 7, diameter = 2.4, pos = { 0, hub, 0 }, color = { 80, 80, 90 }, mat = "Metal" })
		MB.light(hubPart, "Point", { color = neon, brightness = 1.5, range = 30 })
		local n = 24
		for i = 0, n - 1 do
			local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
			for _, z in ipairs({ -2, 2 }) do
				P.segment(f, { math.cos(a1) * r, hub + math.sin(a1) * r, z }, { math.cos(a2) * r, hub + math.sin(a2) * r, z }, 0.6, neon, "Neon", "Decoracion")
			end
			if i % 2 == 0 then
				local cx, cy = math.cos(a1) * r, hub + math.sin(a1) * r
				P.segment(f, { 0, hub, 0 }, { cx, cy, 0 }, 0.4, steel, "Metal", "Decoracion")
				f:box({ name = "Cabina", size = { 2.6, 2.8, 3.4 }, pos = { cx, cy - 2.4, 0 }, color = cabins[(i / 2 % 4) + 1], folder = "Decoracion" })
				f:box({ name = "Techo", size = { 3, 0.4, 3.8 }, pos = { cx, cy - 0.8, 0 }, color = steel, folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Oeste y zona militar
	-- =================================================================
	function P.hayBale(g, pos, rotY)
		local h = g:at(pos, rotY)
		h:box({ name = "Paja", size = { 4, 2.6, 2.6 }, pos = { 0, 1.3, 0 }, color = { 222, 190, 104 }, mat = "Grass" })
		for _, x in ipairs({ -1, 1 }) do
			h:box({ name = "Cuerda", size = { 0.2, 2.7, 2.7 }, pos = { x, 1.3, 0 }, color = { 150, 110, 60 }, folder = "Decoracion" })
		end
	end

	-- Carreta con lona (larga a lo largo de Z local)
	function P.wagon(g, pos, rotY, canvas)
		local w = g:at(pos, rotY)
		local wood = { 130, 88, 56 }
		w:box({ name = "Caja", size = { 5.6, 2.4, 11 }, pos = { 0, 2.6, 0 }, color = wood, mat = "WoodPlanks" })
		w:cylinder({ name = "Lona", axis = "z", length = 10, diameter = 5.4, pos = { 0, 4.2, 0 }, color = canvas or { 240, 232, 214 }, mat = "Fabric" })
		for _, z in ipairs({ -3.5, 0, 3.5 }) do
			w:cylinder({ name = "Aro", axis = "z", length = 0.3, diameter = 5.6, pos = { 0, 4.2, z }, color = { 110, 80, 52 }, folder = "Decoracion" })
		end
		for _, x in ipairs({ -3, 3 }) do
			for _, z in ipairs({ -3.6, 3.6 }) do
				w:cylinder({ name = "Rueda", axis = "x", length = 0.5, diameter = 4.2, pos = { x, 2.1, z }, color = { 90, 62, 40 }, mat = "Wood" })
				w:cylinder({ name = "Buje", axis = "x", length = 0.6, diameter = 1, pos = { x, 2.1, z }, color = { 60, 50, 44 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		w:box({ name = "Lanza", size = { 0.5, 0.5, 6 }, pos = { 0, 1.6, -8.4 }, rot = { -8, 0, 0 }, color = wood, mat = "Wood", folder = "Decoracion" })
	end

	-- Muro de sacos terreros (largo a lo largo de X local)
	function P.sandbags(g, pos, rotY, length, rows)
		local s = g:at(pos, rotY)
		local n = math.max(1, math.floor(length / 2.4))
		for r = 0, (rows or 3) - 1 do
			local offset = (r % 2 == 0) and 0 or 1.2
			for i = 0, n - 1 - (r % 2) do
				local x = -length / 2 + 1.2 + i * 2.4 + offset
				s:box({ name = "Saco", size = { 2.3, 1, 1.5 }, pos = { x, 0.5 + r, 0 }, color = (i + r) % 3 == 0 and { 160, 140, 100 } or { 176, 156, 114 }, mat = "Fabric" })
			end
		end
	end

	-- Torre de vigilancia con escalera trepable y plataforma con barandilla
	function P.watchTower(g, pos, rotY, height)
		local t = g:at(pos, rotY)
		local h = height or 16
		local wood = { 120, 92, 64 }
		for _, x in ipairs({ -3, 3 }) do
			for _, z in ipairs({ -3, 3 }) do
				t:box({ name = "Pata", size = { 1, h, 1 }, pos = { x, h / 2, z }, color = wood, mat = "Wood" })
			end
		end
		t:box({ name = "Plataforma", size = { 8, 0.8, 8 }, pos = { 0, h + 0.4, 0 }, color = wood, mat = "WoodPlanks" })
		for _, side in ipairs({ -1, 1 }) do
			t:box({ name = "Peto", size = { 0.5, 3.4, 8 }, pos = { side * 3.75, h + 2.5, 0 }, color = wood, mat = "WoodPlanks" })
			-- Lado de la escalera con hueco para entrar
			t:box({ name = "Peto", size = { 2.6, 3.4, 0.5 }, pos = { side * 2.7, h + 2.5, 3.75 }, color = wood, mat = "WoodPlanks" })
		end
		t:box({ name = "Peto", size = { 8, 3.4, 0.5 }, pos = { 0, h + 2.5, -3.75 }, color = wood, mat = "WoodPlanks" })
		t:box({ name = "Techo", size = { 9, 0.6, 9 }, pos = { 0, h + 7.5, 0 }, color = { 90, 70, 50 }, mat = "WoodPlanks", folder = "Decoracion" })
		for _, x in ipairs({ -3.6, 3.6 }) do
			for _, z in ipairs({ -3.6, 3.6 }) do
				t:box({ name = "Poste", size = { 0.4, 3.6, 0.4 }, pos = { x, h + 5.6, z }, color = wood, mat = "Wood", folder = "Decoracion" })
			end
		end
		local ladderH = math.floor((h + 2) / 2) * 2
		t:truss({ name = "Escalera", size = { 2, ladderH, 2 }, pos = { 0, ladderH / 2, 5.2 }, color = { 100, 80, 60 } })
	end
	-- =================================================================
	--  Mundo abandonado (estilo apocalipsis)
	-- =================================================================
	-- Musgo y enredaderas sobre una fachada de ancho w y alto H (cara mirando a -Z local, en z)
	function P.overgrowth(g, w, H, z)
		local green = { { 70, 98, 54 }, { 84, 112, 60 }, { 62, 88, 50 } }
		for i, m in ipairs({ { -0.35, 0.12, 0.3, 0.2 }, { 0.3, 0.05, 0.25, 0.14 }, { 0.05, 0.6, 0.18, 0.22 } }) do
			g:box({ name = "Musgo", size = { w * m[3], H * m[4], 0.15 }, pos = { w * m[1], H * m[2] + H * m[4] / 2, z }, color = green[i], mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
		for i = 0, 3 do
			local x = -w / 2 + (i + 0.5) * w / 4 + ((i % 2 == 0) and 0.8 or -0.6)
			local len = H * (0.25 + (i % 3) * 0.15)
			g:box({ name = "Enredadera", size = { 0.7, len, 0.2 }, pos = { x, H - len / 2, z - 0.05 }, color = green[(i % 3) + 1], mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
	end

	-- Montón de escombros
	function P.debris(g, pos, scale)
		local d = g:at(pos, 0)
		local s = scale or 1
		local pieces = { { 0, 0, 0, 4, 1.4, 3, 12 }, { 1.8, 0.6, 1, 2.4, 1, 2, -20 }, { -1.6, 0.4, -0.8, 2.6, 1.2, 1.6, 35 }, { 0.6, 1.2, -1.2, 1.6, 0.8, 1.4, 60 }, { -0.4, 0.2, 1.8, 3, 0.6, 1, -45 } }
		for i, p in ipairs(pieces) do
			d:box({ name = "Escombro", size = { p[4] * s, p[5] * s, p[6] * s }, pos = { p[1] * s, p[2] * s + p[5] * s / 2, p[3] * s }, rot = { (i % 2) * 8, p[7], (i % 3) * 6 }, color = (i % 2 == 0) and { 150, 146, 138 } or { 130, 92, 74 }, mat = (i % 2 == 0) and "Concrete" or "Brick" })
		end
	end

	-- Muro de chapas oxidadas a lo largo de una línea (para comunidades amuralladas)
	function P.metalWall(g, a, b, height, colors)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local w = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		local palette = colors or { { 120, 84, 62 }, { 96, 100, 96 }, { 140, 104, 70 }, { 84, 92, 100 } }
		local n = math.max(1, math.floor(len / 8))
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			local hh = height - (i % 3) * 0.6
			w:box({ name = "Chapa", size = { len / n + 0.2, hh, 0.4 }, pos = { x, hh / 2, (i % 2) * 0.3 }, color = palette[(i % #palette) + 1], mat = "CorrodedMetal" })
		end
		for i = 0, n do
			local x = -len / 2 + i * len / n
			w:box({ name = "Poste", size = { 0.6, height + 0.6, 0.6 }, pos = { x, (height + 0.6) / 2, -0.4 }, color = { 70, 60, 52 }, mat = "Wood", folder = "Decoracion" })
		end
	end

	-- Empalizada de tablones con puntas
	function P.plankWall(g, a, b, height, color)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local w = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		local wood = color or { 120, 92, 64 }
		local n = math.max(1, math.floor(len / 6))
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			local hh = height + (i % 2) * 0.8
			w:box({ name = "Tablones", size = { len / n + 0.1, hh, 0.8 }, pos = { x, hh / 2, 0 }, color = (i % 3 == 0) and darker(wood, 20) or wood, mat = "WoodPlanks" })
			w:wedge({ name = "Punta", size = { len / n, 1.6, 0.4 }, pos = { x, hh + 0.8, -0.2 }, color = darker(wood, 10), mat = "WoodPlanks", folder = "Decoracion" })
			w:wedge({ name = "Punta", size = { len / n, 1.6, 0.4 }, pos = { x, hh + 0.8, 0.2 }, rot = { 0, 180, 0 }, color = darker(wood, 10), mat = "WoodPlanks", folder = "Decoracion" })
		end
	end

	-- Tienda de campaña (a lo largo de X local)
	function P.tent(g, pos, rotY, color, w, d, h)
		local t = g:at(pos, rotY)
		w, d, h = w or 10, d or 7, h or 5
		local c = color or { 92, 110, 70 }
		t:wedge({ name = "Tienda", size = { w, h, d / 2 }, pos = { 0, h / 2, -d / 4 }, color = c, mat = "Fabric" })
		t:wedge({ name = "Tienda", size = { w, h, d / 2 }, pos = { 0, h / 2, d / 4 }, rot = { 0, 180, 0 }, color = darker(c, 12), mat = "Fabric" })
	end

	-- Hoguera con luz
	function P.campfire(g, pos, withLight)
		local f = g:at(pos, 0)
		for i = 0, 5 do
			local a = math.rad(i * 60)
			f:ball({ name = "Piedra", diameter = 1.1, pos = { math.cos(a) * 1.6, 0.4, math.sin(a) * 1.6 }, color = { 110, 108, 104 }, mat = "Slate", folder = "Decoracion" })
		end
		for _, r in ipairs({ 0, 60, 120 }) do
			f:box({ name = "Lena", size = { 2.6, 0.5, 0.5 }, pos = { 0, 0.5, 0 }, rot = { 0, r, 18 }, color = { 80, 58, 40 }, mat = "Wood", folder = "Decoracion" })
		end
		local fire = f:ball({ name = "Fuego", diameter = 1.4, pos = { 0, 1.2, 0 }, color = { 255, 140, 40 }, mat = "Neon", transparency = 0.15, folder = "Decoracion", shadow = false })
		if withLight ~= false then
			MB.light(fire, "Point", { color = { 255, 150, 70 }, brightness = 1.8, range = 18, shadows = true })
		end
	end

	-- Helicóptero militar estrellado
	function P.helicopterWreck(g, pos, rotY)
		local hcp = g:at(pos, rotY)
		local olive = { 74, 82, 60 }
		hcp:box({ name = "Fuselaje", size = { 7, 6, 16 }, pos = { 0, 3.2, 0 }, rot = { 0, 0, 14 }, color = olive, mat = "Metal" })
		hcp:wedge({ name = "Morro", size = { 6.6, 4, 4 }, pos = { 0.6, 2.6, -9.6 }, rot = { 0, 180, 14 }, color = { 40, 48, 44 }, mat = "Glass" })
		hcp:box({ name = "Cola", size = { 2, 2, 16 }, pos = { 1.2, 4, 15 }, rot = { 6, 0, 14 }, color = olive, mat = "Metal" })
		hcp:box({ name = "Aleta", size = { 0.5, 5, 3 }, pos = { 1.6, 6, 22.4 }, color = olive, mat = "Metal", folder = "Decoracion" })
		for i, r in ipairs({ 20, 110 }) do
			hcp:box({ name = "Pala", size = { 26 - i * 6, 0.3, 1.2 }, pos = { -0.8, 6.8 - i * 0.6, 0 }, rot = { 0, r, 12 + i * 6 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
		end
		P.debris(hcp, { 6, 0, -4 }, 0.8)
		hcp:ball({ name = "Humo", diameter = 6, pos = { 0, 11, -2 }, color = { 60, 60, 60 }, transparency = 0.5, folder = "Decoracion", shadow = false })
	end

	-- Vía de tren entre dos puntos: balasto, dos raíles y traviesas opcionales
	function P.rails(g, a, b, sleepers)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		r:box({ name = "Balasto", size = { len, 0.6, 10 }, pos = { 0, 0.3, 0 }, color = { 110, 104, 96 }, mat = "Pebble" })
		for _, z in ipairs({ -2.4, 2.4 }) do
			r:box({ name = "Rail", size = { len, 0.5, 0.5 }, pos = { 0, 0.95, z }, color = { 120, 96, 80 }, mat = "CorrodedMetal" })
		end
		if sleepers then
			for x = -len / 2 + 2, len / 2 - 2, 4 do
				r:box({ name = "Traviesa", size = { 1.2, 0.3, 7.6 }, pos = { x, 0.7, 0 }, color = { 90, 70, 52 }, mat = "Wood", folder = "Decoracion" })
			end
		end
	end

	-- Vagón de tren sobre la vía (largo a lo largo de X local). kind: "vagon", "cisterna", "plataforma", "locomotora"
	function P.trainCar(g, pos, rotY, kind, color)
		local t = g:at(pos, rotY)
		local c = color or { 130, 70, 50 }
		t:box({ name = "Bastidor", size = { 30, 1, 8 }, pos = { 0, 2.6, 0 }, color = { 40, 40, 42 }, mat = "Metal" })
		for _, x in ipairs({ -11, -8, 8, 11 }) do
			for _, z in ipairs({ -2.4, 2.4 }) do
				t:cylinder({ name = "Rueda", axis = "z", length = 0.6, diameter = 2.4, pos = { x, 1.6, z }, color = { 50, 46, 44 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		if kind == "cisterna" then
			t:cylinder({ name = "Cisterna", axis = "x", length = 28, diameter = 8, pos = { 0, 7.1, 0 }, color = c, mat = "Metal" })
		elseif kind == "plataforma" then
			P.crate(t, { -6, 3.1, 0 }, 5, 10)
			P.crate(t, { 2, 3.1, 0.5 }, 4.5, -5)
			t:box({ name = "Tubos", size = { 10, 2.4, 6 }, pos = { 9, 4.3, 0 }, color = { 140, 136, 130 }, mat = "Metal" })
		elseif kind == "locomotora" then
			t:box({ name = "Motor", size = { 20, 8, 7 }, pos = { 4, 7.1, 0 }, color = c, mat = "Metal" })
			t:box({ name = "Cabina", size = { 8, 11, 8 }, pos = { -10, 8.6, 0 }, color = c, mat = "Metal" })
			t:box({ name = "Ventanas", size = { 8.1, 2.4, 8.1 }, pos = { -10, 11, 0 }, color = { 30, 34, 36 }, mat = "Glass", folder = "Decoracion" })
			t:box({ name = "Franja", size = { 30.2, 1, 8.2 }, pos = { 0, 4.6, 0 }, color = { 230, 190, 50 }, folder = "Decoracion" })
		else
			t:box({ name = "Vagon", size = { 30, 10, 8 }, pos = { 0, 8.1, 0 }, color = c, mat = "CorrodedMetal" })
			t:box({ name = "Puerta", size = { 6, 8, 0.3 }, pos = { 0, 7.6, -4.1 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
			t:box({ name = "Puerta", size = { 6, 8, 0.3 }, pos = { 0, 7.6, 4.1 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Torre de radio de celosía con balizas
	function P.radioTower(g, pos, height)
		local t = g:at(pos, 0)
		local h = height or 100
		local steel = { 170, 60, 50 }
		local white = { 230, 230, 226 }
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			P.segment(t, { c[1] * 7, 0, c[2] * 7 }, { c[1] * 1.5, h, c[2] * 1.5 }, 0.8, steel, "Metal")
		end
		for k = 1, 8 do
			local y = k * h / 9
			local half = 7 - 5.5 * y / h
			for i, c in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
				P.segment(t, { c[1] * half, y, c[2] * half }, { c[3] * half, y, c[4] * half }, 0.4, (k % 2 == 0) and white or steel, "Metal", "Decoracion")
			end
		end
		local beacon = t:ball({ name = "Baliza", diameter = 2, pos = { 0, h + 1.5, 0 }, color = { 255, 60, 50 }, mat = "Neon", folder = "Decoracion" })
		MB.light(beacon, "Point", { color = { 255, 60, 50 }, brightness = 2, range = 30 })
		t:box({ name = "Base", size = { 18, 1, 18 }, pos = { 0, 0.5, 0 }, color = { 150, 148, 142 }, mat = "Concrete" })
	end

	function P.solarPanel(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Soporte", size = { 0.4, 3, 0.4 }, pos = { 0, 1.5, 0 }, color = { 120, 120, 126 }, mat = "Metal" })
		s:box({ name = "Panel", size = { 6, 0.3, 4 }, pos = { 0, 3.2, 0 }, rot = { 25, 0, 0 }, color = { 40, 60, 110 }, mat = "Glass", reflectance = 0.2 })
	end

	-- Bancal de huerto con plantas
	function P.gardenBed(g, pos, rotY, w, d)
		local b = g:at(pos, rotY)
		w, d = w or 10, d or 4
		b:box({ name = "Bancal", size = { w, 1, d }, pos = { 0, 0.5, 0 }, color = { 110, 80, 56 }, mat = "WoodPlanks" })
		b:box({ name = "Tierra", size = { w - 0.6, 0.2, d - 0.6 }, pos = { 0, 1.05, 0 }, color = { 70, 52, 40 }, mat = "Ground", folder = "Decoracion" })
		for i = 0, math.floor(w / 1.6) - 1 do
			b:ball({ name = "Planta", diameter = 1.2, pos = { -w / 2 + 1 + i * 1.6, 1.6, (i % 2 == 0) and -0.7 or 0.7 }, color = (i % 3 == 0) and { 200, 60, 50 } or { 80, 140, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.silo(g, pos, radius, height, color)
		local s = g:at(pos, 0)
		local c = color or { 176, 178, 180 }
		s:cylinder({ name = "Silo", length = height, diameter = radius * 2, pos = { 0, height / 2, 0 }, color = c, mat = "CorrodedMetal" })
		s:ball({ name = "Cupula", diameter = radius * 2, pos = { 0, height, 0 }, color = darker(c, 20), mat = "Metal" })
		for y = 6, height - 4, 8 do
			s:cylinder({ name = "Aro", length = 0.4, diameter = radius * 2 + 0.3, pos = { 0, y, 0 }, color = darker(c, 40), mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Molino de viento de granja
	function P.windmill(g, pos, rotY)
		local m = g:at(pos, rotY)
		local steel = { 130, 126, 120 }
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			P.segment(m, { c[1] * 3, 0, c[2] * 3 }, { c[1] * 0.6, 30, c[2] * 0.6 }, 0.4, steel, "Metal")
		end
		m:cylinder({ name = "Buje", axis = "z", length = 1.4, diameter = 1.6, pos = { 0, 31, -1 }, color = steel, mat = "Metal" })
		for i = 0, 11 do
			local a = math.rad(i * 30)
			m:box({ name = "Aspa", size = { 0.8, 5, 0.15 }, pos = { math.cos(a) * 3.2, 31 + math.sin(a) * 3.2, -1.8 }, rot = { 0, 0, i * 30 - 90 }, color = { 190, 186, 176 }, mat = "Metal", folder = "Decoracion" })
		end
		m:box({ name = "Cola", size = { 0.3, 3, 5 }, pos = { 0, 31, 3 }, color = steel, mat = "Metal", folder = "Decoracion" })
	end

	-- Campo de cultivo con surcos (rectángulo x0..x1, z0..z1 a la altura y)
	function P.cropField(g, x0, x1, z0, z1, y, color)
		g:box({ name = "Campo", size = { x1 - x0, 0.3, z1 - z0 }, pos = { (x0 + x1) / 2, y + 0.15, (z0 + z1) / 2 }, color = { 104, 84, 60 }, mat = "Ground", folder = "Decoracion" })
		for z = z0 + 3, z1 - 3, 6 do
			g:box({ name = "Surco", size = { x1 - x0 - 4, 1.6, 1.6 }, pos = { (x0 + x1) / 2, y + 1, z }, color = color or { 150, 140, 70 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
	end

	-- Avioneta estrellada
	function P.planeWreck(g, pos, rotY)
		local p = g:at(pos, rotY)
		local white = { 220, 220, 214 }
		p:cylinder({ name = "Fuselaje", axis = "z", length = 22, diameter = 5, pos = { 0, 2.6, 0 }, rot = { -4, 0, 0 }, color = white, mat = "Metal" })
		p:box({ name = "Ala", size = { 30, 0.6, 5 }, pos = { 0, 3.4, -2 }, rot = { 0, 0, 6 }, color = white, mat = "Metal" })
		p:box({ name = "Cola", size = { 0.5, 5, 4 }, pos = { 0, 5.6, 10 }, color = { 180, 50, 40 }, mat = "Metal", folder = "Decoracion" })
		p:box({ name = "Estabilizador", size = { 10, 0.4, 3 }, pos = { 0, 3.6, 10 }, color = white, mat = "Metal", folder = "Decoracion" })
		p:box({ name = "Cabina", size = { 4, 1.6, 4 }, pos = { 0, 4.6, -6 }, color = { 40, 50, 56 }, mat = "Glass", folder = "Decoracion" })
		P.debris(p, { 8, 0, 6 }, 0.6)
	end

	function P.tractor(g, pos, rotY, color)
		local t = g:at(pos, rotY)
		local c = color or { 60, 120, 60 }
		t:box({ name = "Chasis", size = { 4, 3, 9 }, pos = { 0, 3, 0 }, color = c, mat = "Metal" })
		t:box({ name = "Cabina", size = { 4.4, 4.4, 4 }, pos = { 0, 6.6, 2 }, color = { 40, 46, 44 }, mat = "Glass", transparency = 0.3 })
		t:box({ name = "Techo", size = { 4.8, 0.4, 4.6 }, pos = { 0, 9, 2 }, color = c, mat = "Metal", folder = "Decoracion" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			t:cylinder({ name = "Rueda", axis = "x", length = 1.6, diameter = 6, pos = { x, 3, 2.6 }, color = { 30, 30, 32 }, mat = "Rubber" })
			t:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3.2, pos = { x, 1.6, -3 }, color = { 30, 30, 32 }, mat = "Rubber" })
		end
		t:cylinder({ name = "Escape", length = 3, diameter = 0.4, pos = { 1.2, 6.4, -3 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Barca de pesca varada
	function P.boat(g, pos, rotY, color)
		local b = g:at(pos, rotY)
		local c = color or { 220, 220, 210 }
		b:box({ name = "Casco", size = { 8, 3, 18 }, pos = { 0, 1.5, 0 }, color = c, mat = "WoodPlanks" })
		b:wedge({ name = "Proa", size = { 8, 3, 5 }, pos = { 0, 1.5, -11.5 }, rot = { 0, 180, 0 }, color = c, mat = "WoodPlanks" })
		b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 0, 5, 3 }, color = { 200, 80, 60 }, mat = "WoodPlanks" })
		b:box({ name = "Franja", size = { 8.1, 0.6, 18.1 }, pos = { 0, 2.6, 0 }, color = { 50, 90, 140 }, folder = "Decoracion" })
	end

	-- Cinta transportadora de cantera entre dos puntos (a la altura del punto b)
	function P.conveyor(g, a, b)
		P.segment(g, a, b, 2.4, { 60, 60, 62 }, "Rubber")
		local n = 4
		for i = 1, n - 1 do
			local t = i / n
			local x, y, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
			g:box({ name = "Pata", size = { 1, y - 1, 1 }, pos = { x, (y - 1) / 2, z }, color = { 200, 160, 50 }, mat = "Metal" })
		end
	end
end
