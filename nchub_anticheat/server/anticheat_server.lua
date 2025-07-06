-- ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ 
-- ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
-- ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
-- ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
-- ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
-- ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
--
-- NCHub AntiCheat Server
-- Version: 1.0.0
-- Author: NCHub Development Team

local QBCore = exports['qb-core']:GetCoreObject()
local Logger = require('utils.logger')

-- Global variables
local playerViolations = {}
local playerLastPositions = {}
local playerEntityCounts = {}
local bannedPlayers = {}
local whitelistedPlayers = {}
local eventRateLimits = {}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000) -- Wait for other resources to load
    
    print('^2[NCHub AntiCheat]^7 Initializing server components...')
    
    -- Load banned players from database
    LoadBannedPlayers()
    
    -- Load whitelisted players
    LoadWhitelistedPlayers()
    
    -- Start protection threads
    StartProtectionThreads()
    
    -- Initialize admin commands
    InitializeAdminCommands()
    
    -- Log system startup
    Logger.LogSystemAlert('AntiCheat system initialized successfully', {
        protections = Config.Protections,
        serverId = Config.ServerId,
        version = '1.0.0'
    }, 1)
    
    print('^2[NCHub AntiCheat]^7 System initialized successfully!')
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                DATABASE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function LoadBannedPlayers()
    if not Config.Database.useMySQL then return end
    
    MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.banTable .. ' WHERE is_active = 1', {}, function(result)
        bannedPlayers = {}
        if result then
            for _, ban in ipairs(result) do
                -- Check if temporary ban has expired
                if ban.ban_type == 'temporary' and ban.ban_expires then
                    local expireTime = os.time{
                        year = string.sub(ban.ban_expires, 1, 4),
                        month = string.sub(ban.ban_expires, 6, 7),
                        day = string.sub(ban.ban_expires, 9, 10),
                        hour = string.sub(ban.ban_expires, 12, 13),
                        min = string.sub(ban.ban_expires, 15, 16),
                        sec = string.sub(ban.ban_expires, 18, 19)
                    }
                    
                    if os.time() > expireTime then
                        -- Ban has expired, deactivate it
                        DeactivateBan(ban.id)
                        goto continue
                    end
                end
                
                bannedPlayers[ban.player_identifier] = ban
                ::continue::
            end
            
            if Config.Debug then
                print('[NCHub AntiCheat] Loaded ' .. #result .. ' banned players')
            end
        end
    end)
end

function LoadWhitelistedPlayers()
    if not Config.Database.useMySQL then return end
    
    MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.whitelistTable .. ' WHERE is_active = 1', {}, function(result)
        whitelistedPlayers = {}
        if result then
            for _, whitelist in ipairs(result) do
                whitelistedPlayers[whitelist.player_identifier] = whitelist
            end
            
            if Config.Debug then
                print('[NCHub AntiCheat] Loaded ' .. #result .. ' whitelisted players')
            end
        end
    end)
end

function DeactivateBan(banId)
    if not Config.Database.useMySQL then return end
    
    MySQL.Async.execute('UPDATE ' .. Config.Database.banTable .. ' SET is_active = 0 WHERE id = ?', { banId })
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                PLAYER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════════

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local primaryIdentifier = nil
    
    -- Get primary identifier (license)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            primaryIdentifier = id
            break
        end
    end
    
    -- Check if player is banned
    if primaryIdentifier and bannedPlayers[primaryIdentifier] then
        local ban = bannedPlayers[primaryIdentifier]
        local banMessage = string.format(Config.BanSystem.banMessage, ban.ban_reason)
        
        -- Log ban attempt
        Logger.LogDetection(src, 'BAN_EVASION', 'Banned player attempted to connect: ' .. ban.ban_reason, {
            banId = ban.id,
            banType = ban.ban_type,
            banDate = ban.ban_date,
            banExpires = ban.ban_expires
        }, 'blocked', 3)
        
        setKickReason(banMessage)
        CancelEvent()
        return
    end
    
    -- Initialize player data
    playerViolations[src] = 0
    playerLastPositions[src] = nil
    playerEntityCounts[src] = 0
    eventRateLimits[src] = {}
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    
    -- Clean up player data
    playerViolations[src] = nil
    playerLastPositions[src] = nil
    playerEntityCounts[src] = nil
    eventRateLimits[src] = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function GetPlayerPrimaryIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return nil
