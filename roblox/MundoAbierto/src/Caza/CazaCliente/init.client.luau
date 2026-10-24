--[[
	CazaCliente (va en StarterPlayer > StarterPlayerScripts, con sus módulos dentro).

	Controles:
	  Armas de fuego, arco y ballesta: clic para disparar (mantén pulsado con las automáticas),
	    clic derecho para apuntar (las de mira muestran la mira telescópica), R para recargar.
	    Con un arma a distancia la cámara se pone por encima del hombro y el ratón queda en el centro.
	  Cuerpo a cuerpo: clic para golpear. Molotov y granada: clic para lanzar donde apuntas.
	  C: agacharse (los animales te detectan mucho menos) · Mayús: correr (haces más ruido) · B: mochila.
	  Caña: clic para lanzar donde apuntas, clic otra vez para recoger. Cuando el corcho se hunde: clic
	    para clavar. Luego mantén pulsado para recoger sedal y suéltalo cuando la tensión esté en rojo.
	En móvil: toca para disparar o lanzar y usa los botones de la pantalla.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("CazaConfig"))
local remotos = ReplicatedStorage:WaitForChild("CazaRemotos")
local Accion = remotos:WaitForChild("Accion")
local PescaR = remotos:WaitForChild("Pesca")
local EfectosR = remotos:WaitForChild("Efectos")
local Aviso = remotos:WaitForChild("Aviso")
local Estado = remotos:WaitForChild("Estado")
local Tienda = remotos:WaitForChild("Tienda")
local Pantalla = require(script:WaitForChild("Pantalla"))
local Efectos = require(script:WaitForChild("Efectos"))

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local M = Config.StudsPorMetro
local FOV = 70
local VELOCIDAD = { normal = 16, agachado = 7, corriendo = 24 }
local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

Pantalla.crear(Config)
Efectos.iniciar(Config)

local e = {
	tool = nil, id = nil, cfg = nil, cana = nil, tirador = false, apuntando = false, disparando = false,
	agachado = false, corriendo = false, ultimo = 0, retroceso = 0, floracion = 0, datos = nil, conexiones = {},
}
local pesca = { fase = nil }

local function humanoide()
	local char = jugador.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

local function sonido(id, volumen)
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volumen or 0.8
		s.Parent = SoundService
		s:Play()
		game:GetService("Debris"):AddItem(s, 6)
	end
end

-- =====================================================================
--  Hacia dónde apuntas
-- =====================================================================
local paramsMira = RaycastParams.new()
paramsMira.FilterType = Enum.RaycastFilterType.Exclude
local function puntoApuntado()
	local excluir = { jugador.Character }
	for _, n in ipairs({ "EfectosLocales", "EfectosCaza", "Corchos", "RastrosSangre" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	paramsMira.FilterDescendantsInstances = excluir
	local pantalla
	if e.tirador or esMovil then
		pantalla = camara.ViewportSize / 2
	else
		pantalla = UserInputService:GetMouseLocation()
	end
	local rayo = camara:ViewportPointToRay(pantalla.X, pantalla.Y)
	local res = workspace:Raycast(rayo.Origin, rayo.Direction * 3000, paramsMira)
	return res and res.Position or (rayo.Origin + rayo.Direction * 3000)
end

-- =====================================================================
--  Movimiento: agacharse y correr
-- =====================================================================
local function aplicarVelocidad()
	local hum = humanoide()
	if not hum then
		return
	end
	if e.agachado then
		hum.WalkSpeed = VELOCIDAD.agachado
	elseif e.corriendo and not e.apuntando then
		hum.WalkSpeed = VELOCIDAD.corriendo
	else
		hum.WalkSpeed = VELOCIDAD.normal
	end
	local hombro = e.tirador and Vector3.new(1.6, 0.4, 0) or Vector3.new()
	hum.CameraOffset = hombro + (e.agachado and Vector3.new(0, -1.3, 0) or Vector3.new())
end

local function agacharse(valor)
	if valor == nil then
		valor = not e.agachado
	end
	e.agachado = valor
	Accion:FireServer("agachado", valor)
	aplicarVelocidad()
	Pantalla.aviso(valor and "Agachado: te detectan mucho menos" or "De pie", Color3.fromRGB(190, 190, 180), 1.5)
end

-- =====================================================================
--  Armas
-- =====================================================================
local function reserva()
	local cfg = e.cfg
	return (cfg and cfg.municion) and (jugador:GetAttribute("Municion_" .. cfg.municion) or 0) or 0
end

local function refrescarArma()
	if not e.tool then
		Pantalla.arma(nil)
		return
	end
	if e.cana then
		Pantalla.arma(e.cana.nombre, string.format("%d m", e.cana.distancia), "Clic: lanzar · clic otra vez: recoger")
		return
	end
	local cfg = e.cfg
	if cfg.tipo == "cuerpo" then
		Pantalla.arma(cfg.nombre, "", "Clic: golpear · C: agacharse")
	elseif cfg.tipo == "lanzable" then
		Pantalla.arma(cfg.nombre, "x" .. reserva(), "Clic: lanzar donde apuntas")
	else
		local linea
		if e.tool:GetAttribute("Recargando") then
			linea = "Recargando…"
		else
			linea = string.format("%d / %d", e.tool:GetAttribute("Cargador") or 0, reserva())
		end
		Pantalla.arma(cfg.nombre, linea, esMovil and "Toca: disparar" or "Clic: disparar · clic der.: apuntar · R: recargar")
	end
end

local function disparar()
	local cfg = e.cfg
	if not cfg or not e.tool then
		return
	end
	local t = os.clock()
	if t - e.ultimo < cfg.cadencia then
		return
	end
	if cfg.tipo == "cuerpo" then
		e.ultimo = t
		Accion:FireServer("golpear", e.id, camara.CFrame.LookVector)
		return
	end
	if cfg.tipo == "lanzable" then
		e.ultimo = t
		Accion:FireServer("lanzar", e.id, puntoApuntado())
		return
	end
	if e.tool:GetAttribute("Recargando") then
		return
	end
	if (e.tool:GetAttribute("Cargador") or 0) <= 0 then
		e.ultimo = t
		sonido(Config.Sonidos.Vacio, 0.6)
		if reserva() > 0 then
			Accion:FireServer("recargar", e.id)
		else
			Pantalla.aviso("Sin munición: compra " .. Config.Municion[cfg.municion].nombre:lower() .. " en una tienda de caza", Color3.fromRGB(230, 120, 100), 3)
		end
		return
	end
	e.ultimo = t
	Accion:FireServer("disparar", e.id, puntoApuntado(), e.apuntando)
	e.retroceso = e.retroceso + (cfg.retroceso or 0)
	e.floracion = math.min(e.floracion + (cfg.dispersion or 0) * 1.2, 8)
end

local function recargar()
	if e.cfg and e.cfg.cargador and e.tool and not e.tool:GetAttribute("Recargando") then
		Accion:FireServer("recargar", e.id)
	end
end

local function apuntar(valor)
	if not e.cfg or e.cfg.tipo == "cuerpo" then
		valor = false
	end
	e.apuntando = valor
	aplicarVelocidad()
end

-- =====================================================================
--  Pesca
-- =====================================================================
local pelea
local tocando = false

local function terminarPesca(texto, color)
	pesca.fase = nil
	pelea = nil
	Pantalla.pesca(false)
	if texto then
		Pantalla.aviso(texto, color, 4)
	end
end

local function clicCana()
	if pesca.fase == nil then
		pesca.fase = "lanzando"
		Pantalla.pesca(true, "Lanzando…", "")
		Pantalla.tension(nil)
		PescaR:FireServer("lanzar", puntoApuntado())
	elseif pesca.fase == "esperando" then
		PescaR:FireServer("recoger")
		terminarPesca()
	elseif pesca.fase == "picando" then
		pesca.fase = "clavando"
		PescaR:FireServer("clavar")
	end
end

-- Pelea con el pez: el pez tira en arrancadas y se cansa. Recoges manteniendo pulsado; con mucha tensión
-- el sedal se rompe y si sueltas demasiado sedal el pez se escapa.
local function empezarPelea(d)
	pesca.fase = "luchando"
	pelea = {
		dist = d.distancia, inicial = d.distancia, tension = 0.15, aguante = 1, tirando = false, siguiente = os.clock() + 0.6,
		fin = 0, d = d, t0 = os.clock(),
	}
	Pantalla.pesca(true, d.grande and "¡Algo grande ha picado!" or "¡Clavado!", "")
	Pantalla.tension(0.15)
end

local function actualizarPelea(dt)
	local p = pelea
	local d = p.d
	local t = os.clock()
	local pulsado = tocando or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	-- Arrancadas del pez (más largas y seguidas cuanto más fuerte y fresco está)
	if d.basura then
		p.tirando = false
	elseif not p.tirando and t >= p.siguiente then
		p.tirando = true
		p.fin = t + (0.6 + 1.8 * d.fuerza * p.aguante) * (0.6 + math.random() * 0.8)
	elseif p.tirando and t >= p.fin then
		p.tirando = false
		p.siguiente = t + (1 + 2.2 * (1 - d.fuerza)) * (0.6 + math.random() * 0.8)
	end
	local potencia = (0.25 + d.fuerza * 0.75) * math.min(1.6, d.ratio * 0.9 + 0.35) * (0.35 + 0.65 * p.aguante)
	if d.basura then
		potencia = 0.06
	end
	if pulsado then
		p.dist = p.dist - d.recogida * dt * (p.tirando and 0.25 or 1)
		p.tension = p.tension + (p.tirando and potencia * 1.1 or (0.12 + potencia * 0.2)) * dt
		if p.tirando then
			p.aguante = math.max(0, p.aguante - dt * 0.07 * (1.25 - d.aguante))
		end
	else
		p.tension = p.tension - 0.5 * dt
		if p.tirando then
			p.dist = p.dist + d.recogida * potencia * 0.9 * dt
		end
	end
	p.tension = math.clamp(p.tension, 0, 1.05)
	local aviso = p.tirando and "¡Tira fuerte! Suelta si la tensión sube" or (pulsado and "Recogiendo…" or "Mantén pulsado para recoger")
	Pantalla.tension(p.tension, string.format("Sedal: %d m · %s", math.max(0, math.floor(p.dist / M + 0.5)), pulsado and "carrete girando" or "carrete suelto"), aviso)
	-- (la fase se cambia antes de avisar al servidor, por si la respuesta llega enseguida)
	if p.tension >= 1 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "sedal")
	elseif p.dist > p.inicial + 15 * M then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "escapado")
	elseif p.dist <= 2 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", true)
	end
end

PescaR.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "esperando" then
		pesca.fase = "esperando"
		local aguas = { rio = "río", lago = "lago", mar = "mar" }
		Pantalla.pesca(true, "Esperando a que piquen…", "Pescando en " .. (aguas[d.agua] or "agua") .. " · clic para recoger")
		Pantalla.tension(nil)
	elseif que == "sinAgua" then
		terminarPesca("Ahí no hay agua. Apunta a un río, un lago o el mar.", Color3.fromRGB(200, 200, 190))
	elseif que == "picada" then
		pesca.fase = "picando"
		Pantalla.pesca(true, "¡PICAN! Clic para clavar", "")
		sonido(Config.Sonidos.Picada, 0.9)
		Efectos.sacudir(0.25)
	elseif que == "pelea" then
		empezarPelea(d)
	elseif que == "capturado" then
		local pez = Config.Peces[d.id]
		local rareza, color = Config.rareza(pez)
		terminarPesca()
		sonido(Config.Sonidos.Captura, 0.9)
		Pantalla.aviso(string.format("%s · %s · %s (%s)%s", d.nombre, Pantalla.kg(d.peso), rareza, Pantalla.dineroTexto(d.valor), d.record and " · ¡RÉCORD!" or ""),
			Color3.fromRGB(color[1], color[2], color[3]), 6)
	elseif que == "escapado" then
		if d.motivo == "tarde" then
			pesca.fase = "esperando"
			Pantalla.pesca(true, "Esperando a que piquen…", "Se ha soltado: hay que clavar más rápido")
		else
			terminarPesca("El pez se ha escapado.", Color3.fromRGB(220, 200, 150))
		end
	elseif que == "sedalRoto" then
		sonido(Config.Sonidos.SedalRoto, 0.9)
		terminarPesca(d.motivo == "grande" and "¡Se ha roto el sedal! Ese pez es demasiado grande para esta caña." or "¡Se ha roto el sedal por la tensión!", Color3.fromRGB(230, 110, 90))
	elseif que == "recogido" then
		terminarPesca()
	end
end)

