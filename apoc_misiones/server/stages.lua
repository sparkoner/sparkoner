local QBCore = exports['qb-core']:GetCoreObject()

-- Pide a un participante cercano que calcule puntos válidos sobre el suelo.
local function RequestPoints(m, st, count, minDist, maxDist, onReady)
    if st.requesting then return end
    local spawner = FindClosestMember(m, st.center, Config.SpawnDistance)
    if not spawner then return end
    st.requesting = true
    RequestSpawn(m, spawner, 'points', { center = st.center, count = count, minDist = minDist, maxDist = maxDist }, function(results)
        st.requesting = false
        if not results or m.ended or m.stage ~= st then return end
        local points = {}
        for _, p in ipairs(results) do
            if type(p) == 'vector3' and Utils.Dist2D(p, st.center) <= maxDist + 30.0 and #points < count then
                points[#points + 1] = p
            end
        end
        onReady(points)
    end)
end

-- =====================================================================
--  search: registrar cajas en la zona
-- =====================================================================
local function SearchProgress(st)
    return ('%s: %d/%d'):format(st.def.progressLabel or 'Registrados', st.looted, st.total)
end

StageHandlers.search = {
    start = function(m, st)
        st.total = math.max(1, Utils.Scale(st.def.count, m.size))
        st.looted = 0
        st.client = {
            prop = st.def.prop,
            duration = st.def.duration or 7000,
            anim = st.def.anim,
            interactLabel = st.def.interactLabel or 'Registrar',
        }
    end,
    tick = function(m, st)
        if st.crates then return end
        RequestPoints(m, st, st.total, 3.0, st.radius * 0.8, function(points)
            if #points == 0 then return end
            st.crates = {}
            for i, p in ipairs(points) do st.crates[i] = { coords = p, looted = false } end
            st.total = #points
            st.client.crates = points
            st.progress = SearchProgress(st)
            UpdateStage(m, { crates = points, progress = st.progress })
        end)
    end,
}

RegisterNetEvent('apoc_misiones:server:searchCrate', function(instance, index)
    local src = source
    local m, st = GetStageFor(src, instance, 'search')
    if not st or not st.crates then return end
    local crate = st.crates[index]
    if not crate then return end
    if crate.looted then return Notify(src, 'Alguien ya ha registrado esta caja.', 'error') end
    local coords = GetPlayerCoords(src)
    if not coords or Utils.Dist2D(coords, crate.coords) > 4.0 then return end

    crate.looted = true
    st.looted = st.looted + 1
    st.progress = SearchProgress(st)
    UpdateStage(m, { looted = index, progress = st.progress })
    if st.looted >= st.total then AdvanceStage(m) end
end)

-- =====================================================================
--  return: volver al refugio
-- =====================================================================
StageHandlers['return'] = {
    start = function(m, st)
        st.center = RefugeCoords
        st.radius = Config.Refuge.deliveryRadius
        st.endPoint = RefugeCoords
    end,
    tick = function(m, st)
        if AnyMemberWithin(m, RefugeCoords, Config.Refuge.deliveryRadius) then AdvanceStage(m) end
    end,
}

-- =====================================================================
--  vehicle: recoger el vehículo de la misión
-- =====================================================================
StageHandlers.vehicle = {
    start = function(m, st)
        st.client = { model = st.def.model }
    end,
    tick = function(m, st)
        if not m.vehicle then
            if st.requesting then return end
            local spawner = FindClosestMember(m, st.center, Config.SpawnDistance)
            if not spawner then return end
            st.requesting = true
            RequestSpawn(m, spawner, 'vehicle', { model = st.def.model, center = st.center }, function(results, extra)
                st.requesting = false
                if not results or m.ended then return end
                local net = results[1]
                if type(net) ~= 'number' then return end
                local plate = type(extra.plate) == 'string' and extra.plate or nil
                m.vehicle = { net = net, plate = plate, origin = st.center }
                RegisterEntity(m, net, 'vehicle')
                UpdateStage(m, { vehicle = { net = net, plate = plate } })
            end)
            return
        end

        local veh = GetEntityFromNet(m.vehicle.net)
        if not veh then return end
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver == 0 then return end
        for src in pairs(m.members) do
            if GetPlayerPed(src) == driver then return AdvanceStage(m) end
        end
    end,
}

-- =====================================================================
--  deliver: llevar el vehículo al refugio (con posible emboscada)
-- =====================================================================
local function GetDriverMember(m, veh)
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver == 0 then return nil end
    for src in pairs(m.members) do
        if GetPlayerPed(src) == driver then return src end
    end
    return nil
end

local function TriggerAmbush(m, st, driverSrc)
    local enemy = st.enemy
    local cfg = st.def.enemies
    enemy.triggered = true
    enemy.requesting = true
    RequestSpawn(m, driverSrc, 'ambush', {
        pool = enemy.pool,
        vehicles = math.max(1, Utils.Scale(cfg.vehicles or 1, m.size)),
        perVehicle = cfg.perVehicle or 3,
        targetNet = m.vehicle.net,
        distance = cfg.spawnDistance or 120.0,
    }, function(results, extra)
        enemy.requesting = false
        if not results then
            enemy.triggered = false
            return
        end
        local watch = {}
        for _, net in ipairs(results) do
            if type(net) == 'number' then
                RegisterEntity(m, net, 'enemy')
                watch[#watch + 1] = { net = net, kind = 'enemy' }
            end
        end
        for _, net in ipairs(type(extra.vehicles) == 'table' and extra.vehicles or {}) do
            if type(net) == 'number' then RegisterEntity(m, net, 'aux') end
        end
        enemy.alive = enemy.alive + #watch
        WatchEntities(m, watch)
        if #watch > 0 then NotifyMembers(m, '¡Emboscada! Unos saqueadores van a por el camión.', 'error', 7000) end
    end)
end

StageHandlers.deliver = {
    start = function(m, st)
        st.center = RefugeCoords
        st.radius = Config.Refuge.deliveryRadius
        st.endPoint = RefugeCoords
        if not m.vehicle then FailMission(m, 'No hay ningún vehículo que entregar.') end
    end,
    tick = function(m, st)
        local veh = GetEntityFromNet(m.vehicle.net)
        if not veh then return end
        local coords = GetEntityCoords(veh)
        if Utils.Dist2D(coords, RefugeCoords) <= Config.Refuge.deliveryRadius then
            m.vehicleDelivered = true
            return AdvanceStage(m)
        end

        local enemy = st.enemy
        if enemy and enemy.mode == 'ambush' and not enemy.triggered and not enemy.requesting then
            local trigger = st.def.enemies.triggerDistance or 400.0
            if Utils.Dist2D(coords, m.vehicle.origin) >= trigger and Utils.Dist2D(coords, RefugeCoords) >= 300.0 then
                local driverSrc = GetDriverMember(m, veh)
                if driverSrc then TriggerAmbush(m, st, driverSrc) end
            end
        end
    end,
}

-- =====================================================================
--  kill: eliminar enemigos
-- =====================================================================
local function KillProgress(st)
    return ('%s: %d/%d'):format(st.def.progressLabel or 'Eliminados', st.enemy.killed, st.enemy.total)
end

StageHandlers.kill = {
    start = function(m, st)
        if not st.enemy then
            print(('[apoc_misiones] La etapa "kill" de %s no tiene enemigos configurados'):format(m.def.id))
            return AdvanceStage(m)
        end
        st.progress = KillProgress(st)
    end,
    onEntityGone = function(m, st, net, e, reason)
        if e.kind ~= 'enemy' or e.stage ~= m.stageIndex or reason ~= 'dead' then return end
        SetProgress(m, KillProgress(st))
        if st.enemy.killed >= st.enemy.total then AdvanceStage(m) end
    end,
}

-- =====================================================================
--  interact: acción con barra de progreso en un punto
-- =====================================================================
StageHandlers.interact = {
    start = function(m, st)
        st.client = {
            prop = st.def.prop,
            label = st.def.interactLabel or 'Interactuar',
            duration = st.def.duration or 10000,
            anim = st.def.anim,
            requiredItem = st.def.requiredItem,
        }
    end,
    tick = function(m, st)
        if st.point then return end
        RequestPoints(m, st, 1, 0.0, st.def.pointRadius or 0.0, function(points)
            st.point = points[1] or st.center
            st.client.point = st.point
            UpdateStage(m, { point = st.point })
        end)
    end,
}

RegisterNetEvent('apoc_misiones:server:interactDone', function(instance)
    local src = source
    local m, st = GetStageFor(src, instance, 'interact')
    if not st or not st.point or st.done then return end
    local coords = GetPlayerCoords(src)
    if not coords or Utils.Dist2D(coords, st.point) > 5.0 then return end

    local itemName = st.def.requiredItem
    if itemName then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or InvGetAmount(Player, src, itemName) < 1 then
            local shared = QBCore.Shared.Items[itemName]
            return Notify(src, ('Necesitas: %s'):format(shared and shared.label or itemName), 'error')
        end
        if st.def.consumeItem and InvRemoveItem(Player, src, itemName, 1) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove', 1)
        end
    end

    st.done = true
    st.endPoint = st.point
    if st.def.effect then TriggerClientEvent('apoc_misiones:client:effect', -1, st.def.effect, st.point) end
    AdvanceStage(m)
end)

-- =====================================================================
--  escort: rescatar supervivientes y llevarlos al refugio
-- =====================================================================
local function EscortProgress(st)
    local text = ('Rescatados: %d/%d'):format(st.rescued, st.total)
    if st.dead > 0 then text = text .. (' | Perdidos: %d'):format(st.dead) end
    return text
end

local function CheckEscortFinished(m, st)
    if m.ended or m.stage ~= st or not st.spawned then return end
    if st.total - st.dead < st.minRescued then
        return FailMission(m, 'Han muerto demasiados supervivientes.')
    end
    if st.rescued + st.dead >= st.total then
        m.rewardScale = st.rescued / st.total
        AdvanceStage(m)
    end
end

StageHandlers.escort = {
    start = function(m, st)
        st.total = math.max(1, math.min(Utils.Scale(st.def.count, m.size), 7))
        st.minRescued = math.max(1, math.ceil(st.total * (st.def.minRescuedRatio or 0.5)))
        st.rescued, st.dead = 0, 0
        st.survivors = {}
        st.endPoint = RefugeCoords
        st.progress = 'Encuentra a los supervivientes'
    end,
    tick = function(m, st)
        if not st.spawned then
            if st.requesting then return end
            local spawner = FindClosestMember(m, st.center, Config.SpawnDistance)
            if not spawner then return end
            st.requesting = true
            RequestSpawn(m, spawner, 'survivors', {
                count = st.total, center = st.center, radius = math.min(st.radius * 0.5, 15.0),
            }, function(results)
                st.requesting = false
                if not results or m.ended or m.stage ~= st then return end
                local watch, list = {}, {}
                for _, net in ipairs(results) do
                    if type(net) == 'number' and #list < st.total then
                        st.survivors[net] = {}
                        RegisterEntity(m, net, 'survivor')
                        watch[#watch + 1] = { net = net, kind = 'survivor' }
                        list[#list + 1] = net
                    end
                end
                if #list == 0 then return end
                st.spawned = true
                st.total = #list
                st.minRescued = math.min(st.minRescued, st.total)
                st.progress = EscortProgress(st)
                WatchEntities(m, watch)
                UpdateStage(m, { survivors = list, progress = st.progress })
            end)
            return
        end

        for net, s in pairs(st.survivors) do
            local e = m.entities[net]
            if e and e.alive and not s.rescued then
                local ent = GetEntityFromNet(net)
                if ent and Utils.Dist2D(GetEntityCoords(ent), RefugeCoords) <= Config.Refuge.deliveryRadius then
                    s.rescued = true
                    e.alive = false
                    st.rescued = st.rescued + 1
                    st.progress = EscortProgress(st)
                    UpdateStage(m, { rescued = net, progress = st.progress })
                    NotifyMembers(m, 'Un superviviente ha llegado sano y salvo al refugio.', 'success')
                    SetTimeout(3000, function()
                        local survivor = GetEntityFromNet(net)
                        if survivor then DeleteEntity(survivor) end
                    end)
                end
            end
        end
        CheckEscortFinished(m, st)
    end,
    onEntityGone = function(m, st, net, e, reason)
        if e.kind ~= 'survivor' then return end
        local s = st.survivors and st.survivors[net]
        if not s or s.rescued or s.dead then return end
        s.dead = true
        st.dead = st.dead + 1
        st.progress = EscortProgress(st)
        UpdateStage(m, { progress = st.progress, unwatch = net })
        NotifyMembers(m, reason == 'dead' and 'Un superviviente ha muerto.' or 'Habéis perdido a un superviviente.', 'error')
        CheckEscortFinished(m, st)
    end,
}

RegisterNetEvent('apoc_misiones:server:survivorFollow', function(instance, net)
    local src = source
    local m, st = GetStageFor(src, instance, 'escort')
    if not st or not st.survivors then return end
    local s = st.survivors[net]
    local e = m.entities[net]
    if not s or s.rescued or s.dead or not e or not e.alive then return end
    if s.followBy and m.members[s.followBy] then
        if s.followBy ~= src then Notify(src, 'Este superviviente ya sigue a otra persona.', 'error') end
        return
    end
    local ent = GetEntityFromNet(net)
    local coords = GetPlayerCoords(src)
    if not ent or not coords or #(GetEntityCoords(ent) - coords) > 6.0 then return end

    s.followBy = src
    UpdateStage(m, { following = { net = net, by = src } })
end)

-- =====================================================================
--  defend: resistir oleadas en la zona
-- =====================================================================
StageHandlers.defend = {
    start = function(m, st)
        st.duration = st.def.duration or 180
        st.radius = st.def.radius or 60.0
        st.progress = 'Llega a la zona para empezar'
    end,
    tick = function(m, st)
        local now = os.time()
        local inZone = AnyMemberWithin(m, st.center, st.radius)

        if not st.startedAt then
            if not inZone then return end
            st.startedAt = now
            st.endsAt = now + st.duration
            st.lastInZone = now
            if st.enemy then
                st.enemy.active = true
                st.enemy.nextWave = now + 5
            end
            st.progress = 'Resiste hasta que termine la transmisión'
            UpdateStage(m, { defendEndsIn = st.duration, progress = st.progress })
            NotifyMembers(m, 'La transmisión ha empezado. ¡Se acerca la horda!', 'error', 7000)
            return
        end

        if inZone then
            st.lastInZone = now
            st.warned = false
        else
            local grace = st.def.leaveGrace or 30
            if now - st.lastInZone > grace then
                return FailMission(m, 'Abandonasteis la zona y la transmisión se cortó.')
            elseif not st.warned then
                st.warned = true
                NotifyMembers(m, ('¡Volved a la zona! La transmisión se cortará en %d segundos.'):format(grace), 'error', 7000)
            end
        end

        if now >= st.endsAt then AdvanceStage(m) end
    end,
}
