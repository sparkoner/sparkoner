local QBCore = exports['qb-core']:GetCoreObject()

Mission = nil -- estado de la misión actual de este jugador

local RefugeCoords = vector3(Config.Refuge.coords.x, Config.Refuge.coords.y, Config.Refuge.coords.z)
local refugePed, refugeBlip
local followRequests = {}

-- =====================================================================
--  Relaciones: infectados y saqueadores odian a jugadores y supervivientes
-- =====================================================================
local function SetupRelationships()
    local hostile = {}
    for _, pool in pairs(Config.Enemies) do
        AddRelationshipGroup(pool.relationship)
        hostile[#hostile + 1] = GetHashKey(pool.relationship)
    end
    AddRelationshipGroup(Config.Survivors.relationship)
    local survivors = GetHashKey(Config.Survivors.relationship)
    local player = GetHashKey('PLAYER')

    for _, group in ipairs(hostile) do
        SetRelationshipBetweenGroups(0, group, group)
        for _, target in ipairs({ player, survivors }) do
            SetRelationshipBetweenGroups(5, group, target)
            SetRelationshipBetweenGroups(5, target, group)
        end
        for _, other in ipairs(hostile) do
            if other ~= group then SetRelationshipBetweenGroups(5, group, other) end
        end
    end
    SetRelationshipBetweenGroups(1, survivors, player)
    SetRelationshipBetweenGroups(1, player, survivors)
end

-- =====================================================================
--  Entidades vigiladas (enemigos y supervivientes)
-- =====================================================================
local function RemoveWatchBlip(w)
    if w.blip and DoesBlipExist(w.blip) then RemoveBlip(w.blip) end
    w.blip = nil
end

function RemoveWatched(net)
    if not Mission then return end
    local w = Mission.watched[net]
    if w then RemoveWatchBlip(w) end
    Mission.watched[net] = nil
end

local function ClearWatched()
    if not Mission then return end
    for _, w in pairs(Mission.watched) do RemoveWatchBlip(w) end
    Mission.watched = {}
end

local function EnsureWatchBlip(w, ent)
    if w.kind == 'enemy' and not Config.EnemyBlips then return end
    if w.blip and DoesBlipExist(w.blip) and GetBlipInfoIdEntityIndex(w.blip) == ent then return end
    RemoveWatchBlip(w)
    local blip = AddBlipForEntity(ent)
    if w.kind == 'enemy' then
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.5)
        SetBlipAsShortRange(blip, true)
    else
        SetBlipSprite(blip, 280)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.7)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(w.kind == 'enemy' and 'Hostil' or 'Superviviente')
    EndTextCommandSetBlipName(blip)
    w.blip = blip
end

-- Los enemigos que controla este cliente vuelven a atacar si se quedan quietos
local function UpkeepEnemy(ped)
    if IsPedInAnyVehicle(ped, false) or IsPedInCombat(ped, 0) then return end
    EngageNearestPlayer(ped, 200.0)
end

function MakeSurvivorFollow(net)
    if followRequests[net] then return end
    followRequests[net] = true
    CreateThread(function()
        local ped
        local timeout = GetGameTimer() + 3000
        while GetGameTimer() < timeout do
            if NetworkDoesNetworkIdExist(net) then
                ped = NetworkGetEntityFromNetworkId(net)
                if ped ~= 0 and DoesEntityExist(ped) then
                    if NetworkHasControlOfEntity(ped) then break end
                    NetworkRequestControlOfEntity(ped)
                end
            end
            Wait(50)
        end
        followRequests[net] = nil
        if not ped or ped == 0 or not DoesEntityExist(ped) or not NetworkHasControlOfEntity(ped) then return end
        local group = GetPlayerGroup(PlayerId())
        ClearPedTasks(ped)
        SetPedAsGroupMember(ped, group)
        SetPedNeverLeavesGroup(ped, true)
        SetPedCanTeleportToGroupLeader(ped, group, true)
        SetGroupSeparationRange(group, 999.0)
    end)
end

local function UpkeepSurvivor(ped, net)
    if not IsPedGroupMember(ped, GetPlayerGroup(PlayerId())) then MakeSurvivorFollow(net) end
end

-- =====================================================================
--  Vehículo de la misión
-- =====================================================================
local function SetMissionVehicle(data)
    if Mission.vehicle and Mission.vehicle.net == data.net then return end
    Mission.vehicle = { net = data.net, plate = data.plate }
    if data.plate then Config.GiveKeys(data.plate) end
    QBCore.Functions.Notify('El vehículo de la misión está marcado en el mapa.', 'primary')
end

local function RemoveVehicleBlip()
    local v = Mission and Mission.vehicle
    if v and v.blip and DoesBlipExist(v.blip) then RemoveBlip(v.blip) end
    if v then v.blip = nil end
end