end

function IsPlayerWhitelisted(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    if not identifier then return false end
    
    -- Check config-based admins
    if Config.Admins[identifier] then
        return true
    end
    
    -- Check database whitelist
    if whitelistedPlayers[identifier] then
        return true
    end
    
    -- Check development mode
    if Config.Advanced.developmentMode then
        for _, devId in ipairs(Config.Advanced.devBypassIdentifiers) do
            if identifier == devId then
                return true
            end
        end
    end
    
    return false
end

function IsPlayerAdmin(src, requiredLevel)
    local identifier = GetPlayerPrimaryIdentifier(src)
    if not identifier then return false end
    
    requiredLevel = requiredLevel or 1
    
    -- Check config-based admins
    if Config.Admins[identifier] and Config.Admins[identifier].level >= requiredLevel then
        return true
    end
    
    -- Check database whitelist
    if whitelistedPlayers[identifier] and whitelistedPlayers[identifier].permission_level >= requiredLevel then
        return true
    end
    
    return false
end

function AddViolation(src, reason, details, severityLevel)
    if not src or IsPlayerWhitelisted(src) then return end
    
    playerViolations[src] = (playerViolations[src] or 0) + 1
    severityLevel = severityLevel or 1
    
    -- Log the detection
    Logger.LogDetection(src, 'VIOLATION', reason, details, 'logged', severityLevel)
    
    -- Check if auto-ban should trigger
    if Config.BanSystem.autoBanEnabled and playerViolations[src] >= Config.BanSystem.autoBanThreshold then
        BanPlayer(src, 'Automatic ban: Multiple violations (' .. playerViolations[src] .. ')', 'AntiCheat System')
    end
end

function TakeScreenshot(src, reason)
    if not Config.Screenshots.enabled then return end
    
    TriggerClientEvent('nchub_anticheat:takeScreenshot', src, reason)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                BAN SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

function BanPlayer(src, reason, bannedBy, banTime)
    local playerName = GetPlayerName(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    
    if not identifier then
        print('[NCHub AntiCheat] ERROR: Cannot ban player - no identifier found')
        return false
    end
    
    banTime = banTime or Config.BanSystem.defaultBanTime
    bannedBy = bannedBy or 'AntiCheat System'
    
    local banType = banTime == 0 and 'permanent' or 'temporary'
    local banExpires = banTime > 0 and os.date('%Y-%m-%d %H:%M:%S', os.time() + (banTime * 3600)) or nil
    
    -- Take screenshot if enabled
    if Config.Screenshots.onBan then
        TakeScreenshot(src, 'Player banned: ' .. reason)
    end
    
    -- Insert ban into database
    if Config.Database.useMySQL then
        local playerData = Logger.GetPlayerData(src)
        
        MySQL.Async.insert('INSERT INTO ' .. Config.Database.banTable .. ' (player_name, player_identifier, steam_id, discord_id, license, ip_address, ban_reason, ban_type, banned_by, ban_expires) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            playerName,
            identifier,
            playerData.steam,
            playerData.discord,
            playerData.license,
            playerData.ip,
            reason,
            banType,
            bannedBy,
            banExpires
        }, function(insertId)
            if insertId then
                -- Add to local banned players list
                bannedPlayers[identifier] = {
                    id = insertId,
                    player_name = playerName,
                    player_identifier = identifier,
                    ban_reason = reason,
                    ban_type = banType,
                    banned_by = bannedBy,
                    ban_expires = banExpires,
                    is_active = 1
                }
                
                if Config.Debug then
                    print('[NCHub AntiCheat] Player banned with ID: ' .. insertId)
                end
            end
        end)
    end
    
    -- Log the ban
    Logger.LogDetection(src, 'PLAYER_BANNED', reason, {
        banType = banType,
        banTime = banTime,
        bannedBy = bannedBy,
        banExpires = banExpires
    }, 'banned', 4)
    
    -- Kick the player
    DropPlayer(src, string.format(Config.BanSystem.banMessage, reason))
    
    return true
end

function UnbanPlayer(identifier, unbannedBy, reason)
    if not Config.Database.useMySQL then return false end
    
    MySQL.Async.execute('UPDATE ' .. Config.Database.banTable .. ' SET is_active = 0, unbanned_by = ?, unban_reason = ?, unban_date = NOW() WHERE player_identifier = ? AND is_active = 1', {
        unbannedBy or 'Console',
        reason or 'No reason provided',
        identifier
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Remove from local banned players list
            bannedPlayers[identifier] = nil
            
            -- Log the unban
            Logger.LogSystemAlert('Player unbanned: ' .. identifier, {
                unbannedBy = unbannedBy,
                reason = reason
            }, 2)
            
            if Config.Debug then
                print('[NCHub AntiCheat] Player unbanned: ' .. identifier)
            end
        end
    end)
    
    return true
end

function KickPlayer(src, reason, kickedBy)
    local playerName = GetPlayerName(src)
    
    -- Log the kick
    Logger.LogDetection(src, 'PLAYER_KICKED', reason, {
        kickedBy = kickedBy or 'AntiCheat System'
    }, 'kicked', 2)
    
    -- Kick the player
    DropPlayer(src, string.format(Config.BanSystem.kickMessage, reason))
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                PROTECTION THREADS
-- ═══════════════════════════════════════════════════════════════════════════════════

function StartProtectionThreads()
    -- God Mode Detection Thread
    if Config.Protections.antiGodMode.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Protections.antiGodMode.checkInterval)
                
                for _, src in ipairs(GetPlayers()) do
                    if not IsPlayerWhitelisted(src) then
                        local ped = GetPlayerPed(src)
                        if ped and ped > 0 then
                            TriggerClientEvent('nchub_anticheat:checkGodMode', src)
                        end
                    end
                end
            end
        end)
    end
    
    -- Speed Hack Detection Thread
    if Config.Protections.antiSpeedHack.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Protections.antiSpeedHack.checkInterval)
                
                for _, src in ipairs(GetPlayers()) do
                    if not IsPlayerWhitelisted(src) then
                        TriggerClientEvent('nchub_anticheat:checkSpeed', src)
                    end
                end
            end
        end)
    end
    
    -- Teleport Detection Thread
    if Config.Protections.antiTeleport.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Protections.antiTeleport.checkInterval)
                
                for _, src in ipairs(GetPlayers()) do
                    if not IsPlayerWhitelisted(src) then
                        TriggerClientEvent('nchub_anticheat:checkTeleport', src)
                    end
                end
            end
        end)
    end
    
    -- Noclip Detection Thread
    if Config.Protections.antiNoclip.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Protections.antiNoclip.checkInterval)
                
                for _, src in ipairs(GetPlayers()) do
                    if not IsPlayerWhitelisted(src) then
                        TriggerClientEvent('nchub_anticheat:checkNoclip', src)
                    end
                end
            end
        end)
    end
    
    -- Resource Usage Monitor
    if Config.Advanced.enableResourceMonitoring then
        CreateThread(function()
            while true do
                Wait(30000) -- Check every 30 seconds
                
                local resourceUsage = GetResourceUsage()
                if resourceUsage > Config.Advanced.maxResourceUsage then
                    Logger.LogSystemAlert('High resource usage detected', {
                        usage = resourceUsage,
                        maxAllowed = Config.Advanced.maxResourceUsage
                    }, 2)
                end
            end
        end)
    end
