# Go-Live Checklist

## Goal

Release the current MVP safely with a clear order of operations for:
- database changes
- environment setup
- frontend/backend deployment
- staging QA
- production verification
- rollback awareness

---

## 1. Pre-Deploy Freeze

Status: `must complete first`

- Confirm the release branch/commit to deploy.
- Stop feature merges until rollout is complete.
- Confirm both `app` and `api` are deploying from the intended revision.
- Confirm you have backup access to:
  - production database
  - production environment variables
  - hosting/platform logs

---

## 2. Database Readiness

Status: `required`

Run these migrations in order:

1. [20260404_awb_stock_sequence.sql](/c:/mc_web/api/migrations/20260404_awb_stock_sequence.sql)
2. [20260404_backfill_cargo_user_links.sql](/c:/mc_web/api/migrations/20260404_backfill_cargo_user_links.sql)

Verify after migration:

- `cargo_awb_stock` table exists
- `cargo_bookings.user_id` backfill completed without SQL errors
- a row exists or can be created for the configured AWB airline prefix

Recommended DB checks:

```sql
SHOW TABLES LIKE 'cargo_awb_stock';

SELECT * FROM cargo_awb_stock;

SELECT COUNT(*) AS linked_cargo_rows
FROM cargo_bookings
WHERE user_id IS NOT NULL;
```

Before production migration:

- take a fresh production backup/snapshot
- note rollback contact/person if database restore becomes necessary

---

## 3. Environment Variables

Status: `required`

### API

Confirm production values for:

- `CARGO_AWB_AIRLINE_PREFIX`
- `CARGO_ACCESS_TOKEN_TTL_SECONDS`
- `CARGO_ACCESS_RESEND_COOLDOWN_SECONDS`
- mailer/email configuration
- SMS configuration if enabled
- payment gateway credentials
- auth/JWT settings

### Frontend

Confirm [app/.env](/c:/mc_web/app/.env) or production environment values for:

- `VITE_API_BASE_URL`
- any branding/domain/base URL values used in production

Verify:

- frontend points to the correct production API
- staging points to staging API, not production

---

## 4. Build and Deploy Order

Status: `recommended order`

### Staging first

1. Deploy API to staging
2. Run DB migrations on staging
3. Deploy frontend to staging
4. Run full staging smoke test

### Production after staging signoff

1. Put support team on standby if needed
2. Take DB backup/snapshot
3. Deploy API to production
4. Run production DB migrations
5. Deploy frontend to production
6. Run production smoke test immediately

---

## 5. Staging QA Checklist

Status: `must pass before prod`

### Auth and Session

- Sign up a new user
- Log in with existing user
- Refresh page and confirm user stays signed in
- Close and reopen browser tab/window and confirm session persists
- Log out and confirm:
  - user is signed out
  - booking/cargo guest session artifacts are cleared

### Account

- Open `/account`
- Confirm:
  - profile summary loads
  - loyalty block loads
  - notifications load
  - bookings load
  - cargo history loads for linked shipments

### Profile

- Edit profile fields
- Upload profile photo
- Change password
- Log out and log back in with the new password

### Notifications

- Open `/account/notifications`
- Mark one notification as read
- Mark all notifications as read
- Confirm unread count badge updates correctly

### Passenger Booking Flow

- Search for flight
- Select flight
- Complete booking wizard
- Reach booking success page
- Open booking detail page
- Continue payment flow
- Open documents page if ticketed/paid

### Guest Passenger Recovery

- Open `/manage`
- Request OTP with booking reference + email
- Verify OTP
- Confirm booking opens successfully

### Cargo Quote and Booking

- Open `/cargo`
- Use real cargo search form
- Test both:
  - `Get instant quote`
  - `Book now`
- Confirm selected values carry to `/cargo-search`
- Select cargo option
- Complete cargo booking
- Confirm AWB is generated
- Confirm cargo success page loads

### Cargo Tracking

- Open `/cargo-tracking`
- Search by AWB
- Confirm public tracking data loads
- Request cargo OTP
- Verify cargo OTP
- Confirm full shipment details unlock

### Signed-In Cargo History

- While signed in, create cargo booking
- Confirm shipment appears in `/account`

### Backfilled Cargo History

- After running backfill migration, confirm older eligible cargo rows appear under account when email matches

---

## 6. Production Smoke Test

Status: `run immediately after deploy`

Run this exact minimum set:

1. Open homepage
2. Confirm navbar loads and primary routes work
3. Log in
4. Refresh once and confirm session persists
5. Open `/account`
6. Open `/manage`
7. Test guest OTP request path for booking
8. Test cargo search from `/cargo`
9. Test cargo tracking lookup
10. Confirm no obvious console/server 500 issues in logs

---

## 7. Functional Routes to Click Through

Status: `manual route verification`

- `/`
- `/login`
- `/signup`
- `/account`
- `/account/profile`
- `/account/notifications`
- `/account/loyalty`
- `/manage`
- `/check-in`
- `/status`
- `/cargo`
- `/cargo-search`
- `/cargo-tracking`

Also verify dynamic flows:

- `/my-bookings/{reference}`
- `/my-bookings/{reference}/pay`
- `/my-bookings/{reference}/documents`
- `/cargo-tracking/{awb}`
- `/cargo-booking/{reference}`
- `/cargo-booking/{reference}/success`

---

## 8. Operational Monitoring After Release

Status: `first 24 hours`

Watch for:

- auth/profile `401` spikes after refresh
- booking creation failures
- cargo booking creation failures
- OTP delivery failures
- payment initialization failures
- document generation failures
- frontend route/load errors

Check:

- API error logs
- payment gateway logs
- mail/SMS provider logs
- frontend hosting logs

---

## 9. Known MVP Limitations

Status: `acceptable for launch`

- round-trip booking is not implemented
- check-in optimization is deferred
- some deeper account polish can happen after launch
- some runtime QA still depends on live-browser validation against deployed services

These are acceptable for MVP as long as the core booking, account, and cargo flows pass staging and smoke tests.

---

## 10. Rollback Triggers

Rollback or hotfix immediately if any of these happen:

- users are consistently logged out on refresh due to production auth failures
- passenger bookings cannot be created
- cargo AWBs cannot be generated
- guest OTP verification is failing broadly
- payment initialization fails broadly
- document access is broken for paid bookings

If rollback is needed:

1. stop new deploys
2. identify whether issue is:
   - frontend only
   - API only
   - DB migration/data issue
3. rollback the affected layer first
4. restore DB only if the issue is data/schema related and cannot be hotfixed safely

---

## 11. Release Signoff

Mark release as complete only when:

- staging checklist is fully passed
- production smoke test is passed
- no critical errors are visible in logs
- account, booking, and cargo flows are all confirmed working

Final signoff:

- `Database`: complete
- `API`: complete
- `Frontend`: complete
- `Staging QA`: complete
- `Production smoke test`: complete
- `Monitoring`: active
