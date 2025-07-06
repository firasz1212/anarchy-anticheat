-- ██╗      ██████╗  ██████╗  ██████╗ ███████╗██████╗ 
-- ██║     ██╔═══██╗██╔════╝ ██╔════╝ ██╔════╝██╔══██╗
-- ██║     ██║   ██║██║  ███╗██║  ███╗█████╗  ██████╔╝
-- ██║     ██║   ██║██║   ██║██║   ██║██╔══╝  ██╔══██╗
-- ███████╗╚██████╔╝╚██████╔╝╚██████╔╝███████╗██║  ██║
-- ╚══════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
--
-- NCHub AntiCheat Logger Utility
-- Version: 1.0.0
-- Author: NCHub Development Team

local Logger = {}
local logQueue = {}
local isProcessing = false

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.Initialize()
    if Config.Debug then
        print('[NCHub AntiCheat] Logger initializing...')
    end
    
    -- Create log file if it doesn't exist
    if Config.Logging.enableFileLogging then
        Logger.CreateLogFile()
    end
    
    -- Test database connection
    if Config.Logging.enableDatabaseLogging then
        Logger.TestDatabaseConnection()
    end
    
    -- Start log processing thread
    CreateThread(function()
        while true do
            Logger.ProcessLogQueue()
            Wait(1000) -- Process logs every second
        end
    end)
    
    -- Log rotation thread
    CreateThread(function()
        while true do
            Wait(3600000) -- Check every hour
            Logger.RotateLogFile()
        end
    end)
    
    if Config.Debug then
        print('[NCHub AntiCheat] Logger initialized successfully')
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                FILE LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.CreateLogFile()
    local file = io.open(Config.Logging.logFile, 'a+')
    if file then
        file:close()
        return true
    else
        print('[NCHub AntiCheat] ERROR: Cannot create log file: ' .. Config.Logging.logFile)
        return false
    end
end

function Logger.WriteToFile(logData)
    if not Config.Logging.enableFileLogging then return end
    
    local file = io.open(Config.Logging.logFile, 'a')
    if file then
        local jsonData = json.encode(logData)
        file:write(jsonData .. '\n')
        file:close()
        return true
    else
        print('[NCHub AntiCheat] ERROR: Cannot write to log file')
        return false
    end
end

function Logger.RotateLogFile()
    if not Config.Logging.enableFileLogging then return end
    
    local fileInfo = io.open(Config.Logging.logFile, 'r')
    if fileInfo then
        fileInfo:seek('end')
        local fileSize = fileInfo:seek()
        fileInfo:close()
        
        if fileSize > Config.Logging.maxLogFileSize then
            local timestamp = os.date('%Y%m%d_%H%M%S')
            local backupName = Config.Logging.logFile .. '.backup_' .. timestamp
            
            -- Rename current log file
            os.rename(Config.Logging.logFile, backupName)
            
            -- Create new log file
            Logger.CreateLogFile()
            
            if Config.Debug then
                print('[NCHub AntiCheat] Log file rotated: ' .. backupName)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                DATABASE LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.TestDatabaseConnection()
    if not Config.Database.useMySQL then return end
    
    MySQL.Async.fetchAll('SELECT 1 as test', {}, function(result)
        if result and result[1] then
            if Config.Debug then
                print('[NCHub AntiCheat] Database connection successful')
            end
        else
            print('[NCHub AntiCheat] ERROR: Database connection failed')
        end
    end)
end

