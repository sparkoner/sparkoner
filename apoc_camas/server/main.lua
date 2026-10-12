local QBCore = exports['qb-core']:GetCoreObject()

Beds = {}      -- [id] = { id, citizenid, item, label, coords, heading }
BedTypes = {}  -- [item] = configuración de la cama
for _, bed in ipairs(Config.Beds) do BedTypes[bed.item] = bed end

local Busy = {}  -- evita dobles peticiones mientras se espera a la base de datos

function Notify(src, msg, kind, length)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', length or 5000)
end

function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Inventario: funciones del jugador (qb-core clásico / ox_inventory) o exports de qb-inventory
local function InvAddItem(Player, src, name, amount)
    if Player.Functions.AddItem then return Player.Functions.AddItem(name, amount) end
    local ok, result = pcall(function() return exports['qb-inventory']:AddItem(src, name, amount, false, false, 'apoc_camas') end)
    return ok and result
end

local function InvRemoveItem(Player, src, name, amount)
    if Player.Functions.RemoveItem then return Player.Functions.RemoveItem(name, amount) end
    local ok, result = pcall(function() return exports['qb-inventory']:RemoveItem(src, name, amount, false, 'apoc_camas') end)
    return ok and result
end

local function InvGetAmount(Player, src, name)
    local item
    if Player.Functions.GetItemByName then
        item = Player.Functions.GetItemByName(name)
    else
        local ok, result = pcall(function() return exports['qb-inventory']:GetItemByName(src, name) end)
        item = ok and result or nil
    end
    return item and (item.amount or item.count or 0) or 0
end

local function ItemBox(src, name, kind, amount)
    local shared = QBCore.Shared.Items[name]
    if shared then TriggerClientEvent('inventory:client:ItemBox', src, shared, kind, amount) end
end

local function PublicBed(bed)
    return { id = bed.id, item = bed.item, label = bed.label, coords = bed.coords, heading = bed.heading, owner = bed.citizenid }
end

