-- Add loyalty columns to airline_users table
ALTER TABLE `airline_users`
ADD COLUMN `member_club` ENUM('BRONZE', 'SILVER', 'GOLD', 'PLATINUM') NOT NULL DEFAULT 'BRONZE' AFTER `frequent_flyer_number`,
ADD COLUMN `loyalty_points` INT(11) NOT NULL DEFAULT 0 AFTER `member_club`;

-- Create index for member_club
CREATE INDEX `idx_member_club` ON `airline_users` (`member_club`);
