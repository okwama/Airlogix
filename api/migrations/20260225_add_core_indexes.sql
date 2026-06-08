-- Core indexes to support traveler-facing queries at scale

-- Faster "My Trips" queries by user and recency
ALTER TABLE bookings
    ADD INDEX idx_bookings_user_created_at (user_id, created_at DESC);

-- Faster notifications list & unread count per user
ALTER TABLE notifications
    ADD INDEX idx_notifications_user_read_created (user_id, is_read, created_at DESC);

-- Faster flight search by origin/destination/date
ALTER TABLE flight_series
    ADD INDEX idx_flight_series_route_dates (from_destination_id, to_destination_id, start_date, end_date);

