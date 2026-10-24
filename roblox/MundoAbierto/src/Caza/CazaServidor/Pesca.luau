--[[
	Pesca (servidor):
	  1. Lanzas (clic con la caña): el corcho cae al agua donde apuntas, hasta la distancia de tu caña.
	  2. Esperas: con lluvia o nublado pican antes, con sol o nieve tardan más. Las cañas buenas también ayudan.
	  3. Picada: el corcho se hunde de golpe y tienes poco más de un segundo para clavar (clic).
	  4. Pelea: el pez tira en arrancadas y se va cansando. Recoges manteniendo pulsado; si tiras con el
	     sedal muy tenso se rompe, y si le das demasiado sedal se escapa. Un pez mucho más pesado de lo que
	     aguanta tu caña rompe el sedal nada más clavarlo.
	El pez depende del agua (río, lago o mar) y su peso real se decide aquí, en el servidor.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Pesca = {}
local Config, Modelos, W, Economia, Remoto, Efectos, M
local estados = {}
local carpeta
local params

local function ahora()
	return os.clock()
end

-- "mar", "lago" o "rio" según dónde cae el corcho
local function tipoAgua(x, z)
	if not W then
		return "lago"
	end
	if not W.inLandPoly(x, z) then
		return "mar"
	end
	for _, l in ipairs(W.lakes) do
		if math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) < l[3] + 15 then
			return "lago"
		end
	end
	return "rio"
end
Pesca.tipoAgua = tipoAgua

local function elegirPez(agua, cana)
	local opciones, total = {}, 0
	for id, pez in pairs(Config.Peces) do
		if pez.aguas[agua] then
			local w = pez.prob
			if pez.prob < 8 then
				w = w * (1 + cana.suerte * 4)
			end
			if pez.basura then
				w = w * (1 - cana.suerte)
			end
			table.insert(opciones, { id, w })
			total = total + w
		end
	end
	table.sort(opciones, function(a, b)
		return a[1] < b[1]
	end)
	local r = math.random() * total
	local id = opciones[#opciones][1]
	for _, o in ipairs(opciones) do
		r = r - o[2]
		if r <= 0 then
			id = o[1]
			break
		end
	end
	local pez = Config.Peces[id]
	-- La mayoría de los peces salen pequeños; los grandes son raros (la suerte de la caña ayuda un poco)
	local f = math.random() ^ (2.6 - cana.suerte * 2)
	local peso = pez.peso[1] + (pez.peso[2] - pez.peso[1]) * f
	return id, math.floor(peso * 100 + 0.5) / 100
end
Pesca.elegirPez = elegirPez

local function limpiar(jugador, motivo, info)
	local s = estados[jugador]
	if not s then
		return
	end
	estados[jugador] = nil
	s.fin = true
	if s.conexion then
		s.conexion:Disconnect()
	end
	if s.flote then
		s.flote:Cancel()
	end
	if s.corcho then
		s.corcho:Destroy()
	end
	if motivo then
		Remoto:FireClient(jugador, motivo, info or {})
	end
end

local function flotar(s)
	local raiz = s.corcho.PrimaryPart
	local base = CFrame.new(s.punto + Vector3.new(0, 0.05, 0))
	raiz.CFrame = base
	s.flote = TweenService:Create(raiz, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = base + Vector3.new(0, 0.07, 0) })
	s.flote:Play()
end

local function hundir(s, cuanto, tiempo)
	if s.flote then
		s.flote:Cancel()
	end
	local raiz = s.corcho.PrimaryPart
	TweenService:Create(raiz, TweenInfo.new(tiempo, Enum.EasingStyle.Quad), { CFrame = CFrame.new(s.punto - Vector3.new(0, cuanto, 0)) }):Play()
end

local function esperarPicada(jugador, s)
	while not s.fin do
		local clima = ReplicatedStorage:GetAttribute("Clima")
		local factor = (Config.ClimaPesca[clima] or 1) * s.cana.rapidez
		local e = Config.EsperaPicada
		task.wait((e[1] + math.random() * (e[2] - e[1])) * factor)
		if s.fin or s.estado ~= "esperando" then
			return
		end
		s.pez, s.peso = elegirPez(s.agua, s.cana)
		s.estado = "picando"
		s.picada = ahora()
		-- Un par de toques y luego se hunde de golpe
		hundir(s, 0.5, 0.12)
		Remoto:FireClient(jugador, "picada", {})
		task.wait(Config.TiempoClavar + 0.3)
		if s.fin or s.estado ~= "picando" then
			return
		end
		s.estado = "esperando"
		flotar(s)
		Remoto:FireClient(jugador, "escapado", { motivo = "tarde" })
	end
end

function Pesca.lanzar(jugador, punto)
	if typeof(punto) ~= "Vector3" then
		return
	end
	local char = jugador.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("Cana")
	local cana = id and Config.Canas[id]
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not cana or not hrp then
		return
	end
	limpiar(jugador)
	-- No se puede lanzar más lejos de lo que da la caña
	local plano = Vector3.new(punto.X - hrp.Position.X, 0, punto.Z - hrp.Position.Z)
	local maximo = cana.distancia * M
	if plano.Magnitude > maximo then
		plano = plano.Unit * maximo
	end
	local x, z = hrp.Position.X + plano.X, hrp.Position.Z + plano.Z
	local res = workspace:Raycast(Vector3.new(x, hrp.Position.Y + 60, z), Vector3.new(0, -300, 0), params)
	if not res or res.Material ~= Enum.Material.Water then
		Remoto:FireClient(jugador, "sinAgua", {})
		return
	end
	local corcho = Modelos.corcho()
	corcho.Parent = carpeta
	local s = {
		tool = tool, id = id, cana = cana, corcho = corcho, punto = res.Position, agua = tipoAgua(x, z),
		estado = "esperando", inicio = ahora(),
	}
	estados[jugador] = s
	flotar(s)
	-- El sedal: de la punta de la caña al corcho, con algo de comba
	local punta = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Punta")
	if punta then
		local sedal = Instance.new("Beam")
		sedal.Name = "Sedal"
		sedal.Attachment0 = punta
		sedal.Attachment1 = corcho.PrimaryPart.Linea
		sedal.Width0 = 0.03
		sedal.Width1 = 0.03
		sedal.Color = ColorSequence.new(Color3.fromRGB(235, 235, 230))
		sedal.Transparency = NumberSequence.new(0.25)
		sedal.FaceCamera = true
		sedal.Segments = 14
		sedal.CurveSize0 = -1.5
		sedal.CurveSize1 = 0.5
		sedal.Parent = corcho
	end
	s.conexion = tool.Unequipped:Connect(function()
		limpiar(jugador, "recogido")
	end)
	Efectos:FireAllClients("chapoteo", { pos = res.Position, jugador = jugador.UserId })
	Remoto:FireClient(jugador, "esperando", { agua = s.agua })
	task.spawn(esperarPicada, jugador, s)
end

function Pesca.clavar(jugador)
	local s = estados[jugador]
	if not s or s.estado ~= "picando" or ahora() - s.picada > Config.TiempoClavar + 0.25 then
		return
	end
	local pez = Config.Peces[s.pez]
	local ratio = s.peso / s.cana.resistencia
	if ratio > 3 then
		limpiar(jugador, "sedalRoto", { motivo = "grande" })
		return
	end
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local distancia = hrp and Vector3.new(s.punto.X - hrp.Position.X, 0, s.punto.Z - hrp.Position.Z).Magnitude or 20
	s.estado = "luchando"
	s.inicioPelea = ahora()
	s.distancia = distancia
	hundir(s, 0.9, 0.2)
	Remoto:FireClient(jugador, "pelea", {
		fuerza = pez.fuerza, aguante = pez.aguante, ratio = ratio, distancia = distancia,
		recogida = s.cana.recogida * M, basura = pez.basura == true, grande = s.peso >= pez.peso[1] + (pez.peso[2] - pez.peso[1]) * 0.5,
	})
	task.delay(120, function()
		if estados[jugador] == s and s.estado == "luchando" then
			limpiar(jugador, "escapado", { motivo = "cansado" })
		end
	end)
end

function Pesca.resultado(jugador, ok, motivo)
	local s = estados[jugador]
	if not s or s.estado ~= "luchando" then
		return
	end
	if ok ~= true then
		limpiar(jugador, (motivo == "sedal") and "sedalRoto" or "escapado", { motivo = motivo })
		return
	end
	-- El carrete no recoge más rápido de lo que da de sí: tiempo mínimo de la pelea
	local minimo = 1.2 + s.distancia / (s.cana.recogida * M) * 0.7
	if ahora() - s.inicioPelea < minimo then
		limpiar(jugador, "escapado", { motivo = "rapido" })
		return
	end
	local pez = Config.Peces[s.pez]
	local valor = pez.basura and 1 or math.floor(s.peso * pez.precioKg + 0.5)
	local info = { id = s.pez, nombre = pez.nombre, peso = s.peso, valor = valor, agua = s.agua }
	info.record = Economia.darPez(jugador, info)
	limpiar(jugador)
	Remoto:FireClient(jugador, "capturado", info)
	Efectos:FireAllClients("pez", { jugador = jugador.UserId, id = info.id, peso = info.peso })
end

function Pesca.recoger(jugador)
	limpiar(jugador, "recogido")
end

function Pesca.iniciar(ctx)
	Config, Modelos, W, Economia = ctx.Config, ctx.Modelos, ctx.W, ctx.Economia
	Remoto, Efectos = ctx.remotos.Pesca, ctx.remotos.Efectos
	M = Config.StudsPorMetro
	carpeta = workspace:FindFirstChild("Corchos") or Instance.new("Folder")
	carpeta.Name = "Corchos"
	carpeta.Parent = workspace
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	Players.PlayerRemoving:Connect(function(p)
		limpiar(p)
	end)
end

return Pesca
