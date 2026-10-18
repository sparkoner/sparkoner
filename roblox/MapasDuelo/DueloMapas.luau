--[[
	ModuleScript de ejemplo para tu sistema de duelos (ponlo en ServerScriptService).
	Carga un mapa al azar y coloca a cada jugador en un spawn de su equipo:

		local startDuel = require(game.ServerScriptService.DueloMapas)
		startDuel({ jugador1 }, { jugador2 })
]]
local ServerStorage = game:GetService("ServerStorage")
local MapBuilder = require(ServerStorage:WaitForChild("MapBuilder"))

-- Con Rojo los mapas no están guardados en el lugar: se construyen al arrancar el servidor
if not ServerStorage:FindFirstChild("MapasDuelo") then
	MapBuilder.buildAll()
end

local function randomMapName()
	local names = {}
	for _, map in ipairs(ServerStorage.MapasDuelo:GetChildren()) do
		table.insert(names, map.Name)
	end
	return names[math.random(#names)]
end

local function placePlayer(player, spawnList)
	local character = player.Character or player.CharacterAdded:Wait()
	character:PivotTo(spawnList[math.random(#spawnList)])
end

-- teamA y teamB son listas de jugadores
local function startDuel(teamA, teamB)
	local mapName = randomMapName()
	local _, spawns = MapBuilder.load(mapName)
	for _, player in ipairs(teamA) do
		placePlayer(player, spawns.A)
	end
	for _, player in ipairs(teamB) do
		placePlayer(player, spawns.B)
	end
	return mapName
end

return startDuel
