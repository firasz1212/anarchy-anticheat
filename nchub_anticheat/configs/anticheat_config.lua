-- ██████╗ ███╗   ██╗████████╗██╗     ██████╗██╗  ██╗███████╗ █████╗ ████████╗
-- ██╔══██╗████╗  ██║╚══██╔══╝██║    ██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝
-- ███████║██╔██╗ ██║   ██║   ██║    ██║     ███████║█████╗  ███████║   ██║   
-- ██╔══██║██║╚██╗██║   ██║   ██║    ██║     ██╔══██║██╔══╝  ██╔══██║   ██║   
-- ██║  ██║██║ ╚████║   ██║   ██║    ╚██████╗██║  ██║███████╗██║  ██║   ██║   
-- ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   
--
-- NCHub AntiCheat Configuration File
-- Version: 1.0.0
-- Framework: QBCore
-- Author: NCHub Development Team

Config = {}
Config.Debug = false -- Enable debug prints

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                CORE SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Framework = 'qb-core' -- qb-core, esx, standalone
Config.ResourceName = 'nchub_anticheat'
Config.ServerName = 'Your Server Name'
Config.ServerId = '1' -- Unique server identifier for multi-server setups

-- Database Settings
Config.Database = {
    useMySQL = true,
    logsTable = 'anticheat_logs',
    banTable = 'ban_table',
    whitelistTable = 'anticheat_whitelist',
    statisticsTable = 'anticheat_statistics'
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                PROTECTION MODULES
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Protections = {
    -- Basic Protection Settings
    antiLuaInjection = {
        enabled = true,
        banOnDetection = true,
        sensitivity = 2, -- 1=Low, 2=Medium, 3=High
        checkInterval = 5000, -- ms
    },
    
    antiModMenu = {
        enabled = true,
        banOnDetection = true,
        checkInterval = 10000, -- ms
        detectCommonMenus = true,
    },
    
    antiGodMode = {
        enabled = true,
        banOnDetection = false, -- Usually kicks first, bans on repeat
        checkInterval = 8000,
        maxHealth = 200,
        maxArmor = 100,
    },
    
    antiSpeedHack = {
        enabled = true,
        banOnDetection = false,
        maxSpeed = 500.0, -- Maximum allowed speed
        checkInterval = 3000,
    },
    
    antiTeleport = {
        enabled = true,
        banOnDetection = false,
        maxDistance = 500.0, -- Max distance before flagging
        checkInterval = 5000,
        exemptVehicles = true, -- Allow vehicle teleportation
    },
    
    antiNoclip = {
        enabled = true,
        banOnDetection = true,
        checkInterval = 4000,
    },
    
    antiInvisible = {
        enabled = true,
        banOnDetection = false,
        checkInterval = 6000,
    },
    
    antiExplosiveAmmo = {
        enabled = true,
        banOnDetection = true,
        checkAllWeapons = true,
    },
    
    entityProtection = {
        enabled = true,
        banOnDetection = true,
        maxEntitiesPerPlayer = 50,
        maxSpawnRate = 5, -- entities per second
        checkInterval = 7000,
    },
    
    weaponProtection = {
        enabled = true,
        banOnDetection = true,
        checkInterval = 5000,
    },
    
    vehicleProtection = {
        enabled = true,
        banOnDetection = true,
        checkInterval = 8000,
    },
    
    eventProtection = {
        enabled = true,
        banOnDetection = true,
        maxEventsPerSecond = 10,
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADMIN SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Admins = {
    -- Permission Levels:
    -- 1 = Basic Admin (kick, view logs)
    -- 2 = Moderator (ban, unban, advanced logs)
    -- 3 = Senior Admin (whitelist management)
    -- 4 = Head Admin (config management)
    -- 5 = Super Admin (full access)
    
    ['license:your_license_here'] = { level = 5, name = 'Server Owner' },
    ['steam:110000000000000'] = { level = 4, name = 'Head Admin' },
    -- Add more admins here
}

Config.AdminCommands = {
    mainCommand = 'ncheat',
    banCommand = 'banid',
    kickCommand = 'kickid',
    unbanCommand = 'unbanid',
    logsCommand = 'logs',
    whitelistCommand = 'acwhitelist',
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                BLACKLISTS
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.BlacklistData = {
    -- Blacklisted Weapons
    weapons = {
        'WEAPON_RAILGUN',
        'WEAPON_MINIGUN',
        'WEAPON_RPG',
        'WEAPON_HOMINGLAUNCHER',
        'WEAPON_GRENADE',
        'WEAPON_STICKYBOMB',
        'WEAPON_PROXMINE',
        'WEAPON_BZGAS',
        'WEAPON_MOLOTOV',
        'WEAPON_FIREEXTINGUISHER',
        'WEAPON_PETROLCAN',
        'WEAPON_DIGISCANNER',
        'WEAPON_BRIEFCASE',
        'WEAPON_BRIEFCASE_02',
        'WEAPON_GARBAGEBAG',
        'WEAPON_HANDCUFFS',
        'WEAPON_BALL',
        'WEAPON_FLARE',
        'WEAPON_VEHICLE_ROCKET',
        'WEAPON_AIRSTRIKE_ROCKET',
        'WEAPON_BIRD_CRAP',
        'WEAPON_PASSENGER_ROCKET',
        'WEAPON_AIR_DEFENCE_GUN',
    },
    
    -- Blacklisted Vehicles
    vehicles = {
        'RHINO', -- Tank
        'LAZER', -- Fighter Jet
        'HYDRA', -- Military Jet
        'SAVAGE', -- Attack Helicopter
        'HUNTER', -- Military Helicopter
        'AKULA', -- Stealth Helicopter
        'BARRAGE', -- APC
        'CHERNOBOG', -- Missile Launcher
        'KHANJALI', -- Tank
        'STROMBERG', -- Submarine Car
        'DELUXO', -- Flying Car
        'OPPRESSOR', -- Flying Motorcycle
        'OPPRESSOR2', -- Flying Motorcycle MK2
        'THRUSTER', -- Jetpack
        'ORBITAL_CANNON',
        'KOSATKA', -- Submarine
        'TOREADOR', -- Submarine Car
    },
    
    -- Blacklisted Objects/Props
    objects = {
        'prop_dummy_01',
        'prop_ramp_multi_loop_01',
        'stt_prop_stunt_soccer_ball',
        'stt_prop_stunt_landing_zone_01',
        'prop_jetski_ramp_01',
        'prop_dock_rtg_ld',
        'prop_fnclink_05crnr1',
        'prop_container_05a',
        'prop_container_01a',
        'prop_mb_cargo_04a',
        'prop_ice_box_01',
        'prop_gold_cont_01',
        'prop_barrier_work05',
        'prop_mp_barrier_02b',
        'prop_ld_ferris_wheel',
        'prop_staticmixer_01',
        'prop_towercrane_02a',
    },
    
    -- Blacklisted Peds/Models
    peds = {
        's_m_y_sheriff_01',
        's_m_y_cop_01', 
        's_f_y_sheriff_01',
        's_f_y_cop_01',
        's_m_y_hwaycop_01',
        's_m_y_policedog_01',
        's_m_m_security_01',
        's_m_y_armymech_01',
        's_m_y_blackops_01',
        's_m_y_blackops_02',
        's_m_y_blackops_03',
        's_m_y_marine_01',
        's_m_y_marine_02',
        's_m_y_marine_03',
        's_m_m_pilot_02',
        's_m_m_chemsec_01',
        'u_m_y_zombie_01',
        'a_m_m_acult_01',
        'ig_lamardavis_02',
        'player_zero',
        'player_one',
        'player_two',
        'mp_m_freemode_01',
        'mp_f_freemode_01',
    },
    
    -- Blacklisted Particles/Effects
    particles = {
        'scr_rcbarry1',
        'scr_rcbarry2', 
        'scr_rcpaul1',
        'scr_rcpaul2',
        'scr_rcpaul3',
        'scr_trevor1',
        'scr_trevor2',
        'scr_trevor3',
        'scr_franklin0',
        'scr_franklin1',
        'scr_franklin2',
        'scr_michael1',
        'scr_michael2',
        'core_snow',
        'des_fib_glass',
        'des_paper_trail',
        'des_debris_trail',
        'exp_grd_bzgas_smoke',
        'exp_extinguisher',
        'veh_exhaust_afterburner',
        'weap_xs_vehicle_weapons',
    },
    
    -- Forbidden Trigger Events
    events = {
        '__cfx_internal:*',
        'esx:*',
        'esx_*',
        'es:*',
        'bank:*',
        'atm:*',
        'gcPhone:*',
        'usa-characters:*',
        'lscustoms:*',
        'es_extended:*',
        'kashacters:*',
        'ply_customization:*',
        'usa_carshop:*',
        'vrp_slotmachine:*',
        'AdminMenu:*',
        'bank:deposit',
        'bank:withdraw',
        'bank:balance',
        'esx_vehicleshop:*',
        'esx_drugs:*',
        'esx_policejob:*',
        'esx_ambulancejob:*',
        'esx_mechanicjob:*',
        'esx_society:*',
        '__cfx_export:*',
        'qb-core:*',
        'QBCore:*',
        'qb-*',
        'police:*',
        'ambulance:*',
        'mechanic:*',
        '__resource:*',
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                LOGGING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Logging = {
    -- File Logging
    enableFileLogging = true,
    logFile = 'cheatLogs.json',
    maxLogFileSize = 50 * 1024 * 1024, -- 50MB
    
    -- Database Logging
    enableDatabaseLogging = true,
    
    -- Console Logging
    enableConsoleLogging = true,
    
    -- Discord Webhook Logging
    enableDiscordLogging = true,
    
    webhooks = {
        -- Main detections webhook
        detections = 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE',
        
        -- Ban notifications webhook  
        bans = 'https://discord.com/api/webhooks/YOUR_BAN_WEBHOOK_HERE',
        
        -- Admin actions webhook
        admin = 'https://discord.com/api/webhooks/YOUR_ADMIN_WEBHOOK_HERE',
        
        -- System alerts webhook
        system = 'https://discord.com/api/webhooks/YOUR_SYSTEM_WEBHOOK_HERE',
    },
    
    discordSettings = {
        username = 'NCHub AntiCheat',
        avatar = 'https://cdn.discordapp.com/attachments/000000000000000000/000000000000000000/anticheat_avatar.png',
        color = 16711680, -- Red color
        pingRole = '<@&YOUR_ADMIN_ROLE_ID>', -- Discord role to ping on detections
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                BAN SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.BanSystem = {
    defaultBanTime = 0, -- 0 = permanent, time in hours for temporary
    banMessage = 'You have been banned from this server.\nReason: %s\nAppeal at: discord.gg/yourserver',
    kickMessage = 'You have been kicked from this server.\nReason: %s',
    
    -- Auto-ban settings
    autoBanEnabled = true,
    autoBanThreshold = 3, -- Number of detections before auto-ban
    autoBanExcludeTypes = { -- Detection types that won't trigger auto-ban
        'SPEED_HACK',
        'TELEPORT',
        'INVISIBLE',
    },
    
    -- Ban appeal system
    enableBanAppeals = true,
    appealDiscord = 'discord.gg/yourserver',
    appealWebsite = 'https://yourserver.com/appeal',
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                SCREENSHOT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Screenshots = {
    enabled = true,
    onDetection = true,
    onBan = true,
    quality = 0.8, -- 0.1 to 1.0
    encoding = 'jpg', -- jpg, png, webp
    uploadToWebhook = true,
    saveLocal = false,
    webhookUrl = 'https://discord.com/api/webhooks/YOUR_SCREENSHOT_WEBHOOK_HERE',
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADVANCED SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Advanced = {
    -- Performance Settings
    maxChecksPerSecond = 10,
    enableResourceMonitoring = true,
    maxResourceUsage = 2.0, -- Max CPU usage in %
    
    -- OCR Detection (requires additional setup)
    enableOCR = false,
    ocrKeywords = {
        'cheat', 'hack', 'mod menu', 'trainer', 'inject',
        'bypass', 'exploit', 'aimbot', 'wallhack', 'esp',
        'speed hack', 'fly hack', 'god mode', 'infinite',
    },
    
    -- Machine Learning Detection (future feature)
    enableMLDetection = false,
    mlModelPath = 'models/anticheat_model.json',
    
    -- Network Protection
    enableNetworkProtection = true,
    maxNetworkEvents = 50, -- per second
    maxNetworkSize = 65536, -- bytes
    
    -- Memory Protection
    enableMemoryProtection = true,
    memoryCheckInterval = 30000, -- ms
    
    -- Hardware Detection
    enableHardwareFingerprinting = true,
    hardwareBanEnabled = false,
    
    -- Whitelist bypass for development
    developmentMode = false,
    devBypassIdentifiers = {
        'license:dev_license_here',
        'steam:dev_steam_here',
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                MESSAGES & TRANSLATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Messages = {
    -- Admin Messages
    noPermission = '^1[AntiCheat]^7 You do not have permission to use this command.',
    playerNotFound = '^1[AntiCheat]^7 Player not found.',
    playerBanned = '^2[AntiCheat]^7 Player %s has been banned. Reason: %s',
    playerKicked = '^3[AntiCheat]^7 Player %s has been kicked. Reason: %s',
    playerUnbanned = '^2[AntiCheat]^7 Player %s has been unbanned.',
    
    -- Detection Messages
    detectionLogged = '^3[AntiCheat]^7 Detection logged for %s: %s',
    suspiciousActivity = '^1[AntiCheat]^7 Suspicious activity detected: %s',
    
    -- System Messages
    systemStarted = '^2[AntiCheat]^7 System initialized successfully.',
    systemError = '^1[AntiCheat]^7 System error: %s',
    databaseError = '^1[AntiCheat]^7 Database connection failed.',
    configReloaded = '^2[AntiCheat]^7 Configuration reloaded.',
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EXEMPTIONS & WHITELIST
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Exemptions = {
    -- Jobs that are exempt from certain checks
    exemptJobs = {
        'police', 'ambulance', 'mechanic', 'admin'
    },
    
    -- Vehicles exempt from speed checks
    exemptVehicles = {
        'POLICEOLD1', 'POLICE', 'POLICE2', 'POLICE3', 'POLICE4',
        'AMBULANCE', 'FIRETRUK', 'PRANGER',
    },
    
    -- Locations where checks are less strict
    exemptZones = {
        { coords = vector3(-1038.75, -2745.8, 21.3), radius = 100.0 }, -- Airport
        { coords = vector3(1730.5, 3310.3, 41.2), radius = 50.0 }, -- Sandy Shores Airport
    },
    
    -- Times when checks are less strict (hours in 24h format)
    exemptHours = {}, -- e.g., {2, 3, 4, 5} for 2 AM to 5 AM
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                INTEGRATION SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════════════

Config.Integrations = {
    -- TxAdmin Integration
    txadmin = {
        enabled = true,
        reportToTxAdmin = true,
        txAdminActions = true,
    },
    
    -- QBCore Integration
    qbcore = {
        enabled = true,
        useQBNotify = true,
        useQBLogging = false,
    },
    
    -- Other AntiCheat Systems
    compatibility = {
        fiveguard = false,
        anticheese = false,
        rockstareditor = false,
    },
}