function Logger.WriteToDatabase(logData)
    if not Config.Logging.enableDatabaseLogging or not Config.Database.useMySQL then return end
    
    MySQL.Async.insert('INSERT INTO ' .. Config.Database.logsTable .. ' (player_name, player_identifier, steam_id, discord_id, license, ip_address, detection_type, detection_reason, detection_details, action_taken, severity_level, server_id, screenshot_url, coords, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        logData.playerName or 'Unknown',
        logData.playerIdentifier or 'Unknown',
        logData.steamId,
        logData.discordId,
        logData.license,
        logData.ipAddress,
        logData.detectionType,
        logData.detectionReason,
        logData.detectionDetails and json.encode(logData.detectionDetails) or nil,
        logData.actionTaken or 'logged',
        logData.severityLevel or 1,
        Config.ServerId,
        logData.screenshotUrl,
        logData.coords and json.encode(logData.coords) or nil,
        logData.timestamp or os.date('%Y-%m-%d %H:%M:%S')
    }, function(insertId)
        if Config.Debug and insertId then
            print('[NCHub AntiCheat] Log entry saved to database with ID: ' .. insertId)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                DISCORD LOGGING
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.SendToDiscord(logData, webhookType)
    if not Config.Logging.enableDiscordLogging then return end
    
    webhookType = webhookType or 'detections'
    local webhookUrl = Config.Logging.webhooks[webhookType]
    
    if not webhookUrl or webhookUrl == 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE' then
        if Config.Debug then
            print('[NCHub AntiCheat] Discord webhook not configured for: ' .. webhookType)
        end
        return
    end
    
    local embed = Logger.CreateDiscordEmbed(logData, webhookType)
    local payload = {
        username = Config.Logging.discordSettings.username,
        avatar_url = Config.Logging.discordSettings.avatar,
        embeds = { embed }
    }
    
    -- Add ping for high severity detections
    if logData.severityLevel and logData.severityLevel >= 3 then
        payload.content = Config.Logging.discordSettings.pingRole .. ' High severity detection!'
    end
    
    PerformHttpRequest(webhookUrl, function(statusCode, response, headers)
        if Config.Debug then
            if statusCode == 200 or statusCode == 204 then
                print('[NCHub AntiCheat] Discord webhook sent successfully')
            else
                print('[NCHub AntiCheat] Discord webhook failed: ' .. statusCode)
            end
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

function Logger.CreateDiscordEmbed(logData, webhookType)
    local embed = {
        title = '🛡️ NCHub AntiCheat Detection',
        color = Config.Logging.discordSettings.color,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = 'NCHub AntiCheat v1.0 | Server: ' .. Config.ServerName,
            icon_url = Config.Logging.discordSettings.avatar
        }
    }
    
    -- Customize embed based on webhook type
    if webhookType == 'bans' then
        embed.title = '🔨 Player Banned'
        embed.color = 16711680 -- Red
    elseif webhookType == 'admin' then
        embed.title = '⚙️ Admin Action'
        embed.color = 255 -- Blue
    elseif webhookType == 'system' then
        embed.title = '📊 System Alert'
        embed.color = 16776960 -- Yellow
    end
    
    -- Add fields based on available data
    embed.fields = {}
    
    if logData.playerName then
        table.insert(embed.fields, {
            name = '👤 Player',
            value = logData.playerName,
            inline = true
        })
    end
    
    if logData.steamId then
        table.insert(embed.fields, {
            name = '🎮 Steam ID',
            value = '`' .. logData.steamId .. '`',
            inline = true
        })
    end
    
    if logData.detectionType then
        table.insert(embed.fields, {
            name = '🎯 Detection Type',
            value = '`' .. logData.detectionType .. '`',
            inline = true
        })
    end
    
    if logData.detectionReason then
        table.insert(embed.fields, {
            name = '📝 Reason',
            value = logData.detectionReason,
            inline = false
        })
    end
    
    if logData.actionTaken then
        table.insert(embed.fields, {
            name = '⚡ Action Taken',
            value = logData.actionTaken,
            inline = true
        })
    end
    
    if logData.severityLevel then
        local severityText = 'Low'
        if logData.severityLevel == 2 then severityText = 'Medium'
        elseif logData.severityLevel == 3 then severityText = 'High'
        elseif logData.severityLevel >= 4 then severityText = 'Critical' end
        
        table.insert(embed.fields, {
            name = '⚠️ Severity',
            value = severityText,
            inline = true
        })
    end
    
    if logData.coords then
        local coordsText = string.format('X: %.2f, Y: %.2f, Z: %.2f', 
            logData.coords.x or 0, 
            logData.coords.y or 0, 
            logData.coords.z or 0)
        table.insert(embed.fields, {
            name = '📍 Location',
            value = '`' .. coordsText .. '`',
            inline = true
        })
    end
    
    if logData.detectionDetails then
        local detailsText = type(logData.detectionDetails) == 'table' 
            and json.encode(logData.detectionDetails) 
            or tostring(logData.detectionDetails)
        
        -- Truncate if too long
        if #detailsText > 1000 then
            detailsText = string.sub(detailsText, 1, 997) .. '...'
        end
        
        table.insert(embed.fields, {
            name = '🔍 Details',
            value = '```json\n' .. detailsText .. '\n```',
            inline = false
        })
    end
    
    -- Add screenshot if available
    if logData.screenshotUrl then
        embed.image = {
            url = logData.screenshotUrl
        }
    end
    
    return embed
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                LOG QUEUE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.AddToQueue(logData)
    table.insert(logQueue, logData)
    
    if Config.Debug then
        print('[NCHub AntiCheat] Log added to queue. Queue size: ' .. #logQueue)
    end
end

function Logger.ProcessLogQueue()
    if isProcessing or #logQueue == 0 then return end
    
    isProcessing = true
    
    local batchSize = math.min(10, #logQueue) -- Process max 10 logs at once
    local currentBatch = {}
    
    for i = 1, batchSize do
        table.insert(currentBatch, table.remove(logQueue, 1))
    end
    
    for _, logData in ipairs(currentBatch) do
        -- File logging
        if Config.Logging.enableFileLogging then
            Logger.WriteToFile(logData)
        end
        
        -- Database logging
        if Config.Logging.enableDatabaseLogging then
            Logger.WriteToDatabase(logData)
        end
        
        -- Console logging
        if Config.Logging.enableConsoleLogging then
            Logger.WriteToConsole(logData)
        end
        
        -- Discord logging
        if Config.Logging.enableDiscordLogging then
            local webhookType = 'detections'
            if logData.actionTaken == 'banned' then
                webhookType = 'bans'
            elseif logData.detectionType == 'ADMIN_ACTION' then
                webhookType = 'admin'
            elseif logData.detectionType == 'SYSTEM_ALERT' then
                webhookType = 'system'
            end
            
            Logger.SendToDiscord(logData, webhookType)
        end
        
        Wait(100) -- Small delay between logs to prevent spam
    end
    
    isProcessing = false
end

function Logger.WriteToConsole(logData)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local severity = logData.severityLevel or 1
    local color = '^7' -- White
    
    if severity >= 4 then color = '^1' -- Red (Critical)
    elseif severity == 3 then color = '^3' -- Yellow (High)
    elseif severity == 2 then color = '^5' -- Purple (Medium)
    end
    
    local message = string.format('%s[%s] %s: %s - %s (%s)^7',
        color,
        timestamp,
        logData.detectionType or 'UNKNOWN',
        logData.playerName or 'Unknown Player',
        logData.detectionReason or 'No reason provided',
        logData.actionTaken or 'logged'
    )
    
    print(message)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                PUBLIC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function Logger.LogDetection(playerSrc, detectionType, reason, details, actionTaken, severityLevel, screenshotUrl)
    local player = playerSrc and GetPlayerName(playerSrc) or nil
    local playerData = Logger.GetPlayerData(playerSrc)
    
    local logData = {
        playerName = player or 'Unknown',
        playerIdentifier = playerData.identifier or 'Unknown',
        steamId = playerData.steam,
        discordId = playerData.discord,
        license = playerData.license,
        ipAddress = playerData.ip,
        detectionType = detectionType,
        detectionReason = reason,
        detectionDetails = details,
        actionTaken = actionTaken or 'logged',
        severityLevel = severityLevel or 1,
        screenshotUrl = screenshotUrl,
        coords = playerSrc and Logger.GetPlayerCoords(playerSrc) or nil,
        timestamp = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    Logger.AddToQueue(logData)
    
    -- Trigger detection event for other resources
    TriggerEvent('nchub_anticheat:detectionLogged', playerSrc, logData)
    
    return logData
end

function Logger.LogAdminAction(adminSrc, targetSrc, action, reason, details)
    local adminName = adminSrc and GetPlayerName(adminSrc) or 'Console'
    local targetName = targetSrc and GetPlayerName(targetSrc) or 'Unknown'
    
    return Logger.LogDetection(targetSrc, 'ADMIN_ACTION', 
        string.format('%s performed %s on %s: %s', adminName, action, targetName, reason),
        details, action, 2)
end

function Logger.LogSystemAlert(message, details, severityLevel)
    return Logger.LogDetection(nil, 'SYSTEM_ALERT', message, details, 'logged', severityLevel or 1)
end

function Logger.GetPlayerData(playerSrc)
    if not playerSrc then return {} end
    
    local identifiers = GetPlayerIdentifiers(playerSrc)
    local data = {
        ip = GetPlayerEndpoint(playerSrc)
    }
    
    for _, id in ipairs(identifiers) do
        if string.find(id, 'steam:') then
            data.steam = id
        elseif string.find(id, 'license:') then
            data.license = id
            data.identifier = id -- Use license as primary identifier
        elseif string.find(id, 'discord:') then
            data.discord = id
        end
    end
    
    return data
end

function Logger.GetPlayerCoords(playerSrc)
    if not playerSrc then return nil end
    
    local ped = GetPlayerPed(playerSrc)
    if ped and ped > 0 then
        local coords = GetEntityCoords(ped)
        return {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    end
    
    return nil
end

function Logger.GetLogStats()
    return {
        queueSize = #logQueue,
        isProcessing = isProcessing,
        fileLogging = Config.Logging.enableFileLogging,
        databaseLogging = Config.Logging.enableDatabaseLogging,
        discordLogging = Config.Logging.enableDiscordLogging
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════════

exports('logDetection', Logger.LogDetection)
exports('logAdminAction', Logger.LogAdminAction)
exports('logSystemAlert', Logger.LogSystemAlert)
exports('getLogStats', Logger.GetLogStats)

-- Initialize logger when script starts
CreateThread(function()
    Wait(1000) -- Wait for other resources to load
    Logger.Initialize()
end)

return Logger