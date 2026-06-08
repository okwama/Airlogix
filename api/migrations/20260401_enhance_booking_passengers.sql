-- Enhance booking_passengers table for e-ticketing
ALTER TABLE `booking_passengers` 
ADD COLUMN `ticket_number` VARCHAR(20) DEFAULT NULL AFTER `fare_amount`,
ADD COLUMN `ticket_status` ENUM('OPEN', 'USED', 'VOID', 'REFUNDED') DEFAULT 'OPEN' AFTER `ticket_number`,
ADD COLUMN `issued_at` TIMESTAMP NULL DEFAULT NULL AFTER `ticket_status`,
ADD UNIQUE INDEX `idx_ticket_number` (`ticket_number`);

-- Update bookings status documentation (for reference in code/admin)
-- Status 0: Pending/Created
-- Status 1: Confirmed/Paid
-- Status 2: Cancelled
-- Status 3: Partial Payment
ALTER TABLE `bookings` MODIFY COLUMN `status` TINYINT DEFAULT 0 COMMENT '0:Pending, 1:Confirmed, 2:Cancelled, 3:Partial';
