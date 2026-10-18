--[[
	ModuleScript de ejemplo para tu sistema de duelos (ponlo en ServerScriptService).
	Carga un mapa al azar y coloca a cada jugador en un spawn de su equipo:

		local startDuel = require(game.ServerScriptService.DueloMapas)
		startDuel({ jugador1 }, { jugador2 })            -- 1 contra 1 en un mapa de duelo al azar
		startDuel(equipoAzul, equipoRojo)                -- con más de 12 jugadores elige la Gran Ciudad
		startDuel(equipoAzul, equipoRojo, "Ciudad")      -- o un mapa concreto
]]
local ServerStorage = game:GetService("ServerStorage")
local MapBuilder = require(ServerStorage:WaitForChild("MapBuilder"))

-- Con Rojo los mapas no están guardados en el lugar: se construyen al arrancar el servidor
if not ServerStorage:FindFirstChild("MapasDuelo") then
	MapBuilder.buildAll()
end

-- Cuántos jugadores caben en un mapa (atributo "Jugadores"; los mapas de duelo admiten 12)
local function capacity(map)
	return map:GetAttribute("Jugadores") or 12
end

-- Elige un mapa al azar entre los más pequeños en los que caben todos los jugadores
local function randomMapName(playerCount)
	local best, names = math.huge, {}
	local biggest, biggestName = 0, nil
	for _, map in ipairs(ServerStorage.MapasDuelo:GetChildren()) do
		local cap = capacity(map)
		if cap > biggest then
			biggest, biggestName = cap, map.Name
		end
		if cap >= playerCount then
			if cap < best then
				best, names = cap, {}
			end
			if cap == best then
				table.insert(names, map.Name)
			end
		end
	end
	if #names == 0 then
		return biggestName
	end
	return names[math.random(#names)]
end

-- Reparte a los jugadores entre los spawns en orden aleatorio, sin repetir hasta que se acaban
local function placeTeam(team, spawnList)
	local order = {}
	for i = 1, #spawnList do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	for i, player in ipairs(team) do
		local character = player.Character or player.CharacterAdded:Wait()
		local spawnCFrame = spawnList[order[(i - 1) % #order + 1]]
		-- Si hay más jugadores que spawns, los que repiten aparecen un poco al lado
		local extra = math.floor((i - 1) / #order)
		character:PivotTo(spawnCFrame * CFrame.new(extra * 3, 0, 0))
	end
end

-- teamA y teamB son listas de jugadores; mapName es opcional (si no, se elige uno al azar)
local function startDuel(teamA, teamB, mapName)
	mapName = mapName or randomMapName(#teamA + #teamB)
	local _, spawns = MapBuilder.load(mapName)
	placeTeam(teamA, spawns.A)
	placeTeam(teamB, spawns.B)
	return mapName
end

return startDuel