end

function GetResourceUsage()
    -- Simplified resource usage calculation
    local players = #GetPlayers()
    local baseUsage = 0.5 -- Base usage percentage
    local playerUsage = players * 0.1 -- 0.1% per player
    
    return baseUsage + playerUsage
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                CLIENT EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('nchub_anticheat:detectionReport', function(detectionType, data)
    local src = source
    
    if IsPlayerWhitelisted(src) then return end
    
    local playerName = GetPlayerName(src)
    local reason = ''
    local details = data or {}
    local severityLevel = 2
    local actionTaken = 'logged'
    
    -- Handle different detection types
    if detectionType == 'GOD_MODE' then
        reason = 'God mode detected - Player health: ' .. (data.health or 'unknown') .. ', Armor: ' .. (data.armor or 'unknown')
        severityLevel = Config.Protections.antiGodMode.banOnDetection and 3 or 2
        if Config.Protections.antiGodMode.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        else
            AddViolation(src, reason, details, severityLevel)
        end
        
    elseif detectionType == 'SPEED_HACK' then
        reason = 'Speed hack detected - Speed: ' .. (data.speed or 'unknown')
        if data.speed and data.speed > Config.Protections.antiSpeedHack.maxSpeed * 2 then
            severityLevel = 3
            if Config.Protections.antiSpeedHack.banOnDetection then
                BanPlayer(src, reason, 'AntiCheat System')
                actionTaken = 'banned'
            end
        else
            AddViolation(src, reason, details, severityLevel)
        end
        
    elseif detectionType == 'TELEPORT' then
        reason = 'Teleportation detected - Distance: ' .. (data.distance or 'unknown')
        AddViolation(src, reason, details, severityLevel)
        
    elseif detectionType == 'NOCLIP' then
        reason = 'Noclip detected'
        severityLevel = 3
        if Config.Protections.antiNoclip.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        else
            AddViolation(src, reason, details, severityLevel)
        end
        
    elseif detectionType == 'INVISIBLE' then
        reason = 'Invisibility detected'
        AddViolation(src, reason, details, severityLevel)
        
    elseif detectionType == 'BLACKLISTED_WEAPON' then
        reason = 'Blacklisted weapon detected: ' .. (data.weapon or 'unknown')
        severityLevel = 3
        if Config.Protections.weaponProtection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'BLACKLISTED_VEHICLE' then
        reason = 'Blacklisted vehicle detected: ' .. (data.vehicle or 'unknown')
        severityLevel = 3
        if Config.Protections.vehicleProtection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'ENTITY_SPAM' then
        reason = 'Entity spawning abuse detected - Count: ' .. (data.count or 'unknown')
        severityLevel = 3
        if Config.Protections.entityProtection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'LUA_INJECTION' then
        reason = 'Lua injection detected'
        severityLevel = 4
        if Config.Protections.antiLuaInjection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'MOD_MENU' then
        reason = 'Mod menu detected: ' .. (data.menuName or 'unknown')
        severityLevel = 4
        if Config.Protections.antiModMenu.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
    end
    
    -- Take screenshot for high severity detections
    if severityLevel >= 3 and Config.Screenshots.onDetection then
        TakeScreenshot(src, reason)
    end
    
    -- Log the detection
    Logger.LogDetection(src, detectionType, reason, details, actionTaken, severityLevel)
end)

