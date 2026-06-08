-- Migration: Create Device Tokens Table
CREATE TABLE IF NOT EXISTS `device_tokens` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `device_token` VARCHAR(255) NOT NULL,
    `platform` ENUM('ios', 'android') NOT NULL DEFAULT 'ios',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_user_device` (`user_id`, `device_token`),
    FOREIGN KEY (`user_id`) REFERENCES `airline_users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
