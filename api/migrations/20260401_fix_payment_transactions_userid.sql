-- Fix payment_transactions user_id to allow NULL for guests
ALTER TABLE `payment_transactions` MODIFY COLUMN `user_id` INT(11) NULL;
ALTER TABLE `payment_transactions` DROP FOREIGN KEY `payment_transactions_ibfk_2`;
ALTER TABLE `payment_transactions` ADD CONSTRAINT `payment_transactions_ibfk_2` 
    FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE SET NULL;