RegisterNetEvent('nchub_anticheat:screenshotTaken', function(screenshotData, reason)
    local src = source
    
    if Config.Screenshots.uploadToWebhook and Config.Screenshots.webhookUrl then
        -- Upload screenshot to Discord webhook
        local payload = {
            username = Config.Logging.discordSettings.username,
            content = 'Screenshot from player: ' .. GetPlayerName(src),
            embeds = {{
                title = '📸 AntiCheat Screenshot',
                description = 'Screenshot taken during detection: ' .. (reason or 'Unknown'),
                color = 16711680,
                image = {
                    url = 'attachment://screenshot.jpg'
                },
                fields = {
                    {
                        name = '👤 Player',
                        value = GetPlayerName(src),
                        inline = true
                    },
                    {
                        name = '🆔 Server ID',
                        value = tostring(src),
                        inline = true
                    },
                    {
                        name = '📊 Detection Reason',
                        value = reason or 'Manual Screenshot',
                        inline = false
                    }
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }}
        }
        
        -- Process OCR if enabled
        if Config.Advanced.enableOCR then
            local ocrResult = ProcessScreenshotOCR(screenshotData, src)
            if ocrResult.suspicious then
                payload.embeds[1].fields[#payload.embeds[1].fields + 1] = {
                    name = '🔍 OCR Detection',
                    value = 'Suspicious keywords found: ' .. table.concat(ocrResult.keywords, ', '),
                    inline = false
                }
                
                -- Log OCR detection
                Logger.LogDetection(src, 'OCR_SCREENSHOT_DETECTION', 'Suspicious content detected in screenshot', {
                    keywords = ocrResult.keywords,
                    extractedText = ocrResult.text,
                    screenshotReason = reason
                }, 'logged', 3)
                
                -- Auto-ban if configured
                if #ocrResult.keywords >= 3 then -- If 3+ suspicious keywords found
                    BanPlayer(src, 'OCR Detection: Multiple cheat indicators found in screenshot', 'AntiCheat OCR System')
                end
            end
        end
        
        -- Send to Discord (simplified - would need actual file upload implementation)
        Logger.LogSystemAlert('Screenshot captured and processed for player: ' .. GetPlayerName(src), {
            screenshotSize = #screenshotData,
            reason = reason,
            ocrEnabled = Config.Advanced.enableOCR
        }, 2)
    end
end)

-- Enhanced detection handlers for new detection types
RegisterNetEvent('nchub_anticheat:detectionReport', function(detectionType, data)
    local src = source
    
    if IsPlayerWhitelisted(src) then return end
    
    local playerName = GetPlayerName(src)
    local reason = ''
    local details = data or {}
    local severityLevel = 2
    local actionTaken = 'logged'
    
    -- Handle existing detection types... (keeping existing code)
    
    -- Add new detection type handlers
    if detectionType == 'MOD_MENU_KEYBIND' then
        reason = 'Mod menu keybind detected: ' .. (data.key or 'unknown key')
        severityLevel = 4
        if Config.Protections.antiModMenu.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'OCR_DETECTION' then
        reason = 'OCR detected suspicious content: ' .. table.concat(data.detectedKeywords or {}, ', ')
        severityLevel = 4
        actionTaken = 'flagged'
        
    elseif detectionType == 'TRIGGER_SPAM' then
        reason = 'Event trigger spam detected: ' .. (data.eventName or 'unknown event')
        severityLevel = 3
        if Config.Protections.eventProtection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'BLACKLISTED_TRIGGER' then
        reason = 'Blacklisted event usage: ' .. (data.eventName or 'unknown event')
        severityLevel = 4
        if Config.Protections.eventProtection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'GLOBAL_INJECTION' then
        reason = 'Global variable injection detected: ' .. (data.globalName or 'unknown')
        severityLevel = 4
        if Config.Protections.antiLuaInjection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
        
    elseif detectionType == 'THREAD_SPAM' then
        reason = 'Thread creation spam detected'
        severityLevel = 3
        AddViolation(src, reason, details, severityLevel)
        
    elseif detectionType == 'UNAUTHORIZED_RESOURCE' then
        reason = 'Unauthorized resource detected: ' .. table.concat(data.resources or {}, ', ')
        severityLevel = 4
        if Config.Protections.antiLuaInjection.banOnDetection then
            BanPlayer(src, reason, 'AntiCheat System')
            actionTaken = 'banned'
        end
    end
    
    -- Take screenshot for high severity detections
    if severityLevel >= 3 and Config.Screenshots.onDetection then
        TakeScreenshot(src, reason)
    end
    
    -- Log the detection
    Logger.LogDetection(src, detectionType, reason, details, actionTaken, severityLevel)
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EVENT PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════════════

if Config.Protections.eventProtection.enabled then
    -- Rate limiting for events
    local function CheckEventRateLimit(src, eventName)
        local currentTime = GetGameTimer()
        
        if not eventRateLimits[src] then
            eventRateLimits[src] = {}
        end
        
        if not eventRateLimits[src][eventName] then
            eventRateLimits[src][eventName] = { count = 0, lastReset = currentTime }
        end
        
        local eventData = eventRateLimits[src][eventName]
        
        -- Reset counter every second
        if currentTime - eventData.lastReset > 1000 then
            eventData.count = 0
            eventData.lastReset = currentTime
        end
        
        eventData.count = eventData.count + 1
        
        if eventData.count > Config.Protections.eventProtection.maxEventsPerSecond then
            Logger.LogDetection(src, 'EVENT_SPAM', 'Event spam detected: ' .. eventName, {
                eventName = eventName,
                count = eventData.count,
                timeWindow = '1 second'
            }, 'logged', 3)
            
            if Config.Protections.eventProtection.banOnDetection then
                BanPlayer(src, 'Event spam: ' .. eventName, 'AntiCheat System')
            end
            
            return false
        end
        
        return true
    end
    
    -- Check for blacklisted events
    AddEventHandler('__cfx_internal:commandEntered', function(command)
        local src = source
        if IsPlayerWhitelisted(src) then return end
        
        for _, blacklistedEvent in ipairs(Config.BlacklistData.events) do
            if string.match(command, blacklistedEvent:gsub('%*', '.*')) then
                Logger.LogDetection(src, 'BLACKLISTED_EVENT', 'Attempted to use blacklisted event: ' .. command, {
                    command = command,
                    blacklistedPattern = blacklistedEvent
                }, 'logged', 3)
                
                if Config.Protections.eventProtection.banOnDetection then
                    BanPlayer(src, 'Blacklisted event usage: ' .. command, 'AntiCheat System')
                end
                
                CancelEvent()
                return
            end
        end
        
        CheckEventRateLimit(src, '__cfx_internal:commandEntered')
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADMIN COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════════

function InitializeAdminCommands()
    -- Main AntiCheat command
    RegisterCommand(Config.AdminCommands.mainCommand, function(source, args, rawCommand)
        local src = source
        
        if not IsPlayerAdmin(src, 1) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
            return
        end
        
        -- Show admin menu
        TriggerClientEvent('nchub_anticheat:showAdminMenu', src)
    end, false)
    
    -- Ban command
    RegisterCommand(Config.AdminCommands.banCommand, function(source, args, rawCommand)
        local src = source
        
        if not IsPlayerAdmin(src, 2) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        local reason = table.concat(args, ' ', 2) or 'No reason provided'
        
        if not targetId or not GetPlayerName(targetId) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.playerNotFound, 'error')
            return
        end
        
        BanPlayer(targetId, reason, GetPlayerName(src))
        TriggerClientEvent('QBCore:Notify', src, string.format(Config.Messages.playerBanned, GetPlayerName(targetId), reason), 'success')
        
        Logger.LogAdminAction(src, targetId, 'ban', reason, { command = rawCommand })
    end, false)
    
    -- Kick command
    RegisterCommand(Config.AdminCommands.kickCommand, function(source, args, rawCommand)
        local src = source
        
        if not IsPlayerAdmin(src, 1) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        local reason = table.concat(args, ' ', 2) or 'No reason provided'
        
        if not targetId or not GetPlayerName(targetId) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.playerNotFound, 'error')
            return
        end
        
        KickPlayer(targetId, reason, GetPlayerName(src))
        TriggerClientEvent('QBCore:Notify', src, string.format(Config.Messages.playerKicked, GetPlayerName(targetId), reason), 'success')
        
        Logger.LogAdminAction(src, targetId, 'kick', reason, { command = rawCommand })
    end, false)
    
    -- Unban command
    RegisterCommand(Config.AdminCommands.unbanCommand, function(source, args, rawCommand)
        local src = source
        
        if not IsPlayerAdmin(src, 2) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
            return
        end
        
        local identifier = args[1]
        local reason = table.concat(args, ' ', 2) or 'No reason provided'
        
        if not identifier then
            TriggerClientEvent('QBCore:Notify', src, 'Usage: /' .. Config.AdminCommands.unbanCommand .. ' <identifier> [reason]', 'error')
            return
        end
        
        UnbanPlayer(identifier, GetPlayerName(src), reason)
        TriggerClientEvent('QBCore:Notify', src, string.format(Config.Messages.playerUnbanned, identifier), 'success')
        
        Logger.LogAdminAction(src, nil, 'unban', reason, { identifier = identifier, command = rawCommand })
    end, false)
    
    -- Logs command
    RegisterCommand(Config.AdminCommands.logsCommand, function(source, args, rawCommand)
        local src = source
        
        if not IsPlayerAdmin(src, 1) then
            TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
            return
        end
        
        local logStats = Logger.GetLogStats()
        TriggerClientEvent('nchub_anticheat:showLogStats', src, logStats)
    end, false)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADMIN EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('nchub_anticheat:requestPlayerStatus', function()
    local src = source
    
    local status = {
        whitelisted = IsPlayerWhitelisted(src),
        violations = playerViolations[src] or 0,
        protected = true
    }
    
    TriggerClientEvent('nchub_anticheat:showPlayerStatus', src, status)
end)

RegisterNetEvent('nchub_anticheat:requestLiveDetections', function()
    local src = source
    
    if not IsPlayerAdmin(src, 1) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
        return
    end
    
    -- Get recent detections from database
    if Config.Database.useMySQL then
        MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.logsTable .. ' WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR) ORDER BY timestamp DESC LIMIT 10', {}, function(result)
            if result then
                for _, detection in ipairs(result) do
                    TriggerClientEvent('chat:addMessage', src, {
                        color = {255, 165, 0},
                        multiline = true,
                        args = {'[Recent Detection]', string.format('%s - %s: %s', 
                            detection.timestamp, 
                            detection.player_name, 
                            detection.detection_reason)}
                    })
                end
            else
                TriggerClientEvent('chat:addMessage', src, {
                    color = {255, 255, 0},
                    multiline = true,
                    args = {'[AntiCheat]', 'No recent detections found'}
                })
            end
        end)
    end
end)

