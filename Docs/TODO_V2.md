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
