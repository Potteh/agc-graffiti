fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'AGC'
description 'Persistent wall graffiti for QBCore'
version '1.0.0'
shared_scripts {'config.lua'}
client_scripts {'client/main.lua'}
server_scripts {'@oxmysql/lib/MySQL.lua','server/main.lua'}
ui_page 'html/index.html'
files {'html/index.html','html/app.js','html/style.css','html/texture.html'}
dependency 'qb-core'
dependency 'qb-target'
dependency 'oxmysql'
