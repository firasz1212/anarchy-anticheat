-- ███████╗ ██████╗██████╗ ███████╗███████╗███╗   ██╗███████╗██╗  ██╗ ██████╗ ████████╗
-- ██╔════╝██╔════╝██╔══██╗██╔════╝██╔════╝████╗  ██║██╔════╝██║  ██║██╔═══██╗╚══██╔══╝
-- ███████╗██║     ██████╔╝█████╗  █████╗  ██╔██╗ ██║███████╗███████║██║   ██║   ██║   
-- ╚════██║██║     ██╔══██╗██╔══╝  ██╔══╝  ██║╚██╗██║╚════██║██╔══██║██║   ██║   ██║   
-- ███████║╚██████╗██║  ██║███████╗███████╗██║ ╚████║███████║██║  ██║╚██████╔╝   ██║   
-- ╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   

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

-- ██████╗██╗     ██╗███████╗███╗   ██╗████████╗
-- ██╔════╝██║     ██║██╔════╝████╗  ██║╚══██╔══╝
-- ██║     ██║     ██║█████╗  ██╔██╗ ██║   ██║   
-- ██║     ██║     ██║██╔══╝  ██║╚██╗██║   ██║   
-- ╚██████╗███████╗██║███████╗██║ ╚████║   ██║   
--  ╚═════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝

function CheckModMenuKeybinds()
    if not Config.Protections.antiModMenu.enabled or isWhitelisted then return end
    
    -- Common mod menu injection keys
    local suspiciousKeys = {
        {key = 112, name = 'F1'}, {key = 113, name = 'F2'}, {key = 115, name = 'F4'}, 
        {key = 119, name = 'F8'}, {key = 121, name = 'F10'}, {key = 45, name = 'Insert'}, 
        {key = 46, name = 'Delete'}, {key = 36, name = 'Home'}, {key = 35, name = 'End'},
        {key = 96, name = 'Numpad0'}, {key = 97, name = 'Numpad1'}, {key = 98, name = 'Numpad2'},
        {key = 99, name = 'Numpad3'}, {key = 100, name = 'Numpad4'}, {key = 101, name = 'Numpad5'},
        {key = 144, name = 'NumLock'}, {key = 145, name = 'ScrollLock'}
    }
    
    for _, keyData in ipairs(suspiciousKeys) do
        if IsControlJustPressed(0, keyData.key) then
            -- Check if any suspicious overlay or menu appears after keypress
            CreateThread(function()
                Wait(500) -- Wait half second to see if menu appears
                
                -- Check for common mod menu window titles or elements
                local suspiciousElements = CheckForSuspiciousElements()
                if suspiciousElements.found then
                    ReportDetection('MOD_MENU_KEYBIND', {
                        key = keyData.name,
                        keyCode = keyData.key,
                        elements = suspiciousElements.elements,
                        detectionMethod = 'keybind_detection'
                    })
                    
                    -- Take screenshot for evidence
                    if Config.Screenshots.enabled then
                        TakeScreenshotWithOCR('Mod menu keybind detected: ' .. keyData.name)
                    end
                end
            end)
        end
    end
end

function CheckForSuspiciousElements()
    -- Check for common mod menu indicators
    local suspiciousElements = {}
    local found = false
    
    -- Check for common mod menu text elements
    local menuIndicators = {
        'MENU', 'TRAINER', 'CHEAT', 'HACK', 'MOD', 'INJECT', 'BYPASS',
        'REDENGINE', 'LYNX', 'ELIXIR', 'LUNA', 'MENYOO', 'LAMBDA',
        'IMPULSE', 'CHERAX', 'PHANTOM', '2TAKE1', 'KIDDIONS'
    }
    
    -- This is a simplified check - in reality you'd need native memory scanning
    for _, indicator in ipairs(menuIndicators) do
        -- Placeholder for actual detection logic
        local detected = false -- Would implement actual detection here
        
        if detected then
            table.insert(suspiciousElements, indicator)
            found = true
        end
    end
    
    return {found = found, elements = suspiciousElements}
end

