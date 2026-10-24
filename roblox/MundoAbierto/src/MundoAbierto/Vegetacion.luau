--[[
	Vegetación del mundo abierto, hecha para parecer natural y no de bolas y cubos:
	  · Abetos: capas de ramas que caen y se acortan hacia una punta afilada (silueta de árbol de navidad)
	  · Robles: tronco grueso, ramas abiertas y copa irregular de muchas matas de hojas de varios tonos
	  · Abedules: tronco blanco con marcas y copa alta y estrecha; árboles secos con ramas rotas
	  · Sotobosque: helechos, arbustos bajos y abetos jóvenes; hierba alta en matas; juncos en las orillas
	  · Troncos caídos que siguen la pendiente, tocones y rocas esculpidas en el propio terreno
	El bosque es más denso donde el terreno tiene maleza (LeafyGrass) y los abetos dominan en el norte
	y en las alturas.

	Modelos propios (opcional): si en ServerStorage hay una carpeta "ModelosMundo" con subcarpetas
	Pino, Roble, Abedul, Muerto o Arbusto que tengan modelos dentro (por ejemplo árboles 3D realistas
	de la Toolbox), se colocan esos en lugar de los hechos con piezas, con tamaño y giro al azar.
]]
return function(b, MB, W, T)
	local P = MB.Props
	local V = {}

	local FIR = { { 38, 66, 44 }, { 44, 74, 50 }, { 33, 58, 40 }, { 50, 80, 54 }, { 42, 70, 56 } }
	local OAK = { { 74, 100, 52 }, { 86, 112, 58 }, { 64, 90, 46 }, { 98, 112, 56 }, { 112, 106, 54 } }
	local BIRCH = { { 122, 150, 72 }, { 138, 158, 80 }, { 112, 140, 66 }, { 150, 150, 70 } }
	local FERN = { { 70, 108, 48 }, { 82, 118, 54 }, { 96, 120, 58 } }
	local GRASS = { { 96, 124, 64 }, { 110, 132, 70 }, { 130, 136, 76 }, { 150, 146, 90 }, { 86, 114, 58 } }
	local REED = { { 104, 120, 66 }, { 120, 128, 72 }, { 138, 132, 80 } }
	local BARK = { 70, 54, 42 }
	local BARK_OAK = { 84, 66, 50 }

	local function pick(list)
		return list[math.floor(W.rand() * #list) + 1]
	end

	local function rod(name, a, c, diameter, color, mat, folder)
		local part = P.rod(b, a, c, diameter, color, mat, folder)
		part.Name = name
		return part
	end

	-- =================================================================
	--  Modelos propios de ServerStorage.ModelosMundo (si los hay)
	-- =================================================================
	local MODELS = {}
	do
		local ok, folder = pcall(function()
			return game:GetService("ServerStorage"):FindFirstChild("ModelosMundo")
		end)
		if ok and folder then
			for _, kind in ipairs({ "Pino", "Roble", "Abedul", "Muerto", "Arbusto" }) do
				local sub = folder:FindFirstChild(kind)
				local list = {}
				if sub then
					for _, m in ipairs(sub:GetChildren()) do
						if m:IsA("Model") or m:IsA("BasePart") then
							table.insert(list, m)
						end
					end
				end
				if #list > 0 then
					MODELS[kind] = list
				end
			end
		end
	end
	V.modelos = MODELS

	-- Coloca una copia de un modelo propio apoyada en el suelo. Devuelve false si no hay modelos de ese tipo
	local function useModel(kind, x, z, s)
		local list = MODELS[kind]
		if not list then
			return false
		end
		local src = list[math.floor(W.rand() * #list) + 1]
		local m = src:Clone()
		if m:IsA("BasePart") then
			local g = Instance.new("Model")
			g.Name = src.Name
			m.Parent = g
			g.PrimaryPart = m
			m = g
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- los modelos de la Toolbox a veces traen scripts (incluso maliciosos): fuera
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		pcall(function()
			m:ScaleTo(m:GetScale() * s)
		end)
		local box, size = m:GetBoundingBox()
		local bottom = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		local rel = m:GetPivot():ToObjectSpace(bottom)
		local target = CFrame.new(x, T.height(x, z) - 0.3, z) * CFrame.Angles(0, math.rad(W.range(0, 360)), 0)
		m:PivotTo(target * rel:Inverse())
		m.Parent = b:folder("Mapa")
		return true
	end

	-- =================================================================
	--  Árboles
	-- =================================================================
	-- Abeto: capas de tres ramas en cuña que caen hacia fuera (cada capa girada 60° respecto a la de abajo),
	-- más cortas cuanto más arriba, y punta afilada
	function V.pine(x, z, s)
		if useModel("Pino", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.6
		local c = pick(FIR)
		local H = 27 * s
		local layers = (H < 15) and 3 or ((H > 34) and 6 or 5)
		b:cylinder({ name = "Tronco", length = H * 0.85, diameter = math.max(0.5, 1.3 * s), pos = { x, y + H * 0.425, z }, color = BARK, mat = "Wood" })
		local spin = W.range(0, 90)
		local function whorl(yy, R, th, w, turn, shade, droop)
			for k = 0, 2 do
				local a = spin + turn + k * 120 + W.range(-14, 14)
				local r = math.rad(a)
				local len = R * W.range(0.9, 1.08)
				b:wedge({ name = "Ramas", size = { w, th, len }, pos = { x - math.sin(r) * len / 2, yy + th / 2, z - math.cos(r) * len / 2 }, rot = { -droop, a, 0 }, color = (k % 2 == 0) and shade or P.darker(shade, 7), mat = "LeafyGrass", folder = "Decoracion" })
			end
		end
		for i = 0, layers - 1 do
			local t = i / (layers - 1)
			local R = H * (0.34 - 0.25 * t) * W.range(0.92, 1.08)
			whorl(y + H * (0.16 + 0.64 * t), R, R * 0.5 + H * 0.06, R * 0.95, i * 60, P.lighter(c, math.floor(t * 14)), W.range(5, 12))
		end
		-- Punta: tres aletas finas en cruz que acaban en pico
		whorl(y + H * 0.78, H * 0.09, H * 0.21, math.max(0.35, 0.5 * s), 30, P.lighter(c, 16), 0)
	end

	-- Roble: tronco grueso, tres o cuatro ramas abiertas y matas de hojas aplastadas alrededor de cada punta
	function V.oak(x, z, s)
		if useModel("Roble", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local c = pick(OAK)
		local top = y + 7 * s
		b:cylinder({ name = "Tronco", length = 8 * s, diameter = 2.2 * s, pos = { x, y + 4 * s, z }, color = BARK_OAK, mat = "Wood" })
		local ends = { { x + W.range(-1, 1) * s, top + W.range(6.5, 8) * s, z + W.range(-1, 1) * s } }
		local nb = (W.rand() < 0.5) and 3 or 4
		local spin = W.range(0, 360)
		for k = 1, nb do
			local a = math.rad(spin + k * 360 / nb + W.range(-25, 25))
			local r = W.range(3.5, 5.5) * s
			local e = { x + math.cos(a) * r, top + W.range(3, 5) * s, z + math.sin(a) * r }
			rod("Rama", { x, top - s, z }, e, W.range(0.6, 0.9) * s, BARK_OAK, "Wood", "Decoracion")
			table.insert(ends, e)
		end
		for n, e in ipairs(ends) do
			for j = 1, (n == 1) and 3 or 2 do
				local w = W.range(5.5, 8) * s
				local shade = (j == 1) and c or ((j == 2) and P.lighter(c, 10) or P.darker(c, 10))
				b:blob({ name = "Copa", size = { w, w * W.range(0.7, 0.9), w * W.range(0.8, 1) }, pos = { e[1] + W.range(-1.6, 1.6) * s, e[2] + W.range(-0.4, 1.4) * s, e[3] + W.range(-1.6, 1.6) * s }, rot = { W.range(-15, 15), W.range(0, 180), W.range(-15, 15) }, color = shade, mat = "LeafyGrass", folder = "Decoracion" })
			end
		end
	end

	-- Abedul: tronco blanco con marcas oscuras, dos ramitas y copa alta y estrecha
	function V.birch(x, z, s)
		if useModel("Abedul", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local c = pick(BIRCH)
		local H = 17 * s
		b:cylinder({ name = "Tronco", length = H, diameter = 1.1 * s, pos = { x, y + H / 2, z }, color = { 224, 220, 208 }, mat = "Wood" })
		for k = 1, 3 do
			b:cylinder({ name = "Marca", length = 0.35 * s, diameter = 1.16 * s, pos = { x, y + (2.5 + k * 3.1) * s, z }, color = { 52, 50, 48 }, mat = "Wood", folder = "Decoracion" })
		end
		for _ = 1, 2 do
			local a = math.rad(W.range(0, 360))
			local yy = y + H * W.range(0.5, 0.7)
			rod("Rama", { x, yy, z }, { x + math.cos(a) * 3 * s, yy + 2.5 * s, z + math.sin(a) * 3 * s }, 0.4 * s, { 214, 210, 198 }, "Wood", "Decoracion")
		end
		for k = 0, 5 do
			local t = k / 5
			local w = (4.6 - 1.6 * t) * s * W.range(0.85, 1.15)
			b:blob({ name = "Copa", size = { w, w * W.range(1.1, 1.5), w * 0.9 }, pos = { x + W.range(-1.9, 1.9) * s, y + H * (0.5 + 0.48 * t), z + W.range(-1.9, 1.9) * s }, rot = { W.range(-12, 12), W.range(0, 180), W.range(-12, 12) }, color = (k % 2 == 0) and c or P.lighter(c, 10), mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	-- Árbol seco: tronco gris con la copa partida y ramas desnudas con ramitas
	function V.dead(x, z, s)
		if useModel("Muerto", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local gray = { 106, 96, 86 }
		local H = 11 * s
		b:cylinder({ name = "Tronco", length = H, diameter = 1.4 * s, pos = { x, y + H / 2, z }, color = gray, mat = "Wood" })
		local a0 = math.rad(W.range(0, 360))
		rod("Rama", { x, y + H - 0.3, z }, { x + math.cos(a0) * 1.4 * s, y + H + 3.5 * s, z + math.sin(a0) * 1.4 * s }, 0.8 * s, gray, "Wood", "Decoracion")
		for _ = 1, 3 do
			local a = math.rad(W.range(0, 360))
			local yy = y + H * W.range(0.45, 0.85)
			local r = W.range(2.6, 4) * s
			local e = { x + math.cos(a) * r, yy + W.range(2, 3.5) * s, z + math.sin(a) * r }
			rod("Rama", { x, yy, z }, e, 0.5 * s, gray, "Wood", "Decoracion")
			local a2 = a + math.rad(W.range(-50, 50))
			rod("Rama", e, { e[1] + math.cos(a2) * 1.6 * s, e[2] + 1.4 * s, e[3] + math.sin(a2) * 1.6 * s }, 0.28 * s, gray, "Wood", "Decoracion")
		end
	end

	-- =================================================================
	--  Sotobosque y plantas pequeñas
	-- =================================================================
	-- Arbusto: varias matas aplastadas de distinto tono
	function V.bush(x, z, s)
		if useModel("Arbusto", x, z, s) then
			return
		end
		local y = T.height(x, z)
		local c = pick(OAK)
		for k = 1, 4 do
			local w = W.range(2.4, 3.8) * s
			b:blob({ name = "Arbusto", size = { w, w * W.range(0.55, 0.8), w * W.range(0.7, 1) }, pos = { x + W.range(-1.5, 1.5) * s, y + w * 0.25, z + W.range(-1.5, 1.5) * s }, rot = { 0, W.range(0, 180), W.range(-10, 10) }, color = (k == 1) and c or ((k % 2 == 0) and P.lighter(c, 9) or P.darker(c, 8)), mat = "LeafyGrass", folder = "Decoracion", query = false })
		end
	end

	-- Helecho: siete frondas en cuña que salen del centro hacia arriba y hacia fuera
	function V.fern(x, z, s)
		local y = T.height(x, z) - 0.1
		local c = pick(FERN)
		local spin = W.range(0, 360)
		for k = 0, 6 do
			local a = spin + k * 360 / 7 + W.range(-12, 12)
			local r = math.rad(a)
			local len = W.range(2.4, 3.6) * s
			local up = W.range(22, 38)
			local hx, hy = math.cos(math.rad(up)) * len / 2, math.sin(math.rad(up)) * len / 2
			b:wedge({ name = "Helecho", size = { W.range(0.7, 1) * s, 0.45 * s, len }, pos = { x - math.sin(r) * hx, y + 0.25 * s + hy, z - math.cos(r) * hx }, rot = { up, a, 0 }, color = (k % 2 == 0) and c or P.lighter(c, 10), mat = "Grass", folder = "Decoracion", shadow = false, query = false })
		end
	end

	-- Mata de hierba alta: tres hojas en cuña (punta afilada) abiertas en estrella (sin colisión ni sombra)
	function V.tuft(x, z, s, dry)
		local y = T.height(x, z)
		local c = dry and GRASS[4] or pick(GRASS)
		local yaw = W.range(0, 360)
		for k = 0, 2 do
			local h = W.range(2, 4.4) * s
			local a = yaw + k * 120 + W.range(-25, 25)
			local r = math.rad(a)
			b:wedge({ name = "HierbaAlta", size = { 0.08, h, W.range(0.35, 0.7) * s }, pos = { x + math.cos(r) * 0.3, y + h / 2 - 0.3, z + math.sin(r) * 0.3 }, rot = { W.range(-18, 18), a, W.range(-14, 14) }, color = (k == 1) and P.darker(c, 9) or c, mat = "Grass", folder = "Decoracion", shadow = false, query = false })
		end
	end

	-- Juncos de orilla: tallos finos algo inclinados, dos con la espiga marrón
	function V.reeds(x, z, s)
		local y = T.height(x, z)
		for k = 1, 5 do
			local h = W.range(4, 7) * s
			local px, pz = x + W.range(-1.3, 1.3), z + W.range(-1.3, 1.3)
			local tilt, yaw = W.range(0, 10), W.range(0, 360)
			local c = pick(REED)
			b:cylinder({ name = "Junco", length = h, diameter = 0.18, pos = { px, y + h / 2 - 0.3, pz }, rot = { tilt, yaw, 0 }, color = c, mat = "Grass", folder = "Decoracion", shadow = false, query = false })
			if k <= 2 then
				-- La espiga va en la punta del tallo inclinado
				local d = h / 2 - 0.7
				local st, ct = math.sin(math.rad(tilt)), math.cos(math.rad(tilt))
				local sy, cy = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
				b:cylinder({ name = "Espiga", length = 1.3, diameter = 0.42, pos = { px + sy * d * st, y + h / 2 - 0.3 + d * ct, pz + cy * d * st }, rot = { tilt, yaw, 0 }, color = { 96, 64, 40 }, mat = "Fabric", folder = "Decoracion", shadow = false, query = false })
			end
		end
	end

	-- Tronco caído apoyado en el suelo (sigue la pendiente), con musgo encima y una rama rota
	function V.log(x, z)
		local len = W.range(10, 18)
		local a = math.rad(W.range(0, 360))
		local dx, dz = math.cos(a) * len / 2, math.sin(a) * len / 2
		local d = W.range(1.6, 2.4)
		local p1 = { x - dx, T.height(x - dx, z - dz) + d * 0.35, z - dz }
		local p2 = { x + dx, T.height(x + dx, z + dz) + d * 0.35, z + dz }
		rod("TroncoCaido", p1, p2, d, { 88, 70, 52 }, "Wood", "Mapa")
		local mid = { (p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2, (p1[3] + p2[3]) / 2 }
		rod("Musgo", { p1[1], p1[2] + d * 0.3, p1[3] }, { mid[1], mid[2] + d * 0.3, mid[3] }, d * 0.75, { 74, 102, 56 }, "LeafyGrass", "Decoracion")
		local q = { mid[1] + dx * 0.4, mid[2] + d * 0.3, mid[3] + dz * 0.4 }
		rod("Rama", q, { q[1] - dz * 0.2, q[2] + 2.8, q[3] + dx * 0.2 }, 0.45, { 92, 74, 56 }, "Wood", "Decoracion")
	end

	-- Tocón de un árbol talado, con el corte claro arriba
	function V.stump(x, z)
		local y = T.height(x, z)
		local d, h = W.range(2, 3), W.range(1.2, 2.4)
		b:cylinder({ name = "Tocon", length = h + 0.6, diameter = d, pos = { x, y + h / 2 - 0.3, z }, color = BARK, mat = "Wood" })
		b:cylinder({ name = "Corte", length = 0.12, diameter = d * 0.86, pos = { x, y + h - 0.05, z }, color = { 158, 128, 92 }, mat = "Wood", folder = "Decoracion" })
	end

	-- Rocas: se esculpen en el terreno (ver Terreno.addBoulder); a veces en grupos de dos o tres
	function V.rock(x, z, s)
		T.addBoulder(x, z, 4.5 * s)
		for _ = 1, math.floor(W.range(0, 2.99)) do
			local a = W.range(0, 2 * math.pi)
			local d = W.range(5, 9) * s
			T.addBoulder(x + math.cos(a) * d, z + math.sin(a) * d, W.range(2.6, 3.6) * s)
		end
	end

	-- =================================================================
	--  Repartir por el mapa
	-- =================================================================
	-- Sitio libre: en tierra, fuera de zonas, carreteras y agua, y sin pendiente fuerte
	local function free(x, z, roadMargin, zoneMargin)
		local road, river, zone, coast = T.fields(x, z)
		if coast < 55 or river < 14 or road < 11 + roadMargin or zone < zoneMargin then
			return false
		end
		return true
	end

	-- Orilla de río o lago: entre "lo" (dentro del agua) y "hi" studs del borde
	local function bank(x, z, lo, hi)
		local road, river, zone, coast = T.fields(x, z)
		return river > lo and river < hi and coast > 60 and road > 14 and zone > 8
	end

	local function randomPoint()
		return W.range(-2030, 1560), W.range(-2030, 1500)
	end

	function V.buildAll(counts)
		local placed = { trees = 0, bushes = 0, ferns = 0, saplings = 0, tufts = 0, reeds = 0, logs = 0, stumps = 0, rocks = 0, riverRocks = 0 }
		-- Árboles: el bosque se espesa donde hay maleza; abetos sobre todo en el norte y en las alturas
		local tries = 0
		while placed.trees < counts.trees and tries < counts.trees * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 9, 14) then
				local veg = T.veg(x, z)
				local density = 0.04 + 0.9 * math.max(0, math.min(1, (veg + 0.2) / 0.45))
				if W.rand() < density then
					local surf, h = T.surface(x, z)
					if surf ~= "Rock" and surf ~= "Snow" and surf ~= "Sand" and h < 150 then
						local r = W.rand()
						local _, river = T.fields(x, z)
						if r < 0.07 then
							V.dead(x, z, W.range(0.9, 1.3))
						elseif (z < -1100 or h > 45) and r < 0.88 or r < 0.62 then
							V.pine(x, z, W.range(0.85, 1.5))
						elseif river < 60 and r < 0.85 then
							V.birch(x, z, W.range(0.9, 1.3))
						else
							V.oak(x, z, W.range(0.9, 1.4))
						end
						placed.trees = placed.trees + 1
					end
				end
			end
		end
		-- Sotobosque: helechos y abetos jóvenes bajo los árboles; arbustos en los claros y bordes
		tries = 0
		while placed.bushes + placed.ferns + placed.saplings < counts.bushes and tries < counts.bushes * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) then
				local veg = T.veg(x, z)
				if veg > -0.15 and W.rand() < 0.7 then
					local surf, h = T.surface(x, z)
					if (surf == "Grass" or surf == "LeafyGrass") and h < 150 then
						local r = W.rand()
						local dense = veg > 0.15
						if (dense and r < 0.6) or (not dense and r < 0.2) then
							V.fern(x, z, W.range(0.8, 1.3))
							placed.ferns = placed.ferns + 1
						elseif (dense and r < 0.85) or (not dense and r < 0.4) then
							V.pine(x, z, W.range(0.3, 0.5))
							placed.saplings = placed.saplings + 1
						else
							V.bush(x, z, W.range(0.8, 1.5))
							placed.bushes = placed.bushes + 1
						end
					end
				end
			end
		end
		-- Hierba alta en grupos, sobre todo donde hay maleza
		tries = 0
		while placed.tufts < counts.tufts and tries < counts.tufts * 4 do
			tries = tries + 1
			local cx, cz = randomPoint()
			if free(cx, cz, 2, 4) then
				local surf = T.surface(cx, cz)
				if surf == "LeafyGrass" or (surf == "Grass" and W.rand() < 0.3) then
					local dry = W.rand() < 0.25
					for _ = 1, math.floor(W.range(3, 7)) do
						local x, z = cx + W.range(-6, 6), cz + W.range(-6, 6)
						if free(x, z, 1, 3) then
							V.tuft(x, z, W.range(0.8, 1.3), dry)
							placed.tufts = placed.tufts + 1
						end
					end
				end
			end
		end
		-- Juncos en las orillas (en grupos a lo largo del borde) y rocas en el agua poco profunda
		tries = 0
		while placed.reeds < counts.reeds and tries < counts.reeds * 300 do
			tries = tries + 1
			local cx, cz = randomPoint()
			if bank(cx, cz, -1.5, 6) then
				for _ = 1, math.floor(W.range(2, 5)) do
					local x, z = cx + W.range(-7, 7), cz + W.range(-7, 7)
					if placed.reeds < counts.reeds and bank(x, z, -1.5, 6) then
						V.reeds(x, z, W.range(0.8, 1.2))
						placed.reeds = placed.reeds + 1
					end
				end
			end
		end
		tries = 0
		while placed.riverRocks < counts.riverRocks and tries < counts.riverRocks * 300 do
			tries = tries + 1
			local x, z = randomPoint()
			if bank(x, z, -4, 8) then
				T.addBoulder(x, z, W.range(3, 5.5))
				placed.riverRocks = placed.riverRocks + 1
			end
		end
		-- Troncos caídos y tocones en el bosque
		tries = 0
		while placed.logs < counts.logs and tries < counts.logs * 20 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 6, 10) and T.veg(x, z) > 0.15 then
				local surf = T.surface(x, z)
				if surf == "LeafyGrass" or surf == "Grass" then
					V.log(x, z)
					placed.logs = placed.logs + 1
				end
			end
		end
		tries = 0
		while placed.stumps < counts.stumps and tries < counts.stumps * 20 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) and T.veg(x, z) > 0 then
				V.stump(x, z)
				placed.stumps = placed.stumps + 1
			end
		end
		-- Rocas: más en las colinas
		tries = 0
		while placed.rocks < counts.rocks and tries < counts.rocks * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) then
				local _, h = T.surface(x, z)
				if h > 12 or W.rand() < 0.3 then
					V.rock(x, z, W.range(0.7, 1.6))
					placed.rocks = placed.rocks + 1
				end
			end
		end
		return placed
	end

	return V
end
