fx_version 'cerulean'
game 'gta5'

author 'NCHub Development'
description 'Advanced AntiCheat System for QBCore FiveM Servers'
version '1.0.0'

lua54 'yes'

-- Dependencies
dependencies {
    'qb-core',
    'oxmysql',
    'screenshot-basic'
}

-- Shared files
shared_scripts {
    'configs/anticheat_config.lua'
}

-- Server files
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'utils/logger.lua',
    'server/anticheat_server.lua',
    'server/anticheat_txadmin.lua',
    'setup.lua'
}

-- Client files
client_scripts {
    'client/anticheat_client.lua'
}

-- Optional UI files (uncomment if implementing web UI)
-- ui_page 'html/index.html'
-- files {
--     'html/index.html',
--     'html/script.js',
--     'html/style.css'
-- }

-- Export functions for other resources
exports {
    'isCheater',
    'isPlayerWhitelisted',
    'banPlayer',
    'unbanPlayer',
    'logDetection'
}

server_exports {
    'isCheater',
    'isPlayerWhitelisted',
    'banPlayer',
    'unbanPlayer',
    'logDetection',
    'getPlayerDetections',
    'getBanInfo'
}

-- Provide essential system info
provide 'anticheat'