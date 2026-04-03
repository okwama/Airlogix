ALTER TABLE `bookings`
  ADD COLUMN `reservation_expires_at` DATETIME NULL AFTER `booking_date`,
  ADD COLUMN `expired_at` DATETIME NULL AFTER `reservation_expires_at`,
  ADD INDEX `idx_booking_reservation_expires_at` (`reservation_expires_at`),
  ADD INDEX `idx_booking_expired_at` (`expired_at`);

UPDATE `bookings`
SET `reservation_expires_at` = DATE_ADD(`created_at`, INTERVAL 30 MINUTE)
WHERE `reservation_expires_at` IS NULL
  AND LOWER(`payment_status`) = 'pending';

UPDATE `bookings`
SET `expired_at` = NOW(),
    `payment_status` = 'cancelled',
    `status` = 2
WHERE LOWER(`payment_status`) = 'pending'
  AND `reservation_expires_at` IS NOT NULL
  AND `reservation_expires_at` <= NOW();
