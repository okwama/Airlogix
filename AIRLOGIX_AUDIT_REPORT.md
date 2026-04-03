# Airlogix Airline Booking Platform — Frontend + API Audit (2026-04-01)

This report audits the SvelteKit frontend in `app/` and the PHP API + DB schema in `api/`. It reconstructs the intended lifecycle, classifies feature connectivity, and lists concrete gaps and next steps to move from demo UX to real airline operations (mobile-first, unstable networks, Kinshasa/DRC constraints).

## 1. Executive summary

**Maturity**: **“integration-in-progress”**. The backend contains real operational primitives (webhooks, ticket issuance, notification tables, multiple payment providers). The frontend has strong UX scaffolding but previously contained **fabricated inventory** behavior and had **payment contract mismatches**.

**Biggest strengths**
- **Backend domain surface exists**: `flight_series`, `bookings`, `booking_passengers`, `payment_transactions`, `cargo_bookings`, `airline_users`, `notifications` in [`api/schema.sql`](api/schema.sql).
- **Webhook-driven finalization is implemented** for M‑Pesa callbacks and Stripe (now signature-verifiable).
- The frontend has a coherent booking funnel and sensible UI states (steppers, summaries, basic error boxes).

**Biggest risks / blockers (pre-fix)**
- Frontend flight search could **silently substitute mock flights** when API was empty/slow: [`app/src/lib/services/flightService.js`](app/src/lib/services/flightService.js).
- M‑Pesa polling was **broken** (frontend polled by booking reference; API required `checkout_request_id`).
- `POST /bookings/update_payment` contract mismatch (frontend sent `booking_reference`; API required `booking_id` + `status`).
- Stripe webhook handler accepted unsigned events (“demo mode”).
- Manage/check-in relied on weak identity checks (substring last-name matching).

**What we implemented during this audit**
- **Removed fabricated inventory in production** via explicit `VITE_ENABLE_MOCKS` gating and cache fallback.
- Added **real cargo availability endpoint** `GET /cargo/availability` and wired cargo search to it.
- Fixed **M‑Pesa** polling to use `CheckoutRequestID`.
- Added **Stripe webhook signature verification** when `STRIPE_WEBHOOK_SECRET` is configured.
- Standardized backend **state fields** returned by `GET /bookings/{reference}`: `payment_state`, `ticket_state`, `booking_state`, `next_actions`.
- Added OTP-based booking access endpoints (email) and updated `Manage` + `Check-in` to use them.
- Added booking document endpoint and wired Download flow.
- Added an **offline banner** and lightweight caching of search/booking reads for unstable networks.

## 2. System understanding (actors + lifecycle)

**Actors**
- **Guest traveler**: can create a booking without an account.
- **Registered traveler**: `airline_users` exists; JWT is used for protected endpoints like `GET /bookings` (list).
- **Cargo shipper**: books cargo space and receives an AWB number.
- **Ops/support**: implied by admin scripts and schema breadth, but no dedicated UI in the Svelte app.

**Lifecycle (as the product intends)**
1. Landing → Search flights
2. Select flight series
3. Enter passengers and extras
4. Create booking (PNR/reference)
5. Initiate payment (M‑Pesa / Stripe / bank transfer pending)
6. Webhook/callback finalizes payment
7. Ticket issuance occurs server-side (`booking_passengers.ticket_number`)
8. Email ticket+receipt sent (Mailtrap integration)
9. Customer later accesses booking via secure lookup (now OTP email) and manages/checks-in

## 3. Frontend architecture review

**Framework**: SvelteKit + Svelte 5 runes. See [`app/package.json`](app/package.json).

**Routing**
- Landing: [`app/src/routes/+page.svelte`](app/src/routes/+page.svelte)
- Search results: [`app/src/routes/search/+page.js`](app/src/routes/search/+page.js), [`app/src/routes/search/+page.svelte`](app/src/routes/search/+page.svelte)
- Booking funnel: [`app/src/routes/booking/[reference]/+page.svelte`](app/src/routes/booking/[reference]/+page.svelte)
- Booking success: [`app/src/routes/booking/[reference]/success/+page.js`](app/src/routes/booking/[reference]/success/+page.js), [`app/src/routes/booking/[reference]/success/+page.svelte`](app/src/routes/booking/[reference]/success/+page.svelte)
- Manage: [`app/src/routes/manage/+page.svelte`](app/src/routes/manage/+page.svelte)
- Check-in: [`app/src/routes/check-in/+page.svelte`](app/src/routes/check-in/+page.svelte)
- Cargo search: [`app/src/routes/cargo-search/+page.js`](app/src/routes/cargo-search/+page.js), [`app/src/routes/cargo-search/+page.svelte`](app/src/routes/cargo-search/+page.svelte)

**Data/services**
- Flights/cargo client services: [`app/src/lib/services/flightService.js`](app/src/lib/services/flightService.js)
- Bookings/payments client services: [`app/src/lib/services/bookingService.ts`](app/src/lib/services/bookingService.ts)

**State**
- `bookingStore` is a singleton that generates a client reference used for navigation; backend returns canonical 6-char reference. See [`app/src/lib/stores/bookingStore.svelte.ts`](app/src/lib/stores/bookingStore.svelte.ts).

**Resilience additions**
- Offline banner in [`app/src/routes/+layout.svelte`](app/src/routes/+layout.svelte).
- SessionStorage caching for flight search and booking reads.

## 4. Backend/API architecture review

**Router**: [`api/index.php`](api/index.php) strips `/api/airlogix` and routes to controllers.

