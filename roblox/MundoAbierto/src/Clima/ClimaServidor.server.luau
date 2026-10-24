--[[
	ClimaServidor (va en ServerScriptService).
	Cambia el clima cada pocos minutos con transiciones suaves (luz, niebla, nubes, viento y oleaje),
	va cubriendo el suelo de nieve cuando nieva y lanza los rayos de las tormentas.

	Para forzar un clima desde otro script del servidor:
		game.ServerStorage.CambiarClima:Fire("Tormenta")
	El creador del juego (o cualquiera en Studio) también puede escribir en el chat: /clima tormenta
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("ClimaConfig"))

local objetos = Config.objetos()
local terrain = workspace.Terrain

local function asegurar(parent, clase, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(clase)
		obj.Name = nombre
		obj.Parent = parent
	end
	return obj
end
local rayo = asegurar(ReplicatedStorage, "RemoteEvent", "ClimaRayo")
local cambiar = asegurar(ServerStorage, "BindableEvent", "CambiarClima")

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- =====================================================================
--  Cambio de clima
-- =====================================================================
local actual = nil
local finClima = 0

local function duracion()
	return (Config.DuracionMinima + math.random() * (Config.DuracionMaxima - Config.DuracionMinima)) * 60
end

local function ponerClima(nombre, instantaneo)
	if not Config.Climas[nombre] then
		warn("[Clima] No existe el clima " .. tostring(nombre))
		return
	end
	actual = nombre
	finClima = os.clock() + duracion()
	if instantaneo then
		Config.aplicar(nombre)
	else
		local info = TweenInfo.new(Config.Transicion, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for objeto, props in pairs(Config.propiedades(nombre)) do
			if objeto == "Viento" then
				TweenService:Create(workspace, info, { GlobalWind = props }):Play()
			else
				TweenService:Create(objetos[objeto], info, props):Play()
			end
		end
	end
	ReplicatedStorage:SetAttribute("Clima", nombre)
	ReplicatedStorage:SetAttribute("ClimaDesde", os.time())
	print("[Clima] Ahora: " .. nombre)
end

-- Elige el siguiente clima al azar según su peso (nunca repite el actual)
local function elegir()
	local total = 0
	for nombre, c in pairs(Config.Climas) do
		if nombre ~= actual then
			total = total + c.peso
		end
	end
	local r = math.random() * total
	for nombre, c in pairs(Config.Climas) do
		if nombre ~= actual then
			r = r - c.peso
			if r <= 0 then
				return nombre
			end
		end
	end
	return "Nublado"
end

-- =====================================================================
--  Nieve en el suelo: se acumula en 2 minutos mientras nieva y se derrite en 3
-- =====================================================================
local nieveSuelo = 0
local function pintarSuelo(t)
	for mat, c in pairs(Config.ColoresTerreno) do
		local blanco = Config.ColoresNevado[mat] or c
		terrain:SetMaterialColor(Enum.Material[mat], rgb(c):Lerp(rgb(blanco), t))
	end
end
task.spawn(function()
	while true do
		local objetivo = (actual and Config.Climas[actual].nevar) and 1 or 0
		if math.abs(objetivo - nieveSuelo) > 0.001 then
			local paso = (objetivo > nieveSuelo) and (1 / 120) or (1 / 180)
			nieveSuelo = nieveSuelo + math.clamp(objetivo - nieveSuelo, -paso, paso)
			pintarSuelo(nieveSuelo)
		end
		task.wait(1)
	end
end)

-- =====================================================================
--  Rayos: cerca de un jugador al azar, cada 6-16 segundos durante las tormentas
-- =====================================================================
task.spawn(function()
	while true do
		task.wait(6 + math.random() * 10)
		if actual and Config.Climas[actual].rayos then
			local centro = Vector3.new(0, 0, 0)
			local jugadores = Players:GetPlayers()
			if #jugadores > 0 then
				local j = jugadores[math.random(1, #jugadores)]
				local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
				if raiz then
					centro = raiz.Position
				end
			end
			local angulo = math.random() * math.pi * 2
			local distancia = 120 + math.random() * 650
			rayo:FireAllClients(centro + Vector3.new(math.cos(angulo) * distancia, 0, math.sin(angulo) * distancia))
		end
	end
end)

-- =====================================================================
--  Día y noche
-- =====================================================================
if Config.MinutosPorDia > 0 then
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (Config.MinutosPorDia * 60)) % 24
		end
	end)
else
	Lighting.ClockTime = Config.HoraFija
end

-- =====================================================================
--  Cambiar el clima a mano
-- =====================================================================
cambiar.Event:Connect(function(nombre)
	ponerClima(nombre)
end)

local nombres = {}
for nombre in pairs(Config.Climas) do
	nombres[string.lower(nombre)] = nombre
end
local function escuchar(jugador)
	jugador.Chatted:Connect(function(mensaje)
		local pedido = string.match(string.lower(mensaje), "^/clima%s+(%S+)")
		if pedido and (RunService:IsStudio() or jugador.UserId == game.CreatorId) then
			if nombres[pedido] then
				ponerClima(nombres[pedido])
			else
				warn("[Clima] Climas disponibles: Soleado, Nublado, Niebla, Viento, Lluvia, Tormenta, Nieve")
			end
		end
	end)
end
Players.PlayerAdded:Connect(escuchar)
for _, j in ipairs(Players:GetPlayers()) do
	escuchar(j)
end

-- =====================================================================
--  Bucle principal
-- =====================================================================
ponerClima(Config.ClimaInicial or elegir(), true)
while true do
	task.wait(5)
	if os.clock() >= finClima then
		ponerClima(elegir())
	end
end
