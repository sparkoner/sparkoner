--[[
	Animales del mundo abierto (servidor): dónde aparecen, cómo se comportan, cómo se hieren y qué se saca de ellos.

	Comportamiento:
	  · Pastan, descansan y pasean cerca de su zona; los patos nadan y los cangrejos van por la arena.
	  · Las presas huyen cuando te detectan. La distancia depende de si vas agachado o corriendo y del viento:
	    si el viento sopla de ti hacia ellas te huelen desde mucho más lejos.
	  · Los disparos espantan a las presas que los oyen (cada arma hace más o menos ruido).
	  · Los depredadores (lobos, osos) te cazan si te acercas; el jabalí solo ataca si le hieres o le agobias.
	  · Un animal herido sangra (más con flechas), huye dejando un rastro de sangre en el suelo y cae cuando se desangra.
	Al morir se queda tumbado y se puede despellejar (mantén E): carne según su peso y piel según el daño recibido.
]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Animales = {}
local Config, Modelos, W, M
local carpeta, rastros
local lista = {}
local porModelo = {}
local params
local ctx

local LIMITE = 1950
local AGUA = Enum.Material.Water
local PRADO = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }
local NORTE = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true, [Enum.Material.Snow] = true }

local function ahora()
	return os.clock()
end

-- Altura y material del terreno (o del agua) en un punto
local function suelo(x, z)
	local r = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	if r then
		return r.Position.Y, r.Material
	end
	return nil, nil
end
Animales.suelo = suelo

local function enZona(x, z, margen)
	return W ~= nil and W.inZone(x, z, margen)
end

-- =====================================================================
--  Dónde puede vivir cada especie
-- =====================================================================
local function apto(donde, x, z)
	if math.abs(x) > LIMITE or math.abs(z) > LIMITE or enZona(x, z, 30) then
		return nil
	end
	local y, mat = suelo(x, z)
	if not y then
		return nil
	end
	if donde == "agua" then
		if mat == AGUA and (not W or W.inLandPoly(x, z)) then
			return y
		end
		return nil
	end
	if mat == AGUA then
		return nil
	end
	if donde == "playa" then
		return (mat == Enum.Material.Sand and y > -5 and y < 5) and y or nil
	elseif donde == "prado" then
		return (PRADO[mat] and y < 70) and y or nil
	elseif donde == "bosque" then
		return ((mat == Enum.Material.LeafyGrass or (mat == Enum.Material.Grass and math.random() < 0.25)) and y < 130) and y or nil
	elseif donde == "norte" then
		return (NORTE[mat] and (z < -700 or y > 60) and y < 170) and y or nil
	elseif donde == "montana" then
		return (y > 45 and y < 200 and mat ~= Enum.Material.Sand) and y or nil
	elseif donde == "granja" then
		return PRADO[mat] and y or nil
	end
	return y
end