**Core schema tables**
- Inventory: `flight_series`, `destinations`, `aircrafts`, `cabin_classes`
- Booking: `bookings`, `passengers`, `booking_passengers`
- Payments: `payment_transactions`
- Users/identity: `airline_users` (JWT)
- Comms: `notifications`, `device_tokens`
- Cargo: `cargo_bookings`

**Payments**
- Stripe Checkout session creation: [`api/services/StripeService.php`](api/services/StripeService.php)
- Stripe webhook (now signature-checking): [`api/controllers/PaymentController.php`](api/controllers/PaymentController.php)
- M‑Pesa STK + callback processing: [`api/services/MpesaService.php`](api/services/MpesaService.php)
- Finalization: `finalizeSuccessfulPayment()` issues tickets + emails documents.

## 5. Feature connectivity matrix

| Feature | Status | Evidence | Missing dependency / risk | Recommended next action |
|---|---|---|---|---|
| Routing + shell | UI only | `app/src/routes/+layout.svelte` | None | Keep |
| Flight search | **Partially connected** | FE calls `/flights/search`, BE queries `flight_series` | Was fabricating inventory; now gated by `VITE_ENABLE_MOCKS` | Add explicit error taxonomy to UI (no inventory vs network error) |
| Booking creation | **Connected** | `POST /bookings` multi-passenger supported | Pricing integrity still weak (client total) | Add server quote + idempotency keys |
| M‑Pesa | **Connected (after fix)** | FE uses CheckoutRequestID polling; BE expects `checkout_request_id` | Polling is not a “final truth” — callback is | Add “payment status by booking_reference” for resumability |
| Stripe | **Partially connected → production-safe path exists** | Session + webhook; signature verification now possible | Requires `STRIPE_WEBHOOK_SECRET` configured | Enforce secret in prod deployments |
| Bank transfer | Partially connected | FE marks pending; BE update_payment now supports reference | Needs reconciliation workflow + proof | Add bank transfer instruction object + support tooling |
| Ticketing | Backend-driven | `TicketService::issueTickets` | Frontend didn’t have a document endpoint | Done: `/bookings/{ref}/documents` |
| Email comms | Backend-driven | `EmailService` Mailtrap | Production provider swap + delivery tracking | Add provider abstraction + delivery audit |
| Manage booking | Now OTP-gated (email) | `/bookings/access/*` + FE changes | `/bookings/{ref}` is still public | Tighten `/bookings/{ref}` in next iteration |
| Check-in | UI scaffold | FE routes to booking; BE has checkin controller | Missing true check-in flow | Define check-in model + seat maps |
| Cargo availability | **Connected (after fix)** | `GET /cargo/availability` | Pricing model is heuristic | Add cargo pricing tables/rules |
| Cargo booking | Connected | `POST /cargo`, `GET /cargo/{awb}` | Success page still uses sessionStorage | Switch success page to fetch by AWB |

## 6. Booking lifecycle map (recommended backend events)

Backend should emit events internally (queue/log) to drive idempotent workflows:
- `BookingCreated(reference, flight_series_id, pax_count, amount)`
- `PaymentInitiated(reference, provider, provider_txn_id)`
- `PaymentSucceeded(reference, provider, receipt)`
- `PaymentFailed(reference, provider, reason)`
- `TicketIssued(reference, ticket_numbers[])`
- `NotificationRequested(reference, channel=email|sms, template)`
- `NotificationDelivered(reference, channel, provider_msg_id)`
- `NotificationFailed(reference, channel, error)`

## 7. Integration gap analysis (specific)

**Contract mismatches we found**
- FE M‑Pesa polling used `reference`; API required `checkout_request_id`.\n
- FE `bookings/update_payment` sent `booking_reference` + `payment_status`; API required `booking_id` + `status`.\n

**Operational gaps remaining**
- Pricing is not quoted server-side from `flight_series` + taxes + ancillaries.\n
- Booking retrieval is still possible via `GET /bookings/{ref}` without auth/OTP.\n
- SMS deliverability is not implemented (email OTP only).\n
- Cargo success page still doesn’t fetch by AWB.\n

## 8. UX and operational issues (Kinshasa-first)

- Offline banner + cached reads added; still need **resumable payment** UI for people who close the browser mid-flow.\n
- OTP should support **SMS** in addition to email; email deliverability is less reliable for many Kinshasa-first users.\n
- Support surfaces: missing explicit “contact support” pathways with reference + issue category.\n

## 9. Security and compliance observations

- Stripe webhook signature verification is now supported (requires `STRIPE_WEBHOOK_SECRET`).\n
- OTP endpoints are rate-limited per IP/reference; still need global rate-limits/WAF in production.\n
- Long-term: `GET /bookings/{ref}` should require a verified access token or authenticated user.\n

## 10. Action plan (prioritized)

### Immediate fixes (1–3 days)
- Configure `STRIPE_WEBHOOK_SECRET` in production and fail closed if missing.\n
- Remove remaining public exposure of booking details by reference (require OTP or JWT).\n
- Make backend compute totals (do not accept client totals as authoritative).\n

### Near-term integration (1–2 weeks)
- Introduce a booking “quote/offer” concept and TTL.\n
- Add `GET /payments/status?booking_reference=...` to support resumability and reduce client polling ambiguity.\n
- Implement SMS OTP for booking access (provider abstraction; store delivery audit in `notifications`).\n

### Production hardening (2–6 weeks)
- Observability: correlation IDs across frontend + API logs.\n
- Retry + idempotency strategy per provider.\n
- Operational tooling: support/admin booking lookup and manual override trails.\n