function TakeScreenshotWithOCR(reason)
    if not Config.Screenshots.enabled then return end
    
    exports['screenshot-basic']:requestScreenshotUpload('https://api.example.com/upload', 'image', {
        headers = {},
        isVideo = false,
        isUpload = Config.Screenshots.uploadToWebhook,
        encoding = Config.Screenshots.encoding or 'jpg',
        quality = Config.Screenshots.quality or 0.8
    }, function(data)
        if data then
            -- Send screenshot data to server for OCR processing
            TriggerServerEvent('nchub_anticheat:screenshotTaken', data, reason)
            
            -- If OCR is enabled, analyze the screenshot
            if Config.Advanced.enableOCR then
                AnalyzeScreenshotForOCR(data, reason)
            end
        end
    end)
end

function AnalyzeScreenshotForOCR(screenshotData, reason)
    if not Config.Advanced.enableOCR then return end
    
    -- This would require additional OCR library implementation
    -- For now, we'll simulate OCR detection by checking known patterns
    
    local suspiciousKeywords = Config.Advanced.ocrKeywords or {
        'cheat', 'hack', 'mod menu', 'trainer', 'inject',
        'bypass', 'exploit', 'aimbot', 'wallhack', 'esp',
        'speed hack', 'fly hack', 'god mode', 'infinite',
        'redengine', 'lynx', 'elixir', 'luna', 'menyoo'
    }
    
    -- Simulate OCR text extraction (in reality this would use an OCR library)
    local extractedText = SimulateOCRExtraction(screenshotData)
    
    local detectedKeywords = {}
    for _, keyword in ipairs(suspiciousKeywords) do
        if string.find(string.lower(extractedText), string.lower(keyword)) then
            table.insert(detectedKeywords, keyword)
        end
    end
    
    if #detectedKeywords > 0 then
        ReportDetection('OCR_DETECTION', {
            reason = reason,
            detectedKeywords = detectedKeywords,
            extractedText = extractedText,
            screenshotSize = #screenshotData
        })
    end
end

function SimulateOCRExtraction(screenshotData)
    -- This is a placeholder function - in reality you would use an actual OCR library
    -- such as Tesseract.js or a cloud-based OCR service
    return ""
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ENHANCED TRIGGER PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════════════

local originalTriggerServerEvent = TriggerServerEvent
local eventCallCount = {}
local lastEventTime = {}

-- Override TriggerServerEvent to monitor usage
TriggerServerEvent = function(eventName, ...)
    if isWhitelisted then
        return originalTriggerServerEvent(eventName, ...)
    end
    
    local currentTime = GetGameTimer()
    
    -- Initialize tracking for this event
    if not eventCallCount[eventName] then
        eventCallCount[eventName] = 0
        lastEventTime[eventName] = currentTime
    end
    
    -- Reset counter every second
    if currentTime - lastEventTime[eventName] > 1000 then
        eventCallCount[eventName] = 0
        lastEventTime[eventName] = currentTime
    end
    
    eventCallCount[eventName] = eventCallCount[eventName] + 1
    
    -- Check for spam
    if eventCallCount[eventName] > 20 then -- Max 20 events per second
        ReportDetection('TRIGGER_SPAM', {
            eventName = eventName,
            count = eventCallCount[eventName],
            timeWindow = '1 second'
        })
        return -- Block the event
    end
    
    -- Check against blacklisted events
    for _, blacklistedEvent in ipairs(Config.BlacklistData.events) do
        if string.match(eventName, blacklistedEvent:gsub('%*', '.*')) then
            ReportDetection('BLACKLISTED_TRIGGER', {
                eventName = eventName,
                blacklistedPattern = blacklistedEvent
            })
            return -- Block the event
        end
    end
    
    -- Check for suspicious patterns
    local suspiciousPatterns = {
        '__cfx_internal', 'esx:', 'qb%-core:', 'bank:', 'atm:', 
        'admin', 'money', 'cash', 'society'
    }
    
    for _, pattern in ipairs(suspiciousPatterns) do
        if string.find(string.lower(eventName), pattern) then
            ReportDetection('SUSPICIOUS_TRIGGER', {
                eventName = eventName,
                suspiciousPattern = pattern
            })
        end
    end
    
    return originalTriggerServerEvent(eventName, ...)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                GLOBAL ENVIRONMENT PROTECTION
