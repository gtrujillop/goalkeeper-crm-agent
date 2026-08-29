# Shopify and purchase attribution

## Responsibilities

Shopify is the source of truth for catalogue, variants, prices, availability,
carts, orders, payments, fulfillment, cancellations, and refunds.

The CRM stores normalized references and historical snapshots. It must not claim
live inventory or payment status from cached conversational context.

The CRM is not an alternative Shopify administrator. Detailed order editing,
refunds, fulfillment administration, inventory management, product management,
and financial reporting continue in Shopify. CRM screens provide concise context
and direct links to the corresponding Shopify customer, product, and order.

## Initial product tools

```text
search_products
get_product
create_cart
get_order_status
```

The model never receives a generic GraphQL execution tool. Each application tool
validates a narrow schema, runs an owned query, and returns a compact result.

## Product metadata

Consistent product options or metafields should cover:

- Size and age guidance
- Glove cut
- Palm material
- Recommended surface
- Training or match use
- Grip versus durability
- Care instructions

## Cart correlation

When creating a cart from an assisted conversation, generate opaque signed
correlation tokens for the customer, conversation, opportunity, and optional
campaign touchpoint. Do not expose sequential IDs or personal information.

Store the mapping in `commerce_sessions` and attach supported non-sensitive
attributes to the Shopify cart.

## Order processing

Subscribe to the relevant order lifecycle webhooks. On a paid order:

1. Deduplicate the Shopify event.
2. Resolve its commerce session or verified identity.
3. Link the order to the customer and opportunity.
4. Mark the opportunity as won.
5. Update order count, lifetime value, and last purchase date.
6. Append an `order.paid` activity.
7. Schedule appropriate post-purchase work.

A direct Shopify purchase may have no earlier conversation, opportunity, or known
advertising touchpoint. In that case, create or resolve the CRM customer, record a
direct unassisted purchase, create the relationship timeline entry, and retain
the acquisition source as unknown unless reliable evidence exists.

Identity fallback using phone or email must be normalized and conservative.
Ambiguous orders should enter a reconciliation queue.

## CRM order projection

Store only the fields required for relationship context and local reporting:

```text
shopify_order_id
shopify_order_name
customer_id
financial_status
fulfillment_status
total and currency
purchased_at
shopify_admin_url
last_synced_at
```

The default manager action is `Open order in Shopify`.

## Historical accuracy

Order items retain product, variant, title, option, quantity, and price snapshots.
Catalogue changes must not rewrite historical CRM data.
