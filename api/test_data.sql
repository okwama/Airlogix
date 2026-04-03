-- Airlogix Test Data Setup
-- This script adds realistic test data for flight search and booking

-- ============================================
-- 0. ADD MISSING COUNTRIES
-- ============================================

INSERT INTO Country (name, status) 
SELECT * FROM (
    SELECT 'Uganda' as name, 1 as status UNION ALL
    SELECT 'Rwanda', 1 UNION ALL
    SELECT 'Democratic Republic of Congo', 1 UNION ALL
    SELECT 'Cameroon', 1 UNION ALL
    SELECT 'Gabon', 1 UNION ALL
    SELECT 'Madagascar', 1
) AS tmp
WHERE NOT EXISTS (
    SELECT name FROM Country WHERE name = tmp.name
) LIMIT 6;

-- ============================================
-- 1. ADD MORE DESTINATIONS
-- ============================================

-- Get Country IDs for consistency
SET @kenya_id = (SELECT id FROM Country WHERE name = 'Kenya' LIMIT 1);
SET @tanzania_id = (SELECT id FROM Country WHERE name = 'Tanzania' LIMIT 1);
SET @comoros_id = (SELECT id FROM Country WHERE name = 'Comoros' LIMIT 1);
SET @uganda_id = (SELECT id FROM Country WHERE name = 'Uganda' LIMIT 1);
SET @rwanda_id = (SELECT id FROM Country WHERE name = 'Rwanda' LIMIT 1);
SET @drc_id = (SELECT id FROM Country WHERE name = 'Democratic Republic of Congo' LIMIT 1);
SET @cameroon_id = (SELECT id FROM Country WHERE name = 'Cameroon' LIMIT 1);
SET @gabon_id = (SELECT id FROM Country WHERE name = 'Gabon' LIMIT 1);
SET @madagascar_id = (SELECT id FROM Country WHERE name = 'Madagascar' LIMIT 1);

INSERT INTO destinations (code, name, country_id, status, destination, longitude, latitude, timezone)
VALUES
-- East Africa
('NBO', 'Nairobi', @kenya_id, 'active', 'Jomo Kenyatta International Airport (NBO)', 36.9258, -1.3192, 'Africa/Nairobi'),
('DAR', 'Dar es Salaam', @tanzania_id, 'active', 'Julius Nyerere International Airport (DAR)', 39.2026, -6.8781, 'Africa/Dar_es_Salaam'),
('EBB', 'Entebbe', @uganda_id, 'active', 'Entebbe International Airport (EBB)', 32.4435, 0.0424, 'Africa/Kampala'),
('KGL', 'Kigali', @rwanda_id, 'active', 'Kigali International Airport (KGL)', 30.1395, -1.9686, 'Africa/Kigali'),

-- Central Africa
('FIH', 'Kinshasa', @drc_id, 'active', 'N\'djili International Airport (FIH)', 15.4446, -4.3857, 'Africa/Kinshasa'),
('DLA', 'Douala', @cameroon_id, 'active', 'Douala International Airport (DLA)', 9.7195, 4.0061, 'Africa/Douala'),
('LBV', 'Libreville', @gabon_id, 'active', 'Libreville International Airport (LBV)', 9.4123, 0.4586, 'Africa/Libreville'),

-- Islands
('HAH', 'Moroni', @comoros_id, 'active', 'Prince Said Ibrahim International Airport (HAH)', 43.2719, -11.5337, 'Indian/Comoro'),
('TNR', 'Antananarivo', @madagascar_id, 'active', 'Ivato International Airport (TNR)', 47.4788, -18.7969, 'Indian/Antananarivo')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    status = VALUES(status),
    destination = VALUES(destination),
    country_id = VALUES(country_id);

-- ============================================
-- 2. UPDATE EXISTING DESTINATIONS
-- ============================================

-- Fix Mombasa destination
UPDATE destinations 
SET destination = 'Moi International Airport (MBA)',
    code = 'MBA'
WHERE id = 5;

-- ============================================
-- 3. ADD TEST FLIGHTS (Next 30 Days)
-- ============================================

