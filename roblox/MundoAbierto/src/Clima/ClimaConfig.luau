--[[
	Configuración del clima del mundo abierto (va en ReplicatedStorage como ClimaConfig).
	La usan ClimaServidor (cambia el clima, la luz, el viento y la nieve en el suelo) y
	ClimaCliente (lluvia, nieve, polvo, rayos y sonidos de cada jugador).
]]
local Config = {}

-- Cuánto dura cada clima (en minutos) y cuánto tarda en pasar de uno a otro (en segundos)
Config.DuracionMinima = 4
Config.DuracionMaxima = 9
Config.Transicion = 30
-- Clima con el que empieza el servidor (nil = al azar)
Config.ClimaInicial = "Nublado"

-- Ciclo de día y noche: minutos que dura un día completo (0 = hora fija)
Config.MinutosPorDia = 0
Config.HoraFija = 14.5

--[[
	SONIDOS. Roblox no trae de serie sonidos de lluvia ni de truenos, así que pega aquí los IDs.
	En Studio: Ver > Caja de herramientas > Audio, busca "rain", "thunder", "wind", "birds", "crickets"...,
	elige uno, clic derecho > Copiar ID del recurso y pégalo como "rbxassetid://NUMERO".
	Los sonidos subidos por la cuenta "Roblox" son gratis y funcionan en cualquier juego.
	Si un hueco se queda vacío ("") ese sonido simplemente no suena.
]]
Config.Sonidos = {
	Lluvia = "",                                     -- lluvia suave, en bucle
	LluviaFuerte = "",                               -- lluvia fuerte / aguacero, en bucle
	Viento = "rbxasset://sounds/action_falling.mp3", -- viento (viene con Roblox), en bucle
	Pajaros = "",                                    -- pájaros de día, en bucle
	Ambiente = "",                                   -- ambiente de bosque o grillos, en bucle
	Truenos = { "", "", "" },                        -- truenos (uno o varios, sin bucle)
	Fuego = "",                                      -- crepitar de hoguera, en bucle (suena cerca de cada fuego)
}

-- Texturas de las gotas y los copos ("" = la textura de partículas que trae Roblox)
Config.TexturaLluvia = ""
Config.TexturaNieve = ""

-- Colores del terreno normales y cubiertos de nieve
Config.ColoresTerreno = {
	Grass = { 76, 100, 58 }, LeafyGrass = { 62, 86, 48 }, Ground = { 98, 86, 68 }, Mud = { 74, 64, 50 },
	Rock = { 108, 106, 102 }, Slate = { 98, 100, 102 }, Basalt = { 72, 72, 76 }, Sand = { 190, 178, 144 }, Snow = { 236, 240, 246 },
}
Config.ColoresNevado = {
	Grass = { 226, 232, 238 }, LeafyGrass = { 214, 222, 228 }, Ground = { 214, 218, 224 }, Mud = { 190, 196, 204 },
	Rock = { 196, 200, 206 }, Slate = { 192, 196, 202 }, Basalt = { 186, 190, 198 }, Sand = { 226, 230, 236 }, Snow = { 240, 244, 250 },
}

