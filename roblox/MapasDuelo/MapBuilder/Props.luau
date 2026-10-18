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
	function P.car(g, pos, rotY, color)
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
			c:box({ name = "Faro", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, -5.62 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
			c:box({ name = "Piloto", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, 5.62 }, color = { 210, 30, 30 }, mat = "Neon", folder = "Decoracion" })
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
end