-- =====================================================================
--  Equipar y guardar herramientas
-- =====================================================================
local function desconectar()
	for _, c in ipairs(e.conexiones) do
		c:Disconnect()
	end
	e.conexiones = {}
end

local function alGuardar()
	desconectar()
	if pesca.fase then
		PescaR:FireServer("recoger")
		terminarPesca()
	end
	e.tool, e.id, e.cfg, e.cana = nil, nil, nil, nil
	e.tirador, e.disparando = false, false
	apuntar(false)
	local hum = humanoide()
	if hum then
		hum.AutoRotate = true
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	aplicarVelocidad()
	Pantalla.arma(nil)
	Pantalla.mira(false, 0)
	Pantalla.telescopica(false)
end

local function alEquipar(tool)
	alGuardar()
	local armaId, canaId = tool:GetAttribute("Arma"), tool:GetAttribute("Cana")
	if not armaId and not canaId then
		return
	end
	e.tool = tool
	if canaId then
		e.id, e.cana = canaId, Config.Canas[canaId]
		table.insert(e.conexiones, tool.Activated:Connect(clicCana))
	else
		e.id, e.cfg = armaId, Config.Armas[armaId]
		e.tirador = e.cfg.tipo ~= "cuerpo"
		local hum = humanoide()
		if hum and e.tirador and not esMovil then
			hum.AutoRotate = false
		end
		table.insert(e.conexiones, tool.Activated:Connect(function()
			e.disparando = true
			disparar()
		end))
		table.insert(e.conexiones, tool.Deactivated:Connect(function()
			e.disparando = false
		end))
		for _, atributo in ipairs({ "Cargador", "Recargando" }) do
			table.insert(e.conexiones, tool:GetAttributeChangedSignal(atributo):Connect(refrescarArma))
		end
		if e.cfg.municion then
			table.insert(e.conexiones, jugador:GetAttributeChangedSignal("Municion_" .. e.cfg.municion):Connect(refrescarArma))
		end
	end
	aplicarVelocidad()
	refrescarArma()
