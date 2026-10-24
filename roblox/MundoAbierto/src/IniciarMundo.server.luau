--[[
	Script de servidor para usar el mundo abierto con Rojo (va en ServerScriptService).
	Si el mundo ya está guardado en Workspace no hace nada; si no, lo construye al arrancar.
]]
if not workspace:FindFirstChild("Mundo") then
	local Mundo = require(game:GetService("ServerStorage"):WaitForChild("MundoAbierto"))
	Mundo.instalar()
end
