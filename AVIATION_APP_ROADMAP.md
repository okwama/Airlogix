# Aviation App Roadmap

This roadmap converts the current app review into a practical engineering plan.
It is organized into three sections so we can work through the highest-risk items first, then improve platform reliability, then raise product and UX quality to a stronger airline standard.

## 1. Critical Security And Revenue Protection

These items should be treated as highest priority because they affect passenger data exposure, payment integrity, ticket issuance, or inventory control.

- Protect booking document access.
  Current gap:
  `GET /bookings/{reference}/documents` generates ticket and receipt output without the same authorization guard used by the booking detail endpoint.
  Target:
  Require either authenticated traveler ownership or a valid guest OTP access session before serving any document.
  Outcome:
  Prevent unauthorized access to e-tickets, receipts, passenger names, and booking details.

- Lock down payment status mutation.
  Current gap:
  `POST /bookings/update_payment` can change booking payment state and trigger ticket issuance without a trusted gateway callback or protected internal control.
  Target:
  Restrict payment finalization to verified gateway callbacks or authenticated internal-only actions.
  Outcome:
  Eliminate manual or malicious payment bypass and fraudulent ticket issuance.

- Replace deterministic guest access tokens.
  Current gap:
  Guest access tokens are derived from booking reference and booking id using HMAC and do not expire in a true session-bound way.
  Target:
  Use short-lived, server-stored guest access sessions with expiry, revocation, and optional device binding.
  Outcome:
  Reduce replay risk and align guest booking access with safer session practices.

- Enforce reservation TTL and seat release.
  Current gap:
  Booking hold expiry is documented in comments but not enforced as an operational workflow.
  Target:
  Add a background job or scheduler that expires unpaid holds and releases seat inventory after the reservation window.
  Outcome:
  Prevent stale inventory, false availability, and booking confusion.

- Unify payment initiation validation.
  Current gap:
  Some payment flows validate booking ownership and canonical amount; others trust client-supplied values directly.
  Target:
  Route all payment starts through one authoritative validation path using server-side booking totals and status checks.
  Outcome:
  Consistent payment integrity across Stripe, M-Pesa, Paystack, and future gateways.

- Restrict CORS and harden auth storage strategy.
  Current gap:
  API allows `Access-Control-Allow-Origin: *`, and frontend auth depends on browser storage.
  Target:
  Restrict allowed origins by environment and review long-term move toward safer auth/session handling.
  Outcome:
  Reduce exposure surface for token-bearing application traffic.

- Remove sensitive operational artifacts from repo.
  Current gap:
  Runtime logs, uploads, cache artifacts, and key material appear in the repository tree.
  Target:
  Move secrets and runtime artifacts out of source control, update `.gitignore`, rotate exposed credentials if needed.
  Outcome:
  Improve compliance posture and reduce accidental leakage.

## 2. Reliability, Operational Resilience, And Engineering Quality

These items focus on correctness, maintainability, and recovery under real-world failures.

- Fix booking creation reliability issues.
  Current gap:
  Booking creation references `number_of_passengers` via an undefined variable and has a few fragile assumptions in the booking pipeline.
  Target:
  Clean up booking creation inputs, derived values, and transaction safety.
  Outcome:
  More reliable booking creation and fewer hard-to-debug production failures.

- Standardize backend error handling.
  Current gap:
  Some endpoints return generic failures, some leak implementation detail, and logs are inconsistent.
  Target:
  Adopt a shared API error shape with stable codes, safe user messages, and richer server-side logging.
  Outcome:
  Better debugging, cleaner frontend handling, and safer production responses.

- Stop swallowing frontend service failures.
  Current gap:
  Several frontend services return `null` after fetch failures, making outages look like empty results or missing bookings.
  Target:
  Return typed error states and let the UI distinguish auth issues, network issues, expired holds, and not-found conditions.
  Outcome:
  More trustworthy UI behavior and easier support triage.

