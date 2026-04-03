-- Migration: Add status column to SalesRepJourneyPlans table
-- Status values: 0 = pending, 1 = checked in/in progress, 2 = checkout/completed

ALTER TABLE `SalesRepJourneyPlans` 
ADD COLUMN `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0=pending, 1=checked in/in progress, 2=checkout' 
AFTER `notes`;

-- Update existing records based on check-in/check-out times
UPDATE `SalesRepJourneyPlans` 
SET `status` = CASE 
    WHEN `checkin_time` IS NULL AND `checkout_time` IS NULL THEN 0
    WHEN `checkin_time` IS NOT NULL AND `checkout_time` IS NULL THEN 1
    WHEN `checkin_time` IS NOT NULL AND `checkout_time` IS NOT NULL THEN 2
    ELSE 0
END;

