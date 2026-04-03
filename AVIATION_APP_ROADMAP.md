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

- `Partially Done` Standardize backend error handling.
  Current state:
  API responses now normalize errors through a shared contract (`status=false`, `message`, `error.code`, `error.message`, `error.request_id`), with request IDs emitted via `X-Request-Id` and unhandled exceptions/fatal errors routed through the same response utility.
  Target:
  Complete controller-level migration to explicit domain error codes and richer `details` fields across all major workflows.

- `Pending` Stop swallowing frontend service failures.
  Target:
  Return typed error states and let the UI distinguish auth issues, network issues, expired holds, and not-found conditions.

- `Done` Fix type and contract inconsistencies.
  Outcome:
  `flightService` and cargo-tracking contract issues were corrected, and the frontend now passes `svelte-check`.

- `Partially Done` Improve payment callback idempotency and traceability.
  Current state:
  Gateway callbacks now finalize through gateway-reference idempotency checks, persist request-scoped callback metadata, and cache replay markers to reduce duplicate side effects.
  Target:
  Add DB-level uniqueness/constraints for gateway references and expand callback audit retention/monitoring to complete end-to-end replay safety.

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

- `Partially Done` Raise frontend polish for airline expectations.
  Current state:
  A branded, illustrated global error experience now exists for 404/500/505 states.
  Target:
  Tighten hierarchy, loading states, empty states, mobile handling, and trust cues across booking, payment, and documents.

- `Pending` Improve accessibility and inclusive design.
  Target:
  Review keyboard flows, focus states, form errors, contrast, and screen reader semantics.

- `Pending` Replace placeholder and fallback content in key journeys.
  Target:
  Replace prototype-style copy, mock assumptions, and simplified content in production journeys.

## Next Recommended Ticket

1. Stop swallowing frontend service failures.
2. Complete explicit controller-level error code migration.
3. Add DB-level gateway reference uniqueness for callback replay hardening.

## Recommended Execution Order

1. Critical Security And Revenue Protection
2. Reliability, Operational Resilience, And Engineering Quality
3. UX, Functional Maturity, And Airline-Grade Product Improvements