local function buscarSitio(donde, lejosDe)
	for intento = 1, 500 do
		local x, z
		if donde == "granja" and W and W.zones.Granjas and intento < 300 then
			local r = W.zones.Granjas
			x, z = math.random(r[1] - 260, r[2] + 260), math.random(r[3] - 260, r[4] + 260)
		else
			x, z = math.random(-LIMITE, LIMITE), math.random(-LIMITE, LIMITE)
		end
		local y = apto(donde, x, z)
		local lejos = true
		if y and lejosDe then
			for _, p in ipairs(lejosDe) do
				if (Vector3.new(x, 0, z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 150 then
					lejos = false
				end
			end
		end
		if y and lejos then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

-- =====================================================================
--  Crear un animal
-- =====================================================================
local function sonido(a, nombre)
	local id = Config.Sonidos[nombre or a.especie]
	if id and id ~= "" and ahora() - (a.ultimoSonido or 0) > 5 then
		a.ultimoSonido = ahora()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.RollOffMaxDistance = 220
		s.Volume = 0.8
		s.Parent = a.raiz
		s:Play()
		Debris:AddItem(s, 8)
	end
end

local function crear(especie, punto, casa)
	local def = Config.Animales[especie]
	local macho = (especie == "Ciervo" or especie == "Pato" or especie == "Pavo") and math.random() < 0.5
	local medio = (def.peso[1] + def.peso[2]) / 2
	local peso = def.peso[1] + (def.peso[2] - def.peso[1]) * math.random() ^ 1.3
	if macho and especie == "Ciervo" then
		peso = math.min(def.peso[2], peso * 1.2)
	end
	local escala = (peso / medio) ^ (1 / 3)
	local modelo, altura = Modelos.animal(especie, { escala = escala, macho = macho, variante = math.random(1, 2) })
	local vida = math.floor(def.vida * escala ^ 2 + 0.5)
	modelo:SetAttribute("Nombre", def.nombre)
	modelo:SetAttribute("Peso", math.floor(peso * 10 + 0.5) / 10)
	modelo:SetAttribute("Macho", macho)
	modelo:SetAttribute("Vida", vida)
	modelo:SetAttribute("VidaMax", vida)
	modelo:SetAttribute("Mov", "quieto")
	modelo:SetAttribute("Vel", 0)
	local raiz = modelo.PrimaryPart
	local yaw = math.random() * math.pi * 2
	modelo.Parent = carpeta
	raiz.CFrame = CFrame.new(punto.X, punto.Y + altura, punto.Z) * CFrame.Angles(0, yaw, 0)
	-- Gotas de sangre (solo cuando está herido)
	local gotas = Instance.new("ParticleEmitter")
	gotas.Name = "Sangre"
	gotas.Color = ColorSequence.new(Color3.fromRGB(110, 10, 8))
	gotas.Size = NumberSequence.new(0.08 * escala)
	gotas.Lifetime = NumberRange.new(0.6, 1)
	gotas.Speed = NumberRange.new(0.5, 1.5)
	gotas.Acceleration = Vector3.new(0, -30, 0)
	gotas.Rate = 8
	gotas.Enabled = false
	gotas.Parent = raiz
	CollectionService:AddTag(modelo, "Animal")
	local a = {
		especie = especie, def = def, modelo = modelo, raiz = raiz, altura = altura, escala = escala, peso = peso,
		vida = vida, vidaMax = vida, macho = macho, casa = casa or punto, pos = punto, yaw = yaw,
		hasta = 0, pausa = ahora() + math.random() * 4, secuencia = 0, sangrado = 0, sangradoHasta = 0, manchaEn = 0,
		asustadoHasta = 0, agresivoHasta = 0, ultimoAtaque = 0, golpes = 0, danoPiel = 0,
		nada = def.donde == "agua", playa = def.donde == "playa",
	}
	table.insert(lista, a)
	porModelo[modelo] = a
	return a
end

local function aparecerGrupo(especie, lejosDe)
	local def = Config.Animales[especie]
	local centro = buscarSitio(def.donde, lejosDe)
	if not centro then
		return 0
	end
	local n = 0
	for i = 1, def.grupo or 1 do
		local p = centro
		if i > 1 then
			for _ = 1, 12 do
				local x, z = centro.X + math.random(-10, 10), centro.Z + math.random(-10, 10)
				local y = apto(def.donde, x, z)
				if y then
					p = Vector3.new(x, y, z)
					break
				end
			end
		end
		crear(especie, p, centro)
		n = n + 1
	end
	return n
end

-- =====================================================================
--  Movimiento: gira hacia el destino y anda o corre en línea recta (Tween de la raíz)
-- =====================================================================
local function poner(a, mov, vel)
	if a.modelo:GetAttribute("Mov") ~= mov then
		a.modelo:SetAttribute("Mov", mov)
	end
	a.modelo:SetAttribute("Vel", vel or 0)
end

local function moverA(a, x, z, velocidad, mov)
	local y, mat = suelo(x, z)
	if not y then
		return false
	end
	if a.nada then
		if mat ~= AGUA then
			return false
		end
	elseif mat == AGUA or (a.playa and mat ~= Enum.Material.Sand) then
		return false
	end
	if enZona(x, z, 12) or math.abs(x) > LIMITE + 40 or math.abs(z) > LIMITE + 40 then
		return false
	end
	local dx, dz = x - a.pos.X, z - a.pos.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.3 then
		return false
	end
	if not a.nada and math.abs(y - a.pos.Y) > d * 1.1 + 1 then
		return false -- demasiado empinado
	end
	local yaw = math.atan2(-dx, -dz)
	local pitch = a.nada and 0 or math.atan2(y - a.pos.Y, d) * 0.6
	local destino = CFrame.new(x, y + a.altura, z) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local giro = math.abs(((yaw - a.yaw + math.pi) % (2 * math.pi)) - math.pi)
	a.secuencia = a.secuencia + 1
	local sec = a.secuencia
	if a.tween then
		a.tween:Cancel()
	end
	local t = d / velocidad
	local function andar()
		if sec ~= a.secuencia or a.muerto then
			return
		end
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = destino })
		a.tween:Play()
	end
	local tGiro = 0
	if giro > math.rad(35) and mov ~= "correr" then
		-- Primero se gira en el sitio (como un animal de verdad) y luego echa a andar
		tGiro = math.min(0.8, giro / math.rad(160))
		local actual = a.raiz.CFrame
		local girado = CFrame.new(actual.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(tGiro, Enum.EasingStyle.Sine), { CFrame = girado })
		a.tween.Completed:Connect(andar)
		a.tween:Play()
	else
		andar()
	end
	a.yaw = yaw
	a.pos = Vector3.new(x, y, z)
	a.hasta = ahora() + tGiro + t
	poner(a, mov, velocidad)
	return true
