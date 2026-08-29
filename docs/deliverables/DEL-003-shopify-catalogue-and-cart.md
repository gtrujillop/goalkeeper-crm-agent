# DEL-003: Shopify catalogue and cart

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | In Review |
| Branch | `deliverable/DEL-003-shopify-catalogue-cart` |
| Pull request | [#2](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/2) |
| Production | No |
| Production date | — |

## Outcome

The agent can recommend currently purchasable products and give a customer a
Shopify checkout path without duplicating Shopify administration.

## Scope

- Shopify authentication and provider adapter.
- Store-scoped Shopify configuration and explicit price currency.
- Product and variant search with current price and availability.
- Product detail links and cart creation.
- Commerce-session correlation with customer and conversation.
- Test-store fixtures and webhook-ready external identifiers.

## Acceptance criteria

- [x] Product claims presented by the agent originate from Shopify results.
- [x] Unavailable variants are not recommended as purchasable.
- [x] A cart link is associated with its conversation and customer.
- [x] Product prices retain Shopify's currency and use the active profile's locale for display.
- [x] Shopify failures degrade safely and can trigger human takeover.
- [x] Contract and integration tests run against fixtures or a test store.

## Dependencies

- DEL-002.

## Out of scope

- Rebuilding order administration, fulfillment, or refunds.
- Production order attribution and paid-order processing.

## Delivery notes

Use Shopify as the commerce system of record and link operators to authoritative
Shopify screens wherever detailed commerce work is required.

Implemented a store-scoped Shopify Storefront GraphQL adapter, normalized product
and variant results, product links, localized price display, cart creation, and
persisted commerce-session correlation. Deterministic response fixtures cover
the integration contract. On 2026-08-29, the private-token authentication and
read-only product query succeeded against the configured Shopify store and
returned ten products. A subsequent live test located the exact `DEL003 Test
Gloves` product, selected an available variant, created a quantity-one cart in
COP, received a checkout URL on the store domain, and persisted its CRM
correlation. No checkout, order, or payment was submitted. An operator-facing
application workflow is available at `/shopify` with connection status, live
catalogue search, availability-aware variant controls, correlated test-cart
creation, and a checkout link.