-- Get destination IDs
SET @nairobi_id = (SELECT id FROM destinations WHERE code = 'NBO' LIMIT 1);
SET @mombasa_id = (SELECT id FROM destinations WHERE code = 'MBA' LIMIT 1);
SET @moroni_id = (SELECT id FROM destinations WHERE code = 'HAH' LIMIT 1);
SET @dar_id = (SELECT id FROM destinations WHERE code = 'DAR' LIMIT 1);
SET @entebbe_id = (SELECT id FROM destinations WHERE code = 'EBB' LIMIT 1);
SET @kinshasa_id = (SELECT id FROM destinations WHERE code = 'FIH' LIMIT 1);
SET @douala_id = (SELECT id FROM destinations WHERE code = 'DLA' LIMIT 1);

-- Popular Routes (Daily flights for next 30 days)

-- Nairobi <-> Mombasa (Most popular route)
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
-- Morning flight NBO -> MBA
('MC101', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 
 '06:00:00', '07:15:00', 150, @nairobi_id, @mombasa_id, 8500.00, 5500.00, 1500.00),

-- Afternoon flight NBO -> MBA
('MC103', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '14:30:00', '15:45:00', 150, @nairobi_id, @mombasa_id, 9200.00, 6000.00, 1800.00),

-- Evening flight NBO -> MBA
('MC105', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '19:00:00', '20:15:00', 120, @nairobi_id, @mombasa_id, 12500.00, 8000.00, 2500.00),

-- Morning return MBA -> NBO
('MC102', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '08:00:00', '09:15:00', 150, @mombasa_id, @nairobi_id, 8500.00, 5500.00, 1500.00),

-- Afternoon return MBA -> NBO
('MC104', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '16:00:00', '17:15:00', 150, @mombasa_id, @nairobi_id, 9200.00, 6000.00, 1800.00),

-- Evening return MBA -> NBO
('MC106', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '20:30:00', '21:45:00', 120, @mombasa_id, @nairobi_id, 12500.00, 8000.00, 2500.00);

-- Nairobi <-> Dar es Salaam
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
('MC201', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '10:00:00', '11:30:00', 180, @nairobi_id, @dar_id, 15000.00, 10000.00, 3000.00),

('MC202', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '12:30:00', '14:00:00', 180, @dar_id, @nairobi_id, 15000.00, 10000.00, 3000.00);

-- Nairobi <-> Entebbe
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
('MC301', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '07:30:00', '09:00:00', 120, @nairobi_id, @entebbe_id, 18000.00, 12000.00, 3500.00),

('MC302', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '15:00:00', '16:30:00', 120, @entebbe_id, @nairobi_id, 18000.00, 12000.00, 3500.00);

-- Mombasa <-> Moroni (Island route)
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
('MC401', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '11:00:00', '13:30:00', 150, @mombasa_id, @moroni_id, 22000.00, 15000.00, 4000.00),

('MC402', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '14:30:00', '17:00:00', 150, @moroni_id, @mombasa_id, 22000.00, 15000.00, 4000.00);

-- Nairobi <-> Kinshasa (Central Africa)
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
('MC501', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '09:00:00', '13:00:00', 120, @nairobi_id, @kinshasa_id, 35000.00, 25000.00, 7000.00),

('MC502', 6, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '14:00:00', '18:00:00', 120, @kinshasa_id, @nairobi_id, 35000.00, 25000.00, 7000.00);

-- Kinshasa <-> Douala (Regional Central Africa)
INSERT INTO flight_series 
(flt, aircraft_id, flight_type, start_date, end_date, std, sta, number_of_seats, 
 from_destination_id, to_destination_id, adult_fare, child_fare, infant_fare)
VALUES
('MC601', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '08:00:00', '10:30:00', 150, @kinshasa_id, @douala_id, 28000.00, 18000.00, 5000.00),

('MC602', 7, 'From-To', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY),
 '16:00:00', '18:30:00', 150, @douala_id, @kinshasa_id, 28000.00, 18000.00, 5000.00);

-- ============================================
-- SUMMARY
-- ============================================

SELECT 'Test data added successfully!' as Status;
SELECT COUNT(*) as 'Total Destinations' FROM destinations WHERE status = 'active';
SELECT COUNT(*) as 'Total Active Flights' FROM flight_series WHERE start_date >= CURDATE();