end

-- Intenta moverse en una dirección (radianes) probando a girar un poco si no se puede
local function irHacia(a, angulo, distancia, velocidad, mov)
	for i = 0, 7 do
		local desvio = ((i % 2 == 0) and 1 or -1) * math.ceil(i / 2) * math.rad(28)
		local ang = angulo + desvio
		if moverA(a, a.pos.X + math.cos(ang) * distancia, a.pos.Z + math.sin(ang) * distancia, velocidad, mov) then
			return true
		end
	end
	return false
end

-- =====================================================================
--  Detección: distancia, agachado o corriendo, y el viento (olfato)
-- =====================================================================
local function factorDeteccion(a, jugador, hrp)
	local f = 1
	if jugador:GetAttribute("Agachado") then
		f = f * Config.Deteccion.Agachado
	elseif hrp.AssemblyLinearVelocity.Magnitude > 18 then
		f = f * Config.Deteccion.Corriendo
	end
	local viento = workspace.GlobalWind
	local horiz = Vector3.new(viento.X, 0, viento.Z)
	if horiz.Magnitude > 2 then
		local haciaAnimal = Vector3.new(a.pos.X - hrp.Position.X, 0, a.pos.Z - hrp.Position.Z)
		if haciaAnimal.Magnitude > 0.1 then
			local d = horiz.Unit:Dot(haciaAnimal.Unit)
			if d > 0.5 then
				f = f * Config.Deteccion.VientoAFavor
			elseif d < -0.5 then
				f = f * Config.Deteccion.VientoEnContra
			end
		end
	end
	return f
end

local function masCercano(a)
	local mejor, dist, factor = nil, math.huge, 1
	for _, jugador in ipairs(Players:GetPlayers()) do
		local char = jugador.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - a.raiz.Position).Magnitude
			if d < dist then
				mejor, dist, factor = jugador, d, factorDeteccion(a, jugador, hrp)
			end
		end
	end
	return mejor, dist, factor
end

-- =====================================================================
--  Muerte y despiece
-- =====================================================================
local despellejar

local function morir(a, jugador)
	if a.muerto then
		return
	end
	a.muerto = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	a.vida = 0
	a.modelo:SetAttribute("Vida", 0)
	poner(a, "muerto", 0)
	a.raiz.Sangre.Enabled = false
	-- Cae de lado (el cangrejo panza arriba)
	local caida
	if a.especie == "Cangrejo" then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura, a.pos.Z) * CFrame.Angles(0, a.yaw, math.pi)
	elseif a.nada then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.6, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(80))
	else
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.42, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(88))
	end
	TweenService:Create(a.raiz, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = caida }):Play()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Despellejar"
	prompt.ActionText = (a.especie == "Cangrejo" or a.especie == "Pato" or a.especie == "Pavo") and "Recoger" or "Despellejar"
	prompt.ObjectText = string.format("%s · %s kg", a.def.nombre, (string.format("%.1f", a.peso):gsub("%.", ",")))
	prompt.HoldDuration = math.clamp(a.peso / 45, 0.8, 4)
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = a.raiz
	prompt.Triggered:Connect(function(quien)
		despellejar(a, quien)
	end)
	a.desaparece = ahora() + 300
	if ctx.alMatar then
		ctx.alMatar(jugador, a)
	end
