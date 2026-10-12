Config = {}

-- =====================================================================
--  GENERAL
-- =====================================================================
Config.MaxBeds = 3               -- camas colocadas a la vez por personaje
Config.RenderDistance = 120.0    -- distancia a la que se ven las camas
Config.PlaceTime = 5000          -- ms que se tarda en colocar una cama
Config.PickupTime = 4000         -- ms que se tarda en recogerla
Config.AllowDestroy = false      -- true = otros jugadores pueden destruir camas ajenas
Config.DestroyTime = 20000       -- ms que se tarda en destruir una cama ajena
Config.AutoRegisterItems = true  -- registra los objetos de las camas en qb-core si no existen

-- =====================================================================
--  COLOCACIÓN
-- =====================================================================
Config.Placement = {
    MaxDistance = 6.0,              -- distancia máxima desde el jugador
    MinDistanceBetweenBeds = 2.5,   -- separación mínima entre camas
    MinFlatness = 0.85,             -- 1.0 = suelo totalmente plano; más bajo permite cuestas
    RotateStep = 5.0,               -- grados por giro de la rueda del ratón
    BlockedZones = {                -- zonas donde no se pueden poner camas
        -- { coords = vector3(1853.53, 3686.69, 34.27), radius = 30.0, label = 'el refugio' },
    },
}

-- =====================================================================
--  SELECTOR DE APARICIÓN (sustituye a qb-spawn)
-- =====================================================================
Config.Spawn = {
    ReplaceQbSpawn = true,     -- muestra este selector al elegir personaje (desactiva qb-spawn)
    AllowLastLocation = true,  -- permite aparecer donde se desconectó
    PublicSpawns = {           -- puntos disponibles para todos
        {
            id = 'refugio',
            label = 'Refugio de Sandy Shores',
            description = 'La zona segura de los supervivientes.',
            image = 'refugio.png',
            coords = vector4(1853.53, 3686.69, 34.27, 210.0),
        },
    },
    Camera = {
        distance = 5.5,        -- distancia de la cámara a la cama
        height = 2.8,          -- altura de la cámara
        orbitSpeed = 0.12,     -- grados por fotograma que gira alrededor de la cama
    },
}

-- =====================================================================
--  FABRICACIÓN (banco de trabajo)
-- =====================================================================
Config.Crafting = {
    enabled = true,            -- false si usas tu propio sistema de crafteo
    label = 'Banco de trabajo',
    coords = vector4(1849.6, 3689.8, 34.27, 30.0),
    prop = 'prop_tool_bench02',
    duration = 10000,
    blip = { sprite = 446, color = 47, scale = 0.7, label = 'Banco de trabajo' },
}

-- =====================================================================
--  CAMAS
-- =====================================================================
-- item:        nombre del objeto en el inventario (y de su imagen .png)
-- model:       prop de GTA que se coloca en el mundo
-- recipe:      materiales para fabricarla en el banco de trabajo
-- spawnOffset: dónde aparece el jugador respecto a la cama (x = derecha, y = delante)
Config.Beds = {
    {
        item = 'cama_saco',
        label = 'Saco de dormir',
        model = 'prop_skid_sleepbag_1',
        weight = 2000,
        description = 'Ligero y fácil de esconder. Duerme donde sea.',
        recipe = { { 'plastic', 10 }, { 'rubber', 5 } },
    },
    {
        item = 'cama_colchon_sucio',
        label = 'Colchón de cartones',
        model = 'prop_homeless_matress_01',
        weight = 3000,
        description = 'Un colchón viejo sobre cartones. Barato, pero cumple.',
        recipe = { { 'plastic', 8 }, { 'metalscrap', 5 } },
    },
    {
        item = 'cama_colchon',
        label = 'Colchón viejo',
        model = 'prop_rub_matress_01',
        weight = 4000,
        description = 'Manchado y con muelles, pero mejor que el suelo.',
        recipe = { { 'plastic', 12 }, { 'steel', 4 }, { 'rubber', 4 } },
    },
    {
        item = 'cama_colchon_hospital',
        label = 'Colchón de hospital',
        model = 'v_med_mattress',
        weight = 4000,
        description = 'Rescatado de un hospital abandonado.',
        recipe = { { 'plastic', 15 }, { 'rubber', 8 }, { 'steel', 3 } },
    },
    {
        item = 'cama_tumbona',
        label = 'Tumbona',
        model = 'prop_patio_lounger1',
        weight = 4000,
        description = 'Una tumbona de jardín. Dormir al aire libre con estilo.',
        recipe = { { 'aluminum', 12 }, { 'plastic', 10 } },
    },
    {
        item = 'cama_catre_militar',
        label = 'Catre militar',
        model = 'gr_prop_gr_campbed_01',
        weight = 5000,
        description = 'Catre plegable del ejército. Resistente y aislado del suelo.',
        recipe = { { 'steel', 8 }, { 'plastic', 10 }, { 'aluminum', 5 } },
    },
    {
        item = 'cama_catre_motero',
        label = 'Catre de motero',
        model = 'bkr_prop_biker_campbed_01',
        weight = 5000,
        description = 'Sacado de un club de moteros. Huele a gasolina.',
        recipe = { { 'steel', 8 }, { 'rubber', 10 }, { 'iron', 5 } },
    },
    {
        item = 'cama_catre_taller',
        label = 'Catre de taller',
        model = 'imp_prop_impexp_campbed_01',
        weight = 5000,
        description = 'El catre de un mecánico. Para dormir junto al trabajo.',
        recipe = { { 'aluminum', 10 }, { 'plastic', 10 }, { 'iron', 5 } },
    },
    {
        item = 'cama_tienda',
        label = 'Tienda improvisada',
        model = 'prop_skid_tent_01',
        weight = 6000,
        description = 'Lona, palos y un saco dentro. Te resguarda de la lluvia.',
        recipe = { { 'plastic', 20 }, { 'metalscrap', 10 }, { 'rubber', 5 } },
        spawnOffset = vector3(2.0, 0.0, 0.0),
    },
    {
        item = 'cama_camilla',
        label = 'Camilla de hospital',
        model = 'v_med_emptybed',
        weight = 8000,
        description = 'Una cama de hospital con ruedas. El lujo del apocalipsis.',
        recipe = { { 'steel', 15 }, { 'aluminum', 8 }, { 'rubber', 6 }, { 'plastic', 10 } },
        spawnOffset = vector3(1.5, 0.0, 0.0),
    },
}