end

local function conectarPersonaje(char)
	e.agachado, e.corriendo = false, false
	alGuardar()
	char.ChildAdded:Connect(function(h)
		if h:IsA("Tool") then
			alEquipar(h)
		end
	end)
	char.ChildRemoved:Connect(function(h)
		if h == e.tool then
			alGuardar()
		end
	end)
end
if jugador.Character then
	conectarPersonaje(jugador.Character)
end
jugador.CharacterAdded:Connect(conectarPersonaje)

-- =====================================================================
--  Teclas y botones
-- =====================================================================
UserInputService.InputBegan:Connect(function(input, procesado)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = true
	end
	if procesado then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(true)
	elseif input.KeyCode == Enum.KeyCode.R then
		recargar()
	elseif input.KeyCode == Enum.KeyCode.C then
		agacharse()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = true
		aplicarVelocidad()
	elseif input.KeyCode == Enum.KeyCode.B then
		Pantalla.alternarMochila()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = false
		aplicarVelocidad()
	end
end)

if esMovil then
	local botones
	botones = Pantalla.botonesMovil({
		{ "recargar", "Recargar", recargar },
		{ "apuntar", "Apuntar", function()
			apuntar(not e.apuntando)
			botones.apuntar.Text = e.apuntando and "Dejar" or "Apuntar"
		end },
		{ "agachar", "Agacharse", function()
			agacharse()
			botones.agachar.Text = e.agachado and "Levantarse" or "Agacharse"
		end },
		{ "mochila", "Mochila", Pantalla.alternarMochila },
	})
