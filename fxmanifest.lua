fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'AGC'
description 'Persistent graffiti: QBCore / Qbox / ESX'
version '1.3.0'
shared_scripts {'config.lua'}
client_scripts {'client/main.lua'}
server_scripts {'@oxmysql/lib/MySQL.lua','server/bridge.lua','server/main.lua'}
ui_page 'html/index.html'
files {'html/index.html','html/app.js','html/style.css','html/texture.html'}
dependency 'oxmysql'