-- ═══════════════════════════════════════════════════════════════════════════════════

local originalGetGlobal = getmetatable(_G).__index
local originalSetGlobal = getmetatable(_G).__newindex

-- Monitor global variable access
getmetatable(_G).__index = function(table, key)
    if not isWhitelisted and type(key) == 'string' then
        -- Check for suspicious global access
        local suspiciousGlobals = {
            'debug', 'loadstring', 'load', 'dofile', 'loadfile',
            'require', 'package', 'io', 'os', 'file'
        }
        
        for _, suspiciousGlobal in ipairs(suspiciousGlobals) do
            if key == suspiciousGlobal then
                ReportDetection('SUSPICIOUS_GLOBAL_ACCESS', {
                    globalName = key,
                    accessType = 'read'
                })
                break
            end
        end
    end
    
    return originalGetGlobal(table, key)
end

-- Monitor global variable injection
getmetatable(_G).__newindex = function(table, key, value)
    if not isWhitelisted and type(key) == 'string' then
        -- Check for injection attempts
        local injectionPatterns = {
            'cheat', 'hack', 'menu', 'trainer', 'exploit',
            'bypass', 'injection', 'mod'
        }
        
        for _, pattern in ipairs(injectionPatterns) do
            if string.find(string.lower(key), pattern) then
                ReportDetection('GLOBAL_INJECTION', {
                    globalName = key,
                    valueType = type(value),
                    accessType = 'write'
                })
                return -- Block the injection
            end
        end
    end
    
    return originalSetGlobal(table, key, value)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                THREAD MONITORING
-- ═══════════════════════════════════════════════════════════════════════════════════

local threadCount = 0
local originalCreateThread = CreateThread

-- Monitor thread creation for suspicious activity
CreateThread = function(fn)
    if not isWhitelisted then
        threadCount = threadCount + 1
        
        -- Check for excessive thread creation
        if threadCount > 50 then
            ReportDetection('THREAD_SPAM', {
                threadCount = threadCount,
                threshold = 50
            })
        end
        
        -- Monitor the thread function for suspicious patterns
        local fnString = tostring(fn)
        local suspiciousPatterns = {
            'while true do', 'infinite', 'loop', 'TriggerServerEvent',
            'exploit', 'cheat', 'hack'
        }
        
        for _, pattern in ipairs(suspiciousPatterns) do
            if string.find(fnString, pattern) then
                ReportDetection('SUSPICIOUS_THREAD', {
                    pattern = pattern,
                    threadFunction = fnString:sub(1, 200) -- First 200 chars
                })
                break
            end
        end
    end
    
    return originalCreateThread(fn)
end

-- Reset thread count periodically
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        threadCount = 0
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ENHANCED PROTECTION THREADS
-- ═══════════════════════════════════════════════════════════════════════════════════

-- Add mod menu keybind detection to existing protection threads
function StartProtectionThreads()
    -- Mod menu keybind detection
    if Config.Protections.antiModMenu.enabled then
        CreateThread(function()
            while true do
                Wait(100) -- Check every 100ms for responsive keybind detection
                CheckModMenuKeybinds()
            end
        end)
    end
    
    -- Enhanced lua injection detection
    if Config.Protections.antiLuaInjection.enabled then
        CreateThread(function()
            while true do
                Wait(Config.Protections.antiLuaInjection.checkInterval)
                CheckLuaInjection()
                CheckForInfiniteLoops()
            end
        end)
    end
    
    -- Resource monitoring
    if Config.Advanced.enableResourceMonitoring then
        CreateThread(function()
            while true do
                Wait(30000) -- Every 30 seconds
                CheckUnauthorizedResources()
            end
        end)
    end
end

