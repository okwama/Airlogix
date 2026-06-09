# Implementation Plan: API Fixes

## Overview

7 issues to fix across 3 files. Ordered by dependency — Flight model first since BookingController depends on it.

---

## Fix 1 — `Flight::getById()` Add Return Fare Columns
**File:** `api/models/Flight.php`
**Method:** `getById()`

Add `adult_return_fare`, `child_return_fare`, and `infant_return_fare` to the SELECT statement. These columns exist on `flight_series` and are required for correct return leg pricing in the booking flow. Without this fix, all downstream return fare fixes in the controller are impossible.

---

## Fix 2 — `Flight::search()` and `searchByIds()` Add Return Fare Columns
**File:** `api/models/Flight.php`
**Methods:** `search()`, `searchByIds()`

Add the same three `*_return_fare` columns to both SELECT statements so the frontend receives correct return pricing from search results.

---

## Fix 3 — Remove Tax Calculation, Fix `base_fare` and `taxes_amount`
**File:** `api/controllers/BookingController.php`
**Method:** `create()`

Remove the entire tax calculation block — the `$settingModel` instantiation, the `getByKey('default_tax_rate')` call, the `$taxRateMultiplier` calculation, and the `$baseFare` / `$taxesAmount` derivation from it. Replace with:

- `$baseFare = $expectedTotal`
- `$taxesAmount = 0.00`

Remove the `Setting` model `require_once` and `$settingModel = new Setting(db())` instantiation since it becomes unused.

Update `$bookingData` to pass `base_fare = $expectedTotal` and `taxes_amount = 0.00`.

---

## Fix 4 — Fix Return Leg Fare Calculation
**File:** `api/controllers/BookingController.php`
**Method:** `create()`

**4a — Fix `expectedTotal` calculation for return leg**

The return leg fare loop currently reads `$type . '_fare'`. Change it to read `$type . '_return_fare'` with a fallback to `adult_return_fare`. This depends on Fix 1 being in place so `getById()` actually returns those columns.

**4b — Fix per-passenger fare amounts for `booking_passengers` rows**

Currently the passenger loop uses:
```
$fareAmount = $passengerData['fare_amount'] ?? $bookingData['fare_per_passenger']
```

`fare_per_passenger` is a blended average across all legs and should not be used for individual `booking_passengers` rows. Instead, before the passenger loop, compute two separate fare maps:

- `$outboundFares[$type]` — the one-way fare per passenger type from the outbound `flight_series`
- `$returnFares[$type]` — the return fare per passenger type from the return `flight_series`

Inside the passenger loop, pass `$outboundFares[$passengerType]` when creating the outbound `booking_passengers` row and `$returnFares[$passengerType]` when creating the return row. This ensures each row in `booking_passengers` carries the correct leg-specific fare.

---

## Fix 5 — Fix `payment_method` at Booking Creation
**File:** `api/controllers/BookingController.php` and `api/models/Booking.php`

**In BookingController `create()`:** Remove `payment_method` from `$bookingData` entirely at booking creation time. The payment method is unknown until the user initiates payment — it must not be written as `'pending'` into a column that stores a method name.

**In `Booking::create()`:** Change the `payment_method` param default from `'cash'` to `null`. Since the column allows null, this is safe.

The `payment_method` column on `bookings` will remain null until `updatePaymentStatus()` is called on payment callback, which already accepts and writes the `$method` parameter correctly.

---

## Fix 6 — Add `country_id` and `amount_paid` to Seat Reservation Insert
**File:** `api/controllers/BookingController.php`
**Method:** `create()`

In the `seat_reservations` INSERT:

**`amount_paid`:** Add it to the INSERT column list and pass `0.00` explicitly rather than relying on the column default.

**`country_id`:** Before the INSERT, resolve the primary passenger's nationality to a `country_id`. Query the `Country` table for a match on the nationality string from `$primaryPassenger['nationality']`. If found, pass the ID. If not found, pass `null`. Add this lookup before the seat reservation INSERT, wrapped in a try/catch so a failed country lookup never blocks booking creation.

---