function GetPlayerBeds(citizenid)
    local list = {}
    for _, bed in pairs(Beds) do
        if bed.citizenid == citizenid then list[#list + 1] = bed end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function AllPublicBeds()
    local list = {}
    for _, bed in pairs(Beds) do list[#list + 1] = PublicBed(bed) end
    return list
end

-- =====================================================================
--  Base de datos
-- =====================================================================
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `apoc_camas` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `item` VARCHAR(50) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        )
    ]])
    local rows = MySQL.query.await('SELECT * FROM `apoc_camas`') or {}
    for _, row in ipairs(rows) do
        if BedTypes[row.item] then
            Beds[row.id] = {
                id = row.id, citizenid = row.citizenid, item = row.item, label = row.label,
                coords = vector3(row.x, row.y, row.z), heading = row.heading + 0.0,
            }
        end
    end
    print(('[apoc_camas] %d camas cargadas'):format(#rows))
    TriggerClientEvent('apoc_camas:client:setBeds', -1, AllPublicBeds())
end)

QBCore.Functions.CreateCallback('apoc_camas:server:getBeds', function(source, cb)
    cb(AllPublicBeds())
end)

-- =====================================================================
--  Objetos
-- =====================================================================
local function RegisterItems()
    if not Config.AutoRegisterItems then return end
    local missing = {}
    for _, bed in ipairs(Config.Beds) do
        if not QBCore.Shared.Items[bed.item] then
            local ok, added = pcall(function()
                return exports['qb-core']:AddItem(bed.item, {
                    name = bed.item, label = bed.label, weight = bed.weight or 3000, type = 'item',
                    image = bed.item .. '.png', unique = false, useable = true, shouldClose = true,
                    description = bed.description,
                })
            end)
            if not ok or not added then missing[#missing + 1] = bed.item end
        end
    end
    if #missing > 0 then
        print(('[apoc_camas] No se pudieron registrar automáticamente: %s. Añádelos a qb-core/shared/items.lua (ver README).'):format(table.concat(missing, ', ')))
    end
    QBCore = exports['qb-core']:GetCoreObject() -- recarga la lista de objetos
end
RegisterItems()

for _, bed in ipairs(Config.Beds) do
    QBCore.Functions.CreateUseableItem(bed.item, function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if #GetPlayerBeds(Player.PlayerData.citizenid) >= Config.MaxBeds then
            return Notify(source, ('Ya tienes %d camas colocadas. Recoge alguna antes.'):format(Config.MaxBeds), 'error')
        end
        TriggerClientEvent('apoc_camas:client:startPlacement', source, bed.item)
    end)
end

-- =====================================================================
--  Colocar, recoger y destruir
-- =====================================================================
local function CheckPlacement(src, citizenid, coords)
    local playerCoords = GetPlayerCoords(src)
    if not playerCoords or #(playerCoords - coords) > Config.Placement.MaxDistance + 3.0 then
        return 'Estás demasiado lejos de ese sitio.'
    end
    if #GetPlayerBeds(citizenid) >= Config.MaxBeds then
        return ('Ya tienes %d camas colocadas.'):format(Config.MaxBeds)
    end
    for _, bed in pairs(Beds) do
        if #(bed.coords - coords) < Config.Placement.MinDistanceBetweenBeds then
            return 'Hay otra cama demasiado cerca.'
        end
    end
    for _, zone in ipairs(Config.Placement.BlockedZones) do
        if Dist2D(coords, zone.coords) <= zone.radius then
            return ('No puedes poner camas en %s.'):format(zone.label or 'esta zona')
        end
    end
    return nil
end

RegisterNetEvent('apoc_camas:server:placeBed', function(item, coords, heading)
    local src = source
    local cfg = BedTypes[item]
    local Player = QBCore.Functions.GetPlayer(src)
    if not cfg or not Player or type(coords) ~= 'vector3' or type(heading) ~= 'number' or Busy[src] then return end
    local citizenid = Player.PlayerData.citizenid

    local problem = CheckPlacement(src, citizenid, coords)
    if problem then return Notify(src, problem, 'error') end
    if InvGetAmount(Player, src, item) < 1 or not InvRemoveItem(Player, src, item, 1) then
        return Notify(src, ('No tienes: %s'):format(cfg.label), 'error')
    end
    ItemBox(src, item, 'remove', 1)

    Busy[src] = true
    local label = ('%s #%d'):format(cfg.label, #GetPlayerBeds(citizenid) + 1)
    local id = MySQL.insert.await('INSERT INTO `apoc_camas` (citizenid, item, label, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenid, item, label, coords.x, coords.y, coords.z, heading,
    })
    Busy[src] = nil
    if not id then
        InvAddItem(Player, src, item, 1)
        return Notify(src, 'No se pudo guardar la cama. Inténtalo de nuevo.', 'error')
    end

    local bed = { id = id, citizenid = citizenid, item = item, label = label, coords = coords, heading = heading + 0.0 }
    Beds[id] = bed
    TriggerClientEvent('apoc_camas:client:bedAdded', -1, PublicBed(bed))
    Notify(src, ('%s colocada. Podrás despertar aquí al entrar al servidor.'):format(label), 'success', 7000)
end)

local function RemoveBed(id)
    Beds[id] = nil
    MySQL.query.await('DELETE FROM `apoc_camas` WHERE `id` = ?', { id })
    TriggerClientEvent('apoc_camas:client:bedRemoved', -1, id)
end

RegisterNetEvent('apoc_camas:server:pickupBed', function(id)
    local src = source
    local bed = Beds[id]
    local Player = QBCore.Functions.GetPlayer(src)
    if not bed or not Player or Busy[src] then return end
    if bed.citizenid ~= Player.PlayerData.citizenid then return Notify(src, 'Esta cama no es tuya.', 'error') end
    local coords = GetPlayerCoords(src)
    if not coords or #(coords - bed.coords) > 4.0 then return end

    if not InvAddItem(Player, src, bed.item, 1) then
        return Notify(src, 'No tienes espacio en el inventario.', 'error')
    end
    ItemBox(src, bed.item, 'add', 1)
    Busy[src] = true
    RemoveBed(id)
    Busy[src] = nil
    Notify(src, ('Has recogido %s.'):format(bed.label), 'success')
end)

RegisterNetEvent('apoc_camas:server:destroyBed', function(id)
    local src = source
    local bed = Beds[id]
    local Player = QBCore.Functions.GetPlayer(src)
    if not Config.AllowDestroy or not bed or not Player or Busy[src] then return end
    if bed.citizenid == Player.PlayerData.citizenid then return end
    local coords = GetPlayerCoords(src)
    if not coords or #(coords - bed.coords) > 4.0 then return end

    Busy[src] = true
    RemoveBed(id)
    Busy[src] = nil
    Notify(src, 'Has destruido la cama.', 'success')
    local Owner = QBCore.Functions.GetPlayerByCitizenId(bed.citizenid)
    if Owner then Notify(Owner.PlayerData.source, ('Alguien ha destruido tu %s.'):format(bed.label), 'error', 10000) end
end)

-- =====================================================================
--  Fabricación
-- =====================================================================
RegisterNetEvent('apoc_camas:server:craft', function(item)
    local src = source
    local cfg = BedTypes[item]
    local Player = QBCore.Functions.GetPlayer(src)
    if not Config.Crafting.enabled or not cfg or not Player or Busy[src] then return end
    local coords = GetPlayerCoords(src)
    if not coords or Dist2D(coords, Config.Crafting.coords) > 5.0 then return end

    for _, mat in ipairs(cfg.recipe) do
        if InvGetAmount(Player, src, mat[1]) < mat[2] then
            local shared = QBCore.Shared.Items[mat[1]]
            return Notify(src, ('Te falta: %s x%d'):format(shared and shared.label or mat[1], mat[2]), 'error')
        end
    end

    Busy[src] = true
    local removed = {}
    for _, mat in ipairs(cfg.recipe) do
        if not InvRemoveItem(Player, src, mat[1], mat[2]) then
            for _, back in ipairs(removed) do InvAddItem(Player, src, back[1], back[2]) end
            Busy[src] = nil
            return Notify(src, 'No se pudieron usar los materiales.', 'error')
        end
        removed[#removed + 1] = mat
        ItemBox(src, mat[1], 'remove', mat[2])
    end
    if not InvAddItem(Player, src, item, 1) then
        for _, back in ipairs(removed) do InvAddItem(Player, src, back[1], back[2]) end
        Busy[src] = nil
        return Notify(src, 'No tienes espacio para la cama. Se te devuelven los materiales.', 'error')
    end
    Busy[src] = nil
    ItemBox(src, item, 'add', 1)
    Notify(src, ('Has fabricado: %s'):format(cfg.label), 'success')
end)

AddEventHandler('playerDropped', function()
    Busy[source] = nil
end)
