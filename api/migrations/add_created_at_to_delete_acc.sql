-- Migration: Add created_at column to delete_acc table
-- This is required to track the 30-day deletion period accurately

ALTER TABLE `delete_acc`
ADD COLUMN `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `is_true`;

-- Update existing records to have a created_at timestamp (if any exist)
UPDATE `delete_acc` SET `created_at` = NOW() WHERE `created_at` IS NULL OR `created_at` = '0000-00-00 00:00:00';