RegisterNetEvent('nchub_anticheat:requestPlayerStats', function()
    local src = source
    
    if not IsPlayerAdmin(src, 1) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
        return
    end
    
    local totalPlayers = #GetPlayers()
    local totalViolations = 0
    local whitelistedCount = 0
    
    for playerId, violations in pairs(playerViolations) do
        totalViolations = totalViolations + violations
    end
    
    for identifier, _ in pairs(whitelistedPlayers) do
        whitelistedCount = whitelistedCount + 1
    end
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 0},
        multiline = true,
        args = {'[Player Stats]', 'Total Players: ' .. totalPlayers}
    })
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 0},
        multiline = true,
        args = {'[Player Stats]', 'Total Violations: ' .. totalViolations}
    })
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 0},
        multiline = true,
        args = {'[Player Stats]', 'Whitelisted Players: ' .. whitelistedCount}
    })
end)

RegisterNetEvent('nchub_anticheat:requestSystemStatus', function()
    local src = source
    
    if not IsPlayerAdmin(src, 2) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
        return
    end
    
    local activeProtections = 0
    for _, protection in pairs(Config.Protections) do
        if protection.enabled then
            activeProtections = activeProtections + 1
        end
    end
    
    local logStats = Logger.GetLogStats()
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 255},
        multiline = true,
        args = {'[System Status]', 'Active Protections: ' .. activeProtections}
    })
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 255},
        multiline = true,
        args = {'[System Status]', 'Log Queue Size: ' .. logStats.queueSize}
    })
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 255},
        multiline = true,
        args = {'[System Status]', 'Database Logging: ' .. tostring(logStats.databaseLogging)}
    })
    
    TriggerClientEvent('chat:addMessage', src, {
        color = {0, 255, 255},
        multiline = true,
        args = {'[System Status]', 'Discord Logging: ' .. tostring(logStats.discordLogging)}
    })
