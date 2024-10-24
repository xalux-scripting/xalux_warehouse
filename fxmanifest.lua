fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xalux'
description 'Warehouse System'
version '1.0.0'

-- Required dependencies (oxmysql, ox_lib, ox_target)
dependencies {
    'ox_lib',  
    'ox_target',
    'oxmysql' 
}


shared_scripts {
    '@ox_lib/init.lua', 
    'config.lua',       


}

client_scripts {
    'cl.lua',       
}

-- Server scripts
server_scripts {
    '@mysql-async/lib/MySQL.lua', 
    'sv.lua',                
}
