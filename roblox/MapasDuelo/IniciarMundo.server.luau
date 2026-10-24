--[[
	Script de servidor de ejemplo (ponlo en ServerScriptService) para usar el mundo abierto con Rojo.
	Si el mundo ya está guardado en Workspace (MapaActual) no hace nada; si no, lo construye al
	arrancar el servidor, con su terreno, antes de que entren los jugadores.
]]
local ServerStorage = game:GetService("ServerStorage")

if not workspace:FindFirstChild("MapaActual") then
	local MapBuilder = require(ServerStorage:WaitForChild("MapBuilder"))
	local mundo = MapBuilder.build("MundoAbierto", require(ServerStorage:WaitForChild("MundoAbierto")))
	MapBuilder.show(mundo, "MundoAbierto")
end
