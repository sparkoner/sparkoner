local QBCore = exports['qb-core']:GetCoreObject()

Groups = {}

local groups = {}       -- [groupId] = { id, leader, members = { src, ... } }
local playerGroup = {}  -- [src] = groupId
local invites = {}      -- [src] = { group, from, expires }
local nextGroupId = 0

local function Notify(src, msg, kind, length)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', length or 5000)
end

function GetCharName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local info = Player.PlayerData.charinfo
        return ('%s %s'):format(info.firstname, info.lastname)
    end
    return GetPlayerName(src) or ('ID %s'):format(src)
end

local function Broadcast(group, msg, kind)
    for _, member in ipairs(group.members) do Notify(member, msg, kind) end
end

local function RemoveMember(group, src)
    for i, member in ipairs(group.members) do
        if member == src then
            table.remove(group.members, i)
            break
        end
    end
    playerGroup[src] = nil
    if #group.members == 0 then
        groups[group.id] = nil
        return
    end
    if group.leader == src then
        group.leader = group.members[1]
        Broadcast(group, ('%s es ahora el líder del grupo.'):format(GetCharName(group.leader)), 'primary')
    end
end

function Groups.Get(src)
    local id = playerGroup[src]
    return id and groups[id] or nil
end

function Groups.GetMembers(src)
    local group = Groups.Get(src)
    if not group then return { src } end
    return group.members
end

function Groups.Create(src)
    if playerGroup[src] then return Notify(src, 'Ya estás en un grupo.', 'error') end
    nextGroupId = nextGroupId + 1
    groups[nextGroupId] = { id = nextGroupId, leader = src, members = { src } }
    playerGroup[src] = nextGroupId
    Notify(src, 'Grupo creado. Invita a otros con /grupo invitar [id].', 'success')
end

function Groups.Invite(src, target)
    if not playerGroup[src] then Groups.Create(src) end
    local group = Groups.Get(src)
    if group.leader ~= src then return Notify(src, 'Solo el líder puede invitar.', 'error') end
    target = tonumber(target)
    if not target or not QBCore.Functions.GetPlayer(target) then return Notify(src, 'Jugador no encontrado.', 'error') end
    if target == src then return Notify(src, 'No puedes invitarte a ti mismo.', 'error') end
    if playerGroup[target] then return Notify(src, 'Ese jugador ya está en un grupo.', 'error') end
    if #group.members >= Config.Group.MaxMembers then return Notify(src, 'El grupo está lleno.', 'error') end

    invites[target] = { group = group.id, from = src, expires = os.time() + Config.Group.InviteTimeout }
    Notify(src, ('Invitación enviada a %s.'):format(GetCharName(target)), 'success')
    Notify(target, ('%s te invita a su grupo. Usa /grupo aceptar o /grupo rechazar.'):format(GetCharName(src)), 'primary', 10000)
end

function Groups.Accept(src)
    local invite = invites[src]
    invites[src] = nil
    if not invite or invite.expires < os.time() then return Notify(src, 'No tienes invitaciones pendientes.', 'error') end
    if playerGroup[src] then return Notify(src, 'Ya estás en un grupo.', 'error') end
    local group = groups[invite.group]
    if not group then return Notify(src, 'Ese grupo ya no existe.', 'error') end
    if #group.members >= Config.Group.MaxMembers then return Notify(src, 'El grupo está lleno.', 'error') end

    group.members[#group.members + 1] = src
    playerGroup[src] = group.id
    Broadcast(group, ('%s se ha unido al grupo.'):format(GetCharName(src)), 'success')
end

function Groups.Decline(src)
    local invite = invites[src]
    invites[src] = nil
    if not invite then return Notify(src, 'No tienes invitaciones pendientes.', 'error') end
    Notify(src, 'Invitación rechazada.', 'primary')
    Notify(invite.from, ('%s ha rechazado tu invitación.'):format(GetCharName(src)), 'error')
end

function Groups.Leave(src)
    local group = Groups.Get(src)
    if not group then return Notify(src, 'No estás en ningún grupo.', 'error') end
    RemoveMember(group, src)
    Notify(src, 'Has salido del grupo.', 'primary')
    if groups[group.id] then Broadcast(group, ('%s ha salido del grupo.'):format(GetCharName(src)), 'error') end
end

function Groups.Kick(src, target)
    local group = Groups.Get(src)
    if not group then return Notify(src, 'No estás en ningún grupo.', 'error') end
    if group.leader ~= src then return Notify(src, 'Solo el líder puede expulsar.', 'error') end
    target = tonumber(target)
    if not target or target == src or playerGroup[target] ~= group.id then
        return Notify(src, 'Ese jugador no está en tu grupo.', 'error')
    end
    RemoveMember(group, target)
    Notify(target, 'Te han expulsado del grupo.', 'error')
    Broadcast(group, ('%s ha sido expulsado del grupo.'):format(GetCharName(target)), 'primary')
end

function Groups.Info(src)
    local group = Groups.Get(src)
    if not group then return Notify(src, 'No estás en ningún grupo. Crea uno con /grupo crear.', 'primary') end
    local names = {}
    for _, member in ipairs(group.members) do
        names[#names + 1] = ('%s [%s]%s'):format(GetCharName(member), member, member == group.leader and ' (líder)' or '')
    end
    Notify(src, ('Grupo (%d/%d): %s'):format(#group.members, Config.Group.MaxMembers, table.concat(names, ', ')), 'primary', 10000)
end

function Groups.OnDrop(src)
    invites[src] = nil
    local group = Groups.Get(src)
    if not group then return end
    RemoveMember(group, src)
    if groups[group.id] then Broadcast(group, ('%s se ha desconectado y sale del grupo.'):format(GetCharName(src)), 'error') end
end

QBCore.Commands.Add('grupo', 'Gestiona tu grupo de supervivientes', {
    { name = 'accion', help = 'crear | invitar | aceptar | rechazar | salir | expulsar | info' },
    { name = 'id', help = 'ID del jugador (solo para invitar / expulsar)' },
}, false, function(source, args)
    local action = (args[1] or 'info'):lower()
    if action == 'crear' then
        Groups.Create(source)
    elseif action == 'invitar' then
        Groups.Invite(source, args[2])
    elseif action == 'aceptar' then
        Groups.Accept(source)
    elseif action == 'rechazar' then
        Groups.Decline(source)
    elseif action == 'salir' then
        Groups.Leave(source)
    elseif action == 'expulsar' then
        Groups.Kick(source, args[2])
    elseif action == 'info' then
        Groups.Info(source)
    else
        Notify(source, 'Uso: /grupo crear | invitar [id] | aceptar | rechazar | salir | expulsar [id] | info', 'error', 8000)
    end
end)

exports('GetGroupMembers', Groups.GetMembers)
