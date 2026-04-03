# AirLogix — API Reference

**Base URL:** `https://impulsepromotions.co.ke/api/airlogix`
**Version prefix** (optional): `/v1/` — stripped server-side
**Auth:** `Authorization: Bearer <jwt_token>`
**Content-Type:** `application/json`

> Routes marked 🔓 are public (no token required). Routes marked 🔒 require Bearer JWT.

---

## Auth

| Method | Path                      | Auth | Notes                                                                         |
| ------ | ------------------------- | ---- | ----------------------------------------------------------------------------- |
| POST   | `/auth/register`        | 🔓   | `phone_number`, `password`, `first_name`, `last_name`, email optional |
| POST   | `/auth/login`           | 🔓   | `phone_number` or `email`, `password` → returns JWT                    |
| GET    | `/auth/profile`         | 🔒   | Returns current user profile                                                  |
| PUT    | `/auth/profile`         | 🔒   | Update profile fields                                                         |
| PUT    | `/auth/password`        | 🔒   | `current_password`, `new_password`                                        |
| POST   | `/auth/forgot-password` | 🔓   | `phone_number` → sends OTP                                                 |
| POST   | `/auth/reset-password`  | 🔓   | `phone_number`, `code`, `new_password`                                  |
| POST   | `/auth/device-token`    | 🔒   | `token`, `platform` (ios/android)                                         |
| POST   | `/auth/profile-photo`   | 🔒   | Multipart upload → Cloudinary                                                |
| DELETE | `/auth/delete-account`  | 🔒   | Soft delete / deletion request                                                |

---

## Flights

| Method | Path                                                    | Auth | Notes                                                                        |
| ------ | ------------------------------------------------------- | ---- | ---------------------------------------------------------------------------- |
| GET    | `/flights/search?from=NBO&to=DAR&date=2026-04-10`     | 🔓   | `from`/`to` = IATA code or city name. Returns flight series with pricing |
| GET    | `/flights/{id}`                                       | 🔓   | Single flight series detail                                                  |
| GET    | `/flights/status?flight_number=RY101&date=2026-04-10` | 🔓   | Also accepts `from` + `to` + `date`                                    |
| GET    | `/cabin-classes`                                      | 🔓   | Economy / Business / First with benefits                                     |
| GET    | `/destinations`                                       | 🔓   | All available airports/cities                                                |

---

## Bookings

| Method | Path                         | Auth | Notes                                                                                                                    |
| ------ | ---------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------ |
| POST   | `/bookings`                | 🔓*  | Create booking. Passenger must provide flight_series_id, passengers array, payment_method. Returns `booking_reference` |
| GET    | `/bookings`                | 🔒   | List authenticated user's bookings                                                                                       |
| GET    | `/bookings/{reference}`    | 🔓*  | Get booking by reference (e.g.`BKMISVXKRH6OZ0`)                                                                        |
| POST   | `/bookings/find`           | 🔓   | Find booking by reference + contact info                                                                                 |
| POST   | `/bookings/update_payment` | 🔓   | Link payment result to booking                                                                                           |

> *Booking creation and lookup are semi-public to support agent-assisted booking. Auth is validated but not strictly required for guest-initiated flows.

---

## Payments

### M-Pesa (Daraja STK Push — Kenya)

| Method | Path                                     | Auth | Notes                                                                    |
| ------ | ---------------------------------------- | ---- | ------------------------------------------------------------------------ |
| POST   | `/payments/mpesa/initialize`           | 🔒   | `booking_reference`, `phone_number`, `amount` → triggers STK push |
| POST   | `/payments/mpesa/callback`             | 🔓   | Safaricom webhook (internal)                                             |
| GET    | `/payments/mpesa/status?reference=...` | 🔒   | Poll payment transaction status                                          |

### DPO Pay (Card — multi-country)

| Method | Path                         | Auth | Notes                                                                  |
| ------ | ---------------------------- | ---- | ---------------------------------------------------------------------- |
| POST   | `/payments/dpo/initialize` | 🔒   | `booking_reference`, `amount`, `currency` → returns payment URL |
| GET    | `/payments/dpo/callback`   | 🔓   | DPO redirect callback (browser)                                        |
| GET    | `/payments/dpo/verify?...` | 🔒   | Verify DPO transaction                                                 |