end

local function quitar(a)
	a.quitado = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	porModelo[a.modelo] = nil
	a.modelo:Destroy()
	for i, b in ipairs(lista) do
		if b == a then
			table.remove(lista, i)
			break
		end
	end
	-- Sale otro de la misma especie más adelante, lejos de los jugadores
	task.delay(a.def.reaparicion, function()
		local lejos = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(lejos, hrp.Position)
			end
		end
		local punto = buscarSitio(a.def.donde, lejos)
		if punto then
			crear(a.especie, punto, punto)
		end
	end)
end

function despellejar(a, jugador)
	if a.quitado or not a.muerto then
		return
	end
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - a.raiz.Position).Magnitude > 14 then
		return
	end
	local def = a.def
	local botin = {}
	-- Carne según el peso (los disparos y las explosiones estropean parte)
	if def.carne and def.rendimiento > 0 then
		local perdida = math.min(0.6, math.max(0, a.golpes - 1) * 0.05 + (a.explosion and 0.4 or 0))
		local kg = math.floor(a.peso * def.rendimiento * (1 - perdida) * 10 + 0.5) / 10
		if kg > 0 then
			local obj = Config.Objetos[def.carne]
			table.insert(botin, { id = def.carne, nombre = obj.nombre, cantidad = kg, unidad = "kg", valor = math.floor(kg * obj.porKg + 0.5) })
		end
	end
	-- Piel y trofeos: valen más cuanto más grande es el animal y menos daño tiene la piel
	local calidad, mult = "Buena", 1
	for _, c in ipairs(Config.CalidadPiel) do
		if a.danoPiel <= c[1] then
			calidad, mult = c[2], c[3]
			break
		end
	end
	local extra = {}
	for id, n in pairs(def.botin or {}) do
		extra[id] = n
	end
	if a.macho and def.macho then
		for id, n in pairs(def.macho) do
			extra[id] = n
		end
	end
	for id, n in pairs(extra) do
		local obj = Config.Objetos[id]
		local esPiel = string.sub(id, 1, 4) == "Piel"
		local m = esPiel and mult or 1
		local tam = (id == "Cornamenta") and a.escala ^ 3 or a.escala ^ 2
		if m > 0 then
			table.insert(botin, {
				id = id, nombre = obj.nombre, cantidad = n, unidad = "", calidad = esPiel and calidad or nil,
				valor = math.floor(obj.precio * n * m * tam + 0.5),
			})
		end
	end
	if ctx.darBotin then
		ctx.darBotin(jugador, botin, a)
	end
	quitar(a)
end

-- =====================================================================
--  Daño (lo llaman las armas)
-- =====================================================================
-- Devuelve el animal al que pertenece una pieza (o nil)
function Animales.de(parte)
	local m = parte
	while m and m ~= carpeta do
		if porModelo[m] then
			return porModelo[m]
		end
		m = m.Parent
	end
	return nil
end

-- dano ya multiplicado o no según "zona"; arma: datos de CazaConfig.Armas; desde: posición del atacante
function Animales.danar(a, dano, zona, jugador, arma, desde, explosion)
	if not a or a.muerto then
		return nil
	end
	local mult = Config.Zonas[zona] or 1
	local total = dano * mult
	a.vida = a.vida - total
	a.golpes = a.golpes + 1
	a.danoPiel = a.danoPiel + (arma.piel or 0.2) * ((zona == "Cabeza" or zona == "Cuello") and 0.3 or 1) + ((a.golpes > 1) and 0.1 or 0)
	if explosion then
		a.explosion = true
	end
	a.ultimoAtacante = jugador
	a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
	if (arma.sangrado or 0) > 0 and zona ~= "Cola" then
		a.sangrado = math.max(a.sangrado, total * arma.sangrado * 0.06)
		a.sangradoHasta = ahora() + 14
		a.raiz.Sangre.Enabled = true
	end
	a.asustadoHasta = ahora() + 12
	a.amenaza = desde
	if a.def.tipo ~= "presa" then
		a.agresivoHasta = ahora() + 25
		a.objetivo = jugador
	end
	if a.vida <= 0 then
		morir(a, jugador)
		return "muerto", total
	end
	a.hasta = 0 -- reacciona ya
	return "herido", total
