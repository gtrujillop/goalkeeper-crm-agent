# DEL-008: Retention workflows

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-008-retention-workflows` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The store builds consent-aware repeat relationships through useful post-purchase
care and timely follow-up rather than indiscriminate messaging.

## Scope

- Delivery-confirmation and satisfaction follow-up.
- Product-care guidance based on purchased items.
- Consent and contact-preference enforcement.
- Replenishment estimates and returning-customer context.
- Customer segments and repeat-purchase cohort reporting.

## Acceptance criteria

- [ ] Fulfilled purchases can schedule a traceable follow-up task.
- [ ] Messages respect consent, WhatsApp windows, and template requirements.
- [ ] A manager can review, cancel, or take over scheduled outreach.
- [ ] Recommendations use confirmed purchase history and current Shopify data.
- [ ] Repeat-purchase and cohort metrics can be inspected without exporting raw conversations.

## Dependencies

- DEL-006.
- DEL-007.

## Out of scope

- High-volume campaign automation.
- Contacting customers without an appropriate legal and platform basis.

## Delivery notes

Begin with post-delivery confirmation because it matches the store's current
manual workflow and provides value before predictive replenishment.
