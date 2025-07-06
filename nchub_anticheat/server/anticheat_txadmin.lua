-- ████████╗██╗  ██╗ █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗
-- ╚══██╔══╝╚██╗██╔╝██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║
--    ██║    ╚███╔╝ ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║
--    ██║    ██╔██╗ ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║
--    ██║   ██╔╝ ██╗██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║
--    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝
--
-- NCHub AntiCheat TxAdmin Integration
-- Version: 1.0.0
-- Author: NCHub Development Team

-- Check if TxAdmin is available
local isTxAdminAvailable = GetConvar('txAdminServerMode', 'false') ~= 'false'

if not isTxAdminAvailable then
    if Config.Debug then
        print('[NCHub AntiCheat] TxAdmin not detected - TxAdmin integration disabled')
    end
    return
end

if Config.Debug then
    print('[NCHub AntiCheat] TxAdmin detected - Initializing TxAdmin integration')
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                TXADMIN INTEGRATION
-- ═══════════════════════════════════════════════════════════════════════════════════

local TxAdmin = {}
TxAdmin.actions = {}
TxAdmin.reports = {}

-- Initialize TxAdmin integration
function TxAdmin.Initialize()
    if not Config.Integrations.txadmin.enabled then
        return
    end
    
    -- Register TxAdmin action handlers
    TxAdmin.RegisterActionHandlers()
    
    -- Register TxAdmin menu items
    TxAdmin.RegisterMenuItems()
    
    -- Start TxAdmin monitoring
    TxAdmin.StartMonitoring()
    
    if Config.Debug then
        print('[NCHub AntiCheat] TxAdmin integration initialized successfully')
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ACTION HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

function TxAdmin.RegisterActionHandlers()
    -- Handle TxAdmin ban actions
    AddEventHandler('txAdmin:events:playerBanned', function(eventData)
        if eventData and eventData.targetIds then
            for _, id in ipairs(eventData.targetIds) do
                local src = tonumber(id)
                if src then
                    TxAdmin.HandleTxAdminBan(src, eventData)
                end
            end
        end
    end)
    
    -- Handle TxAdmin kick actions
    AddEventHandler('txAdmin:events:playerKicked', function(eventData)
        if eventData and eventData.targetIds then
            for _, id in ipairs(eventData.targetIds) do
                local src = tonumber(id)
                if src then
                    TxAdmin.HandleTxAdminKick(src, eventData)
                end
            end
        end
    end)
    
    -- Handle TxAdmin warn actions
    AddEventHandler('txAdmin:events:playerWarned', function(eventData)
        if eventData and eventData.targetIds then
            for _, id in ipairs(eventData.targetIds) do
                local src = tonumber(id)
                if src then
                    TxAdmin.HandleTxAdminWarn(src, eventData)
                end
            end
        end
    end)
    
    -- Handle TxAdmin whitelist changes
    AddEventHandler('txAdmin:events:whitelistUpdated', function(eventData)
        TxAdmin.HandleWhitelistUpdate(eventData)
    end)
end

function TxAdmin.HandleTxAdminBan(src, eventData)
    local playerName = GetPlayerName(src) or 'Unknown'
    local reason = eventData.reason or 'No reason provided'
    local adminName = eventData.author or 'TxAdmin'
    
    -- Log the TxAdmin ban action
    local Logger = require('utils.logger')
    Logger.LogAdminAction(nil, src, 'txadmin_ban', reason, {
        adminName = adminName,
        targetName = playerName,
        txAdminData = eventData,
        source = 'txadmin'
    })
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] TxAdmin ban logged: %s banned %s for %s', 
            adminName, playerName, reason))
    end
end

function TxAdmin.HandleTxAdminKick(src, eventData)
    local playerName = GetPlayerName(src) or 'Unknown'
    local reason = eventData.reason or 'No reason provided'
    local adminName = eventData.author or 'TxAdmin'
    
    -- Log the TxAdmin kick action
    local Logger = require('utils.logger')
    Logger.LogAdminAction(nil, src, 'txadmin_kick', reason, {
        adminName = adminName,
        targetName = playerName,
        txAdminData = eventData,
        source = 'txadmin'
    })
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] TxAdmin kick logged: %s kicked %s for %s', 
            adminName, playerName, reason))
    end
end

function TxAdmin.HandleTxAdminWarn(src, eventData)
    local playerName = GetPlayerName(src) or 'Unknown'
    local reason = eventData.reason or 'No reason provided'
    local adminName = eventData.author or 'TxAdmin'
    
    -- Log the TxAdmin warn action
    local Logger = require('utils.logger')
    Logger.LogAdminAction(nil, src, 'txadmin_warn', reason, {
        adminName = adminName,
        targetName = playerName,
        txAdminData = eventData,
        source = 'txadmin'
    })
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] TxAdmin warn logged: %s warned %s for %s', 
            adminName, playerName, reason))
    end
