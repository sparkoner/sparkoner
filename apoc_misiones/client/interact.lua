local QBCore = exports['qb-core']:GetCoreObject()

-- Interacciones por proximidad: muestra "[E] texto" y ejecuta onUse al pulsar.
-- Cada punto puede ir ligado a unas coordenadas fijas (coords) o a una
-- entidad de red (net) que se mueve, como un superviviente.
Interact = {}

local points = {}
local busy = false
local shownLabel = nil

function Interact.Add(id, def) points[id] = def end
function Interact.Remove(id) points[id] = nil end

local function Resolve(def)
    if def.net then
        if not NetworkDoesNetworkIdExist(def.net) then return nil end
        local ent = NetworkGetEntityFromNetworkId(def.net)
        if ent == 0 or not DoesEntityExist(ent) then return nil end
        return GetEntityCoords(ent), ent
    end
    return def.coords, nil
end

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
        local nearest, nearestEnt, nearestDist

        if not busy and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
            local pedCoords = GetEntityCoords(ped)
            for _, def in pairs(points) do
                local coords, ent = Resolve(def)
                if coords then
                    local dist = #(pedCoords - coords)
                    if dist < 25.0 then
                        sleep = 0
                        if def.marker then
                            DrawMarker(2, coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                                0.3, 0.3, 0.3, 255, 190, 0, 160, true, true, 2, false, nil, nil, false)
                        end
                    end
                    if dist <= (def.distance or 2.0) and (not nearestDist or dist < nearestDist)
                        and (not def.canUse or def.canUse(ent)) then
                        nearest, nearestEnt, nearestDist = def, ent, dist
                    end
                end
            end
        end

        if nearest then
            if shownLabel ~= nearest.label then
                exports['qb-core']:DrawText(('[E] %s'):format(nearest.label), 'left')
                shownLabel = nearest.label
            end
            if IsControlJustReleased(0, Config.InteractKey) then
                HideLabel()
                nearest.onUse(nearestEnt)
            end
        else
            HideLabel()
        end
        Wait(sleep)
    end
end)

-- Barra de progreso con animación. anim = { scenario = '...' } o { dict, name, flags }
function Interact.Progress(label, duration, anim, onDone)
    busy = true
    local animation = {}
    if anim and anim.scenario then
        animation = { task = anim.scenario }
    elseif anim and anim.dict then
        animation = { animDict = anim.dict, anim = anim.name, flags = anim.flags or 1 }
    end
    QBCore.Functions.Progressbar('apoc_misiones_accion', label, duration, false, true, {
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

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then HideLabel() end
end)
