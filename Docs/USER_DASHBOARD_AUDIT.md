# User Dashboard Audit

Date: 2026-04-04

## Purpose

This document aligns the current traveler-facing account, profile, dashboard, manage-booking, and cargo progress.

It separates:

- what is already done
- what is partially done
- what is not done yet
- what the existing schema/backend already supports
- what should be included in a strong airline user dashboard

## Executive Summary

The product currently has a solid `Manage Booking / My Trips` foundation, but it is not yet a complete traveler account center.

Today, the frontend is strongest in:

- trip lookup
- authenticated booking list
- booking detail view
- payment continuation
- e-ticket documents
- cargo booking and cargo tracking

The main gap was that the backend already supported a broader account model, but the frontend did not expose it as a real dashboard/profile experience.

In short:

- `Manage` works
- `My Trips` works
- guest OTP access works
- cargo flows are in good shape
- a first `Account / Profile / Loyalty / Notifications` frontend now exists
- remaining work is mostly polish, optimization, and a few deeper controls

## Review Findings

### 1. Resolved: Logout now clears traveler session artifacts

This issue was fixed during the account hub rollout.

Relevant files:

- [authService.ts](/c:/mc_web/app/src/lib/services/auth/authService.ts:89)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:22)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:119)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:261)

Session artifacts that are now cleared on logout:

- `booking_token:{reference}`
- `cargo_token:{awb}`
- cached booking payloads

### 2. Improved: Frontend now exposes a real account surface, but still needs refinement

The copy already tells travelers they can use loyalty and notifications.

Relevant files:

- [login/+page.svelte](/c:/mc_web/app/src/routes/login/+page.svelte:49)
- [signup/+page.svelte](/c:/mc_web/app/src/routes/signup/+page.svelte:63)
- [Navbar.svelte](/c:/mc_web/app/src/lib/components/ui/Navbar.svelte:41)

There is now a dedicated `/account` hub and dedicated account subpages. The signed-in navbar CTA now points to `/account`.

Meanwhile the backend already supports:

- profile read/update
- profile photo upload
- loyalty info/history
- notifications

Relevant backend routes:

- [api/index.php](/c:/mc_web/api/index.php:182)
- [api/index.php](/c:/mc_web/api/index.php:188)
- [api/index.php](/c:/mc_web/api/index.php:299)
- [api/index.php](/c:/mc_web/api/index.php:300)
- [api/index.php](/c:/mc_web/api/index.php:304)

Remaining gap:

- the account hub is live, but richer aggregation and polish are still pending

### 3. Medium: Checked-in dashboard filter is implemented as N+1 requests

Relevant file:

- [manage/+page.svelte](/c:/mc_web/app/src/routes/manage/+page.svelte:88)

The checked-in tab computes status by calling check-in lookup once per booking.

Risk:

- slower dashboard loads for users with many bookings
- mobile/network latency amplification

Recommendation:

- expose check-in summary state in the main bookings list endpoint
- or add a batch check-in summary endpoint

### 4. Low: Some traveler-facing booking pages still have encoding artifacts

Relevant file:

- [my-bookings/[reference]/+page.svelte](/c:/mc_web/app/src/routes/my-bookings/[reference]/+page.svelte:114)

Examples include broken apostrophes/arrows like:

- `couldnâ€™t`
- `â†’`
- `â€”`

Risk:

- trust/quality hit on post-booking pages

Recommendation:

- normalize affected files to UTF-8 clean text

## Current Progress

### Done

#### Authentication and traveler booking access

- login and signup pages exist
- authenticated traveler booking list exists
- guest OTP verification for booking access exists
- session-based booking token flow exists

Relevant files:

- [login/+page.svelte](/c:/mc_web/app/src/routes/login/+page.svelte:1)
- [signup/+page.svelte](/c:/mc_web/app/src/routes/signup/+page.svelte:1)
- [manage/+page.svelte](/c:/mc_web/app/src/routes/manage/+page.svelte:35)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:64)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:82)

