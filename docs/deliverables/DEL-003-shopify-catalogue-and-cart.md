# DEL-003: Shopify catalogue and cart

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-003-shopify-catalogue-cart` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The agent can recommend currently purchasable products and give a customer a
Shopify checkout path without duplicating Shopify administration.

## Scope

- Shopify authentication and provider adapter.
- Product and variant search with current price and availability.
- Product detail links and cart creation.
- Commerce-session correlation with customer and conversation.
- Test-store fixtures and webhook-ready external identifiers.

## Acceptance criteria

- [ ] Product claims presented by the agent originate from Shopify results.
- [ ] Unavailable variants are not recommended as purchasable.
- [ ] A cart link is associated with its conversation and customer.
- [ ] Shopify failures degrade safely and can trigger human takeover.
- [ ] Contract and integration tests run against fixtures or a test store.

## Dependencies

- DEL-002.

## Out of scope

- Rebuilding order administration, fulfillment, or refunds.
- Production order attribution and paid-order processing.

## Delivery notes

Use Shopify as the commerce system of record and link operators to authoritative
Shopify screens wherever detailed commerce work is required.
