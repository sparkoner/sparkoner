--[[
	Efectos de la caza y la pesca (cliente, solo se ven en tu pantalla):
	  · Balas (trazadora), flechas y lanzables que siguen la misma trayectoria que calcula el servidor.
	    Las flechas se quedan clavadas en el suelo o en el animal (y se mueven con él).
	  · Fogonazo, sonidos, sangre, polvo, salpicaduras y temblor de cámara con las explosiones.
	  · Animación de los animales: patas al andar, al trotar y al galopar, cabeza baja al pastar,
	    mirar alrededor, cola levantada al huir (como hacen los ciervos)...
	  · Peces nadando bajo el agua cerca de ti y el pez en la mano cuando pescas uno.
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Efectos = {}
local Config, M
local carpeta, animales
local proyectiles = {}
local cache = setmetatable({}, { __mode = "k" })
local cardumenes = {}
local sacudida = 0
local paramsAgua

local function pieza(props, padre)
	local p = Instance.new(props.clase or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material[props.mat or "SmoothPlastic"]
	for k, v in pairs(props) do
		if k ~= "clase" and k ~= "mat" and k ~= "elipse" then
			p[k] = v
		end
	end
	if props.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = padre or carpeta
	return p
end

local function sonido(id, pos, volumen)
	if not id or id == "" then
		return
	end
	local p = pieza({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 1
	s.RollOffMaxDistance = 600
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 6)
end
Efectos.sonido = sonido

local function particulas(pos, color, n, velocidad, tam, gravedad)
	local p = pieza({ Size = Vector3.new(0.3, 0.3, 0.3), Transparency = 1, Position = pos })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(tam or 0.25, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(velocidad * 0.5, velocidad)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -(gravedad or 40), 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, 2)
end

-- =====================================================================
--  Proyectiles
-- =====================================================================
local function modeloFlecha(ballesta)
	local largo = ballesta and 1.2 or 2.4
	local m = Instance.new("Model")
	m.Name = "Flecha"
	local asta = pieza({ Name = "Asta", Size = Vector3.new(0.06, 0.06, largo), Color = Color3.fromRGB(34, 34, 36), CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(0.03, 0.14, 0.24), Color = Color3.fromRGB(200, 200, 206), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0, -largo / 2 - 0.1) }, m)
	for i = 0, 2 do
		local ang = math.rad(i * 120)
		pieza({ Size = Vector3.new(0.02, 0.16, 0.36), Color = (i == 0) and Color3.fromRGB(230, 110, 30) or Color3.fromRGB(236, 236, 230),
			CFrame = CFrame.new(0, 0, largo / 2 - 0.25) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.08, 0) }, m)
	end
	m.PrimaryPart = asta
	m.Parent = carpeta
	return m, largo
end

local function modeloLanzable(arma)
	local m = Instance.new("Model")
	if arma == "Molotov" then
		local b = pieza({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.62, 0.34, 0.34), Color = Color3.fromRGB(70, 100, 56), Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.new() }, m)
		local trapo = pieza({ Size = Vector3.new(0.3, 0.14, 0.14), Color = Color3.fromRGB(196, 186, 166), CFrame = CFrame.new(0.42, 0, 0) }, m)
		local f = Instance.new("Fire")
		f.Size = 1.5
		f.Heat = 3
		f.Parent = trapo
		m.PrimaryPart = b
	else
		m.PrimaryPart = pieza({ Size = Vector3.new(0.32, 0.44, 0.32), Color = Color3.fromRGB(76, 80, 62), Material = Enum.Material.Metal, elipse = true, CFrame = CFrame.new() }, m)
	end
	m.Parent = carpeta
	return m
end

function Efectos.disparo(d)
	local cfg = Config.Armas[d.arma]
	if not cfg then
		return
	end
	local p = { desde = d.desde, v = d.v, g = d.g, t = 0, tipo = cfg.tipo, arma = d.arma }
	if cfg.tipo == "bala" then
		p.visual = pieza({ Size = Vector3.new(0.05, 0.05, 2), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(d.desde) })
		-- Fogonazo (una vez por disparo, no por perdigón)
		if d.id % (cfg.perdigones or 1) == 0 then
			local f = pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Position = d.desde })
			local luz = Instance.new("PointLight")
			luz.Color = Color3.fromRGB(255, 190, 110)
			luz.Brightness = 4
			luz.Range = 14
			luz.Parent = f
			Debris:AddItem(f, 0.06)
			sonido(Config.Sonidos[d.arma], d.desde, 1)
		end
	elseif cfg.tipo == "proyectil" then
		p.visual, p.largo = modeloFlecha(d.arma == "Ballesta")
		sonido(Config.Sonidos[d.arma], d.desde, 0.8)
	else
		p.visual = modeloLanzable(d.arma)
		sonido(Config.Sonidos.Lanzar, d.desde, 0.8)
	end
	proyectiles[d.id] = p
