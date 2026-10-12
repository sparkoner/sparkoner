Config = {}

-- =====================================================================
--  GENERAL
-- =====================================================================
Config.MoneyType = 'cash'        -- 'cash' o 'bank'
Config.InteractKey = 38          -- tecla de interacción (38 = E)
Config.SpawnDistance = 150.0     -- un participante debe estar a esta distancia de la zona para que aparezcan enemigos y objetos
Config.MaxSpawnBatch = 6         -- enemigos máximos que aparecen de golpe en cada tanda
Config.FailCooldown = 5 * 60     -- espera (segundos) tras fallar o abandonar una misión
Config.EnemyBlips = true         -- muestra a los enemigos de la misión en el minimapa
Config.Hud = { x = 0.985, y = 0.32 } -- posición del texto de objetivo (esquina derecha)

-- =====================================================================
--  REFUGIO (NPC que da las misiones y punto de entrega)
-- =====================================================================
Config.Refuge = {
    label = 'Refugio de Sandy Shores',
    coords = vector4(1853.53, 3686.69, 34.27, 210.0),
    pedModel = 's_m_m_marine_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    deliveryRadius = 25.0,       -- radio para entregar vehículos, supervivientes o volver al refugio
    blip = { sprite = 40, color = 2, scale = 0.85, label = 'Refugio - Misiones' },
}

-- =====================================================================
--  GRUPOS
-- =====================================================================
Config.Group = {
    MaxMembers = 4,              -- máximo de jugadores por grupo
    StartRadius = 30.0,          -- los miembros deben estar a esta distancia del líder al iniciar la misión
    RewardRadius = 250.0,        -- distancia máxima al punto final para cobrar la recompensa (nil = sin límite)
    RequireVisit = true,         -- solo cobra quien haya ido a la zona de la misión (evita que se cobre estando AFK)
    BonusPerMember = 0.10,       -- +10% de dinero para cada participante por cada miembro extra
    InviteTimeout = 60,          -- segundos que dura una invitación
}

-- =====================================================================
--  REPUTACIÓN (se guarda en los metadatos del personaje)
-- =====================================================================
Config.Reputation = {
    enabled = true,
    metadata = 'apoc_reputacion',
}