end

-- Animales a menos de "radio" studs de un punto (para explosiones y fuego)
function Animales.cerca(pos, radio)
	local out = {}
	for _, a in ipairs(lista) do
		if not a.muerto and (a.raiz.Position - pos).Magnitude < radio then
			table.insert(out, a)
		end
	end
	return out
end

-- Un ruido (disparo, explosión): las presas que lo oyen huyen de él
function Animales.ruido(pos, radio)
	if radio <= 0 then
		return
	end
	for _, a in ipairs(lista) do
		if not a.muerto and a.def.tipo ~= "depredador" and (a.raiz.Position - pos).Magnitude < radio then
			a.asustadoHasta = ahora() + 8
			a.amenaza = pos
			a.hasta = 0
			sonido(a)
		end
	end
end

-- =====================================================================
--  Cerebro de cada animal
-- =====================================================================
local function huir(a, desde)
	local ang
	if desde then
		ang = math.atan2(a.pos.Z - desde.Z, a.pos.X - desde.X) + math.rad(math.random(-30, 30))
	else
		ang = math.random() * math.pi * 2
	end
	local v = a.def.correr * M * (a.vida < a.vidaMax * 0.5 and 0.8 or 1)
	irHacia(a, ang, v * 1.1, v, "correr")
end

local function pasear(a)
	local dCasa = Vector3.new(a.casa.X - a.pos.X, 0, a.casa.Z - a.pos.Z)
	local ang
	if dCasa.Magnitude > 25 * M then
		ang = math.atan2(dCasa.Z, dCasa.X) + math.rad(math.random(-40, 40))
	else
		ang = math.random() * math.pi * 2
	end
	local dist = math.random(4, 18) * M * (a.nada and 1.5 or 1) * math.max(0.3, a.escala)
	if irHacia(a, ang, dist, a.def.andar * M, "andar") then
		a.pausa = a.hasta + math.random(1, 4)
	end
end

local function atacar(a, jugador, dist)
	local char = jugador.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		a.objetivo = nil
		return
	end
	local alcance = (1.1 + a.escala * 0.9) * M * (a.especie == "Oso" and 1.25 or 1)
	if dist <= alcance then
		if ahora() - a.ultimoAtaque >= a.def.espera then
			a.ultimoAtaque = ahora()
			-- Mira a la presa y muerde o zarpea
			local d = hrp.Position - a.raiz.Position
			a.yaw = math.atan2(-d.X, -d.Z)
			a.raiz.CFrame = CFrame.new(a.raiz.Position) * CFrame.Angles(0, a.yaw, 0)
			poner(a, "atacar", 0)
			hum:TakeDamage(a.def.dano)
			sonido(a)
			if ctx.alAtacar then
				ctx.alAtacar(jugador, a)
			end
		end
		return
	end
	local v = a.def.correr * M * 0.9
	local dir = Vector3.new(hrp.Position.X - a.pos.X, 0, hrp.Position.Z - a.pos.Z)
	local paso = math.min(dist - alcance * 0.6, v * 0.5)
	if paso > 0.5 then
		local u = dir.Unit
		if not moverA(a, a.pos.X + u.X * paso, a.pos.Z + u.Z * paso, v, "correr") then
			irHacia(a, math.atan2(dir.Z, dir.X), paso, v, "correr")
		end
	end
end

