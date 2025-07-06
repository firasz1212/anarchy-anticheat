-- NCHub AntiCheat Database Structure
-- Version: 1.0
-- Compatible with: MySQL 5.7+ / MariaDB 10.2+

-- Create anticheat_logs table for logging all detection events
CREATE TABLE IF NOT EXISTS `anticheat_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `player_name` varchar(50) NOT NULL,
    `player_identifier` varchar(100) NOT NULL,
    `steam_id` varchar(50) DEFAULT NULL,
    `discord_id` varchar(50) DEFAULT NULL,
    `license` varchar(100) DEFAULT NULL,
    `ip_address` varchar(45) DEFAULT NULL,
    `detection_type` varchar(50) NOT NULL,
    `detection_reason` text NOT NULL,
    `detection_details` longtext DEFAULT NULL,
    `action_taken` varchar(50) NOT NULL DEFAULT 'logged',
    `severity_level` int(1) NOT NULL DEFAULT 1,
    `server_id` varchar(10) DEFAULT NULL,
    `screenshot_url` varchar(255) DEFAULT NULL,
    `coords` varchar(100) DEFAULT NULL,
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_identifier` (`player_identifier`),
    KEY `idx_steam_id` (`steam_id`),
    KEY `idx_detection_type` (`detection_type`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create ban_table for managing player bans
CREATE TABLE IF NOT EXISTS `ban_table` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `player_name` varchar(50) NOT NULL,
    `player_identifier` varchar(100) NOT NULL,
    `steam_id` varchar(50) DEFAULT NULL,
    `discord_id` varchar(50) DEFAULT NULL,
    `license` varchar(100) DEFAULT NULL,
    `ip_address` varchar(45) DEFAULT NULL,
    `ban_reason` text NOT NULL,
    `ban_type` enum('permanent','temporary') NOT NULL DEFAULT 'permanent',
    `banned_by` varchar(50) NOT NULL,
    `ban_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ban_expires` timestamp NULL DEFAULT NULL,
    `is_active` tinyint(1) NOT NULL DEFAULT 1,
    `appeal_status` enum('none','pending','approved','denied') NOT NULL DEFAULT 'none',
    `ban_evidence` text DEFAULT NULL,
    `unban_reason` text DEFAULT NULL,
    `unbanned_by` varchar(50) DEFAULT NULL,
    `unban_date` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_active_ban` (`player_identifier`, `is_active`),
    KEY `idx_player_identifier` (`player_identifier`),
    KEY `idx_steam_id` (`steam_id`),
    KEY `idx_ban_type` (`ban_type`),
    KEY `idx_is_active` (`is_active`),
    KEY `idx_ban_expires` (`ban_expires`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create anticheat_whitelist for trusted players and admins
CREATE TABLE IF NOT EXISTS `anticheat_whitelist` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `player_identifier` varchar(100) NOT NULL,
    `steam_id` varchar(50) DEFAULT NULL,
    `player_name` varchar(50) NOT NULL,
    `whitelist_type` enum('admin','trusted','developer','bypass') NOT NULL DEFAULT 'trusted',
    `permission_level` int(1) NOT NULL DEFAULT 1,
    `added_by` varchar(50) NOT NULL,
    `reason` text DEFAULT NULL,
    `is_active` tinyint(1) NOT NULL DEFAULT 1,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_identifier` (`player_identifier`),
    KEY `idx_steam_id` (`steam_id`),
    KEY `idx_whitelist_type` (`whitelist_type`),
    KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create anticheat_statistics for system performance tracking
CREATE TABLE IF NOT EXISTS `anticheat_statistics` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `date` date NOT NULL,
    `total_detections` int(11) NOT NULL DEFAULT 0,
    `total_bans` int(11) NOT NULL DEFAULT 0,
    `false_positives` int(11) NOT NULL DEFAULT 0,
    `most_common_cheat` varchar(50) DEFAULT NULL,
    `server_uptime` bigint(20) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default admin entries (update identifiers as needed)
-- INSERT INTO `anticheat_whitelist` (`player_identifier`, `steam_id`, `player_name`, `whitelist_type`, `permission_level`, `added_by`, `reason`) VALUES
-- ('license:your_license_here', 'steam:your_steam_here', 'ServerOwner', 'admin', 5, 'system', 'Default server owner'),
-- ('license:admin_license_here', 'steam:admin_steam_here', 'AdminName', 'admin', 4, 'system', 'Default admin');

-- Triggers for automatic cleanup and maintenance
DELIMITER $$

CREATE TRIGGER IF NOT EXISTS `cleanup_old_logs` 
AFTER INSERT ON `anticheat_logs` 
FOR EACH ROW 
BEGIN 
    DELETE FROM `anticheat_logs` 
    WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 30 DAY) 
    AND `severity_level` < 3; 
END$$

CREATE TRIGGER IF NOT EXISTS `update_statistics`
AFTER INSERT ON `anticheat_logs`
FOR EACH ROW
BEGIN
    INSERT INTO `anticheat_statistics` (`date`, `total_detections`)
    VALUES (CURDATE(), 1)
    ON DUPLICATE KEY UPDATE `total_detections` = `total_detections` + 1;
END$$

DELIMITER ;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS `idx_logs_composite` ON `anticheat_logs` (`player_identifier`, `detection_type`, `timestamp`);
CREATE INDEX IF NOT EXISTS `idx_bans_composite` ON `ban_table` (`player_identifier`, `is_active`, `ban_expires`);

-- Views for easy data access
CREATE VIEW IF NOT EXISTS `active_bans` AS
SELECT 
    b.*,
    CASE 
        WHEN b.ban_type = 'permanent' THEN 'Never'
        WHEN b.ban_expires > NOW() THEN DATE_FORMAT(b.ban_expires, '%Y-%m-%d %H:%i:%s')
        ELSE 'Expired'
    END as expires_formatted
FROM `ban_table` b
WHERE b.is_active = 1 
AND (b.ban_type = 'permanent' OR (b.ban_type = 'temporary' AND b.ban_expires > NOW()));

CREATE VIEW IF NOT EXISTS `detection_summary` AS
SELECT 
    DATE(timestamp) as detection_date,
    detection_type,
    COUNT(*) as count,
    COUNT(DISTINCT player_identifier) as unique_players
FROM `anticheat_logs`
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(timestamp), detection_type
ORDER BY detection_date DESC, count DESC;