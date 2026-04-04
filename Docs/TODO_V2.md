# V2 TODO

## Deferred From MVP v1

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
