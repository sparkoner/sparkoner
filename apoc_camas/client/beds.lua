local QBCore = exports['qb-core']:GetCoreObject()

ClientBeds = {}  -- [id] = { id, item, label, coords, heading, owner, obj }
BedTypes = {}
for _, bed in ipairs(Config.Beds) do BedTypes[bed.item] = bed end

local myCitizenId = nil
local placing = false

local function RefreshCitizenId()
    local data = QBCore.Functions.GetPlayerData()
    myCitizenId = data and data.citizenid or nil
end

-- =====================================================================
--  Camas en el mundo (objetos locales que se crean al acercarse)
-- =====================================================================
local function UpdateInteraction(bed)
    local id = 'bed:' .. bed.id
    Interact.Remove(id)
    if not bed.obj then return end
    if myCitizenId and bed.owner == myCitizenId then
        Interact.Add(id, {
            coords = bed.coords, distance = 2.2, label = ('Recoger %s'):format(bed.label),
            onUse = function()
                Interact.Progress('Recogiendo la cama...', Config.PickupTime, { scenario = 'CODE_HUMAN_MEDIC_KNEEL' }, function()
                    TriggerServerEvent('apoc_camas:server:pickupBed', bed.id)
                end)
            end,
        })
    elseif Config.AllowDestroy then
        Interact.Add(id, {
            coords = bed.coords, distance = 2.2, label = 'Destruir cama',
            onUse = function()
                Interact.Progress('Destrozando la cama...', Config.DestroyTime, { scenario = 'WORLD_HUMAN_HAMMERING' }, function()
                    TriggerServerEvent('apoc_camas:server:destroyBed', bed.id)
                end)
            end,
        })
    end
end

local function SpawnBedObject(bed)
    if bed.obj or bed.loading then return end
    local cfg = BedTypes[bed.item]
    if not cfg then return end
    bed.loading = true
    local hash = LoadModel(cfg.model)
    bed.loading = false
    if not hash or not ClientBeds[bed.id] or bed.obj then return end
    local obj = CreateObjectNoOffset(hash, bed.coords.x, bed.coords.y, bed.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(obj, bed.heading)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    bed.obj = obj
    UpdateInteraction(bed)
end

local function DespawnBedObject(bed)
    if bed.obj and DoesEntityExist(bed.obj) then DeleteEntity(bed.obj) end
    bed.obj = nil
    Interact.Remove('bed:' .. bed.id)
end

function EnsureBedObject(id)
    local bed = ClientBeds[id]
    if bed then SpawnBedObject(bed) end
end

local function AddBed(data)
    local old = ClientBeds[data.id]
    if old then DespawnBedObject(old) end
    ClientBeds[data.id] = data
end

RegisterNetEvent('apoc_camas:client:setBeds', function(list)
    for _, bed in pairs(ClientBeds) do DespawnBedObject(bed) end
    ClientBeds = {}
    for _, bed in ipairs(list) do AddBed(bed) end
end)

RegisterNetEvent('apoc_camas:client:bedAdded', function(bed)
    AddBed(bed)
end)

RegisterNetEvent('apoc_camas:client:bedRemoved', function(id)
    local bed = ClientBeds[id]
    if bed then DespawnBedObject(bed) end
    ClientBeds[id] = nil
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    RefreshCitizenId()
    for _, bed in pairs(ClientBeds) do UpdateInteraction(bed) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    myCitizenId = nil
    for _, bed in pairs(ClientBeds) do UpdateInteraction(bed) end
end)

CreateThread(function()
    RefreshCitizenId()
    QBCore.Functions.TriggerCallback('apoc_camas:server:getBeds', function(list)
        for _, bed in ipairs(list or {}) do AddBed(bed) end
    end)
    while true do
        -- Se usa la posición de la cámara para que también se vean en la vista previa del selector
        local camCoords = GetFinalRenderedCamCoord()
        for _, bed in pairs(ClientBeds) do
            local dist = #(camCoords - bed.coords)
            if dist < Config.RenderDistance then
                SpawnBedObject(bed)
            elseif dist > Config.RenderDistance + 20.0 and bed.obj then
                DespawnBedObject(bed)
            end
        end
        Wait(1000)
    end
end)

-- =====================================================================
--  Colocación con vista previa (fantasma)
-- =====================================================================
local function RotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function RaycastFromCamera(distance)
    local origin = GetGameplayCamCoord()
    local dest = origin + RotationToDirection(GetGameplayCamRot(2)) * distance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, dest.x, dest.y, dest.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, endCoords, surfaceNormal = GetShapeTestResult(ray)
    return hit == 1 or hit == true, endCoords, surfaceNormal
end

local function PlacementProblem(coords, normal)
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - coords) > Config.Placement.MaxDistance then return 'Demasiado lejos' end
    if normal.z < Config.Placement.MinFlatness then return 'El suelo está demasiado inclinado' end
    local inWater, waterHeight = GetWaterHeight(coords.x, coords.y, coords.z)
    if inWater and waterHeight > coords.z - 0.2 then return 'No puedes ponerla en el agua' end
    for _, bed in pairs(ClientBeds) do
        if #(bed.coords - coords) < Config.Placement.MinDistanceBetweenBeds then return 'Hay otra cama demasiado cerca' end
    end
    for _, zone in ipairs(Config.Placement.BlockedZones) do
        local dx, dy = coords.x - zone.coords.x, coords.y - zone.coords.y
        if math.sqrt(dx * dx + dy * dy) <= zone.radius then return ('No se permiten camas en %s'):format(zone.label or 'esta zona') end
    end
    return nil
