--[[
	Armas (servidor). El servidor decide si un disparo acierta para que nadie pueda hacer trampas:
	  · Las balas, flechas y lanzables vuelan con su velocidad real y caen por la gravedad. Se simulan
	    paso a paso, así que una flecha tarda en llegar y un ciervo que corre puede esquivarla.
	  · El daño depende de dónde acierta (cabeza, cuello, pecho...) y de la distancia (las balas pierden fuerza).
	  · La dispersión aumenta al moverte y baja agachado o apuntando. Cada disparo hace ruido y espanta animales.
	  · Recarga real: gasta cartuchos de la mochila y tarda lo que tarda cada arma.
	  · La granada explota a los 3 segundos y el molotov incendia el suelo. Las dos hacen daño también a quien
	    las lanza si está cerca.
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Armas = {}
local Config, Animales, Economia, Efectos, Aviso, M
local ctx
local ultimo = {}
local siguienteId = 0
local efectos

local function ahora()
	return os.clock()
end

local function herramienta(jugador, id)
	local char = jugador.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Arma") == id then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")
		if hum and hum.Health > 0 and hrp and head then
			return tool, char, hrp, head
		end
	end
	return nil
end

local function puede(jugador, id, cadencia)
	ultimo[jugador] = ultimo[jugador] or {}
	if ahora() - (ultimo[jugador][id] or -math.huge) < cadencia * 0.85 then
		return false
	end
	ultimo[jugador][id] = ahora()
	return true
end

local function parametros(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local excluir = { char, efectos }
	for _, n in ipairs({ "RastrosSangre", "Corchos" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	p.FilterDescendantsInstances = excluir
	p.IgnoreWater = false
	return p
end

-- Desvía una dirección un ángulo al azar dentro de un cono
local function desviar(dir, grados)
	if grados <= 0 then
		return dir
	end
	local r = math.rad(grados) * math.sqrt(math.random())
	local giro = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.new(0, 0, 0), dir) * CFrame.Angles(0, 0, giro) * CFrame.Angles(r, 0, 0)).LookVector
end

local function jugadorDe(parte)
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo do
		local p = Players:GetPlayerFromCharacter(modelo)
		if p then
			return p, modelo
		end
		modelo = modelo.Parent and modelo.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Aplica un impacto. Devuelve qué ha tocado ("animal", "jugador", "agua", "suelo") y el resultado
local function impacto(jugador, cfg, res, distancia, desde)
	local parte = res.Instance
	local caida = 1
	if cfg.tipo == "bala" and cfg.alcance then
		caida = math.clamp(1 - (distancia / (cfg.alcance * M)) ^ 2 * 0.5, 0.5, 1)
	end
	local a = Animales.de(parte)
	if a then
		local zona = parte:GetAttribute("Zona") or "Cuerpo"
		local estado = Animales.danar(a, cfg.dano * caida, zona, jugador, cfg, desde)
		return "animal", estado, zona
	end
	local otro, modelo = jugadorDe(parte)
	if otro and otro ~= jugador and Config.DanoEntreJugadores then
		local hum = modelo:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:TakeDamage(cfg.dano * caida * ((parte.Name == "Head") and 2 or 1))
			return "jugador", (hum.Health <= 0) and "muerto" or "herido", (parte.Name == "Head") and "Cabeza" or "Cuerpo"
		end
	end
	if res.Material == Enum.Material.Water then
		return "agua"
	end
	return "suelo"
end

-- Simula un proyectil (bala, flecha o lanzable) paso a paso con gravedad
-- "origen" es desde donde vuela de verdad; "visual" desde donde lo dibujan los clientes (la boca del arma)
local function simular(jugador, char, id, alcance, origen, velocidad, alImpactar, visual)
	siguienteId = siguienteId + 1
	local pid = siguienteId
	local g = Vector3.new(0, -Config.Gravedad * M, 0)
	local params = parametros(char)
	Efectos:FireAllClients("disparo", { id = pid, arma = id, desde = visual or origen, v = velocidad, g = g.Y, jugador = jugador.UserId })
	task.spawn(function()
		local p, v = origen, velocidad
		local recorrido, t = 0, 0
		while recorrido < alcance and t < 15 do
			local dt = math.min(RunService.Heartbeat:Wait(), 0.05)
			local nueva = p + v * dt + g * (0.5 * dt * dt)
			local paso = nueva - p
			local res = workspace:Raycast(p, paso, params)
			if res then
				alImpactar(res, recorrido + (res.Position - p).Magnitude, pid, v)
				return
			end
			recorrido = recorrido + paso.Magnitude
			v = v + g * dt
			p = nueva
			t = t + dt
		end
		Efectos:FireAllClients("fin", { id = pid, pos = p })
	end)
	return pid
end

-- =====================================================================
--  Disparar (armas de fuego, arco y ballesta)
-- =====================================================================
function Armas.disparar(jugador, id, apunta, apuntando)
	local cfg = Config.Armas[id]
	if not cfg or (cfg.tipo ~= "bala" and cfg.tipo ~= "proyectil") or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga <= 0 then
		Aviso:FireClient(jugador, "vacio", { arma = id })
		return
	end
	if not puede(jugador, id, cfg.cadencia) then
		return
	end
	tool:SetAttribute("Cargador", carga - 1)
	-- La bala sale desde la cabeza (donde está la vista del jugador) para que acierte donde apunta incluso
	-- a bocajarro; los clientes la dibujan saliendo de la boca del arma
	local origen = head.Position
	local boca = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Boca")
	local visual = boca and boca.WorldPosition or origen
	if (visual - origen).Magnitude > 10 then
		visual = origen
	end
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local disp = cfg.dispersion or 0
	if hrp.AssemblyLinearVelocity.Magnitude > 3 then
		disp = disp * 2
	end
	if jugador:GetAttribute("Agachado") then
		disp = disp * 0.6
	end
	if apuntando == true then
		disp = disp * 0.5
	end
	for _ = 1, cfg.perdigones or 1 do
		simular(jugador, char, id, cfg.alcance * M, origen, desviar(dir, disp) * (cfg.velocidad * M), function(res, distancia, pid)
			local tipo, estado, zona = impacto(jugador, cfg, res, distancia, origen)
			Efectos:FireAllClients("impacto", {
				id = pid, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id,
				parte = (cfg.tipo == "proyectil" and tipo == "animal") and res.Instance or nil,
			})
			if estado then
				Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
			end
		end, visual)
	end
	Animales.ruido(origen, (cfg.ruido or 0) * M)
	-- El arco y la ballesta se cargan solos si quedan flechas
	if cfg.tipo == "proyectil" then
		task.delay(0.15, function()
			Armas.recargar(jugador, id)
		end)
	end
end

-- =====================================================================
--  Recargar
-- =====================================================================
function Armas.recargar(jugador, id)
	local cfg = Config.Armas[id]
	if not cfg or not cfg.cargador then
		return
	end
	local tool = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga >= cfg.cargador then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		Aviso:FireClient(jugador, "sinMunicion", { arma = id, municion = cfg.municion })
		return
	end
	tool:SetAttribute("Recargando", true)
	Efectos:FireAllClients("recarga", { jugador = jugador.UserId, arma = id, tiempo = cfg.recarga })
	task.delay(cfg.recarga, function()
		tool:SetAttribute("Recargando", false)
		-- Si guardas el arma a medio recargar, la recarga se pierde
		if tool.Parent ~= jugador.Character then
			return
		end
		local actual = tool:GetAttribute("Cargador") or 0
		local n = math.min(cfg.cargador - actual, Economia.municion(jugador, cfg.municion))
		if n > 0 then
			Economia.gastar(jugador, cfg.municion, n)
			tool:SetAttribute("Cargador", actual + n)
		end
	end)
end

-- =====================================================================
--  Cuerpo a cuerpo
-- =====================================================================
local function balancear(tool)
	-- Golpe visible para todos: el arma sube y baja de golpe
	tool.Grip = CFrame.Angles(math.rad(-55), 0, 0)
	task.delay(0.12, function()
		tool.Grip = CFrame.Angles(math.rad(65), 0, 0)
		task.delay(0.16, function()
			tool.Grip = CFrame.new()
		end)
	end)
end

function Armas.golpear(jugador, id, mirada)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "cuerpo" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	local dir = hrp.CFrame.LookVector
	if typeof(mirada) == "Vector3" and mirada.Magnitude > 0.1 then
		local u = mirada.Unit
		dir = Vector3.new(u.X, math.clamp(u.Y, -0.7, 0.7), u.Z).Unit
	end
	balancear(tool)
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	local res = workspace:Spherecast(head.Position, 1.1, dir * (cfg.alcance * M + 1), parametros(char))
	if res then
		local tipo, estado, zona = impacto(jugador, cfg, res, 0, head.Position)
		Efectos:FireAllClients("impacto", { id = 0, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id })
		if estado then
			Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
		end
	end
	Animales.ruido(head.Position, 5 * M)
end

-- =====================================================================
--  Lanzables: granada y molotov
-- =====================================================================
local function danarPersonas(jugador, pos, radio, dano)
	for _, p in ipairs(Players:GetPlayers()) do
		if p == jugador or Config.DanoEntreJugadores then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local d = (hrp.Position - pos).Magnitude
				if d < radio then
					hum:TakeDamage(dano * (1 - d / radio))
				end
			end
		end
	end
end

local function explosion(jugador, cfg, pos)
	local R = cfg.radio * M
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = R
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = workspace
	Efectos:FireAllClients("explosion", { pos = pos, radio = R })
	for _, a in ipairs(Animales.cerca(pos, R * 1.4)) do
		local d = (a.raiz.Position - pos).Magnitude
		Animales.danar(a, cfg.dano * math.max(0, 1 - d / (R * 1.4)) ^ 1.2, "Cuerpo", jugador, cfg, pos, true)
	end
	danarPersonas(jugador, pos, R * 1.4, cfg.dano * 0.8)
	Animales.ruido(pos, cfg.ruido * M)
end

local function incendio(jugador, cfg, pos)
	local R = cfg.radio * M
	-- Llamas: una grande en el centro y cinco más pequeñas alrededor
	local function llama(posicion, tam)
		local p = Instance.new("Part")
		p.Name = "Incendio"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 0.4, 1)
		p.Position = posicion
		p.Parent = efectos
		local f = Instance.new("Fire")
		f.Size = tam
		f.Heat = 12
		f.Color = Color3.fromRGB(255, 140, 50)
		f.SecondaryColor = Color3.fromRGB(255, 60, 15)
		f.Parent = p
		Debris:AddItem(p, cfg.duracion)
		return p
	end
	local base = llama(pos, 9)
	for i = 1, 5 do
		local ang = i / 5 * math.pi * 2
		llama(pos + Vector3.new(math.cos(ang) * R * 0.6, 0, math.sin(ang) * R * 0.6), 5)
	end
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(40, 36, 34)
	humo.Opacity = 0.3
	humo.RiseVelocity = 7
	humo.Size = 8
	humo.Parent = base
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 140, 60)
	luz.Brightness = 3
	luz.Range = R * 3
	luz:SetAttribute("Base", 3)
	luz.Parent = base
	CollectionService:AddTag(luz, "LuzFuego")
	Efectos:FireAllClients("explosion", { pos = pos, radio = R, fuego = true })
	Animales.ruido(pos, cfg.ruido * M)
	task.spawn(function()
		local fin = ahora() + cfg.duracion
		while ahora() < fin do
			task.wait(0.5)
			for _, a in ipairs(Animales.cerca(pos, R)) do
				Animales.danar(a, cfg.dano, "Cuerpo", jugador, cfg, pos, true)
			end
			danarPersonas(jugador, pos, R, cfg.dano * 0.6)
		end
	end)