end

function TxAdmin.HandleWhitelistUpdate(eventData)
    -- Reload whitelist data when TxAdmin whitelist is updated
    if Config.Integrations.txadmin.enabled then
        -- Trigger whitelist reload
        TriggerEvent('nchub_anticheat:reloadWhitelist')
        
        local Logger = require('utils.logger')
        Logger.LogSystemAlert('TxAdmin whitelist updated - reloading AntiCheat whitelist', {
            txAdminData = eventData
        }, 1)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                TXADMIN REPORTING
-- ═══════════════════════════════════════════════════════════════════════════════════

function TxAdmin.ReportToTxAdmin(eventType, playerSrc, data)
    if not Config.Integrations.txadmin.reportToTxAdmin then
        return
    end
    
    local playerName = playerSrc and GetPlayerName(playerSrc) or 'Unknown'
    local playerIdentifiers = playerSrc and GetPlayerIdentifiers(playerSrc) or {}
    
    local report = {
        type = 'nchub_anticheat',
        subtype = eventType,
        player = {
            id = playerSrc,
            name = playerName,
            identifiers = playerIdentifiers
        },
        data = data,
        timestamp = os.time(),
        severity = data.severityLevel or 1
    }
    
    -- Send report to TxAdmin
    TriggerEvent('txAdmin:events:announcement', {
        message = string.format('[AntiCheat] %s detected for %s: %s', 
            eventType, playerName, data.reason or 'No reason'),
        author = 'NCHub AntiCheat',
        type = 'warning'
    })
    
    -- Store report for later processing
    table.insert(TxAdmin.reports, report)
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] Report sent to TxAdmin: %s for %s', 
            eventType, playerName))
    end
end

function TxAdmin.SendBanRequest(playerSrc, reason, duration)
    if not Config.Integrations.txadmin.txAdminActions then
        return false
    end
    
    local playerName = GetPlayerName(playerSrc) or 'Unknown'
    
    -- Send ban request to TxAdmin
    TriggerEvent('txAdmin:events:playerBanned', {
        targetIds = { tostring(playerSrc) },
        reason = reason,
        author = 'NCHub AntiCheat',
        duration = duration or 0, -- 0 = permanent
        source = 'anticheat'
    })
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] Ban request sent to TxAdmin for %s: %s', 
            playerName, reason))
    end
    
    return true
end

function TxAdmin.SendKickRequest(playerSrc, reason)
    if not Config.Integrations.txadmin.txAdminActions then
        return false
    end
    
    local playerName = GetPlayerName(playerSrc) or 'Unknown'
    
    -- Send kick request to TxAdmin
    TriggerEvent('txAdmin:events:playerKicked', {
        targetIds = { tostring(playerSrc) },
        reason = reason,
        author = 'NCHub AntiCheat',
        source = 'anticheat'
    })
    
    if Config.Debug then
        print(string.format('[NCHub AntiCheat] Kick request sent to TxAdmin for %s: %s', 
            playerName, reason))
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                TXADMIN MENU INTEGRATION
-- ═══════════════════════════════════════════════════════════════════════════════════

