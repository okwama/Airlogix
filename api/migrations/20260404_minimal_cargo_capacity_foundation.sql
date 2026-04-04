START TRANSACTION;

-- Minimal cargo foundation for production-grade availability without table sprawl.
-- Strategy:
-- 1) Extend existing cargo_bookings for hold/confirmed lifecycle and weight snapshots.
-- 2) Add one per-flight/date override table for operational capacity controls.
-- 3) Add one tariff table for route/commodity/weight-band pricing.

ALTER TABLE `cargo_bookings`
  ADD COLUMN `chargeable_weight_kg` decimal(10,2) DEFAULT NULL AFTER `volumetric_weight`,
  ADD COLUMN `booking_phase` enum('hold','confirmed','cancelled') NOT NULL DEFAULT 'hold' AFTER `payment_status`,
  ADD COLUMN `hold_expires_at` datetime DEFAULT NULL AFTER `booking_date`,
  ADD COLUMN `capacity_snapshot_kg` decimal(10,2) DEFAULT NULL AFTER `hold_expires_at`;

ALTER TABLE `cargo_bookings`
  ADD KEY `idx_cargo_booking_phase` (`booking_phase`),
  ADD KEY `idx_cargo_hold_expires_at` (`hold_expires_at`),
  ADD KEY `idx_cargo_flight_date_phase` (`flight_series_id`, `booking_date`, `booking_phase`);

CREATE TABLE IF NOT EXISTS `cargo_capacity_overrides` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight_series_id` int(11) NOT NULL,
  `override_date` date NOT NULL,
  `effective_capacity_kg` decimal(10,2) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cargo_capacity_override_flight_date` (`flight_series_id`, `override_date`),
  KEY `idx_cargo_capacity_override_date` (`override_date`),
  KEY `idx_cargo_capacity_override_active` (`is_active`),
  CONSTRAINT `fk_cargo_capacity_override_flight_series`
    FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cargo_tariffs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `from_destination_id` int(11) DEFAULT NULL,
  `to_destination_id` int(11) DEFAULT NULL,
  `commodity_type` varchar(100) NOT NULL DEFAULT 'general',
  `min_weight_kg` decimal(10,2) NOT NULL DEFAULT 0.00,
  `max_weight_kg` decimal(10,2) DEFAULT NULL,
  `price_per_kg` decimal(10,2) NOT NULL,
  `min_charge_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` char(3) NOT NULL DEFAULT 'USD',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `effective_from` date DEFAULT NULL,
  `effective_to` date DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_cargo_tariff_route` (`from_destination_id`, `to_destination_id`),
  KEY `idx_cargo_tariff_commodity` (`commodity_type`),
  KEY `idx_cargo_tariff_active` (`is_active`),
  KEY `idx_cargo_tariff_effective` (`effective_from`, `effective_to`),
  CONSTRAINT `fk_cargo_tariff_from_destination`
    FOREIGN KEY (`from_destination_id`) REFERENCES `destinations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cargo_tariff_to_destination`
    FOREIGN KEY (`to_destination_id`) REFERENCES `destinations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Keep backward compatibility with existing code path that reads settings fallback.
INSERT INTO `settings` (`setting_key`, `setting_value`, `group_name`, `description`)
VALUES (
  'cargo_price_per_kg_default',
  '120',
  'cargo',
  'Fallback cargo rate per kg when no tariff row matches'
)
ON DUPLICATE KEY UPDATE
  `setting_value` = VALUES(`setting_value`),
  `group_name` = VALUES(`group_name`),
  `description` = VALUES(`description`);

-- Global default tariff row (applies when route-specific row is missing).
INSERT INTO `cargo_tariffs` (
  `from_destination_id`,
  `to_destination_id`,
  `commodity_type`,
  `min_weight_kg`,
  `max_weight_kg`,
  `price_per_kg`,
  `min_charge_amount`,
  `currency`,
  `is_active`,
  `effective_from`,
  `notes`
)
SELECT
  NULL,
  NULL,
  'general',
  0.00,
  NULL,
  120.00,
  0.00,
  'USD',
  1,
  CURRENT_DATE,
  'Global fallback tariff'
WHERE NOT EXISTS (
  SELECT 1
  FROM `cargo_tariffs`
  WHERE `from_destination_id` IS NULL
    AND `to_destination_id` IS NULL
    AND `commodity_type` = 'general'
    AND `is_active` = 1
);

COMMIT;
