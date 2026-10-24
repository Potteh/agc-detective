fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'agc-detective'
author 'AGC'
description 'Cross-framework persistent forensic investigation system'
version '0.2.2'
shared_scripts {'shared/config.lua'}
client_scripts {'client/main.lua'}
server_scripts {'@oxmysql/lib/MySQL.lua','server/main.lua'}
ui_page 'html/index.html'
files {'html/index.html','html/style.css','html/app.js','sql/install.sql'}
dependency 'oxmysql'