function TxAdmin.RegisterMenuItems()
    -- Add AntiCheat statistics to TxAdmin menu
    RegisterCommand('tx:anticheat:stats', function(source, args, rawCommand)
        local src = source
        
        -- Check if command was called from TxAdmin
        if src ~= 0 then
            return
        end
        
        local stats = TxAdmin.GetStatistics()
        
        -- Send stats to TxAdmin console
        print('[NCHub AntiCheat] Statistics:')
        print('  Total Reports: ' .. #TxAdmin.reports)
        print('  Active Protections: ' .. stats.activeProtections)
        print('  Players Online: ' .. stats.playersOnline)
        print('  Violations (Last Hour): ' .. stats.violationsLastHour)
    end, true)
    
    -- Add AntiCheat player info command
    RegisterCommand('tx:anticheat:player', function(source, args, rawCommand)
        local src = source
        
        if src ~= 0 then
            return
        end
        
        local playerId = tonumber(args[1])
        if not playerId then
            print('[NCHub AntiCheat] Usage: tx:anticheat:player <player_id>')
            return
        end
        
        local playerInfo = TxAdmin.GetPlayerInfo(playerId)
        if playerInfo then
            print('[NCHub AntiCheat] Player Info for ' .. (GetPlayerName(playerId) or 'Unknown') .. ':')
            print('  Violations: ' .. playerInfo.violations)
            print('  Whitelisted: ' .. tostring(playerInfo.whitelisted))
            print('  Last Detection: ' .. (playerInfo.lastDetection or 'None'))
        else
            print('[NCHub AntiCheat] Player not found or no data available')
        end
    end, true)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                MONITORING & STATISTICS
-- ═══════════════════════════════════════════════════════════════════════════════════

function TxAdmin.StartMonitoring()
    CreateThread(function()
        while true do
            Wait(300000) -- Every 5 minutes
            
            -- Send periodic statistics to TxAdmin
            local stats = TxAdmin.GetStatistics()
            
            TriggerEvent('txAdmin:events:announcement', {
                message = string.format('[AntiCheat] Status Update - %d players online, %d violations in last hour', 
                    stats.playersOnline, stats.violationsLastHour),
                author = 'NCHub AntiCheat System',
                type = 'info'
            })
            
            -- Clean up old reports
            TxAdmin.CleanupReports()
        end
    end)
end

function TxAdmin.GetStatistics()
    local currentTime = os.time()
    local oneHourAgo = currentTime - 3600
    
    local violationsLastHour = 0
    for _, report in ipairs(TxAdmin.reports) do
        if report.timestamp >= oneHourAgo then
            violationsLastHour = violationsLastHour + 1
        end
    end
    
    local activeProtections = 0
    for _, protection in pairs(Config.Protections) do
        if protection.enabled then
            activeProtections = activeProtections + 1
        end
    end
    
    return {
        playersOnline = #GetPlayers(),
        violationsLastHour = violationsLastHour,
        totalReports = #TxAdmin.reports,
        activeProtections = activeProtections,
        serverUptime = GetGameTimer() / 1000 / 60, -- minutes
        lastUpdate = currentTime
    }
end

function TxAdmin.GetPlayerInfo(playerId)
    if not GetPlayerName(playerId) then
        return nil
    end
    
    local violations = 0
    local lastDetection = nil
    local playerIdentifier = nil
    
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then
            playerIdentifier = id
            break
        end
    end
    
    -- Count violations for this player
    for _, report in ipairs(TxAdmin.reports) do
        if report.player.id == playerId then
            violations = violations + 1
            if not lastDetection or report.timestamp > lastDetection then
                lastDetection = report.timestamp
            end
        end
    end
    
    return {
        violations = violations,
        whitelisted = exports[GetCurrentResourceName()]:isPlayerWhitelisted(playerId),
        lastDetection = lastDetection and os.date('%Y-%m-%d %H:%M:%S', lastDetection) or nil,
        identifier = playerIdentifier
    }
end

function TxAdmin.CleanupReports()
    local currentTime = os.time()
    local twentyFourHoursAgo = currentTime - 86400 -- 24 hours
    
    local newReports = {}
    for _, report in ipairs(TxAdmin.reports) do
        if report.timestamp >= twentyFourHoursAgo then
            table.insert(newReports, report)
        end
    end
    
    local removedCount = #TxAdmin.reports - #newReports
    TxAdmin.reports = newReports
    
    if Config.Debug and removedCount > 0 then
        print(string.format('[NCHub AntiCheat] Cleaned up %d old TxAdmin reports', removedCount))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

-- Listen for AntiCheat detections and report to TxAdmin
AddEventHandler('nchub_anticheat:detectionLogged', function(playerSrc, logData)
    if Config.Integrations.txadmin.reportToTxAdmin then
        TxAdmin.ReportToTxAdmin(logData.detectionType, playerSrc, logData)
    end
end)

-- Handle server shutdown
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Send final statistics to TxAdmin
        if Config.Integrations.txadmin.enabled then
            local stats = TxAdmin.GetStatistics()
            
            TriggerEvent('txAdmin:events:announcement', {
                message = string.format('[AntiCheat] System shutting down - Final stats: %d total reports, %d players protected', 
                    stats.totalReports, stats.playersOnline),
                author = 'NCHub AntiCheat System',
                type = 'warning'
            })
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════════

exports('txadmin_reportDetection', TxAdmin.ReportToTxAdmin)
exports('txadmin_sendBanRequest', TxAdmin.SendBanRequest)
exports('txadmin_sendKickRequest', TxAdmin.SendKickRequest)
exports('txadmin_getStatistics', TxAdmin.GetStatistics)
exports('txadmin_getPlayerInfo', TxAdmin.GetPlayerInfo)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════════

-- Initialize TxAdmin integration when the resource starts
CreateThread(function()
    Wait(5000) -- Wait for other systems to initialize
    TxAdmin.Initialize()
end)