fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'apoc_misiones'
description 'Misiones apocalípticas para QBCore: jugables en solitario o en grupo'
version '1.1.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/interact.lua',
    'client/spawn.lua',
    'client/stages.lua',
    'client/main.lua',
}

server_scripts {
    'server/groups.lua',
    'server/main.lua',
    'server/stages.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
}
