# 🛡️ NCHub AntiCheat - Installation & Setup Guide

## 📋 Prerequisites

Before installing NCHub AntiCheat, ensure you have:

- **FiveM Server** with latest artifacts (recommended: 5848+)
- **QBCore Framework** (latest version)
- **oxmysql** resource for database operations
- **screenshot-basic** resource for screenshot functionality
- **MySQL/MariaDB** database server
- **Discord Webhooks** (optional but recommended)

## 🔧 Installation Steps

### 1. Download and Extract

```bash
cd resources
git clone https://github.com/nchub/nchub_anticheat.git
# or download and extract the ZIP file
```

### 2. Database Setup

Import the SQL file to create required tables:

```sql
mysql -u your_username -p your_database < nchub_anticheat/sql/anticheat.sql
```

Or manually execute the SQL file through phpMyAdmin/HeidiSQL.

### 3. Configuration

Edit `configs/anticheat_config.lua`:

```lua
-- Update these settings
Config.ServerName = 'Your Server Name'
Config.ServerId = '1' -- Unique identifier for your server

-- Admin Configuration
Config.Admins = {
    ['license:your_license_here'] = { level = 5, name = 'Server Owner' },
    ['license:admin_license_here'] = { level = 4, name = 'Head Admin' },
}

-- Discord Webhooks
Config.Logging.webhooks = {
    detections = 'YOUR_DETECTION_WEBHOOK_URL',
    bans = 'YOUR_BAN_WEBHOOK_URL',
    admin = 'YOUR_ADMIN_WEBHOOK_URL',
    system = 'YOUR_SYSTEM_WEBHOOK_URL',
}

-- Screenshot Settings
Config.Screenshots.webhookUrl = 'YOUR_SCREENSHOT_WEBHOOK_URL'
```

### 4. Server Configuration

Add to your `server.cfg`:

```cfg
# Core Dependencies
ensure oxmysql
ensure screenshot-basic

# AntiCheat System
ensure nchub_anticheat

# Set MySQL connection (if not already set)
set mysql_connection_string "mysql://username:password@localhost/database_name?charset=utf8mb4"
```

### 5. Permissions Setup

#### Option A: Database Whitelist
Execute this SQL to add admins:

```sql
INSERT INTO anticheat_whitelist (player_identifier, steam_id, player_name, whitelist_type, permission_level, added_by, reason) 
VALUES ('license:your_license', 'steam:your_steam', 'Your Name', 'admin', 5, 'system', 'Server Owner');
```

#### Option B: Config-based (Automatic)
Your admins are automatically loaded from the config file.

## ⚙️ Configuration Options

### Protection Modules

Enable/disable specific protections:

```lua
Config.Protections = {
    antiGodMode = { enabled = true, banOnDetection = false },
    antiSpeedHack = { enabled = true, banOnDetection = false },
    antiTeleport = { enabled = true, banOnDetection = false },
    antiNoclip = { enabled = true, banOnDetection = true },
    antiModMenu = { enabled = true, banOnDetection = true },
    -- ... more protections
}
```

### Logging Configuration

```lua
Config.Logging = {
    enableFileLogging = true,        -- JSON file logging
    enableDatabaseLogging = true,    -- MySQL logging
    enableDiscordLogging = true,     -- Discord webhooks
    enableConsoleLogging = true,     -- Server console
}
```

### Ban System

```lua
Config.BanSystem = {
    defaultBanTime = 0,              -- 0 = permanent, hours for temporary
    autoBanEnabled = true,           -- Auto-ban on multiple violations
    autoBanThreshold = 3,            -- Number of violations before auto-ban
}
```

### Screenshot & OCR

```lua
Config.Screenshots = {
    enabled = true,
    onDetection = true,              -- Auto-screenshot on detection
    onBan = true,                    -- Screenshot when banning
    quality = 0.8,                   -- Image quality (0.1-1.0)
}

Config.Advanced = {
    enableOCR = false,               -- Enable OCR text detection
    ocrKeywords = {                  -- Keywords to detect
        'cheat', 'hack', 'mod menu', 'trainer', 'inject'
    }
}
```

## 🎮 Usage Commands

### Player Commands
- `/acstatus` - View your anticheat status

### Admin Commands
- `/ncheat` - Open admin menu
- `/banid <id> <reason>` - Ban a player
- `/kickid <id> <reason>` - Kick a player  
- `/unbanid <identifier> <reason>` - Unban a player
- `/logs` - View log statistics
- `/acwhitelist <add/remove> <identifier>` - Manage whitelist
- `/acaction <1-7>` - Admin menu actions

### Admin Menu Options
1. View Live Detections
2. Player Statistics
3. System Status
4. Ban Management
5. Whitelist Management
6. Take Screenshot
7. Close Menu

## 🔍 Monitoring & Logs

### File Logs
Check `nchub_anticheat/cheatLogs.json` for JSON formatted logs.

### Database Logs
Query the `anticheat_logs` table:

```sql
SELECT * FROM anticheat_logs ORDER BY timestamp DESC LIMIT 50;
```

### Discord Notifications
Configure webhooks to receive real-time alerts in Discord.

## 🛠️ Troubleshooting

### Common Issues

**"Database connection failed"**
- Check MySQL credentials in oxmysql
- Ensure database exists and user has permissions
- Verify tables were created correctly

**"No recent detections found"**
- Check if protections are enabled in config
- Verify players are not whitelisted
- Check console for error messages

**"Discord webhooks not working"**
- Verify webhook URLs are correct and valid
- Check Discord server permissions
- Test webhooks manually

**"High resource usage"**
- Reduce check intervals in config
- Disable unnecessary protections
- Check for conflicting resources

### Debug Mode
Enable detailed logging:

```lua
Config.Debug = true
```

### Performance Optimization

```lua
Config.Advanced = {
    maxChecksPerSecond = 10,         -- Reduce for better performance
    enableResourceMonitoring = true, -- Monitor system resources
    maxResourceUsage = 2.0,          -- Max CPU usage %
}
```

## 🔄 Updates

### Automatic Updates (Git)
```bash
cd resources/nchub_anticheat
git pull origin main
restart nchub_anticheat
```

### Manual Updates
1. Backup your `configs/anticheat_config.lua`
2. Download latest version
3. Replace files (keep your config)
4. Check changelog for breaking changes
5. Restart resource

## 🏗️ Advanced Setup

### TxAdmin Integration
The system automatically detects and integrates with TxAdmin:

```lua
Config.Integrations.txadmin = {
    enabled = true,
    reportToTxAdmin = true,
    txAdminActions = true,
}
```

### Multi-Server Setup
For multiple servers, use unique server IDs:

```lua
Config.ServerId = '1'  -- Server 1
-- Config.ServerId = '2'  -- Server 2
```

### OCR Implementation
To implement real OCR detection:

1. Install Tesseract OCR on your server
2. Modify `SimulateOCRProcessing()` function
3. Add OCR processing logic
4. Enable OCR in config

## 📊 Statistics & Analytics

View system statistics:
- Database: Check `anticheat_statistics` table
- TxAdmin: Use `tx:anticheat:stats` command
- Discord: Automatic status updates

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section
2. Enable debug mode and check console
3. Review the configuration settings
4. Check Discord/GitHub for community support

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**⚠️ Important Security Notes:**
- Keep webhook URLs private and secure
- Regularly backup your database
- Monitor system performance
- Update regularly for security patches
- Never share database credentials publicly