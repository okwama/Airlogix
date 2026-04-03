-- ============================================================
-- Airlogix Home Screen Seed Data
-- Run this to populate offers, hotels, experiences, and
-- ensure destinations have status='active'.
-- Safe to re-run (uses INSERT IGNORE).
-- ============================================================

-- ── 1. Activate all existing destinations ───────────────────
UPDATE destinations SET status = 'active' WHERE status != 'active';

-- ── 2. Experiences (complete-your-trip tiles) ───────────────
CREATE TABLE IF NOT EXISTS `experiences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `subtitle` varchar(255) DEFAULT NULL,
  `icon` varchar(50) DEFAULT NULL,
  `color_hex` varchar(10) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT IGNORE INTO `experiences` (`id`, `title`, `subtitle`, `icon`, `color_hex`, `is_active`) VALUES
(1, 'Lounge Access', 'Relax before your flight', 'sofa', '#7209B7', 1),
(2, 'Tours & Activities', 'Explore your destination', 'map', '#06D6A0', 1),
(3, 'Travel Insurance', 'Fly worry-free', 'shield', '#F72585', 1),
(4, 'Car Hire', 'Book a ride on arrival', 'car', '#3A86FF', 1);

-- ── 3. Offers & Packages ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `offers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `promo_code` varchar(50) DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT IGNORE INTO `offers` (`id`, `title`, `description`, `image_url`, `promo_code`, `expiry_date`, `is_active`) VALUES
(1, '20% Off Mombasa Beach', 'Enjoy the coast with our exclusive summer deal on all NBO-MBA routes.', NULL, 'BEACH20', DATE_ADD(CURDATE(), INTERVAL 60 DAY), 1),
(2, 'Business Class Upgrade', 'Upgrade to Business Class from just $99 extra on selected routes.', NULL, 'BIZ99', DATE_ADD(CURDATE(), INTERVAL 30 DAY), 1),
(3, 'Island Getaway – Comoros', 'Fly Mombasa to Moroni from KES 18,000. Limited seats!', NULL, 'ISLAND18', DATE_ADD(CURDATE(), INTERVAL 45 DAY), 1);

-- ── 4. Partner Hotels ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `hotels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `location` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `price_per_night` decimal(10,2) DEFAULT NULL,
  `rating` decimal(3,1) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT IGNORE INTO `hotels` (`id`, `name`, `location`, `description`, `image_url`, `price_per_night`, `rating`, `is_active`) VALUES
(1, 'Sarova Whitesands', 'Mombasa, Kenya', 'Beachfront luxury resort on Bamburi Beach.', NULL, 12500.00, 4.7, 1),
(2, 'Serena Hotel Nairobi', 'Nairobi, Kenya', 'Five-star elegance in the heart of Nairobi.', NULL, 18000.00, 4.8, 1),
(3, 'Speke Hotel', 'Kampala, Uganda', 'Historic hotel steps from Kampala city centre.', NULL, 8500.00, 4.2, 1),
(4, 'Kigali Marriott', 'Kigali, Rwanda', 'Premium stays in Rwanda\'s capital city.', NULL, 15000.00, 4.6, 1);
