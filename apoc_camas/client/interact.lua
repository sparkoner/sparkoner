local QBCore = exports['qb-core']:GetCoreObject()

-- Interacciones por proximidad: muestra "[E] texto" y ejecuta onUse al pulsar E.
Interact = {}

local points = {}
local busy = false
local shownLabel = nil

function Interact.Add(id, def) points[id] = def end
function Interact.Remove(id) points[id] = nil end
function Interact.IsBusy() return busy end

local function HideLabel()
    if shownLabel then
        exports['qb-core']:HideText()
        shownLabel = nil
    end
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local nearest, nearestDist

        if not busy and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
            local pedCoords = GetEntityCoords(ped)
            for _, def in pairs(points) do
                local dist = #(pedCoords - def.coords)
                if dist < 15.0 then sleep = 0 end
                if dist <= (def.distance or 2.0) and (not nearestDist or dist < nearestDist)
                    and (not def.canUse or def.canUse()) then
                    nearest, nearestDist = def, dist
                end
            end
        end

        if nearest then
            if shownLabel ~= nearest.label then
                exports['qb-core']:DrawText(('[E] %s'):format(nearest.label), 'left')
                shownLabel = nearest.label
            end
            if IsControlJustReleased(0, 38) then
                HideLabel()
                nearest.onUse()
            end
        else
            HideLabel()
        end
        Wait(sleep)
    end
end)

-- Barra de progreso con animación: anim = { scenario = '...' } o { dict, name, flags }
function Interact.Progress(label, duration, anim, onDone)
    busy = true
    local animation = {}
    if anim and anim.scenario then
        animation = { task = anim.scenario }
    elseif anim and anim.dict then
        animation = { animDict = anim.dict, anim = anim.name, flags = anim.flags or 1 }
    end
    QBCore.Functions.Progressbar('apoc_camas_accion', label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, animation, {}, {}, function()
        busy = false
        ClearPedTasks(PlayerPedId())
        onDone()
    end, function()
        busy = false
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify('Acción cancelada.', 'error')
    end)
end

function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then
        print(('[apoc_camas] El modelo "%s" no existe en tu versión del juego'):format(model))
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

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then HideLabel() end
end)
