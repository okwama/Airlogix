-- ========================================
-- RoyalAir Airline Tables Migration
-- Creates only missing tables for booking system
-- Uses existing: flight_series, destinations, passengers, aircrafts
-- ========================================

-- --------------------------------------------------------
-- 1. AIRLINE USERS (Customers)
-- Separate from staff table for airline passengers
-- --------------------------------------------------------
CREATE TABLE `airline_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone_number` varchar(20) UNIQUE NOT NULL,
  `email` varchar(255) UNIQUE DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `passport_number` varchar(50) DEFAULT NULL,
  `passport_expiry_date` date DEFAULT NULL,
  `frequent_flyer_number` varchar(50) UNIQUE DEFAULT NULL,
  `profile_photo_url` varchar(512) DEFAULT NULL,
  `status` enum('active', 'suspended', 'deleted') DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  INDEX `idx_phone` (`phone_number`),
  INDEX `idx_email` (`email`),
  INDEX `idx_ff_number` (`frequent_flyer_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 2. CABIN CLASSES
-- Economy, Business, First class pricing
-- --------------------------------------------------------
CREATE TABLE `cabin_classes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT 'Economy, Business, First',
  `subtitle` varchar(100) DEFAULT NULL COMMENT 'e.g., Classic, Comfort',
  `base_price` decimal(10,2) NOT NULL,
  `baggage_allowance_kg` int(11) DEFAULT 20,
  `cabin_baggage_kg` int(11) DEFAULT 7,
  `priority_boarding` tinyint(1) DEFAULT 0,
  `lounge_access` tinyint(1) DEFAULT 0,
  `extra_legroom` tinyint(1) DEFAULT 0,
  `meal_service` varchar(100) DEFAULT NULL,
  `wifi_included` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sample cabin classes
INSERT INTO `cabin_classes` (`name`, `subtitle`, `base_price`, `baggage_allowance_kg`, `cabin_baggage_kg`, `priority_boarding`, `lounge_access`) VALUES
('Economy', 'Classic', 100.00, 20, 7, 0, 0),
('Business', 'Premium', 500.00, 40, 15, 1, 1),
('First', 'Luxury', 1500.00, 50, 20, 1, 1);

-- --------------------------------------------------------
-- 3. BOOKINGS
-- Main booking table with payment & reservation logic
-- Links to existing flight_series
-- --------------------------------------------------------
CREATE TABLE `bookings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_reference` varchar(10) UNIQUE NOT NULL COMMENT 'e.g., ABC123',
  `user_id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `flight_date` date NOT NULL COMMENT 'Actual date of travel',
  `cabin_class_id` int(11) DEFAULT NULL,
  `total_passengers` int(11) NOT NULL DEFAULT 1,
  `total_amount` decimal(10,2) NOT NULL,
  `payment_status` enum('pending', 'paid', 'refunded', 'failed') DEFAULT 'pending',
  `booking_status` enum('reserved', 'confirmed', 'cancelled', 'completed') DEFAULT 'reserved',
  `reservation_date` datetime NOT NULL,
  `reservation_expires_at` datetime NOT NULL COMMENT '30 minutes after reservation',
  `payment_date` datetime DEFAULT NULL,
  `payment_method` varchar(50) DEFAULT NULL,
  `payment_reference` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`user_id`) REFERENCES `airline_users`(`id`),
  FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series`(`id`),
  FOREIGN KEY (`cabin_class_id`) REFERENCES `cabin_classes`(`id`),
  INDEX `idx_booking_ref` (`booking_reference`),
  INDEX `idx_user` (`user_id`),
  INDEX `idx_payment_status` (`payment_status`),
  INDEX `idx_booking_status` (`booking_status`),
  INDEX `idx_reservation_expires` (`reservation_expires_at`),
  INDEX `idx_flight_date` (`flight_series_id`, `flight_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 4. BOOKING PASSENGERS
-- Links passengers to bookings
-- --------------------------------------------------------
CREATE TABLE `booking_passengers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_id` int(11) NOT NULL,
  `passenger_id` int(11) NOT NULL,
  `seat_number` varchar(5) DEFAULT NULL COMMENT 'Assigned during check-in, e.g., 12A',
  `is_primary` tinyint(1) DEFAULT 0 COMMENT 'Primary contact for booking',
  `boarding_pass_issued` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`booking_id`) REFERENCES `bookings`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`passenger_id`) REFERENCES `passengers`(`id`),
  INDEX `idx_booking` (`booking_id`),
  INDEX `idx_passenger` (`passenger_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 5. FLIGHT SEATS
-- Seat inventory per flight_series instance
-- --------------------------------------------------------
CREATE TABLE `flight_seats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight_series_id` int(11) NOT NULL,
  `flight_date` date NOT NULL COMMENT 'Specific date for this flight instance',
  `seat_number` varchar(5) NOT NULL COMMENT 'e.g., 12A',
  `row_number` int(11) NOT NULL,
  `column_letter` varchar(1) NOT NULL COMMENT 'A-F',
  `seat_type` enum('standard', 'extra_legroom', 'premium', 'blocked') DEFAULT 'standard',
  `price` decimal(10,2) DEFAULT 0.00 COMMENT 'Additional price for premium seats',
  `is_window` tinyint(1) DEFAULT 0,
  `is_aisle` tinyint(1) DEFAULT 0,
  `status` enum('available', 'occupied', 'blocked') DEFAULT 'available',
  `booking_passenger_id` int(11) DEFAULT NULL COMMENT 'Assigned passenger',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`booking_passenger_id`) REFERENCES `booking_passengers`(`id`),
  UNIQUE KEY `unique_flight_seat` (`flight_series_id`, `flight_date`, `seat_number`),
  INDEX `idx_flight` (`flight_series_id`, `flight_date`),
  INDEX `idx_status` (`status`),
  INDEX `idx_type` (`seat_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 6. CHECK-INS
-- Check-in records (5-hour window logic)
-- --------------------------------------------------------
CREATE TABLE `checkins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_id` int(11) NOT NULL,
  `booking_passenger_id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `flight_date` date NOT NULL,
  `seat_number` varchar(5) NOT NULL,
  `carry_on_bags` int(11) DEFAULT 0,
  `checked_bags` int(11) DEFAULT 0,
  `checked_in_at` datetime NOT NULL,
  `boarding_pass_url` varchar(512) DEFAULT NULL,
  `qr_code_data` text DEFAULT NULL COMMENT 'QR code for boarding pass',
  `gate` varchar(10) DEFAULT NULL,
  `boarding_time` time DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`booking_id`) REFERENCES `bookings`(`id`),
  FOREIGN KEY (`booking_passenger_id`) REFERENCES `booking_passengers`(`id`),
  FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series`(`id`),
  INDEX `idx_booking` (`booking_id`),
  INDEX `idx_flight` (`flight_series_id`, `flight_date`),
  INDEX `idx_passenger` (`booking_passenger_id`),
  INDEX `idx_checkin_time` (`checked_in_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 7. PAYMENT TRANSACTIONS
-- Track all payment attempts
-- --------------------------------------------------------
CREATE TABLE `payment_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `booking_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'KES',
  `payment_method` varchar(50) NOT NULL COMMENT 'M-Pesa, Card, etc',
  `payment_reference` varchar(100) DEFAULT NULL,
  `transaction_id` varchar(100) DEFAULT NULL COMMENT 'External payment gateway ID',
  `status` enum('pending', 'completed', 'failed', 'refunded') DEFAULT 'pending',
  `payment_date` datetime DEFAULT NULL,
  `metadata` text DEFAULT NULL COMMENT 'JSON data from payment gateway',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`booking_id`) REFERENCES `bookings`(`id`),
  FOREIGN KEY (`user_id`) REFERENCES `airline_users`(`id`),
  INDEX `idx_booking` (`booking_id`),
  INDEX `idx_user` (`user_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_reference` (`payment_reference`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 8. NOTIFICATIONS (Optional but recommended)
-- Push notifications for users
-- --------------------------------------------------------
CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `type` enum('booking_confirmed', 'payment_reminder', 'checkin_available', 'gate_change', 'delay', 'cancellation', 'general') NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `sent_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  FOREIGN KEY (`user_id`) REFERENCES `airline_users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`booking_id`) REFERENCES `bookings`(`id`),
  INDEX `idx_user` (`user_id`),
  INDEX `idx_is_read` (`is_read`),
  INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- SAMPLE DATA FOR TESTING
-- ========================================

-- Sample airline user
INSERT INTO `airline_users` (`phone_number`, `email`, `password_hash`, `first_name`, `last_name`, `nationality`) VALUES
('0790193625', 'john.doe@example.com', '$2b$10$wCiwvdIuaC11/dD5xo9HlONGSEVwBuV1eAITaJHyFJ/O5apC4m.WG', 'John', 'Doe', 'Kenyan');

-- Sample booking (reserved, pending payment)
INSERT INTO `bookings` (`booking_reference`, `user_id`, `flight_series_id`, `flight_date`, `cabin_class_id`, `total_amount`, `payment_status`, `booking_status`, `reservation_date`, `reservation_expires_at`) VALUES
('ABC123', 1, 1, '2025-12-05', 1, 150.00, 'pending', 'reserved', NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE));

-- ========================================
-- END OF MIGRATION
-- ========================================