-- =====================================================================
--  ENEMIGOS
-- =====================================================================
Config.Enemies = {
    infected = {
        relationship = 'APOC_INFECTED',
        style = 'infected',      -- cuerpo a cuerpo, caminar errático, aspecto ensangrentado
        health = 250,
        armour = 0,
        accuracy = 0,
        sight = 80.0,
        models = {
            'u_m_y_zombie_01', 'a_m_m_tramp_01', 'a_m_o_tramp_01', 'a_f_m_tramp_01',
            'a_m_m_trampbeac_01', 'a_f_m_trampbeac_01', 'a_m_y_methhead_01',
            'a_m_m_hillbilly_02', 's_m_m_paramedic_01', 'a_m_m_salton_02',
        },
        walkStyles = { 'move_m@drunk@verydrunk', 'move_m@drunk@moderatedrunk', 'move_m@injured' },
    },
    raiders = {
        relationship = 'APOC_RAIDERS',
        style = 'armed',
        health = 200,
        armour = 25,
        accuracy = 25,
        sight = 100.0,
        dropWeapons = false,     -- true = sueltan el arma al morir
        models = { 'g_m_y_lost_01', 'g_m_y_lost_02', 'g_m_y_lost_03', 'g_f_y_lost_01', 'a_m_m_hillbilly_01' },
        weapons = { 'WEAPON_PISTOL', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_MICROSMG' },
        vehicles = { 'rebel', 'bfinjection', 'sandking2' },
    },
    -- Jefe: infectado gigante muy resistente (no muere de un tiro en la cabeza)
    mutant = {
        relationship = 'APOC_INFECTED',
        style = 'infected',
        health = 3000,
        armour = 100,
        accuracy = 0,
        sight = 120.0,
        criticalHits = false,
        models = { 'u_m_y_juggernaut_01' },
        fallbackModels = { 'u_m_y_zombie_01' }, -- por si tu versión del juego no tiene el modelo anterior
    },
}

Config.Survivors = {
    relationship = 'APOC_SURVIVOR',
    health = 200,
    scenario = 'CODE_HUMAN_COWER',
    models = {
        'a_m_m_farmer_01', 'a_f_y_hippie_01', 'a_m_y_hippy_01', 'a_f_m_fatwhite_01',
        'a_m_o_genstreet_01', 'a_f_m_salton_01', 'a_m_m_salton_01',
    },
}

-- =====================================================================
--  INTEGRACIONES (llaves y combustible) - adáptalas a tus scripts
-- =====================================================================
Config.GiveKeys = function(plate, vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', plate) -- qb-vehiclekeys
end

Config.SetFuel = function(vehicle, amount)
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, amount)
    elseif GetResourceState('cdn-fuel') == 'started' then
        exports['cdn-fuel']:SetFuel(vehicle, amount)
    elseif GetResourceState('ps-fuel') == 'started' then
        exports['ps-fuel']:SetFuel(vehicle, amount)
    elseif GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state.fuel = amount
    else
        SetVehicleFuelLevel(vehicle, amount + 0.0)
    end
end

-- =====================================================================
--  MISIONES
-- =====================================================================
-- Cada misión es una lista de etapas ("stages"). Tipos de etapa disponibles:
--   search   -> registrar N cajas en la zona
--   return   -> volver al refugio
--   vehicle  -> recoger un vehículo en la zona
--   deliver  -> llevar el vehículo de la misión al refugio
--   kill     -> eliminar N enemigos
--   interact -> acción con barra de progreso en un punto (reparar, quemar...)
--   escort   -> rescatar supervivientes y llevarlos al refugio
--   defend   -> resistir oleadas en la zona durante X segundos
--
-- Los valores { base = X, perMember = Y } escalan con el tamaño del grupo.
-- Modos de enemigos: 'guards' (vigilan la zona), 'objective' (hay que matarlos),
-- 'waves' (oleadas durante 'defend') y 'ambush' (emboscada durante 'deliver').
--
-- Las coordenadas son de ejemplo: revísalas en tu mapa.

Config.Missions = {
    -- 1. SUMINISTROS MÉDICOS ------------------------------------------
    {
        id = 'suministros_medicos',
        label = 'Suministros Médicos',
        description = 'El refugio se ha quedado sin medicinas. Saquea un hospital infestado y vuelve con todo lo que encuentres.',
        icon = 'fas fa-briefcase-medical',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 20 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Centro Médico de Paleto Bay', coords = vector3(-254.88, 6324.50, 32.58), radius = 40.0 },
            { label = 'Hospital Pillbox Hill', coords = vector3(298.60, -584.50, 43.26), radius = 45.0 },
            { label = 'Hospital Mount Zonah', coords = vector3(-449.67, -340.83, 34.50), radius = 45.0 },
        },
        stages = {
            {
                type = 'search',
                label = 'Registra las cajas de suministros del hospital',
                progressLabel = 'Cajas registradas',
                interactLabel = 'Registrar caja',
                count = { base = 4, perMember = 2 },
                prop = 'prop_cs_cardbox_01',
                duration = 7000,
                anim = { scenario = 'PROP_HUMAN_BUM_BIN' },
                enemies = { mode = 'guards', pool = 'infected', count = { base = 6, perMember = 3 }, maxAlive = { base = 8, perMember = 2 }, minDist = 10.0, maxDist = 40.0 },
            },
            { type = 'return', label = 'Vuelve al refugio con los suministros' },
        },
        rewards = {
            cash = { min = 800, max = 1200 },
            reputation = 10,
            items = {
                { name = 'bandage', min = 3, max = 6 },
                { name = 'painkillers', min = 1, max = 3, chance = 70 },
                { name = 'firstaid', min = 1, max = 2, chance = 40 },
                { name = 'ifaks', min = 1, max = 1, chance = 25 },
            },
        },
    },

    -- 2. COMBUSTIBLE PARA EL GENERADOR --------------------------------
    {
        id = 'combustible',
        label = 'Combustible para el Generador',
        description = 'Recupera un camión cargado de bidones y tráelo al refugio. Cuidado: los saqueadores vigilan las carreteras.',
        icon = 'fas fa-gas-pump',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 25 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Gasolinera de Grapeseed', coords = vector3(1687.16, 4929.39, 42.08), radius = 40.0 },
            { label = 'Gasolinera de Harmony', coords = vector3(1207.26, 2660.18, 37.90), radius = 40.0 },
            { label = 'Gasolinera de Paleto Bay', coords = vector3(-94.46, 6419.59, 31.49), radius = 40.0 },
        },
        stages = {
            {
                type = 'vehicle',
                label = 'Recupera el camión de combustible',
                model = 'mule',
                enemies = { mode = 'guards', pool = 'infected', count = { base = 4, perMember = 2 }, maxAlive = { base = 6, perMember = 2 }, minDist = 15.0, maxDist = 40.0 },
            },
            {
                type = 'deliver',
                label = 'Lleva el camión al refugio sin que lo destruyan',
                enemies = { mode = 'ambush', pool = 'raiders', vehicles = { base = 1, perMember = 0.5 }, perVehicle = 3, triggerDistance = 400.0 },
            },
        },
        rewards = {
            cash = { min = 1200, max = 1800 },
            reputation = 15,
            items = {
                { name = 'jerry_can', min = 1, max = 1, chance = 50 },
                { name = 'repairkit', min = 1, max = 1, chance = 60 },
                { name = 'metalscrap', min = 5, max = 10 },
            },
        },
    },

    -- 3. PURGAR EL NIDO -----------------------------------------------
    {
        id = 'nido_infectado',
        label = 'Purgar el Nido',
        description = 'Hay un nido de infectados creciendo cerca de una zona habitada. Acaba con ellos y quema el nido antes de que se extienda.',
        icon = 'fas fa-biohazard',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 20 * 60,
        timeLimit = 20 * 60,
        locations = {
            { label = 'Stab City', coords = vector3(60.0, 3705.0, 39.75), radius = 50.0 },
            { label = 'Cantera Davis Quartz', coords = vector3(2950.0, 2790.0, 41.0), radius = 55.0 },
            { label = 'Aserradero de Paleto', coords = vector3(-570.0, 5325.0, 70.2), radius = 50.0 },
        },
        stages = {
            {
                type = 'kill',
                label = 'Elimina a los infectados del nido',
                progressLabel = 'Infectados eliminados',
                enemies = { mode = 'objective', pool = 'infected', count = { base = 12, perMember = 6 }, maxAlive = { base = 6, perMember = 2 }, minDist = 10.0, maxDist = 45.0 },
            },
            {
                type = 'interact',
                label = 'Quema el nido',
                interactLabel = 'Quemar el nido',
                prop = 'prop_rub_binbag_01',
                duration = 8000,
                anim = { dict = 'weapon@w_sp_jerrycan', name = 'fire', flags = 1 },
                effect = 'fire',
            },
        },
        rewards = {
            cash = { min = 1000, max = 1500 },
            reputation = 15,
            items = {
                { name = 'pistol_ammo', min = 1, max = 2 },
                { name = 'metalscrap', min = 3, max = 8 },
                { name = 'plastic', min = 3, max = 8, chance = 60 },
            },
        },
    },

    -- 4. RESCATE DE SUPERVIVIENTES ------------------------------------
    {
        id = 'rescate',
        label = 'Rescate de Supervivientes',
        description = 'Un grupo de civiles está atrapado entre infectados. Llega hasta ellos y escóltalos con vida al refugio. Lleva un vehículo con plazas.',
        icon = 'fas fa-users',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 10,
        cooldown = 25 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = "Rancho O'Neil", coords = vector3(2441.0, 4975.0, 46.8), radius = 45.0 },
            { label = 'Aeródromo de Grapeseed', coords = vector3(2133.0, 4783.0, 40.97), radius = 45.0 },
            { label = 'Centro de Paleto Bay', coords = vector3(-111.6, 6464.0, 31.6), radius = 45.0 },
        },
        stages = {
            {
                type = 'escort',
                label = 'Rescata a los supervivientes y llévalos al refugio',
                count = { base = 2, perMember = 1 },
                minRescuedRatio = 0.5,   -- si muere más de la mitad, la misión falla
                enemies = { mode = 'guards', pool = 'infected', count = { base = 6, perMember = 3 }, maxAlive = { base = 8, perMember = 2 }, minDist = 15.0, maxDist = 45.0 },
            },
        },
        rewards = {
            cash = { min = 1500, max = 2200 },  -- se reduce en proporción a los supervivientes perdidos
            reputation = 20,
            items = {
                { name = 'sandwich', min = 2, max = 4 },
                { name = 'water_bottle', min = 2, max = 4 },
                { name = 'armor', min = 1, max = 1, chance = 30 },
            },
        },
    },

    -- 5. SEÑAL DE SOCORRO ---------------------------------------------
    {
        id = 'antena',
        label = 'Señal de Socorro',
        description = 'Repara el generador de una antena de radio y defiéndela mientras emite. El ruido atraerá a toda la horda.',
        icon = 'fas fa-broadcast-tower',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 25,
        cooldown = 30 * 60,
        timeLimit = 30 * 60,
        locations = {
            { label = 'Cima del Monte Chiliad', coords = vector3(501.8, 5604.8, 797.9), radius = 60.0 },
            { label = 'Antenas de Vinewood Hills', coords = vector3(750.0, 1290.0, 360.3), radius = 60.0 },
        },
        stages = {
            {
                type = 'interact',
                label = 'Repara el generador de la antena',
                interactLabel = 'Reparar generador',
                prop = 'prop_generator_01a',
                duration = 15000,
                anim = { dict = 'mini@repair', name = 'fixing_a_ped', flags = 1 },
                requiredItem = nil,      -- p. ej. 'electronickit' para exigir un objeto
                consumeItem = false,
                enemies = { mode = 'guards', pool = 'infected', count = { base = 4, perMember = 2 }, maxAlive = { base = 4, perMember = 2 }, minDist = 20.0, maxDist = 45.0 },
            },
            {
                type = 'defend',
                label = 'Defiende la antena mientras transmite',
                duration = 180,          -- segundos que hay que resistir
                prepTime = 0,            -- segundos de preparación antes de la primera oleada
                radius = 60.0,
                leaveGrace = 30,         -- segundos fuera de la zona antes de fallar
                timerLabel = 'Transmisión',
                progressText = 'Resiste hasta que termine la transmisión',
                startMessage = 'La transmisión ha empezado. ¡Se acerca la horda!',
                failMessage = 'Abandonasteis la zona y la transmisión se cortó.',
                enemies = { mode = 'waves', pool = 'infected', perWave = { base = 4, perMember = 2 }, interval = 25, maxAlive = { base = 10, perMember = 3 }, minDist = 35.0, maxDist = 60.0 },
            },
        },
        rewards = {
            cash = { min = 2000, max = 3000 },
            reputation = 25,
            items = {
                { name = 'radio', min = 1, max = 1, chance = 50 },
                { name = 'electronickit', min = 1, max = 1, chance = 40 },
                { name = 'rifle_ammo', min = 1, max = 2, chance = 30 },
                { name = 'heavyarmor', min = 1, max = 1, chance = 20 },
            },
        },
    },

    -- 6. DESPENSA VACÍA -----------------------------------------------
    {
        id = 'despensa',
        label = 'Despensa Vacía',
        description = 'Las reservas de comida se agotan. Saquea una tienda abandonada antes de que los infectados te rodeen.',
        icon = 'fas fa-shopping-basket',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 15 * 60,
        timeLimit = 20 * 60,
        locations = {
            { label = '24/7 de Grapeseed', coords = vector3(1697.99, 4924.40, 42.06), radius = 35.0 },
            { label = '24/7 de la Ruta 68', coords = vector3(547.79, 2671.79, 42.15), radius = 35.0 },
            { label = '24/7 de la autopista Senora', coords = vector3(2678.90, 3280.67, 55.24), radius = 35.0 },
        },
        stages = {
            {
                type = 'search',
                label = 'Busca comida en la tienda',
                progressLabel = 'Estanterías registradas',
                interactLabel = 'Buscar comida',
                count = { base = 5, perMember = 2 },
                prop = 'prop_cs_cardbox_01',
                duration = 6000,
                anim = { scenario = 'PROP_HUMAN_BUM_BIN' },
                enemies = { mode = 'guards', pool = 'infected', count = { base = 5, perMember = 2 }, maxAlive = { base = 6, perMember = 2 }, minDist = 10.0, maxDist = 35.0 },
            },
            { type = 'return', label = 'Vuelve al refugio con la comida' },
        },
        rewards = {
            cash = { min = 600, max = 900 },
            reputation = 8,
            items = {
                { name = 'sandwich', min = 3, max = 6 },
                { name = 'water_bottle', min = 3, max = 6 },
                { name = 'tosti', min = 1, max = 3, chance = 60 },
                { name = 'kurkakola', min = 1, max = 3, chance = 60 },
            },
        },
    },

    -- 7. AGUA POTABLE -------------------------------------------------
    {
        id = 'agua',
        label = 'Agua Potable',
        description = 'Repara una bomba de agua en la costa, llena los bidones y tráelos al refugio.',
        icon = 'fas fa-tint',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 20 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Muelle de Paleto Bay', coords = vector3(-275.0, 6635.0, 7.5), radius = 30.0 },
            { label = 'Muelle de Chumash', coords = vector3(-3426.0, 967.0, 8.35), radius = 30.0 },
            { label = 'Muelle de Del Perro', coords = vector3(-1850.0, -1249.0, 8.6), radius = 30.0 },
        },
        stages = {
            {
                type = 'interact',
                label = 'Repara la bomba de agua',
                interactLabel = 'Reparar bomba',
                prop = 'prop_generator_01a',
                duration = 10000,
                anim = { dict = 'mini@repair', name = 'fixing_a_ped', flags = 1 },
                enemies = { mode = 'guards', pool = 'infected', count = { base = 4, perMember = 2 }, maxAlive = { base = 4, perMember = 2 }, minDist = 15.0, maxDist = 35.0 },
            },
            {
                type = 'search',
                label = 'Llena los bidones de agua',
                progressLabel = 'Bidones llenos',
                interactLabel = 'Llenar bidón',
                count = { base = 3, perMember = 1 },
                prop = 'prop_barrel_02a',
                duration = 6000,
                anim = { scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
                enemies = { mode = 'guards', pool = 'infected', count = { base = 3, perMember = 2 }, maxAlive = { base = 4, perMember = 2 }, minDist = 20.0, maxDist = 40.0 },
            },
            { type = 'return', label = 'Lleva el agua al refugio' },
        },
        rewards = {
            cash = { min = 900, max = 1300 },
            reputation = 10,
            items = {
                { name = 'water_bottle', min = 6, max = 10 },
            },
        },
    },

    -- 8. CHATARRERÍA --------------------------------------------------
    {
        id = 'chatarra',
        label = 'Chatarrería',
        description = 'El refugio necesita materiales para reforzar las barricadas. Rebusca en un desguace infestado.',
        icon = 'fas fa-tools',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 0,
        cooldown = 15 * 60,
        timeLimit = 20 * 60,
        locations = {
            { label = 'Desguace de La Puerta', coords = vector3(-428.54, -1728.29, 19.78), radius = 45.0 },
            { label = 'Planta de reciclaje de Paleto', coords = vector3(55.57, 6472.12, 31.43), radius = 40.0 },
            { label = 'YouTool de la autopista Senora', coords = vector3(2748.0, 3473.0, 55.67), radius = 40.0 },
        },
        stages = {
            {
                type = 'search',
                label = 'Rebusca materiales en el desguace',
                progressLabel = 'Montones registrados',
                interactLabel = 'Rebuscar chatarra',
                count = { base = 5, perMember = 2 },
                prop = 'prop_toolchest_01',
                duration = 7000,
                anim = { dict = 'mini@repair', name = 'fixing_a_ped', flags = 1 },
                enemies = { mode = 'guards', pool = 'infected', count = { base = 6, perMember = 3 }, maxAlive = { base = 6, perMember = 2 }, minDist = 10.0, maxDist = 45.0 },
            },
            { type = 'return', label = 'Vuelve al refugio con los materiales' },
        },
        rewards = {
            cash = { min = 700, max = 1000 },
            reputation = 10,
            items = {
                { name = 'metalscrap', min = 8, max = 15 },
                { name = 'steel', min = 3, max = 6 },
                { name = 'iron', min = 3, max = 6, chance = 70 },
                { name = 'aluminum', min = 3, max = 6, chance = 70 },
                { name = 'copper', min = 2, max = 5, chance = 50 },
                { name = 'rubber', min = 2, max = 5, chance = 50 },
                { name = 'glass', min = 2, max = 5, chance = 50 },
            },
        },
    },

    -- 9. AMBULANCIA DE CAMPAÑA ----------------------------------------
    {
        id = 'ambulancia',
        label = 'Ambulancia de Campaña',
        description = 'Una ambulancia cargada de material médico quedó abandonada en la carretera. Recupérala; los saqueadores también la quieren.',
        icon = 'fas fa-ambulance',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 10,
        cooldown = 25 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Ruta 68 (oeste)', coords = vector3(49.42, 2778.79, 58.04), radius = 40.0 },
            { label = 'Ruta 68 (este)', coords = vector3(2539.69, 2594.19, 37.94), radius = 40.0 },
            { label = 'Great Ocean Highway', coords = vector3(-2554.99, 2334.40, 33.08), radius = 40.0 },
        },
        stages = {
            {
                type = 'vehicle',
                label = 'Recupera la ambulancia',
                model = 'ambulance',
                enemies = { mode = 'guards', pool = 'infected', count = { base = 5, perMember = 2 }, maxAlive = { base = 6, perMember = 2 }, minDist = 15.0, maxDist = 40.0 },
            },
            {
                type = 'deliver',
                label = 'Lleva la ambulancia al refugio',
                enemies = { mode = 'ambush', pool = 'raiders', vehicles = { base = 1, perMember = 0.5 }, perVehicle = 3, triggerDistance = 500.0 },
            },
        },
        rewards = {
            cash = { min = 1300, max = 1900 },
            reputation = 15,
            items = {
                { name = 'bandage', min = 4, max = 8 },
                { name = 'firstaid', min = 1, max = 3 },
                { name = 'ifaks', min = 1, max = 2, chance = 50 },
            },
        },
    },

    -- 10. SAQUEO DE LA ARMERÍA ----------------------------------------
    {
        id = 'armeria',
        label = 'Saqueo de la Armería',
        description = 'Una banda de saqueadores está vaciando una Ammu-Nation. Llévate la munición antes que ellos.',
        icon = 'fas fa-crosshairs',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 15,
        cooldown = 25 * 60,
        timeLimit = 20 * 60,
        locations = {
            { label = 'Ammu-Nation de Paleto Bay', coords = vector3(-330.24, 6083.88, 31.45), radius = 35.0 },
            { label = 'Ammu-Nation de la Ruta 68', coords = vector3(-1117.58, 2698.61, 18.55), radius = 35.0 },
            { label = 'Ammu-Nation de Chumash', coords = vector3(-3171.98, 1087.32, 20.84), radius = 35.0 },
        },
        stages = {
            {
                type = 'search',
                label = 'Saquea las cajas de munición',
                progressLabel = 'Cajas saqueadas',
                interactLabel = 'Saquear caja',
                count = { base = 4, perMember = 2 },
                prop = 'prop_mil_crate_01',
                duration = 8000,
                anim = { scenario = 'PROP_HUMAN_BUM_BIN' },
                enemies = { mode = 'guards', pool = 'raiders', count = { base = 4, perMember = 2 }, maxAlive = { base = 4, perMember = 2 }, minDist = 10.0, maxDist = 35.0 },
            },
            { type = 'return', label = 'Vuelve al refugio con la munición' },
        },
        rewards = {
            cash = { min = 1200, max = 1700 },
            reputation = 15,
            items = {
                { name = 'pistol_ammo', min = 2, max = 4 },
                { name = 'smg_ammo', min = 1, max = 2, chance = 60 },
                { name = 'shotgun_ammo', min = 1, max = 2, chance = 50 },
                { name = 'rifle_ammo', min = 1, max = 1, chance = 30 },
                { name = 'armor', min = 1, max = 1, chance = 40 },
            },
        },
    },

    -- 11. CAMPAMENTO DE SAQUEADORES -----------------------------------
    {
        id = 'campamento',
        label = 'Campamento de Saqueadores',
        description = 'Los saqueadores que atacan nuestras rutas tienen un campamento. Acaba con ellos y recupera lo que robaron.',
        icon = 'fas fa-campground',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 20,
        cooldown = 30 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Desguace de Joshua Road', coords = vector3(2397.42, 3089.44, 49.92), radius = 50.0 },
            { label = "Hookies", coords = vector3(-2192.0, 4290.0, 49.17), radius = 45.0 },
            { label = 'Bayview Lodge', coords = vector3(-697.0, 5802.0, 17.3), radius = 45.0 },
        },
        stages = {
            {
                type = 'kill',
                label = 'Elimina a los saqueadores del campamento',
                progressLabel = 'Saqueadores abatidos',
                enemies = { mode = 'objective', pool = 'raiders', count = { base = 8, perMember = 4 }, maxAlive = { base = 4, perMember = 2 }, minDist = 15.0, maxDist = 45.0 },
            },
            {
                type = 'search',
                label = 'Recupera el botín robado',
                progressLabel = 'Cajas recuperadas',
                interactLabel = 'Abrir caja',
                count = { base = 3, perMember = 1 },
                prop = 'prop_mil_crate_01',
                duration = 6000,
                anim = { scenario = 'PROP_HUMAN_BUM_BIN' },
            },
            { type = 'return', label = 'Vuelve al refugio con el botín' },
        },
        rewards = {
            cash = { min = 1800, max = 2600 },
            reputation = 20,
            items = {
                { name = 'pistol_ammo', min = 2, max = 3 },
                { name = 'lockpick', min = 1, max = 2, chance = 60 },
                { name = 'metalscrap', min = 5, max = 10 },
                { name = 'armor', min = 1, max = 1, chance = 30 },
            },
        },
    },

    -- 12. HELICÓPTERO DERRIBADO ---------------------------------------
    {
        id = 'helicoptero',
        label = 'Helicóptero Derribado',
        description = 'Un helicóptero militar se ha estrellado. Los saqueadores ya están allí: recupera la caja negra con las rutas de evacuación.',
        icon = 'fas fa-helicopter',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 25,
        cooldown = 30 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Club de golf de Los Santos', coords = vector3(-1330.0, 60.0, 53.5), radius = 50.0 },
            { label = 'Viñedos Marlowe', coords = vector3(-1888.0, 2050.0, 140.9), radius = 50.0 },
            { label = 'Aeropuerto de Los Santos', coords = vector3(-1336.0, -3044.0, 13.94), radius = 55.0 },
        },
        stages = {
            {
                type = 'kill',
                label = 'Elimina a los saqueadores del lugar del accidente',
                progressLabel = 'Saqueadores abatidos',
                enemies = { mode = 'objective', pool = 'raiders', count = { base = 6, perMember = 3 }, maxAlive = { base = 4, perMember = 2 }, minDist = 15.0, maxDist = 45.0 },
            },
            {
                type = 'interact',
                label = 'Recupera la caja negra del helicóptero',
                interactLabel = 'Recuperar caja negra',
                prop = 'prop_crashed_heli',
                interactDistance = 6.0,  -- el helicóptero es grande: se puede interactuar desde más lejos
                duration = 12000,
                anim = { dict = 'mini@repair', name = 'fixing_a_ped', flags = 1 },
            },
            { type = 'return', label = 'Lleva la caja negra al refugio' },
        },
        rewards = {
            cash = { min = 2000, max = 2800 },
            reputation = 20,
            items = {
                { name = 'electronickit', min = 1, max = 1, chance = 60 },
                { name = 'radio', min = 1, max = 1, chance = 50 },
                { name = 'heavyarmor', min = 1, max = 1, chance = 25 },
            },
        },
    },

    -- 13. ASEDIO AL REFUGIO -------------------------------------------
    {
        id = 'asedio',
        label = 'Asedio al Refugio',
        description = 'Una horda enorme se dirige hacia el refugio. Prepara las defensas y aguanta hasta que pase.',
        icon = 'fas fa-shield-alt',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 30,
        cooldown = 45 * 60,
        timeLimit = 15 * 60,
        locations = {
            -- Se defiende el propio refugio: si lo mueves, el asedio se mueve con él
            { label = Config.Refuge.label, coords = vector3(Config.Refuge.coords.x, Config.Refuge.coords.y, Config.Refuge.coords.z), radius = 50.0 },
        },
        stages = {
            {
                type = 'defend',
                label = 'Defiende el refugio de la horda',
                duration = 240,
                prepTime = 30,
                radius = 50.0,
                leaveGrace = 20,
                timerLabel = 'Asedio',
                progressText = 'Que no entre ni un infectado',
                startMessage = 'La horda viene hacia el refugio. ¡Tenéis 30 segundos para prepararos!',
                failMessage = 'Abandonasteis el refugio y la horda lo ha arrasado.',
                enemies = { mode = 'waves', pool = 'infected', perWave = { base = 5, perMember = 3 }, interval = 20, maxAlive = { base = 12, perMember = 4 }, minDist = 40.0, maxDist = 70.0 },
            },
        },
        rewards = {
            cash = { min = 2200, max = 3200 },
            reputation = 25,
            items = {
                { name = 'firstaid', min = 1, max = 2 },
                { name = 'armor', min = 1, max = 1, chance = 50 },
                { name = 'rifle_ammo', min = 1, max = 2, chance = 40 },
            },
        },
    },

    -- 14. EL DOCTOR ---------------------------------------------------
    {
        id = 'doctor',
        label = 'El Doctor',
        description = 'Una doctora que investiga una cura sigue con vida, atrapada entre infectados. Escóltala al refugio: si muere, todo está perdido.',
        icon = 'fas fa-user-md',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 35,
        cooldown = 40 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Laboratorios Humane', coords = vector3(3536.0, 3660.0, 28.1), radius = 50.0 },
            { label = 'Centro Kortz', coords = vector3(-2243.0, 264.0, 174.6), radius = 45.0 },
            { label = 'Universidad de San Andreas', coords = vector3(-1636.0, 181.0, 61.76), radius = 50.0 },
        },
        stages = {
            {
                type = 'escort',
                label = 'Encuentra a la doctora y escóltala al refugio',
                interactLabel = 'Hablar con la doctora',
                count = 1,
                models = { 's_f_y_scrubs_01' },
                minRescuedRatio = 1.0,
                failMessage = 'La doctora ha muerto. Sin ella no habrá cura.',
                enemies = { mode = 'guards', pool = 'infected', count = { base = 10, perMember = 4 }, maxAlive = { base = 8, perMember = 3 }, minDist = 15.0, maxDist = 45.0 },
            },
        },
        rewards = {
            cash = { min = 2500, max = 3500 },
            reputation = 30,
            items = {
                { name = 'ifaks', min = 2, max = 3 },
                { name = 'firstaid', min = 2, max = 3 },
                { name = 'painkillers', min = 2, max = 4 },
            },
        },
    },

    -- 15. EL COLOSO ---------------------------------------------------
    {
        id = 'coloso',
        label = 'El Coloso',
        description = 'Un infectado mutado y gigantesco lidera una horda. Abre paso entre sus crías y derríbalo. Recomendado ir en grupo.',
        icon = 'fas fa-skull',
        minPlayers = 1,
        maxPlayers = 4,
        minReputation = 50,
        cooldown = 60 * 60,
        timeLimit = 25 * 60,
        locations = {
            { label = 'Prisión de Bolingbroke', coords = vector3(1845.9, 2585.9, 45.67), radius = 55.0 },
            { label = 'Club de los Lost MC', coords = vector3(981.0, -103.0, 74.85), radius = 50.0 },
            { label = 'Puerto de Los Santos', coords = vector3(1010.0, -3100.0, 5.9), radius = 55.0 },
        },
        stages = {
            {
                type = 'kill',
                label = 'Abre paso entre la horda',
                progressLabel = 'Infectados eliminados',
                enemies = { mode = 'objective', pool = 'infected', count = { base = 15, perMember = 5 }, maxAlive = { base = 8, perMember = 3 }, minDist = 15.0, maxDist = 50.0 },
            },
            {
                type = 'kill',
                label = 'Derriba al Coloso',
                progressLabel = 'Colosos abatidos',
                enemies = { mode = 'objective', pool = 'mutant', count = { base = 1, perMember = 0.34 }, maxAlive = 2, minDist = 20.0, maxDist = 35.0 },
            },
        },
        rewards = {
            cash = { min = 3500, max = 5000 },
            reputation = 40,
            items = {
                { name = 'heavyarmor', min = 1, max = 1 },
                { name = 'rifle_ammo', min = 2, max = 3 },
                { name = 'smg_ammo', min = 2, max = 3, chance = 50 },
            },
        },
    },
}