## Fix 7 — Remove Legacy `addPassengers()` Call from Booking Model
**File:** `api/models/Booking.php`
**Method:** `create()`

Remove this block from `Booking::create()`:

```php
if (!empty($data['passengers']) && is_array($data['passengers'])) {
    $this->addPassengers($booking_id, $data['passengers']);
}
```

The controller handles all `booking_passengers` inserts itself via `BookingPassenger` model calls. This block in the model creates duplicate, incomplete rows whenever `$data['passengers']` is passed. The private `addPassengers()` method itself can also be deleted since nothing will call it after this removal.

---

## Fix 8 — Replace Fragile `hasColumn()` Guards for Known Columns
**File:** `api/models/Booking.php`
**Method:** `create()`

The following columns are confirmed present in the live schema and should be written unconditionally — remove their `hasColumn()` guards:

- `is_return_trip`
- `return_date`
- `return_flight_series_id`
- `reservation_expires_at`
- `expired_at`

Move all five directly into the base `$columns` and `$params` arrays. Keep `hasColumn()` only if there are genuinely optional future columns being guarded — there are none currently. This also removes the `information_schema` query risk on the shared cPanel host.

---

## Fix 9 — Move `expireStaleReservations()` Out of Flight Model
**File:** `api/models/Flight.php`
**Method:** `getAvailableSeats()`

Remove the `require_once` for `Booking.php`, the `new Booking($this->conn)` instantiation, and the `$bookingModel->expireStaleReservations()` call from inside `getAvailableSeats()`. The `Flight` model must not instantiate or mutate booking state.

Move the expiry call to wherever `getAvailableSeats()` is invoked at the controller layer — call `expireStaleReservations()` there before calling `getAvailableSeats()`. If it is called from a flight search controller or availability endpoint, add it there.

---

## Implementation Sequence

| Step | Fix | File | Depends On |
|---|---|---|---|
| 1 | Fix 1 | Flight model — `getById()` return fares | — |
| 2 | Fix 2 | Flight model — `search()` / `searchByIds()` return fares | — |
| 3 | Fix 9 | Flight model — remove Booking dependency | — |
| 4 | Fix 3 | BookingController — remove tax calculation | — |
| 5 | Fix 4a | BookingController — return leg `_return_fare` columns | Fix 1 |
| 6 | Fix 4b | BookingController — per-leg fare maps for passengers | Fix 4a |
| 7 | Fix 5 | BookingController + Booking model — `payment_method` null | — |
| 8 | Fix 6 | BookingController — `country_id` and `amount_paid` on seat reservation | — |
| 9 | Fix 7 | Booking model — remove legacy `addPassengers()` | — |
| 10 | Fix 8 | Booking model — remove `hasColumn()` guards | — |

---

## Not In Scope Here (Tracked Separately)

- Journal entry creation on payment callback — covered in the Payment & Accounting implementation plan
- `source` column population — low priority, no functional impact currently
- Observability error message sanitisation — low priority



NEXT






---

# Implementation Plan: Payment Callback GL Posting + Deferred Items

## Overview

Three items to implement across the existing codebase:

1. **Journal entry creation on payment callback** — the core accounting gap
2. **`source` column population** — minor, set from request context
3. **Observability error message sanitisation** — harden before internal details leak

---

## Item 1 — Journal Entry Creation on Payment Callback

### Where it happens

All successful payments — regardless of gateway (M-Pesa, Stripe, Paystack, DPO, Onafriq) — flow through one single method: `PaymentControllerBase::finalizeSuccessfulPayment()` in `api/controllers/payment/PaymentControllerBase.php`.

This is the correct and only place to add journal entry creation. Every gateway controller calls `$this->finalizeSuccessfulPayment()` and nothing else needs to change at the gateway level.

---

### Step 1a — Create `api/models/JournalEntry.php`

New model class responsible solely for GL posting. It must:

- Accept: `booking_id`, `booking_reference`, `amount`, `payment_method`, `entry_date`
- Resolve the debit-side `account_id` from a hardcoded payment method map inside the model:
  - M-Pesa / mpesa → id 23
  - DTB KES / dtb kes → id 21
  - DTB USD / dtb usd → id 22
  - Cash / cash → id 24
  - ABSA / absa → id 26
  - Stripe / stripe → id 21 (DTB KES as default card settlement — confirm with client)
  - Paystack / paystack → id 21
  - DPO / dpo → id 21
  - Any unrecognised method → log a warning and use a configurable fallback account ID
- Query `chart_of_accounts` to confirm the Ticket Revenue account exists (by account name or hardcoded ID noted during setup)
- Generate `entry_number` in format `JE-YYYYMMDD-NNNN` where NNNN is a zero-padded daily sequence. Get the current day's count from `journal_entries` where `entry_date = today` and increment by 1
- Insert one row into `journal_entries` with `status = 'posted'`, `created_by = 1` (system user)
- Insert two rows into `journal_entry_lines`:
  - Line 1: Debit the resolved payment method account, full booking amount, credit = 0
  - Line 2: Credit the Ticket Revenue account, full booking amount, debit = 0
- Validate `total_debit == total_credit` before writing — if they don't match, throw an exception so the outer transaction rolls back
- Return the new `journal_entry_id` on success
- Wrap both inserts in a try/catch — a GL failure must not silently succeed; it should propagate up

---

### Step 1b — Modify `PaymentControllerBase::finalizeSuccessfulPayment()`

**File:** `api/controllers/payment/PaymentControllerBase.php`

This method already does the following in sequence:
1. Idempotency check
2. `bookingModel->updatePaymentStatus()`
3. `seat_reservations` UPDATE
4. `booking_passengers` UPDATE
5. `paymentModel->createGatewayTrace()` / `updateStatus()`
6. `TicketService::issueTickets()` + `sendTicket()`
7. Loyalty points
8. Notification
9. `markCallbackProcessed()`
10. Observability event

**Add after step 2 (after `updatePaymentStatus`) and before step 3:**

Require `JournalEntry` model. Instantiate it with `db()`. Call its `create()` method passing:
- `booking_reference` from `$booking['booking_reference']`
- `amount` from `$booking['total_amount']`
- `payment_method` from `$method` (already normalised to lowercase in the method)
- `entry_date` as today's date

Wrap this call in a try/catch. If it throws, log the error with `error_log()` and emit an observability event `payment.gl_posting_failed` with booking ID and reference. Do not let a GL failure block ticket issuance or notification — the payment has already been confirmed by the gateway. The GL failure should be visible in logs and observability but not surface to the user.

This design means GL posting is best-effort after the payment fact, consistent with how an accountant would reconcile from logs if a posting fails, rather than risking a payment that succeeded at the gateway being stuck in a failed state.

---

### Step 1c — Add `require_once` to `PaymentControllerBase.php`

At the top of `PaymentControllerBase.php`, add:

```
require_once dirname(__DIR__, 2) . '/models/JournalEntry.php';
```

---

### Step 1d — Verify Ticket Revenue account exists in `chart_of_accounts`

Before deploying, run this query on the live database:

```sql
SELECT id, account_name, account_code, account_type 
FROM chart_of_accounts 
WHERE account_name LIKE '%Revenue%' OR account_name LIKE '%Ticket%';
```

If no suitable income account exists, insert one:

```sql
INSERT INTO chart_of_accounts 
  (account_name, account_code, account_type, parent_account_id, is_active, created_at, updated_at)
VALUES 
  ('Ticket Revenue', '400001', 3, 1, 1, NOW(), NOW());
```

Note the auto-generated ID. Hardcode this ID in `JournalEntry.php` as the credit-side account. Account type 3 = income, matching the pattern visible in the existing `chart_of_accounts` data.

---

### Step 1e — Verify journal_entries `created_by` constraint

The `journal_entries` table has `created_by int(11) NOT NULL`. Currently there is no `system` user record constraint enforced — confirm that `created_by = 1` (staff ID 1 or a known admin) exists in the `staff` table or whichever table `created_by` references. If there is no FK on this column (the schema shows none), value `1` is safe to use as a system sentinel.

---

