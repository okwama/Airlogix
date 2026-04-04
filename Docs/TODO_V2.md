# V2 TODO

## Deferred From MVP v1

### Account Hub Rollout Follow-Up

Status: `in_progress`
Priority: `high`
Scope: `account hub v1.1`

#### Implemented
- Added traveler account hub at `app/src/routes/account/+page.svelte`
- Added profile page with:
  - profile edit
  - profile photo upload
  - change password UI
  - delete account UI
- Added loyalty page
- Added notifications page
- Added unread notification badge in navbar
- Added authenticated cargo shipment history to account hub
- Added conservative cargo user-link backfill migration:
  - `api/migrations/20260404_backfill_cargo_user_links.sql`
- Added logout cleanup for booking/cargo access session artifacts

#### Next Tasks
- Fix UTF-8/encoding artifacts on traveler booking pages
- Optimize checked-in dashboard filter to avoid one request per booking
- Add richer account summary:
  - next trip hero
  - stronger empty states
  - better mobile polish
- Decide whether guest cargo shipments should be claimable into account after booking

---

### Round-Trip Flight Search and Booking

Status: `todo`
Priority: `medium`
Scope: `post-v2 search and booking enhancement`

#### Why Deferred
- Current DB/backend flow is single-flight oriented:
  - `bookings` stores one `flight_series_id`
  - current booking model writes one flight per booking
  - current flight search loader/service only processes `from`, `to`, and `date`
- The homepage `Round Trip` toggle was removed because it was UI-only and not backed by schema or booking flow logic.

#### Tasks
- Extend schema to support round-trip intent:
  - either linked outbound/inbound bookings, or
  - a parent itinerary model with separate outbound and return segments
- Extend search flow to accept:
  - `trip_type`
  - `departure_date`
  - `return_date`
- Update results UI to support:
  - outbound selection first
  - return selection second
  - combined fare summary
- Update booking/checkout flow to persist and price both segments safely
- Update documents, manage booking, and account views to render round-trip itineraries correctly

#### Acceptance Criteria
- User can search one-way or round-trip intentionally
- Return date affects search results and pricing
- Booking persists both segments reliably
- Manage booking, payment, and documents all understand round-trip itineraries

---

### Check-in Luggage Finalization (V2)

Status: `todo`
Priority: `high`
Scope: `v2`

#### Goal
Finalize and charge optional luggage (checked bags and special items) during check-in, not during initial booking hold.

#### Tasks
- Persist selected luggage intent (counts/types) from booking flow for later check-in processing.
- Implement/extend check-in API logic to:
  - price luggage using server-side rules,
  - validate totals server-side,
  - persist luggage records in DB.
- Update payment/ticketing flow to include finalized luggage charges at check-in stage.
- Reflect finalized luggage charges in traveler documents (receipt/ticket summary where applicable).
- Add audit/observability events for luggage finalization success/failure.

#### Acceptance Criteria
- Booking hold total excludes optional luggage charges.
- Check-in computes luggage charges server-side and stores them reliably.
- Traveler sees finalized luggage charges before completing check-in payment.
- API and UI tests cover end-to-end check-in luggage flow.

#### Out of Scope (MVP v1)
- Charging optional luggage during initial booking/reservation hold.

---

### Legal and Compliance Rollout

Status: `todo`
Priority: `high`
Scope: `post-draft legal content`

#### Tasks
- Add cookie consent behavior to match the Cookie Policy (banner + preference storage).
- Run QA pass for legal/support rollout:
  - all footer links work,
  - legal pages render correctly on mobile and desktop,
  - contact details are consistent across all pages,
  - SEO titles/meta are set for all legal routes.
- Publish and store approved legal text/version in docs repository for audit trail.

---

### Cargo Availability Hardening (Minimal Tables)

Status: `in_progress`
Priority: `high`
Scope: `v2`

#### Implemented Foundation
- Added migration: `api/migrations/20260404_minimal_cargo_capacity_foundation.sql`
- Extended `cargo_bookings` with:
  - `chargeable_weight_kg`
  - `booking_phase` (`hold` | `confirmed` | `cancelled`)
  - `hold_expires_at`
  - `capacity_snapshot_kg`
- Added new table: `cargo_capacity_overrides` (per-flight/per-date effective capacity).
- Added new table: `cargo_tariffs` (route/commodity/weight-band pricing).
- Seeded fallback setting key: `cargo_price_per_kg_default`.

#### Next Tasks
- Update cargo availability query to prefer `cargo_capacity_overrides.effective_capacity_kg` over aircraft default.
- Add tariff match logic in API (route + commodity + weight band), fallback to settings default.
- Add hold expiry worker/cron to clear stale holds (`booking_phase='hold'` past `hold_expires_at`).