end

-- =====================================================================
--  Mensajes del servidor
-- =====================================================================
local ultimoAtaque = 0
Aviso.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "acierto" then
		Pantalla.acierto(d.estado == "muerto", d.zona == "Cabeza")
		if d.estado == "muerto" and d.zona == "Cabeza" then
			Pantalla.aviso("¡En la cabeza!", Color3.fromRGB(255, 220, 120), 2)
		end
	elseif que == "abatido" then
		Pantalla.aviso(string.format("Has abatido: %s (%s). Acércate y mantén E para despellejarlo.", d.nombre, Pantalla.kg(d.peso)), Color3.fromRGB(150, 220, 130), 6)
	elseif que == "botin" then
		local partes = {}
		for _, b in ipairs(d.botin or {}) do
			local cant = (b.unidad == "kg") and Pantalla.kg(b.cantidad) or ("x" .. b.cantidad)
			table.insert(partes, string.format("%s %s%s", b.nombre, cant, b.calidad and (" (" .. b.calidad .. ")") or ""))
		end
		Pantalla.aviso("Botín: " .. ((#partes > 0) and table.concat(partes, " · ") or "nada aprovechable"), Color3.fromRGB(236, 200, 110), 6)
	elseif que == "atacado" then
		Pantalla.herido()
		Efectos.sacudir(0.9)
		if os.clock() - ultimoAtaque > 3 then
			ultimoAtaque = os.clock()
			Pantalla.aviso("¡Te ataca un " .. d.nombre:lower() .. "!", Color3.fromRGB(240, 90, 80), 2.5)
		end
	elseif que == "vacio" then
		sonido(Config.Sonidos.Vacio, 0.6)
	elseif que == "sinMunicion" then
		local m = Config.Municion[d.municion]
		Pantalla.aviso("No te quedan " .. (m and m.nombre:lower() or "balas") .. ". Cómpralos en una tienda de caza.", Color3.fromRGB(230, 120, 100), 4)
	elseif que == "venta" then
		Pantalla.aviso(string.format("Has vendido %d cosas por %s", d.n, Pantalla.dineroTexto(d.total)), Color3.fromRGB(236, 200, 90), 5)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "compra" then
		Pantalla.aviso(string.format("Has comprado: %s (-%s)", d.nombre, Pantalla.dineroTexto(d.precio)), Color3.fromRGB(236, 200, 90), 4)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "mensaje" then
		Pantalla.aviso(d.texto, Color3.fromRGB(230, 226, 214), 4)
	end
end)

Estado.OnClientEvent:Connect(function(datos)
	e.datos = datos
	Pantalla.estado(datos)
	refrescarArma()
end)

local tiendaEn
Tienda.OnClientEvent:Connect(function(que, d)
	if que == "abrir" then
		local _, hrp = humanoide()
		tiendaEn = hrp and hrp.Position
		Pantalla.abrirTienda(d and d.nombre, function(tipo, id)
			Accion:FireServer("comprar", tipo, id)
		end, function()
			Accion:FireServer("vender")
		end)
	end
end)

-- Pide el dinero y la mochila al arrancar (por si el servidor los mandó antes de que este script escuchara)
Accion:FireServer("estado")

EfectosR.OnClientEvent:Connect(function(que, d)
	local f = Efectos[que]
	if f and type(d) == "table" then
		f(d, camara.CFrame.Position)
	end
end)

-- =====================================================================
--  Bucles
-- =====================================================================
-- Después de la cámara de Roblox: hombro, giro del personaje con la cámara, zoom, retroceso y temblor
RunService:BindToRenderStep("CazaCamara", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local hum, hrp = humanoide()
	if e.tirador and hrp and hum and hum.Health > 0 then
		if not esMovil then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		local mirada = camara.CFrame.LookVector
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-mirada.X, -mirada.Z), 0)
	end
	local objetivo = (e.apuntando and e.cfg) and (e.cfg.zoom or 55) or FOV
	camara.FieldOfView = camara.FieldOfView + (objetivo - camara.FieldOfView) * math.min(1, dt * 12)
	UserInputService.MouseDeltaSensitivity = math.clamp(camara.FieldOfView / FOV, 0.15, 1)
	if e.retroceso > 0.01 then
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad(e.retroceso), 0, 0)
		e.retroceso = e.retroceso * math.exp(-dt * 14)
	end
	Efectos.camara(dt, camara)
