CREATE TABLE IF NOT EXISTS `cargo_bookings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `awb_number` VARCHAR(20) NOT NULL UNIQUE,
  `flight_series_id` INT NOT NULL,
  `user_id` INT DEFAULT NULL,
  
  -- Shipper Info
  `shipper_name` VARCHAR(255) NOT NULL,
  `shipper_company` VARCHAR(255) DEFAULT NULL,
  `shipper_phone` VARCHAR(50) NOT NULL,
  `shipper_email` VARCHAR(255) DEFAULT NULL,
  `shipper_address` TEXT NOT NULL,
  
  -- Consignee Info
  `consignee_name` VARCHAR(255) NOT NULL,
  `consignee_company` VARCHAR(255) DEFAULT NULL,
  `consignee_phone` VARCHAR(50) NOT NULL,
  `consignee_email` VARCHAR(255) DEFAULT NULL,
  `consignee_address` TEXT NOT NULL,
  
  -- Logistics Info
  `commodity_type` VARCHAR(100) NOT NULL,
  `weight_kg` DECIMAL(10, 2) NOT NULL,
  `pieces` INT NOT NULL DEFAULT 1,
  `volumetric_weight` DECIMAL(10, 2) DEFAULT NULL,
  `dimensions_json` JSON DEFAULT NULL, -- Store multiple pieces dims
  `declared_value` DECIMAL(15, 2) DEFAULT 0.00,
  
  -- Financial Info
  `total_amount` DECIMAL(15, 2) NOT NULL,
  `currency` VARCHAR(3) DEFAULT 'USD',
  `payment_method` VARCHAR(50) DEFAULT 'pending',
  `payment_status` ENUM('pending', 'paid', 'cancelled', 'refunded') DEFAULT 'pending',
  
  -- Operational Info
  `status` ENUM('booked', 'manifested', 'in-transit', 'arrived', 'delivered') DEFAULT 'booked',
  `notes` TEXT DEFAULT NULL,
  
  `booking_date` DATE NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Index for searching AWBs
CREATE INDEX idx_awb_number ON `cargo_bookings` (`awb_number`);
CREATE INDEX idx_cargo_booking_date ON `cargo_bookings` (`booking_date`);