end

local function DisablePlacementControls()
    for _, control in ipairs({ 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 257, 263 }) do
        DisableControlAction(0, control, true)
    end
end

RegisterNetEvent('apoc_camas:client:startPlacement', function(item)
    local cfg = BedTypes[item]
    local ped = PlayerPedId()
    if placing or not cfg or Interact.IsBusy() then return end
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
        return QBCore.Functions.Notify('No puedes colocar una cama ahora.', 'error')
    end
    local hash = LoadModel(cfg.model)
    if not hash then return QBCore.Functions.Notify('Este modelo de cama no está disponible.', 'error') end

    placing = true
    local pedCoords = GetEntityCoords(ped)
    local ghost = CreateObjectNoOffset(hash, pedCoords.x, pedCoords.y, pedCoords.z - 5.0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ghost, false, false)
    SetEntityAlpha(ghost, 190, false)
    FreezeEntityPosition(ghost, true)
    SetEntityDrawOutline(ghost, true)
    SetEntityDrawOutlineShader(1)

    local heading = GetEntityHeading(ped)
    local shownText = nil
    local function ShowText(text)
        if text ~= shownText then
            exports['qb-core']:DrawText(text, 'left')
            shownText = text
        end
    end

    CreateThread(function()
        while placing do
            DisablePlacementControls()
            if IsDisabledControlJustPressed(0, 14) then heading = heading - Config.Placement.RotateStep end
            if IsDisabledControlJustPressed(0, 15) then heading = heading + Config.Placement.RotateStep end
            if IsControlPressed(0, 174) then heading = heading + 1.5 end
            if IsControlPressed(0, 175) then heading = heading - 1.5 end

            local hit, coords, normal = RaycastFromCamera(Config.Placement.MaxDistance + 4.0)
            local problem = 'Apunta al suelo'
            if hit then
                SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z, false, false, false)
                SetEntityHeading(ghost, heading)
                PlaceObjectOnGroundProperly(ghost)
                SetEntityVisible(ghost, true, false)
                problem = PlacementProblem(GetEntityCoords(ghost), normal)
            else
                SetEntityVisible(ghost, false, false)
            end

            if problem then
                SetEntityDrawOutlineColor(220, 60, 50, 255)
                ShowText(('~r~%s~s~ | [Rueda] Girar | [Retroceso] Cancelar'):format(problem))
            else
                SetEntityDrawOutlineColor(90, 220, 90, 255)
                ShowText('[E] Colocar | [Rueda] Girar | [Retroceso] Cancelar')
            end

            if IsControlJustReleased(0, 38) and not problem then
                local final, finalHeading = GetEntityCoords(ghost), GetEntityHeading(ghost)
                placing = false
                DeleteEntity(ghost)
                exports['qb-core']:HideText()
                Interact.Progress(('Colocando %s...'):format(cfg.label), Config.PlaceTime, { scenario = 'CODE_HUMAN_MEDIC_KNEEL' }, function()
                    TriggerServerEvent('apoc_camas:server:placeBed', item, final, finalHeading)
                end)
                return
            end
            if IsControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 25) or IsEntityDead(PlayerPedId()) then
                placing = false
            end
            Wait(0)
        end
        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        exports['qb-core']:HideText()
    end)
end)

-- =====================================================================
--  /vercamas: muestra los 10 modelos reales en fila delante del jugador
-- =====================================================================
local showroom = {}
local showroomToken = 0

local function ClearShowroom()
    for _, item in ipairs(showroom) do
        if DoesEntityExist(item.obj) then DeleteEntity(item.obj) end
    end
    showroom = {}
end

local function DrawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('apoc_camas:client:showroom', function()
    ClearShowroom()
    showroomToken = showroomToken + 1
    local token = showroomToken
    local ped = PlayerPedId()
    local spacing = 3.5
    for i, cfg in ipairs(Config.Beds) do
        local offset = (i - (#Config.Beds + 1) / 2) * spacing
        local pos = GetOffsetFromEntityInWorldCoords(ped, offset, 6.0, 0.0)
        local hash = LoadModel(cfg.model)
        if hash then
            local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            SetEntityHeading(obj, GetEntityHeading(ped) + 90.0)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            showroom[#showroom + 1] = { obj = obj, text = ('~y~%d. %s~s~~n~%s'):format(i, cfg.label, cfg.model) }
        end
    end
    QBCore.Functions.Notify('Estos son los 10 modelos de cama. Desaparecen en 60 segundos.', 'primary', 8000)
    local endsAt = GetGameTimer() + 60000
    while GetGameTimer() < endsAt and token == showroomToken and #showroom > 0 do
        for _, item in ipairs(showroom) do
            local c = GetEntityCoords(item.obj)
            DrawText3D(vector3(c.x, c.y, c.z + 1.4), item.text)
        end
        Wait(0)
    end
    if token == showroomToken then ClearShowroom() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    placing = false
    ClearShowroom()
    for _, bed in pairs(ClientBeds) do DespawnBedObject(bed) end
end)
