-- Table to store global application settings and configuration
CREATE TABLE IF NOT EXISTS `settings` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `setting_key` VARCHAR(64) NOT NULL UNIQUE,
    `setting_value` TEXT,
    `group_name` VARCHAR(32) DEFAULT 'general',
    `description` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inserting Estonian Bank Details for Mc Aviation / ESTBRAND AVIATORS OÜ
INSERT INTO `settings` (`setting_key`, `setting_value`, `group_name`, `description`) VALUES
('bank_beneficiary', 'ESTBRAND AVIATORS OÜ', 'payment', 'Company name for bank transfers'),
('bank_name', 'AS SEB PANK (Estonia)', 'payment', 'Bank provider name'),
('bank_swift_bic', 'EEUHEE2X', 'payment', 'SWIFT/BIC code for international transfers'),
('bank_reg_code', '10004252', 'payment', 'Corporate registration number'),
('bank_address', 'Tornimäe 2, 15010 Tallinn, Eesti Vabariik', 'payment', 'Physical bank address'),
('bank_iban', 'EE171010220301870220', 'payment', 'Account IBAN number'),
('payment_instruction_note', 'Please use your Booking Reference (PNR) as the transfer description.', 'payment', 'General instruction for manual bank transfers');