local function CheckMissionVehicle()
    local v = Mission.vehicle
    if not v or v.lost then return end
    if not NetworkDoesNetworkIdExist(v.net) then return RemoveVehicleBlip() end
    local veh = NetworkGetEntityFromNetworkId(v.net)
    if veh == 0 or not DoesEntityExist(veh) then return RemoveVehicleBlip() end

    if IsEntityDead(veh) or not IsVehicleDriveable(veh, false) then
        v.lost = true
        RemoveVehicleBlip()
        TriggerServerEvent('apoc_misiones:server:vehicleLost', Mission.instance)
        return
    end

    if GetVehiclePedIsIn(PlayerPedId(), false) == veh then
        RemoveVehicleBlip()
    elseif not v.blip or not DoesBlipExist(v.blip) then
        v.blip = AddBlipForEntity(veh)
        SetBlipSprite(v.blip, 225)
        SetBlipColour(v.blip, 5)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Vehículo de la misión')
        EndTextCommandSetBlipName(v.blip)
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        if Mission then
            for net, w in pairs(Mission.watched) do
                if not w.reported and NetworkDoesNetworkIdExist(net) then
                    local ent = NetworkGetEntityFromNetworkId(net)
                    if ent ~= 0 and DoesEntityExist(ent) then
                        if IsPedDeadOrDying(ent, true) then
                            w.reported = true
                            RemoveWatchBlip(w)
                            TriggerServerEvent('apoc_misiones:server:entityDown', Mission.instance, net)
                        else
                            EnsureWatchBlip(w, ent)
                            if w.kind == 'enemy' and NetworkGetEntityOwner(ent) == PlayerId() then
                                UpkeepEnemy(ent)
                            elseif w.kind == 'survivor' and Mission.mySurvivors[net] then
                                UpkeepSurvivor(ent, net)
                            end
                        end
                    end
                end
            end
            CheckMissionVehicle()
        end
    end
end)

