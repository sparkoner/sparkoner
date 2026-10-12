-- Creación de entidades. El servidor elige a un participante cercano a la zona
-- y le pide que cree las entidades; el cliente devuelve sus IDs de red.

function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then
        print(('[apoc_misiones] El modelo "%s" no existe'):format(model))
        return nil
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

-- Carga un modelo al azar de la lista; si alguno no existe prueba con los demás
function LoadRandomModel(models)
    if not models or #models == 0 then return nil end
    local start = math.random(#models)
    for i = 0, #models - 1 do
        local hash = LoadModel(models[(start + i - 1) % #models + 1])
        if hash then return hash end
    end
    return nil
end

local function LoadAnimSet(set)
    RequestAnimSet(set)
    local timeout = GetGameTimer() + 3000
    while not HasAnimSetLoaded(set) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimSetLoaded(set)
end

-- Punto aleatorio sobre el suelo entre minDist y maxDist del centro
function RandomGroundPoint(center, minDist, maxDist)
    for _ = 1, 12 do
        local angle = math.random() * 2 * math.pi
        local dist = minDist + math.random() * math.max(0.0, maxDist - minDist)
        local x, y = center.x + math.cos(angle) * dist, center.y + math.sin(angle) * dist
        local ok, safe = GetSafeCoordForPed(x, y, center.z, false, 16)
        if ok and Utils.Dist2D(safe, center) <= maxDist + 10.0 then return safe end
        for _, offset in ipairs({ 3.0, 50.0 }) do
            local found, groundZ = GetGroundZFor_3dCoord(x, y, center.z + offset, false)
            if found then return vector3(x, y, groundZ) end
        end
    end
    return vector3(center.x, center.y, center.z)
end

function GetNearestPlayerPed(coords, range)
    local best, bestDist
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and not IsPedDeadOrDying(ped, true) then
            local dist = #(GetEntityCoords(ped) - coords)
            if dist <= range and (not bestDist or dist < bestDist) then best, bestDist = ped, dist end
        end
    end
    return best
end

function EngageNearestPlayer(ped, range)
    local target = GetNearestPlayerPed(GetEntityCoords(ped), range or 200.0)
    if target then
        TaskCombatPed(ped, target, 0, 16)
    else
        TaskWanderStandard(ped, 10.0, 10)
    end
end

local function ApplyInfectedStyle(ped, pool)
    RemoveAllPedWeapons(ped, true)
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 3)
    SetPedCombatRange(ped, 0)
    SetPedConfigFlag(ped, 281, true) -- sin animación de agonía en el suelo
    SetPedCanEvasiveDive(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedSuffersCriticalHits(ped, pool.criticalHits ~= false) -- los disparos en la cabeza matan
    DisablePedPainAudio(ped, true)
    StopPedSpeaking(ped, true)
    ApplyPedDamagePack(ped, 'BigHitByVehicle', 0.0, 9.0)
    ApplyPedDamagePack(ped, 'SCR_Dumpster', 0.0, 9.0)
    if pool.walkStyles and #pool.walkStyles > 0 then
        local style = pool.walkStyles[math.random(#pool.walkStyles)]
        if LoadAnimSet(style) then SetPedMovementClipset(ped, style, 1.0) end
    end
end

local function ApplyArmedStyle(ped, pool)
    if pool.weapons and #pool.weapons > 0 then
        GiveWeaponToPed(ped, GetHashKey(pool.weapons[math.random(#pool.weapons)]), 250, false, true)
    end
    SetPedCombatAbility(ped, 1)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 1)
    SetPedCombatAttributes(ped, 0, true) -- usa coberturas
    SetPedCombatAttributes(ped, 2, true) -- dispara desde vehículos
    SetPedDropsWeaponsWhenDead(ped, pool.dropWeapons == true)
end

function SpawnEnemy(poolName, pos)
    local pool = Config.Enemies[poolName]
    if not pool then return nil end
    local hash = LoadRandomModel(pool.models) or LoadRandomModel(pool.fallbackModels)
    if not hash then return nil end

    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end

    SetEntityAsMissionEntity(ped, true, true)
    local net = PedToNet(ped)
    SetNetworkIdCanMigrate(net, true)

    SetPedRandomComponentVariation(ped, 0)
    SetPedRelationshipGroupHash(ped, GetHashKey(pool.relationship))
    SetPedMaxHealth(ped, pool.health or 200)
    SetEntityHealth(ped, pool.health or 200)
    SetPedArmour(ped, pool.armour or 0)
    SetPedAccuracy(ped, pool.accuracy or 20)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true) -- lucha siempre
    SetPedCombatAttributes(ped, 5, true)  -- ataca aunque el objetivo vaya armado
    SetPedSeeingRange(ped, pool.sight or 80.0)
    SetPedHearingRange(ped, pool.sight or 80.0)
    SetPedKeepTask(ped, true)

    if pool.style == 'infected' then
        ApplyInfectedStyle(ped, pool)
    else
        ApplyArmedStyle(ped, pool)
    end
    EngageNearestPlayer(ped)
    return ped, net
end

-- =====================================================================
--  Tipos de aparición
-- =====================================================================
local Spawners = {}

function Spawners.enemies(p)
    local nets = {}
    for _ = 1, math.min(p.count or 0, 20) do
        local pos = RandomGroundPoint(p.center, p.minDist or 15.0, p.maxDist or 45.0)
        local _, net = SpawnEnemy(p.pool, pos)
        if net then nets[#nets + 1] = net end
        Wait(50)
    end
    return nets
end

function Spawners.points(p)
    local points = {}
    for _ = 1, math.min(p.count or 1, 30) do
        points[#points + 1] = RandomGroundPoint(p.center, p.minDist or 0.0, p.maxDist or 0.0)
    end
    return points
end

function Spawners.vehicle(p)
    local found, node, heading = GetClosestVehicleNodeWithHeading(p.center.x, p.center.y, p.center.z, 1, 3.0, 0)
    if not found then node, heading = p.center, 0.0 end
    local hash = LoadModel(p.model)
    if not hash then return {} end

    local veh = CreateVehicle(hash, node.x, node.y, node.z + 0.5, heading, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return {} end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    local plate = ('APOC%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDirtLevel(veh, 12.0)
    SetVehicleDoorsLocked(veh, 1)
    Config.SetFuel(veh, 100.0)
    local net = VehToNet(veh)
    SetNetworkIdCanMigrate(net, true)
    return { net }, { plate = plate }
end

function Spawners.survivors(p)
    local cfg = Config.Survivors
    local nets = {}
    for _ = 1, math.min(p.count or 1, 7) do
        local pos = RandomGroundPoint(p.center, 1.0, p.radius or 8.0)
        local models = (type(p.models) == 'table' and #p.models > 0) and p.models or cfg.models
        local hash = LoadRandomModel(models)
        if hash then
            local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true)
            SetModelAsNoLongerNeeded(hash)
            if DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                local net = PedToNet(ped)
                SetNetworkIdCanMigrate(net, true)
                SetPedRandomComponentVariation(ped, 0)
                SetPedRelationshipGroupHash(ped, GetHashKey(cfg.relationship))
                SetPedMaxHealth(ped, cfg.health or 200)
                SetEntityHealth(ped, cfg.health or 200)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, false)
                if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end
                SetPedKeepTask(ped, true)
                nets[#nets + 1] = net
            end
        end
        Wait(50)
    end
    return nets
end

function Spawners.ambush(p)
    local pool = Config.Enemies[p.pool or 'raiders']
    if not pool or not pool.vehicles or #pool.vehicles == 0 then return {} end
    local base = PlayerPedId()
    if p.targetNet and NetworkDoesNetworkIdExist(p.targetNet) then
        local target = NetworkGetEntityFromNetworkId(p.targetNet)
        if target ~= 0 and DoesEntityExist(target) then base = target end
    end
    local targetPed = PlayerPedId()
    local nets, vehicles = {}, {}

    for v = 1, math.min(p.vehicles or 1, 4) do
        local behind = GetOffsetFromEntityInWorldCoords(base, 0.0, -((p.distance or 120.0) + (v - 1) * 20.0), 0.0)
        local found, node, heading = GetClosestVehicleNodeWithHeading(behind.x, behind.y, behind.z, 1, 3.0, 0)
        if not found then node, heading = behind, GetEntityHeading(base) end
        local hash = LoadRandomModel(pool.vehicles)
        if hash then
            local veh = CreateVehicle(hash, node.x, node.y, node.z + 0.5, heading, true, true)
            SetModelAsNoLongerNeeded(hash)
            if DoesEntityExist(veh) then
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleOnGroundProperly(veh)
                SetVehicleEngineOn(veh, true, true, false)
                local vehNet = VehToNet(veh)
                SetNetworkIdCanMigrate(vehNet, true)
                vehicles[#vehicles + 1] = vehNet

                local seats = math.min(p.perVehicle or 2, GetVehicleModelNumberOfSeats(hash))
                for seat = -1, seats - 2 do
                    local ped, net = SpawnEnemy(p.pool or 'raiders', vector3(node.x, node.y, node.z + 1.0))
                    if ped then
                        SetPedIntoVehicle(ped, veh, seat)
                        if seat == -1 then
                            SetDriverAbility(ped, 1.0)
                            SetDriverAggressiveness(ped, 1.0)
                            TaskVehicleChase(ped, targetPed)
                            SetTaskVehicleChaseIdealPursuitDistance(ped, 0.0)
                        else
                            TaskCombatPed(ped, targetPed, 0, 16)
                        end
                        nets[#nets + 1] = net
                    end
                end
            end
        end
    end
    return nets, { vehicles = vehicles }
end

RegisterNetEvent('apoc_misiones:client:spawn', function(instance, reqId, kind, payload)
    local results, extra = {}, {}
    local spawner = Spawners[kind]
    if spawner then results, extra = spawner(payload) end
    TriggerServerEvent('apoc_misiones:server:spawned', instance, reqId, results or {}, extra or {})
end)

-- Borra entidades que se crearon cuando la misión ya había terminado
RegisterNetEvent('apoc_misiones:client:deleteEntities', function(nets)
    for _, net in ipairs(nets) do
        if type(net) == 'number' and NetworkDoesNetworkIdExist(net) then
            local ent = NetworkGetEntityFromNetworkId(net)
            if ent ~= 0 and DoesEntityExist(ent) and NetworkHasControlOfEntity(ent) then DeleteEntity(ent) end
        end
    end
end)

-- Al terminar la misión los enemigos se dejan al motor del juego para que los limpie
RegisterNetEvent('apoc_misiones:client:releaseEntities', function(nets)
    for _, net in ipairs(nets) do
        if NetworkDoesNetworkIdExist(net) then
            local ent = NetworkGetEntityFromNetworkId(net)
            if ent ~= 0 and DoesEntityExist(ent) and NetworkHasControlOfEntity(ent) then
                SetEntityAsNoLongerNeeded(ent)
            end
        end
    end
end)
