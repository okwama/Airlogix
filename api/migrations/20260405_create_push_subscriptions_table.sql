CREATE TABLE IF NOT EXISTS `push_subscriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `provider` varchar(32) NOT NULL DEFAULT 'onesignal',
  `platform` enum('android','ios','web') NOT NULL DEFAULT 'android',
  `subscription_id` varchar(191) NOT NULL,
  `external_user_id` varchar(191) DEFAULT NULL,
  `status` enum('active','inactive') NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_provider_subscription` (`provider`,`subscription_id`),
  KEY `idx_push_subscriptions_user` (`user_id`),
  KEY `idx_push_subscriptions_user_status` (`user_id`,`status`),
  CONSTRAINT `fk_push_subscriptions_user`
    FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
