--[[
	Mundo abierto postapocalíptico (al estilo The Last of Us): unos 4 x 4 km con relieve realista,
	ríos, lagos, playas, montañas nevadas, bosques y 16 zonas abandonadas unidas por carreteras.

	Va en ServerStorage como ModuleScript "MundoAbierto" con estos hijos:
	  Motor       construye piezas y zonas
	  Piezas      objetos prefabricados (casas, coches, vallas...)
	  Datos       costa, ríos, carreteras, zonas y utilidades
	  Terreno     relieve y suelo (se escribe con WriteVoxels)
	  Vegetacion  abetos, robles, abedules, sotobosque, hierba alta, juncos, troncos y rocas
	  Zonas       un ModuleScript por zona

	Uso:
		local Mundo = require(game.ServerStorage.MundoAbierto)
		Mundo.instalar()   -- pone las piezas en Workspace.Mundo y genera el terreno
]]
local Mundo = {}

-- Construye todas las piezas y devuelve el Model (sin terreno todavía)
function Mundo.construir()
	local Motor = require(script:WaitForChild("Motor"))
	return Motor.build("Mundo", function(b, MB)
		local W = require(script:WaitForChild("Datos"))(b, MB)
		local T = require(script:WaitForChild("Terreno"))(W)
		local V = require(script:WaitForChild("Vegetacion"))(b, MB, W, T)
		Mundo.W, Mundo.T, Mundo.V = W, T, V
		-- Las zonas pueden plantar árboles sueltos
		local KINDS = { roble = V.oak, pino = V.pine, abeto = V.pine, muerto = V.dead, abedul = V.birch }
		function W.tree(x, z, kind, s)
			(KINDS[kind] or V.oak)(x, z, s or 1)
		end

		b.model:SetAttribute("Nombre", "Mundo Abierto")

		b:zone("Carreteras")
		W.buildRoads()
		W.buildBridges()
		W.buildCars()

		local zones = script:WaitForChild("Zonas"):GetChildren()
		table.sort(zones, function(a, c)
			return a.Name < c.Name
		end)
		for _, module in ipairs(zones) do
			if module:IsA("ModuleScript") then
				b:zone(module.Name)
				require(module)(b, MB, W)
			end
		end

		b:zone("Bosque")
		Mundo.vegetacion = V.buildAll({ trees = 2600, bushes = 1100, tufts = 4500, reeds = 450, riverRocks = 160, logs = 140, stumps = 160, rocks = 320 })
		b:zone(nil)
		W.buildBounds()
	end)
end

-- Escribe el terreno (tarda un poco). progress(hechos, total) es opcional.
function Mundo.generarTerreno(progress)
	local terrain = workspace.Terrain
	terrain:Clear()
	Mundo.T.generate(terrain, progress)
end

-- Todo en uno: piezas en Workspace.Mundo y terreno
function Mundo.instalar(progress)
	local viejo = workspace:FindFirstChild("Mundo")
	if viejo then
		viejo:Destroy()
	end
	local modelo = Mundo.construir()
	modelo.Parent = workspace
	Mundo.generarTerreno(progress)
	return modelo
end

return Mundo