end

local function quitar(id)
	local p = proyectiles[id]
	proyectiles[id] = nil
	return p
end

function Efectos.impacto(d)
	local p = d.id and quitar(d.id)
	if p then
		if p.tipo == "proyectil" then
			-- La flecha se queda clavada (y unida al animal si le ha dado)
			local vel = p.v + Vector3.new(0, p.g * p.t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(d.pos - dir * (p.largo * 0.2), d.pos - dir * (p.largo * 0.2) + dir)
			p.visual:PivotTo(cf)
			if d.parte and d.parte.Parent then
				for _, parte in ipairs(p.visual:GetChildren()) do
					if parte:IsA("BasePart") then
						parte.Anchored = false
						parte.Massless = true
						local w = Instance.new("WeldConstraint")
						w.Part0 = d.parte
						w.Part1 = parte
						w.Parent = parte
					end
				end
			end
			Debris:AddItem(p.visual, 30)
		else
			p.visual:Destroy()
		end
	end
	if d.tipo == "animal" or d.tipo == "jugador" then
		particulas(d.pos, Color3.fromRGB(120, 10, 8), 16, 8, 0.18, 30)
	elseif d.tipo == "agua" then
		particulas(d.pos, Color3.fromRGB(220, 230, 235), 20, 12, 0.3, 50)
	elseif d.tipo == "suelo" then
		particulas(d.pos, Color3.fromRGB(120, 108, 90), 10, 6, 0.3, 20)
	end
	if d.tipo ~= "lanzable" then
		sonido(Config.Sonidos.Impacto, d.pos, 0.6)
	end
end

function Efectos.fin(d)
	local p = quitar(d.id)
	if p then
		p.visual:Destroy()
	end
end

function Efectos.explosion(d, posCamara)
	local dist = (d.pos - posCamara).Magnitude
	if not d.fuego then
		sacudida = math.max(sacudida, math.clamp(1 - dist / 220, 0, 1) * 1.6)
		particulas(d.pos, Color3.fromRGB(70, 66, 60), 30, 25, 0.8, 10)
	end
end

local function sonidoEn(jugadorId, id, volumen)
	local p = Players:GetPlayerByUserId(jugadorId)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		sonido(id, hrp.Position, volumen)
	end
end

function Efectos.golpe(d)
	sonidoEn(d.jugador, Config.Sonidos.Cuerpo, 0.7)
end

function Efectos.recarga(d)
	sonidoEn(d.jugador, Config.Sonidos.Recarga, 0.8)
end

function Efectos.chapoteo(d)
	particulas(d.pos, Color3.fromRGB(220, 232, 236), 14, 6, 0.25, 30)
	sonido(Config.Sonidos.Chapoteo, d.pos, 0.7)
end

function Efectos.sacudir(n)
	sacudida = math.max(sacudida, n)
end

-- Temblor de cámara (se aplica después de que Roblox coloca la cámara)
function Efectos.camara(dt, camara)
	if sacudida > 0.01 then
		local a = sacudida
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * a * 2), math.rad((math.random() - 0.5) * a * 2), 0)
		sacudida = sacudida * math.exp(-dt * 6)
	end
end

-- =====================================================================
--  Peces: el de la mano al pescar y los que nadan bajo el agua
-- =====================================================================
-- Largo de un pez según su peso (la relación real peso-talla: W ≈ 0,01·L³ en gramos y cm)
local function largoPez(peso)
	return ((peso * 1000) / 0.01) ^ (1 / 3) / 100 * M
end

local function modeloPez(color, largo, transparencia)
	local m = Instance.new("Model")
	m.Name = "Pez"
	local c = Color3.fromRGB(color[1], color[2], color[3])
	local cuerpo = pieza({ Size = Vector3.new(largo * 0.2, largo * 0.28, largo), Color = c, elipse = true, Transparency = transparencia or 0, CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(largo * 0.16, largo * 0.14, largo * 0.8), Color = c:Lerp(Color3.new(1, 1, 1), 0.5), elipse = true,
		Transparency = transparencia or 0, CFrame = CFrame.new(0, -largo * 0.06, 0) }, m)
	for _, k in ipairs({ 1, -1 }) do
		pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.2, largo * 0.22), Color = c:Lerp(Color3.new(0, 0, 0), 0.2), Transparency = transparencia or 0,
			CFrame = CFrame.new(0, k * largo * 0.08, largo * 0.55) * CFrame.Angles(math.rad(k * 35), 0, 0) }, m)
	end
	pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.12, largo * 0.3), Color = c:Lerp(Color3.new(0, 0, 0), 0.25), Transparency = transparencia or 0,
		CFrame = CFrame.new(0, largo * 0.16, 0.02 * largo) }, m)
	if not transparencia then
		for _, k in ipairs({ 1, -1 }) do
			pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * largo * 0.05, Color = Color3.new(0.05, 0.05, 0.05), CFrame = CFrame.new(k * largo * 0.08, largo * 0.04, -largo * 0.36) }, m)
		end
	end
	m.PrimaryPart = cuerpo
	m.Parent = carpeta
	return m
