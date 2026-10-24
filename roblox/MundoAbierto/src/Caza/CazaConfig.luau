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
