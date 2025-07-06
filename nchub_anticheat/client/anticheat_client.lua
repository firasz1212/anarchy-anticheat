-- ██████╗██╗     ██╗███████╗███╗   ██╗████████╗
-- ██╔════╝██║     ██║██╔════╝████╗  ██║╚══██╔══╝
-- ██║     ██║     ██║█████╗  ██╔██╗ ██║   ██║   
-- ██║     ██║     ██║██╔══╝  ██║╚██╗██║   ██║   
-- ╚██████╗███████╗██║███████╗██║ ╚████║   ██║   
--  ╚═════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   
--
-- NCHub AntiCheat Client
-- Version: 1.0.0
-- Author: NCHub Development Team

local QBCore = exports['qb-core']:GetCoreObject()

-- Client-side variables
local isWhitelisted = false
local lastPosition = nil
local lastVelocity = 0
local entitySpawnCount = 0
local lastEntityReset = GetGameTimer()
local violationCount = 0
local isInVehicle = false
local lastVehicleCheck = GetGameTimer()

-- Protection states
local protectionStates = {
    godModeActive = false,
    speedHackActive = false,
    noclipActive = false,
    invisibleActive = false,
    teleportActive = false
}

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000) -- Wait for everything to load
    
    -- Check if player is whitelisted
    TriggerServerEvent('nchub_anticheat:checkWhitelist')
    
    -- Start protection threads
    StartProtectionThreads()
    
    -- Initialize detection systems
    InitializeDetectionSystems()
    
    if Config.Debug then
        print('[NCHub AntiCheat] Client initialized successfully')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function ReportDetection(detectionType, data)
    if isWhitelisted then return end
    
    violationCount = violationCount + 1
    TriggerServerEvent('nchub_anticheat:detectionReport', detectionType, data)
    
    if Config.Debug then
        print('[NCHub AntiCheat] Detection reported: ' .. detectionType)
    end
end

function IsInExemptZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.Exemptions.exemptZones) do
        local distance = #(playerCoords - zone.coords)
        if distance <= zone.radius then
            return true
        end
    end
    
    return false
end

function IsInExemptTime()
    local currentHour = tonumber(os.date('%H'))
    
    for _, hour in ipairs(Config.Exemptions.exemptHours) do
        if currentHour == hour then
            return true
        end
    end
    
    return false
end

function GetPlayerJob()
    local Player = QBCore.Functions.GetPlayerData()
    return Player.job and Player.job.name or nil
end

function IsJobExempt()
    local playerJob = GetPlayerJob()
    if not playerJob then return false end
    
    for _, exemptJob in ipairs(Config.Exemptions.exemptJobs) do
        if playerJob == exemptJob then
            return true
        end
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                DETECTION SYSTEMS
-- ═══════════════════════════════════════════════════════════════════════════════════

function CheckGodMode()
    if not Config.Protections.antiGodMode.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    local health = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local armor = GetPedArmour(playerPed)
    
    -- Check for abnormal health values
    if health > Config.Protections.antiGodMode.maxHealth or 
       armor > Config.Protections.antiGodMode.maxArmor or
       health > maxHealth then
        
        protectionStates.godModeActive = true
        ReportDetection('GOD_MODE', {
            health = health,
            maxHealth = maxHealth,
            armor = armor,
            configMaxHealth = Config.Protections.antiGodMode.maxHealth,
            configMaxArmor = Config.Protections.antiGodMode.maxArmor
        })
    else
        protectionStates.godModeActive = false
    end
    
    -- Check for invincibility
    if GetPlayerInvincible(PlayerId()) then
        ReportDetection('GOD_MODE', {
            invincible = true,
            health = health,
            armor = armor
        })
    end
end

