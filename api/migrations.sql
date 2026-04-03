-- Migration: Extend PNR column and add Cabin Class support
ALTER TABLE `passengers` MODIFY COLUMN `pnr` VARCHAR(20) NOT NULL;
ALTER TABLE `bookings` ADD COLUMN `cabin_class_id` INT NULL AFTER `flight_series_id`;
