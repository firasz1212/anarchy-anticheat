# 🛡️ NCHub AntiCheat System

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/nchub/anticheat)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-green.svg)](https://fivem.net/)
[![QBCore](https://img.shields.io/badge/QBCore-Compatible-purple.svg)](https://github.com/qbcore-framework)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

A comprehensive, production-ready AntiCheat system for FiveM QBCore roleplay servers. Built with advanced detection methods, comprehensive logging, and seamless TxAdmin integration.

## 🚀 Features

### 🔍 Detection Systems
- **God Mode Detection** - Detects invincibility and abnormal health/armor values
- **Speed Hack Detection** - Monitors player movement speed and velocity
- **Teleportation Detection** - Catches impossible position changes
- **Noclip Detection** - Identifies collision bypass attempts
- **Invisibility Detection** - Detects players with modified transparency
- **Lua Injection Detection** - Advanced code injection monitoring
- **Mod Menu Detection** - Identifies common cheat menus
- **Weapon Protection** - Blacklist system for prohibited weapons
- **Vehicle Protection** - Blacklist system for restricted vehicles
- **Entity Spawning Protection** - Prevents object/ped spawning abuse
- **Event Protection** - Rate limiting and blacklist for server events

### 📊 Logging & Reporting
- **Multi-Format Logging** - JSON files, MySQL database, Discord webhooks
- **Screenshot Integration** - Automatic screenshot capture on detection
- **TxAdmin Integration** - Seamless reporting to TxAdmin dashboard
- **Real-time Notifications** - Instant Discord alerts for violations
- **Comprehensive Statistics** - Detailed analytics and reporting

### 👨‍💼 Administration
- **Permission-Based Admin System** - Multiple permission levels
- **Advanced Ban Management** - Permanent and temporary bans
- **Whitelist System** - Exempt trusted players and staff
- **Live Commands** - In-game commands for real-time management
- **Appeal System** - Built-in ban appeal tracking

### ⚡ Performance & Optimization
- **Low Resource Usage** - Optimized for minimal server impact
- **Configurable Intervals** - Adjust check frequencies
- **Smart Exemptions** - Job, location, and time-based exemptions
- **Background Processing** - Asynchronous logging and reporting

## 📋 Requirements

- **FiveM Server** with latest artifacts
- **QBCore Framework** (latest version)
- **oxmysql** resource for database operations
- **screenshot-basic** resource for screenshot functionality
- **MySQL/MariaDB** database server
- **Discord Webhooks** (optional but recommended)

## 🛠️ Installation

### 1. Download and Extract
```bash
cd resources
git clone https://github.com/nchub/nchub_anticheat.git
```

### 2. Database Setup
Import the SQL file to create required tables:
```sql
mysql -u username -p database_name < nchub_anticheat/sql/anticheat.sql
```

### 3. Configuration
Edit `configs/anticheat_config.lua`:

```lua
-- Core Settings
Config.ServerName = 'Your Server Name'
Config.ServerId = '1'

-- Database Settings
Config.Database = {
    useMySQL = true,
    logsTable = 'anticheat_logs',
    banTable = 'ban_table',
    whitelistTable = 'anticheat_whitelist',
    statisticsTable = 'anticheat_statistics'
}

-- Admin Permissions
Config.Admins = {
    ['license:your_license_here'] = { level = 5, name = 'Server Owner' },
    ['steam:110000000000000'] = { level = 4, name = 'Head Admin' },
}

-- Discord Webhooks
Config.Logging.webhooks = {
    detections = 'YOUR_WEBHOOK_URL_HERE',
    bans = 'YOUR_BAN_WEBHOOK_URL_HERE',
    admin = 'YOUR_ADMIN_WEBHOOK_URL_HERE',
    system = 'YOUR_SYSTEM_WEBHOOK_URL_HERE',
}
```

### 4. Server Configuration
Add to your `server.cfg`:
```cfg
ensure oxmysql
ensure screenshot-basic
ensure nchub_anticheat
```

### 5. Permissions (Optional)
Grant yourself admin permissions by adding your identifier to the config or database:
```sql
INSERT INTO anticheat_whitelist (player_identifier, steam_id, player_name, whitelist_type, permission_level, added_by, reason) 
VALUES ('license:your_license', 'steam:your_steam', 'Your Name', 'admin', 5, 'system', 'Server Owner');
```

## ⚙️ Configuration Guide

### Protection Modules
Each protection can be individually configured:

```lua
Config.Protections = {
    antiGodMode = {
        enabled = true,
        banOnDetection = false,
        checkInterval = 8000,
        maxHealth = 200,
        maxArmor = 100,
    },
    -- ... other protections
}
```

### Admin Permission Levels
- **Level 1**: Basic Admin (kick, view logs)
- **Level 2**: Moderator (ban, unban, advanced logs)
- **Level 3**: Senior Admin (whitelist management)
- **Level 4**: Head Admin (config management)
- **Level 5**: Super Admin (full access)

### Blacklist Configuration
Add items to blacklists in the config:

```lua
Config.BlacklistData = {
    weapons = {
        'WEAPON_RAILGUN',
        'WEAPON_MINIGUN',
        -- Add more weapons
    },
    vehicles = {
        'RHINO',
        'LAZER',
        -- Add more vehicles
    },
    -- ... other blacklists
}
```

### Exemption System
Configure exemptions for specific scenarios:

```lua
Config.Exemptions = {
    exemptJobs = {'police', 'ambulance', 'mechanic'},
    exemptVehicles = {'POLICE', 'AMBULANCE'},
    exemptZones = {
        { coords = vector3(-1038.75, -2745.8, 21.3), radius = 100.0 },
    },
    exemptHours = {2, 3, 4, 5}, -- 2 AM to 5 AM
}
```

## 🎮 Usage

### Admin Commands
- `/ncheat` - Open admin menu
- `/banid <id> <reason>` - Ban a player
- `/kickid <id> <reason>` - Kick a player
- `/unbanid <identifier> <reason>` - Unban a player
- `/logs` - View log statistics
- `/acwhitelist <identifier>` - Manage whitelist

### Player Commands
- `/acstatus` - View your anticheat status (debug)

### Exports for Other Resources
```lua
-- Check if player is flagged as cheater
local isCheater = exports['nchub_anticheat']:isCheater(source)

-- Check if player is whitelisted
local isWhitelisted = exports['nchub_anticheat']:isPlayerWhitelisted(source)

-- Ban a player programmatically
exports['nchub_anticheat']:banPlayer(source, 'Reason', 'Admin Name', 24) -- 24 hour ban

-- Log a custom detection
exports['nchub_anticheat']:logDetection(source, 'CUSTOM_DETECTION', 'Custom reason', {details}, 'logged', 2)
```

## 📊 Discord Integration

### Webhook Setup
1. Create Discord webhooks in your server
2. Add webhook URLs to the config
3. Configure Discord settings:

```lua
Config.Logging.discordSettings = {
    username = 'NCHub AntiCheat',
    avatar = 'YOUR_AVATAR_URL',
    color = 16711680, -- Red color
    pingRole = '<@&YOUR_ADMIN_ROLE_ID>',
}
```

### Webhook Types
- **Detections**: All anticheat detections
- **Bans**: Player ban notifications
- **Admin**: Administrative actions
- **System**: System alerts and status updates

## 🔧 TxAdmin Integration

### Features
- Automatic reporting to TxAdmin dashboard
- TxAdmin action logging
- Console commands for statistics
- Seamless ban/kick integration

### Commands (TxAdmin Console)
```bash
tx:anticheat:stats       # View anticheat statistics
tx:anticheat:player <id> # Get player information
```

## 📈 Performance Optimization

### Resource Usage
- CPU Usage: < 2% with default settings
- Memory Usage: ~5-10MB RAM
- Network Usage: Minimal (only reporting)

### Optimization Tips
1. **Adjust Check Intervals**: Increase intervals for better performance
2. **Disable Unused Protections**: Turn off protections you don't need
3. **Configure Exemptions**: Reduce false positives with proper exemptions
4. **Database Optimization**: Regular cleanup of old logs

### Performance Settings
```lua
Config.Advanced = {
    maxChecksPerSecond = 10,
    enableResourceMonitoring = true,
    maxResourceUsage = 2.0,
}
```

## 🐛 Troubleshooting

### Common Issues

**Database Connection Failed**
- Check MySQL credentials in oxmysql
- Ensure database exists and tables are created
- Verify database permissions

**Detections Not Working**
- Check if protections are enabled in config
- Verify player is not whitelisted
- Check console for error messages

**Discord Webhooks Not Working**
- Verify webhook URLs are correct
- Check Discord server permissions
- Test webhook URLs manually

**High Resource Usage**
- Reduce check intervals
- Disable unnecessary protections
- Check for conflicting resources

### Debug Mode
Enable debug mode for detailed logging:
```lua
Config.Debug = true
```

## 🔄 Updates

### Automatic Updates
```bash
cd resources/nchub_anticheat
git pull origin main
restart nchub_anticheat
```

### Manual Updates
1. Backup your config file
2. Download latest version
3. Replace files (keep your config)
4. Check changelog for breaking changes
5. Restart resource

## 🤝 Support

### Getting Help
- **Documentation**: Check this README first
- **Discord**: Join our Discord server
- **GitHub Issues**: Report bugs and feature requests
- **Community**: QBCore Discord community

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- **NCHub Development Team** - Main development
- **QBCore Framework** - Framework integration
- **FiveM Community** - Testing and feedback
- **Contributors** - Bug reports and improvements

## 📋 Changelog

### Version 1.0.0
- Initial release
- All core features implemented
- Full QBCore integration
- TxAdmin integration
- Discord webhook support
- Screenshot integration
- Comprehensive logging system

---

**⚠️ Important**: This anticheat system is designed for legitimate server protection. Always ensure compliance with FiveM Terms of Service and applicable laws in your jurisdiction.

**🔒 Security Note**: Keep your configuration file secure and never share webhook URLs or database credentials publicly.

For the latest updates and information, visit our [GitHub repository](https://github.com/nchub/nchub_anticheat).