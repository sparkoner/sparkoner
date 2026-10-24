-- Pega TODO este texto en la barra de comandos de Roblox Studio y pulsa Enter.
-- Instala (o actualiza) solo la caza, la pesca y las armas. Las tiendas de caza vienen con el mundo
-- (ConstruirMundo.luau). Archivo generado por build_bundle.py a partir de src/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local CAZA_CONFIG = [=[
--[[
	Configuración de la caza, la pesca y las armas del mundo abierto (va en ReplicatedStorage como CazaConfig).
	La usan CazaServidor (animales, disparos, pesca, tienda y dinero) y CazaCliente (controles, pantalla y efectos).

	Todo está pensado para ser realista:
	  · Distancias en METROS, velocidades en METROS POR SEGUNDO y pesos en KILOS (el código lo pasa a studs).
	  · Las balas y las flechas vuelan con su velocidad real y caen por la gravedad.
	  · Un disparo en la cabeza o en el pecho (corazón y pulmones) mata mucho antes que en las patas.
	  · Un animal herido sangra, huye y deja rastro de sangre hasta que cae.
	  · Los animales te huelen si el viento les lleva tu olor, te oyen si corres y huyen de los disparos.
	  · Al despellejar se saca la carne según el peso del animal y la piel vale menos si está destrozada.
]]
local Config = {}

-- Un personaje de Roblox mide 5 studs (1,75 m): 1 metro = 2,9 studs
Config.StudsPorMetro = 2.9
-- Gravedad real (9,81 m/s²) para balas, flechas y lanzables
Config.Gravedad = 9.81

-- =====================================================================
--  General
-- =====================================================================
Config.DineroInicial = 150
-- Lo que tiene cada jugador nuevo
Config.KitInicial = { armas = { "Cuchillo", "Arco" }, canas = { "CanaBambu" }, municion = { Flechas = 12 } }
-- Las armas también hacen daño a otros jugadores (false = solo a los animales)
Config.DanoEntreJugadores = false
-- Guardar dinero, equipo y capturas entre partidas (necesita el juego publicado; para probarlo en Studio
-- activa "Permitir acceso de Studio a los servicios de API" en la configuración del juego)
Config.GuardarDatos = true

-- Cómo te detectan los animales (se multiplica la distancia de huida o de ataque)
Config.Deteccion = {
	Agachado = 0.5,       -- tecla C: andas despacio y casi no te ven
	Corriendo = 1.4,      -- moverse rápido hace ruido
	VientoAFavor = 1.6,   -- el viento lleva tu olor hacia el animal
	VientoEnContra = 0.7, -- el viento sopla de él hacia ti: no te huele
}

-- =====================================================================
--  Sonidos: pega IDs de la Caja de herramientas como "rbxassetid://NUMERO" ("" = sin sonido)
-- =====================================================================
Config.Sonidos = {
	Pistola = "", Revolver = "", Escopeta = "", RifleCaza = "", Fusil = "", Subfusil = "", Francotirador = "",
	Arco = "", Ballesta = "", Recarga = "", Vacio = "", Impacto = "",
	Cuerpo = "rbxasset://sounds/swordslash.wav", -- golpe cuerpo a cuerpo (viene con Roblox)
	Lanzar = "rbxasset://sounds/swordlunge.wav", -- lanzar molotov o granada (viene con Roblox)
	Chapoteo = "rbxasset://sounds/impact_water.mp3", -- el anzuelo cae al agua (viene con Roblox)
	Carrete = "", Picada = "", Captura = "", SedalRoto = "", Caja = "",
	Lobo = "", Oso = "", Jabali = "", Ciervo = "", Pato = "", Pavo = "", Conejo = "", Cangrejo = "",
}

-- =====================================================================
--  Munición (se compra por cajas en la tienda)
-- =====================================================================
Config.Municion = {
	Flechas = { nombre = "Flechas de caza", paquete = 6, precio = 18, orden = 1 },
	Virotes = { nombre = "Virotes de ballesta", paquete = 6, precio = 24, orden = 2 },
	Pistola = { nombre = "Cartuchos 9 mm", paquete = 30, precio = 28, orden = 3 },
	Revolver = { nombre = "Cartuchos .357 Magnum", paquete = 18, precio = 30, orden = 4 },
	Cartuchos = { nombre = "Cartuchos del calibre 12", paquete = 10, precio = 30, orden = 5 },
	Rifle = { nombre = "Cartuchos .308", paquete = 10, precio = 40, orden = 6 },
	Fusil = { nombre = "Cartuchos 5,56 mm", paquete = 30, precio = 42, orden = 7 },
	Magnum = { nombre = "Cartuchos .338 Lapua", paquete = 5, precio = 55, orden = 8 },
	Molotov = { nombre = "Cóctel molotov", paquete = 1, precio = 35, orden = 9 },
	Granada = { nombre = "Granada de fragmentación", paquete = 1, precio = 60, orden = 10 },
}

--[[
	ARMAS
	tipo: "cuerpo" (cuerpo a cuerpo), "bala" (arma de fuego), "proyectil" (arco y ballesta), "lanzable"
	dano: daño por golpe, bala o perdigón (un ciervo tiene 100 de vida; ver los multiplicadores por zona abajo)
	velocidad: m/s al salir del cañón · alcance: metros hasta que la bala se pierde
	cadencia: segundos entre disparos · cargador · recarga: segundos
	dispersion: grados de desvío parado (se dobla al moverte y se reduce agachado o apuntando)
	retroceso: cuánto sube la cámara al disparar · perdigones: balas por disparo (escopeta)
	automatica: se dispara manteniendo pulsado · zoom: campo de visión al apuntar (clic derecho)
	mira: con mira telescópica (pantalla de la mira al apuntar) · ruido: metros a los que espanta animales
	sangrado: cuánto sangra lo que hieres (las flechas matan por desangrado) · piel: daño que hace a la piel
	radio y duracion: explosión o fuego de los lanzables
]]
Config.Armas = {
	Cuchillo = { nombre = "Cuchillo de caza", tipo = "cuerpo", dano = 30, alcance = 2.2, cadencia = 0.45, sangrado = 0.5, piel = 0.1,
		precio = 0, orden = 1, desc = "Hoja de acero de 15 cm. Para rematar." },
	Bate = { nombre = "Bate de madera", tipo = "cuerpo", dano = 34, alcance = 2.6, cadencia = 0.8, sangrado = 0, piel = 0.2,
		precio = 40, orden = 2, desc = "Golpes contundentes." },
	Machete = { nombre = "Machete", tipo = "cuerpo", dano = 46, alcance = 2.6, cadencia = 0.7, sangrado = 0.6, piel = 0.25,
		precio = 90, orden = 3, desc = "Hoja de 45 cm." },
	Hacha = { nombre = "Hacha", tipo = "cuerpo", dano = 64, alcance = 2.6, cadencia = 1.1, sangrado = 0.5, piel = 0.35,
		precio = 140, orden = 4, desc = "Lenta pero brutal." },
	Lanza = { nombre = "Lanza de caza", tipo = "cuerpo", dano = 52, alcance = 3.6, cadencia = 0.95, sangrado = 0.7, piel = 0.15,
		precio = 120, orden = 5, desc = "Asta de 2 m con punta de acero. Llega más lejos." },
	Arco = { nombre = "Arco recurvo", tipo = "proyectil", municion = "Flechas", dano = 70, velocidad = 60, alcance = 90, cadencia = 1,
		cargador = 1, recarga = 0.9, dispersion = 0.4, retroceso = 0, ruido = 0, sangrado = 0.9, piel = 0.05,
		precio = 0, orden = 6, desc = "Silencioso. La flecha cae con la distancia: apunta por encima si está lejos." },
	Ballesta = { nombre = "Ballesta", tipo = "proyectil", municion = "Virotes", dano = 95, velocidad = 100, alcance = 120, cadencia = 1,
		cargador = 1, recarga = 2.2, dispersion = 0.25, retroceso = 0.4, ruido = 8, sangrado = 0.9, piel = 0.05, zoom = 45, mira = true,
		precio = 320, orden = 7, desc = "Más potente y plana que el arco. Recarga lenta." },
	Pistola = { nombre = "Pistola 9 mm", tipo = "bala", municion = "Pistola", dano = 30, velocidad = 360, alcance = 120, cadencia = 0.18,
		cargador = 15, recarga = 1.6, dispersion = 1.1, retroceso = 1.6, ruido = 160, sangrado = 0.4, piel = 0.15,
		precio = 220, orden = 8, desc = "15 balas. Poca potencia para caza mayor." },
	Revolver = { nombre = "Revólver .357 Magnum", tipo = "bala", municion = "Revolver", dano = 55, velocidad = 440, alcance = 150, cadencia = 0.55,
		cargador = 6, recarga = 2.8, dispersion = 0.8, retroceso = 3.6, ruido = 200, sangrado = 0.5, piel = 0.2,
		precio = 380, orden = 9, desc = "6 balas muy potentes." },
	Escopeta = { nombre = "Escopeta de corredera calibre 12", tipo = "bala", municion = "Cartuchos", dano = 16, perdigones = 9, velocidad = 400,
		alcance = 45, cadencia = 0.95, cargador = 5, recarga = 3.2, dispersion = 3.2, retroceso = 5, ruido = 240, sangrado = 0.3, piel = 0.6,
		precio = 480, orden = 10, desc = "9 perdigones por disparo. Letal de cerca, destroza la piel." },
	Subfusil = { nombre = "Subfusil 9 mm", tipo = "bala", municion = "Pistola", dano = 22, velocidad = 390, alcance = 100, cadencia = 0.075,
		automatica = true, cargador = 30, recarga = 2, dispersion = 2, retroceso = 0.9, ruido = 170, sangrado = 0.4, piel = 0.3, zoom = 60,
		precio = 640, orden = 11, desc = "Automático. Usa cartuchos de 9 mm." },
	RifleCaza = { nombre = "Rifle de cerrojo .308", tipo = "bala", municion = "Rifle", dano = 98, velocidad = 850, alcance = 600, cadencia = 1.3,
		cargador = 5, recarga = 3, dispersion = 0.12, retroceso = 4.2, ruido = 330, sangrado = 0.6, piel = 0.1, zoom = 22, mira = true,
		precio = 760, orden = 12, desc = "Mira 6x. El arma de caza mayor por excelencia." },
	Fusil = { nombre = "Fusil de asalto 5,56", tipo = "bala", municion = "Fusil", dano = 30, velocidad = 920, alcance = 450, cadencia = 0.085,
		automatica = true, cargador = 30, recarga = 2.4, dispersion = 1.2, retroceso = 1.3, ruido = 280, sangrado = 0.45, piel = 0.35, zoom = 50,
		precio = 900, orden = 13, desc = "Automático, 30 balas." },
	Francotirador = { nombre = "Rifle de francotirador .338", tipo = "bala", municion = "Magnum", dano = 170, velocidad = 900, alcance = 1500,
		cadencia = 1.8, cargador = 5, recarga = 3.6, dispersion = 0.04, retroceso = 6, ruido = 420, sangrado = 0.7, piel = 0.2, zoom = 8, mira = true,
		precio = 1450, orden = 14, desc = "Mira 12x. A 300 m la bala cae casi un metro." },
	Molotov = { nombre = "Cóctel molotov", tipo = "lanzable", municion = "Molotov", dano = 7, radio = 3.5, duracion = 9, velocidad = 16,
		cadencia = 1, ruido = 30, sangrado = 0, piel = 1, precio = 0, orden = 15, desc = "Incendia el suelo unos segundos." },
	Granada = { nombre = "Granada de fragmentación", tipo = "lanzable", municion = "Granada", dano = 140, radio = 6, espoleta = 3, velocidad = 17,
		cadencia = 1, ruido = 500, sangrado = 0, piel = 1, precio = 0, orden = 16, desc = "Explota a los 3 segundos de lanzarla." },
}

-- Daño según dónde acierta (las piezas de los animales tienen estos nombres)
Config.Zonas = {
	Cabeza = 2.4, Cuello = 1.7, Pecho = 1.5, Cuerpo = 0.9, Pata = 0.5, Cola = 0.4,
}

--[[
	CAÑAS DE PESCAR
	distancia: metros que lanzas · recogida: metros por segundo que recoge el carrete
	resistencia: kilos de tirón que aguanta el sedal (un pez que pesa más tensa mucho más)
	rapidez: multiplica la espera hasta la picada (menos = antes) · suerte: más peces grandes y raros
]]
Config.Canas = {
	CanaBambu = { nombre = "Caña de bambú", distancia = 10, recogida = 1.4, resistencia = 4, rapidez = 1, suerte = 0, precio = 0, orden = 1,
		color = { 196, 170, 100 }, desc = "Sedal de 0,20 mm. Para percas y truchas." },
	CanaMadera = { nombre = "Caña de madera con carrete", distancia = 16, recogida = 1.7, resistencia = 8, rapidez = 0.92, suerte = 0.05, precio = 110, orden = 2,
		color = { 120, 82, 52 }, desc = "Sedal de 0,25 mm. Aguanta carpas medianas." },
	CanaFibra = { nombre = "Caña de fibra de vidrio", distancia = 24, recogida = 2.1, resistencia = 15, rapidez = 0.85, suerte = 0.1, precio = 320, orden = 3,
		color = { 60, 110, 160 }, desc = "Sedal de 0,30 mm. Ligera y resistente." },
	CanaCarbono = { nombre = "Caña de carbono", distancia = 32, recogida = 2.6, resistencia = 30, rapidez = 0.75, suerte = 0.18, precio = 780, orden = 4,
		color = { 40, 40, 44 }, desc = "Trenzado de 0,20 mm. Lucios y siluros." },
	CanaMar = { nombre = "Caña de mar (surfcasting)", distancia = 45, recogida = 3, resistencia = 70, rapidez = 0.8, suerte = 0.15, precio = 1250, orden = 5,
		color = { 210, 210, 206 }, desc = "4,2 m y carrete grande. Para pescar desde la playa." },
	CanaCurrican = { nombre = "Caña de curricán", distancia = 50, recogida = 3.6, resistencia = 220, rapidez = 0.65, suerte = 0.3, precio = 3200, orden = 6,
		color = { 214, 170, 60 }, desc = "Carrete de altura. Atunes, peces espada y esturiones." },
}

-- Cuánto tardan en picar según el clima (menos = antes): con lluvia y nublado pican más
Config.ClimaPesca = { Soleado = 1.15, Nublado = 0.9, Niebla = 0.85, Viento = 1.05, Lluvia = 0.7, Tormenta = 0.65, Nieve = 1.25 }
-- Segundos de espera hasta la picada (antes de aplicar la caña y el clima)
Config.EsperaPicada = { 7, 20 }
-- Segundos que tienes para clavar el anzuelo cuando pican
Config.TiempoClavar = 1.4

--[[
	PECES (pesos reales; la mayoría salen pequeños y los ejemplares grandes son raros)
	aguas: rio, lago, mar · peso: kilos mínimo y máximo · precioKg · prob: frecuencia
	fuerza: lo que tira para su tamaño (0 a 1) · aguante: cuánto tarda en cansarse (0 a 1)
]]
Config.Peces = {
	Perca = { nombre = "Perca", aguas = { rio = true, lago = true }, peso = { 0.1, 1.8 }, precioKg = 9, prob = 30, fuerza = 0.2, aguante = 0.2, color = { 140, 150, 80 } },
	Trucha = { nombre = "Trucha común", aguas = { rio = true, lago = true }, peso = { 0.2, 4 }, precioKg = 12, prob = 30, fuerza = 0.45, aguante = 0.35, color = { 150, 140, 120 } },
	Carpa = { nombre = "Carpa", aguas = { lago = true }, peso = { 1, 20 }, precioKg = 6, prob = 22, fuerza = 0.4, aguante = 0.6, color = { 170, 140, 70 } },
	Lucio = { nombre = "Lucio", aguas = { lago = true, rio = true }, peso = { 1, 18 }, precioKg = 10, prob = 12, fuerza = 0.65, aguante = 0.45, color = { 110, 130, 80 } },
	Salmon = { nombre = "Salmón atlántico", aguas = { rio = true, mar = true }, peso = { 2, 20 }, precioKg = 16, prob = 12, fuerza = 0.7, aguante = 0.6, color = { 200, 120, 100 } },
	Siluro = { nombre = "Siluro", aguas = { lago = true, rio = true }, peso = { 4, 90 }, precioKg = 5, prob = 6, fuerza = 0.55, aguante = 0.85, color = { 80, 76, 70 } },
	Esturion = { nombre = "Esturión", aguas = { lago = true, rio = true }, peso = { 20, 200 }, precioKg = 22, prob = 1.2, fuerza = 0.7, aguante = 0.9, color = { 120, 120, 110 } },
	Caballa = { nombre = "Caballa", aguas = { mar = true }, peso = { 0.2, 1.6 }, precioKg = 8, prob = 30, fuerza = 0.5, aguante = 0.3, color = { 80, 120, 140 } },
	Lubina = { nombre = "Lubina", aguas = { mar = true }, peso = { 0.5, 9 }, precioKg = 15, prob = 22, fuerza = 0.55, aguante = 0.45, color = { 150, 160, 170 } },
	Bacalao = { nombre = "Bacalao", aguas = { mar = true }, peso = { 1, 40 }, precioKg = 9, prob = 14, fuerza = 0.45, aguante = 0.55, color = { 150, 140, 110 } },
	Atun = { nombre = "Atún rojo", aguas = { mar = true }, peso = { 15, 400 }, precioKg = 24, prob = 2.5, fuerza = 0.95, aguante = 0.95, color = { 60, 70, 110 } },
	PezEspada = { nombre = "Pez espada", aguas = { mar = true }, peso = { 30, 450 }, precioKg = 22, prob = 1, fuerza = 1, aguante = 0.9, color = { 70, 90, 130 } },
	BotaVieja = { nombre = "Bota vieja", aguas = { rio = true, lago = true, mar = true }, peso = { 0.4, 1 }, precioKg = 1, prob = 4, fuerza = 0, aguante = 0, basura = true, color = { 70, 56, 44 } },
}

-- Rareza según la frecuencia (para el color del aviso)
function Config.rareza(pez)
	if pez.basura then
		return "Basura", { 150, 140, 130 }
	elseif pez.prob >= 20 then
		return "Común", { 225, 225, 225 }
	elseif pez.prob >= 8 then
		return "Poco común", { 120, 220, 120 }
	elseif pez.prob >= 2 then
		return "Raro", { 110, 170, 255 }
	end
	return "Legendario", { 255, 190, 60 }
end

-- =====================================================================
--  Lo que se saca al despellejar (se vende en la tienda)
--  porKg: precio por kilo (la carne) · precio: precio por unidad (pieles, cornamentas...)
-- =====================================================================
Config.Objetos = {
	CarneCaza = { nombre = "Carne de caza menor", porKg = 7 },
	CarneVenado = { nombre = "Carne de venado", porKg = 11 },
	CarneJabali = { nombre = "Carne de jabalí", porKg = 9 },
	CarneOso = { nombre = "Carne de oso", porKg = 8 },
	PielConejo = { nombre = "Piel de conejo", precio = 6 },
	PielCiervo = { nombre = "Piel de ciervo", precio = 45 },
	Cornamenta = { nombre = "Cornamenta", precio = 70 },
	Colmillos = { nombre = "Colmillos de jabalí", precio = 30 },
	PielLobo = { nombre = "Piel de lobo", precio = 85 },
	PielOso = { nombre = "Piel de oso", precio = 220 },
	Garras = { nombre = "Garras de oso", precio = 60 },
	Plumas = { nombre = "Plumas", precio = 2 },
	Pinzas = { nombre = "Pinzas de cangrejo", precio = 8 },
}
-- Calidad de la piel según el daño que ha recibido (la escopeta y las explosiones la destrozan)
Config.CalidadPiel = { { 0.15, "Perfecta", 1.3 }, { 0.45, "Buena", 1 }, { 0.8, "Dañada", 0.5 }, { math.huge, "Destrozada", 0 } }

--[[
	ANIMALES (medidas y pesos reales)
	tipo: "presa" (huye), "neutral" (se defiende si le hieres o te acercas mucho), "depredador" (te caza)
	peso: kilos · rendimiento: parte del peso que es carne · vida (con el peso medio)
	andar / correr: m/s · huida / agresion: metros a los que reacciona · dano y espera: su ataque
	cantidad: cuántos hay en el mapa · grupo: tamaño de la manada
	donde: "prado", "bosque", "norte", "montana", "granja", "agua" (lagos y ríos), "playa"
	carne: objeto de carne · botin: otros objetos (piel, cornamenta...) · reaparicion: segundos
]]
Config.Animales = {
	Conejo = { nombre = "Conejo", tipo = "presa", peso = { 1, 2.4 }, rendimiento = 0.5, vida = 10, andar = 1.2, correr = 11, huida = 14,
		cantidad = 28, donde = "prado", carne = "CarneCaza", botin = { PielConejo = 1 }, reaparicion = 90 },
	Ciervo = { nombre = "Ciervo", tipo = "presa", peso = { 45, 120 }, rendimiento = 0.45, vida = 100, andar = 1.4, correr = 13, huida = 40,
		cantidad = 24, grupo = 2, donde = "bosque", carne = "CarneVenado", botin = { PielCiervo = 1 }, macho = { Cornamenta = 1 }, reaparicion = 150 },
	Pavo = { nombre = "Pavo salvaje", tipo = "presa", peso = { 4, 11 }, rendimiento = 0.55, vida = 14, andar = 1, correr = 7, huida = 22,
		cantidad = 16, grupo = 3, donde = "granja", carne = "CarneCaza", botin = { Plumas = 6 }, reaparicion = 90 },
	Jabali = { nombre = "Jabalí", tipo = "neutral", peso = { 50, 140 }, rendimiento = 0.5, vida = 130, andar = 1.3, correr = 10, huida = 0,
		agresion = 5, dano = 18, espera = 1.3, cantidad = 14, grupo = 2, donde = "bosque", carne = "CarneJabali", botin = { Colmillos = 1 },
		reaparicion = 150 },
	Lobo = { nombre = "Lobo gris", tipo = "depredador", peso = { 30, 65 }, rendimiento = 0, vida = 75, andar = 1.8, correr = 11, agresion = 35,
		dano = 9, espera = 1.5, cantidad = 12, grupo = 3, donde = "norte", botin = { PielLobo = 1 }, reaparicion = 180 },
	Oso = { nombre = "Oso pardo", tipo = "depredador", peso = { 150, 380 }, rendimiento = 0.4, vida = 420, andar = 1.3, correr = 10, agresion = 25,
		dano = 42, espera = 1.7, cantidad = 6, donde = "montana", carne = "CarneOso", botin = { PielOso = 1, Garras = 1 }, reaparicion = 300 },
	Pato = { nombre = "Ánade real", tipo = "presa", peso = { 0.9, 1.5 }, rendimiento = 0.6, vida = 8, andar = 0.6, correr = 3, huida = 18,
		cantidad = 18, grupo = 3, donde = "agua", carne = "CarneCaza", botin = { Plumas = 3 }, reaparicion = 90 },
	Cangrejo = { nombre = "Cangrejo de mar", tipo = "presa", peso = { 0.3, 1.2 }, rendimiento = 0.3, vida = 6, andar = 0.4, correr = 1.6, huida = 4,
		cantidad = 16, donde = "playa", carne = "CarneCaza", botin = { Pinzas = 2 }, reaparicion = 90 },
}
-- Los animales solo se mueven si hay algún jugador a menos de estos metros (ahorra servidor)
Config.DistanciaActiva = 160

return Config
]=]
local CAZA_SERVIDOR = [=[
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
]=]
local CAZA_CLIENTE = [=[
--[[
	CazaCliente (va en StarterPlayer > StarterPlayerScripts, con sus módulos dentro).

	Controles:
	  Armas de fuego, arco y ballesta: clic para disparar (mantén pulsado con las automáticas),
	    clic derecho para apuntar (las de mira muestran la mira telescópica), R para recargar.
	    Con un arma a distancia la cámara se pone por encima del hombro y el ratón queda en el centro.
	  Cuerpo a cuerpo: clic para golpear. Molotov y granada: clic para lanzar donde apuntas.
	  C: agacharse (los animales te detectan mucho menos) · Mayús: correr (haces más ruido) · B: mochila.
	  Caña: clic para lanzar donde apuntas, clic otra vez para recoger. Cuando el corcho se hunde: clic
	    para clavar. Luego mantén pulsado para recoger sedal y suéltalo cuando la tensión esté en rojo.
	En móvil: toca para disparar o lanzar y usa los botones de la pantalla.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("CazaConfig"))
local remotos = ReplicatedStorage:WaitForChild("CazaRemotos")
local Accion = remotos:WaitForChild("Accion")
local PescaR = remotos:WaitForChild("Pesca")
local EfectosR = remotos:WaitForChild("Efectos")
local Aviso = remotos:WaitForChild("Aviso")
local Estado = remotos:WaitForChild("Estado")
local Tienda = remotos:WaitForChild("Tienda")
local Pantalla = require(script:WaitForChild("Pantalla"))
local Efectos = require(script:WaitForChild("Efectos"))

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local M = Config.StudsPorMetro
local FOV = 70
local VELOCIDAD = { normal = 16, agachado = 7, corriendo = 24 }
local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

Pantalla.crear(Config)
Efectos.iniciar(Config)

local e = {
	tool = nil, id = nil, cfg = nil, cana = nil, tirador = false, apuntando = false, disparando = false,
	agachado = false, corriendo = false, ultimo = 0, retroceso = 0, floracion = 0, datos = nil, conexiones = {},
}
local pesca = { fase = nil }

local function humanoide()
	local char = jugador.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

local function sonido(id, volumen)
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volumen or 0.8
		s.Parent = SoundService
		s:Play()
		game:GetService("Debris"):AddItem(s, 6)
	end
end

-- =====================================================================
--  Hacia dónde apuntas
-- =====================================================================
local paramsMira = RaycastParams.new()
paramsMira.FilterType = Enum.RaycastFilterType.Exclude
local function puntoApuntado()
	local excluir = { jugador.Character }
	for _, n in ipairs({ "EfectosLocales", "EfectosCaza", "Corchos", "RastrosSangre" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	paramsMira.FilterDescendantsInstances = excluir
	local pantalla
	if e.tirador or esMovil then
		pantalla = camara.ViewportSize / 2
	else
		pantalla = UserInputService:GetMouseLocation()
	end
	local rayo = camara:ViewportPointToRay(pantalla.X, pantalla.Y)
	local res = workspace:Raycast(rayo.Origin, rayo.Direction * 3000, paramsMira)
	return res and res.Position or (rayo.Origin + rayo.Direction * 3000)
end

-- =====================================================================
--  Movimiento: agacharse y correr
-- =====================================================================
local function aplicarVelocidad()
	local hum = humanoide()
	if not hum then
		return
	end
	if e.agachado then
		hum.WalkSpeed = VELOCIDAD.agachado
	elseif e.corriendo and not e.apuntando then
		hum.WalkSpeed = VELOCIDAD.corriendo
	else
		hum.WalkSpeed = VELOCIDAD.normal
	end
	local hombro = e.tirador and Vector3.new(1.6, 0.4, 0) or Vector3.new()
	hum.CameraOffset = hombro + (e.agachado and Vector3.new(0, -1.3, 0) or Vector3.new())
end

local function agacharse(valor)
	if valor == nil then
		valor = not e.agachado
	end
	e.agachado = valor
	Accion:FireServer("agachado", valor)
	aplicarVelocidad()
	Pantalla.aviso(valor and "Agachado: te detectan mucho menos" or "De pie", Color3.fromRGB(190, 190, 180), 1.5)
end

-- =====================================================================
--  Armas
-- =====================================================================
local function reserva()
	local cfg = e.cfg
	return (cfg and cfg.municion) and (jugador:GetAttribute("Municion_" .. cfg.municion) or 0) or 0
end

local function refrescarArma()
	if not e.tool then
		Pantalla.arma(nil)
		return
	end
	if e.cana then
		Pantalla.arma(e.cana.nombre, string.format("%d m", e.cana.distancia), "Clic: lanzar · clic otra vez: recoger")
		return
	end
	local cfg = e.cfg
	if cfg.tipo == "cuerpo" then
		Pantalla.arma(cfg.nombre, "", "Clic: golpear · C: agacharse")
	elseif cfg.tipo == "lanzable" then
		Pantalla.arma(cfg.nombre, "x" .. reserva(), "Clic: lanzar donde apuntas")
	else
		local linea
		if e.tool:GetAttribute("Recargando") then
			linea = "Recargando…"
		else
			linea = string.format("%d / %d", e.tool:GetAttribute("Cargador") or 0, reserva())
		end
		Pantalla.arma(cfg.nombre, linea, esMovil and "Toca: disparar" or "Clic: disparar · clic der.: apuntar · R: recargar")
	end
end

local function disparar()
	local cfg = e.cfg
	if not cfg or not e.tool then
		return
	end
	local t = os.clock()
	if t - e.ultimo < cfg.cadencia then
		return
	end
	if cfg.tipo == "cuerpo" then
		e.ultimo = t
		Accion:FireServer("golpear", e.id, camara.CFrame.LookVector)
		return
	end
	if cfg.tipo == "lanzable" then
		e.ultimo = t
		Accion:FireServer("lanzar", e.id, puntoApuntado())
		return
	end
	if e.tool:GetAttribute("Recargando") then
		return
	end
	if (e.tool:GetAttribute("Cargador") or 0) <= 0 then
		e.ultimo = t
		sonido(Config.Sonidos.Vacio, 0.6)
		if reserva() > 0 then
			Accion:FireServer("recargar", e.id)
		else
			Pantalla.aviso("Sin munición: compra " .. Config.Municion[cfg.municion].nombre:lower() .. " en una tienda de caza", Color3.fromRGB(230, 120, 100), 3)
		end
		return
	end
	e.ultimo = t
	Accion:FireServer("disparar", e.id, puntoApuntado(), e.apuntando)
	e.retroceso = e.retroceso + (cfg.retroceso or 0)
	e.floracion = math.min(e.floracion + (cfg.dispersion or 0) * 1.2, 8)
end

local function recargar()
	if e.cfg and e.cfg.cargador and e.tool and not e.tool:GetAttribute("Recargando") then
		Accion:FireServer("recargar", e.id)
	end
end

local function apuntar(valor)
	if not e.cfg or e.cfg.tipo == "cuerpo" then
		valor = false
	end
	e.apuntando = valor
	aplicarVelocidad()
end

-- =====================================================================
--  Pesca
-- =====================================================================
local pelea
local tocando = false

local function terminarPesca(texto, color)
	pesca.fase = nil
	pelea = nil
	Pantalla.pesca(false)
	if texto then
		Pantalla.aviso(texto, color, 4)
	end
end

local function clicCana()
	if pesca.fase == nil then
		pesca.fase = "lanzando"
		Pantalla.pesca(true, "Lanzando…", "")
		Pantalla.tension(nil)
		PescaR:FireServer("lanzar", puntoApuntado())
	elseif pesca.fase == "esperando" then
		PescaR:FireServer("recoger")
		terminarPesca()
	elseif pesca.fase == "picando" then
		pesca.fase = "clavando"
		PescaR:FireServer("clavar")
	end
end

-- Pelea con el pez: el pez tira en arrancadas y se cansa. Recoges manteniendo pulsado; con mucha tensión
-- el sedal se rompe y si sueltas demasiado sedal el pez se escapa.
local function empezarPelea(d)
	pesca.fase = "luchando"
	pelea = {
		dist = d.distancia, inicial = d.distancia, tension = 0.15, aguante = 1, tirando = false, siguiente = os.clock() + 0.6,
		fin = 0, d = d, t0 = os.clock(),
	}
	Pantalla.pesca(true, d.grande and "¡Algo grande ha picado!" or "¡Clavado!", "")
	Pantalla.tension(0.15)
end

local function actualizarPelea(dt)
	local p = pelea
	local d = p.d
	local t = os.clock()
	local pulsado = tocando or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	-- Arrancadas del pez (más largas y seguidas cuanto más fuerte y fresco está)
	if d.basura then
		p.tirando = false
	elseif not p.tirando and t >= p.siguiente then
		p.tirando = true
		p.fin = t + (0.6 + 1.8 * d.fuerza * p.aguante) * (0.6 + math.random() * 0.8)
	elseif p.tirando and t >= p.fin then
		p.tirando = false
		p.siguiente = t + (1 + 2.2 * (1 - d.fuerza)) * (0.6 + math.random() * 0.8)
	end
	local potencia = (0.25 + d.fuerza * 0.75) * math.min(1.6, d.ratio * 0.9 + 0.35) * (0.35 + 0.65 * p.aguante)
	if d.basura then
		potencia = 0.06
	end
	if pulsado then
		p.dist = p.dist - d.recogida * dt * (p.tirando and 0.25 or 1)
		p.tension = p.tension + (p.tirando and potencia * 1.1 or (0.12 + potencia * 0.2)) * dt
		if p.tirando then
			p.aguante = math.max(0, p.aguante - dt * 0.07 * (1.25 - d.aguante))
		end
	else
		p.tension = p.tension - 0.5 * dt
		if p.tirando then
			p.dist = p.dist + d.recogida * potencia * 0.9 * dt
		end
	end
	p.tension = math.clamp(p.tension, 0, 1.05)
	local aviso = p.tirando and "¡Tira fuerte! Suelta si la tensión sube" or (pulsado and "Recogiendo…" or "Mantén pulsado para recoger")
	Pantalla.tension(p.tension, string.format("Sedal: %d m · %s", math.max(0, math.floor(p.dist / M + 0.5)), pulsado and "carrete girando" or "carrete suelto"), aviso)
	-- (la fase se cambia antes de avisar al servidor, por si la respuesta llega enseguida)
	if p.tension >= 1 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "sedal")
	elseif p.dist > p.inicial + 15 * M then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "escapado")
	elseif p.dist <= 2 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", true)
	end
end

PescaR.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "esperando" then
		pesca.fase = "esperando"
		local aguas = { rio = "río", lago = "lago", mar = "mar" }
		Pantalla.pesca(true, "Esperando a que piquen…", "Pescando en " .. (aguas[d.agua] or "agua") .. " · clic para recoger")
		Pantalla.tension(nil)
	elseif que == "sinAgua" then
		terminarPesca("Ahí no hay agua. Apunta a un río, un lago o el mar.", Color3.fromRGB(200, 200, 190))
	elseif que == "picada" then
		pesca.fase = "picando"
		Pantalla.pesca(true, "¡PICAN! Clic para clavar", "")
		sonido(Config.Sonidos.Picada, 0.9)
		Efectos.sacudir(0.25)
	elseif que == "pelea" then
		empezarPelea(d)
	elseif que == "capturado" then
		local pez = Config.Peces[d.id]
		local rareza, color = Config.rareza(pez)
		terminarPesca()
		sonido(Config.Sonidos.Captura, 0.9)
		Pantalla.aviso(string.format("%s · %s · %s (%s)%s", d.nombre, Pantalla.kg(d.peso), rareza, Pantalla.dineroTexto(d.valor), d.record and " · ¡RÉCORD!" or ""),
			Color3.fromRGB(color[1], color[2], color[3]), 6)
	elseif que == "escapado" then
		if d.motivo == "tarde" then
			pesca.fase = "esperando"
			Pantalla.pesca(true, "Esperando a que piquen…", "Se ha soltado: hay que clavar más rápido")
		else
			terminarPesca("El pez se ha escapado.", Color3.fromRGB(220, 200, 150))
		end
	elseif que == "sedalRoto" then
		sonido(Config.Sonidos.SedalRoto, 0.9)
		terminarPesca(d.motivo == "grande" and "¡Se ha roto el sedal! Ese pez es demasiado grande para esta caña." or "¡Se ha roto el sedal por la tensión!", Color3.fromRGB(230, 110, 90))
	elseif que == "recogido" then
		terminarPesca()
	end
end)

-- =====================================================================
--  Equipar y guardar herramientas
-- =====================================================================
local function desconectar()
	for _, c in ipairs(e.conexiones) do
		c:Disconnect()
	end
	e.conexiones = {}
end

local function alGuardar()
	desconectar()
	if pesca.fase then
		PescaR:FireServer("recoger")
		terminarPesca()
	end
	e.tool, e.id, e.cfg, e.cana = nil, nil, nil, nil
	e.tirador, e.disparando = false, false
	apuntar(false)
	local hum = humanoide()
	if hum then
		hum.AutoRotate = true
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	aplicarVelocidad()
	Pantalla.arma(nil)
	Pantalla.mira(false, 0)
	Pantalla.telescopica(false)
end

local function alEquipar(tool)
	alGuardar()
	local armaId, canaId = tool:GetAttribute("Arma"), tool:GetAttribute("Cana")
	if not armaId and not canaId then
		return
	end
	e.tool = tool
	if canaId then
		e.id, e.cana = canaId, Config.Canas[canaId]
		table.insert(e.conexiones, tool.Activated:Connect(clicCana))
	else
		e.id, e.cfg = armaId, Config.Armas[armaId]
		e.tirador = e.cfg.tipo ~= "cuerpo"
		local hum = humanoide()
		if hum and e.tirador and not esMovil then
			hum.AutoRotate = false
		end
		table.insert(e.conexiones, tool.Activated:Connect(function()
			e.disparando = true
			disparar()
		end))
		table.insert(e.conexiones, tool.Deactivated:Connect(function()
			e.disparando = false
		end))
		for _, atributo in ipairs({ "Cargador", "Recargando" }) do
			table.insert(e.conexiones, tool:GetAttributeChangedSignal(atributo):Connect(refrescarArma))
		end
		if e.cfg.municion then
			table.insert(e.conexiones, jugador:GetAttributeChangedSignal("Municion_" .. e.cfg.municion):Connect(refrescarArma))
		end
	end
	aplicarVelocidad()
	refrescarArma()
end

local function conectarPersonaje(char)
	e.agachado, e.corriendo = false, false
	alGuardar()
	char.ChildAdded:Connect(function(h)
		if h:IsA("Tool") then
			alEquipar(h)
		end
	end)
	char.ChildRemoved:Connect(function(h)
		if h == e.tool then
			alGuardar()
		end
	end)
end
if jugador.Character then
	conectarPersonaje(jugador.Character)
end
jugador.CharacterAdded:Connect(conectarPersonaje)

-- =====================================================================
--  Teclas y botones
-- =====================================================================
UserInputService.InputBegan:Connect(function(input, procesado)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = true
	end
	if procesado then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(true)
	elseif input.KeyCode == Enum.KeyCode.R then
		recargar()
	elseif input.KeyCode == Enum.KeyCode.C then
		agacharse()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = true
		aplicarVelocidad()
	elseif input.KeyCode == Enum.KeyCode.B then
		Pantalla.alternarMochila()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = false
		aplicarVelocidad()
	end
end)

if esMovil then
	local botones
	botones = Pantalla.botonesMovil({
		{ "recargar", "Recargar", recargar },
		{ "apuntar", "Apuntar", function()
			apuntar(not e.apuntando)
			botones.apuntar.Text = e.apuntando and "Dejar" or "Apuntar"
		end },
		{ "agachar", "Agacharse", function()
			agacharse()
			botones.agachar.Text = e.agachado and "Levantarse" or "Agacharse"
		end },
		{ "mochila", "Mochila", Pantalla.alternarMochila },
	})
end

-- =====================================================================
--  Mensajes del servidor
-- =====================================================================
local ultimoAtaque = 0
Aviso.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "acierto" then
		Pantalla.acierto(d.estado == "muerto", d.zona == "Cabeza")
		if d.estado == "muerto" and d.zona == "Cabeza" then
			Pantalla.aviso("¡En la cabeza!", Color3.fromRGB(255, 220, 120), 2)
		end
	elseif que == "abatido" then
		Pantalla.aviso(string.format("Has abatido: %s (%s). Acércate y mantén E para despellejarlo.", d.nombre, Pantalla.kg(d.peso)), Color3.fromRGB(150, 220, 130), 6)
	elseif que == "botin" then
		local partes = {}
		for _, b in ipairs(d.botin or {}) do
			local cant = (b.unidad == "kg") and Pantalla.kg(b.cantidad) or ("x" .. b.cantidad)
			table.insert(partes, string.format("%s %s%s", b.nombre, cant, b.calidad and (" (" .. b.calidad .. ")") or ""))
		end
		Pantalla.aviso("Botín: " .. ((#partes > 0) and table.concat(partes, " · ") or "nada aprovechable"), Color3.fromRGB(236, 200, 110), 6)
	elseif que == "atacado" then
		Pantalla.herido()
		Efectos.sacudir(0.9)
		if os.clock() - ultimoAtaque > 3 then
			ultimoAtaque = os.clock()
			Pantalla.aviso("¡Te ataca un " .. d.nombre:lower() .. "!", Color3.fromRGB(240, 90, 80), 2.5)
		end
	elseif que == "vacio" then
		sonido(Config.Sonidos.Vacio, 0.6)
	elseif que == "sinMunicion" then
		local m = Config.Municion[d.municion]
		Pantalla.aviso("No te quedan " .. (m and m.nombre:lower() or "balas") .. ". Cómpralos en una tienda de caza.", Color3.fromRGB(230, 120, 100), 4)
	elseif que == "venta" then
		Pantalla.aviso(string.format("Has vendido %d cosas por %s", d.n, Pantalla.dineroTexto(d.total)), Color3.fromRGB(236, 200, 90), 5)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "compra" then
		Pantalla.aviso(string.format("Has comprado: %s (-%s)", d.nombre, Pantalla.dineroTexto(d.precio)), Color3.fromRGB(236, 200, 90), 4)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "mensaje" then
		Pantalla.aviso(d.texto, Color3.fromRGB(230, 226, 214), 4)
	end
end)

Estado.OnClientEvent:Connect(function(datos)
	e.datos = datos
	Pantalla.estado(datos)
	refrescarArma()
end)

local tiendaEn
Tienda.OnClientEvent:Connect(function(que, d)
	if que == "abrir" then
		local _, hrp = humanoide()
		tiendaEn = hrp and hrp.Position
		Pantalla.abrirTienda(d and d.nombre, function(tipo, id)
			Accion:FireServer("comprar", tipo, id)
		end, function()
			Accion:FireServer("vender")
		end)
	end
end)

-- Pide el dinero y la mochila al arrancar (por si el servidor los mandó antes de que este script escuchara)
Accion:FireServer("estado")

EfectosR.OnClientEvent:Connect(function(que, d)
	local f = Efectos[que]
	if f and type(d) == "table" then
		f(d, camara.CFrame.Position)
	end
end)

-- =====================================================================
--  Bucles
-- =====================================================================
-- Después de la cámara de Roblox: hombro, giro del personaje con la cámara, zoom, retroceso y temblor
RunService:BindToRenderStep("CazaCamara", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local hum, hrp = humanoide()
	if e.tirador and hrp and hum and hum.Health > 0 then
		if not esMovil then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		local mirada = camara.CFrame.LookVector
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-mirada.X, -mirada.Z), 0)
	end
	local objetivo = (e.apuntando and e.cfg) and (e.cfg.zoom or 55) or FOV
	camara.FieldOfView = camara.FieldOfView + (objetivo - camara.FieldOfView) * math.min(1, dt * 12)
	UserInputService.MouseDeltaSensitivity = math.clamp(camara.FieldOfView / FOV, 0.15, 1)
	if e.retroceso > 0.01 then
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad(e.retroceso), 0, 0)
		e.retroceso = e.retroceso * math.exp(-dt * 14)
	end
	Efectos.camara(dt, camara)
end)

RunService.RenderStepped:Connect(function(dt)
	Efectos.actualizar(dt)
	Efectos.peces(dt, camara.CFrame.Position)
	if pesca.fase == "luchando" and pelea then
		actualizarPelea(dt)
	end
	if e.disparando and e.cfg and e.cfg.automatica then
		disparar()
	end
	-- Mira: se abre con la dispersión real del arma (más al moverte, menos agachado o apuntando)
	local cfg = e.cfg
	local conMira = e.tirador and cfg and (cfg.tipo ~= "lanzable")
	local tele = conMira and cfg.mira and e.apuntando and camara.FieldOfView < (cfg.zoom or 55) + 6
	Pantalla.telescopica(tele == true)
	if conMira and not tele then
		local _, hrp = humanoide()
		local disp = (cfg.dispersion or 0) + e.floracion
		if hrp and hrp.AssemblyLinearVelocity.Magnitude > 3 then
			disp = disp * 2
		end
		if e.agachado then
			disp = disp * 0.6
		end
		if e.apuntando then
			disp = disp * 0.5
		end
		local px = math.tan(math.rad(disp)) / math.tan(math.rad(camara.FieldOfView / 2)) * camara.ViewportSize.Y / 2
		Pantalla.mira(true, px)
	else
		Pantalla.mira(false, 0)
	end
	e.floracion = e.floracion * math.exp(-dt * 5)
	-- La tienda se cierra si te alejas
	if Pantalla.tiendaAbierta() and tiendaEn then
		local _, hrp = humanoide()
		if not hrp or (hrp.Position - tiendaEn).Magnitude > 25 then
			Pantalla.cerrarTienda()
		end
	end
end)

-- Las articulaciones de los animales se mueven antes de la física de cada fotograma
RunService.Stepped:Connect(function(_, dt)
	Efectos.animar(dt, camara.CFrame.Position)
end)
]=]
local CAZA_SERVIDOR_MODULOS, CAZA_CLIENTE_MODULOS = {}, {}
CAZA_SERVIDOR_MODULOS["Modelos"] = [=[
--[[
	Modelos de la caza y la pesca (los construye el servidor):
	  · Animales a tamaño real (1 metro = 2,9 studs) hechos con formas orgánicas (elipsoides) y con
	    articulaciones (Motor6D) en caderas, rodillas, cuello y cola para que el cliente los anime al andar,
	    correr o pastar. Cada pieza lleva el atributo "Zona" (Cabeza, Cuello, Pecho, Cuerpo, Pata, Cola)
	    para el daño según dónde acierta el disparo.
	  · Armas y cañas de pescar como herramientas (Tool) con piezas detalladas.
	  · El corcho de la caña y las manchas del rastro de sangre.
	Los animales se construyen mirando hacia -Z con la raíz en el centro del cuerpo; "altura" es la
	distancia de la raíz al suelo.
]]
local Modelos = {}

local ZERO = CFrame.new()
local NEGRO = { 26, 24, 22 }

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function giroDe(rot)
	if not rot then
		return ZERO
	end
	return CFrame.fromEulerAnglesYXZ(math.rad(rot[1] or 0), math.rad(rot[2] or 0), math.rad(rot[3] or 0))
end

local function mezclar(t, extra)
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

-- =====================================================================
--  Piezas: E elipsoide, B bloque, W cuña, S bola, C cilindro (eje x/y/z), R cilindro entre dos puntos
-- =====================================================================
local function E(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), elipse = true }, x)
end
local function B(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot) }, x)
end
local function W(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), clase = "WedgePart" }, x)
end
local function S(nombre, d, pos, color, x)
	return mezclar({ nombre = nombre, tam = { d, d, d }, pos = pos, color = color, giro = ZERO, forma = "Ball" }, x)
