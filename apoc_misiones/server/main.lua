local QBCore = exports['qb-core']:GetCoreObject()

Missions = {}       -- [instanceId] = misión activa
PlayerMission = {}  -- [src] = instanceId
StageHandlers = {}  -- se rellena en server/stages.lua

RefugeCoords = vector3(Config.Refuge.coords.x, Config.Refuge.coords.y, Config.Refuge.coords.z)

local MissionDefs = {}
for _, def in ipairs(Config.Missions) do MissionDefs[def.id] = def end

local Cooldowns = {}       -- [citizenid][missionId] = os.time() en que termina la espera
local LocationsInUse = {}  -- ['missionId:indice'] = instanceId
local nextInstance, nextRequest = 0, 0

-- Modelos que el servidor puede borrar al limpiar (evita borrar entidades ajenas)
local DeletableModels = {}
for _, model in ipairs(Config.Survivors.models) do DeletableModels[GetHashKey(model)] = true end
for _, def in ipairs(Config.Missions) do
    for _, stage in ipairs(def.stages) do
        if stage.model then DeletableModels[GetHashKey(stage.model)] = true end
        for _, model in ipairs(stage.models or {}) do DeletableModels[GetHashKey(model)] = true end
    end
end

-- =====================================================================
--  Utilidades
-- =====================================================================
function Notify(src, msg, kind, length)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', length or 5000)
end

function NotifyMembers(m, msg, kind, length)
    for src in pairs(m.members) do Notify(src, msg, kind, length) end
end

function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function GetEntityFromNet(net)
    local ent = NetworkGetEntityFromNetworkId(net)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

function SendToMembers(m, event, ...)
    for src in pairs(m.members) do TriggerClientEvent(event, src, ...) end
end

function FindClosestMember(m, center, range)
    local best, bestDist
    for src in pairs(m.members) do
        local coords = GetPlayerCoords(src)
        if coords then
            local dist = Utils.Dist2D(coords, center)
            if dist <= range and (not bestDist or dist < bestDist) then best, bestDist = src, dist end
        end
    end
    return best, bestDist
end

function AnyMemberWithin(m, center, range)
    return FindClosestMember(m, center, range) ~= nil
end

function GetStageFor(src, instance, stageType)
    local id = PlayerMission[src]
    if not id or id ~= instance then return nil end
    local m = Missions[id]
    if not m or m.ended or not m.stage then return nil end
    if stageType and m.stage.type ~= stageType then return nil end
    return m, m.stage
end

-- Inventario: usa las funciones del jugador si existen (qb-core clásico, ox_inventory)
-- y si no, los exports de qb-inventory (versiones nuevas de QBCore).
function InvAddItem(Player, src, name, amount)
    if Player.Functions.AddItem then return Player.Functions.AddItem(name, amount) end
    local ok, result = pcall(function() return exports['qb-inventory']:AddItem(src, name, amount, false, false, 'apoc_misiones') end)
    return ok and result
end

function InvGetAmount(Player, src, name)
    local item
    if Player.Functions.GetItemByName then
        item = Player.Functions.GetItemByName(name)
    else
        local ok, result = pcall(function() return exports['qb-inventory']:GetItemByName(src, name) end)
        item = ok and result or nil
    end
    return item and (item.amount or item.count or 0) or 0
end

function InvRemoveItem(Player, src, name, amount)
    if Player.Functions.RemoveItem then return Player.Functions.RemoveItem(name, amount) end
    local ok, result = pcall(function() return exports['qb-inventory']:RemoveItem(src, name, amount, false, 'apoc_misiones') end)
    return ok and result
end

