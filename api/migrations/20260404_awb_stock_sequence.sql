START TRANSACTION;

-- Controlled AWB stock for airline-grade AWB allocation.
-- One row per airline prefix, with sequential 7-digit serial allocation.
CREATE TABLE IF NOT EXISTS `cargo_awb_stock` (
  `airline_prefix` char(3) NOT NULL,
  `next_serial` int(11) UNSIGNED NOT NULL DEFAULT 1,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`airline_prefix`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed the current working prefix so allocation works immediately.
-- Replace 450 with the officially assigned IATA cargo prefix when available.
INSERT INTO `cargo_awb_stock` (`airline_prefix`, `next_serial`)
VALUES ('450', 1)
ON DUPLICATE KEY UPDATE
  `next_serial` = IF(`next_serial` < 1, 1, `next_serial`);

COMMIT;
