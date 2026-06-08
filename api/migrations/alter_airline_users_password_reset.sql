ALTER TABLE airline_users
ADD COLUMN password_reset_code VARCHAR(6) NULL,
ADD COLUMN password_reset_expires_at DATETIME NULL;