end

function Efectos.pez(d)
	local p = Players:GetPlayerByUserId(d.jugador)
	local char = p and p.Character
	local mano = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local pez = Config.Peces[d.id]
	if not mano or not pez then
		return
	end
	local largo = math.clamp(largoPez(d.peso), 0.6, 9)
	local m = modeloPez(pez.color, largo)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 3 and m.Parent and mano.Parent do
			-- Colgando de la mano, coleteando
			m:PivotTo(mano.CFrame * CFrame.new(0, -largo * 0.5 - 0.4, 0) * CFrame.Angles(math.rad(90), math.rad(math.sin(os.clock() * 14) * 15), 0))
			task.wait()
		end
		m:Destroy()
	end)
end

local function nuevoCardumen(centro, superficie)
	local c = { centro = centro, y = superficie - 1.4, peces = {}, nace = os.clock(), rumbo = math.random() * math.pi * 2 }
	for i = 1, math.random(4, 7) do
		local largo = (0.25 + math.random() * 0.35) * M
		table.insert(c.peces, { m = modeloPez({ 50, 62, 56 }, largo, 0.35), r = 1.5 + math.random() * 3, a = math.random() * math.pi * 2, v = 0.6 + math.random() * 0.6, h = (math.random() - 0.5) * 0.8 })
	end
	table.insert(cardumenes, c)
end

local siguienteBusqueda = 0
function Efectos.peces(dt, posCamara)
	local ahora = os.clock()
	if ahora > siguienteBusqueda and #cardumenes < 3 then
		siguienteBusqueda = ahora + 1.5
		local ang, r = math.random() * math.pi * 2, 12 + math.random() * 35
		local x, z = posCamara.X + math.cos(ang) * r, posCamara.Z + math.sin(ang) * r
		local agua = workspace:Raycast(Vector3.new(x, posCamara.Y + 80, z), Vector3.new(0, -260, 0), paramsAgua)
		if agua and agua.Material == Enum.Material.Water then
			nuevoCardumen(Vector3.new(x, 0, z), agua.Position.Y)
		end
	end
	for i = #cardumenes, 1, -1 do
		local c = cardumenes[i]
		local lejos = (Vector3.new(c.centro.X, c.y, c.centro.Z) - posCamara).Magnitude > 110
		if lejos or ahora - c.nace > 45 then
			for _, p in ipairs(c.peces) do
				p.m:Destroy()
			end
			table.remove(cardumenes, i)
		else
			c.rumbo = c.rumbo + (math.random() - 0.5) * dt
			c.centro = c.centro + Vector3.new(math.cos(c.rumbo), 0, math.sin(c.rumbo)) * dt * 0.8
			for _, p in ipairs(c.peces) do
				p.a = p.a + p.v * dt
				local pos = Vector3.new(c.centro.X + math.cos(p.a) * p.r, c.y + p.h, c.centro.Z + math.sin(p.a) * p.r)
				local tangente = Vector3.new(-math.sin(p.a), 0, math.cos(p.a))
				p.m:PivotTo(CFrame.lookAt(pos, pos + tangente) * CFrame.Angles(0, math.rad(math.sin(ahora * 9 + p.a) * 10), 0))
			end
		end
	end
end

-- =====================================================================
--  Animación de los animales (Motor6D.Transform; cada cliente anima los que tiene cerca)
-- =====================================================================
local function juntas(modelo)
	local c = cache[modelo]
	if c then
		return c
	end
	c = { m = {}, fase = math.random() * 6.28, semilla = math.random() * 100, cuello = 0, cola = 0, mira = 0 }
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("Motor6D") then
			c.m[d.Name] = d
		end
	end
	cache[modelo] = c
	return c
end

local PASO = { DI = 0, TD = 0, DD = math.pi, TI = math.pi }
local GALOPE = { DI = 0, DD = 0.5, TI = math.pi, TD = math.pi + 0.5 }
local SALTO = { DI = 0, DD = 0.2, TI = math.pi * 0.8, TD = math.pi * 0.8 + 0.2 }
local ID = CFrame.new()

