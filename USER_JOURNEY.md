# Airlogix User Journey - Complete Flow

## System Overview
Airlogix is an **airline booking + cargo management + financial accounting** system. The user journey spans:
- **Flight booking** (single/return trips)
- **Payment processing** (multiple gateways)
- **Check-in & boarding**
- **Financial tracking** (journal entries, revenue recognition)

---

## Architecture: Two Booking Channels

### Channel 1: WEBSITE BOOKING (General Users)
```
User → Website (app) → API → Booking Created (source='web')
  ↓
Payment Gateway (M-Pesa, Stripe, etc.)
  ↓
payment_transactions table (tracks payment)
  ↓
bookings table updated (payment_status='paid')
  ↓
NO journal entry created
  ↓
Status: Temporary hold until ticketed or expired
```

**Key Characteristics:**
- `source = 'web'`
- `agent_id = NULL`, `agency_id = NULL`
- `markup_amount = NULL`
- Payment info stored in `bookings` table: `payment_method`, `payment_reference`, `payment_account`
- NO accounting/revenue recognition (just payment tracking)
- Booking is temporary inventory hold

### Channel 2: AGENT PORTAL BOOKING (Travel Agents)
```
Agent → Portal (admin) → API → Booking Created (source='portal')
  ↓
Agent Markup Applied
  ↓
Agent collects payment from client
  ↓
Agent creates MANUAL Journal Entry:
  - Debit: Bank Account (revenue received)
  - Credit: Ticket Revenue (service provided)
  ↓
Status: Revenue recognized in accounting
```

**Key Characteristics:**
- `source = 'portal'`
- `agent_id = {agent_id}`, `agency_id = {agency_id}`
- `markup_amount = {agent's markup}`
- Full accounting trail in `journal_entries` table
- Revenue recognized immediately

### Why the Difference?
- **Website:** Just a payment processor - money flows to airline, NOT tracked in accounting
- **Agent:** Business partner - receives markup, must reconcile in accounting

---

## Phase 1: DISCOVERY & SEARCH

### Frontend Route: `/search`
**User Action:** Search for flights
- Depart: City/Date
- Return: Date (optional for return trips)
- Passengers: Count + types (adult/child/infant)

### Backend Query:
```
FlightController::search()
  → Flight::search()
    → flight_series table
      - Filter by destinations, date range, fares
      - Join: destinations, aircrafts
    Returns: Available flights with:
      - Flight number, times, fares (adult/child/infant)
      - Aircraft info (seating)
      - Cabin classes available
```

### Tables Involved:
- `flight_series` — recurring flight templates
- `flights` — dated occurrences (one per day per series)
- `destinations` — airport info
- `aircrafts` — aircraft details
- `cabin_classes` — fare tiers (Economy/Business/First)

---

## Phase 2: BOOKING CREATION

### Frontend Route: `/booking/[reference]` (POST on creation)
**User Action:** Select flight + passengers + details
- Select outbound & return flights
- Enter passenger info (name, nationality, ID, age, contact)
- Select cabin class
- View calculated total

