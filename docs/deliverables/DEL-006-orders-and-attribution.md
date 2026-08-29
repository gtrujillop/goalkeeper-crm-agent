# DEL-006: Orders and attribution

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-006-orders-attribution` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The store can connect purchases to customers and conversations, and understand
acquisition evidence when it exists without inventing attribution.

## Scope

- Shopify paid, cancelled, fulfilled, and refunded order events.
- Customer and conversation correlation using defensible identity evidence.
- Opportunity conversion and payment-path recording.
- Store-scoped Colombian payment and fulfillment context, initially including
  bank transfer, Mercado Pago, and TCC cash on delivery.
- Instagram referral metadata and Google redirect tokens.
- First-touch and last-touch attribution reporting with confidence/source.
- Direct Shopify purchases with no preceding conversation as a first-class path.

## Acceptance criteria

- [ ] Shopify event processing is idempotent and traceable.
- [ ] A paid order updates the related opportunity when correlation is reliable.
- [ ] Unknown acquisition remains explicitly unknown.
- [ ] Direct purchases appear in the CRM and can initiate delivery follow-up.
- [ ] Bank transfer, MercadoPago through Shopify, and TCC cash-on-delivery paths are represented.
- [ ] First- and last-touch reports expose their underlying evidence.

## Dependencies

- DEL-003.
- DEL-005.

## Out of scope

- Replacing Shopify analytics or advertising-platform reporting.
- Automated media buying or campaign optimization.

## Delivery notes

Identity and attribution confidence must be visible; phone number matching alone
must not silently overwrite contradictory customer evidence.