end
local EJES = { x = ZERO, y = CFrame.Angles(0, 0, math.rad(90)), z = CFrame.Angles(0, math.rad(90), 0) }
local function C(nombre, d, largo, eje, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = { largo, d, d }, pos = pos, color = color, giro = giroDe(rot) * EJES[eje], forma = "Cylinder" }, x)
end
local function R(nombre, a, b, d, color, x)
	local va, vb = Vector3.new(a[1], a[2], a[3]), Vector3.new(b[1], b[2], b[3])
	local dir = vb - va
	local arriba = (math.abs(dir.Unit.Y) > 0.98) and Vector3.new(0, 0, -1) or Vector3.new(0, 1, 0)
	local m = (va + vb) / 2
	return mezclar({
		nombre = nombre, tam = { dir.Magnitude, d, d }, pos = { m.X, m.Y, m.Z }, color = color, forma = "Cylinder",
		giro = CFrame.lookAt(Vector3.new(0, 0, 0), dir, arriba) * CFrame.Angles(0, math.rad(90), 0),
	}, x)
end

-- Los dos lados (izquierda y derecha) de una pieza simétrica
local function par(lista, hacer)
	table.insert(lista, hacer(1))
	table.insert(lista, hacer(-1))
end

local function fabricar(sp, s)
	local part = Instance.new(sp.clase or "Part")
	part.Name = sp.nombre
	if sp.forma then
		part.Shape = Enum.PartType[sp.forma]
	end
	part.Size = Vector3.new(sp.tam[1] * s, sp.tam[2] * s, sp.tam[3] * s)
	part.CFrame = CFrame.new(sp.pos[1] * s, sp.pos[2] * s, sp.pos[3] * s) * sp.giro
	part.Color = rgb(sp.color)
	part.Material = Enum.Material[sp.mat or "SmoothPlastic"]
	if sp.trans then
		part.Transparency = sp.trans
	end
	if sp.refl then
		part.Reflectance = sp.refl
	end
	if sp.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = sp.sombra ~= false
	if sp.zona then
		part:SetAttribute("Zona", sp.zona)
	end
	return part