function Efectos.animar(dt, posCamara)
	local t = os.clock()
	for _, modelo in ipairs(animales:GetChildren()) do
		local raiz = modelo.PrimaryPart
		if raiz and (raiz.Position - posCamara).Magnitude < 230 then
			local c = juntas(modelo)
			local mov = modelo:GetAttribute("Mov") or "quieto"
			if mov == "muerto" then
				if not c.muerto then
					c.muerto = true
					for _, m in pairs(c.m) do
						m.Transform = ID
					end
				end
			else
				c.muerto = false
				local escala = modelo:GetAttribute("Escala") or 1
				local especie = modelo:GetAttribute("Especie")
				local corre = mov == "correr"
				local anda = corre or mov == "andar"
				local freq = (corre and 2.3 or 1.3) / math.sqrt(math.max(escala, 0.3))
				if especie == "Conejo" then
					freq = corre and 3.2 or 1.6
				end
				if anda then
					c.fase = c.fase + dt * freq * math.pi * 2
				end
				local f = c.fase
				local amp = anda and (corre and 34 or 18) or 0
				local flex = anda and (corre and 55 or 30) or 0
				local patron = corre and GALOPE or PASO
				if modelo:GetAttribute("Salta") and anda then
					patron, amp = SALTO, 42
				end
				for lado, off in pairs(patron) do
					local cadera, rodilla = c.m["Cadera" .. lado], c.m["Rodilla" .. lado]
					if cadera then
						cadera.Transform = CFrame.Angles(math.rad(amp * math.sin(f + off)), 0, 0)
					end
					if rodilla then
						rodilla.Transform = CFrame.Angles(math.rad(-flex * math.max(0, math.cos(f + off))), 0, 0)
					end
				end
				-- Aves (pavo)
				for lado, off in pairs({ I = 0, D = math.pi }) do
					local p = c.m["Pierna" .. lado]
					if p then
						p.Transform = CFrame.Angles(math.rad((anda and (corre and 40 or 26) or 0) * math.sin(f + off)), 0, 0)
					end
				end
				-- Cangrejo
				for i = 1, 8 do
					local p = c.m["Pata" .. i]
					if p then
						p.Transform = anda and CFrame.Angles(0, math.rad(18 * math.sin(f * 2 + i)), math.rad(10 * math.cos(f * 2 + i))) or ID
					end
				end
				-- Cuello: baja la cabeza al pastar, cabecea al andar, mira alrededor parado
				local objetivo = (mov == "pastar") and -55 or (corre and -6 or ((mov == "atacar") and -20 or 0))
				if especie == "Pavo" or especie == "Pato" then
					objetivo = (mov == "pastar") and -40 or 0
				end
				c.cuello = c.cuello + (objetivo - c.cuello) * math.min(1, dt * 3)
				local cabeceo = anda and math.sin(f * 2) * ((especie == "Pavo") and 12 or 4) or 0
				local mirar = (mov == "quieto") and math.sin(t * 0.45 + c.semilla) * 28 or 0
				c.mira = c.mira + (mirar - c.mira) * math.min(1, dt * 2)
				if c.m.Cuello then
					c.m.Cuello.Transform = CFrame.Angles(math.rad(c.cuello + cabeceo), math.rad(c.mira), 0)
				end
				-- Cola: el ciervo la levanta al huir (la "bandera" blanca)
				local cola = (corre and especie == "Ciervo") and -60 or 0
				c.cola = c.cola + (cola - c.cola) * math.min(1, dt * 4)
				if c.m.Cola then
					c.m.Cola.Transform = CFrame.Angles(math.rad(c.cola), math.rad(12 * math.sin(t * 2.4 + c.semilla)), 0)
				end
			end
		end
	end
end

-- =====================================================================
--  Bucle de proyectiles
-- =====================================================================
function Efectos.actualizar(dt)
	for id, p in pairs(proyectiles) do
		p.t = p.t + dt
		if p.t > 15 or not p.visual.Parent then
			quitar(id)
			p.visual:Destroy()
		else
			local t = p.t
			local pos = p.desde + p.v * t + Vector3.new(0, 0.5 * p.g * t * t, 0)
			local vel = p.v + Vector3.new(0, p.g * t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			if p.tipo == "bala" then
				local largo = math.clamp(vel.Magnitude * dt * 0.8, 1, 12)
				p.visual.Size = Vector3.new(0.05, 0.05, largo)
				p.visual.CFrame = CFrame.lookAt(pos - dir * largo / 2, pos)
			elseif p.tipo == "proyectil" then
				p.visual:PivotTo(CFrame.lookAt(pos, pos + dir))
			else
				p.visual:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 4, 0))
			end
		end
	end
end

function Efectos.iniciar(config)
	Config = config
	M = Config.StudsPorMetro
	carpeta = Instance.new("Folder")
	carpeta.Name = "EfectosLocales"
	carpeta.Parent = workspace
	animales = workspace:WaitForChild("Animales", 30) or Instance.new("Folder")
	paramsAgua = RaycastParams.new()
	paramsAgua.FilterType = Enum.RaycastFilterType.Include
	paramsAgua.FilterDescendantsInstances = { workspace.Terrain }
	paramsAgua.IgnoreWater = false
end

return Efectos
