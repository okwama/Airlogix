# Aviation App Roadmap

This roadmap is now the live status tracker for the app hardening and product-improvement work. It shows what has already been completed, what is partially complete, what is next, and what is still pending.

## Current State

- Booking holds expire after 30 minutes.
- Expiry cron exists and is intended to run every 5 minutes.
- Travelers can resume payment through Manage Booking + OTP.
- Hold reminder email/SMS is sent after reservation creation.
- Dedicated resume-payment page exists at `/my-bookings/[reference]/pay`.

## 1. Critical Security And Revenue Protection

- `Done` Protect booking document access.
  Outcome:
  Require authenticated traveler ownership or valid guest booking access before serving documents.

- `Done` Lock down payment status mutation.
  Outcome:
  Prevent traveler-facing endpoints from directly marking bookings as paid or triggering ticket issuance.

- `Done` Replace deterministic guest access tokens.
  Outcome:
  Guest booking access now uses short-lived, server-stored opaque sessions with expiry and revocation on reissue.

- `Done` Enforce reservation TTL and seat release.
  Outcome:
  Unpaid holds expire, stale inventory is released, and payment is blocked after hold expiry.

- `Partially Done` Unify payment initiation validation.
  Current state:
  Stripe, M-Pesa, Paystack, Onafriq, and DPO initialization now validate booking access and use DB totals. Legacy/internal payment paths still need consolidation.
  Target:
  Route all payment starts through one authoritative validation path using server-side booking totals and status checks.
  Outcome:
  Consistent payment integrity across current and future gateways.

- `Partially Done` Restrict CORS and harden auth storage strategy.
  Current state:
  API CORS is now origin-restricted by environment/config. Longer-term auth storage strategy still remains.
  Target:
  Restrict allowed origins by environment and review longer-term session/token handling.

- `Done` Remove sensitive operational artifacts from repo.
  Outcome:
  Runtime logs, cache files, uploaded profile photos, key material, and archive/junk artifacts are removed from source control, with placeholder keep-files and tighter ignore rules in place.

## 2. Reliability, Operational Resilience, And Engineering Quality

- `Partially Done` Fix booking creation reliability issues.
  Current state:
  The undefined passenger-count bug is fixed and hold metadata is now persisted. Broader input cleanup and transaction hardening still remain.

- `Pending` Standardize backend error handling.
  Target:
  Adopt a shared API error shape with stable codes, safe user messages, and richer server-side logging.

- `Pending` Stop swallowing frontend service failures.
  Target:
  Return typed error states and let the UI distinguish auth issues, network issues, expired holds, and not-found conditions.

- `Pending` Fix type and contract inconsistencies.
  Current state:
  `svelte-check` still fails because of `flightService` and cargo-tracking issues.
  Target:
  Normalize service contracts and make the app pass `svelte-check`.

- `Pending` Improve payment callback idempotency and traceability.
  Target:
  Ensure callbacks are safe to replay, consistently linked to booking and transaction records, and fully auditable.

- `Pending` Add booking lifecycle observability.
  Target:
  Add structured logs and lifecycle events for hold creation, hold expiry, payment success, ticket issuance, and document delivery.

- `Pending` Separate dev-mode behavior from production behavior.
  Target:
  Make production fail closed when required secrets or callback validation are missing.

## 3. UX, Functional Maturity, And Airline-Grade Product Improvements

- `Partially Done` Make booking and payment states honest and explicit.
  Current state:
  Pending/paid/expired resume flows are much clearer, but success-page consistency and a few downstream states still need cleanup.

- `Done` Add reservation hold countdown and expiry messaging.
  Outcome:
  Travelers can see hold timing, expiry warnings, and recovery options during checkout and on booking detail views.

- `Done` Improve failure recovery UX.
  Outcome:
  Interrupted checkout now has clearer next steps for resume-payment and expired-hold recovery.

- `Done` Strengthen manage-booking and self-service workflows for pending reservations.
  Outcome:
  Travelers can re-enter via OTP, open the booking, and continue payment from a dedicated resume-payment page.

- `Pending` Raise frontend polish for airline expectations.
  Target:
  Tighten hierarchy, loading states, empty states, mobile handling, and trust cues across booking, payment, and documents.

- `Pending` Improve accessibility and inclusive design.
  Target:
  Review keyboard flows, focus states, form errors, contrast, and screen reader semantics.

- `Pending` Replace placeholder and fallback content in key journeys.
  Target:
  Replace prototype-style copy, mock assumptions, and simplified content in production journeys.

## Next Recommended Ticket

1. Clean frontend service/type errors so release checks become reliable.
2. Standardize backend error handling.
3. Improve payment callback idempotency and traceability.

## Recommended Execution Order

1. Critical Security And Revenue Protection
2. Reliability, Operational Resilience, And Engineering Quality
3. UX, Functional Maturity, And Airline-Grade Product Improvements