### Paystack (Card — East/West Africa)

| Method | Path                                        | Auth | Notes                                      |
| ------ | ------------------------------------------- | ---- | ------------------------------------------ |
| POST   | `/payments/paystack/initialize`           | 🔒   | Returns `authorization_url` for redirect |
| GET    | `/payments/paystack/verify?reference=...` | 🔒   | Verify after redirect                      |
| POST   | `/payments/paystack/webhook`              | 🔓   | Paystack webhook (internal)                |

### Onafriq (Mobile Money — Central Africa)

| Method | Path                             | Auth | Notes                            |
| ------ | -------------------------------- | ---- | -------------------------------- |
| POST   | `/payments/onafriq/initialize` | 🔒   | Central Africa mobile money push |
| POST   | `/payments/onafriq/callback`   | 🔓   | Onafriq webhook (internal)       |
| GET    | `/payments/onafriq/status?...` | 🔒   | Poll status                      |

### Legacy

| Method | Path                   | Auth | Notes                          |
| ------ | ---------------------- | ---- | ------------------------------ |
| POST   | `/payments/initiate` | 🔒   | Generic initiate (older route) |
| POST   | `/payments/callback` | 🔓   | Generic callback (older route) |

---

## Check-in

| Method | Path                      | Auth | Notes                                                                                |
| ------ | ------------------------- | ---- | ------------------------------------------------------------------------------------ |
| POST   | `/checkin`              | 🔒   | `booking_reference` (and optionally seat preference) → returns boarding pass data |
| GET    | `/checkin/{booking_id}` | 🔒   | Get check-in details and boarding pass for a booking                                 |

---

## Loyalty

| Method | Path                 | Auth | Notes                                             |
| ------ | -------------------- | ---- | ------------------------------------------------- |
| GET    | `/loyalty/info`    | 🔒   | Current tier, points balance, next tier threshold |
| GET    | `/loyalty/history` | 🔒   | Paginated earn/deduct history                     |

---

## Notifications

| Method | Path                            | Auth | Notes                            |
| ------ | ------------------------------- | ---- | -------------------------------- |
| GET    | `/notifications`              | 🔒   | List all notifications           |
| GET    | `/notifications/unread-count` | 🔒   | Returns `{ count: N }`         |
| POST   | `/notifications/read/{id}`    | 🔒   | Mark single notification as read |
| POST   | `/notifications/read-all`     | 🔒   | Mark all as read                 |
| DELETE | `/notifications/{id}`         | 🔒   | Delete notification              |

---

## Home & Utility

| Method | Path                | Auth | Notes                                           |
| ------ | ------------------- | ---- | ----------------------------------------------- |
| GET    | `/home-content`   | 🔓   | Offers, deals, banners for home screen carousel |
| GET    | `/currency/rates` | 🔓   | Cached exchange rates (TTL 15 min)              |
| GET    | `/health`         | 🔓   | `{ status: "ok" }` — for connectivity check  |

---

## Standard Response Shape

```json
// Success
{ "status": true, "data": { ... } }
{ "status": true, "data": [ ... ] }

// Error
{ "status": false, "message": "Human-readable error" }

// 401 Unauthorized
{ "error": "Unauthorized" }

// 404 Not Found
{ "error": "Not found" }

// 500 Server Error
{ "error": "Internal server error" }
```

---

## Flutter Integration Notes

- Store JWT in `flutter_secure_storage`
- Inject JWT via Dio interceptor on every 🔒 request
- On 401 response → clear token → redirect to `/login`
- For M-Pesa: `initializeMpesa` → show `MpesaWaitingPage` → poll `/mpesa/status` every ~3s
- For DPO/Paystack: open `authorization_url` in in-app WebView → capture callback URL redirect → call verify
- `booking_reference` format: alphanumeric uppercase string (e.g. `BKMISVXKRH6OZ0`)