function CheckSpeedHack()
    if not Config.Protections.antiSpeedHack.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    local velocity = GetEntityVelocity(playerPed)
    local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2) * 3.6 -- Convert to km/h
    
    -- Check if player is in exempt vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        local vehicleModel = GetEntityModel(vehicle)
        local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
        
        for _, exemptVehicle in ipairs(Config.Exemptions.exemptVehicles) do
            if vehicleName == exemptVehicle then
                return
            end
        end
    end
    
    -- Check for speed hack
    if speed > Config.Protections.antiSpeedHack.maxSpeed and not IsInExemptZone() then
        protectionStates.speedHackActive = true
        ReportDetection('SPEED_HACK', {
            speed = speed,
            maxAllowed = Config.Protections.antiSpeedHack.maxSpeed,
            inVehicle = IsPedInAnyVehicle(playerPed, false),
            vehicleModel = IsPedInAnyVehicle(playerPed, false) and GetEntityModel(GetVehiclePedIsIn(playerPed, false)) or nil
        })
    else
        protectionStates.speedHackActive = false
    end
    
    lastVelocity = speed
end

function CheckTeleport()
    if not Config.Protections.antiTeleport.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    local currentPos = GetEntityCoords(playerPed)
    
    if lastPosition then
        local distance = #(currentPos - lastPosition)
        local timeDiff = (GetGameTimer() - (lastPosition.time or 0)) / 1000
        
        -- Calculate expected maximum distance based on time and max speed
        local maxDistance = (Config.Protections.antiSpeedHack.maxSpeed / 3.6) * timeDiff * 1.5 -- Add 50% tolerance
        
        if distance > Config.Protections.antiTeleport.maxDistance and distance > maxDistance then
            -- Check if player is in vehicle and vehicle teleport is allowed
            if IsPedInAnyVehicle(playerPed, false) and Config.Protections.antiTeleport.exemptVehicles then
                goto skipTeleportCheck
            end
            
            protectionStates.teleportActive = true
            ReportDetection('TELEPORT', {
                distance = distance,
                maxAllowed = Config.Protections.antiTeleport.maxDistance,
                timeDiff = timeDiff,
                lastPos = lastPosition,
                currentPos = currentPos,
                inVehicle = IsPedInAnyVehicle(playerPed, false)
            })
        end
    end
    
    ::skipTeleportCheck::
    lastPosition = vector4(currentPos.x, currentPos.y, currentPos.z, GetGameTimer())
end

function CheckNoclip()
    if not Config.Protections.antiNoclip.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    
    -- Check if player is in noclip state
    if GetEntityCollision(playerPed) == false and not IsPedInAnyVehicle(playerPed, false) then
        local velocity = GetEntityVelocity(playerPed)
        local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
        
        -- If player is moving without collision and not falling
        if speed > 0.1 and velocity.z > -1.0 then
            protectionStates.noclipActive = true
            ReportDetection('NOCLIP', {
                collision = GetEntityCollision(playerPed),
                velocity = velocity,
                speed = speed,
                onGround = IsPedOnFoot(playerPed) and not IsPedFalling(playerPed)
            })
        end
    else
        protectionStates.noclipActive = false
    end
end

function CheckInvisibility()
    if not Config.Protections.antiInvisible.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    local alpha = GetEntityAlpha(playerPed)
    
    -- Check if player is invisible or nearly invisible
    if alpha < 100 and alpha > 0 then
        protectionStates.invisibleActive = true
        ReportDetection('INVISIBLE', {
            alpha = alpha,
            visible = IsEntityVisible(playerPed),
            collision = GetEntityCollision(playerPed)
        })
    else
        protectionStates.invisibleActive = false
    end
end