#### Manage / My Trips

- authenticated bookings dashboard block in `/manage`
- filters for upcoming, past, pending payment, checked-in, all
- search across PNR, route, and flight
- pagination

Relevant file:

- [manage/+page.svelte](/c:/mc_web/app/src/routes/manage/+page.svelte:272)

#### Booking detail flows

- booking detail page
- hold timer
- resume payment
- e-ticket/documents page

Relevant files:

- [my-bookings/[reference]/+page.svelte](/c:/mc_web/app/src/routes/my-bookings/[reference]/+page.svelte:90)
- [my-bookings/[reference]/pay/+page.svelte](/c:/mc_web/app/src/routes/my-bookings/[reference]/pay/+page.svelte:79)
- [my-bookings/[reference]/documents/+page.svelte](/c:/mc_web/app/src/routes/my-bookings/[reference]/documents/+page.svelte:67)

#### Cargo experience

- public cargo tracking summary
- protected cargo detail retrieval
- cargo OTP request/verify
- cargo access token storage in browser session
- cargo booking success flow improvements
- cargo entry point in Manage page
- AWB sequential stock + check-digit generation + validation
- authenticated cargo history endpoint
- signed-in cargo bookings now link to `user_id` automatically
- conservative cargo backfill migration by exact email match

Relevant files:

- [CargoController.php](/c:/mc_web/api/controllers/CargoController.php:13)
- [20260404_awb_stock_sequence.sql](/c:/mc_web/api/migrations/20260404_awb_stock_sequence.sql)
- [20260404_backfill_cargo_user_links.sql](/c:/mc_web/api/migrations/20260404_backfill_cargo_user_links.sql)
- [manage/+page.svelte](/c:/mc_web/app/src/routes/manage/+page.svelte:570)
- [bookingService.impl.ts](/c:/mc_web/app/src/lib/services/booking/bookingService.impl.ts:231)

#### Account hub

- `/account` overview page exists
- `/account/profile` exists
- `/account/notifications` exists
- `/account/loyalty` exists
- profile photo upload is wired
- profile update is wired
- change password UI is wired
- delete account UI is wired
- navbar signed-in CTA now points to account hub
- navbar shows unread notification badge

Relevant files:

- [account/+page.svelte](/c:/mc_web/app/src/routes/account/+page.svelte:1)
- [account/profile/+page.svelte](/c:/mc_web/app/src/routes/account/profile/+page.svelte:1)
- [account/notifications/+page.svelte](/c:/mc_web/app/src/routes/account/notifications/+page.svelte:1)
- [account/loyalty/+page.svelte](/c:/mc_web/app/src/routes/account/loyalty/+page.svelte:1)
- [accountService.ts](/c:/mc_web/app/src/lib/services/account/accountService.ts:1)
- [Navbar.svelte](/c:/mc_web/app/src/lib/components/ui/Navbar.svelte:1)

### Partially Done

#### Dashboard

What exists:

- `/manage` acts as a traveler dashboard for bookings

What is missing:

- richer aggregation
- next-trip hero
- preferences/settings summary
- deeper operational shortcuts

Assessment:

- `/manage` is a strong `My Trips / Manage Booking` page
- `/account` now covers the essential backend-supported account functions
- the broader dashboard vision is now partially implemented rather than mostly missing

#### Profile

What exists:

- profile fetch/update API
- profile photo upload API
- frontend profile page
- profile edit form
- photo upload UI
- change password UI
- delete account UI

What is missing:

- device/session management UI
- broader traveler preferences model

Relevant backend:

- [AirlineUserController.php](/c:/mc_web/api/controllers/AirlineUserController.php:35)
- [AirlineUserController.php](/c:/mc_web/api/controllers/AirlineUserController.php:181)

#### Loyalty

What exists:

- loyalty tier endpoint
- loyalty history endpoint
- points-award flow in backend
- loyalty frontend page
- loyalty card in account hub

What is missing:

- richer progress visualization

Relevant backend routes:

- [api/index.php](/c:/mc_web/api/index.php:299)
- [api/index.php](/c:/mc_web/api/index.php:300)

#### Notifications

What exists:

- notifications API
- unread count API
- mark-as-read and read-all APIs
- notifications frontend page
- unread badge in navbar

What is missing:

- richer filtering and grouping
- deeper dashboard summaries

Relevant backend routes:

- [api/index.php](/c:/mc_web/api/index.php:304)
- [api/index.php](/c:/mc_web/api/index.php:305)
- [api/index.php](/c:/mc_web/api/index.php:306)
- [api/index.php](/c:/mc_web/api/index.php:307)

### Not Done

#### Frontend account center

- advanced settings screen
- device/session management UI

#### Traveler personalization

- saved traveler profiles
- saved documents/passport shortcuts
- saved communication preferences
- saved payment preferences

#### Dashboard intelligence

- next-trip hero
- upcoming flight timeline
- one-click check-in shortcut from dashboard
- rebook past flight shortcut
- proactive alerts card

#### Cargo under signed-in account

- recent cargo shipments list for authenticated users
- cargo history module within dashboard
- cargo rebook shortcut

## Schema and Backend Readiness

This section confirms whether the current database and API already support the recommended dashboard scope.

### Already Supported by Existing Schema

#### Airline user profile

The `airline_users` table already contains:

- first name / last name
- phone and email
- date of birth
- nationality
- passport number
- frequent flyer number
- member club
- loyalty points
- profile photo URL

Relevant schema:

- [schema.sql](/c:/mc_web/api/schema.sql:169)
- [schema.sql](/c:/mc_web/api/schema.sql:176)
- [schema.sql](/c:/mc_web/api/schema.sql:177)
- [schema.sql](/c:/mc_web/api/schema.sql:178)
- [schema.sql](/c:/mc_web/api/schema.sql:180)
- [schema.sql](/c:/mc_web/api/schema.sql:181)
- [schema.sql](/c:/mc_web/api/schema.sql:182)
- [schema.sql](/c:/mc_web/api/schema.sql:183)

Assessment:

- schema-ready
- API-ready
- frontend-missing

#### Bookings linked to user

The `bookings` table already includes nullable `user_id`.

Relevant schema:

- [schema.sql](/c:/mc_web/api/schema.sql:198)
- [schema.sql](/c:/mc_web/api/schema.sql:221)

Assessment:

- schema-ready
- API-ready
- frontend already partially using this

#### Loyalty

Existing tables:

- `loyalty_points_history`
- `loyalty_tiers`

Relevant schema:

- [schema.sql](/c:/mc_web/api/schema.sql:681)
- [schema.sql](/c:/mc_web/api/schema.sql:697)

Assessment:

- schema-ready
- backend-ready
- frontend-missing

#### Notifications

Existing table:

- `notifications`

Relevant schema:

- [schema.sql](/c:/mc_web/api/schema.sql:743)

Assessment:

- schema-ready
- backend-ready
- frontend-missing

#### Profile photo

Existing support:

- `profile_photo_url` on user
- upload endpoint

Relevant schema and backend:

- [schema.sql](/c:/mc_web/api/schema.sql:183)
- [AirlineUserController.php](/c:/mc_web/api/controllers/AirlineUserController.php:181)

Assessment:

- schema-ready
- backend-ready
- frontend-missing

#### Device tokens

Existing support:

- backend can register device tokens for push-style notification architecture

Relevant backend:

- [AirlineUserController.php](/c:/mc_web/api/controllers/AirlineUserController.php:88)

Assessment:

- backend groundwork exists
- traveler-facing notification UX still missing

### Not Yet Clearly Supported or Not Yet Wired

These are the items that likely need more work beyond frontend integration.

#### Saved traveler profiles / preferences

