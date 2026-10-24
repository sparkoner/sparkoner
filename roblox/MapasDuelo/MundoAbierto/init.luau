--[[
	Mundo abierto postapocalíptico (al estilo The Last of Us): unos 4 x 4 km de terreno con costa,
	ríos, lagos, montañas y bosques, y 16 zonas abandonadas unidas por carreteras.

	Va en su propio ModuleScript (ServerStorage.MundoAbierto) con dos hijos:
	  - Mundo: datos del mapa (costa, ríos, carreteras, zonas) y utilidades.
	  - Zonas: un ModuleScript por zona.
	ConstruirMundoAbierto.luau lo crea y lo pone en Workspace con su terreno.
]]
return function(b, MB)
	local W = require(script:WaitForChild("Mundo"))(b, MB)
	b.model:SetAttribute("Nombre", "Mundo Abierto")
	b.model:SetAttribute("Tipo", "MundoAbierto")
	b.model:SetAttribute("Jugadores", 100)

	W.buildTerrain()

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
	W.buildForest(2400)
	b:zone(nil)
	W.buildBounds()

	-- Tarde nublada con niebla: verde apagado y luz cálida entre las nubes
	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 16.4,
			Brightness = 2.2,
			Ambient = { 96, 104, 92 },
			OutdoorAmbient = { 136, 144, 128 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.35,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.38, offset = 0.12, color = { 200, 206, 190 }, decay = { 120, 130, 110 }, glare = 0.6, haze = 2.2 },
		colorCorrection = { contrast = 0.1, saturation = -0.15, tint = { 240, 248, 232 } },
		clouds = { cover = 0.72, density = 0.6, color = { 214, 218, 210 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.12, spread = 0.7 },
	})
end
