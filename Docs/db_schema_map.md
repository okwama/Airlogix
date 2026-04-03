# AirLogix — Database Schema Map

**Database:** `impulsep_royal` (MariaDB 10.6 on shared cPanel)  
**Charset:** `utf8mb4_unicode_ci`

> Only AirLogix-relevant tables are documented here. The database also contains unrelated CRM tables (SalesRep, JourneyPlan, Clients, sales_orders, etc.) from a separate product — **ignore those**.

---

## Core Tables

### `airline_users`
Primary passenger account table.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | Auto-increment |
| `phone_number` | varchar(20) UNIQUE | Primary login identifier |
| `email` | varchar(255) | Optional |
| `password_hash` | varchar(255) | bcrypt |
| `first_name` | varchar(100) | |
| `last_name` | varchar(100) | |
| `date_of_birth` | date | |
| `nationality` | varchar(100) | |
| `passport_number` | varchar(50) | |
| `passport_expiry_date` | date | |
| `frequent_flyer_number` | varchar(50) | |
| `member_club` | enum | `BRONZE` / `SILVER` / `GOLD` / `PLATINUM` |
| `loyalty_points` | int | Current balance |
| `profile_photo_url` | varchar(512) | Cloudinary URL |
| [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | enum | `active` / `suspended` / `deleted` |
| `deletion_status` | enum | `active` / `pending` / `deleted` |
| `password_reset_code` | varchar(6) | OTP for forgot password |
| `password_reset_expires_at` | datetime | OTP expiry |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

---

### `flight_series`
Scheduled/recurring flights — the core flight entity.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `flight_number` | varchar(20) | e.g. `RY101` |
| `origin_id` | int FK | → `destinations.id` |
| `destination_id` | int FK | → `destinations.id` |
| `departure_time` | time | Scheduled departure |
| `arrival_time` | time | Scheduled arrival |
| `duration_minutes` | int | Flight duration |
| `aircraft_id` | int FK | → `aircrafts.id` |
| `frequency` | varchar(50) | Days of week (e.g. `Mon,Wed,Fri`) |
| [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | varchar(20) | `active` / `cancelled` / `delayed` |
| `price_economy` | decimal(10,2) | |
| `price_business` | decimal(10,2) | |
| `price_first` | decimal(10,2) | |
| `capacity` | int | Total seats |
| `available_seats` | int | Remaining |

---

### `destinations`
Airport and city lookup.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `iata_code` | varchar(3) | e.g. `NBO`, `DAR`, `EBB` |
| `city` | varchar(100) | e.g. `Nairobi` |
| `country` | varchar(100) | |
| `airport_name` | varchar(255) | |
| `latitude` | decimal | |
| `longitude` | decimal | |
| `timezone` | varchar(50) | |

---

### `bookings`
One booking record per booking event. May have multiple passengers.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `booking_reference` | varchar(50) UNIQUE | e.g. `BKMISVXKRH6OZ0` |
| `flight_series_id` | int FK | → `flight_series.id` |
| `cabin_class_id` | int FK | → `cabin_classes.id` (nullable) |
| `passenger_id` | int FK | Lead passenger → `passengers.id` |
| `passenger_name` | varchar(255) | Lead name (denormalized) |
| `passenger_email` | varchar(255) | |
| `passenger_phone` | varchar(50) | |
| `passenger_type` | varchar(20) | `adult` / `child` / `infant` |
| `number_of_passengers` | int | Total count |
| `fare_per_passenger` | decimal(10,2) | |
| `total_amount` | decimal(10,2) | |
| `payment_method` | varchar(50) | `mpesa`, `dpo`, `paystack`, `onafriq`, `cash` |
| `payment_status` | varchar(50) | `pending` / `paid` / `failed` |
| [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | tinyint | `0`=pending, `1`=confirmed, `2`=cancelled |
| `booking_date` | date | |
| `notes` | text | |
| `user_id` | int FK | → `airline_users.id` (nullable for guest) |
| `revenue_recognized` | tinyint(1) | Finance flag |

---

### `booking_passengers`
Individual passenger rows per booking (for multi-pax).

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `booking_id` | int FK | → `bookings.id` |
| `passenger_name` | varchar(255) | |
| `passenger_type` | varchar(20) | `adult` / `child` / `infant` |
| `passport_number` | varchar(50) | |
| `nationality` | varchar(100) | |
| `date_of_birth` | date | |
| `seat_number` | varchar(10) | After check-in |

---

### `passengers`
Reusable passenger profiles (linked to logged-in user).

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `user_id` | int FK | → `airline_users.id` |
| `title` | varchar(10) | Mr / Mrs / Ms / Dr |
| `full_name` | varchar(255) | |
| `phone` | varchar(20) | |
| `email` | varchar(255) | |
| `nationality` | varchar(100) | |
| `passport_number` | varchar(50) | |
| `id_number` | varchar(50) | |
| `age` | int | |
| `passenger_type` | varchar(20) | |

---

### `cabin_classes`
Flight class options.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `name` | varchar(50) | `Economy` / `Business` / `First` |
| `benefits` | text | JSON or pipe-delimited |
| `baggage_allowance` | varchar(100) | |
| `price_multiplier` | decimal | |

---

### `checkins`
Check-in record per booking.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `booking_id` | int FK | → `bookings.id` |
| `user_id` | int FK | → `airline_users.id` |
| `seat_number` | varchar(10) | |
| `gate` | varchar(10) | |
| `boarding_time` | datetime | |
| `qr_code` | text | Boarding pass QR data |
| [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | varchar(20) | `completed` / `pending` |
| `checked_in_at` | timestamp | |

---

### `payments`
Payment transaction records.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `booking_id` | int FK | → `bookings.id` |
| `booking_reference` | varchar(50) | |
| `method` | varchar(50) | `mpesa` / `dpo` / `paystack` / `onafriq` |
| `amount` | decimal(10,2) | |
| `currency` | varchar(3) | |
| `provider_reference` | varchar(100) | Safaricom/DPO/Paystack transaction ID |
| [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | varchar(20) | `pending` / `completed` / `failed` |
| `raw_response` | text | Provider raw callback payload |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

---

### `loyalty_accounts`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `user_id` | int FK UNIQUE | → `airline_users.id` |
| `tier` | enum | `BRONZE` / `SILVER` / `GOLD` / `PLATINUM` |
| `points_balance` | int | |
| `lifetime_points` | int | Never decrements |
| `updated_at` | timestamp | |

---

### `loyalty_transactions`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `user_id` | int FK | → `airline_users.id` |
| `type` | enum | `earn` / `redeem` / `adjust` |
| `points` | int | Positive = earn, negative = deduct |
| `description` | varchar(255) | e.g. `Booking RY101 NBO→DAR` |
| `booking_id` | int FK | → `bookings.id` (nullable) |
| `created_at` | timestamp | |

---

### `device_tokens`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `user_id` | int FK | → `airline_users.id` |
| `token` | text | FCM or APNS token |
| `platform` | varchar(10) | `ios` / `android` |
| `created_at` | timestamp | |

---

### `notifications`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `user_id` | int FK | → `airline_users.id` |
| `title` | varchar(255) | |
| `body` | text | |
| `type` | varchar(50) | `booking`, `payment`, `checkin`, [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80), `promo` |
| `is_read` | tinyint(1) | `0`=unread, `1`=read |
| `data` | json | Extra payload (booking_reference, etc.) |
| `created_at` | timestamp | |

---

## Relationship Diagram

```
airline_users
  ├── passengers (1:N)
  ├── bookings (1:N via user_id)
  ├── loyalty_accounts (1:1)
  ├── loyalty_transactions (1:N)
  ├── device_tokens (1:N)
  └── notifications (1:N)

bookings
  ├── booking_passengers (1:N)
  ├── payments (1:N)
  └── checkins (1:1)

flight_series
  ├── bookings (1:N)
  ├── destinations (origin, N:1)
  └── destinations (destination, N:1)
```

---

## Status Code Reference

| Entity | Field | Values |
|---|---|---|
| `airline_users` | [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | `active`, `suspended`, `deleted` |
| `airline_users` | `member_club` | `BRONZE`, `SILVER`, `GOLD`, `PLATINUM` |
| `bookings` | [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | `0`=pending, `1`=confirmed, `2`=cancelled |
| `bookings` | `payment_status` | `pending`, `paid`, `failed` |
| `checkins` | [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | `pending`, `completed` |
| `payments` | [status](file:///c:/Airlogix/api/controllers/FlightController.php#47-80) | `pending`, `completed`, `failed` |
| `loyalty_transactions` | `type` | `earn`, `redeem`, `adjust` |
