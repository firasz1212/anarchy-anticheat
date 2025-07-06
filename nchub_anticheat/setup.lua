-- NCHub AntiCheat Setup & Verification Script
-- Run this script to verify your installation and setup

local SetupScript = {}

print("^2[NCHub AntiCheat]^7 Starting setup verification...")

-- Check if QBCore is available
local function CheckQBCore()
    local success, QBCore = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    
    if success and QBCore then
        print("^2✓^7 QBCore Framework detected and working")
        return true
    else
        print("^1✗^7 QBCore Framework not found or not working")
        print("^3⚠^7 Please ensure QBCore is installed and started before nchub_anticheat")
        return false
    end
end

-- Check if oxmysql is available
local function CheckDatabase()
    local success = pcall(function()
        MySQL = exports.oxmysql
    end)
    
    if success and MySQL then
        print("^2✓^7 oxmysql detected and available")
        
        -- Test database connection
        MySQL.Async.fetchAll('SELECT 1 as test', {}, function(result)
            if result and result[1] then
                print("^2✓^7 Database connection successful")
            else
                print("^1✗^7 Database connection failed")
                print("^3⚠^7 Please check your MySQL connection settings")
            end
        end)
        return true
    else
        print("^1✗^7 oxmysql not found")
        print("^3⚠^7 Please ensure oxmysql is installed and configured")
        return false
    end
end

-- Check if screenshot-basic is available
local function CheckScreenshots()
    local success = pcall(function()
        return exports['screenshot-basic']
    end)
    
    if success then
        print("^2✓^7 screenshot-basic detected and available")
        return true
    else
        print("^3⚠^7 screenshot-basic not found (optional but recommended)")
        print("^7  Screenshot functionality will be disabled")
        return false
    end
end

-- Verify database tables exist
local function VerifyTables()
    local tables = {
        'anticheat_logs',
        'ban_table', 
        'anticheat_whitelist',
        'anticheat_statistics'
    }
    
    print("^3[Setup]^7 Verifying database tables...")
    
    for _, tableName in ipairs(tables) do
        MySQL.Async.fetchAll('SHOW TABLES LIKE ?', {tableName}, function(result)
            if result and #result > 0 then
                print("^2✓^7 Table exists: " .. tableName)
            else
                print("^1✗^7 Table missing: " .. tableName)
                print("^3⚠^7 Please run the SQL file: sql/anticheat.sql")
            end
        end)
    end
end

-- Check configuration
local function CheckConfiguration()
    print("^3[Setup]^7 Checking configuration...")
    
    -- Check if admin identifiers are set
    local adminCount = 0
    for identifier, admin in pairs(Config.Admins) do
        if identifier ~= 'license:your_license_here' then
            adminCount = adminCount + 1
        end
    end
    
    if adminCount > 0 then
        print("^2✓^7 Admin identifiers configured (" .. adminCount .. " admins)")
    else
        print("^3⚠^7 No admin identifiers configured")
        print("^7  Please update Config.Admins in configs/anticheat_config.lua")
    end
    
    -- Check Discord webhooks
    local webhookCount = 0
    for webhookType, url in pairs(Config.Logging.webhooks) do
        if url and url ~= 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE' then
            webhookCount = webhookCount + 1
        end
    end
    
    if webhookCount > 0 then
        print("^2✓^7 Discord webhooks configured (" .. webhookCount .. " webhooks)")
    else
        print("^3⚠^7 No Discord webhooks configured")
        print("^7  Discord logging will be disabled")
    end
    
    -- Check enabled protections
    local enabledProtections = 0
    for protectionName, protection in pairs(Config.Protections) do
        if protection.enabled then
            enabledProtections = enabledProtections + 1
        end
    end
    
    print("^2✓^7 Active protections: " .. enabledProtections .. "/" .. (function()
        local total = 0
        for _ in pairs(Config.Protections) do total = total + 1 end
        return total
    end)())
end

-- Create test detection
local function CreateTestDetection()
    print("^3[Setup]^7 Creating test detection entry...")
    
    local Logger = require('utils.logger')
    Logger.LogSystemAlert('NCHub AntiCheat setup completed successfully', {
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
        version = '1.0.0',
        setupStatus = 'complete'
    }, 1)
    
    print("^2✓^7 Test detection logged")
end

-- Display system status
local function DisplayStatus()
    print("^6" .. string.rep("=", 60))
    print("^6           NCHub AntiCheat - Setup Complete")
    print("^6" .. string.rep("=", 60))
    print("^2✓^7 System Status: ^2ACTIVE")
    print("^2✓^7 Version: ^31.0.0")
    print("^2✓^7 Resource: ^3" .. GetCurrentResourceName())
    print("^2✓^7 Framework: ^3QBCore")
    print("^6" .. string.rep("=", 60))
    print("^3Available Commands:")
    print("^7  /ncheat - Admin menu")
    print("^7  /banid <id> <reason> - Ban player")  
    print("^7  /kickid <id> <reason> - Kick player")
    print("^7  /logs - View statistics")
    print("^7  /acstatus - Check your status")
    print("^6" .. string.rep("=", 60))
    print("^2[NCHub AntiCheat]^7 Setup verification complete!")
end

-- Main setup function
function SetupScript.Run()
    CreateThread(function()
        Wait(5000) -- Wait for other resources to load
        
        print("^6" .. string.rep("=", 60))
        print("^6        NCHub AntiCheat - Setup Verification")
        print("^6" .. string.rep("=", 60))
        
        -- Run all checks
        local qbCheck = CheckQBCore()
        local dbCheck = CheckDatabase()
        local screenshotCheck = CheckScreenshots()
        
        Wait(2000) -- Wait for database checks
        
        if qbCheck and dbCheck then
            VerifyTables()
            CheckConfiguration()
            CreateTestDetection()
            
            Wait(1000)
            DisplayStatus()
        else
            print("^1[Setup Error]^7 Critical dependencies missing!")
            print("^7Please fix the above issues and restart the resource.")
        end
    end)
end

-- Auto-run setup on resource start
SetupScript.Run()

return SetupScript