- Fix type and contract inconsistencies.
  Current gap:
  Flight search offline mode returns a different shape than online mode, and cargo tracking already shows compile-time issues.
  Target:
  Normalize service contracts, fix Svelte type issues, and make `svelte-check` pass on app code.
  Outcome:
  Better release confidence and fewer runtime regressions.

- Improve payment callback idempotency and traceability.
  Current gap:
  There is some idempotent behavior, but gateway finalization and transaction linking should be stricter and easier to audit.
  Target:
  Ensure callbacks are safe to replay, consistently linked to booking and transaction records, and fully auditable.
  Outcome:
  Stronger financial controls and fewer reconciliation issues.

- Add booking lifecycle observability.
  Current gap:
  There is no clear operational instrumentation for hold creation, hold expiry, payment success, ticket issuance, and document delivery.
  Target:
  Add structured logs and lifecycle events for key reservation states.
  Outcome:
  Easier incident handling and better business monitoring.

- Separate dev-mode behavior from production behavior.
  Current gap:
  Some webhook and payment paths still allow permissive fallbacks suitable for development.
  Target:
  Make production fail closed when required secrets or callback validation are missing.
  Outcome:
  Safer live environment behavior.

## 3. UX, Functional Maturity, And Airline-Grade Product Improvements

These items improve customer trust, usability, and operational clarity in the booking and servicing experience.

- Make booking and payment states honest and explicit.
  Current gap:
  Some flows present a success experience before funds are truly confirmed or ticketing is complete.
  Target:
  Clearly separate `reservation created`, `payment pending`, `payment failed`, `paid`, `ticketing in progress`, `ticket issued`, and `expired`.
  Outcome:
  Less customer confusion and fewer support contacts.

- Add reservation hold countdown and expiry messaging.
  Current gap:
  The user is not clearly shown the hold window or what happens when it expires.
  Target:
  Display hold timer, expiry warnings, and recovery options during checkout.
  Outcome:
  Airline-style transparency around seat holding and payment urgency.

- Improve failure recovery UX.
  Current gap:
  Error messages exist but are not consistently recovery-oriented.
  Target:
  Give users clear next steps for payment retries, expired bookings, document access problems, and interrupted checkout.
  Outcome:
  Better conversion and lower abandonment.

- Strengthen manage-booking and self-service workflows.
  Current gap:
  Manage booking has a good base, but servicing actions are still mostly placeholders.
  Target:
  Expand itinerary actions, add true modification pathways, clearer payment status handling, and stronger check-in integration.
  Outcome:
  Better post-booking experience and reduced support dependency.

- Raise frontend polish for airline expectations.
  Current gap:
  The design is improving, but some pages still feel prototype-level and some operational states are visually underdeveloped.
  Target:
  Tighten hierarchy, loading states, empty states, mobile handling, and trust cues across booking, payment, and documents.
  Outcome:
  More premium and credible passenger experience.

- Improve accessibility and inclusive design.
  Current gap:
  There is no evidence yet of a full accessibility pass.
  Target:
  Review keyboard flows, focus states, form errors, contrast, and screen reader semantics.
  Outcome:
  Better usability, broader customer reach, and closer alignment with mature product standards.

- Replace placeholder and fallback content in key journeys.
  Current gap:
  A few flows still rely on generic placeholders, mock assumptions, or simplified text that would not fit a production airline experience.
  Target:
  Replace placeholder content with real operational copy and behavior.
  Outcome:
  Stronger trust and better production readiness.

## Recommended Execution Order

We should tackle this roadmap in the following order:

1. Critical Security And Revenue Protection
2. Reliability, Operational Resilience, And Engineering Quality
3. UX, Functional Maturity, And Airline-Grade Product Improvements

## Suggested First Ticket

Start with:

- Protect booking document access
- Lock down payment status mutation

These two changes close the highest-risk gaps immediately and give us a safer base for everything else.
