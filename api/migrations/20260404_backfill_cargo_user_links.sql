START TRANSACTION;

-- Backfill cargo bookings to authenticated traveler accounts conservatively.
-- This migration only links rows that currently have no user_id and where the
-- booking email exactly matches a known airline_users email (case-insensitive).
-- We avoid phone-based matching here to reduce accidental cross-linking caused
-- by formatting differences or shared contact numbers.

UPDATE cargo_bookings cb
JOIN airline_users au
  ON TRIM(cb.shipper_email) COLLATE utf8mb4_unicode_ci = TRIM(au.email) COLLATE utf8mb4_unicode_ci
SET cb.user_id = au.id
WHERE cb.user_id IS NULL
  AND cb.shipper_email IS NOT NULL
  AND TRIM(cb.shipper_email) <> '';

UPDATE cargo_bookings cb
JOIN airline_users au
  ON TRIM(cb.consignee_email) COLLATE utf8mb4_unicode_ci = TRIM(au.email) COLLATE utf8mb4_unicode_ci
SET cb.user_id = au.id
WHERE cb.user_id IS NULL
  AND cb.consignee_email IS NOT NULL
  AND TRIM(cb.consignee_email) <> '';

COMMIT;