Current schema shows rich user and booking data, but there is no clear dedicated traveler-preferences model exposed to frontend for:

- saved seat preference
- meal preference
- saved companions
- preferred airport/route defaults

Assessment:

- likely backend/schema extension needed

#### Dashboard aggregation endpoint

There is no clear dedicated `/dashboard` API that returns:

- next trip
- unread notifications
- loyalty summary
- quick action state

Assessment:

- can be assembled client-side initially
- ideal long-term solution is a dedicated dashboard summary endpoint

#### Cargo tied to authenticated user history

Current cargo flow is still guest-first, but there is now an authenticated cargo history path for signed-in users.
Existing rows can be backfilled conservatively by exact email match.

Assessment:

- baseline authenticated cargo history is now implemented
- future work is improving coverage for older guest cargo records and possible claim flows

## Recommended Dashboard Scope

As a senior product/engineering recommendation, the dashboard should be split into two clear surfaces:

### 1. Account Dashboard

Primary purpose:

- signed-in home for the traveler

Should include:

- profile summary
- next trip summary
- loyalty summary
- notifications summary
- quick links to documents, payment, check-in, cargo, and settings

### 2. Manage Booking

Primary purpose:

- operational lookup and trip handling

Should include:

- booking list
- OTP verification for guest bookings
- trip detail access
- payment continuation
- cargo lookup

This keeps information architecture clean:

- `/account` = who you are
- `/manage` = what you are handling right now

## What Should Be Included In A Strong Airline User Dashboard

### Core account summary

- name
- tier
- loyalty points
- profile completion
- profile photo

### Next trip card

- next departure
- route
- check-in state
- payment state
- direct actions

### My trips section

- upcoming
- past
- checked-in
- pending payment

### Loyalty block

- current tier
- points balance
- progress to next tier
- recent history

### Notifications center

- unread count
- operational alerts
- payment reminders
- ticket/document updates
- loyalty updates

### Profile and documents

- personal details
- passport/frequent flyer info
- contact preferences
- photo upload

### Security and settings

- change password
- delete account
- session hygiene
- notification preferences

### Cargo block

- AWB lookup
- recent shipments if account-linked later
- quick action to book cargo again

## Recommended Delivery Plan

### Phase 1

- create `Account Dashboard` route
- show profile summary from existing profile endpoint
- show loyalty summary from existing loyalty endpoint
- show unread notifications count from existing notifications endpoint
- add quick links to bookings, cargo, profile, documents

No schema changes required.

### Phase 2

- create `Profile` page
- wire profile update
- wire profile photo upload
- add change password UI
- add delete account UI

No major schema changes required.

### Phase 3

- create notifications inbox page
- create loyalty history page
- add navbar notification badge
- add dashboard hero for next trip

No major schema changes required.

### Phase 4

- add dashboard aggregation endpoint
- optimize checked-in status to avoid N+1 requests
- add logout cleanup for booking/cargo session artifacts

Backend improvement recommended.

### Phase 5

- evaluate cargo history under authenticated account
- evaluate saved preferences/traveler profiles

This may require backend/schema additions.

## Immediate Priorities

### Highest value next

1. Fix encoding issues on traveler booking pages
2. Optimize checked-in dashboard lookup to avoid N+1 requests
3. Add next-trip hero and richer account aggregation
4. Add session/device management if product wants deeper account controls
5. Decide whether guest cargo should be claimable into account after booking

## Final Assessment

The good news is that we do not need a major schema redesign for the next dashboard milestone.

For the most important traveler account features:

- profile: ready in backend/schema
- profile photo: ready in backend/schema
- bookings: ready and already used
- loyalty: ready in backend/schema
- notifications: ready in backend/schema

So the next meaningful step is not database-heavy work.

The next meaningful step is frontend product integration:

- create a real account dashboard
- expose existing profile capabilities
- surface loyalty and notifications
- tighten session/security hygiene