end)

RunService.RenderStepped:Connect(function(dt)
	Efectos.actualizar(dt)
	Efectos.peces(dt, camara.CFrame.Position)
	if pesca.fase == "luchando" and pelea then
		actualizarPelea(dt)
	end
	if e.disparando and e.cfg and e.cfg.automatica then
		disparar()
	end
	-- Mira: se abre con la dispersión real del arma (más al moverte, menos agachado o apuntando)
	local cfg = e.cfg
	local conMira = e.tirador and cfg and (cfg.tipo ~= "lanzable")
	local tele = conMira and cfg.mira and e.apuntando and camara.FieldOfView < (cfg.zoom or 55) + 6
	Pantalla.telescopica(tele == true)
	if conMira and not tele then
		local _, hrp = humanoide()
		local disp = (cfg.dispersion or 0) + e.floracion
		if hrp and hrp.AssemblyLinearVelocity.Magnitude > 3 then
			disp = disp * 2
		end
		if e.agachado then
			disp = disp * 0.6
		end
		if e.apuntando then
			disp = disp * 0.5
		end
		local px = math.tan(math.rad(disp)) / math.tan(math.rad(camara.FieldOfView / 2)) * camara.ViewportSize.Y / 2
		Pantalla.mira(true, px)
	else
		Pantalla.mira(false, 0)
	end
	e.floracion = e.floracion * math.exp(-dt * 5)
	-- La tienda se cierra si te alejas
	if Pantalla.tiendaAbierta() and tiendaEn then
		local _, hrp = humanoide()
		if not hrp or (hrp.Position - tiendaEn).Magnitude > 25 then
			Pantalla.cerrarTienda()
		end
	end
end)

-- Las articulaciones de los animales se mueven antes de la física de cada fotograma
RunService.Stepped:Connect(function(_, dt)
	Efectos.animar(dt, camara.CFrame.Position)
end)
