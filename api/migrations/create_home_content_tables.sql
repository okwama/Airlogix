-- Migration: Create Home Screen Content Tables

-- 1. Offers Table
CREATE TABLE IF NOT EXISTS `offers` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT NOT NULL,
    `image_url` VARCHAR(255),
    `promo_code` VARCHAR(50),
    `expiry_date` DATE,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 2. Hotels Table
CREATE TABLE IF NOT EXISTS `hotels` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `location` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `image_url` VARCHAR(255),
    `price_per_night` DECIMAL(10,2),
    `rating` DECIMAL(2,1),
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 3. Experiences Table
CREATE TABLE IF NOT EXISTS `experiences` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(255) NOT NULL,
    `subtitle` VARCHAR(255),
    `icon` VARCHAR(50),
    `color_hex` VARCHAR(10),
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Seed Data
INSERT INTO `offers` (`title`, `description`, `promo_code`) VALUES 
('Launch Offer', 'Get 20% off your first booking', 'ROYAL20'),
('Weekend Getaway', 'Fly to Mombasa this weekend for less', 'BEACHVIBES');

INSERT INTO `hotels` (`name`, `location`, `price_per_night`, `rating`) VALUES 
('Royal Palm Hotel', 'Moroni, Comoros', 150.00, 4.8),
('Ocean Breeze Resort', 'Nairobi, Kenya', 120.00, 4.5);

INSERT INTO `experiences` (`title`, `subtitle`, `icon`, `color_hex`) VALUES 
('Lounge Access', 'Premium access', 'sofa.fill', '#7209B7'),
('Tours & Activities', 'Explore more', 'map.fill', '#06D6A0');