function CheckForInfiniteLoops()
    -- Monitor for suspicious infinite loops that might indicate injection
    local startTime = GetGameTimer()
    local checkDuration = 1000 -- 1 second
    local maxIterations = 10000
    
    for i = 1, maxIterations do
        if GetGameTimer() - startTime > checkDuration then
            break
        end
        -- Simulate checking for runaway loops
    end
    
    if GetGameTimer() - startTime > checkDuration * 2 then
        ReportDetection('INFINITE_LOOP_DETECTED', {
            duration = GetGameTimer() - startTime,
            expectedDuration = checkDuration
        })
    end
end

function CheckUnauthorizedResources()
    -- Get list of currently running resources
    local resourceCount = GetNumResources()
    local suspiciousResources = {}
    
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        
        if resourceName then
            -- Check for suspicious resource names
            local suspiciousNames = {
                'cheat', 'hack', 'menu', 'trainer', 'exploit',
                'bypass', 'inject', 'mod', 'unknown'
            }
            
            for _, suspiciousName in ipairs(suspiciousNames) do
                if string.find(string.lower(resourceName), suspiciousName) then
                    table.insert(suspiciousResources, resourceName)
                    break
                end
            end
        end
    end
    
    if #suspiciousResources > 0 then
        ReportDetection('UNAUTHORIZED_RESOURCE', {
            resources = suspiciousResources,
            totalResources = resourceCount
        })
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
--                                ADMIN GUI FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('nchub_anticheat:showAdminMenu', function()
    -- Simple text-based admin menu (can be enhanced with NUI later)
    local menuOptions = {
        '1. View Live Detections',
        '2. Player Statistics', 
        '3. System Status',
        '4. Ban Management',
        '5. Whitelist Management',
        '6. Take Screenshot',
        '7. Close Menu'
    }
    
    -- Display menu (simplified - in reality you'd want a proper UI)
    for _, option in ipairs(menuOptions) do
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 255},
            multiline = true,
            args = {'[AntiCheat Admin]', option}
        })
    end
    
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 0},
        multiline = true,
        args = {'[AntiCheat Admin]', 'Use /acaction <number> to select an option'}
    })
end)

RegisterNetEvent('nchub_anticheat:showLogStats', function(stats)
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {'[AntiCheat Stats]', 'Queue Size: ' .. stats.queueSize}
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {'[AntiCheat Stats]', 'Processing: ' .. tostring(stats.isProcessing)}
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {'[AntiCheat Stats]', 'File Logging: ' .. tostring(stats.fileLogging)}
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {'[AntiCheat Stats]', 'Database Logging: ' .. tostring(stats.databaseLogging)}
    })
end)

-- Admin action command
RegisterCommand('acaction', function(source, args, rawCommand)
    local action = tonumber(args[1])
    
    if not action then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {'[AntiCheat]', 'Invalid action number'}
        })
        return
    end
    
    if action == 1 then
        TriggerServerEvent('nchub_anticheat:requestLiveDetections')
    elseif action == 2 then
        TriggerServerEvent('nchub_anticheat:requestPlayerStats')
    elseif action == 3 then
        TriggerServerEvent('nchub_anticheat:requestSystemStatus')
    elseif action == 6 then
        local targetId = tonumber(args[2])
        if targetId then
            TriggerServerEvent('nchub_anticheat:adminTakeScreenshot', targetId)
        else
            TriggerEvent('chat:addMessage', {
                color = {255, 0, 0},
                multiline = true,
                args = {'[AntiCheat]', 'Usage: /acaction 6 <player_id>'}
            })
        end
    elseif action == 7 then
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {'[AntiCheat]', 'Admin menu closed'}
        })
    end
end, false)

-- Player status command for debugging
RegisterCommand('acstatus', function(source, args, rawCommand)
    TriggerServerEvent('nchub_anticheat:requestPlayerStatus')
end, false)

RegisterNetEvent('nchub_anticheat:showPlayerStatus', function(status)
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 255},
        multiline = true,
        args = {'[AntiCheat Status]', 'Whitelisted: ' .. tostring(status.whitelisted)}
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 255},
        multiline = true,
        args = {'[AntiCheat Status]', 'Violations: ' .. status.violations}
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 255},
        multiline = true,
        args = {'[AntiCheat Status]', 'Protected: ' .. tostring(status.protected)}
    })
end)