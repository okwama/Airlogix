START TRANSACTION;

-- Seed data for local/manual QA of:
-- 1) Flight search + booking flow
-- 2) Cargo availability + cargo booking flow
-- Idempotent by design (safe to run multiple times).

-- Ensure common test destinations exist.
INSERT INTO `destinations` (`code`, `name`, `status`, `destination`)
SELECT 'NBO', 'Nairobi', 'active', 'Nairobi'
WHERE NOT EXISTS (SELECT 1 FROM `destinations` WHERE `code` = 'NBO');

INSERT INTO `destinations` (`code`, `name`, `status`, `destination`)
SELECT 'MBA', 'Mombasa', 'active', 'Mombasa'
WHERE NOT EXISTS (SELECT 1 FROM `destinations` WHERE `code` = 'MBA');

INSERT INTO `destinations` (`code`, `name`, `status`, `destination`)
SELECT 'DAR', 'Dar es Salaam', 'active', 'Dar es Salaam'
WHERE NOT EXISTS (SELECT 1 FROM `destinations` WHERE `code` = 'DAR');

INSERT INTO `destinations` (`code`, `name`, `status`, `destination`)
SELECT 'FIH', 'Kinshasa', 'active', 'Kinshasa'
WHERE NOT EXISTS (SELECT 1 FROM `destinations` WHERE `code` = 'FIH');

INSERT INTO `destinations` (`code`, `name`, `status`, `destination`)
SELECT 'BZV', 'Brazzaville', 'active', 'Brazzaville'
WHERE NOT EXISTS (SELECT 1 FROM `destinations` WHERE `code` = 'BZV');

-- Ensure at least one aircraft with realistic cargo capacity for testing.
INSERT INTO `aircrafts` (`name`, `registration`, `capacity`, `max_cargo_weight`, `status`, `calendar_color`)
SELECT 'QA Dash 8-400', 'QA-D8-400', 72, 3500.00, 'active', '#1D4ED8'
WHERE NOT EXISTS (SELECT 1 FROM `aircrafts` WHERE `registration` = 'QA-D8-400');

INSERT INTO `aircrafts` (`name`, `registration`, `capacity`, `max_cargo_weight`, `status`, `calendar_color`)
SELECT 'QA EMB 120', 'QA-EMB-120', 30, 1200.00, 'active', '#0EA5E9'
WHERE NOT EXISTS (SELECT 1 FROM `aircrafts` WHERE `registration` = 'QA-EMB-120');

-- Ensure cabin class id=1 exists (booking flow defaults to cabin_class_id=1).
INSERT INTO `cabin_classes` (`id`, `name`, `subtitle`, `base_price`, `baggage_allowance_kg`, `cabin_baggage_kg`, `priority_boarding`, `lounge_access`, `extra_legroom`, `meal_service`, `wifi_included`)
SELECT 1, 'Economy', 'Classic', 0.00, 20, 7, 0, 0, 0, 'Standard', 0
WHERE NOT EXISTS (SELECT 1 FROM `cabin_classes` WHERE `id` = 1);

-- Seed flight series covering current date window for easy search testing.
-- Window: from yesterday until +180 days.
INSERT INTO `flight_series` (
  `flt`, `aircraft_id`, `flight_type`,
  `start_date`, `end_date`,
  `std`, `sta`,
  `number_of_seats`,
  `from_destination_id`, `to_destination_id`,
  `adult_fare`, `child_fare`, `infant_fare`,
  `status`
)
SELECT
  'MC901',
  a.id,
  'passenger',
  DATE_SUB(CURDATE(), INTERVAL 1 DAY),
  DATE_ADD(CURDATE(), INTERVAL 180 DAY),
  '08:00:00',
  '09:00:00',
  72,
  d_from.id,
  d_to.id,
  220.00,
  150.00,
  60.00,
  'Scheduled'
FROM `aircrafts` a
JOIN `destinations` d_from ON d_from.code = 'NBO'
JOIN `destinations` d_to ON d_to.code = 'MBA'
WHERE a.registration = 'QA-D8-400'
  AND NOT EXISTS (
    SELECT 1
    FROM `flight_series` fs
    WHERE fs.flt = 'MC901'
      AND fs.from_destination_id = d_from.id
      AND fs.to_destination_id = d_to.id
  );

INSERT INTO `flight_series` (
  `flt`, `aircraft_id`, `flight_type`,
  `start_date`, `end_date`,
  `std`, `sta`,
  `number_of_seats`,
  `from_destination_id`, `to_destination_id`,
  `adult_fare`, `child_fare`, `infant_fare`,
  `status`
)
SELECT
  'MC902',
  a.id,
  'passenger',
  DATE_SUB(CURDATE(), INTERVAL 1 DAY),
  DATE_ADD(CURDATE(), INTERVAL 180 DAY),
  '14:20:00',
  '15:20:00',
  72,
  d_from.id,
  d_to.id,
  250.00,
  170.00,
  70.00,
  'Scheduled'