### Backend:
```
BookingController::create()

STEP 1: VALIDATE FARES (Server-Side)
  ├─ Query flight_series for adult/child/infant fares
  ├─ Compute expected_total = Σ(passenger_fares)
  ├─ Compare client_total vs expected_total (reject if >5% delta)
  └─ Compute: base_fare, taxes_amount from default_tax_rate

STEP 2: CREATE BOOKING RECORD
  ├─ Generate 6-char booking_reference (IATA style)
  ├─ Determine user_id from JWT token (or null for guest)
  ├─ Calculate reservation_expires_at = NOW() + 30 minutes
  └─ INSERT bookings table:
      - booking_reference (unique)
      - flight_series_id, flight_id
      - passenger_name, passenger_email, passenger_phone (primary)
      - number_of_passengers, fare_per_passenger
      - base_fare, taxes_amount, total_amount
      - payment_status = 'pending'
      - user_id (optional)
      - is_return_trip, return_date, return_flight_series_id (if applicable)

STEP 3: CREATE PASSENGER RECORDS
  For each passenger:
    ├─ INSERT passengers table:
    │   - name, email, contact, nationality
    │   - identification, age, title
    │   - Generate PNR (Passenger Name Record)
    └─ INSERT booking_passengers table (per leg):
        - booking_id, passenger_id
        - flight_series_id, flight_id, travel_date, leg ('outbound')
        - passenger_type, fare_amount
        - (repeat for 'return' leg if is_return_trip=1)

STEP 4: CREATE SEAT RESERVATION
  ├─ INSERT seat_reservations table:
  │   - booking_reference, flight_series_id
  │   - number_of_seats, passenger_name
  │   - status = 'reserved', payment_status = 'unpaid'
  │   - reservation_date, trip_type ('one_way' or 'return')
  └─ Holds inventory (blocks seats for 30 min default)

STEP 5: GENERATE GUEST ACCESS TOKEN
  ├─ Create one-time token (for guests without account)
  ├─ Store in cache (Redis): booking_access_session:{token_hash}
  └─ Return to user for managing booking

STEP 6: SEND NOTIFICATIONS
  ├─ Email: Reservation hold (booking ref, expiry time)
  ├─ SMS: Seats held until [expiry_time]
  └─ Frontend: Display booking_reference + 30-min countdown
```

### Database Tables:
| Table | Action | Key Fields |
|-------|--------|-----------|
| `bookings` | INSERT | booking_reference, flight_series_id, passenger_name, total_amount, payment_status='pending', reservation_expires_at |
| `passengers` | INSERT (N rows) | name, email, contact, nationality, identification, age, pnr |
| `booking_passengers` | INSERT (N rows, 1-2 per passenger) | booking_id, passenger_id, leg ('outbound'/'return'), fare_amount |
| `seat_reservations` | INSERT | booking_reference, flight_series_id, number_of_seats, status='reserved' |
| `booking_status_history` | INSERT (audit) | booking_id, from_status=NULL, to_status='Pending', changed_by_type='system' |

---

## Phase 3: PAYMENT INITIATION

### Frontend Route: `/booking/[reference]` → "Complete Payment"
**User Action:** Choose payment method → Redirected to gateway

### Payment Methods Available:
- M-Pesa (Kenya)
- Stripe (Card)
- Paystack
- Onafriq
- DPO
- Bank Transfer (manual)

### Backend:
```
BookingController::updatePayment() or PaymentController::initiate()

STEP 1: VALIDATE ACCESS
  ├─ Check JWT token (authenticated user) OR
  └─ Validate guest access token

STEP 2: CHECK BOOKING STILL VALID
  ├─ Is payment_status still 'pending'?
  ├─ Is reservation NOT expired?
  └─ Reject if expired (status → 'cancelled')

STEP 3: INITIATE PAYMENT
  ├─ Payment::initiate() → INSERT payment_transactions:
  │   - booking_id, user_id, amount, currency
  │   - payment_method, status='pending'
  ├─ Get external payment gateway URL
  └─ Redirect user to gateway (M-Pesa, Stripe, etc.)

STEP 4: GATEWAY PROCESSES PAYMENT
  └─ User enters credentials → Gateway confirms/rejects
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `payment_transactions` | INSERT | booking_id, user_id, amount, payment_method, status='pending' |

---

## Phase 4: PAYMENT CALLBACK / WEBHOOK

### Trigger: Payment gateway POST to `/api/payment/{gateway}/callback`

### Backend (Website Booking - No Agent Accounting):
```
MpesaPaymentController::callback() (or Stripe, Paystack, etc.)

STEP 1: VERIFY WEBHOOK SIGNATURE
  ├─ Validate X-Request-Signature header
  └─ Prevent replay attacks (idempotency_key)