local function GetReputation(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    return Player.PlayerData.metadata[Config.Reputation.metadata] or 0
end

local function GetCooldown(src, missionId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    local list = Cooldowns[Player.PlayerData.citizenid]
    local endsAt = list and list[missionId]
    if not endsAt then return 0 end
    return math.max(0, endsAt - os.time())
end

local function SetCooldown(citizenid, missionId, seconds)
    if not citizenid or not seconds or seconds <= 0 then return end
    Cooldowns[citizenid] = Cooldowns[citizenid] or {}
    Cooldowns[citizenid][missionId] = os.time() + seconds
end

local function PickLocation(def)
    local free = {}
    for i in ipairs(def.locations) do
        if not LocationsInUse[def.id .. ':' .. i] then free[#free + 1] = i end
    end
    if #free == 0 then return nil end
    return free[math.random(#free)]
end

-- =====================================================================
--  Entidades de la misión
-- =====================================================================
-- Tipos: 'enemy' y 'survivor' (vigilados por los clientes), 'vehicle'
-- (vehículo de la misión) y 'aux' (vehículos de los saqueadores).
function RegisterEntity(m, net, kind, stageIndex)
    m.entities[net] = { kind = kind, alive = true, stage = stageIndex or m.stageIndex, at = os.time() }
end

function WatchEntities(m, list)
    if #list > 0 then UpdateStage(m, { watch = list }) end
end

function OnEntityGone(m, net, e, reason)
    if e.kind == 'enemy' then
        local st = m.stage
        if st and st.enemy and e.stage == m.stageIndex then
            local enemy = st.enemy
            enemy.alive = math.max(0, enemy.alive - 1)
            if reason == 'dead' then
                enemy.killed = enemy.killed + 1
            else
                enemy.spawned = math.max(0, enemy.spawned - 1) -- se volverá a generar
            end
        end
    elseif e.kind == 'vehicle' and not m.vehicleDelivered then
        return FailMission(m, 'Habéis perdido el vehículo de la misión.')
    end
    local st = m.stage
    local handler = st and StageHandlers[st.type]
    if handler and handler.onEntityGone then handler.onEntityGone(m, st, net, e, reason) end
end

local function CheckEntities(m)
    local now = os.time()
    for net, e in pairs(m.entities) do
        if e.alive and now - e.at > 5 then
            local ent = GetEntityFromNet(net)
            if not ent then
                e.alive = false
                OnEntityGone(m, net, e, 'lost')
                if m.ended then return end
            elseif not e.persistent and (e.kind == 'vehicle' or e.kind == 'survivor') then
                -- Que no desaparezcan aunque nadie esté cerca
                if SetEntityOrphanMode then SetEntityOrphanMode(ent, 2) end
                e.persistent = true
            end
        end
    end
end

-- =====================================================================
--  Peticiones de aparición (el servidor decide, un cliente cercano crea)
-- =====================================================================
function RequestSpawn(m, src, kind, payload, cb)
    nextRequest = nextRequest + 1
    m.pending[nextRequest] = { src = src, cb = cb, at = os.time() }
    TriggerClientEvent('apoc_misiones:client:spawn', src, m.id, nextRequest, kind, payload)
end

RegisterNetEvent('apoc_misiones:server:spawned', function(instance, reqId, results, extra)
    local src = source
    local m = Missions[instance]
    if not m or m.ended then
        if type(results) == 'table' then TriggerClientEvent('apoc_misiones:client:deleteEntities', src, results) end
        if type(extra) == 'table' and type(extra.vehicles) == 'table' then
            TriggerClientEvent('apoc_misiones:client:deleteEntities', src, extra.vehicles)
        end
        return
    end
    local req = m.pending[reqId]
    if not req or req.src ~= src then return end
    m.pending[reqId] = nil
    req.cb(type(results) == 'table' and results or {}, type(extra) == 'table' and extra or {})
end)

-- =====================================================================
--  Enemigos
-- =====================================================================
local function SetupEnemies(m, st)
    local cfg = st.def.enemies
    if not cfg then return end
    local mode = cfg.mode or 'guards'
    st.enemy = {
        mode = mode,
        pool = cfg.pool or 'infected',
        total = Utils.Scale(cfg.count, m.size),
        perWave = Utils.Scale(cfg.perWave, m.size),
        maxAlive = Utils.Scale(cfg.maxAlive or 10, m.size),
        minDist = cfg.minDist or 15.0,
        maxDist = cfg.maxDist or 45.0,
        interval = cfg.interval or 30,
        spawned = 0, killed = 0, alive = 0,
        active = (mode == 'guards' or mode == 'objective'),
        nextWave = 0,
    }
end

local function SpawnEnemyBatch(m, st, spawner, amount)
    local enemy = st.enemy
    local stageIndex = m.stageIndex
    enemy.requesting = true
    enemy.spawned = enemy.spawned + amount
    RequestSpawn(m, spawner, 'enemies', {
        pool = enemy.pool, count = amount, center = st.center,
        minDist = enemy.minDist, maxDist = enemy.maxDist,
    }, function(results)
        enemy.requesting = false
        if not results then
            enemy.spawned = enemy.spawned - amount
            return
        end
        local watch = {}
        for _, net in ipairs(results) do
            if type(net) == 'number' and #watch < amount then
                RegisterEntity(m, net, 'enemy', stageIndex)
                watch[#watch + 1] = { net = net, kind = 'enemy' }
            end
        end
        enemy.spawned = enemy.spawned - amount + #watch
        enemy.alive = enemy.alive + #watch
        WatchEntities(m, watch)
    end)
end

local function TickEnemies(m, st)
    local enemy = st.enemy
    if not enemy or not enemy.active or enemy.requesting then return end
    local room = enemy.maxAlive - enemy.alive
    if room <= 0 then return end

    if enemy.mode == 'guards' or enemy.mode == 'objective' then
        if enemy.spawned >= enemy.total then return end
        local spawner = FindClosestMember(m, st.center, Config.SpawnDistance)
        if not spawner then return end
        SpawnEnemyBatch(m, st, spawner, math.min(room, enemy.total - enemy.spawned, Config.MaxSpawnBatch))
    elseif enemy.mode == 'waves' then
        if os.time() < enemy.nextWave then return end
        local spawner = FindClosestMember(m, st.center, Config.SpawnDistance)
        if not spawner then return end
        enemy.nextWave = os.time() + enemy.interval
        SpawnEnemyBatch(m, st, spawner, math.min(room, enemy.perWave))
    end
end

-- =====================================================================
--  Etapas
-- =====================================================================
function UpdateStage(m, data)
    SendToMembers(m, 'apoc_misiones:client:stageUpdate', m.id, data)
end

function SetProgress(m, text)
    m.stage.progress = text
    UpdateStage(m, { progress = text })
end

local function BuildStagePayload(m)
    local st = m.stage
    return {
        instance = m.id,
        index = m.stageIndex,
        total = #m.def.stages,
        type = st.type,
        label = st.def.label,
        center = st.center,
        radius = st.radius,
        expiresIn = m.expiresAt - os.time(),
        progress = st.progress,
        client = st.client,
        vehicle = m.vehicle and { net = m.vehicle.net, plate = m.vehicle.plate } or nil,
    }
end

function StartStage(m, index)
    if m.ended then return end
    local sdef = m.def.stages[index]
    if not sdef then return CompleteMission(m) end
    m.stageIndex = index
    local st = {
        def = sdef,
        type = sdef.type,
        center = m.location.coords,
        radius = sdef.radius or m.location.radius or 40.0,
        client = {},
    }
    m.stage = st
    SetupEnemies(m, st)
    local handler = StageHandlers[st.type]
    if handler and handler.start then handler.start(m, st) end
    if m.ended or m.stage ~= st then return end
    SendToMembers(m, 'apoc_misiones:client:setStage', BuildStagePayload(m))
end

function AdvanceStage(m)
    if m.ended then return end
    if m.stageIndex >= #m.def.stages then return CompleteMission(m) end
    StartStage(m, m.stageIndex + 1)
end

-- =====================================================================
--  Fin de misión
-- =====================================================================
local function GiveRewards(m)
    local rewards = m.def.rewards or {}
    local endPoint = (m.stage and (m.stage.endPoint or m.stage.center)) or RefugeCoords
    local multiplier = 1.0 + (Config.Group.BonusPerMember or 0) * (m.size - 1)
    local scale = m.rewardScale or 1.0

    for src, info in pairs(m.members) do
        local Player = QBCore.Functions.GetPlayer(src)
        local coords = GetPlayerCoords(src)
        if Player and coords then
            if Config.Group.RequireVisit and not info.visited then
                Notify(src, 'No llegaste a ir a la zona de la misión: no recibes recompensa.', 'error', 8000)
            elseif Config.Group.RewardRadius and Utils.Dist2D(coords, endPoint) > Config.Group.RewardRadius then
                Notify(src, 'Estabas demasiado lejos al completar la misión: no recibes recompensa.', 'error', 8000)
            else
                local cash = 0
                if rewards.cash then
                    cash = math.floor(math.random(rewards.cash.min, rewards.cash.max) * multiplier * scale)
                    if cash > 0 then Player.Functions.AddMoney(Config.MoneyType, cash, 'apoc-mision-' .. m.def.id) end
                end
                for _, item in ipairs(rewards.items or {}) do
                    if not item.chance or math.random(100) <= item.chance then
                        local shared = QBCore.Shared.Items[item.name]
                        if shared then
                            local amount = math.random(item.min or 1, item.max or item.min or 1)
                            amount = math.max(1, math.floor(amount * scale + 0.5))
                            if InvAddItem(Player, src, item.name, amount) then
                                TriggerClientEvent('inventory:client:ItemBox', src, shared, 'add', amount)
                            else
                                Notify(src, ('No tienes espacio para: %s'):format(shared.label), 'error')
                            end
                        else
                            print(('[apoc_misiones] El objeto "%s" no existe en qb-core/shared/items.lua'):format(item.name))
                        end
                    end
                end
                if Config.Reputation.enabled and rewards.reputation then
                    local rep = math.max(1, math.floor(rewards.reputation * scale + 0.5))
                    Player.Functions.SetMetaData(Config.Reputation.metadata, GetReputation(src) + rep)
                end
                Notify(src, ('Misión completada: %s. Recompensa: $%d'):format(m.def.label, cash), 'success', 8000)
            end
        end
    end
end

function CleanupMission(m, deleteEverything)
    local release, delete = {}, {}
    for net, e in pairs(m.entities) do
        if not deleteEverything and (e.kind == 'enemy' or e.kind == 'aux') then
            release[#release + 1] = net
        else
            delete[#delete + 1] = { net = net, kind = e.kind }
        end
    end
    -- Los enemigos se "sueltan" para que el juego los limpie de forma natural
    if #release > 0 then TriggerClientEvent('apoc_misiones:client:releaseEntities', -1, release) end

    local function doDelete()
        for _, item in ipairs(delete) do
            local ent = GetEntityFromNet(item.net)
            if ent then
                local isPlayer = GetEntityType(ent) == 1 and IsPedAPlayer(ent)
                if not isPlayer and (deleteEverything or DeletableModels[GetEntityModel(ent)]) then
                    DeleteEntity(ent)
                end
            end
        end
    end
    if deleteEverything then doDelete() else SetTimeout(5000, doDelete) end
end

local function EndMission(m, success, reason)
    if m.ended then return end
    m.ended = true
    if success then GiveRewards(m) end
    local cooldown = success and (m.def.cooldown or 0) or Config.FailCooldown
    for src, info in pairs(m.members) do
        SetCooldown(info.cid, m.def.id, cooldown)
        PlayerMission[src] = nil
        TriggerClientEvent('apoc_misiones:client:missionEnded', src, m.id, success, reason)
    end
    CleanupMission(m)
    LocationsInUse[m.locationKey] = nil
    Missions[m.id] = nil
end

function CompleteMission(m) EndMission(m, true) end
function FailMission(m, reason) EndMission(m, false, reason) end

function RemoveFromMission(src, reason, silent)
    local id = PlayerMission[src]
    if not id then return end
    PlayerMission[src] = nil
    local m = Missions[id]
    if not m then return end
    local info = m.members[src]
    m.members[src] = nil
    if info then SetCooldown(info.cid, m.def.id, Config.FailCooldown) end
    if not silent then TriggerClientEvent('apoc_misiones:client:missionEnded', src, m.id, false, reason) end

    if next(m.members) == nil then
        return FailMission(m, 'Todos los participantes han abandonado.')
    end
    -- Los supervivientes que seguían a este jugador quedan libres
    local st = m.stage
    if st and st.survivors then
        for net, s in pairs(st.survivors) do
            if s.followBy == src then
                s.followBy = nil
                UpdateStage(m, { available = net })
            end
        end
    end
    NotifyMembers(m, ('%s ha abandonado la misión.'):format(info and info.name or 'Un participante'), 'error')
end

-- =====================================================================
--  Inicio de misión
-- =====================================================================
RegisterNetEvent('apoc_misiones:server:startMission', function(missionId)
    local src = source
    local def = MissionDefs[missionId]
    if not def then return end
    if PlayerMission[src] then return Notify(src, 'Ya estás en una misión.', 'error') end

    local coords = GetPlayerCoords(src)
    if not coords or Utils.Dist2D(coords, RefugeCoords) > 15.0 then
        return Notify(src, 'Debes estar en el refugio para aceptar misiones.', 'error')
    end
    if Config.Reputation.enabled and (def.minReputation or 0) > GetReputation(src) then
        return Notify(src, ('Necesitas %d de reputación para esta misión.'):format(def.minReputation), 'error')
    end

    local group = Groups.Get(src)
    if group and group.leader ~= src then
        return Notify(src, 'Solo el líder del grupo puede iniciar misiones.', 'error')
    end

    local participants = {}
    for _, p in ipairs(group and group.members or { src }) do
        local reason
        local pCoords = GetPlayerCoords(p)
        local cooldown = GetCooldown(p, def.id)
        if PlayerMission[p] then
            reason = 'ya está en otra misión'
        elseif p ~= src and (not pCoords or Utils.Dist2D(pCoords, coords) > Config.Group.StartRadius) then
            reason = 'está demasiado lejos del líder'
        elseif cooldown > 0 then
            reason = ('debe esperar %s para repetirla'):format(Utils.FormatTime(cooldown))
        end
        if reason then
            if p == src then return Notify(src, ('No puedes iniciar esta misión: %s.'):format(reason), 'error') end
            Notify(src, ('%s no participará: %s.'):format(GetCharName(p), reason), 'error')
            Notify(p, ('No participarás en la misión: %s.'):format(reason), 'error')
        else
            participants[#participants + 1] = p
        end
    end

    local minPlayers = def.minPlayers or 1
    local maxPlayers = def.maxPlayers or Config.Group.MaxMembers
    if #participants < minPlayers then
        return Notify(src, ('Esta misión necesita al menos %d participantes.'):format(minPlayers), 'error')
    end
    if #participants > maxPlayers then
        return Notify(src, ('Esta misión admite como máximo %d participantes.'):format(maxPlayers), 'error')
    end

    local locIndex = PickLocation(def)
    if not locIndex then
        return Notify(src, 'Todas las zonas de esta misión están ocupadas. Inténtalo más tarde.', 'error')
    end

    nextInstance = nextInstance + 1
    local m = {
        id = nextInstance,
        def = def,
        location = def.locations[locIndex],
        locationKey = def.id .. ':' .. locIndex,
        leader = src,
        members = {},
        size = #participants,
        stageIndex = 0,
        entities = {},
        pending = {},
        expiresAt = os.time() + (def.timeLimit or 1800),
        rewardScale = 1.0,
    }
    for _, p in ipairs(participants) do
        local Player = QBCore.Functions.GetPlayer(p)
        m.members[p] = { cid = Player and Player.PlayerData.citizenid, name = GetCharName(p) }
        PlayerMission[p] = m.id
    end
    Missions[m.id] = m
    LocationsInUse[m.locationKey] = m.id

    SendToMembers(m, 'apoc_misiones:client:missionStarted', {
        instance = m.id, label = def.label, location = m.location.label, size = m.size,
    })
    StartStage(m, 1)
end)

RegisterNetEvent('apoc_misiones:server:abandon', function()
    local src = source
    if not PlayerMission[src] then return Notify(src, 'No estás en ninguna misión.', 'error') end
    RemoveFromMission(src, 'Has abandonado la misión.')
end)

RegisterNetEvent('apoc_misiones:server:entityDown', function(instance, net)
    local src = source
    local m = GetStageFor(src, instance)
    if not m then return end
    local e = m.entities[net]
    if not e or not e.alive or (e.kind ~= 'enemy' and e.kind ~= 'survivor') then return end
    local ent = GetEntityFromNet(net)
    local coords = GetPlayerCoords(src)
    if ent and coords and #(GetEntityCoords(ent) - coords) > 450.0 then return end
    e.alive = false
    OnEntityGone(m, net, e, 'dead')
end)

RegisterNetEvent('apoc_misiones:server:vehicleLost', function(instance)
    local src = source
    local m = GetStageFor(src, instance)
    if not m or not m.vehicle or m.vehicleDelivered then return end
    FailMission(m, 'El vehículo de la misión ha quedado destruido.')
end)

-- =====================================================================
--  Menú del refugio
-- =====================================================================
QBCore.Functions.CreateCallback('apoc_misiones:server:getMenu', function(source, cb)
    local rep = GetReputation(source)
    local list = {}
    for _, def in ipairs(Config.Missions) do
        list[#list + 1] = {
            id = def.id,
            label = def.label,
            description = def.description,
            icon = def.icon,
            minPlayers = def.minPlayers or 1,
            maxPlayers = def.maxPlayers or Config.Group.MaxMembers,
            minReputation = def.minReputation or 0,
            locked = Config.Reputation.enabled and (def.minReputation or 0) > rep,
            cooldown = GetCooldown(source, def.id),
            free = PickLocation(def) ~= nil,
        }
    end
    local group = Groups.Get(source)
    cb({
        missions = list,
        reputation = rep,
        reputationEnabled = Config.Reputation.enabled,
        inMission = PlayerMission[source] ~= nil,
        group = group and { size = #group.members, max = Config.Group.MaxMembers, leader = group.leader == source } or nil,
    })
end)

-- =====================================================================
--  Bucle principal
-- =====================================================================
local function TickMission(m)
    local now = os.time()
    if now >= m.expiresAt then return FailMission(m, 'Se acabó el tiempo.') end

    for id, req in pairs(m.pending) do
        if now - req.at > 15 then
            m.pending[id] = nil
            req.cb(nil)
        end
    end

    -- Marca a quién ha ido de verdad a la zona de la misión
    for src, info in pairs(m.members) do
        if not info.visited then
            local coords = GetPlayerCoords(src)
            if coords and Utils.Dist2D(coords, m.location.coords) <= Config.SpawnDistance then info.visited = true end
        end
    end

    CheckEntities(m)
    if m.ended then return end

    local st = m.stage
    if not st then return end
    TickEnemies(m, st)
    local handler = StageHandlers[st.type]
    if handler and handler.tick then handler.tick(m, st) end
end

CreateThread(function()
    while true do
        Wait(1000)
        for _, m in pairs(Missions) do
            if not m.ended then
                local ok, err = pcall(TickMission, m)
                if not ok then print(('[apoc_misiones] Error en la misión %s: %s'):format(m.def.id, err)) end
            end
        end
    end
end)

-- =====================================================================
--  Comandos, desconexiones y exports
-- =====================================================================
QBCore.Commands.Add('abandonarmision', 'Abandona la misión apocalíptica actual', {}, false, function(source)
    if not PlayerMission[source] then return Notify(source, 'No estás en ninguna misión.', 'error') end
    RemoveFromMission(source, 'Has abandonado la misión.')
end)

QBCore.Commands.Add('apocreset', 'Reinicia los tiempos de espera de misiones de un jugador', {
    { name = 'id', help = 'ID del jugador' },
}, true, function(source, args)
    local target = tonumber(args[1])
    local Player = target and QBCore.Functions.GetPlayer(target)
    if not Player then return Notify(source, 'Jugador no encontrado.', 'error') end
    Cooldowns[Player.PlayerData.citizenid] = nil
    Notify(source, 'Tiempos de espera reiniciados.', 'success')
end, 'admin')

AddEventHandler('playerDropped', function()
    local src = source
    RemoveFromMission(src, nil, true)
    Groups.OnDrop(src)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, m in pairs(Missions) do CleanupMission(m, true) end
end)

exports('IsInMission', function(src) return PlayerMission[src] ~= nil end)
