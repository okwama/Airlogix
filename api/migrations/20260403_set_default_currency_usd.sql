-- Set USD as the system default currency for transactional tables.
ALTER TABLE `payment_transactions`
  MODIFY COLUMN `currency` VARCHAR(3) DEFAULT 'USD';

ALTER TABLE `cargo_bookings`
  MODIFY COLUMN `currency` VARCHAR(3) DEFAULT 'USD';