end

function Armas.lanzar(jugador, id, apunta)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "lanzable" or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		return
	end
	Economia.gastar(jugador, cfg.municion, 1)
	local origen = head.Position + hrp.CFrame.LookVector * 1.5 + Vector3.new(0, 0.4, 0)
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		dir = hrp.CFrame.LookVector
	end
	-- Se lanza en parábola: un poco hacia arriba y más fuerte cuanto más lejos apuntas (hasta su máximo)
	local distancia = math.min(dir.Magnitude, 40 * M)
	dir = (dir.Unit + Vector3.new(0, 0.3, 0)).Unit
	local fuerza = math.clamp(math.sqrt(distancia * Config.Gravedad * M), 8 * M, cfg.velocidad * M)
	local lanzado = ahora()
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	simular(jugador, char, id, 200 * M, origen, dir * fuerza, function(res, _, pid)
		Efectos:FireAllClients("impacto", { id = pid, pos = res.Position, normal = res.Normal, tipo = "lanzable", arma = id })
		if id == "Molotov" then
			incendio(jugador, cfg, res.Position)
		else
			local espera = math.max(0, (cfg.espoleta or 0) - (ahora() - lanzado))
			task.delay(espera, function()
				explosion(jugador, cfg, res.Position + res.Normal * 0.4)
			end)
		end
	end)
	if Economia.municion(jugador, cfg.municion) <= 0 then
		tool:Destroy()
	end
end

function Armas.iniciar(contexto)
	ctx = contexto
	Config, Animales, Economia = ctx.Config, ctx.Animales, ctx.Economia
	Efectos, Aviso = ctx.remotos.Efectos, ctx.remotos.Aviso
	M = Config.StudsPorMetro
	efectos = workspace:FindFirstChild("EfectosCaza") or Instance.new("Folder")
	efectos.Name = "EfectosCaza"
	efectos.Parent = workspace
	Players.PlayerRemoving:Connect(function(p)
		ultimo[p] = nil
	end)
end

return Armas
