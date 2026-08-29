# DEL-005: Manager CRM workspace

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-005-manager-crm` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The owner or store manager can quickly understand customer context, handle
exceptions, and advance sales from one mobile-friendly workspace.

## Scope

- Exception-driven inbox and customer search.
- Progressive profile with confirmed facts and identity confidence.
- Unified conversation, activity, and order-summary timeline.
- Opportunity pipeline, notes, and follow-up tasks.
- AI enable/disable, assignment, and takeover actions.
- Concise Shopify order cards linking to Shopify order details.

## Acceptance criteria

- [ ] A manager can find a customer by phone or known profile information.
- [ ] The timeline clearly distinguishes customer, agent, system, and manager activity.
- [ ] Conversations needing attention are prioritized with a reason.
- [ ] A manager can pause automation and reply without leaving the conversation.
- [ ] Shopify order details open in Shopify rather than being reimplemented.
- [ ] Primary workflows are usable on a phone-sized viewport.

## Dependencies

- DEL-002.
- DEL-003 for live product and order links.
- DEL-004 for real message delivery; fake delivery may be used during development.

## Out of scope

- General-purpose CRM customization.
- Shopify inventory or fulfillment administration.

## Delivery notes

Optimize for exceptions and next actions rather than exposing every stored field.