function CheckWeapons()
    if not Config.Protections.weaponProtection.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    
    -- Check all weapon slots
    for i = 0, 12 do
        local weaponHash = GetPedWeapontypeInSlot(playerPed, i)
        
        if weaponHash ~= GetHashKey('WEAPON_UNARMED') then
            local weaponName = GetWeapontypeDisplayName(weaponHash)
            
            -- Check against blacklist
            for _, blacklistedWeapon in ipairs(Config.BlacklistData.weapons) do
                if GetHashKey(blacklistedWeapon) == weaponHash then
                    ReportDetection('BLACKLISTED_WEAPON', {
                        weapon = blacklistedWeapon,
                        weaponHash = weaponHash,
                        weaponName = weaponName,
                        slot = i
                    })
                    
                    -- Remove the weapon
                    RemoveWeaponFromPed(playerPed, weaponHash)
                    break
                end
            end
            
            -- Check for explosive ammo
            if Config.Protections.antiExplosiveAmmo.enabled then
                local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponHash)
                if ammoType == GetHashKey('AMMO_RPG') or 
                   ammoType == GetHashKey('AMMO_GRENADE') or
                   ammoType == GetHashKey('AMMO_EXPLOSIVE') then
                    ReportDetection('EXPLOSIVE_AMMO', {
                        weapon = weaponName,
                        weaponHash = weaponHash,
                        ammoType = ammoType
                    })
                end
            end
        end
    end
end

function CheckVehicles()
    if not Config.Protections.vehicleProtection.enabled or isWhitelisted then return end
    
    local playerPed = PlayerPedId()
    
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        local vehicleModel = GetEntityModel(vehicle)
        local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
        
        -- Check against blacklist
        for _, blacklistedVehicle in ipairs(Config.BlacklistData.vehicles) do
            if GetHashKey(blacklistedVehicle) == vehicleModel then
                ReportDetection('BLACKLISTED_VEHICLE', {
                    vehicle = blacklistedVehicle,
                    vehicleModel = vehicleModel,
                    vehicleName = vehicleName,
                    engineHealth = GetVehicleEngineHealth(vehicle),
                    bodyHealth = GetVehicleBodyHealth(vehicle)
                })
                
                -- Remove player from vehicle
                TaskLeaveVehicle(playerPed, vehicle, 16)
                break
            end
        end
    end
end

function CheckEntitySpawning()
    if not Config.Protections.entityProtection.enabled or isWhitelisted then return end
    
    local currentTime = GetGameTimer()
    
    -- Reset entity count every second
    if currentTime - lastEntityReset > 1000 then
        entitySpawnCount = 0
        lastEntityReset = currentTime
    end
    
    entitySpawnCount = entitySpawnCount + 1
    
    -- Check for entity spam
    if entitySpawnCount > Config.Protections.entityProtection.maxSpawnRate then
        ReportDetection('ENTITY_SPAM', {
            count = entitySpawnCount,
            timeWindow = '1 second',
            maxAllowed = Config.Protections.entityProtection.maxSpawnRate
        })
    end
    
    -- Check total entity count around player
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearbyObjects = GetGamePool('CObject')
    local playerObjects = 0
    
    for _, obj in ipairs(nearbyObjects) do
        if #(GetEntityCoords(obj) - playerCoords) < 100.0 then
            playerObjects = playerObjects + 1
        end
    end
    
    if playerObjects > Config.Protections.entityProtection.maxEntitiesPerPlayer then
        ReportDetection('ENTITY_SPAM', {
            nearbyCount = playerObjects,
            maxAllowed = Config.Protections.entityProtection.maxEntitiesPerPlayer,
            type = 'nearby_objects'
        })
    end
end

function CheckBlacklistedObjects()
    if isWhitelisted then return end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearbyObjects = GetGamePool('CObject')
    
    for _, obj in ipairs(nearbyObjects) do
        if #(GetEntityCoords(obj) - playerCoords) < 50.0 then
            local objModel = GetEntityModel(obj)
            
            for _, blacklistedObj in ipairs(Config.BlacklistData.objects) do
                if GetHashKey(blacklistedObj) == objModel then
                    ReportDetection('BLACKLISTED_OBJECT', {
                        object = blacklistedObj,
                        objectModel = objModel,
                        coords = GetEntityCoords(obj),
                        distance = #(GetEntityCoords(obj) - playerCoords)
                    })
                    
                    -- Delete the object
                    DeleteObject(obj)
                    break
                end
            end
        end
    end