local function pensar(a, dt)
	local t = ahora()
	if a.muerto then
		if a.desaparece and t > a.desaparece and not a.quitado then
			quitar(a)
		end
		return
	end
	-- Desangrarse
	if a.sangrado > 0 then
		if t < a.sangradoHasta then
			a.vida = a.vida - a.sangrado * dt
			a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
			if t > a.manchaEn and not a.nada then
				a.manchaEn = t + 1.6
				local y = suelo(a.raiz.Position.X, a.raiz.Position.Z)
				if y and #rastros:GetChildren() < 500 then
					local m = Modelos.manchaSangre(CFrame.new(a.raiz.Position.X, y + 0.03, a.raiz.Position.Z), (0.35 + math.random() * 0.4) * a.escala)
					m.Parent = rastros
					Debris:AddItem(m, 240)
				end
			end
			if a.vida <= 0 then
				morir(a, a.ultimoAtacante)
				return
			end
		else
			a.sangrado = 0
			a.raiz.Sangre.Enabled = false
		end
	end
	local jugador, dist, factor = masCercano(a)
	if dist > Config.DistanciaActiva * M and t > a.asustadoHasta then
		if t >= a.hasta and a.modelo:GetAttribute("Mov") ~= "quieto" then
			poner(a, "quieto", 0)
		end
		return -- nadie cerca: el animal "duerme" para no gastar servidor
	end
	local def = a.def
	local hrp = jugador and jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local tipo = def.tipo
	if tipo ~= "presa" and a.vida < a.vidaMax * 0.25 then
		tipo = "presa" -- muy herido: huye
	end
	if tipo == "depredador" or tipo == "neutral" then
		local agresion = (def.agresion or 0) * M * factor
		if t < a.agresivoHasta and a.objetivo then
			local thrp = a.objetivo.Character and a.objetivo.Character:FindFirstChild("HumanoidRootPart")
			if thrp and (thrp.Position - a.raiz.Position).Magnitude < 160 * M then
				if t >= a.hasta - 0.05 then
					atacar(a, a.objetivo, (thrp.Position - a.raiz.Position).Magnitude)
				end
				return
			end
			a.objetivo = nil
		end
		if jugador and dist < agresion then
			if a.objetivo ~= jugador then
				sonido(a)
			end
			a.objetivo = jugador
			a.agresivoHasta = t + 12
			if t >= a.hasta - 0.05 then
				atacar(a, jugador, dist)
			end
			return
		end
	end
	if tipo == "presa" then
		local huida = (def.huida or 0) * M * factor
		if jugador and dist < huida then
			if t > a.asustadoHasta then
				sonido(a)
			end
			a.asustadoHasta = t + 6
			a.amenaza = hrp and hrp.Position or a.amenaza
		end
		if t < a.asustadoHasta then
			if t >= a.hasta - 0.1 then
				huir(a, a.amenaza)
			end
			return
		end
	end
	-- Tranquilo: pasta, descansa o pasea
	if t >= a.hasta and t >= a.pausa then
		local r = math.random()
		if r < 0.45 and not a.nada then
			poner(a, "pastar", 0)
			a.pausa = t + math.random(3, 9)
		elseif r < 0.6 then
			poner(a, "quieto", 0)
			a.pausa = t + math.random(2, 6)
		else
			pasear(a)
		end
	elseif t >= a.hasta and a.modelo:GetAttribute("Mov") == "andar" then
		poner(a, "quieto", 0)
	end
end

-- =====================================================================
--  Arranque
-- =====================================================================
function Animales.iniciar(contexto)
	ctx = contexto
	Config, Modelos, W = ctx.Config, ctx.Modelos, ctx.W
	M = Config.StudsPorMetro
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	carpeta = workspace:FindFirstChild("Animales") or Instance.new("Folder")
	carpeta.Name = "Animales"
	carpeta.Parent = workspace
	rastros = workspace:FindFirstChild("RastrosSangre") or Instance.new("Folder")
	rastros.Name = "RastrosSangre"
	rastros.Parent = workspace
	local total = 0
	local especies = {}
	for especie in pairs(Config.Animales) do
		table.insert(especies, especie)
	end
	table.sort(especies)
	for _, especie in ipairs(especies) do
		local def = Config.Animales[especie]
		local hechos = 0
		local intentos = 0
		while hechos < def.cantidad and intentos < def.cantidad * 2 do
			intentos = intentos + 1
			hechos = hechos + aparecerGrupo(especie)
		end
		total = total + hechos
		task.wait()
	end
	task.spawn(function()
		local antes = ahora()
		while true do
			task.wait(0.2)
			local t = ahora()
			local dt = t - antes
			antes = t
			for i = #lista, 1, -1 do
				local a = lista[i]
				if a then
					local ok, err = pcall(pensar, a, dt)
					if not ok then
						warn("[Caza] animal", a.especie, err)
					end
				end
			end
		end
	end)
	return total
end

function Animales.lista()
	return lista
end

return Animales
