local QBCore = exports['qb-core']:GetCoreObject()

-- Lógica de cada tipo de etapa en el cliente: blips, objetos e interacciones.
ClientStages = {}

local stageProps, stageInteractions, stageBlips = {}, {}, {}

local function AddStageInteraction(id, def)
    stageInteractions[id] = true
    Interact.Add(id, def)
end

local function RemoveStageInteraction(id)
    stageInteractions[id] = nil
    Interact.Remove(id)
end

local function SpawnLocalProp(key, model, coords)
    if not model then return end
    local hash = LoadModel(model)
    if not hash then return end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    stageProps[key] = obj
end

local function RemoveLocalProp(key)
    local obj = stageProps[key]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    stageProps[key] = nil
end

function AddStageBlip(key, coords, sprite, color, scale, label, route)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, color)
    end
    stageBlips[key] = blip
    return blip
end

local function RemoveStageBlip(key)
    local blip = stageBlips[key]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    stageBlips[key] = nil
end

function CreateStageBlips(stage)
    local area = AddBlipForRadius(stage.center.x, stage.center.y, stage.center.z, stage.radius + 0.0)
    SetBlipColour(area, 1)
    SetBlipAlpha(area, 80)
    stageBlips.area = area
    AddStageBlip('zone', stage.center, 1, 5, 0.9, stage.label, true)
end

function ExitCurrentStage()
    for key in pairs(stageProps) do RemoveLocalProp(key) end
    for id in pairs(stageInteractions) do Interact.Remove(id) end
    for key in pairs(stageBlips) do RemoveStageBlip(key) end
    stageProps, stageInteractions, stageBlips = {}, {}, {}
    if Mission then Mission.defendEnds = nil end
end

-- =====================================================================
--  search
-- =====================================================================
local function SetupCrates(st)
    local c = st.client
    for i, coords in ipairs(c.crates) do
        local key = 'crate' .. i
        SpawnLocalProp(key, c.prop, coords)
        AddStageBlip(key, coords, 1, 5, 0.55, 'Suministros', false)
        AddStageInteraction(key, {
            coords = coords,
            distance = 2.5,
            label = c.interactLabel,
            marker = not c.prop,
            onUse = function()
                Interact.Progress(c.interactLabel .. '...', c.duration, c.anim, function()
                    TriggerServerEvent('apoc_misiones:server:searchCrate', Mission.instance, i)
                end)
            end,
        })
    end
end

ClientStages.search = {
    enter = function(st)
        if st.client.crates then SetupCrates(st) end
    end,
    update = function(st, data)
        if data.crates then
            st.client.crates = data.crates
            SetupCrates(st)
        end
        if data.looted then
            local key = 'crate' .. data.looted
            RemoveLocalProp(key)
            RemoveStageBlip(key)
            RemoveStageInteraction(key)
        end
    end,
}

-- =====================================================================
--  interact
-- =====================================================================
local function SetupInteractPoint(st)
    local c = st.client
    SpawnLocalProp('interact', c.prop, c.point)
    AddStageInteraction('interact', {
        coords = c.point,
        distance = 3.0,
        label = c.label,
        marker = true,
        onUse = function()
            if c.requiredItem and not QBCore.Functions.HasItem(c.requiredItem) then
                local item = QBCore.Shared.Items[c.requiredItem]
                return QBCore.Functions.Notify(('Necesitas: %s'):format(item and item.label or c.requiredItem), 'error')
            end
            Interact.Progress(c.label .. '...', c.duration, c.anim, function()
                TriggerServerEvent('apoc_misiones:server:interactDone', Mission.instance)
            end)
        end,
    })
end

ClientStages.interact = {
    enter = function(st)
        if st.client.point then SetupInteractPoint(st) end
    end,
    update = function(st, data)
        if data.point then
            st.client.point = data.point
            SetupInteractPoint(st)
        end
    end,
}

-- =====================================================================
--  escort
-- =====================================================================
local function AddSurvivorInteraction(net)
    AddStageInteraction('surv' .. net, {
        net = net,
        distance = 2.5,
        label = 'Rescatar superviviente',
        canUse = function(ent) return ent and not IsPedDeadOrDying(ent, true) end,
        onUse = function()
            TriggerServerEvent('apoc_misiones:server:survivorFollow', Mission.instance, net)
        end,
    })
end

ClientStages.escort = {
    enter = function(st)
        AddStageBlip('refuge', Config.Refuge.coords, 40, 2, 0.9, 'Refugio: entrega de supervivientes', false)
        if st.client.survivors then
            for _, net in ipairs(st.client.survivors) do AddSurvivorInteraction(net) end
        end
    end,
    update = function(st, data)
        if data.survivors then
            st.client.survivors = data.survivors
            for _, net in ipairs(data.survivors) do AddSurvivorInteraction(net) end
        end
        if data.following then
            local net = data.following.net
            RemoveStageInteraction('surv' .. net)
            if data.following.by == GetPlayerServerId(PlayerId()) then
                Mission.mySurvivors[net] = true
                MakeSurvivorFollow(net)
                QBCore.Functions.Notify('El superviviente te sigue. ¡Llévalo al refugio!', 'success')
                if stageBlips.zone then SetBlipRoute(stageBlips.zone, false) end
                if stageBlips.refuge then
                    SetBlipRoute(stageBlips.refuge, true)
                    SetBlipRouteColour(stageBlips.refuge, 2)
                end
            end
        end
        if data.available then
            Mission.mySurvivors[data.available] = nil
            AddSurvivorInteraction(data.available)
        end
        if data.rescued then
            Mission.mySurvivors[data.rescued] = nil
            RemoveStageInteraction('surv' .. data.rescued)
            RemoveWatched(data.rescued)
        end
        if data.unwatch then RemoveStageInteraction('surv' .. data.unwatch) end
    end,
}

-- =====================================================================
--  defend
-- =====================================================================
ClientStages.defend = {
    update = function(st, data)
        if data.defendEndsIn then Mission.defendEnds = GetGameTimer() + data.defendEndsIn * 1000 end
    end,
}
