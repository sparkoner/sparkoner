--[[
	CazaServidor (va en ServerScriptService, con sus módulos dentro): caza, pesca y armas del mundo abierto.
	  Modelos   animales a tamaño real, armas, cañas y corcho
	  Animales  aparición, comportamiento, heridas y despiece
	  Armas     disparos con balística real, cuerpo a cuerpo, recarga, granadas y molotov
	  Pesca     lanzar, picada y pelea con el pez
	  Economia  dinero, mochila, equipo, tiendas y guardado
	Se configura en ReplicatedStorage.CazaConfig.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("CazaConfig"))
local Modelos = require(script:WaitForChild("Modelos"))
local Animales = require(script:WaitForChild("Animales"))
local Armas = require(script:WaitForChild("Armas"))
local Pesca = require(script:WaitForChild("Pesca"))
local Economia = require(script:WaitForChild("Economia"))

-- Eventos entre servidor y jugadores
local carpeta = ReplicatedStorage:FindFirstChild("CazaRemotos") or Instance.new("Folder")
carpeta.Name = "CazaRemotos"
carpeta.Parent = ReplicatedStorage
local function remoto(nombre)
	local r = carpeta:FindFirstChild(nombre) or Instance.new("RemoteEvent")
	r.Name = nombre
	r.Parent = carpeta
	return r
end
local remotos = {
	Accion = remoto("Accion"), -- jugador -> servidor: disparar, golpear, recargar, lanzar, comprar, vender, agachado
	Pesca = remoto("Pesca"), -- ida y vuelta: lanzar, clavar, resultado / esperando, picada, pelea, capturado...
	Efectos = remoto("Efectos"), -- servidor -> todos: balas, flechas, impactos, explosiones
	Aviso = remoto("Aviso"), -- servidor -> un jugador: avisos en pantalla
	Estado = remoto("Estado"), -- servidor -> un jugador: dinero, equipo y mochila
	Tienda = remoto("Tienda"), -- servidor -> un jugador: abrir la tienda
}

-- Datos del mapa (zonas, lagos y costa) del mundo abierto, si está instalado
local W
do
	local ok, res = pcall(function()
		local modulo = ServerStorage:WaitForChild("MundoAbierto", 10)
		return require(modulo:WaitForChild("Datos"))({}, { Props = {} })
	end)
	if ok then
		W = res
	else
		warn("[Caza] Sin datos del mundo abierto; los animales aparecerán en cualquier sitio:", res)
	end
end

local ctx = {
	Config = Config, Modelos = Modelos, W = W, remotos = remotos,
	Animales = Animales, Armas = Armas, Pesca = Pesca, Economia = Economia,
}
function ctx.darBotin(jugador, botin, animal)
	Economia.darBotin(jugador, botin, animal)
end
function ctx.alMatar(jugador, animal)
	if jugador then
		remotos.Aviso:FireClient(jugador, "abatido", { nombre = animal.def.nombre, peso = animal.peso })
	end
end
function ctx.alAtacar(jugador, animal)
	remotos.Aviso:FireClient(jugador, "atacado", { nombre = animal.def.nombre })
end

Economia.iniciar(ctx)
Armas.iniciar(ctx)
Pesca.iniciar(ctx)

-- Límite de mensajes por jugador (para que nadie sature el servidor)
local cuenta = {}
local function permitido(jugador)
	local t = os.clock()
	local c = cuenta[jugador]
	if not c or t - c.desde > 1 then
		c = { desde = t, n = 0 }
		cuenta[jugador] = c
	end
	c.n = c.n + 1
	return c.n <= 40
end
Players.PlayerRemoving:Connect(function(p)
	cuenta[p] = nil
end)

remotos.Accion.OnServerEvent:Connect(function(jugador, accion, a, b, c)
	if not permitido(jugador) then
		return
	end
	if accion == "disparar" then
		Armas.disparar(jugador, a, b, c)
	elseif accion == "golpear" then
		Armas.golpear(jugador, a, b)
	elseif accion == "recargar" then
		Armas.recargar(jugador, a)
	elseif accion == "lanzar" then
		Armas.lanzar(jugador, a, b)
	elseif accion == "comprar" then
		Economia.comprar(jugador, a, b)
	elseif accion == "vender" then
		Economia.vender(jugador)
	elseif accion == "agachado" then
		jugador:SetAttribute("Agachado", a == true)
	elseif accion == "estado" then
		Economia.enviar(jugador)
	end
end)

remotos.Pesca.OnServerEvent:Connect(function(jugador, accion, a, b)
	if not permitido(jugador) then
		return
	end
	if accion == "lanzar" then
		Pesca.lanzar(jugador, a)
	elseif accion == "clavar" then
		Pesca.clavar(jugador)
	elseif accion == "resultado" then
		Pesca.resultado(jugador, a, b)
	elseif accion == "recoger" then
		Pesca.recoger(jugador)
	end
end)

-- Los animales se reparten por el mapa (tarda unos segundos)
task.spawn(function()
	local n = Animales.iniciar(ctx)
	print(string.format("[Caza] %d animales en el mapa", n))
end)
