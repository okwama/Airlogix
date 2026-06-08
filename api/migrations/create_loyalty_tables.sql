-- Create loyalty_tiers table
CREATE TABLE IF NOT EXISTS `loyalty_tiers` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM') NOT NULL,
    `min_points` INT(11) NOT NULL,
    `description` TEXT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed loyalty_tiers
INSERT INTO `loyalty_tiers` (`name`, `min_points`, `description`) VALUES
('BRONZE', 0, 'Entry level member benefits'),
('SILVER', 2001, 'Silver level member benefits with priority check-in'),
('GOLD', 5001, 'Gold level member benefits with lounge access'),
('PLATINUM', 10001, 'Premium level member benefits with all perks');

-- Create loyalty_points_history table
CREATE TABLE IF NOT EXISTS `loyalty_points_history` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `booking_id` INT(11) DEFAULT NULL,
    `points` INT(11) NOT NULL,
    `transaction_type` ENUM('EARN', 'REDEEM', 'ADJUSTMENT') NOT NULL,
    `description` VARCHAR(255),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (`id`),
    INDEX `idx_user_loyalty` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