end

function CheckBlacklistedPeds()
    if isWhitelisted then return end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearbyPeds = GetGamePool('CPed')
    
    for _, ped in ipairs(nearbyPeds) do
        if ped ~= PlayerPedId() and #(GetEntityCoords(ped) - playerCoords) < 100.0 then
            local pedModel = GetEntityModel(ped)
            
            for _, blacklistedPed in ipairs(Config.BlacklistData.peds) do
                if GetHashKey(blacklistedPed) == pedModel then
                    ReportDetection('BLACKLISTED_PED', {
                        ped = blacklistedPed,
                        pedModel = pedModel,
                        coords = GetEntityCoords(ped),
                        distance = #(GetEntityCoords(ped) - playerCoords)
                    })
                    
                    -- Delete the ped
                    DeletePed(ped)
                    break
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADVANCED DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════════

function CheckLuaInjection()
    if not Config.Protections.antiLuaInjection.enabled or isWhitelisted then return end
    
    -- Check for common injection patterns in memory
    local suspiciousPatterns = {
        'ExecuteCommand',
        'TriggerServerEvent',
        'RegisterNetEvent',
        'AddEventHandler',
        'Citizen.CreateThread',
        'while true do',
        'loadstring',
        'debug.getupvalue',
        'debug.setupvalue'
    }
    
    -- This is a simplified check - in a real implementation, you'd need more sophisticated detection
    local consoleBuffer = GetConsoleBuffer()
    if consoleBuffer then
        for _, pattern in ipairs(suspiciousPatterns) do
            if string.find(consoleBuffer, pattern) then
                ReportDetection('LUA_INJECTION', {
                    pattern = pattern,
                    bufferSize = #consoleBuffer,
                    detectionMethod = 'console_buffer_scan'
                })
                break
            end
        end
    end
end

function CheckModMenus()
    if not Config.Protections.antiModMenu.enabled or isWhitelisted then return end
    
    -- Check for common mod menu indicators
    local commonMenus = {
        'Menyoo',
        'Enhanced Native Trainer',
        'Lambda Menu',
        'Modest Menu',
        'Kiddions',
        'Impulse',
        'Luna',
        'Cherax',
        'Phantom-X',
        '2Take1'
    }
    
    -- Check for mod menu files/processes (simplified)
    for _, menuName in ipairs(commonMenus) do
        -- This would require native checks or memory scanning in a real implementation
        local detected = false -- Placeholder
        
        if detected then
            ReportDetection('MOD_MENU', {
                menuName = menuName,
                detectionMethod = 'file_scan'
            })
        end
    end
    
    -- Check for common mod menu hotkeys being pressed
    local modMenuHotkeys = {
        {key = 166, name = 'F5'}, -- Common mod menu toggle
        {key = 167, name = 'F6'},
        {key = 168, name = 'F7'},
        {key = 169, name = 'F8'}
    }
    
    for _, hotkey in ipairs(modMenuHotkeys) do
        if IsControlJustPressed(0, hotkey.key) and IsControlPressed(0, 21) then -- SHIFT + Function key
            ReportDetection('MOD_MENU', {
                hotkey = hotkey.name,
                detectionMethod = 'hotkey_detection'
            })
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                PROTECTION THREADS
-- ═══════════════════════════════════════════════════════════════════════════════════