end)

RegisterNetEvent('nchub_anticheat:adminTakeScreenshot', function(targetId)
    local src = source
    
    if not IsPlayerAdmin(src, 2) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
        return
    end
    
    if not GetPlayerName(targetId) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.playerNotFound, 'error')
        return
    end
    
    TakeScreenshot(targetId, 'Admin requested screenshot by ' .. GetPlayerName(src))
    TriggerClientEvent('QBCore:Notify', src, 'Screenshot request sent to player ' .. GetPlayerName(targetId), 'success')
    
    Logger.LogAdminAction(src, targetId, 'screenshot_request', 'Admin requested screenshot', {
        adminName = GetPlayerName(src),
        targetName = GetPlayerName(targetId)
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADDITIONAL ADMIN COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════════

-- Whitelist management command
RegisterCommand('acwhitelist', function(source, args, rawCommand)
    local src = source
    
    if not IsPlayerAdmin(src, 3) then
        TriggerClientEvent('QBCore:Notify', src, Config.Messages.noPermission, 'error')
        return
    end
    
    local action = args[1]
    local identifier = args[2]
    
    if not action or not identifier then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /acwhitelist <add/remove> <identifier>', 'error')
        return
    end
    
    if action == 'add' then
        AddToWhitelist(identifier, GetPlayerName(src), 'Admin whitelist')
        TriggerClientEvent('QBCore:Notify', src, 'Player added to whitelist: ' .. identifier, 'success')
    elseif action == 'remove' then
        RemoveFromWhitelist(identifier, GetPlayerName(src), 'Admin removal')
        TriggerClientEvent('QBCore:Notify', src, 'Player removed from whitelist: ' .. identifier, 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Invalid action. Use add or remove.', 'error')
    end
end, false)

function AddToWhitelist(identifier, addedBy, reason)
    if not Config.Database.useMySQL then return false end
    
    MySQL.Async.insert('INSERT INTO ' .. Config.Database.whitelistTable .. ' (player_identifier, player_name, whitelist_type, permission_level, added_by, reason) VALUES (?, ?, ?, ?, ?, ?)', {
        identifier,
        'Manual Whitelist',
        'trusted',
        1,
        addedBy or 'System',
        reason or 'Manual whitelist'
    }, function(insertId)
        if insertId then
            -- Add to local whitelist
            whitelistedPlayers[identifier] = {
                id = insertId,
                player_identifier = identifier,
                whitelist_type = 'trusted',
                permission_level = 1,
                is_active = 1
            }
            
            Logger.LogSystemAlert('Player whitelisted: ' .. identifier, {
                addedBy = addedBy,
                reason = reason
            }, 1)
        end
    end)
    
    return true
end

function RemoveFromWhitelist(identifier, removedBy, reason)
    if not Config.Database.useMySQL then return false end
    
    MySQL.Async.execute('UPDATE ' .. Config.Database.whitelistTable .. ' SET is_active = 0 WHERE player_identifier = ?', {
        identifier
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Remove from local whitelist
            whitelistedPlayers[identifier] = nil
            
            Logger.LogSystemAlert('Player removed from whitelist: ' .. identifier, {
                removedBy = removedBy,
                reason = reason
            }, 1)
        end
    end)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════════

exports('isCheater', function(src)
    return playerViolations[src] and playerViolations[src] > 0
end)

exports('isPlayerWhitelisted', IsPlayerWhitelisted)

exports('banPlayer', BanPlayer)

exports('unbanPlayer', UnbanPlayer)

exports('kickPlayer', KickPlayer)

exports('logDetection', Logger.LogDetection)

exports('getPlayerDetections', function(src)
    return playerViolations[src] or 0
end)

exports('getBanInfo', function(identifier)
    return bannedPlayers[identifier]
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                OCR PROCESSING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function ProcessScreenshotOCR(screenshotData, playerId)
    if not Config.Advanced.enableOCR then
        return { suspicious = false, keywords = {}, text = "" }
    end
    
    -- This is a placeholder for actual OCR implementation
    -- In a real implementation, you would:
    -- 1. Save the screenshot temporarily
    -- 2. Use an OCR library (like Tesseract) to extract text
    -- 3. Analyze the text for suspicious keywords
    -- 4. Clean up temporary files
    
    local extractedText = SimulateOCRProcessing(screenshotData)
    local suspiciousKeywords = {}
    
    -- Check for suspicious keywords
    for _, keyword in ipairs(Config.Advanced.ocrKeywords) do
        if string.find(string.lower(extractedText), string.lower(keyword)) then
            table.insert(suspiciousKeywords, keyword)
        end
    end
    
    return {
        suspicious = #suspiciousKeywords > 0,
        keywords = suspiciousKeywords,
        text = extractedText
    }
end

function SimulateOCRProcessing(screenshotData)
    -- Placeholder for actual OCR processing
    -- In reality, this would interface with an OCR service or library
    
    -- For demonstration, we'll return an empty string
    -- In a real implementation, you might use:
    -- - Cloud OCR services (Google Vision, AWS Textract, Azure Computer Vision)
    -- - Local OCR libraries (Tesseract)
    -- - Custom OCR solutions
    
    return ""
end

-- Enhanced detection handlers for new detection types