-- =====================================================================
--  HUD con el objetivo actual
-- =====================================================================
local function DrawHudText(text, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextRightJustify(true)
    SetTextWrap(0.0, Config.Hud.x)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(Config.Hud.x, y)
end

CreateThread(function()
    while true do
        if Mission and Mission.stage then
            local st = Mission.stage
            local y = Config.Hud.y
            DrawHudText(('~y~%s~s~ (%d/%d)'):format(Mission.label, st.index, st.total), y, 0.5)
            y = y + 0.032
            DrawHudText(st.label, y, 0.4)
            if st.progress then
                y = y + 0.027
                DrawHudText(st.progress, y, 0.4)
            end
            local now = GetGameTimer()
            if Mission.prepEnds and now < Mission.prepEnds then
                y = y + 0.027
                DrawHudText(('~o~La horda llega en: %s'):format(Utils.FormatTime((Mission.prepEnds - now) / 1000)), y, 0.4)
            elseif Mission.defendEnds then
                y = y + 0.027
                local label = st.client and st.client.timerLabel or 'Resiste'
                DrawHudText(('~r~%s: %s'):format(label, Utils.FormatTime((Mission.defendEnds - now) / 1000)), y, 0.4)
            end
            y = y + 0.027
            DrawHudText(('Tiempo restante: %s'):format(Utils.FormatTime((Mission.deadline - GetGameTimer()) / 1000)), y, 0.35)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- =====================================================================
--  Eventos de la misión
-- =====================================================================
RegisterNetEvent('apoc_misiones:client:missionStarted', function(info)
    Mission = {
        instance = info.instance,
        label = info.label,
        location = info.location,
        watched = {},
        mySurvivors = {},
    }
    local mode = info.size > 1 and ('en grupo (%d)'):format(info.size) or 'en solitario'
    QBCore.Functions.Notify(('Misión iniciada %s: %s - %s'):format(mode, info.label, info.location), 'success', 8000)
end)

RegisterNetEvent('apoc_misiones:client:setStage', function(stage)
    if not Mission or Mission.instance ~= stage.instance then return end
    ExitCurrentStage()
    Mission.stage = stage
    Mission.deadline = GetGameTimer() + stage.expiresIn * 1000
    if stage.vehicle then SetMissionVehicle(stage.vehicle) end
    CreateStageBlips(stage)
    local handler = ClientStages[stage.type]
    if handler and handler.enter then handler.enter(stage) end
    QBCore.Functions.Notify(stage.label, 'primary', 7000)
end)

RegisterNetEvent('apoc_misiones:client:stageUpdate', function(instance, data)
    if not Mission or Mission.instance ~= instance then return end
    local st = Mission.stage
    if data.progress and st then st.progress = data.progress end
    if data.watch then
        for _, w in ipairs(data.watch) do Mission.watched[w.net] = { kind = w.kind } end
    end
    if data.unwatch then RemoveWatched(data.unwatch) end
    if data.vehicle then SetMissionVehicle(data.vehicle) end
    local handler = st and ClientStages[st.type]
    if handler and handler.update then handler.update(st, data) end
end)

RegisterNetEvent('apoc_misiones:client:missionEnded', function(instance, success, reason)
    if not Mission or Mission.instance ~= instance then return end
    ExitCurrentStage()
    ClearWatched()
    RemoveVehicleBlip()
    local v = Mission.vehicle
    if success and v and NetworkDoesNetworkIdExist(v.net) then
        local veh = NetworkGetEntityFromNetworkId(v.net)
        if veh ~= 0 and GetVehiclePedIsIn(PlayerPedId(), false) == veh then TaskLeaveVehicle(PlayerPedId(), veh, 0) end
    end
    if success then
        PlaySoundFrontend(-1, 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', true)
    else
        QBCore.Functions.Notify(('Misión fallida: %s'):format(reason or 'sin motivo'), 'error', 8000)
    end
    Mission = nil
end)

RegisterNetEvent('apoc_misiones:client:effect', function(kind, coords)
    if kind ~= 'fire' or #(GetEntityCoords(PlayerPedId()) - coords) > 300.0 then return end
    RequestNamedPtfxAsset('core')
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < timeout do Wait(10) end
    UseParticleFxAssetNextCall('core')
    local fx = StartParticleFxLoopedAtCoord('ent_amb_beach_campfire', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 2.0, false, false, false, false)
    Wait(30000)
    StopParticleFxLooped(fx, false)
end)

-- =====================================================================
--  Refugio: NPC y menú de misiones
-- =====================================================================
local function OpenMissionMenu()
    QBCore.Functions.TriggerCallback('apoc_misiones:server:getMenu', function(data)
        local groupText = 'En solitario'
        if data.group then
            groupText = ('Grupo %d/%d%s'):format(data.group.size, data.group.max, data.group.leader and ' (líder)' or '')
        end
        local subtitle = groupText
        if data.reputationEnabled then subtitle = ('Reputación: %d | %s'):format(data.reputation, groupText) end

        local menu = {
            { header = Config.Refuge.label, txt = subtitle, icon = 'fas fa-campground', isMenuHeader = true },
        }
        if data.inMission then
            menu[#menu + 1] = {
                header = 'Abandonar misión',
                txt = 'Sales de la misión actual sin recompensa.',
                icon = 'fas fa-running',
                params = { event = 'apoc_misiones:client:abandon' },
            }
        end
        for _, ms in ipairs(data.missions) do
            local players = ms.maxPlayers > 1 and ('%d-%d jugadores'):format(ms.minPlayers, ms.maxPlayers) or 'Solo 1 jugador'
            local txt = ('%s<br>%s'):format(ms.description, players)
            local disabled = data.inMission
            if ms.locked then
                txt = txt .. ('<br>Requiere %d de reputación'):format(ms.minReputation)
                disabled = true
            elseif ms.cooldown > 0 then
                txt = txt .. ('<br>Disponible en %s'):format(Utils.FormatTime(ms.cooldown))
                disabled = true
            elseif not ms.free then
                txt = txt .. '<br>Todas las zonas están ocupadas ahora mismo'
                disabled = true
            end
            menu[#menu + 1] = {
                header = ms.label,
                txt = txt,
                icon = ms.icon,
                disabled = disabled,
                params = { event = 'apoc_misiones:client:selectMission', args = { id = ms.id } },
            }
        end
        menu[#menu + 1] = { header = 'Cerrar', icon = 'fas fa-times', params = { event = 'qb-menu:client:closeMenu' } }
        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterNetEvent('apoc_misiones:client:selectMission', function(data)
    TriggerServerEvent('apoc_misiones:server:startMission', data.id)
end)

RegisterNetEvent('apoc_misiones:client:abandon', function()
    TriggerServerEvent('apoc_misiones:server:abandon')
end)

local function SpawnRefugePed()
    local hash = LoadModel(Config.Refuge.pedModel)
    if not hash then return end
    local c = Config.Refuge.coords
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    local ped = CreatePed(4, hash, c.x, c.y, found and groundZ or c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if Config.Refuge.scenario then TaskStartScenarioInPlace(ped, Config.Refuge.scenario, 0, true) end
    refugePed = ped
end

CreateThread(function()
    SetupRelationships()

    local b = Config.Refuge.blip
    refugeBlip = AddBlipForCoord(RefugeCoords.x, RefugeCoords.y, RefugeCoords.z)
    SetBlipSprite(refugeBlip, b.sprite)
    SetBlipColour(refugeBlip, b.color)
    SetBlipScale(refugeBlip, b.scale)
    SetBlipAsShortRange(refugeBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(refugeBlip)

    Interact.Add('apoc_refuge', {
        coords = RefugeCoords,
        distance = 2.5,
        label = 'Hablar con el coordinador del refugio',
        onUse = OpenMissionMenu,
    })

    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - RefugeCoords)
        if dist < 80.0 and not refugePed then
            SpawnRefugePed()
        elseif dist > 100.0 and refugePed then
            DeleteEntity(refugePed)
            refugePed = nil
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if refugePed and DoesEntityExist(refugePed) then DeleteEntity(refugePed) end
    if Mission then
        ExitCurrentStage()
        ClearWatched()
        RemoveVehicleBlip()
    end
end)
