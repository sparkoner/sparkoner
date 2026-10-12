fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'apoc_camas'
description 'Camas fabricables que sirven como punto de aparición, con selector y vista previa'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/interact.lua',
    'client/beds.lua',
    'client/crafting.lua',
    'client/spawn.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/spawn.lua',
}

dependencies {
    'qb-core',
    'qb-menu',
    'oxmysql',
}
