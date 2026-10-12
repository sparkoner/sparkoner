local QBCore = exports['qb-core']:GetCoreObject()

-- Spawned[src] = true cuando el jugador ya ha aparecido en esta sesión:
-- impide usar el selector para teletransportarse una vez dentro del juego.
local Spawned = {}
local Testing = {}

local function BedSpawnPoint(bed)
    local cfg = BedTypes[bed.item]
    local offset = cfg and cfg.spawnOffset or vector3(1.2, 0.0, 0.0)
    local h = math.rad(bed.heading)
    local right = vector3(math.cos(h), math.sin(h), 0.0)
    local forward = vector3(-math.sin(h), math.cos(h), 0.0)
    return bed.coords + right * offset.x + forward * offset.y + vector3(0.0, 0.0, offset.z), bed.heading
end

local function LastPosition(Player)
    local pos = Player.PlayerData.position
    if type(pos) ~= 'table' and type(pos) ~= 'vector3' and type(pos) ~= 'vector4' then return nil end
    if not pos.x then return nil end
    return vector3(pos.x, pos.y, pos.z), (pos.w or pos.a or pos.h or 0.0) + 0.0
end

local function BuildOptions(Player)
    local options = {}
    for _, bed in ipairs(GetPlayerBeds(Player.PlayerData.citizenid)) do
        local cfg = BedTypes[bed.item]
        options[#options + 1] = {
            kind = 'bed', id = bed.id, label = bed.label, kindLabel = 'Tu cama',
            description = cfg.description, image = bed.item .. '.png', coords = bed.coords,
        }
    end
    if Config.Spawn.AllowLastLocation then
        local coords = LastPosition(Player)
        if coords then
            options[#options + 1] = {
                kind = 'last', id = 'last', label = 'Última ubicación', kindLabel = 'Donde lo dejaste',
                description = 'Apareces donde estabas al desconectarte.', image = 'ultima.png', coords = coords,
            }
        end
    end
    for _, spawn in ipairs(Config.Spawn.PublicSpawns) do
        options[#options + 1] = {
            kind = 'public', id = spawn.id, label = spawn.label, kindLabel = 'Zona pública',
            description = spawn.description or '', image = spawn.image or 'refugio.png',
            coords = vector3(spawn.coords.x, spawn.coords.y, spawn.coords.z),
        }
    end
    return options
end

local function CanSelect(src)
    return Config.Spawn.ReplaceQbSpawn and (not Spawned[src] or Testing[src])
end

QBCore.Functions.CreateCallback('apoc_camas:server:getSpawnOptions', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not CanSelect(source) then return cb({}) end
    cb(BuildOptions(Player))
end)

QBCore.Functions.CreateCallback('apoc_camas:server:requestSpawn', function(source, cb, kind, id)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not CanSelect(source) then return cb(nil) end

    local coords, heading
    if kind == 'bed' then
        local bed = Beds[tonumber(id)]
        if not bed or bed.citizenid ~= Player.PlayerData.citizenid then return cb(nil) end
        coords, heading = BedSpawnPoint(bed)
    elseif kind == 'last' and Config.Spawn.AllowLastLocation then
        coords, heading = LastPosition(Player)
    elseif kind == 'public' then
        for _, spawn in ipairs(Config.Spawn.PublicSpawns) do
            if spawn.id == id then
                coords, heading = vector3(spawn.coords.x, spawn.coords.y, spawn.coords.z), (spawn.coords.w or 0.0) + 0.0
            end
        end
    end
    if not coords then return cb(nil) end

    local test = Testing[source] == true
    Spawned[source] = true
    Testing[source] = nil
    cb({ coords = coords, heading = heading or 0.0, test = test })
end)

-- Al volver a la selección de personaje se puede elegir de nuevo
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    Spawned[src] = nil
    Testing[src] = nil
end)

AddEventHandler('playerDropped', function()
    Spawned[source] = nil
    Testing[source] = nil
end)

-- Si el recurso se reinicia, quien ya está jugando cuenta como aparecido
CreateThread(function()
    for src in pairs(QBCore.Functions.GetQBPlayers()) do Spawned[src] = true end
    if Config.Spawn.ReplaceQbSpawn and GetResourceState('qb-spawn') == 'started' then
        print('^3[apoc_camas] qb-spawn está activo: quítalo del server.cfg o pon Config.Spawn.ReplaceQbSpawn = false para evitar dos selectores.^0')
    end
end)

QBCore.Commands.Add('probarspawn', 'Abre el selector de aparición para probarlo', {}, false, function(source)
    Testing[source] = true
    TriggerClientEvent('apoc_camas:client:openSelector', source, true)
end, 'admin')

QBCore.Commands.Add('vercamas', 'Muestra los 10 modelos de cama delante de ti durante 60 segundos', {}, false, function(source)
    TriggerClientEvent('apoc_camas:client:showroom', source)
end, 'admin')
