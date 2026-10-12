local QBCore = exports['qb-core']:GetCoreObject()

if not Config.Crafting.enabled then return end

local bench = Config.Crafting
local benchCoords = vector3(bench.coords.x, bench.coords.y, bench.coords.z)
local benchObj = nil

local function MaterialLabel(name)
    local item = QBCore.Shared.Items[name]
    return item and item.label or name
end

local function HasMaterials(recipe)
    for _, mat in ipairs(recipe) do
        if not QBCore.Functions.HasItem(mat[1], mat[2]) then return false end
    end
    return true
end

local function OpenCraftMenu()
    local menu = {
        { header = bench.label, txt = 'Fabrica una cama para poder despertar donde la pongas.', icon = 'fas fa-hammer', isMenuHeader = true },
    }
    for _, cfg in ipairs(Config.Beds) do
        local parts = {}
        for _, mat in ipairs(cfg.recipe) do
            local ok = QBCore.Functions.HasItem(mat[1], mat[2])
            parts[#parts + 1] = ('<span style="color:%s">%s x%d</span>'):format(ok and '#7bd389' or '#e0645a', MaterialLabel(mat[1]), mat[2])
        end
        menu[#menu + 1] = {
            header = cfg.label,
            txt = table.concat(parts, ' · '),
            icon = 'fas fa-bed',
            params = { event = 'apoc_camas:client:craft', args = { item = cfg.item } },
        }
    end
    menu[#menu + 1] = { header = 'Cerrar', icon = 'fas fa-times', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('apoc_camas:client:craft', function(data)
    local cfg = BedTypes[data.item]
    if not cfg then return end
    if not HasMaterials(cfg.recipe) then
        return QBCore.Functions.Notify('No tienes todos los materiales.', 'error')
    end
    Interact.Progress(('Fabricando %s...'):format(cfg.label), bench.duration,
        { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer', flags = 1 }, function()
            TriggerServerEvent('apoc_camas:server:craft', cfg.item)
        end)
end)

CreateThread(function()
    if bench.blip then
        local blip = AddBlipForCoord(benchCoords.x, benchCoords.y, benchCoords.z)
        SetBlipSprite(blip, bench.blip.sprite)
        SetBlipColour(blip, bench.blip.color)
        SetBlipScale(blip, bench.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(bench.blip.label)
        EndTextCommandSetBlipName(blip)
    end

    Interact.Add('apoc_camas_bench', { coords = benchCoords, distance = 2.5, label = bench.label, onUse = OpenCraftMenu })

    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - benchCoords)
        if dist < 80.0 and not benchObj and bench.prop then
            local hash = LoadModel(bench.prop)
            if hash then
                benchObj = CreateObjectNoOffset(hash, benchCoords.x, benchCoords.y, benchCoords.z, false, false, false)
                SetModelAsNoLongerNeeded(hash)
                SetEntityHeading(benchObj, bench.coords.w)
                PlaceObjectOnGroundProperly(benchObj)
                FreezeEntityPosition(benchObj, true)
            end
        elseif dist > 100.0 and benchObj then
            DeleteEntity(benchObj)
            benchObj = nil
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and benchObj then DeleteEntity(benchObj) end
end)