end

local function soldar(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Articulación: el cliente gira Motor6D.Transform alrededor del punto "junta" (en studs, ejes del animal)
local function articular(nombre, padre, hijo, junta)
	local j = CFrame.new(junta)
	local m = Instance.new("Motor6D")
	m.Name = nombre
	m.Part0 = padre
	m.Part1 = hijo
	m.C0 = padre.CFrame:Inverse() * j
	m.C1 = hijo.CFrame:Inverse() * j
	m.Parent = hijo
	return m
end

-- =====================================================================
--  Animales (medidas en studs para el peso medio; se escalan según el peso de cada ejemplar)
--  patas: ancho (separación), delante/detras (z de las caderas), cadera (altura de la cadera respecto a
--  la raíz), largoMuslo, muslo/muslo2 (tamaño delante/detrás), grosorCana, pezuna (pie o pezuña)
-- =====================================================================
local ANIMALES = {}

ANIMALES.Ciervo = function(op)
	local pelo = (op.variante == 1) and { 150, 108, 70 } or { 132, 98, 66 }
	local claro, oscuro, asta = { 226, 214, 196 }, { 92, 70, 52 }, { 206, 190, 158 }
	local cabeza = {
		E("Cuello", { 0.5, 1.85, 0.68 }, { 0, 1.0, -1.85 }, pelo, { -35, 0, 0 }, { zona = "Cuello" }),
		E("Garganta", { 0.36, 0.36, 0.3 }, { 0, 1.5, -2.2 }, claro, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.52, 0.56, 1.0 }, { 0, 1.95, -2.38 }, pelo, { -15, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.34, 0.36, 0.55 }, { 0, 1.8, -2.82 }, oscuro, { -15, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.17, { 0, 1.79, -3.07 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.25 * k, 2.03, -2.46 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.1, 0.5, 0.3 }, { 0.36 * k, 2.3, -2.12 }, pelo, { 0, 0, -40 * k }, { zona = "Cabeza" })
	end)
	if op.macho then
		-- Cornamenta: rama principal curvada con tres puntas por lado
		for _, k in ipairs({ 1, -1 }) do
			local p0, p1, p2, p3 = { 0.2 * k, 2.25, -2.2 }, { 0.5 * k, 2.9, -2.0 }, { 0.72 * k, 3.45, -2.35 }, { 0.6 * k, 3.85, -2.85 }
			table.insert(cabeza, R("Cuerna", p0, p1, 0.15, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, p2, 0.13, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, p3, 0.11, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, { 0.45 * k, 3.45, -1.75 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, { 0.85 * k, 4.0, -2.2 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", { 0.28 * k, 2.45, -2.25 }, { 0.3 * k, 2.78, -2.62 }, 0.08, asta, { zona = "Cabeza", mat = "Wood" }))
		end
	end
	return {
		altura = 2.5, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.35, 1.7, 2.7 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.4, 1.85, 2.2 }, { 0, 0.1, -0.85 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.0, 0.75, 2.8 }, { 0, -0.55, 0 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.5, 0.26, 3.0 }, { 0, 0.73, -0.05 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Grupa", { 0.8, 0.75, 0.28 }, { 0, 0.12, 1.98 }, claro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.42, delante = -1.2, detras = 1.3, cadera = -0.35, largoMuslo = 1.15, muslo = { 0.4, 1.15, 0.52 },
			muslo2 = { 0.5, 1.35, 0.78 }, grosorMuslo = 0.26, grosorCana = 0.18, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.2, 0.16, 0.26 },
			colorPezuna = { 30, 26, 24 } },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.45, -1.45 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.75, 1.95 }, partes = {
				E("Cola", { 0.34, 0.6, 0.24 }, { 0, 0.5, 2.1 }, pelo, { 20, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.26, 0.45, 0.12 }, { 0, 0.45, 2.2 }, claro, { 20, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Lobo = function(op)
	local pelo = (op.variante == 1) and { 128, 124, 116 } or { 104, 98, 90 }
	local claro, oscuro = { 206, 200, 188 }, { 62, 58, 54 }
	local cabeza = {
		E("Cuello", { 0.72, 1.15, 0.85 }, { 0, 0.62, -1.5 }, pelo, { -38, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.72, 0.68, 0.85 }, { 0, 1.05, -2.0 }, pelo, nil, { zona = "Cabeza" }),
		E("Mejilla", { 0.8, 0.5, 0.5 }, { 0, 0.92, -2.05 }, claro, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.36, 0.36, 0.78 }, { 0, 0.9, -2.55 }, claro, { -6, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.3, 0.16, 0.6 }, { 0, 1.02, -2.6 }, pelo, { -6, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.16, { 0, 0.98, -2.94 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.22 * k, 1.18, -2.32 }, { 196, 150, 50 }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.08, 0.42, 0.3 }, { 0.25 * k, 1.5, -1.92 }, pelo, { 0, 180, 12 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 2.0, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.0, 1.2, 2.2 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.1, 1.45, 1.6 }, { 0, 0.05, -0.65 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.72, 0.5, 2.2 }, { 0, -0.42, 0.1 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.6, 0.42, 2.8 }, { 0, 0.55, 0.1 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Melena", { 1.2, 1.1, 0.9 }, { 0, 0.35, -1.15 }, pelo, nil, { zona = "Cuello" }),
		},
		patas = { ancho = 0.33, delante = -1.0, detras = 1.25, cadera = -0.2, largoMuslo = 0.85, muslo = { 0.34, 0.95, 0.44 },
			muslo2 = { 0.42, 1.05, 0.62 }, grosorMuslo = 0.22, grosorCana = 0.16, colorMuslo = pelo,
			colorCana = { pelo[1] + 26, pelo[2] + 26, pelo[3] + 26 }, pezuna = { 0.24, 0.14, 0.34 }, colorPezuna = oscuro, dedos = -0.06, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.35, -1.2 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.45, 1.75 }, partes = {
				E("Cola", { 0.42, 0.42, 1.55 }, { 0, 0.02, 2.4 }, pelo, { 38, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.3, 0.3, 0.5 }, { 0, -0.38, 2.95 }, oscuro, { 38, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Oso = function(op)
	local pelo = (op.variante == 1) and { 96, 66, 44 } or { 78, 56, 40 }
	local claro, oscuro = { 128, 96, 68 }, { 56, 40, 30 }
	local cabeza = {
		E("Cuello", { 1.5, 1.5, 1.3 }, { 0, 0.55, -2.3 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 1.45, 1.35, 1.35 }, { 0, 0.88, -2.95 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.78, 0.68, 0.9 }, { 0, 0.62, -3.58 }, claro, nil, { zona = "Cabeza" }),
		E("Nariz", { 0.42, 0.3, 0.25 }, { 0, 0.8, -3.98 }, NEGRO, nil, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.14, { 0.36 * k, 1.15, -3.45 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Oreja", 0.46, { 0.56 * k, 1.55, -2.82 }, pelo, { zona = "Cabeza" })
	end)
	return {
		altura = 2.3, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 2.4, 2.6, 3.3 }, { 0, 0.1, 0.9 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 2.5, 2.8, 2.6 }, { 0, 0.25, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Joroba", { 1.8, 1.0, 1.8 }, { 0, 1.2, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.8, 1.0, 3.6 }, { 0, -0.8, 0 }, oscuro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.45, { 0, 0.6, 2.5 }, pelo, { zona = "Cola" }),
		},
		patas = { ancho = 0.85, delante = -1.6, detras = 1.7, cadera = -0.4, largoMuslo = 1.1, muslo = { 0.72, 1.4, 1.0 },
			muslo2 = { 0.8, 1.5, 1.25 }, grosorMuslo = 0.85, grosorCana = 0.74, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.92, 0.44, 1.15 },
			colorPezuna = oscuro, dedos = -0.12, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.6, -2.0 }, partes = cabeza },
		},
	}
end

ANIMALES.Jabali = function(op)
	local pelo = (op.variante == 1) and { 72, 60, 52 } or { 88, 72, 58 }
	local oscuro, hocico, colmillo = { 44, 38, 34 }, { 112, 92, 86 }, { 236, 228, 210 }
	local cabeza = {
		E("Cuello", { 0.95, 1.05, 0.75 }, { 0, 0.25, -1.55 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.58, 0.72, 1.75 }, { 0, -0.06, -2.25 }, pelo, { 22, 0, 0 }, { zona = "Cabeza" }),
		E("Frente", { 0.5, 0.5, 0.9 }, { 0, 0.2, -1.95 }, oscuro, { 22, 0, 0 }, { zona = "Cabeza" }),
		C("Hocico", 0.32, 0.12, "z", { 0, -0.4, -3.02 }, hocico, { 22, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return W("Colmillo", { 0.07, 0.28, 0.11 }, { 0.17 * k, -0.3, -2.74 }, colmillo, { -30, 0, 14 * k }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Ojo", 0.1, { 0.3 * k, 0.25, -2.25 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.1, 0.36, 0.26 }, { 0.3 * k, 0.55, -1.85 }, oscuro, { 0, 180, 18 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 1.7, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.25, 1.5, 2.1 }, { 0, 0, 0.6 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.35, 1.75, 1.75 }, { 0, 0.12, -0.75 }, pelo, nil, { zona = "Pecho" }),
			E("Crin", { 0.26, 0.36, 2.4 }, { 0, 0.84, -0.3 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Vientre", { 0.95, 0.6, 2.4 }, { 0, -0.5, 0 }, oscuro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.38, delante = -1.05, detras = 1.15, cadera = -0.35, largoMuslo = 0.65, muslo = { 0.4, 0.8, 0.5 },
			muslo2 = { 0.46, 0.85, 0.64 }, grosorMuslo = 0.24, grosorCana = 0.16, colorMuslo = pelo, colorCana = oscuro, pezuna = { 0.22, 0.15, 0.26 },
			colorPezuna = NEGRO },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.25, -1.35 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.3, 1.62 }, partes = {
				R("Cola", { 0, 0.3, 1.62 }, { 0, -0.35, 1.82 }, 0.08, oscuro, { zona = "Cola" }),
				E("Cola", { 0.14, 0.26, 0.14 }, { 0, -0.42, 1.84 }, oscuro, nil, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Conejo = function(op)
	local pelo = (op.variante == 1) and { 132, 114, 92 } or { 112, 98, 82 }
	local claro = { 228, 222, 210 }
	local cabeza = {
		E("Cabeza", { 0.38, 0.36, 0.46 }, { 0, 0.32, -0.5 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.2, 0.18, 0.16 }, { 0, 0.26, -0.72 }, claro, nil, { zona = "Cabeza" }),
		S("Nariz", 0.06, { 0, 0.3, -0.79 }, { 170, 120, 120 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.08, { 0.17 * k, 0.39, -0.55 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.07, 0.5, 0.16 }, { 0.08 * k, 0.72, -0.38 }, pelo, { 18, 0, -10 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 0.42, mat = "Fabric", salta = true,
		cuerpo = {
			E("Cuerpo", { 0.62, 0.68, 0.85 }, { 0, 0, 0.12 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 0.55, 0.6, 0.5 }, { 0, 0.04, -0.24 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.42, 0.3, 0.7 }, { 0, -0.2, 0 }, claro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.22, { 0, 0.16, 0.54 }, claro, { zona = "Cola" }),
		},
		patas = { ancho = 0.17, ancho2 = 0.22, delante = -0.26, detras = 0.22, cadera = -0.08, largoMuslo = 0.22, muslo = { 0.12, 0.28, 0.14 },
			muslo2 = { 0.2, 0.42, 0.5 }, grosorCana = 0.07, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.1, 0.07, 0.3 },
			colorPezuna = pelo, dedos = -0.08, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.15, -0.32 }, partes = cabeza },
		},
	}
end

ANIMALES.Pavo = function(op)
	local plumas = { 62, 48, 38 }
	local bronce, cabezaC, rojo, pata = { 92, 70, 48 }, { 150, 172, 196 }, { 176, 52, 46 }, { 170, 132, 120 }
	local cuello = {
		E("Cuello", { 0.22, 0.85, 0.26 }, { 0, 0.85, -0.75 }, { 120, 92, 88 }, { -12, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.26, 0.28, 0.32 }, { 0, 1.3, -0.86 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Moco", { 0.07, 0.24, 0.07 }, { 0, 1.24, -1.04 }, rojo, nil, { zona = "Cabeza" }),
		E("Barba", { 0.13, 0.32, 0.13 }, { 0, 1.06, -0.93 }, rojo, nil, { zona = "Cabeza" }),
		W("Pico", { 0.09, 0.09, 0.2 }, { 0, 1.27, -1.06 }, { 200, 180, 150 }, { 0, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.11 * k, 1.36, -0.92 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 1.25, 1.2, 1.5 }, { 0, 0, 0.1 }, plumas, nil, { zona = "Cuerpo" }),
		E("Pecho", { 1.0, 1.1, 0.85 }, { 0, 0.12, -0.55 }, bronce, nil, { zona = "Pecho" }),
		E("Cola", { 0.95, 0.3, 1.15 }, { 0, -0.02, 0.95 }, plumas, { 25, 0, 0 }, { zona = "Cola" }),
		E("Cola", { 0.86, 0.1, 0.32 }, { 0, -0.22, 1.42 }, { 196, 176, 140 }, { 25, 0, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.24, 0.78, 1.25 }, { 0.6 * k, 0.04, 0.12 }, { 76, 62, 48 }, { 0, 0, 6 * k }, { zona = "Cuerpo" })
	end)
	return {
		altura = 1.4, mat = "Fabric", cuerpo = cuerpo,
		piernas = { ancho = 0.25, cadera = -0.35, z = 0.05, grosor = 0.12, color = pata },
		juntas = { { nombre = "Cuello", junta = { 0, 0.45, -0.6 }, partes = cuello } },
	}
end

ANIMALES.Pato = function(op)
	local macho = op.macho
	local cuerpoC = macho and { 150, 146, 140 } or { 140, 112, 82 }
	local cabezaC = macho and { 34, 92, 52 } or { 120, 94, 66 }
	local pechoC = macho and { 104, 66, 48 } or { 132, 104, 76 }
	local cuello = {
		E("Cuello", { 0.28, 0.45, 0.3 }, { 0, 0.55, -0.66 }, cabezaC, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.36, 0.38, 0.5 }, { 0, 0.85, -0.76 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Pico", { 0.18, 0.08, 0.38 }, { 0, 0.78, -1.1 }, { 214, 176, 60 }, nil, { zona = "Cabeza" }),
	}
	if macho then
		table.insert(cuello, E("Collar", { 0.31, 0.07, 0.33 }, { 0, 0.4, -0.64 }, { 236, 236, 232 }, nil, { zona = "Cuello" }))
	end
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.15 * k, 0.9, -0.88 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 0.75, 0.6, 1.4 }, { 0, 0, 0.05 }, cuerpoC, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.66, 0.55, 0.52 }, { 0, 0.12, -0.5 }, pechoC, nil, { zona = "Pecho" }),
		E("Lomo", { 0.7, 0.28, 1.1 }, { 0, 0.24, 0.12 }, macho and { 110, 100, 90 } or { 112, 88, 64 }, nil, { zona = "Cuerpo" }),
		W("Cola", { 0.3, 0.16, 0.35 }, { 0, 0.18, 0.8 }, macho and { 30, 30, 30 } or { 112, 88, 64 }, { 0, 180, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.08, 0.14, 0.32 }, { 0.36 * k, 0.16, 0.2 }, { 60, 70, 150 }, nil, { zona = "Cuerpo" })
	end)
	return { altura = 0.22, mat = "Fabric", nada = true, cuerpo = cuerpo,
		juntas = { { nombre = "Cuello", junta = { 0, 0.3, -0.55 }, partes = cuello } } }
end

ANIMALES.Cangrejo = function(op)
	local cap, oscuro = { 186, 84, 48 }, { 140, 60, 36 }
	local cuerpo = {
		E("Cuerpo", { 0.78, 0.3, 0.58 }, { 0, 0, 0 }, cap, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.5, 0.16, 0.35 }, { 0, 0.12, -0.05 }, oscuro, nil, { zona = "Pecho" }),
	}
	par(cuerpo, function(k)
		return R("Ojo", { 0.1 * k, 0.1, -0.24 }, { 0.12 * k, 0.24, -0.28 }, 0.03, oscuro, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return S("Ojo", 0.06, { 0.12 * k, 0.26, -0.28 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return R("Brazo", { 0.3 * k, 0, -0.2 }, { 0.42 * k, 0.02, -0.42 }, 0.07, cap, { zona = "Pata" })
	end)
	par(cuerpo, function(k)
		return E("Pinza", { 0.2, 0.15, 0.3 }, { 0.4 * k, 0.04, -0.56 }, cap, { 0, -20 * k, 0 }, { zona = "Pata" })
	end)
	return { altura = 0.2, mat = "SmoothPlastic", cuerpo = cuerpo, patasCangrejo = { color = oscuro } }
end

-- Patas de cuadrúpedo: cadera y rodilla articuladas, caña y pezuña
local function patas(def, s, modelo, raiz)
	local P = def.patas
	for _, lado in ipairs({ { "DI", -1, P.delante, P.muslo, P.ancho }, { "DD", 1, P.delante, P.muslo, P.ancho },
		{ "TI", -1, P.detras, P.muslo2, P.ancho2 or P.ancho }, { "TD", 1, P.detras, P.muslo2, P.ancho2 or P.ancho } }) do
		local nombre, k, z, tm, ancho = lado[1], lado[2], lado[3], lado[4], lado[5]
		local x = k * ancho
		local yRodilla = P.cadera - P.largoMuslo
		local largoCana = def.altura + yRodilla - P.pezuna[2]
		-- Pierna (hueso de la cadera) + anca musculosa que se funde con el cuerpo, caña fina y pezuña o pie
		local grosor = P.grosorMuslo or P.grosorCana * 1.5
		local pierna = fabricar(C("Pata", grosor, P.largoMuslo + 0.1, "y", { x, P.cadera - P.largoMuslo / 2, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local anca = fabricar(E("Pata", tm, { x * 0.85, P.cadera - tm[2] * 0.08, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local cana = fabricar(C("Pata", P.grosorCana, largoCana + 0.1, "y", { x, yRodilla - largoCana / 2, z }, P.colorCana, nil, { zona = "Pata" }), s)
		local forma = P.pieRedondo and E or B
		local pie = fabricar(forma("Pata", P.pezuna, { x, -def.altura + P.pezuna[2] / 2, z + (P.dedos or 0) }, P.colorPezuna, nil, { zona = "Pata" }), s)
		for _, p in ipairs({ pierna, anca, cana, pie }) do
			p.Material = Enum.Material[def.mat]
			p.Parent = modelo
		end
		if not P.pieRedondo then
			pie.Material = Enum.Material.SmoothPlastic
		end
		articular("Cadera" .. nombre, raiz, pierna, Vector3.new(x, P.cadera, z) * s)
		soldar(pierna, anca)
		articular("Rodilla" .. nombre, pierna, cana, Vector3.new(x, yRodilla, z) * s)
		soldar(cana, pie)
	end
end

-- Patas de ave (pavo): dos patas finas con tres dedos
local function piernas(def, s, modelo, raiz)
	local P = def.piernas
	for _, lado in ipairs({ { "I", -1 }, { "D", 1 } }) do
		local x = lado[2] * P.ancho
		local largo = def.altura + P.cadera
		local pierna = fabricar(C("Pata", P.grosor, largo, "y", { x, P.cadera - largo / 2, P.z }, P.color, nil, { zona = "Pata" }), s)
		pierna.Parent = modelo
		articular("Pierna" .. lado[1], raiz, pierna, Vector3.new(x, P.cadera, P.z) * s)
		for _, a in ipairs({ -30, 0, 30 }) do
			local dedo = fabricar(B("Pata", { 0.06, 0.05, 0.36 }, { x + math.sin(math.rad(a)) * -0.15, -def.altura + 0.03, P.z - math.cos(math.rad(a)) * 0.15 }, P.color, { 0, a, 0 }, { zona = "Pata" }), s)
			dedo.Parent = modelo
			soldar(pierna, dedo)
		end
	end
end

-- Patas de cangrejo: cuatro por lado, cada una articulada
local function patasCangrejo(def, s, modelo, raiz)
	local n = 0
	for _, k in ipairs({ 1, -1 }) do
		for i, z in ipairs({ -0.1, 0.04, 0.18, 0.3 }) do
			n = n + 1
			local a, c = { 0.32 * k, 0, z }, { 0.62 * k, -def.altura + 0.03, z + 0.04 * (i - 2) }
			local pata = fabricar(R("Pata", a, c, 0.05, def.patasCangrejo.color, { zona = "Pata" }), s)
			pata.Parent = modelo
			articular("Pata" .. n, raiz, pata, Vector3.new(a[1], a[2], a[3]) * s)
		end
	end
end

--[[
	Construye un animal. op: { escala, macho, variante }. Devuelve el Model (Raiz anclada en el origen,
	las demás piezas unidas a ella) y la altura de la raíz sobre el suelo en studs.
]]
function Modelos.animal(especie, op)
	op = op or {}
	local s = op.escala or 1
	local def = ANIMALES[especie](op)
	local modelo = Instance.new("Model")
	modelo.Name = especie
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Size = Vector3.new(0.4, 0.4, 0.4) * s
	raiz.Transparency = 1
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.CFrame = ZERO
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	for _, sp in ipairs(def.cuerpo) do
		local p = fabricar(sp, s)
		if sp.forma ~= "Ball" or sp.nombre == "Cola" then
			p.Material = Enum.Material[def.mat]
		end
		p.Parent = modelo
		soldar(raiz, p)
	end
	for _, j in ipairs(def.juntas or {}) do
		local hueso
		for i, sp in ipairs(j.partes) do
			local p = fabricar(sp, s)
			if sp.forma ~= "Ball" and not sp.mat and sp.nombre ~= "Pico" and sp.nombre ~= "Nariz" then
				p.Material = Enum.Material[def.mat]
			end
			p.Parent = modelo
			if i == 1 then
				hueso = p
				articular(j.nombre, raiz, p, Vector3.new(j.junta[1], j.junta[2], j.junta[3]) * s)
			else
				soldar(hueso, p)
			end
		end
	end
	if def.patas then
		patas(def, s, modelo, raiz)
	elseif def.piernas then
		piernas(def, s, modelo, raiz)
	elseif def.patasCangrejo then
		patasCangrejo(def, s, modelo, raiz)
	end
	modelo:SetAttribute("Especie", especie)
	modelo:SetAttribute("Escala", s)
	if def.salta then
		modelo:SetAttribute("Salta", true)
	end
	if def.nada then
		modelo:SetAttribute("Nada", true)
	end
	pcall(function()
		modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	return modelo, def.altura * s
end

-- =====================================================================
--  Armas y cañas (en el espacio del mango: -Z hacia delante, +Y hacia arriba, origen en la mano)
-- =====================================================================
local ACERO, PAVONADO, POLIMERO, NOGAL, MADERA = { 176, 178, 184 }, { 44, 46, 50 }, { 34, 34, 36 }, { 104, 66, 40 }, { 150, 108, 66 }
local VERDE_OLIVA = { 76, 80, 62 }

local HERRAMIENTAS = {}

HERRAMIENTAS.Cuchillo = function()
	return { partes = {
		B("Mango", { 0.17, 0.24, 0.52 }, { 0, 0, 0.02 }, POLIMERO, nil, { mat = "Fabric" }),
		B("Guarda", { 0.3, 0.06, 0.06 }, { 0, 0, -0.27 }, PAVONADO, nil, { mat = "Metal" }),
		B("Hoja", { 0.04, 0.2, 0.52 }, { 0, 0.02, -0.56 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		W("Hoja", { 0.04, 0.2, 0.22 }, { 0, 0.02, -0.93 }, ACERO, { 0, 0, 180 }, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Bate = function()
	return { partes = {
		C("Mango", 0.17, 0.6, "z", { 0, 0, 0 }, MADERA, nil, { mat = "Wood" }),
		C("Pomo", 0.24, 0.08, "z", { 0, 0, 0.32 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.22, 0.8, "z", { 0, 0, -0.68 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.29, 0.8, "z", { 0, 0, -1.45 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.35, 0.95, "z", { 0, 0, -2.3 }, MADERA, nil, { mat = "Wood" }),
		S("Bate", 0.35, { 0, 0, -2.78 }, MADERA, { mat = "Wood" }),
		C("Cinta", 0.18, 0.45, "z", { 0, 0, -0.05 }, { 30, 30, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Machete = function()
	return { partes = {
		B("Mango", { 0.18, 0.26, 0.58 }, { 0, 0, 0.04 }, { 40, 40, 40 }, nil, { mat = "Fabric" }),
		B("Hoja", { 0.04, 0.3, 1.4 }, { 0, 0.03, -0.98 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		B("Hoja", { 0.04, 0.12, 0.5 }, { 0, -0.12, -1.45 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		W("Punta", { 0.04, 0.42, 0.32 }, { 0, -0.03, -1.83 }, { 120, 122, 126 }, { 0, 0, 180 }, { mat = "Metal", refl = 0.1 }),
	} }
end
HERRAMIENTAS.Hacha = function()
	return { partes = {
		C("Mango", 0.2, 2.5, "z", { 0, 0, -0.9 }, MADERA, nil, { mat = "Wood" }),
		B("Cabeza", { 0.22, 0.5, 0.34 }, { 0, 0.12, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		E("Hoja", { 0.07, 0.78, 0.64 }, { 0, 0.6, -2.05 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Lanza = function()
	return { partes = {
		C("Asta", 0.14, 5.8, "z", { 0, 0, -1.2 }, { 120, 92, 62 }, nil, { mat = "Wood" }),
		C("Atadura", 0.18, 0.35, "z", { 0, 0, -4.05 }, { 70, 56, 40 }, nil, { mat = "Fabric" }),
		E("Punta", { 0.05, 0.3, 0.85 }, { 0, 0, -4.55 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		C("Cinta", 0.17, 0.5, "z", { 0, 0, 0 }, { 40, 34, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Arco = function()
	local partes = {
		B("Empunadura", { 0.18, 0.62, 0.3 }, { 0, 0, 0 }, { 82, 54, 36 }, nil, { mat = "Wood" }),
		C("Cuerda", 0.025, 4.4, "y", { 0, 0, 0.43 }, { 230, 226, 214 }, nil, { mat = "Fabric", sombra = false }),
	}
	for _, k in ipairs({ 1, -1 }) do
		table.insert(partes, B("Cuerpo", { 0.15, 0.62, 0.22 }, { 0, 0.6 * k, -0.04 }, { 82, 54, 36 }, nil, { mat = "Wood" }))
		local p = { { 0, 0.9 * k, -0.02 }, { 0, 1.55 * k, 0.28 }, { 0, 2.05 * k, 0.5 }, { 0, 2.2 * k, 0.42 } }
		for i = 1, 3 do
			table.insert(partes, R("Pala", p[i], p[i + 1], 0.09 - i * 0.015, { 60, 44, 34 }, { mat = "Wood" }))
		end
	end
	return { partes = partes, boca = { 0, 0.15, -0.3 } }
end
HERRAMIENTAS.Ballesta = function()
	local partes = {
		B("Culata", { 0.24, 0.36, 1.5 }, { 0, 0.08, 0.35 }, { 50, 50, 46 }, nil, { mat = "SmoothPlastic" }),
		B("Empunadura", { 0.2, 0.48, 0.3 }, { 0, -0.12, 0 }, { 40, 40, 38 }, { -15, 0, 0 }),
		B("Riel", { 0.16, 0.12, 1.5 }, { 0, 0.3, -0.65 }, PAVONADO, nil, { mat = "Metal" }),
		B("Estribo", { 0.42, 0.06, 0.06 }, { 0, 0.18, -1.48 }, PAVONADO, nil, { mat = "Metal" }),
		C("Mira", 0.14, 0.7, "z", { 0, 0.55, -0.2 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cuerda", { 0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		R("Cuerda", { -0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		C("Virote", 0.05, 1.0, "z", { 0, 0.38, -0.95 }, { 40, 40, 40 }),
	}
	par(partes, function(k)
		return R("Pala", { 0.05 * k, 0.33, -1.38 }, { 1.0 * k, 0.33, -1.18 }, 0.1, { 60, 60, 56 }, { mat = "SmoothPlastic" })
	end)
	return { partes = partes, boca = { 0, 0.38, -1.5 } }
end
HERRAMIENTAS.Pistola = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.32 }, { 0, -0.06, 0.02 }, POLIMERO, { -14, 0, 0 }),
		B("Armazon", { 0.2, 0.14, 0.8 }, { 0, 0.25, -0.22 }, POLIMERO),
		B("Corredera", { 0.22, 0.2, 0.92 }, { 0, 0.41, -0.24 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		C("Canon", 0.1, 0.06, "z", { 0, 0.42, -0.72 }, { 14, 14, 14 }),
		B("Guardamonte", { 0.05, 0.05, 0.32 }, { 0, 0.07, -0.32 }, POLIMERO),
		B("Guardamonte", { 0.05, 0.16, 0.05 }, { 0, 0.13, -0.47 }, POLIMERO),
		B("Gatillo", { 0.04, 0.12, 0.04 }, { 0, 0.13, -0.26 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		B("Mira", { 0.06, 0.05, 0.05 }, { 0, 0.53, -0.66 }, POLIMERO),
		B("Mira", { 0.14, 0.05, 0.06 }, { 0, 0.53, 0.17 }, POLIMERO),
		B("Cargador", { 0.16, 0.08, 0.22 }, { 0, -0.36, 0.06 }, POLIMERO, { -14, 0, 0 }),
	}, boca = { 0, 0.42, -0.76 } }
end
HERRAMIENTAS.Revolver = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.3 }, { 0, -0.08, 0.06 }, NOGAL, { -20, 0, 0 }, { mat = "Wood" }),
		B("Armazon", { 0.2, 0.32, 0.55 }, { 0, 0.3, -0.2 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Tambor", 0.4, 0.34, "z", { 0, 0.34, -0.24 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Canon", 0.14, 0.8, "z", { 0, 0.42, -0.85 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		B("Guia", { 0.12, 0.1, 0.76 }, { 0, 0.32, -0.86 }, ACERO, nil, { mat = "Metal" }),
		B("Martillo", { 0.06, 0.14, 0.1 }, { 0, 0.5, 0.06 }, PAVONADO, { 20, 0, 0 }),
		B("Guardamonte", { 0.05, 0.05, 0.28 }, { 0, 0.1, -0.24 }, ACERO, nil, { mat = "Metal" }),
		B("Mira", { 0.04, 0.07, 0.08 }, { 0, 0.52, -1.2 }, ACERO, nil, { mat = "Metal" }),
	}, boca = { 0, 0.42, -1.27 } }
end
HERRAMIENTAS.Escopeta = function()
	return { partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, NOGAL, { -14, 0, 0 }, { mat = "Wood" }),
		B("Culata", { 0.23, 0.44, 1.25 }, { 0, 0.1, 1.02 }, NOGAL, nil, { mat = "Wood" }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.67 }, { 30, 30, 30 }),
		B("Cajon", { 0.26, 0.4, 1.0 }, { 0, 0.28, -0.4 }, PAVONADO, nil, { mat = "Metal" }),
		C("Canon", 0.15, 2.3, "z", { 0, 0.4, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Deposito", 0.13, 1.7, "z", { 0, 0.24, -1.75 }, PAVONADO, nil, { mat = "Metal" }),
		C("Corredera", 0.24, 0.62, "z", { 0, 0.24, -1.45 }, NOGAL, nil, { mat = "Wood" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.05, -0.18 }, PAVONADO),
		S("Mira", 0.06, { 0, 0.5, -3.15 }, { 230, 210, 160 }),
	}, boca = { 0, 0.4, -3.22 } }
end
HERRAMIENTAS.Subfusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.04 }, POLIMERO, { -16, 0, 0 }),
		B("Cajon", { 0.24, 0.38, 1.0 }, { 0, 0.3, -0.28 }, POLIMERO),
		C("Funda", 0.2, 0.42, "z", { 0, 0.34, -0.98 }, PAVONADO, nil, { mat = "Metal" }),
		B("Cargador", { 0.15, 0.72, 0.25 }, { 0, -0.1, -0.5 }, PAVONADO, { 6, 0, 0 }),
		R("Culata", { 0.08, 0.36, 0.2 }, { 0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		R("Culata", { -0.08, 0.36, 0.2 }, { -0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		B("Cantonera", { 0.24, 0.42, 0.06 }, { 0, 0.22, 1.02 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.12 }, { 0, 0.54, 0.1 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.06 }, { 0, 0.54, -0.72 }, POLIMERO),
	}, boca = { 0, 0.34, -1.22 } }
end
HERRAMIENTAS.Fusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.05 }, POLIMERO, { -18, 0, 0 }),
		B("Cajon", { 0.24, 0.42, 1.15 }, { 0, 0.32, -0.32 }, POLIMERO),
		B("Cargador", { 0.17, 0.78, 0.34 }, { 0, -0.12, -0.5 }, POLIMERO, { -14, 0, 0 }),
		B("Culata", { 0.22, 0.45, 0.95 }, { 0, 0.26, 0.78 }, POLIMERO),
		B("Cantonera", { 0.24, 0.55, 0.08 }, { 0, 0.22, 1.28 }, { 20, 20, 20 }),
		B("Guardamanos", { 0.26, 0.3, 1.0 }, { 0, 0.35, -1.38 }, POLIMERO),
		C("Canon", 0.09, 0.66, "z", { 0, 0.37, -2.2 }, PAVONADO, nil, { mat = "Metal" }),
		C("Bocacha", 0.13, 0.16, "z", { 0, 0.37, -2.6 }, PAVONADO, nil, { mat = "Metal" }),
		B("Riel", { 0.12, 0.06, 1.0 }, { 0, 0.56, -0.4 }, POLIMERO),
		C("Visor", 0.18, 0.38, "z", { 0, 0.7, -0.35 }, POLIMERO),
		C("Lente", 0.15, 0.02, "z", { 0, 0.7, -0.55 }, { 120, 40, 40 }, nil, { mat = "Glass", trans = 0.2 }),
	}, boca = { 0, 0.37, -2.7 } }
end

local function rifleCerrojo(op)
	local partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, op.madera, { -14, 0, 0 }, { mat = op.mat }),
		B("Culata", { 0.23, 0.44, 1.2 }, { 0, 0.1, 1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.62 }, { 30, 30, 30 }),
		B("Fuste", { 0.24, 0.24, 1.5 }, { 0, 0.22, -1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cajon", { 0.22, 0.24, 0.85 }, { 0, 0.36, -0.28 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cerrojo", { 0.08, 0.38, 0.05 }, { 0.3, 0.3, 0.12 }, 0.06, PAVONADO, { mat = "Metal" }),
		S("Cerrojo", 0.12, { 0.32, 0.29, 0.13 }, PAVONADO, { mat = "Metal" }),
		C("Canon", 0.12, op.canon, "z", { 0, 0.38, -0.7 - op.canon / 2 }, PAVONADO, nil, { mat = "Metal" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.1, -0.18 }, PAVONADO),
		C("Mira", op.mira, 1.15, "z", { 0, 0.72, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		C("Objetivo", op.mira * 1.6, 0.34, "z", { 0, 0.72, -1.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Ocular", op.mira * 1.35, 0.24, "z", { 0, 0.72, 0.28 }, PAVONADO, nil, { mat = "Metal" }),
		C("Lente", op.mira * 1.45, 0.02, "z", { 0, 0.72, -1.23 }, { 70, 120, 150 }, nil, { mat = "Glass", trans = 0.15, refl = 0.3 }),
		C("Torreta", 0.12, 0.14, "y", { 0, 0.86, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.7 }, PAVONADO),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.05 }, PAVONADO),
	}
	if op.bipode then
		for _, k in ipairs({ 1, -1 }) do
			table.insert(partes, R("Bipode", { 0.05 * k, 0.15, -1.6 }, { 0.35 * k, -0.85, -1.85 }, 0.05, PAVONADO, { mat = "Metal" }))
		end
		table.insert(partes, B("Freno", { 0.2, 0.2, 0.3 }, { 0, 0.38, -0.85 - op.canon }, PAVONADO, nil, { mat = "Metal" }))
	end
	return { partes = partes, boca = { 0, 0.38, -0.75 - op.canon - (op.bipode and 0.2 or 0) } }
end
HERRAMIENTAS.RifleCaza = function()
	return rifleCerrojo({ madera = NOGAL, mat = "Wood", canon = 1.9, mira = 0.17 })
end
HERRAMIENTAS.Francotirador = function()
	return rifleCerrojo({ madera = VERDE_OLIVA, mat = "SmoothPlastic", canon = 2.5, mira = 0.2, bipode = true })
end
HERRAMIENTAS.Molotov = function()
	return { partes = {
		C("Botella", 0.34, 0.62, "y", { 0, 0.05, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		C("Liquido", 0.3, 0.42, "y", { 0, -0.04, 0 }, { 196, 140, 60 }, nil, { trans = 0.3 }),
		C("Gollete", 0.14, 0.3, "y", { 0, 0.5, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		E("Trapo", { 0.16, 0.38, 0.16 }, { 0, 0.74, 0 }, { 196, 186, 166 }, { 0, 0, 12 }, { mat = "Fabric" }),
	}, mecha = { 0, 0.88, 0 } }
end
HERRAMIENTAS.Granada = function()
	return { partes = {
		E("Cuerpo", { 0.32, 0.44, 0.32 }, { 0, 0.04, 0 }, VERDE_OLIVA, nil, { mat = "Metal" }),
		C("Espoleta", 0.14, 0.14, "y", { 0, 0.32, 0 }, { 120, 120, 110 }, nil, { mat = "Metal" }),
		B("Cuchara", { 0.05, 0.36, 0.08 }, { 0.16, 0.16, 0 }, { 120, 120, 110 }, { 0, 0, -8 }, { mat = "Metal" }),
		C("Anilla", 0.16, 0.03, "x", { -0.1, 0.38, 0 }, { 150, 150, 140 }, nil, { mat = "Metal" }),
	} }
end

-- Caña: mango de corcho, carrete debajo, tramos cada vez más finos y anillas; "Punta" al final
local function cana(cfg, op)
	local color = cfg.color
	local metal = op.dorado and { 200, 160, 70 } or { 150, 150, 156 }
	local partes = {
		C("Mango", 0.2, 0.95, "z", { 0, 0, 0.1 }, { 176, 140, 100 }, nil, { mat = "Sand" }),
		C("Portacarrete", 0.16, 0.35, "z", { 0, 0, -0.5 }, metal, nil, { mat = "Metal" }),
		B("Pie", { 0.06, 0.28, 0.1 }, { 0, -0.18, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Carrete", op.carrete, 0.26, "z", { 0, -0.32 - op.carrete / 2, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Bobina", op.carrete * 0.75, 0.2, "z", { 0, -0.32 - op.carrete / 2, -0.66 }, { 220, 220, 210 }),
		R("Manivela", { 0.15, -0.32 - op.carrete / 2, -0.5 }, { 0.32, -0.42 - op.carrete / 2, -0.5 }, 0.04, metal, { mat = "Metal" }),
	}
	-- La caña sale hacia delante y arriba
	local dir = Vector3.new(0, math.sin(math.rad(op.angulo)), -math.cos(math.rad(op.angulo)))
	local base = Vector3.new(0, 0, -0.65)
	local tramos = { { 0, 0.34, 0.13 }, { 0.34, 0.68, 0.09 }, { 0.68, 1, 0.055 } }
	for _, t in ipairs(tramos) do
		local a, b = base + dir * (op.largo * t[1]), base + dir * (op.largo * t[2])
		table.insert(partes, R("Tramo", { a.X, a.Y, a.Z }, { b.X, b.Y, b.Z }, t[3], color, { mat = op.mat or "SmoothPlastic" }))
	end
	for i = 1, 4 do
		local p = base + dir * (op.largo * (0.22 + i * 0.18))
		table.insert(partes, C("Anilla", 0.12 - i * 0.015, 0.02, "z", { p.X, p.Y - 0.08, p.Z }, metal, { op.angulo, 0, 0 }, { mat = "Metal" }))
	end
	local punta = base + dir * op.largo
	return { partes = partes, punta = { punta.X, punta.Y, punta.Z } }
end
local CANAS = {
	CanaBambu = { largo = 7.5, angulo = 26, carrete = 0, mat = "Wood" },
	CanaMadera = { largo = 6.5, angulo = 26, carrete = 0.32, mat = "Wood" },
	CanaFibra = { largo = 6.8, angulo = 26, carrete = 0.36 },
	CanaCarbono = { largo = 7, angulo = 26, carrete = 0.38 },
	CanaMar = { largo = 11, angulo = 30, carrete = 0.5 },
	CanaCurrican = { largo = 5.6, angulo = 24, carrete = 0.62, dorado = true },
}

-- Construye la herramienta (Tool) de un arma o una caña con sus datos de CazaConfig
function Modelos.herramienta(id, cfg, esCana)
	local def
	if esCana then
		local op = CANAS[id]
		def = cana(cfg, op)
		if op.carrete == 0 then
			-- La de bambú no lleva carrete: el sedal va atado a la punta
			for i = #def.partes, 1, -1 do
				local n = def.partes[i].nombre
				if n == "Carrete" or n == "Bobina" or n == "Manivela" or n == "Portacarrete" or n == "Pie" then
					table.remove(def.partes, i)
				end
			end
		end
	else
		def = HERRAMIENTAS[id]()
	end
	local tool = Instance.new("Tool")
	tool.Name = cfg.nombre
	tool.ToolTip = cfg.desc or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(esCana and "Cana" or "Arma", id)
	tool:SetAttribute("CazaPesca", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = ZERO
	handle.Parent = tool
	for _, sp in ipairs(def.partes) do
		local p = fabricar(sp, 1)
		p.CanQuery = false
		p.Parent = tool
		soldar(handle, p)
	end
	for nombre, pos in pairs({ Boca = def.boca, Punta = def.punta, Mecha = def.mecha }) do
		local a = Instance.new("Attachment")
		a.Name = nombre
		a.Position = Vector3.new(pos[1], pos[2], pos[3])
		a.Parent = handle
	end
	if def.mecha then
		local fuego = Instance.new("Fire")
		fuego.Size = 1.2
		fuego.Heat = 4
		fuego.Parent = handle.Mecha
	end
	return tool
end

-- =====================================================================
--  Corcho de pesca y rastro de sangre
-- =====================================================================
function Modelos.corcho()
	local m = Instance.new("Model")
	m.Name = "Corcho"
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Shape = Enum.PartType.Ball
	raiz.Size = Vector3.new(0.36, 0.36, 0.36)
	raiz.Color = Color3.fromRGB(214, 40, 34)
	raiz.Material = Enum.Material.SmoothPlastic
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Parent = m
	m.PrimaryPart = raiz
	local franja = fabricar(C("Franja", 0.37, 0.12, "y", { 0, -0.08, 0 }, { 240, 240, 236 }), 1)
	franja.CanQuery = false
	franja.Parent = m
	soldar(raiz, franja)
	local antena = fabricar(C("Antena", 0.05, 0.36, "y", { 0, 0.32, 0 }, { 250, 210, 60 }), 1)
	antena.CanQuery = false
	antena.Parent = m
	soldar(raiz, antena)
	local a = Instance.new("Attachment")
	a.Name = "Linea"
	a.Position = Vector3.new(0, 0.5, 0)
	a.Parent = raiz
	return m
end

function Modelos.manchaSangre(cf, tam)
	local p = Instance.new("Part")
	p.Name = "RastroSangre"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, tam, tam * (0.6 + math.random() * 0.5))
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = Color3.fromRGB(92 + math.random(0, 20), 14, 12)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

Modelos.especies = ANIMALES
return Modelos
]=]
CAZA_SERVIDOR_MODULOS["Animales"] = [=[
--[[
	Animales del mundo abierto (servidor): dónde aparecen, cómo se comportan, cómo se hieren y qué se saca de ellos.

	Comportamiento:
	  · Pastan, descansan y pasean cerca de su zona; los patos nadan y los cangrejos van por la arena.
	  · Las presas huyen cuando te detectan. La distancia depende de si vas agachado o corriendo y del viento:
	    si el viento sopla de ti hacia ellas te huelen desde mucho más lejos.
	  · Los disparos espantan a las presas que los oyen (cada arma hace más o menos ruido).
	  · Los depredadores (lobos, osos) te cazan si te acercas; el jabalí solo ataca si le hieres o le agobias.
	  · Un animal herido sangra (más con flechas), huye dejando un rastro de sangre en el suelo y cae cuando se desangra.
	Al morir se queda tumbado y se puede despellejar (mantén E): carne según su peso y piel según el daño recibido.
]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Animales = {}
local Config, Modelos, W, M
local carpeta, rastros
local lista = {}
local porModelo = {}
local params
local ctx

local LIMITE = 1950
local AGUA = Enum.Material.Water
local PRADO = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }
local NORTE = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true, [Enum.Material.Snow] = true }

local function ahora()
	return os.clock()
end

-- Altura y material del terreno (o del agua) en un punto
local function suelo(x, z)
	local r = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	if r then
		return r.Position.Y, r.Material
	end
	return nil, nil
end
Animales.suelo = suelo

local function enZona(x, z, margen)
	return W ~= nil and W.inZone(x, z, margen)
end

-- =====================================================================
--  Dónde puede vivir cada especie
-- =====================================================================
local function apto(donde, x, z)
	if math.abs(x) > LIMITE or math.abs(z) > LIMITE or enZona(x, z, 30) then
		return nil
	end
	local y, mat = suelo(x, z)
	if not y then
		return nil
	end
	if donde == "agua" then
		if mat == AGUA and (not W or W.inLandPoly(x, z)) then
			return y
		end
		return nil
	end
	if mat == AGUA then
		return nil
	end
	if donde == "playa" then
		return (mat == Enum.Material.Sand and y > -5 and y < 5) and y or nil
	elseif donde == "prado" then
		return (PRADO[mat] and y < 70) and y or nil
	elseif donde == "bosque" then
		return ((mat == Enum.Material.LeafyGrass or (mat == Enum.Material.Grass and math.random() < 0.25)) and y < 130) and y or nil
	elseif donde == "norte" then
		return (NORTE[mat] and (z < -700 or y > 60) and y < 170) and y or nil
	elseif donde == "montana" then
		return (y > 45 and y < 200 and mat ~= Enum.Material.Sand) and y or nil
	elseif donde == "granja" then
		return PRADO[mat] and y or nil
	end
	return y
end

local function buscarSitio(donde, lejosDe)
	for intento = 1, 500 do
		local x, z
		if donde == "granja" and W and W.zones.Granjas and intento < 300 then
			local r = W.zones.Granjas
			x, z = math.random(r[1] - 260, r[2] + 260), math.random(r[3] - 260, r[4] + 260)
		else
			x, z = math.random(-LIMITE, LIMITE), math.random(-LIMITE, LIMITE)
		end
		local y = apto(donde, x, z)
		local lejos = true
		if y and lejosDe then
			for _, p in ipairs(lejosDe) do
				if (Vector3.new(x, 0, z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 150 then
					lejos = false
				end
			end
		end
		if y and lejos then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

-- =====================================================================
--  Crear un animal
-- =====================================================================
local function sonido(a, nombre)
	local id = Config.Sonidos[nombre or a.especie]
	if id and id ~= "" and ahora() - (a.ultimoSonido or 0) > 5 then
		a.ultimoSonido = ahora()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.RollOffMaxDistance = 220
		s.Volume = 0.8
		s.Parent = a.raiz
		s:Play()
		Debris:AddItem(s, 8)
	end
end

local function crear(especie, punto, casa)
	local def = Config.Animales[especie]
	local macho = (especie == "Ciervo" or especie == "Pato" or especie == "Pavo") and math.random() < 0.5
	local medio = (def.peso[1] + def.peso[2]) / 2
	local peso = def.peso[1] + (def.peso[2] - def.peso[1]) * math.random() ^ 1.3
	if macho and especie == "Ciervo" then
		peso = math.min(def.peso[2], peso * 1.2)
	end
	local escala = (peso / medio) ^ (1 / 3)
	local modelo, altura = Modelos.animal(especie, { escala = escala, macho = macho, variante = math.random(1, 2) })
	local vida = math.floor(def.vida * escala ^ 2 + 0.5)
	modelo:SetAttribute("Nombre", def.nombre)
	modelo:SetAttribute("Peso", math.floor(peso * 10 + 0.5) / 10)
	modelo:SetAttribute("Macho", macho)
	modelo:SetAttribute("Vida", vida)
	modelo:SetAttribute("VidaMax", vida)
	modelo:SetAttribute("Mov", "quieto")
	modelo:SetAttribute("Vel", 0)
	local raiz = modelo.PrimaryPart
	local yaw = math.random() * math.pi * 2
	modelo.Parent = carpeta
	raiz.CFrame = CFrame.new(punto.X, punto.Y + altura, punto.Z) * CFrame.Angles(0, yaw, 0)
	-- Gotas de sangre (solo cuando está herido)
	local gotas = Instance.new("ParticleEmitter")
	gotas.Name = "Sangre"
	gotas.Color = ColorSequence.new(Color3.fromRGB(110, 10, 8))
	gotas.Size = NumberSequence.new(0.08 * escala)
	gotas.Lifetime = NumberRange.new(0.6, 1)
	gotas.Speed = NumberRange.new(0.5, 1.5)
	gotas.Acceleration = Vector3.new(0, -30, 0)
	gotas.Rate = 8
	gotas.Enabled = false
	gotas.Parent = raiz
	CollectionService:AddTag(modelo, "Animal")
	local a = {
		especie = especie, def = def, modelo = modelo, raiz = raiz, altura = altura, escala = escala, peso = peso,
		vida = vida, vidaMax = vida, macho = macho, casa = casa or punto, pos = punto, yaw = yaw,
		hasta = 0, pausa = ahora() + math.random() * 4, secuencia = 0, sangrado = 0, sangradoHasta = 0, manchaEn = 0,
		asustadoHasta = 0, agresivoHasta = 0, ultimoAtaque = 0, golpes = 0, danoPiel = 0,
		nada = def.donde == "agua", playa = def.donde == "playa",
	}
	table.insert(lista, a)
	porModelo[modelo] = a
	return a
end

local function aparecerGrupo(especie, lejosDe)
	local def = Config.Animales[especie]
	local centro = buscarSitio(def.donde, lejosDe)
	if not centro then
		return 0
	end
	local n = 0
	for i = 1, def.grupo or 1 do
		local p = centro
		if i > 1 then
			for _ = 1, 12 do
				local x, z = centro.X + math.random(-10, 10), centro.Z + math.random(-10, 10)
				local y = apto(def.donde, x, z)
				if y then
					p = Vector3.new(x, y, z)
					break
				end
			end
		end
		crear(especie, p, centro)
		n = n + 1
	end
	return n
end

-- =====================================================================
--  Movimiento: gira hacia el destino y anda o corre en línea recta (Tween de la raíz)
-- =====================================================================
local function poner(a, mov, vel)
	if a.modelo:GetAttribute("Mov") ~= mov then
		a.modelo:SetAttribute("Mov", mov)
	end
	a.modelo:SetAttribute("Vel", vel or 0)
end

local function moverA(a, x, z, velocidad, mov)
	local y, mat = suelo(x, z)
	if not y then
		return false
	end
	if a.nada then
		if mat ~= AGUA then
			return false
		end
	elseif mat == AGUA or (a.playa and mat ~= Enum.Material.Sand) then
		return false
	end
	if enZona(x, z, 12) or math.abs(x) > LIMITE + 40 or math.abs(z) > LIMITE + 40 then
		return false
	end
	local dx, dz = x - a.pos.X, z - a.pos.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.3 then
		return false
	end
	if not a.nada and math.abs(y - a.pos.Y) > d * 1.1 + 1 then
		return false -- demasiado empinado
	end
	local yaw = math.atan2(-dx, -dz)
	local pitch = a.nada and 0 or math.atan2(y - a.pos.Y, d) * 0.6
	local destino = CFrame.new(x, y + a.altura, z) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local giro = math.abs(((yaw - a.yaw + math.pi) % (2 * math.pi)) - math.pi)
	a.secuencia = a.secuencia + 1
	local sec = a.secuencia
	if a.tween then
		a.tween:Cancel()
	end
	local t = d / velocidad
	local function andar()
		if sec ~= a.secuencia or a.muerto then
			return
		end
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = destino })
		a.tween:Play()
	end
	local tGiro = 0
	if giro > math.rad(35) and mov ~= "correr" then
		-- Primero se gira en el sitio (como un animal de verdad) y luego echa a andar
		tGiro = math.min(0.8, giro / math.rad(160))
		local actual = a.raiz.CFrame
		local girado = CFrame.new(actual.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(tGiro, Enum.EasingStyle.Sine), { CFrame = girado })
		a.tween.Completed:Connect(andar)
		a.tween:Play()
	else
		andar()
	end
	a.yaw = yaw
	a.pos = Vector3.new(x, y, z)
	a.hasta = ahora() + tGiro + t
	poner(a, mov, velocidad)
	return true
end

-- Intenta moverse en una dirección (radianes) probando a girar un poco si no se puede
local function irHacia(a, angulo, distancia, velocidad, mov)
	for i = 0, 7 do
		local desvio = ((i % 2 == 0) and 1 or -1) * math.ceil(i / 2) * math.rad(28)
		local ang = angulo + desvio
		if moverA(a, a.pos.X + math.cos(ang) * distancia, a.pos.Z + math.sin(ang) * distancia, velocidad, mov) then
			return true
		end
	end
	return false
end

-- =====================================================================
--  Detección: distancia, agachado o corriendo, y el viento (olfato)
-- =====================================================================
local function factorDeteccion(a, jugador, hrp)
	local f = 1
	if jugador:GetAttribute("Agachado") then
		f = f * Config.Deteccion.Agachado
	elseif hrp.AssemblyLinearVelocity.Magnitude > 18 then
		f = f * Config.Deteccion.Corriendo
	end
	local viento = workspace.GlobalWind
	local horiz = Vector3.new(viento.X, 0, viento.Z)
	if horiz.Magnitude > 2 then
		local haciaAnimal = Vector3.new(a.pos.X - hrp.Position.X, 0, a.pos.Z - hrp.Position.Z)
		if haciaAnimal.Magnitude > 0.1 then
			local d = horiz.Unit:Dot(haciaAnimal.Unit)
			if d > 0.5 then
				f = f * Config.Deteccion.VientoAFavor
			elseif d < -0.5 then
				f = f * Config.Deteccion.VientoEnContra
			end
		end
	end
	return f
end

local function masCercano(a)
	local mejor, dist, factor = nil, math.huge, 1
	for _, jugador in ipairs(Players:GetPlayers()) do
		local char = jugador.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - a.raiz.Position).Magnitude
			if d < dist then
				mejor, dist, factor = jugador, d, factorDeteccion(a, jugador, hrp)
			end
		end
	end
	return mejor, dist, factor
end

-- =====================================================================
--  Muerte y despiece
-- =====================================================================
local despellejar

local function morir(a, jugador)
	if a.muerto then
		return
	end
	a.muerto = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	a.vida = 0
	a.modelo:SetAttribute("Vida", 0)
	poner(a, "muerto", 0)
	a.raiz.Sangre.Enabled = false
	-- Cae de lado (el cangrejo panza arriba)
	local caida
	if a.especie == "Cangrejo" then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura, a.pos.Z) * CFrame.Angles(0, a.yaw, math.pi)
	elseif a.nada then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.6, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(80))
	else
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.42, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(88))
	end
	TweenService:Create(a.raiz, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = caida }):Play()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Despellejar"
	prompt.ActionText = (a.especie == "Cangrejo" or a.especie == "Pato" or a.especie == "Pavo") and "Recoger" or "Despellejar"
	prompt.ObjectText = string.format("%s · %s kg", a.def.nombre, (string.format("%.1f", a.peso):gsub("%.", ",")))
	prompt.HoldDuration = math.clamp(a.peso / 45, 0.8, 4)
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = a.raiz
	prompt.Triggered:Connect(function(quien)
		despellejar(a, quien)
	end)
	a.desaparece = ahora() + 300
	if ctx.alMatar then
		ctx.alMatar(jugador, a)
	end
end

local function quitar(a)
	a.quitado = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	porModelo[a.modelo] = nil
	a.modelo:Destroy()
	for i, b in ipairs(lista) do
		if b == a then
			table.remove(lista, i)
			break
		end
	end
	-- Sale otro de la misma especie más adelante, lejos de los jugadores
	task.delay(a.def.reaparicion, function()
		local lejos = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(lejos, hrp.Position)
			end
		end
		local punto = buscarSitio(a.def.donde, lejos)
		if punto then
			crear(a.especie, punto, punto)
		end
	end)
end

function despellejar(a, jugador)
	if a.quitado or not a.muerto then
		return
	end
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - a.raiz.Position).Magnitude > 14 then
		return
	end
	local def = a.def
	local botin = {}
	-- Carne según el peso (los disparos y las explosiones estropean parte)
	if def.carne and def.rendimiento > 0 then
		local perdida = math.min(0.6, math.max(0, a.golpes - 1) * 0.05 + (a.explosion and 0.4 or 0))
		local kg = math.floor(a.peso * def.rendimiento * (1 - perdida) * 10 + 0.5) / 10
		if kg > 0 then
			local obj = Config.Objetos[def.carne]
			table.insert(botin, { id = def.carne, nombre = obj.nombre, cantidad = kg, unidad = "kg", valor = math.floor(kg * obj.porKg + 0.5) })
		end
	end
	-- Piel y trofeos: valen más cuanto más grande es el animal y menos daño tiene la piel
	local calidad, mult = "Buena", 1
	for _, c in ipairs(Config.CalidadPiel) do
		if a.danoPiel <= c[1] then
			calidad, mult = c[2], c[3]
			break
		end
	end
	local extra = {}
	for id, n in pairs(def.botin or {}) do
		extra[id] = n
	end
	if a.macho and def.macho then
		for id, n in pairs(def.macho) do
			extra[id] = n
		end
	end
	for id, n in pairs(extra) do
		local obj = Config.Objetos[id]
		local esPiel = string.sub(id, 1, 4) == "Piel"
		local m = esPiel and mult or 1
		local tam = (id == "Cornamenta") and a.escala ^ 3 or a.escala ^ 2
		if m > 0 then
			table.insert(botin, {
				id = id, nombre = obj.nombre, cantidad = n, unidad = "", calidad = esPiel and calidad or nil,
				valor = math.floor(obj.precio * n * m * tam + 0.5),
			})
		end
	end
	if ctx.darBotin then
		ctx.darBotin(jugador, botin, a)
	end
	quitar(a)
end

-- =====================================================================
--  Daño (lo llaman las armas)
-- =====================================================================
-- Devuelve el animal al que pertenece una pieza (o nil)
function Animales.de(parte)
	local m = parte
	while m and m ~= carpeta do
		if porModelo[m] then
			return porModelo[m]
		end
		m = m.Parent
	end
	return nil
end

-- dano ya multiplicado o no según "zona"; arma: datos de CazaConfig.Armas; desde: posición del atacante
function Animales.danar(a, dano, zona, jugador, arma, desde, explosion)
	if not a or a.muerto then
		return nil
	end
	local mult = Config.Zonas[zona] or 1
	local total = dano * mult
	a.vida = a.vida - total
	a.golpes = a.golpes + 1
	a.danoPiel = a.danoPiel + (arma.piel or 0.2) * ((zona == "Cabeza" or zona == "Cuello") and 0.3 or 1) + ((a.golpes > 1) and 0.1 or 0)
	if explosion then
		a.explosion = true
	end
	a.ultimoAtacante = jugador
	a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
	if (arma.sangrado or 0) > 0 and zona ~= "Cola" then
		a.sangrado = math.max(a.sangrado, total * arma.sangrado * 0.06)
		a.sangradoHasta = ahora() + 14
		a.raiz.Sangre.Enabled = true
	end
	a.asustadoHasta = ahora() + 12
	a.amenaza = desde
	if a.def.tipo ~= "presa" then
		a.agresivoHasta = ahora() + 25
		a.objetivo = jugador
	end
	if a.vida <= 0 then
		morir(a, jugador)
		return "muerto", total
	end
	a.hasta = 0 -- reacciona ya
	return "herido", total
end

-- Animales a menos de "radio" studs de un punto (para explosiones y fuego)
function Animales.cerca(pos, radio)
	local out = {}
	for _, a in ipairs(lista) do
		if not a.muerto and (a.raiz.Position - pos).Magnitude < radio then
			table.insert(out, a)
		end
	end
	return out
end

-- Un ruido (disparo, explosión): las presas que lo oyen huyen de él
function Animales.ruido(pos, radio)
	if radio <= 0 then
		return
	end
	for _, a in ipairs(lista) do
		if not a.muerto and a.def.tipo ~= "depredador" and (a.raiz.Position - pos).Magnitude < radio then
			a.asustadoHasta = ahora() + 8
			a.amenaza = pos
			a.hasta = 0
			sonido(a)
		end
	end
end

-- =====================================================================
--  Cerebro de cada animal
-- =====================================================================
local function huir(a, desde)
	local ang
	if desde then
		ang = math.atan2(a.pos.Z - desde.Z, a.pos.X - desde.X) + math.rad(math.random(-30, 30))
	else
		ang = math.random() * math.pi * 2
	end
	local v = a.def.correr * M * (a.vida < a.vidaMax * 0.5 and 0.8 or 1)
	irHacia(a, ang, v * 1.1, v, "correr")
end

local function pasear(a)
	local dCasa = Vector3.new(a.casa.X - a.pos.X, 0, a.casa.Z - a.pos.Z)
	local ang
	if dCasa.Magnitude > 25 * M then
		ang = math.atan2(dCasa.Z, dCasa.X) + math.rad(math.random(-40, 40))
	else
		ang = math.random() * math.pi * 2
	end
	local dist = math.random(4, 18) * M * (a.nada and 1.5 or 1) * math.max(0.3, a.escala)
	if irHacia(a, ang, dist, a.def.andar * M, "andar") then
		a.pausa = a.hasta + math.random(1, 4)
	end
end

local function atacar(a, jugador, dist)
	local char = jugador.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		a.objetivo = nil
		return
	end
	local alcance = (1.1 + a.escala * 0.9) * M * (a.especie == "Oso" and 1.25 or 1)
	if dist <= alcance then
		if ahora() - a.ultimoAtaque >= a.def.espera then
			a.ultimoAtaque = ahora()
			-- Mira a la presa y muerde o zarpea
			local d = hrp.Position - a.raiz.Position
			a.yaw = math.atan2(-d.X, -d.Z)
			a.raiz.CFrame = CFrame.new(a.raiz.Position) * CFrame.Angles(0, a.yaw, 0)
			poner(a, "atacar", 0)
			hum:TakeDamage(a.def.dano)
			sonido(a)
			if ctx.alAtacar then
				ctx.alAtacar(jugador, a)
			end
		end
		return
	end
	local v = a.def.correr * M * 0.9
	local dir = Vector3.new(hrp.Position.X - a.pos.X, 0, hrp.Position.Z - a.pos.Z)
	local paso = math.min(dist - alcance * 0.6, v * 0.5)
	if paso > 0.5 then
		local u = dir.Unit
		if not moverA(a, a.pos.X + u.X * paso, a.pos.Z + u.Z * paso, v, "correr") then
			irHacia(a, math.atan2(dir.Z, dir.X), paso, v, "correr")
		end
	end
end

local function pensar(a, dt)
	local t = ahora()
	if a.muerto then
		if a.desaparece and t > a.desaparece and not a.quitado then
			quitar(a)
		end
		return
	end
	-- Desangrarse
	if a.sangrado > 0 then
		if t < a.sangradoHasta then
			a.vida = a.vida - a.sangrado * dt
			a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
			if t > a.manchaEn and not a.nada then
				a.manchaEn = t + 1.6
				local y = suelo(a.raiz.Position.X, a.raiz.Position.Z)
				if y and #rastros:GetChildren() < 500 then
					local m = Modelos.manchaSangre(CFrame.new(a.raiz.Position.X, y + 0.03, a.raiz.Position.Z), (0.35 + math.random() * 0.4) * a.escala)
					m.Parent = rastros
					Debris:AddItem(m, 240)
				end
			end
			if a.vida <= 0 then
				morir(a, a.ultimoAtacante)
				return
			end
		else
			a.sangrado = 0
			a.raiz.Sangre.Enabled = false
		end
	end
	local jugador, dist, factor = masCercano(a)
	if dist > Config.DistanciaActiva * M and t > a.asustadoHasta then
		if t >= a.hasta and a.modelo:GetAttribute("Mov") ~= "quieto" then
			poner(a, "quieto", 0)
		end
		return -- nadie cerca: el animal "duerme" para no gastar servidor
	end
	local def = a.def
	local hrp = jugador and jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local tipo = def.tipo
	if tipo ~= "presa" and a.vida < a.vidaMax * 0.25 then
		tipo = "presa" -- muy herido: huye
	end
	if tipo == "depredador" or tipo == "neutral" then
		local agresion = (def.agresion or 0) * M * factor
		if t < a.agresivoHasta and a.objetivo then
			local thrp = a.objetivo.Character and a.objetivo.Character:FindFirstChild("HumanoidRootPart")
			if thrp and (thrp.Position - a.raiz.Position).Magnitude < 160 * M then
				if t >= a.hasta - 0.05 then
					atacar(a, a.objetivo, (thrp.Position - a.raiz.Position).Magnitude)
				end
				return
			end
			a.objetivo = nil
		end
		if jugador and dist < agresion then
			if a.objetivo ~= jugador then
				sonido(a)
			end
			a.objetivo = jugador
			a.agresivoHasta = t + 12
			if t >= a.hasta - 0.05 then
				atacar(a, jugador, dist)
			end
			return
		end
	end
	if tipo == "presa" then
		local huida = (def.huida or 0) * M * factor
		if jugador and dist < huida then
			if t > a.asustadoHasta then
				sonido(a)
			end
			a.asustadoHasta = t + 6
			a.amenaza = hrp and hrp.Position or a.amenaza
		end
		if t < a.asustadoHasta then
			if t >= a.hasta - 0.1 then
				huir(a, a.amenaza)
			end
			return
		end
	end
	-- Tranquilo: pasta, descansa o pasea
	if t >= a.hasta and t >= a.pausa then
		local r = math.random()
		if r < 0.45 and not a.nada then
			poner(a, "pastar", 0)
			a.pausa = t + math.random(3, 9)
		elseif r < 0.6 then
			poner(a, "quieto", 0)
			a.pausa = t + math.random(2, 6)
		else
			pasear(a)
		end
	elseif t >= a.hasta and a.modelo:GetAttribute("Mov") == "andar" then
		poner(a, "quieto", 0)
	end
end

-- =====================================================================
--  Arranque
-- =====================================================================
function Animales.iniciar(contexto)
	ctx = contexto
	Config, Modelos, W = ctx.Config, ctx.Modelos, ctx.W
	M = Config.StudsPorMetro
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	carpeta = workspace:FindFirstChild("Animales") or Instance.new("Folder")
	carpeta.Name = "Animales"
	carpeta.Parent = workspace
	rastros = workspace:FindFirstChild("RastrosSangre") or Instance.new("Folder")
	rastros.Name = "RastrosSangre"
	rastros.Parent = workspace
	local total = 0
	local especies = {}
	for especie in pairs(Config.Animales) do
		table.insert(especies, especie)
	end
	table.sort(especies)
	for _, especie in ipairs(especies) do
		local def = Config.Animales[especie]
		local hechos = 0
		local intentos = 0
		while hechos < def.cantidad and intentos < def.cantidad * 2 do
			intentos = intentos + 1
			hechos = hechos + aparecerGrupo(especie)
		end
		total = total + hechos
		task.wait()
	end
	task.spawn(function()
		local antes = ahora()
		while true do
			task.wait(0.2)
			local t = ahora()
			local dt = t - antes
			antes = t
			for i = #lista, 1, -1 do
				local a = lista[i]
				if a then
					local ok, err = pcall(pensar, a, dt)
					if not ok then
						warn("[Caza] animal", a.especie, err)
					end
				end
			end
		end
	end)
	return total
end

function Animales.lista()
	return lista
end

return Animales
]=]
CAZA_SERVIDOR_MODULOS["Armas"] = [=[
--[[
	Armas (servidor). El servidor decide si un disparo acierta para que nadie pueda hacer trampas:
	  · Las balas, flechas y lanzables vuelan con su velocidad real y caen por la gravedad. Se simulan
	    paso a paso, así que una flecha tarda en llegar y un ciervo que corre puede esquivarla.
	  · El daño depende de dónde acierta (cabeza, cuello, pecho...) y de la distancia (las balas pierden fuerza).
	  · La dispersión aumenta al moverte y baja agachado o apuntando. Cada disparo hace ruido y espanta animales.
	  · Recarga real: gasta cartuchos de la mochila y tarda lo que tarda cada arma.
	  · La granada explota a los 3 segundos y el molotov incendia el suelo. Las dos hacen daño también a quien
	    las lanza si está cerca.
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Armas = {}
local Config, Animales, Economia, Efectos, Aviso, M
local ctx
local ultimo = {}
local siguienteId = 0
local efectos

local function ahora()
	return os.clock()
end

local function herramienta(jugador, id)
	local char = jugador.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Arma") == id then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")
		if hum and hum.Health > 0 and hrp and head then
			return tool, char, hrp, head
		end
	end
	return nil
end

local function puede(jugador, id, cadencia)
	ultimo[jugador] = ultimo[jugador] or {}
	if ahora() - (ultimo[jugador][id] or -math.huge) < cadencia * 0.85 then
		return false
	end
	ultimo[jugador][id] = ahora()
	return true
end

local function parametros(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local excluir = { char, efectos }
	for _, n in ipairs({ "RastrosSangre", "Corchos" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	p.FilterDescendantsInstances = excluir
	p.IgnoreWater = false
	return p
end

-- Desvía una dirección un ángulo al azar dentro de un cono
local function desviar(dir, grados)
	if grados <= 0 then
		return dir
	end
	local r = math.rad(grados) * math.sqrt(math.random())
	local giro = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.new(0, 0, 0), dir) * CFrame.Angles(0, 0, giro) * CFrame.Angles(r, 0, 0)).LookVector
end

local function jugadorDe(parte)
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo do
		local p = Players:GetPlayerFromCharacter(modelo)
		if p then
			return p, modelo
		end
		modelo = modelo.Parent and modelo.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Aplica un impacto. Devuelve qué ha tocado ("animal", "jugador", "agua", "suelo") y el resultado
local function impacto(jugador, cfg, res, distancia, desde)
	local parte = res.Instance
	local caida = 1
	if cfg.tipo == "bala" and cfg.alcance then
		caida = math.clamp(1 - (distancia / (cfg.alcance * M)) ^ 2 * 0.5, 0.5, 1)
	end
	local a = Animales.de(parte)
	if a then
		local zona = parte:GetAttribute("Zona") or "Cuerpo"
		local estado = Animales.danar(a, cfg.dano * caida, zona, jugador, cfg, desde)
		return "animal", estado, zona
	end
	local otro, modelo = jugadorDe(parte)
	if otro and otro ~= jugador and Config.DanoEntreJugadores then
		local hum = modelo:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:TakeDamage(cfg.dano * caida * ((parte.Name == "Head") and 2 or 1))
			return "jugador", (hum.Health <= 0) and "muerto" or "herido", (parte.Name == "Head") and "Cabeza" or "Cuerpo"
		end
	end
	if res.Material == Enum.Material.Water then
		return "agua"
	end
	return "suelo"
end

-- Simula un proyectil (bala, flecha o lanzable) paso a paso con gravedad
-- "origen" es desde donde vuela de verdad; "visual" desde donde lo dibujan los clientes (la boca del arma)
local function simular(jugador, char, id, alcance, origen, velocidad, alImpactar, visual)
	siguienteId = siguienteId + 1
	local pid = siguienteId
	local g = Vector3.new(0, -Config.Gravedad * M, 0)
	local params = parametros(char)
	Efectos:FireAllClients("disparo", { id = pid, arma = id, desde = visual or origen, v = velocidad, g = g.Y, jugador = jugador.UserId })
	task.spawn(function()
		local p, v = origen, velocidad
		local recorrido, t = 0, 0
		while recorrido < alcance and t < 15 do
			local dt = math.min(RunService.Heartbeat:Wait(), 0.05)
			local nueva = p + v * dt + g * (0.5 * dt * dt)
			local paso = nueva - p
			local res = workspace:Raycast(p, paso, params)
			if res then
				alImpactar(res, recorrido + (res.Position - p).Magnitude, pid, v)
				return
			end
			recorrido = recorrido + paso.Magnitude
			v = v + g * dt
			p = nueva
			t = t + dt
		end
		Efectos:FireAllClients("fin", { id = pid, pos = p })
	end)
	return pid
end

-- =====================================================================
--  Disparar (armas de fuego, arco y ballesta)
-- =====================================================================
function Armas.disparar(jugador, id, apunta, apuntando)
	local cfg = Config.Armas[id]
	if not cfg or (cfg.tipo ~= "bala" and cfg.tipo ~= "proyectil") or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga <= 0 then
		Aviso:FireClient(jugador, "vacio", { arma = id })
		return
	end
	if not puede(jugador, id, cfg.cadencia) then
		return
	end
	tool:SetAttribute("Cargador", carga - 1)
	-- La bala sale desde la cabeza (donde está la vista del jugador) para que acierte donde apunta incluso
	-- a bocajarro; los clientes la dibujan saliendo de la boca del arma
	local origen = head.Position
	local boca = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Boca")
	local visual = boca and boca.WorldPosition or origen
	if (visual - origen).Magnitude > 10 then
		visual = origen
	end
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local disp = cfg.dispersion or 0
	if hrp.AssemblyLinearVelocity.Magnitude > 3 then
		disp = disp * 2
	end
	if jugador:GetAttribute("Agachado") then
		disp = disp * 0.6
	end
	if apuntando == true then
		disp = disp * 0.5
	end
	for _ = 1, cfg.perdigones or 1 do
		simular(jugador, char, id, cfg.alcance * M, origen, desviar(dir, disp) * (cfg.velocidad * M), function(res, distancia, pid)
			local tipo, estado, zona = impacto(jugador, cfg, res, distancia, origen)
			Efectos:FireAllClients("impacto", {
				id = pid, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id,
				parte = (cfg.tipo == "proyectil" and tipo == "animal") and res.Instance or nil,
			})
			if estado then
				Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
			end
		end, visual)
	end
	Animales.ruido(origen, (cfg.ruido or 0) * M)
	-- El arco y la ballesta se cargan solos si quedan flechas
	if cfg.tipo == "proyectil" then
		task.delay(0.15, function()
			Armas.recargar(jugador, id)
		end)
	end
end

-- =====================================================================
--  Recargar
-- =====================================================================
function Armas.recargar(jugador, id)
	local cfg = Config.Armas[id]
	if not cfg or not cfg.cargador then
		return
	end
	local tool = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga >= cfg.cargador then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		Aviso:FireClient(jugador, "sinMunicion", { arma = id, municion = cfg.municion })
		return
	end
	tool:SetAttribute("Recargando", true)
	Efectos:FireAllClients("recarga", { jugador = jugador.UserId, arma = id, tiempo = cfg.recarga })
	task.delay(cfg.recarga, function()
		tool:SetAttribute("Recargando", false)
		-- Si guardas el arma a medio recargar, la recarga se pierde
		if tool.Parent ~= jugador.Character then
			return
		end
		local actual = tool:GetAttribute("Cargador") or 0
		local n = math.min(cfg.cargador - actual, Economia.municion(jugador, cfg.municion))
		if n > 0 then
			Economia.gastar(jugador, cfg.municion, n)
			tool:SetAttribute("Cargador", actual + n)
		end
	end)
end

-- =====================================================================
--  Cuerpo a cuerpo
-- =====================================================================
local function balancear(tool)
	-- Golpe visible para todos: el arma sube y baja de golpe
	tool.Grip = CFrame.Angles(math.rad(-55), 0, 0)
	task.delay(0.12, function()
		tool.Grip = CFrame.Angles(math.rad(65), 0, 0)
		task.delay(0.16, function()
			tool.Grip = CFrame.new()
		end)
	end)
end

function Armas.golpear(jugador, id, mirada)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "cuerpo" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	local dir = hrp.CFrame.LookVector
	if typeof(mirada) == "Vector3" and mirada.Magnitude > 0.1 then
		local u = mirada.Unit
		dir = Vector3.new(u.X, math.clamp(u.Y, -0.7, 0.7), u.Z).Unit
	end
	balancear(tool)
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	local res = workspace:Spherecast(head.Position, 1.1, dir * (cfg.alcance * M + 1), parametros(char))
	if res then
		local tipo, estado, zona = impacto(jugador, cfg, res, 0, head.Position)
		Efectos:FireAllClients("impacto", { id = 0, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id })
		if estado then
			Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
		end
	end
	Animales.ruido(head.Position, 5 * M)
end

-- =====================================================================
--  Lanzables: granada y molotov
-- =====================================================================
local function danarPersonas(jugador, pos, radio, dano)
	for _, p in ipairs(Players:GetPlayers()) do
		if p == jugador or Config.DanoEntreJugadores then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local d = (hrp.Position - pos).Magnitude
				if d < radio then
					hum:TakeDamage(dano * (1 - d / radio))
				end
			end
		end
	end
end

local function explosion(jugador, cfg, pos)
	local R = cfg.radio * M
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = R
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = workspace
	Efectos:FireAllClients("explosion", { pos = pos, radio = R })
	for _, a in ipairs(Animales.cerca(pos, R * 1.4)) do
		local d = (a.raiz.Position - pos).Magnitude
		Animales.danar(a, cfg.dano * math.max(0, 1 - d / (R * 1.4)) ^ 1.2, "Cuerpo", jugador, cfg, pos, true)
	end
	danarPersonas(jugador, pos, R * 1.4, cfg.dano * 0.8)
	Animales.ruido(pos, cfg.ruido * M)
end

local function incendio(jugador, cfg, pos)
	local R = cfg.radio * M
	-- Llamas: una grande en el centro y cinco más pequeñas alrededor
	local function llama(posicion, tam)
		local p = Instance.new("Part")
		p.Name = "Incendio"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 0.4, 1)
		p.Position = posicion
		p.Parent = efectos
		local f = Instance.new("Fire")
		f.Size = tam
		f.Heat = 12
		f.Color = Color3.fromRGB(255, 140, 50)
		f.SecondaryColor = Color3.fromRGB(255, 60, 15)
		f.Parent = p
		Debris:AddItem(p, cfg.duracion)
		return p
	end
	local base = llama(pos, 9)
	for i = 1, 5 do
		local ang = i / 5 * math.pi * 2
		llama(pos + Vector3.new(math.cos(ang) * R * 0.6, 0, math.sin(ang) * R * 0.6), 5)
	end
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(40, 36, 34)
	humo.Opacity = 0.3
	humo.RiseVelocity = 7
	humo.Size = 8
	humo.Parent = base
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 140, 60)
	luz.Brightness = 3
	luz.Range = R * 3
	luz:SetAttribute("Base", 3)
	luz.Parent = base
	CollectionService:AddTag(luz, "LuzFuego")
	Efectos:FireAllClients("explosion", { pos = pos, radio = R, fuego = true })
	Animales.ruido(pos, cfg.ruido * M)
	task.spawn(function()
		local fin = ahora() + cfg.duracion
		while ahora() < fin do
			task.wait(0.5)
			for _, a in ipairs(Animales.cerca(pos, R)) do
				Animales.danar(a, cfg.dano, "Cuerpo", jugador, cfg, pos, true)
			end
			danarPersonas(jugador, pos, R, cfg.dano * 0.6)
		end
	end)
end

function Armas.lanzar(jugador, id, apunta)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "lanzable" or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		return
	end
	Economia.gastar(jugador, cfg.municion, 1)
	local origen = head.Position + hrp.CFrame.LookVector * 1.5 + Vector3.new(0, 0.4, 0)
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		dir = hrp.CFrame.LookVector
	end
	-- Se lanza en parábola: un poco hacia arriba y más fuerte cuanto más lejos apuntas (hasta su máximo)
	local distancia = math.min(dir.Magnitude, 40 * M)
	dir = (dir.Unit + Vector3.new(0, 0.3, 0)).Unit
	local fuerza = math.clamp(math.sqrt(distancia * Config.Gravedad * M), 8 * M, cfg.velocidad * M)
	local lanzado = ahora()
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	simular(jugador, char, id, 200 * M, origen, dir * fuerza, function(res, _, pid)
		Efectos:FireAllClients("impacto", { id = pid, pos = res.Position, normal = res.Normal, tipo = "lanzable", arma = id })
		if id == "Molotov" then
			incendio(jugador, cfg, res.Position)
		else
			local espera = math.max(0, (cfg.espoleta or 0) - (ahora() - lanzado))
			task.delay(espera, function()
				explosion(jugador, cfg, res.Position + res.Normal * 0.4)
			end)
		end
	end)
	if Economia.municion(jugador, cfg.municion) <= 0 then
		tool:Destroy()
	end
end

function Armas.iniciar(contexto)
	ctx = contexto
	Config, Animales, Economia = ctx.Config, ctx.Animales, ctx.Economia
	Efectos, Aviso = ctx.remotos.Efectos, ctx.remotos.Aviso
	M = Config.StudsPorMetro
	efectos = workspace:FindFirstChild("EfectosCaza") or Instance.new("Folder")
	efectos.Name = "EfectosCaza"
	efectos.Parent = workspace
	Players.PlayerRemoving:Connect(function(p)
		ultimo[p] = nil
	end)
end

return Armas
]=]
CAZA_SERVIDOR_MODULOS["Pesca"] = [=[
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
]=]
CAZA_SERVIDOR_MODULOS["Economia"] = [=[
--[[
	Dinero, mochila y equipo de cada jugador (servidor):
	  · Lo que cazas y pescas va a la mochila; se vende en las tiendas de caza y pesca.
	  · En la tienda se compran armas (cada arma de fuego trae una caja de su munición), cañas y munición.
	  · Las armas y cañas que tienes se te dan al aparecer; las balas que quedan en cada cargador se recuerdan.
	  · Se guarda todo entre partidas con DataStore (si el juego lo permite).
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

local Economia = {}
local Config, Modelos, remotos
local datos = {}
local plantillas
local almacen
local avisadoGuardado = false

local MAX_PECES = 150

local function nuevo()
	local e = { dinero = Config.DineroInicial, armas = {}, canas = {}, municion = {}, cargadores = {}, objetos = {}, peces = {}, records = {}, capturas = {}, caza = {} }
	for _, id in ipairs(Config.KitInicial.armas) do
		e.armas[id] = true
	end
	for _, id in ipairs(Config.KitInicial.canas) do
		e.canas[id] = true
	end
	for tipo, n in pairs(Config.KitInicial.municion) do
		e.municion[tipo] = n
	end
	-- Las armas del equipo inicial empiezan cargadas (el arco con una flecha montada)
	for _, id in ipairs(Config.KitInicial.armas) do
		local cfg = Config.Armas[id]
		if cfg and cfg.cargador then
			e.cargadores[id] = cfg.cargador
		end
	end
	return e
end

local function valorMochila(e)
	local total = 0
	for _, o in ipairs(e.objetos) do
		total = total + o.valor
	end
	for _, p in ipairs(e.peces) do
		total = total + p.valor
	end
	return total
end

local function lista(t)
	local out = {}
	for id, v in pairs(t) do
		if v then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Manda al jugador un resumen de su dinero, equipo y mochila (para la pantalla y la tienda)
local function enviar(jugador)
	local e = datos[jugador]
	if not e then
		return
	end
	local ls = jugador:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Dinero") then
		ls.Dinero.Value = e.dinero
	end
	jugador:SetAttribute("Dinero", e.dinero)
	for tipo in pairs(Config.Municion) do
		jugador:SetAttribute("Municion_" .. tipo, e.municion[tipo] or 0)
	end
	remotos.Estado:FireClient(jugador, {
		dinero = e.dinero, armas = lista(e.armas), canas = lista(e.canas), municion = e.municion,
		objetos = e.objetos, peces = e.peces, records = e.records, capturas = e.capturas, caza = e.caza, valor = valorMochila(e),
	})
end
Economia.enviar = enviar

-- =====================================================================
--  Herramientas en la mochila de Roblox
-- =====================================================================
local function darHerramienta(jugador, id, esCana)
	local e = datos[jugador]
	local plantilla = plantillas:FindFirstChild((esCana and "Cana_" or "Arma_") .. id)
	local mochila = jugador:FindFirstChild("Backpack")
	if not plantilla or not mochila or not e then
		return
	end
	local tool = plantilla:Clone()
	tool.Name = plantilla:GetAttribute("Nombre") -- en la mochila se ve el nombre real
	if not esCana then
		local cfg = Config.Armas[id]
		if cfg.cargador then
			tool:SetAttribute("Cargador", e.cargadores[id] or 0)
			tool:GetAttributeChangedSignal("Cargador"):Connect(function()
				e.cargadores[id] = tool:GetAttribute("Cargador")
			end)
		end
	end
	tool.Parent = mochila
	return tool
end

local function tieneHerramienta(jugador, id)
	for _, donde in ipairs({ jugador:FindFirstChild("Backpack"), jugador.Character }) do
		if donde then
			for _, t in ipairs(donde:GetChildren()) do
				if t:IsA("Tool") and (t:GetAttribute("Arma") == id or t:GetAttribute("Cana") == id) then
					return true
				end
			end
		end
	end
	return false
end

local function ordenadas(t, cfgs)
	local ids = lista(t)
	table.sort(ids, function(a, b)
		return (cfgs[a] and cfgs[a].orden or 99) < (cfgs[b] and cfgs[b].orden or 99)
	end)
	return ids
end

local function equipar(jugador)
	local e = datos[jugador]
	local mochila = jugador:WaitForChild("Backpack", 10)
	if not e or not mochila then
		return
	end
	for _, t in ipairs(mochila:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("CazaPesca") then
			t:Destroy()
		end
	end
	for _, id in ipairs(ordenadas(e.armas, Config.Armas)) do
		if Config.Armas[id] then
			darHerramienta(jugador, id, false)
		end
	end
	for _, id in ipairs(ordenadas(e.canas, Config.Canas)) do
		if Config.Canas[id] then
			darHerramienta(jugador, id, true)
		end
	end
	for id, cfg in pairs(Config.Armas) do
		if cfg.tipo == "lanzable" and (e.municion[cfg.municion] or 0) > 0 then
			darHerramienta(jugador, id, false)
		end
	end
end

-- =====================================================================
--  Munición
-- =====================================================================
function Economia.municion(jugador, tipo)
	local e = datos[jugador]
	return e and (e.municion[tipo] or 0) or 0
end

function Economia.gastar(jugador, tipo, n)
	local e = datos[jugador]
	if e then
		e.municion[tipo] = math.max(0, (e.municion[tipo] or 0) - n)
		jugador:SetAttribute("Municion_" .. tipo, e.municion[tipo])
	end
end

-- =====================================================================
--  Botín de caza y pesca
-- =====================================================================
function Economia.darBotin(jugador, botin, animal)
	local e = datos[jugador]
	if not e then
		return
	end
	for _, b in ipairs(botin) do
		local junto = false
		for _, o in ipairs(e.objetos) do
			if o.id == b.id and o.calidad == b.calidad then
				o.cantidad = math.floor((o.cantidad + b.cantidad) * 10 + 0.5) / 10
				o.valor = o.valor + b.valor
				junto = true
				break
			end
		end
		if not junto then
			table.insert(e.objetos, { id = b.id, nombre = b.nombre, cantidad = b.cantidad, unidad = b.unidad, valor = b.valor, calidad = b.calidad })
		end
	end
	e.caza[animal.especie] = (e.caza[animal.especie] or 0) + 1
	remotos.Aviso:FireClient(jugador, "botin", { nombre = animal.def.nombre, peso = animal.peso, botin = botin })
	enviar(jugador)
end

-- Devuelve true si es el pez más grande de su especie que ha pescado el jugador
function Economia.darPez(jugador, pez)
	local e = datos[jugador]
	if not e then
		return false
	end
	table.insert(e.peces, { id = pez.id, nombre = pez.nombre, peso = pez.peso, valor = pez.valor })
	while #e.peces > MAX_PECES do
		table.remove(e.peces, 1)
	end
	e.capturas[pez.id] = (e.capturas[pez.id] or 0) + 1
	local record = pez.peso > (e.records[pez.id] or 0)
	if record then
		e.records[pez.id] = pez.peso
	end
	enviar(jugador)
	return record
end

-- =====================================================================
--  Tienda
-- =====================================================================
local function cercaDeTienda(jugador)
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	for _, prompt in ipairs(CollectionService:GetTagged("TiendaCaza")) do
		local parte = prompt.Parent
		if parte and parte:IsA("BasePart") and (parte.Position - hrp.Position).Magnitude < 30 then
			return true
		end
	end
	return false
end

function Economia.vender(jugador)
	local e = datos[jugador]
	if not e or not cercaDeTienda(jugador) then
		return
	end
	local total = valorMochila(e)
	local n = #e.objetos + #e.peces
	if n == 0 then
		remotos.Aviso:FireClient(jugador, "mensaje", { texto = "No llevas nada que vender." })
		return
	end
	e.dinero = e.dinero + total
	e.objetos = {}
	e.peces = {}
	remotos.Aviso:FireClient(jugador, "venta", { total = total, n = n })
	enviar(jugador)
end

-- tipo: "arma", "cana" o "municion"
function Economia.comprar(jugador, tipo, id)
	local e = datos[jugador]
	if not e or type(id) ~= "string" then
		return
	end
	local function mensaje(texto)
		remotos.Aviso:FireClient(jugador, "mensaje", { texto = texto })
	end
	if not cercaDeTienda(jugador) then
		return mensaje("Tienes que estar en una tienda de caza y pesca.")
	end
	local cfg, precio
	if tipo == "arma" then
		cfg = Config.Armas[id]
		if not cfg or cfg.tipo == "lanzable" then
			return
		end
		if e.armas[id] then
			return mensaje("Ya tienes " .. cfg.nombre .. ".")
		end
		precio = cfg.precio
	elseif tipo == "cana" then
		cfg = Config.Canas[id]
		if not cfg then
			return
		end
		if e.canas[id] then
			return mensaje("Ya tienes " .. cfg.nombre .. ".")
		end
		precio = cfg.precio
	elseif tipo == "municion" then
		cfg = Config.Municion[id]
		if not cfg then
			return
		end
		precio = cfg.precio
	else
		return
	end
	if e.dinero < precio then
		return mensaje("No tienes dinero suficiente.")
	end
	e.dinero = e.dinero - precio
	if tipo == "arma" then
		e.armas[id] = true
		-- Cada arma trae una caja de su munición
		if cfg.municion and Config.Municion[cfg.municion] then
			e.municion[cfg.municion] = (e.municion[cfg.municion] or 0) + Config.Municion[cfg.municion].paquete
		end
		darHerramienta(jugador, id, false)
	elseif tipo == "cana" then
		e.canas[id] = true
		darHerramienta(jugador, id, true)
	else
		e.municion[id] = (e.municion[id] or 0) + cfg.paquete
		-- Molotov y granada son herramientas que aparecen cuando tienes alguna
		for armaId, a in pairs(Config.Armas) do
			if a.tipo == "lanzable" and a.municion == id and not tieneHerramienta(jugador, armaId) then
				darHerramienta(jugador, armaId, false)
			end
		end
	end
	remotos.Aviso:FireClient(jugador, "compra", { nombre = cfg.nombre, precio = precio })
	enviar(jugador)
end

-- =====================================================================
--  Guardar y cargar
-- =====================================================================
local CAMPOS = { "dinero", "armas", "canas", "municion", "cargadores", "objetos", "peces", "records", "capturas", "caza" }

local function cargar(jugador)
	local e = nuevo()
	if almacen then
		local ok, guardado = pcall(function()
			return almacen:GetAsync("j_" .. jugador.UserId)
		end)
		if ok and type(guardado) == "table" then
			for _, campo in ipairs(CAMPOS) do
				if guardado[campo] ~= nil then
					e[campo] = guardado[campo]
				end
			end
		elseif not ok and not avisadoGuardado then
			avisadoGuardado = true
			warn("[Caza] No se pueden cargar los datos guardados (en Studio activa el acceso a los servicios de API):", guardado)
		end
	end
	return e
end

local function guardar(jugador)
	local e = datos[jugador]
	if not almacen or not e then
		return
	end
	local copia = {}
	for _, campo in ipairs(CAMPOS) do
		copia[campo] = e[campo]
	end
	local ok, err = pcall(function()
		almacen:SetAsync("j_" .. jugador.UserId, copia)
	end)
	if not ok and not avisadoGuardado then
		avisadoGuardado = true
		warn("[Caza] No se pudo guardar:", err)
	end
end

local function entrar(jugador)
	local ls = jugador:FindFirstChild("leaderstats") or Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = jugador
	local dinero = ls:FindFirstChild("Dinero") or Instance.new("IntValue")
	dinero.Name = "Dinero"
	dinero.Parent = ls
	datos[jugador] = cargar(jugador)
	jugador.CharacterAdded:Connect(function()
		task.wait(0.2)
		equipar(jugador)
		enviar(jugador)
	end)
	if jugador.Character then
		equipar(jugador)
	end
	enviar(jugador)
end

function Economia.iniciar(ctx)
	Config, Modelos, remotos = ctx.Config, ctx.Modelos, ctx.remotos
	-- Plantillas de todas las armas y cañas (se copian a la mochila de cada jugador)
	plantillas = ServerStorage:FindFirstChild("CazaHerramientas") or Instance.new("Folder")
	plantillas.Name = "CazaHerramientas"
	plantillas:ClearAllChildren()
	plantillas.Parent = ServerStorage
	for id, cfg in pairs(Config.Armas) do
		local t = Modelos.herramienta(id, cfg, false)
		t.Name = "Arma_" .. id
		t:SetAttribute("Nombre", cfg.nombre)
		t.Parent = plantillas
	end
	for id, cfg in pairs(Config.Canas) do
		local t = Modelos.herramienta(id, cfg, true)
		t.Name = "Cana_" .. id
		t:SetAttribute("Nombre", cfg.nombre)
		t.Parent = plantillas
	end
	if Config.GuardarDatos then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore("CazaPesca_v1")
		end)
		if ok then
			almacen = ds
		end
	end
	local function conectarTienda(prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.Triggered:Connect(function(jugador)
			if prompt:GetAttribute("Accion") == "Vender" then
				Economia.vender(jugador)
			else
				remotos.Tienda:FireClient(jugador, "abrir", { nombre = prompt:GetAttribute("Tienda") or "Tienda de caza y pesca" })
				enviar(jugador)
			end
		end)
	end
	for _, prompt in ipairs(CollectionService:GetTagged("TiendaCaza")) do
		conectarTienda(prompt)
	end
	CollectionService:GetInstanceAddedSignal("TiendaCaza"):Connect(conectarTienda)
	Players.PlayerAdded:Connect(entrar)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(entrar, p)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		guardar(jugador)
		datos[jugador] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do
			guardar(p)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, p in ipairs(Players:GetPlayers()) do
				guardar(p)
			end
		end
	end)
end

function Economia.datos(jugador)
	return datos[jugador]
end

return Economia
]=]
CAZA_CLIENTE_MODULOS["Pantalla"] = [=[
--[[
	Pantalla de la caza y la pesca (cliente): dinero, munición, mira, avisos, mochila, tienda y la barra
	de tensión del sedal. Todo se crea por código en PlayerGui.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Pantalla = {}
local Config
local gui
local refs = {}

local BLANCO = Color3.fromRGB(240, 236, 226)
local GRIS = Color3.fromRGB(170, 166, 156)
local FONDO = Color3.fromRGB(22, 24, 22)
local VERDE = Color3.fromRGB(120, 200, 110)
local ROJO = Color3.fromRGB(220, 70, 60)
local DORADO = Color3.fromRGB(236, 196, 90)

local function nuevo(clase, props, padre)
	local o = Instance.new(clase)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = padre
	return o
end

local function redondear(o, r)
	nuevo("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
	return o
end

local function texto(props, padre)
	local t = nuevo("TextLabel", {
		BackgroundTransparency = 1, TextColor3 = BLANCO, Font = Enum.Font.GothamMedium, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, padre)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

local function boton(props, padre, alPulsar)
	local b = nuevo("TextButton", {
		BackgroundColor3 = Color3.fromRGB(60, 74, 52), TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 15,
		AutoButtonColor = true,
	}, padre)
	for k, v in pairs(props) do
		b[k] = v
	end
	redondear(b, 6)
	if alPulsar then
		b.MouseButton1Click:Connect(alPulsar)
	end
	return b
end

-- Números a la española: 1,8 kg · 1.250 $
local function kg(n)
	local s = (n >= 10) and string.format("%.1f", n) or string.format("%.2f", n)
	return (s:gsub("%.", ",")) .. " kg"
end
Pantalla.kg = kg
local function dinero(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out .. " $"
end
Pantalla.dineroTexto = dinero

function Pantalla.crear(config)
	Config = config
	local jugador = Players.LocalPlayer
	gui = nuevo("ScreenGui", { Name = "CazaPantalla", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, jugador:WaitForChild("PlayerGui"))

	-- Dinero (arriba a la derecha)
	local caja = redondear(nuevo("Frame", { Size = UDim2.fromOffset(210, 54), Position = UDim2.new(1, -226, 0, 60), BackgroundColor3 = FONDO, BackgroundTransparency = 0.35 }, gui))
	refs.dinero = texto({ Name = "Dinero", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(12, 4), Text = dinero(0), TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, caja)
	refs.mochilaValor = texto({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 31), Text = "Mochila: 0 $  ·  B", TextSize = 13, TextColor3 = GRIS }, caja)

	-- Arma (abajo a la derecha)
	local arma = redondear(nuevo("Frame", { Size = UDim2.fromOffset(250, 74), Position = UDim2.new(1, -266, 1, -170), BackgroundColor3 = FONDO, BackgroundTransparency = 0.35, Visible = false }, gui))
	refs.armaCaja = arma
	refs.armaNombre = texto({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 14, TextColor3 = GRIS }, arma)
	refs.armaBalas = texto({ Name = "Balas", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 24), Text = "", TextSize = 28, Font = Enum.Font.GothamBold }, arma)
	refs.armaAyuda = texto({ Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(12, 54), Text = "", TextSize = 12, TextColor3 = GRIS }, arma)

	-- Mira (cuatro rayitas que se separan con la dispersión) y marca de acierto
	local mira = nuevo("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, gui)
	refs.mira = mira
	refs.rayas = {}
	for i, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local vertical = d[1] == 0
		refs.rayas[i] = { nuevo("Frame", { Size = vertical and UDim2.fromOffset(2, 9) or UDim2.fromOffset(9, 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BLANCO, BorderSizePixel = 0 }, mira), d }
	end
	nuevo("Frame", { Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BLANCO, BorderSizePixel = 0 }, mira)
	refs.acierto = texto({ Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Text = "✕", TextSize = 30, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1 }, gui)

	-- Mira telescópica: todo negro salvo un círculo central con retícula
	local tele = nuevo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	refs.tele = tele
	local hueco = nuevo("Frame", { Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeYY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, tele)
	nuevo("UIStroke", { Thickness = 900, Color = Color3.new(0, 0, 0) }, redondear(hueco, 2000))
	nuevo("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	nuevo("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	for _, y in ipairs({ 0.58, 0.64, 0.7 }) do
		nuevo("Frame", { Size = UDim2.new(0.04, 0, 0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, y), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	end

	-- Avisos (arriba en el centro)
	refs.avisos = nuevo("Frame", { Name = "Avisos", Size = UDim2.fromOffset(560, 200), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), BackgroundTransparency = 1 }, gui)
	nuevo("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.avisos)

	-- Pesca (abajo en el centro)
	local pesca = redondear(nuevo("Frame", { Size = UDim2.fromOffset(380, 96), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), BackgroundColor3 = FONDO, BackgroundTransparency = 0.3, Visible = false }, gui))
	refs.pesca = pesca
	refs.pescaTexto = texto({ Name = "PescaTexto", Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center }, pesca)
	local barra = redondear(nuevo("Frame", { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 40), BackgroundColor3 = Color3.fromRGB(50, 52, 48) }, pesca), 5)
	refs.tension = redondear(nuevo("Frame", { Name = "Tension", Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = VERDE, BorderSizePixel = 0 }, barra), 5)
	nuevo("Frame", { Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(0.82, 0, 0, -2), BackgroundColor3 = ROJO, BorderSizePixel = 0 }, barra)
	refs.barraPesca = barra
	refs.pescaInfo = texto({ Name = "PescaInfo", Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 64), Text = "", TextSize = 13, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Center }, pesca)

	-- Destello rojo al recibir un mordisco
	refs.herido = nuevo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, ZIndex = 0 }, gui)

	-- Mochila (B)
	local mochila = redondear(nuevo("Frame", { Size = UDim2.fromOffset(360, 440), Position = UDim2.new(1, -376, 0, 124), BackgroundColor3 = FONDO, BackgroundTransparency = 0.12, Visible = false }, gui), 10)
	refs.mochila = mochila
	texto({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 8), Text = "Mochila", TextSize = 20, Font = Enum.Font.GothamBold }, mochila)
	refs.mochilaLista = nuevo("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -86), Position = UDim2.fromOffset(12, 42), BackgroundTransparency = 1, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, mochila)
	nuevo("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, refs.mochilaLista)
	refs.mochilaTotal = texto({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -38), Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, mochila)

	-- Tienda
	local tienda = redondear(nuevo("Frame", { Size = UDim2.fromOffset(680, 480), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = FONDO, BackgroundTransparency = 0.05, Visible = false }, gui), 12)
	refs.tienda = tienda
	refs.tiendaTitulo = texto({ Size = UDim2.new(1, -120, 0, 34), Position = UDim2.fromOffset(18, 10), Text = "Tienda de caza y pesca", TextSize = 22, Font = Enum.Font.GothamBold }, tienda)
	boton({ Size = UDim2.fromOffset(36, 32), Position = UDim2.new(1, -50, 0, 10), Text = "✕", BackgroundColor3 = Color3.fromRGB(110, 50, 44) }, tienda, function()
		tienda.Visible = false
	end)
	refs.pestanas = {}
	for i, p in ipairs({ { "arma", "Armas" }, { "cana", "Cañas" }, { "municion", "Munición" } }) do
		refs.pestanas[p[1]] = boton({ Size = UDim2.fromOffset(130, 32), Position = UDim2.fromOffset(18 + (i - 1) * 138, 52), Text = p[2] }, tienda, function()
			refs.pestana = p[1]
			Pantalla.refrescarTienda()
		end)
	end
	refs.pestana = "arma"
	refs.tiendaLista = nuevo("ScrollingFrame", { Size = UDim2.new(1, -36, 1, -150), Position = UDim2.fromOffset(18, 94), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, tienda)
	nuevo("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.tiendaLista)
	refs.tiendaDinero = texto({ Size = UDim2.fromOffset(260, 30), Position = UDim2.new(0, 18, 1, -46), Text = "", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, tienda)
	refs.vender = boton({ Size = UDim2.fromOffset(260, 36), Position = UDim2.new(1, -278, 1, -50), Text = "Vender la mochila", BackgroundColor3 = Color3.fromRGB(150, 116, 40) }, tienda, function()
		if refs.alVender then
			refs.alVender()
		end
	end)

	-- Botones para móvil y tableta
	refs.movil = nuevo("Frame", { Size = UDim2.fromOffset(200, 200), Position = UDim2.new(1, -230, 1, -420), BackgroundTransparency = 1, Visible = false }, gui)
	return gui
end

-- =====================================================================
--  Actualizaciones
-- =====================================================================
function Pantalla.estado(e)
	refs.e = e
	refs.dinero.Text = dinero(e.dinero)
	refs.mochilaValor.Text = string.format("Mochila: %s  ·  B", dinero(e.valor))
	if refs.mochila.Visible then
		Pantalla.refrescarMochila()
	end
	if refs.tienda.Visible then
		Pantalla.refrescarTienda()
	end
end

function Pantalla.arma(nombre, linea, ayuda)
	refs.armaCaja.Visible = nombre ~= nil
	if nombre then
		refs.armaNombre.Text = nombre
		refs.armaBalas.Text = linea or ""
		refs.armaAyuda.Text = ayuda or ""
	end
end

function Pantalla.mira(visible, separacion)
	refs.mira.Visible = visible
	if visible then
		for _, r in ipairs(refs.rayas) do
			local d = r[2]
			r[1].Position = UDim2.fromOffset(1 + d[1] * (separacion + 5), 1 + d[2] * (separacion + 5))
		end
	end
end

function Pantalla.telescopica(visible)
	refs.tele.Visible = visible
end

function Pantalla.acierto(muerto, cabeza)
	local a = refs.acierto
	a.TextColor3 = muerto and ROJO or BLANCO
	a.TextSize = cabeza and 38 or 30
	a.TextTransparency = 0
	TweenService:Create(a, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
end

function Pantalla.herido()
	refs.herido.BackgroundTransparency = 0.55
	TweenService:Create(refs.herido, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

local orden = 0
function Pantalla.aviso(txt, color, segundos)
	orden = orden + 1
	local hijos = {}
	for _, c in ipairs(refs.avisos:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(hijos, c)
		end
	end
	if #hijos >= 4 then
		hijos[1]:Destroy()
	end
	local t = texto({
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = txt, TextSize = 17, Font = Enum.Font.GothamBold,
		TextColor3 = color or BLANCO, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, LayoutOrder = orden,
	}, refs.avisos)
	task.delay(segundos or 4, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.55, function()
				t:Destroy()
			end)
		end
	end)
	return t
end

-- Pesca: texto arriba y barra de tensión
function Pantalla.pesca(visible, txt, info)
	refs.pesca.Visible = visible
	if visible then
		refs.pescaTexto.Text = txt or ""
		refs.pescaInfo.Text = info or ""
	end
end

function Pantalla.tension(t, info, aviso)
	refs.barraPesca.Visible = t ~= nil
	if t then
		refs.tension.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
		refs.tension.BackgroundColor3 = (t < 0.55) and VERDE or ((t < 0.82) and Color3.fromRGB(230, 190, 70) or ROJO)
	end
	if info then
		refs.pescaInfo.Text = info
	end
	if aviso then
		refs.pescaTexto.Text = aviso
	end
end

-- =====================================================================
--  Mochila
-- =====================================================================
function Pantalla.alternarMochila()
	refs.mochila.Visible = not refs.mochila.Visible
	if refs.mochila.Visible then
		Pantalla.refrescarMochila()
	end
end

function Pantalla.refrescarMochila()
	local e = refs.e
	local lista = refs.mochilaLista
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not e then
		return
	end
	local n = 0
	local function fila(izq, der, color)
		n = n + 1
		local f = nuevo("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = n }, lista)
		texto({ Size = UDim2.new(0.72, 0, 1, 0), Text = izq, TextSize = 14, TextColor3 = color or BLANCO, TextTruncate = Enum.TextTruncate.AtEnd }, f)
		texto({ Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), Text = der or "", TextSize = 14, TextColor3 = DORADO, TextXAlignment = Enum.TextXAlignment.Right }, f)
	end
	if #e.objetos == 0 and #e.peces == 0 then
		fila("Vacía. Caza o pesca algo.", "", GRIS)
	end
	for _, o in ipairs(e.objetos) do
		local cant = (o.unidad == "kg") and kg(o.cantidad) or ("x" .. o.cantidad)
		fila(string.format("%s %s%s", o.nombre, cant, o.calidad and (" · " .. o.calidad) or ""), dinero(o.valor))
	end
	-- Peces agrupados por especie
	local grupos, ordenG = {}, {}
	for _, p in ipairs(e.peces) do
		local g = grupos[p.id]
		if not g then
			g = { nombre = p.nombre, n = 0, kg = 0, valor = 0 }
			grupos[p.id] = g
			table.insert(ordenG, p.id)
		end
		g.n, g.kg, g.valor = g.n + 1, g.kg + p.peso, g.valor + p.valor
	end
	for _, id in ipairs(ordenG) do
		local g = grupos[id]
		fila(string.format("%s x%d (%s)", g.nombre, g.n, kg(g.kg)), dinero(g.valor), Color3.fromRGB(150, 200, 230))
	end
	-- Récords de pesca
	local recs = {}
	for id, peso in pairs(e.records or {}) do
		table.insert(recs, { id, peso })
	end
	table.sort(recs, function(a, b)
		return a[2] > b[2]
	end)
	if #recs > 0 then
		fila("Récords de pesca", "", GRIS)
		for _, r in ipairs(recs) do
			local pez = Config.Peces[r[1]]
			fila("  " .. (pez and pez.nombre or r[1]), kg(r[2]), GRIS)
		end
	end
	refs.mochilaTotal.Text = "Valor total: " .. dinero(e.valor)
end

-- =====================================================================
--  Tienda
-- =====================================================================
function Pantalla.abrirTienda(nombre, alComprar, alVender)
	refs.alComprar, refs.alVender = alComprar, alVender
	refs.tiendaTitulo.Text = nombre or "Tienda de caza y pesca"
	refs.tienda.Visible = true
	Pantalla.refrescarTienda()
end

function Pantalla.tiendaAbierta()
	return refs.tienda.Visible
end

function Pantalla.cerrarTienda()
	refs.tienda.Visible = false
end

local function tiene(lista, id)
	for _, v in ipairs(lista or {}) do
		if v == id then
			return true
		end
	end
	return false
end

function Pantalla.refrescarTienda()
	local e = refs.e or { dinero = 0, armas = {}, canas = {}, municion = {}, valor = 0 }
	for clave, b in pairs(refs.pestanas) do
		b.BackgroundColor3 = (clave == refs.pestana) and Color3.fromRGB(96, 120, 70) or Color3.fromRGB(56, 62, 50)
	end
	refs.tiendaDinero.Text = "Tienes " .. dinero(e.dinero)
	refs.vender.Text = "Vender la mochila (" .. dinero(e.valor or 0) .. ")"
	local lista = refs.tiendaLista
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local items = {}
	if refs.pestana == "arma" then
		for id, cfg in pairs(Config.Armas) do
			if cfg.tipo ~= "lanzable" then
				local extra = cfg.municion and Config.Municion[cfg.municion] and (" · usa " .. Config.Municion[cfg.municion].nombre:lower()) or ""
				table.insert(items, { id = id, nombre = cfg.nombre, desc = (cfg.desc or "") .. extra, precio = cfg.precio, orden = cfg.orden, tengo = tiene(e.armas, id) })
			end
		end
	elseif refs.pestana == "cana" then
		for id, cfg in pairs(Config.Canas) do
			local desc = string.format("%s Lanza %d m · aguanta %s", cfg.desc or "", cfg.distancia, kg(cfg.resistencia))
			table.insert(items, { id = id, nombre = cfg.nombre, desc = desc, precio = cfg.precio, orden = cfg.orden, tengo = tiene(e.canas, id) })
		end
	else
		for id, cfg in pairs(Config.Municion) do
			table.insert(items, { id = id, nombre = string.format("%s (x%d)", cfg.nombre, cfg.paquete), desc = "Tienes " .. ((e.municion or {})[id] or 0),
				precio = cfg.precio, orden = cfg.orden, tengo = false })
		end
	end
	table.sort(items, function(a, b)
		return a.orden < b.orden
	end)
	for i, it in ipairs(items) do
		local f = redondear(nuevo("Frame", { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = Color3.fromRGB(38, 42, 36), LayoutOrder = i }, lista), 8)
		texto({ Size = UDim2.new(1, -190, 0, 22), Position = UDim2.fromOffset(12, 6), Text = it.nombre, TextSize = 16, Font = Enum.Font.GothamBold }, f)
		texto({ Size = UDim2.new(1, -190, 0, 26), Position = UDim2.fromOffset(12, 28), Text = it.desc, TextSize = 12, TextColor3 = GRIS }, f)
		texto({ Size = UDim2.fromOffset(80, 22), Position = UDim2.new(1, -176, 0, 18), Text = (it.precio > 0) and dinero(it.precio) or "Gratis", TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = DORADO, TextXAlignment = Enum.TextXAlignment.Right }, f)
		local puede = (not it.tengo) and e.dinero >= it.precio
		boton({ Size = UDim2.fromOffset(84, 34), Position = UDim2.new(1, -92, 0, 12), Text = it.tengo and "Lo tienes" or "Comprar",
			BackgroundColor3 = puede and Color3.fromRGB(70, 120, 60) or Color3.fromRGB(70, 70, 66), AutoButtonColor = puede }, f, function()
			if puede and refs.alComprar then
				refs.alComprar(refs.pestana, it.id)
			end
		end)
	end
end

-- =====================================================================
--  Móvil: botones en pantalla
-- =====================================================================
function Pantalla.botonesMovil(acciones)
	local m = refs.movil
	m.Visible = true
	local botones = {}
	for i, a in ipairs(acciones) do
		local fila, col = math.floor((i - 1) / 2), (i - 1) % 2
		botones[a[1]] = boton({ Size = UDim2.fromOffset(92, 46), Position = UDim2.fromOffset(col * 100, fila * 54), Text = a[2], BackgroundTransparency = 0.25 }, m, a[3])
	end
	return botones
end

return Pantalla
]=]
CAZA_CLIENTE_MODULOS["Efectos"] = [=[
--[[
	Efectos de la caza y la pesca (cliente, solo se ven en tu pantalla):
	  · Balas (trazadora), flechas y lanzables que siguen la misma trayectoria que calcula el servidor.
	    Las flechas se quedan clavadas en el suelo o en el animal (y se mueven con él).
	  · Fogonazo, sonidos, sangre, polvo, salpicaduras y temblor de cámara con las explosiones.
	  · Animación de los animales: patas al andar, al trotar y al galopar, cabeza baja al pastar,
	    mirar alrededor, cola levantada al huir (como hacen los ciervos)...
	  · Peces nadando bajo el agua cerca de ti y el pez en la mano cuando pescas uno.
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Efectos = {}
local Config, M
local carpeta, animales
local proyectiles = {}
local cache = setmetatable({}, { __mode = "k" })
local cardumenes = {}
local sacudida = 0
local paramsAgua

local function pieza(props, padre)
	local p = Instance.new(props.clase or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material[props.mat or "SmoothPlastic"]
	for k, v in pairs(props) do
		if k ~= "clase" and k ~= "mat" and k ~= "elipse" then
			p[k] = v
		end
	end
	if props.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = padre or carpeta
	return p
end

local function sonido(id, pos, volumen)
	if not id or id == "" then
		return
	end
	local p = pieza({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 1
	s.RollOffMaxDistance = 600
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 6)
end
Efectos.sonido = sonido

local function particulas(pos, color, n, velocidad, tam, gravedad)
	local p = pieza({ Size = Vector3.new(0.3, 0.3, 0.3), Transparency = 1, Position = pos })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(tam or 0.25, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(velocidad * 0.5, velocidad)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -(gravedad or 40), 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, 2)
end

-- =====================================================================
--  Proyectiles
-- =====================================================================
local function modeloFlecha(ballesta)
	local largo = ballesta and 1.2 or 2.4
	local m = Instance.new("Model")
	m.Name = "Flecha"
	local asta = pieza({ Name = "Asta", Size = Vector3.new(0.06, 0.06, largo), Color = Color3.fromRGB(34, 34, 36), CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(0.03, 0.14, 0.24), Color = Color3.fromRGB(200, 200, 206), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0, -largo / 2 - 0.1) }, m)
	for i = 0, 2 do
		local ang = math.rad(i * 120)
		pieza({ Size = Vector3.new(0.02, 0.16, 0.36), Color = (i == 0) and Color3.fromRGB(230, 110, 30) or Color3.fromRGB(236, 236, 230),
			CFrame = CFrame.new(0, 0, largo / 2 - 0.25) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.08, 0) }, m)
	end
	m.PrimaryPart = asta
	m.Parent = carpeta
	return m, largo
end

local function modeloLanzable(arma)
	local m = Instance.new("Model")
	if arma == "Molotov" then
		local b = pieza({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.62, 0.34, 0.34), Color = Color3.fromRGB(70, 100, 56), Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.new() }, m)
		local trapo = pieza({ Size = Vector3.new(0.3, 0.14, 0.14), Color = Color3.fromRGB(196, 186, 166), CFrame = CFrame.new(0.42, 0, 0) }, m)
		local f = Instance.new("Fire")
		f.Size = 1.5
		f.Heat = 3
		f.Parent = trapo
		m.PrimaryPart = b
	else
		m.PrimaryPart = pieza({ Size = Vector3.new(0.32, 0.44, 0.32), Color = Color3.fromRGB(76, 80, 62), Material = Enum.Material.Metal, elipse = true, CFrame = CFrame.new() }, m)
	end
	m.Parent = carpeta
	return m
end

function Efectos.disparo(d)
	local cfg = Config.Armas[d.arma]
	if not cfg then
		return
	end
	local p = { desde = d.desde, v = d.v, g = d.g, t = 0, tipo = cfg.tipo, arma = d.arma }
	if cfg.tipo == "bala" then
		p.visual = pieza({ Size = Vector3.new(0.05, 0.05, 2), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(d.desde) })
		-- Fogonazo (una vez por disparo, no por perdigón)
		if d.id % (cfg.perdigones or 1) == 0 then
			local f = pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Position = d.desde })
			local luz = Instance.new("PointLight")
			luz.Color = Color3.fromRGB(255, 190, 110)
			luz.Brightness = 4
			luz.Range = 14
			luz.Parent = f
			Debris:AddItem(f, 0.06)
			sonido(Config.Sonidos[d.arma], d.desde, 1)
		end
	elseif cfg.tipo == "proyectil" then
		p.visual, p.largo = modeloFlecha(d.arma == "Ballesta")
		sonido(Config.Sonidos[d.arma], d.desde, 0.8)
	else
		p.visual = modeloLanzable(d.arma)
		sonido(Config.Sonidos.Lanzar, d.desde, 0.8)
	end
	proyectiles[d.id] = p
end

local function quitar(id)
	local p = proyectiles[id]
	proyectiles[id] = nil
	return p
end

function Efectos.impacto(d)
	local p = d.id and quitar(d.id)
	if p then
		if p.tipo == "proyectil" then
			-- La flecha se queda clavada (y unida al animal si le ha dado)
			local vel = p.v + Vector3.new(0, p.g * p.t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(d.pos - dir * (p.largo * 0.2), d.pos - dir * (p.largo * 0.2) + dir)
			p.visual:PivotTo(cf)
			if d.parte and d.parte.Parent then
				for _, parte in ipairs(p.visual:GetChildren()) do
					if parte:IsA("BasePart") then
						parte.Anchored = false
						parte.Massless = true
						local w = Instance.new("WeldConstraint")
						w.Part0 = d.parte
						w.Part1 = parte
						w.Parent = parte
					end
				end
			end
			Debris:AddItem(p.visual, 30)
		else
			p.visual:Destroy()
		end
	end
	if d.tipo == "animal" or d.tipo == "jugador" then
		particulas(d.pos, Color3.fromRGB(120, 10, 8), 16, 8, 0.18, 30)
	elseif d.tipo == "agua" then
		particulas(d.pos, Color3.fromRGB(220, 230, 235), 20, 12, 0.3, 50)
	elseif d.tipo == "suelo" then
		particulas(d.pos, Color3.fromRGB(120, 108, 90), 10, 6, 0.3, 20)
	end
	if d.tipo ~= "lanzable" then
		sonido(Config.Sonidos.Impacto, d.pos, 0.6)
	end
end

function Efectos.fin(d)
	local p = quitar(d.id)
	if p then
		p.visual:Destroy()
	end
end

function Efectos.explosion(d, posCamara)
	local dist = (d.pos - posCamara).Magnitude
	if not d.fuego then
		sacudida = math.max(sacudida, math.clamp(1 - dist / 220, 0, 1) * 1.6)
		particulas(d.pos, Color3.fromRGB(70, 66, 60), 30, 25, 0.8, 10)
	end
end

local function sonidoEn(jugadorId, id, volumen)
	local p = Players:GetPlayerByUserId(jugadorId)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		sonido(id, hrp.Position, volumen)
	end
end

function Efectos.golpe(d)
	sonidoEn(d.jugador, Config.Sonidos.Cuerpo, 0.7)
end

function Efectos.recarga(d)
	sonidoEn(d.jugador, Config.Sonidos.Recarga, 0.8)
end

function Efectos.chapoteo(d)
	particulas(d.pos, Color3.fromRGB(220, 232, 236), 14, 6, 0.25, 30)
	sonido(Config.Sonidos.Chapoteo, d.pos, 0.7)
end

function Efectos.sacudir(n)
	sacudida = math.max(sacudida, n)
end

-- Temblor de cámara (se aplica después de que Roblox coloca la cámara)
function Efectos.camara(dt, camara)
	if sacudida > 0.01 then
		local a = sacudida
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * a * 2), math.rad((math.random() - 0.5) * a * 2), 0)
		sacudida = sacudida * math.exp(-dt * 6)
	end
end

-- =====================================================================
--  Peces: el de la mano al pescar y los que nadan bajo el agua
-- =====================================================================
-- Largo de un pez según su peso (la relación real peso-talla: W ≈ 0,01·L³ en gramos y cm)
local function largoPez(peso)
	return ((peso * 1000) / 0.01) ^ (1 / 3) / 100 * M
end

local function modeloPez(color, largo, transparencia)
	local m = Instance.new("Model")
	m.Name = "Pez"
	local c = Color3.fromRGB(color[1], color[2], color[3])
	local cuerpo = pieza({ Size = Vector3.new(largo * 0.2, largo * 0.28, largo), Color = c, elipse = true, Transparency = transparencia or 0, CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(largo * 0.16, largo * 0.14, largo * 0.8), Color = c:Lerp(Color3.new(1, 1, 1), 0.5), elipse = true,
		Transparency = transparencia or 0, CFrame = CFrame.new(0, -largo * 0.06, 0) }, m)
	for _, k in ipairs({ 1, -1 }) do
		pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.2, largo * 0.22), Color = c:Lerp(Color3.new(0, 0, 0), 0.2), Transparency = transparencia or 0,
			CFrame = CFrame.new(0, k * largo * 0.08, largo * 0.55) * CFrame.Angles(math.rad(k * 35), 0, 0) }, m)
	end
	pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.12, largo * 0.3), Color = c:Lerp(Color3.new(0, 0, 0), 0.25), Transparency = transparencia or 0,
		CFrame = CFrame.new(0, largo * 0.16, 0.02 * largo) }, m)
	if not transparencia then
		for _, k in ipairs({ 1, -1 }) do
			pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * largo * 0.05, Color = Color3.new(0.05, 0.05, 0.05), CFrame = CFrame.new(k * largo * 0.08, largo * 0.04, -largo * 0.36) }, m)
		end
	end
	m.PrimaryPart = cuerpo
	m.Parent = carpeta
	return m
end

function Efectos.pez(d)
	local p = Players:GetPlayerByUserId(d.jugador)
	local char = p and p.Character
	local mano = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local pez = Config.Peces[d.id]
	if not mano or not pez then
		return
	end
	local largo = math.clamp(largoPez(d.peso), 0.6, 9)
	local m = modeloPez(pez.color, largo)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 3 and m.Parent and mano.Parent do
			-- Colgando de la mano, coleteando
			m:PivotTo(mano.CFrame * CFrame.new(0, -largo * 0.5 - 0.4, 0) * CFrame.Angles(math.rad(90), math.rad(math.sin(os.clock() * 14) * 15), 0))
			task.wait()
		end
		m:Destroy()
	end)
end

local function nuevoCardumen(centro, superficie)
	local c = { centro = centro, y = superficie - 1.4, peces = {}, nace = os.clock(), rumbo = math.random() * math.pi * 2 }
	for i = 1, math.random(4, 7) do
		local largo = (0.25 + math.random() * 0.35) * M
		table.insert(c.peces, { m = modeloPez({ 50, 62, 56 }, largo, 0.35), r = 1.5 + math.random() * 3, a = math.random() * math.pi * 2, v = 0.6 + math.random() * 0.6, h = (math.random() - 0.5) * 0.8 })
	end
	table.insert(cardumenes, c)
end

local siguienteBusqueda = 0
function Efectos.peces(dt, posCamara)
	local ahora = os.clock()
	if ahora > siguienteBusqueda and #cardumenes < 3 then
		siguienteBusqueda = ahora + 1.5
		local ang, r = math.random() * math.pi * 2, 12 + math.random() * 35
		local x, z = posCamara.X + math.cos(ang) * r, posCamara.Z + math.sin(ang) * r
		local agua = workspace:Raycast(Vector3.new(x, posCamara.Y + 80, z), Vector3.new(0, -260, 0), paramsAgua)
		if agua and agua.Material == Enum.Material.Water then
			nuevoCardumen(Vector3.new(x, 0, z), agua.Position.Y)
		end
	end
	for i = #cardumenes, 1, -1 do
		local c = cardumenes[i]
		local lejos = (Vector3.new(c.centro.X, c.y, c.centro.Z) - posCamara).Magnitude > 110
		if lejos or ahora - c.nace > 45 then
			for _, p in ipairs(c.peces) do
				p.m:Destroy()
			end
			table.remove(cardumenes, i)
		else
			c.rumbo = c.rumbo + (math.random() - 0.5) * dt
			c.centro = c.centro + Vector3.new(math.cos(c.rumbo), 0, math.sin(c.rumbo)) * dt * 0.8
			for _, p in ipairs(c.peces) do
				p.a = p.a + p.v * dt
				local pos = Vector3.new(c.centro.X + math.cos(p.a) * p.r, c.y + p.h, c.centro.Z + math.sin(p.a) * p.r)
				local tangente = Vector3.new(-math.sin(p.a), 0, math.cos(p.a))
				p.m:PivotTo(CFrame.lookAt(pos, pos + tangente) * CFrame.Angles(0, math.rad(math.sin(ahora * 9 + p.a) * 10), 0))
			end
		end
	end
end

-- =====================================================================
--  Animación de los animales (Motor6D.Transform; cada cliente anima los que tiene cerca)
-- =====================================================================
local function juntas(modelo)
	local c = cache[modelo]
	if c then
		return c
	end
	c = { m = {}, fase = math.random() * 6.28, semilla = math.random() * 100, cuello = 0, cola = 0, mira = 0 }
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("Motor6D") then
			c.m[d.Name] = d
		end
	end
	cache[modelo] = c
	return c
end

local PASO = { DI = 0, TD = 0, DD = math.pi, TI = math.pi }
local GALOPE = { DI = 0, DD = 0.5, TI = math.pi, TD = math.pi + 0.5 }
local SALTO = { DI = 0, DD = 0.2, TI = math.pi * 0.8, TD = math.pi * 0.8 + 0.2 }
local ID = CFrame.new()

function Efectos.animar(dt, posCamara)
	local t = os.clock()
	for _, modelo in ipairs(animales:GetChildren()) do
		local raiz = modelo.PrimaryPart
		if raiz and (raiz.Position - posCamara).Magnitude < 230 then
			local c = juntas(modelo)
			local mov = modelo:GetAttribute("Mov") or "quieto"
			if mov == "muerto" then
				if not c.muerto then
					c.muerto = true
					for _, m in pairs(c.m) do
						m.Transform = ID
					end
				end
			else
				c.muerto = false
				local escala = modelo:GetAttribute("Escala") or 1
				local especie = modelo:GetAttribute("Especie")
				local corre = mov == "correr"
				local anda = corre or mov == "andar"
				local freq = (corre and 2.3 or 1.3) / math.sqrt(math.max(escala, 0.3))
				if especie == "Conejo" then
					freq = corre and 3.2 or 1.6
				end
				if anda then
					c.fase = c.fase + dt * freq * math.pi * 2
				end
				local f = c.fase
				local amp = anda and (corre and 34 or 18) or 0
				local flex = anda and (corre and 55 or 30) or 0
				local patron = corre and GALOPE or PASO
				if modelo:GetAttribute("Salta") and anda then
					patron, amp = SALTO, 42
				end
				for lado, off in pairs(patron) do
					local cadera, rodilla = c.m["Cadera" .. lado], c.m["Rodilla" .. lado]
					if cadera then
						cadera.Transform = CFrame.Angles(math.rad(amp * math.sin(f + off)), 0, 0)
					end
					if rodilla then
						rodilla.Transform = CFrame.Angles(math.rad(-flex * math.max(0, math.cos(f + off))), 0, 0)
					end
				end
				-- Aves (pavo)
				for lado, off in pairs({ I = 0, D = math.pi }) do
					local p = c.m["Pierna" .. lado]
					if p then
						p.Transform = CFrame.Angles(math.rad((anda and (corre and 40 or 26) or 0) * math.sin(f + off)), 0, 0)
					end
				end
				-- Cangrejo
				for i = 1, 8 do
					local p = c.m["Pata" .. i]
					if p then
						p.Transform = anda and CFrame.Angles(0, math.rad(18 * math.sin(f * 2 + i)), math.rad(10 * math.cos(f * 2 + i))) or ID
					end
				end
				-- Cuello: baja la cabeza al pastar, cabecea al andar, mira alrededor parado
				local objetivo = (mov == "pastar") and -55 or (corre and -6 or ((mov == "atacar") and -20 or 0))
				if especie == "Pavo" or especie == "Pato" then
					objetivo = (mov == "pastar") and -40 or 0
				end
				c.cuello = c.cuello + (objetivo - c.cuello) * math.min(1, dt * 3)
				local cabeceo = anda and math.sin(f * 2) * ((especie == "Pavo") and 12 or 4) or 0
				local mirar = (mov == "quieto") and math.sin(t * 0.45 + c.semilla) * 28 or 0
				c.mira = c.mira + (mirar - c.mira) * math.min(1, dt * 2)
				if c.m.Cuello then
					c.m.Cuello.Transform = CFrame.Angles(math.rad(c.cuello + cabeceo), math.rad(c.mira), 0)
				end
				-- Cola: el ciervo la levanta al huir (la "bandera" blanca)
				local cola = (corre and especie == "Ciervo") and -60 or 0
				c.cola = c.cola + (cola - c.cola) * math.min(1, dt * 4)
				if c.m.Cola then
					c.m.Cola.Transform = CFrame.Angles(math.rad(c.cola), math.rad(12 * math.sin(t * 2.4 + c.semilla)), 0)
				end
			end
		end
	end
end

-- =====================================================================
--  Bucle de proyectiles
-- =====================================================================
function Efectos.actualizar(dt)
	for id, p in pairs(proyectiles) do
		p.t = p.t + dt
		if p.t > 15 or not p.visual.Parent then
			quitar(id)
			p.visual:Destroy()
		else
			local t = p.t
			local pos = p.desde + p.v * t + Vector3.new(0, 0.5 * p.g * t * t, 0)
			local vel = p.v + Vector3.new(0, p.g * t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			if p.tipo == "bala" then
				local largo = math.clamp(vel.Magnitude * dt * 0.8, 1, 12)
				p.visual.Size = Vector3.new(0.05, 0.05, largo)
				p.visual.CFrame = CFrame.lookAt(pos - dir * largo / 2, pos)
			elseif p.tipo == "proyectil" then
				p.visual:PivotTo(CFrame.lookAt(pos, pos + dir))
			else
				p.visual:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 4, 0))
			end
		end
	end
end

function Efectos.iniciar(config)
	Config = config
	M = Config.StudsPorMetro
	carpeta = Instance.new("Folder")
	carpeta.Name = "EfectosLocales"
	carpeta.Parent = workspace
	animales = workspace:WaitForChild("Animales", 30) or Instance.new("Folder")
	paramsAgua = RaycastParams.new()
	paramsAgua.FilterType = Enum.RaycastFilterType.Include
	paramsAgua.FilterDescendantsInstances = { workspace.Terrain }
	paramsAgua.IgnoreWater = false
end

return Efectos
]=]

local function crear(padre, clase, nombre, fuente)
	local viejo = padre:FindFirstChild(nombre)
	if viejo then viejo:Destroy() end
	local s = Instance.new(clase)
	s.Name = nombre
	s.Source = fuente
	s.Parent = padre
	return s
end
crear(ReplicatedStorage, "ModuleScript", "CazaConfig", CAZA_CONFIG)
local cazaServidor = crear(ServerScriptService, "Script", "CazaServidor", CAZA_SERVIDOR)
for nombre, fuente in pairs(CAZA_SERVIDOR_MODULOS) do
	crear(cazaServidor, "ModuleScript", nombre, fuente)
end
local jugadorScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts", StarterPlayer)
local cazaCliente = crear(jugadorScripts, "LocalScript", "CazaCliente", CAZA_CLIENTE)
for nombre, fuente in pairs(CAZA_CLIENTE_MODULOS) do
	crear(cazaCliente, "ModuleScript", nombre, fuente)
end
print("[Caza] Instalada la caza, la pesca y las armas. Pulsa Jugar para probarla.")
