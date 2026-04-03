
-- --------------------------------------------------------

--
-- Table structure for table `exchange_rates`
--

CREATE TABLE `exchange_rates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `currency_code` varchar(3) NOT NULL,
  `rate` decimal(10, 6) NOT NULL COMMENT 'Exchange rate relative to EUR (Fixer Base)',
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `currency_code` (`currency_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `exchange_rates`
--

INSERT INTO `exchange_rates` (`id`, `currency_code`, `rate`, `last_updated`) VALUES
(1, 'EUR', 1.000000, '2025-12-07 15:43:26'),
(2, 'USD', 1.164546, '2025-12-07 15:58:16'),
(3, 'GBP', 0.872678, '2025-12-07 15:58:16'),
(4, 'QAR', 4.244719, '2025-12-07 15:58:16'),
(5, 'AED', 4.276798, '2025-12-07 15:58:16'),
(6, 'SAR', 4.370508, '2025-12-07 15:58:16'),
(7, 'KES', 150.636483, '2025-12-07 15:58:16'),
(8, 'JPY', 180.924237, '2025-12-07 15:58:16'),
(9, 'CNY', 8.233458, '2025-12-07 15:58:16'),
(55, 'CDF', 2703.000000, '2026-02-24 13:18:53'),
(56, 'XAF', 655.957000, '2026-02-24 13:18:53'),
(57, 'KMF', 491.968000, '2026-02-24 13:18:53');