--[[
	Climas. peso = probabilidad relativa de que salga.
	luz: Lighting · atmosfera: niebla · nubes · color: corrección de color · rayosSol · brillo
	viento: dirección y fuerza (mueve la hierba del terreno, las nubes y las partículas)
	olas: tamaño y velocidad del oleaje · agua: color y transparencia del agua (con lluvia baja turbia)
	lluvia/nieve/polvo: cantidad de partículas (0 = nada)
	rayos: hay relámpagos y truenos · nevar: el suelo se va cubriendo de nieve
	sonidos: volumen de cada sonido (0 a 1)
]]
Config.Climas = {
	Soleado = {
		peso = 4,
		luz = { Brightness = 3, Ambient = { 118, 118, 110 }, OutdoorAmbient = { 158, 158, 148 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0, ShadowSoftness = 0.15 },
		atmosfera = { Density = 0.26, Offset = 0.1, Haze = 1, Glare = 0.4, Color = { 199, 214, 226 }, Decay = { 110, 128, 150 } },
		nubes = { Cover = 0.4, Density = 0.5, Color = { 255, 255, 255 } },
		color = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.05, TintColor = { 255, 250, 240 } },
		rayosSol = 0.15, brillo = 0.3,
		viento = { 6, 0, 3 }, olas = { 0.08, 6 }, agua = { { 30, 84, 90 }, 0.5 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Pajaros = 0.5, Ambiente = 0.3, Viento = 0.08 },
	},
	Nublado = {
		peso = 3,
		luz = { Brightness = 2, Ambient = { 108, 112, 110 }, OutdoorAmbient = { 136, 142, 138 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.1, ShadowSoftness = 0.45 },
		atmosfera = { Density = 0.35, Offset = 0.12, Haze = 1.9, Glare = 0.1, Color = { 198, 205, 204 }, Decay = { 118, 128, 128 } },
		nubes = { Cover = 0.84, Density = 0.65, Color = { 202, 206, 208 } },
		color = { Brightness = 0, Contrast = 0.07, Saturation = -0.12, TintColor = { 244, 248, 246 } },
		rayosSol = 0.04, brillo = 0.25,
		viento = { 10, 0, 6 }, olas = { 0.12, 7 }, agua = { { 34, 74, 78 }, 0.35 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Pajaros = 0.15, Ambiente = 0.3, Viento = 0.2 },
	},
	Niebla = {
		peso = 2,
		luz = { Brightness = 1.6, Ambient = { 120, 124, 122 }, OutdoorAmbient = { 140, 146, 144 }, EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.15, ShadowSoftness = 0.8 },
		atmosfera = { Density = 0.62, Offset = 0.25, Haze = 3, Glare = 0, Color = { 196, 202, 200 }, Decay = { 150, 158, 156 } },
		nubes = { Cover = 0.9, Density = 0.7, Color = { 210, 214, 214 } },
		color = { Brightness = 0.02, Contrast = 0.02, Saturation = -0.22, TintColor = { 240, 246, 246 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 2, 0, 1 }, olas = { 0.05, 4 }, agua = { { 46, 74, 76 }, 0.3 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Ambiente = 0.25, Viento = 0.06 },
	},
	Viento = {
		peso = 2,
		luz = { Brightness = 2.4, Ambient = { 114, 116, 110 }, OutdoorAmbient = { 150, 152, 144 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0, ShadowSoftness = 0.3 },
		atmosfera = { Density = 0.32, Offset = 0.1, Haze = 1.8, Glare = 0.2, Color = { 206, 204, 190 }, Decay = { 140, 130, 110 } },
		nubes = { Cover = 0.62, Density = 0.5, Color = { 236, 236, 232 } },
		color = { Brightness = 0, Contrast = 0.08, Saturation = -0.05, TintColor = { 252, 248, 238 } },
		rayosSol = 0.08, brillo = 0.25,
		viento = { 55, 0, 26 }, olas = { 0.3, 14 }, agua = { { 38, 76, 78 }, 0.3 },
		lluvia = 0, nieve = 0, polvo = 60, rayos = false, nevar = false,
		sonidos = { Viento = 0.9, Ambiente = 0.1 },
	},
	Lluvia = {
		peso = 3,
		luz = { Brightness = 1.3, Ambient = { 90, 96, 100 }, OutdoorAmbient = { 110, 118, 124 }, EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 1, ExposureCompensation = 0.1, ShadowSoftness = 0.7 },
		atmosfera = { Density = 0.45, Offset = 0.15, Haze = 2.2, Glare = 0, Color = { 170, 180, 186 }, Decay = { 100, 110, 120 } },
		nubes = { Cover = 0.97, Density = 0.82, Color = { 120, 126, 132 } },
		color = { Brightness = 0, Contrast = 0.05, Saturation = -0.25, TintColor = { 230, 238, 245 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 12, 0, 8 }, olas = { 0.2, 10 }, agua = { { 54, 70, 62 }, 0.15 },
		lluvia = 500, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Lluvia = 0.8, Viento = 0.25 },
	},
	Tormenta = {
		peso = 1.5,
		luz = { Brightness = 0.9, Ambient = { 70, 74, 82 }, OutdoorAmbient = { 86, 92, 104 }, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ExposureCompensation = 0.15, ShadowSoftness = 0.8 },
		atmosfera = { Density = 0.52, Offset = 0.18, Haze = 2.6, Glare = 0, Color = { 140, 146, 156 }, Decay = { 80, 86, 98 } },
		nubes = { Cover = 1, Density = 1, Color = { 80, 84, 92 } },
		color = { Brightness = -0.02, Contrast = 0.12, Saturation = -0.3, TintColor = { 220, 228, 240 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 40, 0, 22 }, olas = { 0.45, 18 }, agua = { { 58, 66, 58 }, 0.08 },
		lluvia = 950, nieve = 0, polvo = 0, rayos = true, nevar = false,
		sonidos = { LluviaFuerte = 1, Lluvia = 0.4, Viento = 0.6 },
	},
	Nieve = {
		peso = 1.2,
		luz = { Brightness = 1.8, Ambient = { 130, 136, 146 }, OutdoorAmbient = { 170, 178, 190 }, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0.1, ShadowSoftness = 0.7 },
		atmosfera = { Density = 0.5, Offset = 0.2, Haze = 2.4, Glare = 0, Color = { 220, 228, 236 }, Decay = { 170, 180, 196 } },
		nubes = { Cover = 0.95, Density = 0.7, Color = { 230, 234, 240 } },
		color = { Brightness = 0.02, Contrast = 0.04, Saturation = -0.2, TintColor = { 232, 240, 255 } },
		rayosSol = 0.02, brillo = 0.3,
		viento = { 8, 0, 5 }, olas = { 0.06, 4 }, agua = { { 40, 70, 84 }, 0.35 },
		lluvia = 0, nieve = 350, polvo = 0, rayos = false, nevar = true,
		sonidos = { Viento = 0.35 },
	},
}

-- Convierte un clima en propiedades para cada objeto de iluminación
local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end
local function convertir(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = (type(v) == "table") and rgb(v) or v
	end
	return out
end
function Config.propiedades(nombre)
	local c = Config.Climas[nombre]
	return {
		Lighting = convertir(c.luz),
		Atmosfera = convertir(c.atmosfera),
		Nubes = convertir(c.nubes),
		ColorClima = convertir(c.color),
		RayosSol = { Intensity = c.rayosSol },
		BrilloClima = { Intensity = c.brillo },
		Terrain = { WaterWaveSize = c.olas[1], WaterWaveSpeed = c.olas[2], WaterColor = rgb(c.agua[1]), WaterTransparency = c.agua[2] },
		Viento = Vector3.new(c.viento[1], c.viento[2], c.viento[3]),
	}
end

-- Crea (si faltan) los objetos de iluminación que usa el clima y los devuelve por nombre
function Config.objetos()
	local Lighting = game:GetService("Lighting")
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
	local o = {
		Lighting = Lighting,
		Terrain = terrain,
		Atmosfera = asegurar(Lighting, "Atmosphere", "Atmosfera"),
		ColorClima = asegurar(Lighting, "ColorCorrectionEffect", "ColorClima"),
		RayosSol = asegurar(Lighting, "SunRaysEffect", "RayosSol"),
		BrilloClima = asegurar(Lighting, "BloomEffect", "BrilloClima"),
		Nubes = asegurar(terrain, "Clouds", "Nubes"),
	}
	terrain.WaterReflectance = 1
	o.BrilloClima.Threshold = 0.95
	o.BrilloClima.Size = 24
	o.RayosSol.Spread = 0.7
	return o
end

-- Aplica un clima al instante (sin transición)
function Config.aplicar(nombre)
	local o = Config.objetos()
	for objeto, props in pairs(Config.propiedades(nombre)) do
		if objeto == "Viento" then
			workspace.GlobalWind = props
		else
			for prop, valor in pairs(props) do
				o[objeto][prop] = valor
			end
		end
	end
	for mat, c in pairs(Config.ColoresTerreno) do
		o.Terrain:SetMaterialColor(Enum.Material[mat], rgb(c))
	end
end

return Config
