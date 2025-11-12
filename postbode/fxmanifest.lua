fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'postbode'
author 'Rube Minnen'
description 'speel als een postbode'
version '1.3.2'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target'
}
