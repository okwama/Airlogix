-- M-Pesa Transactions Table
-- Run this migration to enable transaction tracking

CREATE TABLE IF NOT EXISTS `mpesa_transactions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `checkout_request_id` VARCHAR(100) NOT NULL,
  `merchant_request_id` VARCHAR(100) DEFAULT NULL,
  `booking_reference` VARCHAR(50) NOT NULL,
  `phone_number` VARCHAR(20) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `mpesa_receipt` VARCHAR(50) DEFAULT NULL,
  `result_code` INT(11) DEFAULT NULL,
  `result_desc` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('pending', 'success', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
  `callback_data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `checkout_request_id` (`checkout_request_id`),
  KEY `booking_reference` (`booking_reference`),
  KEY `phone_number` (`phone_number`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add transaction_reference column to bookings table if not exists
ALTER TABLE `bookings` 
ADD COLUMN IF NOT EXISTS `transaction_reference` VARCHAR(100) DEFAULT NULL AFTER `payment_method`;
