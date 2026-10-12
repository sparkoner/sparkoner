local QBCore = exports['qb-core']:GetCoreObject()

local selecting = false
local testMode = false
local options = {}
local cam = nil
local target = nil
local orbitAngle = 0.0
local previewToken = 0

local function LocationText(c)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local streetHash = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = streetHash and GetStreetNameFromHashKey(streetHash) or ''
    if street ~= '' and zone ~= 'NULL' then return ('%s, %s'):format(street, zone) end
    if zone ~= 'NULL' then return zone end
    return street
end

-- Posición de la cámara girando alrededor del punto, sin atravesar paredes
local function CameraPosition(point)
    local cfg = Config.Spawn.Camera
    local desired = vector3(point.x + math.cos(orbitAngle) * cfg.distance, point.y + math.sin(orbitAngle) * cfg.distance, point.z + cfg.height)
    local from = vector3(point.x, point.y, point.z + 1.0)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, desired.x, desired.y, desired.z, 1, 0, 7)
    local _, hit, hitCoords = GetShapeTestResult(ray)
    if hit == 1 or hit == true then
        local dir = desired - from
        local len = #dir
        local safe = math.max(1.2, #(hitCoords - from) - 0.4)
        if len > 0 then return from + dir / len * safe end
    end
    return desired
end

CreateThread(function()
    while true do
        if selecting and cam and target then
            orbitAngle = orbitAngle + math.rad(Config.Spawn.Camera.orbitSpeed)
            local pos = CameraPosition(target)
            SetCamCoord(cam, pos.x, pos.y, pos.z)
            PointCamAtCoord(cam, target.x, target.y, target.z + 0.3)
            DrawMarker(2, target.x, target.y, target.z + 1.4, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                0.35, 0.35, 0.35, 224, 160, 48, 200, true, true, 2, false, nil, nil, false)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function PreviewOption(index)
    local opt = options[index]
    if not opt then return end
    previewToken = previewToken + 1
    local token = previewToken
    local point = vector3(opt.coords.x, opt.coords.y, opt.coords.z)
    -- Si el punto está lejos se funde a negro mientras carga la zona
    local far = not target or #(point - target) > 60.0 or IsScreenFadedOut() or IsScreenFadingOut()
    if far then
        DoScreenFadeOut(200)
        while not IsScreenFadedOut() do Wait(0) end
    end
    if token ~= previewToken then return end

    target = point
    orbitAngle = math.rad(math.random(0, 359))
    SetFocusPosAndVel(point.x, point.y, point.z, 0.0, 0.0, 0.0)
    if far then
        NewLoadSceneStartSphere(point.x, point.y, point.z, 60.0, 0)
        local timeout = GetGameTimer() + 4000
        while not IsNewLoadSceneLoaded() and GetGameTimer() < timeout do Wait(0) end
        NewLoadSceneStop()
    end
    if opt.kind == 'bed' then EnsureBedObject(opt.id) end
    if token ~= previewToken then return end
    if far then DoScreenFadeIn(300) end
end

local function CleanupSelector()
    selecting = false
    target = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    ClearFocus()
end

local function FinishSpawn(coords, heading, isTest)
    CreateThread(function()
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        DoScreenFadeOut(400)
        while not IsScreenFadedOut() do Wait(0) end
        CleanupSelector()

        local ped = PlayerPedId()
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 1.0, false, false, false)
        SetEntityHeading(ped, heading or 0.0)
        local timeout = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)
            Wait(0)
        end
        local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
        SetEntityCoords(ped, coords.x, coords.y, found and groundZ or coords.z, false, false, false, false)
        SetEntityHeading(ped, heading or 0.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)

        if not isTest then
            -- Igual que qb-spawn: avisa al resto de scripts de que el personaje ha cargado
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            if GetResourceState('qb-houses') == 'started' then TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false) end
            if GetResourceState('qb-apartments') == 'started' then TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false) end
        end
        Wait(500)
        DoScreenFadeIn(800)
    end)
end

function OpenSelector(isTest)
    if selecting then return end
    selecting = true
    testMode = isTest == true

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    local p = promise.new()
    QBCore.Functions.TriggerCallback('apoc_camas:server:getSpawnOptions', function(result) p:resolve(result or {}) end)
    options = Citizen.Await(p)

    if #options == 0 then
        -- No hay nada que elegir (o el servidor lo ha denegado): aparece donde está
        selecting = false
        local coords = GetEntityCoords(ped)
        return FinishSpawn(coords, GetEntityHeading(ped), testMode)
    end

    local nui = {}
    local bedCount = 0
    for i, opt in ipairs(options) do
        if opt.kind == 'bed' then bedCount = bedCount + 1 end
        nui[i] = {
            kind = opt.kind, kindLabel = opt.kindLabel, label = opt.label,
            description = opt.description, image = opt.image, location = LocationText(opt.coords),
        }
    end

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 55.0)
    RenderScriptCams(true, false, 0, true, true)
    target = nil
    PreviewOption(1)

    SendNUIMessage({ action = 'open', options = nui, index = 1, beds = bedCount, maxBeds = Config.MaxBeds })
    SetNuiFocus(true, true)
end

RegisterNUICallback('select', function(data, cb)
    cb({})
    local index = tonumber(data.index)
    if selecting and index then PreviewOption(index) end
end)

RegisterNUICallback('spawn', function(data, cb)
    local opt = options[tonumber(data.index) or 0]
    if not selecting or not opt then return cb({ ok = false }) end
    QBCore.Functions.TriggerCallback('apoc_camas:server:requestSpawn', function(result)
        if not result then
            QBCore.Functions.Notify('No puedes aparecer ahí. Elige otro sitio.', 'error')
            return cb({ ok = false })
        end
        cb({ ok = true })
        FinishSpawn(result.coords, result.heading, result.test)
    end, opt.kind, opt.id)
end)

-- Sustituto de qb-spawn: qb-multicharacter lanza estos eventos al elegir personaje
RegisterNetEvent('qb-spawn:client:setupSpawns', function() end)

RegisterNetEvent('qb-spawn:client:openUI', function(value)
    if not Config.Spawn.ReplaceQbSpawn or not value then return end
    OpenSelector(false)
end)

RegisterNetEvent('apoc_camas:client:openSelector', function(isTest)
    OpenSelector(isTest)
end)

exports('OpenSpawnSelector', OpenSelector)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not selecting then return end
    CleanupSelector()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DoScreenFadeIn(0)
end)