FROM `aircrafts` a
JOIN `destinations` d_from ON d_from.code = 'NBO'
JOIN `destinations` d_to ON d_to.code = 'DAR'
WHERE a.registration = 'QA-D8-400'
  AND NOT EXISTS (
    SELECT 1
    FROM `flight_series` fs
    WHERE fs.flt = 'MC902'
      AND fs.from_destination_id = d_from.id
      AND fs.to_destination_id = d_to.id
  );

INSERT INTO `flight_series` (
  `flt`, `aircraft_id`, `flight_type`,
  `start_date`, `end_date`,
  `std`, `sta`,
  `number_of_seats`,
  `from_destination_id`, `to_destination_id`,
  `adult_fare`, `child_fare`, `infant_fare`,
  `status`
)
SELECT
  'MC903',
  a.id,
  'passenger',
  DATE_SUB(CURDATE(), INTERVAL 1 DAY),
  DATE_ADD(CURDATE(), INTERVAL 180 DAY),
  '11:10:00',
  '11:55:00',
  30,
  d_from.id,
  d_to.id,
  180.00,
  120.00,
  50.00,
  'Scheduled'
FROM `aircrafts` a
JOIN `destinations` d_from ON d_from.code = 'FIH'
JOIN `destinations` d_to ON d_to.code = 'BZV'
WHERE a.registration = 'QA-EMB-120'
  AND NOT EXISTS (
    SELECT 1
    FROM `flight_series` fs
    WHERE fs.flt = 'MC903'
      AND fs.from_destination_id = d_from.id
      AND fs.to_destination_id = d_to.id
  );

-- Ensure cargo fallback pricing exists.
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

-- Route-specific tariff examples for QA.
INSERT INTO `cargo_tariffs` (
  `from_destination_id`, `to_destination_id`, `commodity_type`,
  `min_weight_kg`, `max_weight_kg`,
  `price_per_kg`, `min_charge_amount`, `currency`,
  `is_active`, `effective_from`, `notes`
)
SELECT
  d_from.id, d_to.id, 'general',
  0.00, NULL,
  115.00, 0.00, 'USD',
  1, CURDATE(), 'QA tariff NBO-MBA'
FROM `destinations` d_from
JOIN `destinations` d_to ON d_to.code = 'MBA'
WHERE d_from.code = 'NBO'
  AND NOT EXISTS (
    SELECT 1 FROM `cargo_tariffs` ct
    WHERE ct.from_destination_id = d_from.id
      AND ct.to_destination_id = d_to.id
      AND LOWER(ct.commodity_type) = 'general'
      AND ct.is_active = 1
  );

INSERT INTO `cargo_tariffs` (
  `from_destination_id`, `to_destination_id`, `commodity_type`,
  `min_weight_kg`, `max_weight_kg`,
  `price_per_kg`, `min_charge_amount`, `currency`,
  `is_active`, `effective_from`, `notes`
)
SELECT
  d_from.id, d_to.id, 'general',
  0.00, NULL,
  140.00, 0.00, 'USD',
  1, CURDATE(), 'QA tariff FIH-BZV'
FROM `destinations` d_from
JOIN `destinations` d_to ON d_to.code = 'BZV'
WHERE d_from.code = 'FIH'
  AND NOT EXISTS (
    SELECT 1 FROM `cargo_tariffs` ct
    WHERE ct.from_destination_id = d_from.id
      AND ct.to_destination_id = d_to.id
      AND LOWER(ct.commodity_type) = 'general'
      AND ct.is_active = 1
  );

-- Optional: capacity override example on Kinshasa-Brazzaville for today.
INSERT INTO `cargo_capacity_overrides` (`flight_series_id`, `override_date`, `effective_capacity_kg`, `reason`, `is_active`)
SELECT fs.id, CURDATE(), 900.00, 'QA capacity constraint test', 1
FROM `flight_series` fs
JOIN `destinations` d_from ON fs.from_destination_id = d_from.id
JOIN `destinations` d_to ON fs.to_destination_id = d_to.id
WHERE fs.flt = 'MC903'
  AND d_from.code = 'FIH'
  AND d_to.code = 'BZV'
  AND NOT EXISTS (
    SELECT 1
    FROM `cargo_capacity_overrides` cco
    WHERE cco.flight_series_id = fs.id
      AND cco.override_date = CURDATE()
  );

COMMIT;