## Item 2 — `source` Column Population

**File:** `api/controllers/BookingController.php`  
**Method:** `create()`

The `bookings.source` column is an enum `('web', 'mobile', 'portal')`. It defaults to `'web'` but is never explicitly set in `$bookingData`.

**Fix:** Before building `$bookingData`, detect the client channel from the request:

- Check for an `X-Client-Channel` header or a `source` field in the request body
- If the value is `'mobile'` or `'android'` or `'ios'`, map to `'mobile'`
- If the value is `'portal'`, map to `'portal'`
- Default to `'web'` for everything else

Add `'source' => $resolvedSource` to `$bookingData` and pass it through to `Booking::create()`, which must include it in the INSERT.

**In `Booking::create()`:** Add `source` to the `$columns` and `$params` arrays unconditionally (the column exists in the live schema).

This is low-effort and makes the `source` field meaningful for reporting — particularly important once the Flutter mobile app and SvelteKit web app are both booking against the same API.

---

## Item 3 — Observability Error Message Sanitisation

**File:** `api/controllers/BookingController.php`  
**Method:** `create()` — the catch block

Current code:

```php
Observability::event('booking.hold_create_failed', [
    'flight_series_id' => $data['flight_series_id'] ?? null,
    'error_message' => $e->getMessage()
]);
```

`$e->getMessage()` on a PDO exception often contains the raw SQL query, table names, and column names. This gets written to the lifecycle log file at `logs/booking_lifecycle_YYYY-MM-DD.log`. If that log is ever exposed (e.g. misconfigured web server, S3 bucket, log aggregation tool with broad access), internal schema details leak.

**Fix:** Before emitting to observability, sanitise the error message:

- If the exception class is `PDOException` or contains a DB-specific pattern (SQLSTATE, table name patterns), replace the message with a generic `'Database error during booking creation'`
- Otherwise pass a truncated version of the message, capped at 200 characters, with any file paths stripped
- Always include the exception class name for debugging context without leaking query internals

Apply the same sanitisation pattern to the existing observability calls inside `PaymentCoreController::callback()` and anywhere else `$e->getMessage()` is emitted directly to observability or structured logs. A shared static helper method on the `Observability` class — `Observability::sanitiseError(Throwable $e): string` — keeps this consistent across the codebase.

---

## Implementation Sequence

| Step | Item | File | Depends On |
|---|---|---|---|
| 1 | Verify/insert Ticket Revenue in chart_of_accounts | DB | — |
| 2 | Confirm created_by=1 is safe | DB | — |
| 3 | Create JournalEntry model | `api/models/JournalEntry.php` | Steps 1, 2 |
| 4 | Add require_once for JournalEntry | `PaymentControllerBase.php` | Step 3 |
| 5 | Add GL posting call in finalizeSuccessfulPayment | `PaymentControllerBase.php` | Step 3 |
| 6 | Add source resolution in BookingController | `BookingController.php` | — |
| 7 | Add source to Booking::create() INSERT | `Booking.php` | Step 6 |
| 8 | Add Observability::sanitiseError() helper | `Observability.php` | — |
| 9 | Apply sanitiseError to all catch blocks emitting to observability | `BookingController.php`, `PaymentCoreController.php` | Step 8 |

---

## Verification After Deployment

```sql
-- 1. Confirm GL entry created after a test payment
SELECT entry_number, reference, total_debit, total_credit, status
FROM journal_entries
WHERE reference = 'YOUR_TEST_BOOKING_REF';

-- 2. Confirm both lines balance
SELECT account_id, debit_amount, credit_amount, description
FROM journal_entry_lines
WHERE journal_entry_id = (
  SELECT id FROM journal_entries WHERE reference = 'YOUR_TEST_BOOKING_REF'
);

-- 3. Confirm source populated correctly
SELECT booking_reference, source, payment_method, payment_account
FROM bookings
WHERE booking_reference = 'YOUR_TEST_BOOKING_REF';
```

Check `logs/booking_lifecycle_YYYY-MM-DD.log` after a failed booking attempt — confirm no SQL or table names appear in the `error_message` field.