function StartProtectionThreads()
    -- Main detection loop
    CreateThread(function()
        while true do
            Wait(1000) -- Run every second
            
            if not isWhitelisted then
                -- Basic checks
                CheckWeapons()
                CheckVehicles()
                CheckBlacklistedObjects()
                CheckBlacklistedPeds()
                
                -- Advanced checks (less frequent)
                if GetGameTimer() % 5000 == 0 then -- Every 5 seconds
                    CheckLuaInjection()
                    CheckModMenus()
                end
            end
        end
    end)
    
    -- Entity spawning monitor
    CreateThread(function()
        while true do
            Wait(100) -- Check frequently for entity spawning
            
            if not isWhitelisted then
                CheckEntitySpawning()
            end
        end
    end)
    
    -- Performance monitoring
    CreateThread(function()
        while true do
            Wait(10000) -- Every 10 seconds
            
            local frameRate = GetFrameCount()
            local memoryUsage = GetResourceUsage()
            
            if frameRate < 30 then
                -- Low FPS might indicate cheating or system issues
                TriggerServerEvent('nchub_anticheat:performanceIssue', {
                    frameRate = frameRate,
                    memoryUsage = memoryUsage,
                    type = 'low_fps'
                })
            end
        end
    end)
end

function InitializeDetectionSystems()
    -- Hook into entity creation events
    AddEventHandler('entityCreating', function(entity)
        if not isWhitelisted then
            CheckEntitySpawning()
        end
    end)
    
    -- Hook into network events
    AddEventHandler('onResourceStart', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            -- Monitor for suspicious resource starts
            if Config.Debug then
                print('[NCHub AntiCheat] Resource started: ' .. resourceName)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                SERVER EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('nchub_anticheat:checkGodMode', function()
    CheckGodMode()
end)

RegisterNetEvent('nchub_anticheat:checkSpeed', function()
    CheckSpeedHack()
end)

RegisterNetEvent('nchub_anticheat:checkTeleport', function()
    CheckTeleport()
end)

RegisterNetEvent('nchub_anticheat:checkNoclip', function()
    CheckNoclip()
end)

RegisterNetEvent('nchub_anticheat:checkInvisible', function()
    CheckInvisibility()
end)

RegisterNetEvent('nchub_anticheat:setWhitelist', function(whitelisted)
    isWhitelisted = whitelisted
    
    if Config.Debug then
        print('[NCHub AntiCheat] Whitelist status: ' .. tostring(whitelisted))
    end
end)

RegisterNetEvent('nchub_anticheat:takeScreenshot', function(reason)
    if not Config.Screenshots.enabled then return end
    
    exports['screenshot-basic']:requestScreenshotUpload('https://api.example.com/upload', 'image', {
        headers = {
            ['Content-Type'] = 'multipart/form-data'
        }
    }, function(data)
        local response = json.decode(data)
        if response and response.url then
            TriggerServerEvent('nchub_anticheat:screenshotTaken', response.url)
        end
    end)
end)

RegisterNetEvent('nchub_anticheat:showAdminMenu', function()
    -- This would open an admin GUI in a real implementation
    -- For now, we'll just show some basic info in chat
    
    local stats = {
        violations = violationCount,
        protectionStates = protectionStates,
        whitelisted = isWhitelisted
    }
    
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 255 },
        multiline = true,
        args = { "AntiCheat Status", json.encode(stats, { indent = true }) }
    })
end)

RegisterNetEvent('nchub_anticheat:showLogStats', function(logStats)
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 255 },
        multiline = true,
        args = { "AntiCheat Log Stats", json.encode(logStats, { indent = true }) }
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

function GetConsoleBuffer()
    -- This would need native implementation
    -- For now, return nil
    return nil
end

function GetResourceUsage()
    -- Simplified resource usage check
    return collectgarbage('count') / 1024 -- Memory usage in MB
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                CLIENT COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════════

RegisterCommand('acstatus', function()
    local stats = {
        violations = violationCount,
        whitelisted = isWhitelisted,
        protections = protectionStates,
        lastPos = lastPosition,
        lastVel = lastVelocity
    }
    
    TriggerEvent('chat:addMessage', {
        color = { 0, 255, 0 },
        args = { "[AntiCheat]", "Status: " .. json.encode(stats, { indent = true }) }
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Cleanup when resource stops
        if Config.Debug then
            print('[NCHub AntiCheat] Client cleanup completed')
        end
    end
end)