STEP 2: LOOKUP PAYMENT TRANSACTION
  ├─ Query payment_transactions by transaction_id or payment_reference
  └─ Find linked booking_id

STEP 3: UPDATE TRANSACTION STATUS
  ├─ UPDATE payment_transactions:
  │   - status = 'completed' (if payment_code=0)
  │   - status = 'failed' (if payment_code != 0)
  │   - transaction_id = gateway_transaction_id (e.g., ws_CO_27022026162107806706166875)
  │   - payment_date = NOW()
  │   - metadata = {gateway response JSON}
  └─ Record payment_date = NOW()

STEP 4: UPDATE BOOKING IF SUCCESSFUL
  ├─ If payment_status == 'completed':
  │   ├─ UPDATE bookings:
  │   │   - payment_status = 'paid'
  │   │   - payment_method = {gateway method} (e.g., 'M-Pesa', 'Card', 'Stripe')
  │   │   - payment_reference = {gateway_reference_id} (same as transaction_id)
  │   │   - payment_account = {account used} (optional, e.g., phone # for M-Pesa)
  │   │   - updated_at = NOW()
  │   ├─ Send confirmation email to passenger
  │   ├─ Fire observability event: 'payment.success'
  │   └─ IMPORTANT: NO journal entry created for website bookings
  │       (Accounting only for agents/portal - see Phase 11 for accounting)
  └─ If payment_status == 'failed':
      ├─ UPDATE bookings: payment_status = 'failed'
      ├─ Send failure email
      └─ Fire observability event: 'payment.failed'
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `payment_transactions` | UPDATE | status='completed', transaction_id={gateway_id}, payment_date=NOW(), metadata={JSON} |
| `bookings` | UPDATE | payment_status='paid', payment_method={method}, payment_reference={gateway_ref}, payment_account={optional_account}, updated_at=NOW() |

### Bookings Table - Updated Columns Breakdown:
| Column | Website Booking Value | Purpose |
|--------|----------------------|---------|
| `payment_status` | 'paid' (from 'pending') | Tracks payment state: pending → paid/failed → cancelled |
| `payment_method` | 'M-Pesa', 'Card', 'Stripe', etc | Which gateway processed the payment |
| `payment_reference` | Gateway reference ID | External gateway transaction reference for support/reconciliation |
| `payment_account` | Optional (e.g., phone # if M-Pesa) | Account details used; helps with disputes |
| `revenue_recognized` | 0 (stays false for website) | Only set to 1 when agent processes or ticketed |
| `source` | 'web' | Distinguishes web bookings from agent portal bookings |
| `agent_id` | NULL | Website bookings have no agent |
| `agency_id` | NULL | Website bookings have no agency |
| `markup_amount` | NULL (or 0.00) | No markup on website bookings |
| `status` | 0 (Pending) → 1 (Confirmed after ticketing) | Booking confirmation state

---

## Phase 5: TICKETING (Post-Payment)

### Trigger: Cron job or manual admin action

### Backend:
```
TicketService::issueTickets()

STEP 1: FIND PAID BOOKINGS NOT YET TICKETED
  ├─ SELECT bookings WHERE payment_status='paid' AND status != 1

STEP 2: FOR EACH BOOKING:
  ├─ Query GDS/Airline system to issue e-tickets (external API)
  ├─ Receive ticket_numbers from GDS
  └─ UPDATE booking_passengers:
      - ticket_number = {ticket_from_GDS}
      - ticket_status = 'OPEN'
      - status = 'confirmed'
      - issued_at = NOW()

STEP 3: UPDATE BOOKING RECORD
  ├─ UPDATE bookings:
  │   - status = 1 (Confirmed/Ticketed)
  │   - pnr = {PNR_from_GDS}
  │   - revenue_recognized = 1 (or already done at payment)
  └─ Send e-ticket email to passenger

STEP 4: LOG AUDIT TRAIL
  └─ INSERT booking_status_history:
      - from_status = 'Pending', to_status = 'Confirmed'
      - changed_by_type = 'system'
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `bookings` | UPDATE | status=1, pnr, revenue_recognized=1 |
| `booking_passengers` | UPDATE | ticket_number, ticket_status='OPEN', status='confirmed', issued_at |
| `booking_status_history` | INSERT | from_status='Pending', to_status='Confirmed' |

---

## Phase 6: CHECK-IN (24-48 hrs before flight)

### Frontend Route: `/check-in`
**User Action:** Enter booking_reference + flight_date

### Backend:
```
CheckInController::checkin()

STEP 1: FIND BOOKING & FLIGHT
  ├─ Query bookings by booking_reference
  ├─ Query flight_passengers linked to booking
  └─ Verify flight_date matches and is within check-in window

STEP 2: VALIDATE STATUS
  ├─ ticket_status = 'OPEN' (not 'USED', 'VOID', etc.)
  └─ Booking status = 1 (Confirmed/Ticketed)

STEP 3: REQUEST SEAT ASSIGNMENT
  ├─ Query available seats from aircraft layout
  ├─ Auto-assign or prompt user to select seat
  └─ Reserve seat in inventory system

STEP 4: UPDATE CHECK-IN STATUS
  ├─ UPDATE passengers: booking_status = 'CHECK IN' (or 'CHECKED_IN')
  ├─ UPDATE booking_passengers: status = 'checked_in'
  └─ Generate boarding pass

STEP 5: SEND NOTIFICATIONS
  ├─ Email: Boarding pass attachment
  ├─ SMS: Gate assignment + departure time
  └─ Observability: 'checkin.success'
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `passengers` | UPDATE | booking_status='CHECK IN' |
| `booking_passengers` | UPDATE | status='checked_in' |
| `seat_reservations` | UPDATE (if used) | status='checked_in' |

---

## Phase 7: BOARDING & FLIGHT

### Backend Tracking:
```
BoardingService / FlightService

STEP 1: BOARDING GATE
  ├─ Scan ticket QR code
  ├─ Verify passenger identity
  └─ UPDATE passengers: booking_status = 'Boarded'

STEP 2: IN-FLIGHT (No DB updates)

STEP 3: ARRIVAL
  ├─ Pilot submits flight completion
  └─ UPDATE passengers: booking_status = 'Arrived' or 'Completed'
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `passengers` | UPDATE | booking_status='Boarded' → 'Arrived' |

---

## Phase 8: GUEST BOOKING RECOVERY (Manage Booking)

### Frontend Route: `/manage?reference={ref}&email={email}`
**User Action:** "Manage Booking" (for users without account)

### Backend:
```
BookingController::requestAccessCode()

STEP 1: VALIDATE REQUEST
  ├─ Rate limit: 5 requests per 10 min per IP
  ├─ Cooldown: 60 sec between sends
  └─ Verify booking exists with matching email

STEP 2: GENERATE 6-DIGIT CODE
  ├─ code = random_int(100000, 999999)
  ├─ Store code_hash = sha256(code) in cache
  └─ TTL = 10 minutes

STEP 3: SEND CODE VIA EMAIL/SMS
  ├─ Email channel (if email provided)
  └─ SMS channel (if phone provided & Twilio configured)

STEP 4: USER VERIFIES CODE
  └─ BookingController::verifyAccessCode()
      ├─ Compare sha256(user_code) vs stored code_hash
      ├─ Limit 10 attempts
      └─ If valid: issueGuestAccessToken() (one-time use)
          └─ Return token for X-Booking-Access-Token header

STEP 5: ACCESS BOOKING
  ├─ Include X-Booking-Access-Token in request
  ├─ BookingController::canAccessBooking() validates it
  └─ User can now view/update payment status
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| Cache (Redis) | SET | booking_access_otp:{ref}:{email} → {code_hash, attempts} |
| Cache (Redis) | SET | booking_access_session:{token_hash} → {booking_id, reference} |

---

## Phase 9: AUTO-LINK GUEST TO ACCOUNT

### Trigger: User logs in + guest booking exists

### Backend:
```
BookingController::listByUser()

STEP 1: GET USER PROFILE
  ├─ email = user.email
  └─ phone = user.phone_number

STEP 2: FIND UNLINKED BOOKINGS
  ├─ SELECT bookings WHERE user_id IS NULL
  │   AND (passenger_email = {email} OR passenger_phone = {phone})

STEP 3: AUTO-LINK
  ├─ UPDATE bookings: user_id = {authenticated_user_id}
  │   WHERE (passenger_email = {email} OR passenger_phone = {phone})
  │   AND user_id IS NULL
  └─ Observability: 'booking.auto_linked'

STEP 4: RETURN LINKED BOOKINGS
  └─ Include in user's my-bookings dashboard
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `bookings` | UPDATE | user_id = {authenticated_user_id} (where NULL & email/phone match) |

---

## Phase 10: RESERVATION EXPIRY (Background Job)

### Trigger: Cron job `/bookings/expireStale` or daemon

### Backend:
```
BookingController::expireStale()
  → Booking::expireStaleReservations()

STEP 1: FIND EXPIRED BOOKINGS
  ├─ SELECT bookings WHERE
  │   - payment_status = 'pending'
  │   - reservation_expires_at <= NOW()
  │   - expired_at IS NULL
  └─ Limit: Process in batches (e.g., 100 at a time)

STEP 2: EXPIRE EACH BOOKING
  ├─ UPDATE bookings:
  │   - payment_status = 'cancelled'
  │   - status = 2 (Cancelled)
  │   - expired_at = NOW()
  │   - updated_at = NOW()
  └─ This releases seat inventory back to available

STEP 3: LOG AUDIT TRAIL
  ├─ INSERT booking_status_history:
  │   - from_status = 'Pending', to_status = 'Cancelled'
  │   - reason = 'Reservation expired automatically'
  │   - changed_by_type = 'system'
  └─ Observability: 'booking.hold_expired_batch'
```

### Database Tables:
| Table | Action | Columns |
|-------|--------|---------|
| `bookings` | UPDATE | payment_status='cancelled', status=2, expired_at=NOW() |
| `booking_status_history` | INSERT | from_status='Pending', to_status='Cancelled' |

---

## Phase 11: ACCOUNTING CYCLE (AGENT PORTAL ONLY)

### Important: Website Bookings Are NOT in Accounting
- Website bookings are **temporary holds** on inventory
- NO journal entries created for web bookings
- Payment collected is **NOT** recognized as revenue in accounting
- Only when booking is **ticketed** or **converted to agent booking** does accounting happen

### Agent Portal Revenue Recognition (Different Flow)
```
Agent creates booking via /portal → Sets source='portal' → Adds markup
  ├─ Agent collects payment from client
  ├─ Agent creates MANUAL journal entry for revenue:
  │   ├─ Debit: Bank Account (received cash)
  │   └─ Credit: Ticket Revenue (service provided)
  └─ Creates separate booking record with:
      - source = 'portal'
      - agent_id = {agent_id}
      - agency_id = {agency_id}
      - markup_amount = {marked up price}
```

### Daily/Monthly Processes (Admin/Accounting):

#### A. Expense Recording (Fueling, Maintenance, etc.)
```
Admin records expense:
  ├─ Fueling::record() or ExpenseController::create()
  ├─ Specify: flight, supplier, amount, type
  └─ System creates journal_entries:
      - Debit: Fuel Expense (P&L account) → Cost
      - Credit: Accounts Payable (balance sheet) → Liability
      - reference: flight_series_id or receipt number
      - journal_entry_id links to fuel/expense record
```

#### B. Invoice Payment Processing
```
Admin records payment for expenses:
  ├─ Select invoice/expense to pay
  ├─ Specify: bank account, payment amount
  └─ System creates journal_entries:
      - Debit: Accounts Payable → reduces liability
      - Credit: Bank Account → reduces cash
```

#### C. Financial Reports
```
Admin views reports:
  ├─ Chart of Accounts (GL structure)
  ├─ Trial Balance (debit/credit totals)
  ├─ P&L Report (Revenue - Expenses = Net Income)
  │   Revenue: Agent portal bookings only
  │   Expenses: Fueling, maintenance, salaries
  └─ Balance Sheet (Assets, Liabilities, Equity)
```

### Accounting Tables (Agent/Internal Only):
| Table | Purpose | When Used |
|-------|---------|-----------|
| `chart_of_accounts` | GL structure (Assets, Liabilities, Revenue, Expenses) | Admin setup only |
| `journal_entries` | Transaction batches | Agent bookings, expenses, payments |
| `journal_entry_lines` | Debit/credit pairs | Every transaction |
| `expenses` | Expense tracking (Fuel, maintenance, etc) | Operational expenses |
| `fueling` | Detailed fuel costs | Flight operations |

### Website Bookings vs Agent Bookings:
| Field | Website Booking | Agent Booking |
|-------|-----------------|---------------|
| `source` | 'web' | 'portal' |
| `agent_id` | NULL | {agent_id} |
| `agency_id` | NULL | {agency_id} |
| `markup_amount` | NULL/0.00 | {marked up amount} |
| `payment_status` | 'paid'/'pending'/'failed' | 'paid'/'pending'/'failed' |
| Journal Entry Created? | **NO** | **YES** (manual by agent) |
| Accounting Impact? | **NO** | **YES** (revenue recognized) |

---

## Complete Database Schema Relationship Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER ACCOUNT                              │
│  (airline_users, passengers, saved_passenger_profiles)          │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
        ┌──────────────────┐      ┌──────────────────┐
        │  FLIGHT SEARCH   │      │   BOOKING        │
        │  flight_series   │      │   (main record)  │
        │  flights         │      │                  │
        │  destinations    │      │ - booking_ref    │
        │  aircrafts       │      │ - passenger_info │
        │  cabin_classes   │      │ - fares          │
        └──────────────────┘      │ - payment_status │
                    │             │ - reservation_   │
                    └─────────────┤  expires_at      │
                                  └──────────────────┘
                                       │
                        ┌──────────────┼──────────────┐
                        ▼              ▼              ▼
           ┌────────────────────┐  ┌──────────────┐  ┌─────────────────┐
           │  BOOKING_          │  │  PASSENGERS  │  │  SEAT_          │
           │  PASSENGERS        │  │              │  │  RESERVATIONS   │
           │                    │  │ - name       │  │                 │
           │ - booking_id       │  │ - nationality│  │ - booking_ref   │
           │ - passenger_id     │  │ - id_number  │  │ - flight_series │
           │ - ticket_number    │  │ - age        │  │ - status        │
           │ - fare_amount      │  │ - title      │  │ - payment_      │
           │ - travel_date      │  │ - booking_   │  │   status        │
           │ - leg (outbound/   │  │   status     │  └─────────────────┘
           │   return)          │  └──────────────┘
           └────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  PAYMENT FLOW        │
        │                      │
        │ payment_transactions │
        │ - booking_id         │
        │ - amount             │
        │ - payment_method     │
        │ - transaction_id     │
        │ - payment_reference  │
        │ - status             │
        └──────────────────────┘
                   │
                   ▼ (when paid - WEBSITE)
        ┌──────────────────────┐
        │  UPDATE BOOKING      │
        │                      │
        │ - payment_status     │
        │   ='paid'            │
        │ - payment_method     │
        │ - payment_reference  │
        │ - payment_account    │
        │                      │
        │ ❌ NO JOURNAL ENTRY  │
        │ (website only)       │
        └──────────────────────┘

        (AGENT PORTAL ONLY:
         Manual journal entry
         created separately)
```

---

## Key Data States & Transitions

### Booking Status Lifecycle:
```
    CREATE
      ↓
  Pending (0)
   ├─ [Payment]→ Paid
   │              ├─ [Ticketing]→ Confirmed (1)
   │              │                 └─ [Boarding]→ Boarded
   │              │                    └─ [Arrival]→ Completed
   │              │
   │              └─ [No ticketing]→ Pending Ticketing
   │                  └─ [Timeout]→ Cancelled (2)
   │
   └─ [Expiry Timer]→ Cancelled (2)
      (30 min default)
```

### Payment Status Lifecycle (Website Booking):
```
pending (initial)
  ├─ [Payment Gateway Success]→ paid
  │   └─ ❌ NO journal entry (website only)
  │       (Agent portal creates manual entry)
  ├─ [Payment Gateway Fail]→ failed
  └─ [Expiry]→ cancelled
```

### Seat Reservation Status:
```
reserved (initial)
  ├─ [Check-in]→ checked_in
  │   └─ [Boarding]→ boarded
  └─ [Expiry]→ cancelled
```

---

## Multi-Stage User Journeys

### Journey A: Guest → Book → Pay → Check-in (No Account)
1. Search flights (`/search`)
2. Create booking (Guest mode, no JWT)
3. Receive booking_reference + 6-digit access code
4. Complete payment via gateway callback
5. Auto-expire if not paid in 30 min
6. Check-in via `/manage?reference={ref}&email={email}` + OTP code
7. Generate boarding pass

### Journey B: Registered User → Book → Pay → Account Dashboard
1. Login (`/login`)
2. Search flights (`/search`)
3. Create booking (JWT token auto-assigns user_id)
4. Complete payment
5. View in `/my-bookings` dashboard
6. Download e-ticket from booking page
7. Check-in

### Journey C: Agent Portal → Bulk Booking (Advanced)
1. Agent logs in (portal credentials)
2. Create booking on behalf of passenger
3. Markup fare configured per agency
4. Collect payment from passenger
5. Issue ticket + boarding pass

---

## Financial Accounting Integration (AGENT PORTAL ONLY)

### Website Bookings: NO Accounting
- Website payments are **NOT** journal entries
- Money flows to airline account directly
- No revenue recognition in accounting system
- Just payment transaction tracking

### Agent Portal: Manual Journal Entry
When agent creates booking and collects payment:
```
JE-20260530-0001 (MANUAL - Agent creates via portal)
  Debit:  Bank Account                350.00
  Credit: Ticket Revenue              350.00
  Status: Posted
  Reference: Booking reference
  Created by: Agent (agent_id)
```

This is manually created, NOT automatic.

### Key Account Mappings:
| Transaction Type | Debit Account | Credit Account | When Used |
|------------------|---------------|----------------|-----------|
| **Agent Booking Payment** | Bank Account | Ticket Revenue | Agent portal only |
| **Fueling Expense** | Fuel Expense | Accounts Payable | Operations |
| **Maintenance** | Maintenance Expense | Accounts Payable | Operations |
| **Salary** | Salary Expense | Bank | Payroll |

---

## Balance Sheet Impact (Agent Bookings Only)

**Website Booking Payment:** No impact on accounting
- Money goes to airline bank account
- System just tracks payment status

**Agent Booking Payment:** Accounting entries
- **Assets** (Increase):
  - Bank Account: +350 (revenue received from agent)
- **Revenue**:
  - Ticket Revenue: +350 (service provided)
- **Agent Commission** (optional):
  - Commission Payable: +commission_amount

---

## Summary: 9 Core Tables

### Website Booking Flow (7 Tables):
| # | Table | Purpose | Key Columns | Lifecycle |
|---|-------|---------|-----------|-----------|
| 1 | `flight_series` | Recurring flights | flt, std, sta, adult_fare, child_fare | Managed by airline |
| 2 | `flights` | Dated flight instances | series_id, flight_date, seats_available | Generated daily/weekly |
| 3 | `bookings` | Main booking record | booking_reference, flight_series_id, payment_status, user_id, **payment_method, payment_reference, payment_account** | CREATE → UPDATE (pay) → UPDATE (expire) |
| 4 | `passengers` | Passenger details | name, nationality, identification, age, pnr | CREATE once per passenger |
| 5 | `booking_passengers` | Link bookings → passengers | booking_id, passenger_id, ticket_number, leg | CREATE → UPDATE (ticket) |
| 6 | `seat_reservations` | Inventory holds | booking_reference, flight_series_id, status, payment_status | CREATE → UPDATE (check-in/expire) |
| 7 | `payment_transactions` | Payment records | booking_id, amount, payment_method, status, **transaction_id, payment_reference, metadata** | INSERT → UPDATE (callback) |

### Accounting Tables (Agent Portal & Operations Only - 2 Tables):
| # | Table | Purpose | When Used | Key Columns |
|---|-------|---------|-----------|-------------|
| 8 | `journal_entries` | Accounting batches | Agent bookings, expenses, payments | entry_number, entry_date, reference, total_debit, total_credit, status |
| 9 | `journal_entry_lines` | Debit/credit detail | Every accounting transaction | journal_entry_id, account_id, debit_amount, credit_amount |

---

## Quick Reference: Payment Columns Flow (Website Booking)

### When Payment Initiated:
```
Frontend → POST /payment/initiate
  ├─ payload: { booking_id, amount, payment_method }
  ├─ INSERT payment_transactions:
  │   - booking_id, user_id, amount, currency
  │   - payment_method (selected by user)
  │   - status = 'pending'
  └─ Redirect to gateway (M-Pesa, Stripe, etc.)
```

### When Gateway Callback Received:
```
Gateway → POST /payment/{gateway}/callback
  ├─ payload: { transaction_id, status, message, ... }
  ├─ UPDATE payment_transactions:
  │   ✓ status = 'completed' or 'failed'
  │   ✓ transaction_id = {gateway_transaction_id}
  │   ✓ payment_reference = {gateway_reference}
  │   ✓ payment_date = NOW()
  │   ✓ metadata = {JSON from gateway}
  └─ If completed → Call updatePaymentStatus()
```

### When updatePaymentStatus() Called (Booking.php line 235):
```php
$bookingModel->updatePaymentStatus(
  $booking_id,
  'paid',  // status parameter
  $payment_method,  // method parameter (optional)
  $payment_reference,  // reference parameter (optional)
  $payment_account  // account parameter (optional)
);
```

### Updates to Bookings Table:
```sql
UPDATE bookings SET
  payment_status = 'paid',
  payment_method = '{payment_method}',  -- e.g., 'M-Pesa'
  payment_reference = '{transaction_id}',  -- e.g., 'ws_CO_27022026162107...'
  payment_account = '{account_info}',  -- e.g., phone number for M-Pesa
  updated_at = NOW()
WHERE id = {booking_id}
```

### Current Implementation Gap:
- PaymentCoreController only passes: `$booking['payment_method']`
- Should also pass: `$transaction['payment_reference']`, `$transaction['payment_account']`
- Recommendation: Update callback to include all gateway details

---

## Missing Pieces (Not Yet Implemented)

1. **Ticketing Integration** — Currently no external GDS/airline system integration for actual e-ticket generation
2. **Loyalty Points** — Loyalty table exists but no points issuance on booking creation
3. **Refunds/Amendments** — No refund flow or booking amendment logic (amendment table schema exists but unused)
4. **Multi-Currency** — Exchange rates table exists; currency conversion in place for documents but not for payments
5. **Email Templates** — Hardcoded email body; could use template system
6. **Agent Commission** — Agent markup stored but no automated commission calculation/payout
7. **Cargo Accounting** — Separate cargo_bookings flow but cargo revenue not integrated into main accounting

