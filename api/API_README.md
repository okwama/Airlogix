# RoyalAir Airline API

This API has been refactored to a modular structure to exclusively serve the RoyalAir airline iOS application.

## Directory Structure

```
royalair/php_api/
├── config.php              # Database configuration and environment variables
├── index.php               # Main entry point and router
├── .htaccess               # URL rewriting rules
├── controllers/            # Request handlers
│   ├── AirlineUserController.php
│   ├── FlightController.php
│   ├── BookingController.php
│   ├── PaymentController.php
│   └── CheckInController.php
├── models/                 # Database interaction logic
│   ├── AirlineUser.php
│   ├── Flight.php
│   ├── Booking.php
│   ├── Payment.php
│   └── CheckIn.php
├── utils/                  # Helper classes
│   ├── Jwt.php             # JWT generation and decoding
│   └── Response.php        # Standardized JSON response helper
├── migrations/             # Database migration files
│   └── create_airline_tables.sql
└── archive/                # Deprecated/Unused controllers
```

## Setup

1.  **Database**: Ensure your MySQL database is running and configured in `.env` (or `config.php`).
2.  **Migrations**: Run the SQL commands in `migrations/create_airline_tables.sql` to create the necessary tables (`airline_users`, `bookings`, `checkins`, etc.).
3.  **Server**: Point your web server (Apache/Nginx) to the `royalair/php_api` directory.

## Endpoints

### Authentication
- `POST /auth/register`: Register a new airline user.
- `POST /auth/login`: Login and receive a JWT.
- `GET /auth/profile`: Get current user profile (Requires Bearer Token).
- `PUT /auth/profile`: Update user profile.

### Flights
- `GET /flights/search?from=NBO&to=MBA&date=2023-12-25`: Search for flights.
- `GET /flights/{id}`: Get details of a specific flight series.

### Bookings
- `POST /bookings`: Create a new booking.
- `GET /bookings`: List user's bookings.
- `GET /bookings/{reference}`: Get booking details by reference.

### Payments
- `POST /payments/initiate`: Initiate a payment (e.g., M-Pesa).
- `POST /payments/callback`: Webhook for payment status updates.

### Check-In
- `POST /checkin`: Check-in for a flight (select seat, bags).
- `GET /checkin/{booking_id}`: Get check-in details and boarding pass.

## Authentication

All protected endpoints require a Bearer Token in the `Authorization` header:
`Authorization: Bearer <your_jwt_token>`
