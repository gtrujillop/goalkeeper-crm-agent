# Shopify and purchase attribution

## Responsibilities

Shopify is the source of truth for its catalogue, variants, prices, availability,
carts and Shopify-channel orders, payments, fulfillment, cancellations and refunds.
Most sales close through WhatsApp outside Shopify. The CRM owns those native
orders; Shopify integration is optional for registering and tracking them.

The CRM stores normalized references and historical snapshots. It must not claim
live inventory or payment status from cached conversational context.

The CRM is not an alternative Shopify administrator. Detailed order editing,
refunds, fulfillment administration, inventory management, product management,
and financial reporting continue in Shopify. CRM screens provide concise context
and direct links to the corresponding Shopify customer, product, and order.

## Inventory across sales channels

The owner confirmed on 2026-09-05 that Shopify inventory is updated after every
sale, including WhatsApp and direct sales. A separate XLSX inventory document is
maintained with matching stock. Use Shopify as the live inventory source for AI
catalogue answers across channels; the spreadsheet is a reconciliation reference,
not a second runtime dependency or an implemented import.

This operational process is separate from CRM automation: registering a native
order does not update Shopify inventory or create a Shopify order. Do not add an
automatic decrement that would duplicate the existing stock update. Recheck the
selected variant before order confirmation; a stock lookup does not reserve it.
If inventory cannot be retrieved or a discrepancy is reported, request human help.

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

For Shopify-channel orders, the default manager action is `Open order in Shopify`.
Native WhatsApp orders open their CRM detail workspace instead.

## Historical accuracy

Order items retain product, variant, title, option, quantity, and price snapshots.
Catalogue changes must not rewrite historical CRM data.

## DEL-006 webhook operations

Configure `SHOPIFY_WEBHOOK_SECRET` with the signing secret for the sending Shopify
app (or the webhook secret supplied by Shopify Admin for Admin-created
subscriptions). Keep it in the environment. Set each store profile's
`shopify_shop_domain` to its exact `*.myshopify.com` domain; ambiguous or unknown
domains are rejected. This installation uses one Shopify app signing secret;
separate apps require separate deployments or a future per-store secret resolver.

Subscribe `orders/create`, `orders/updated`, `orders/paid`, `orders/cancelled`,
`orders/fulfilled`, and `refunds/create` to `POST /webhooks/shopify`. Send complete
JSON payloads; order events require `id`, `created_at`, and `total_price`. The
endpoint verifies Base64 HMAC-SHA256 against the original request bytes and uses
`X-Shopify-Event-Id` (falling back to `X-Shopify-Webhook-Id`) plus topic and store
for deduplication. Event persistence and Oban insertion share one transaction.
See [Shopify webhook documentation](https://shopify.dev/docs/apps/build/webhooks)
and the [topic payload reference](https://shopify.dev/docs/api/webhooks/2026-01).

Workers serialize by store and rebuild each projection from its recorded events.
The newest order snapshot supplies commerce details; payment, cancellation,
fulfillment evidence and unique refund IDs survive older deliveries. Successful
refund transactions determine the separately displayed refund amount. A refund
arriving before any order snapshot retries; after retry exhaustion, inspect the
failed `shopify_events` record and Oban job, obtain the missing order event, and
retry. No external refund or fulfillment action is executed by this integration.

New assisted carts carry a signed opaque `gk_correlation` attribute. The CRM stores
its customer/conversation mapping and pins an opportunity only when exactly one
nonterminal opportunity exists at cart creation. Old carts without the attribute
can use conservative customer identity fallback but cannot infer an opportunity.
Conflicting identity evidence stays flagged for manual investigation in
`/crm/orders`; automated customer merges and reconciliation overrides are not
implemented. Inspect the candidate IDs and Shopify record before correcting
source data. Follow-up is an internal task, never automatic customer messaging.

Payment gateway names map to `bank_transfer`, `mercado_pago_shopify`, or
`collect_on_delivery`; unrecognized methods remain `unknown`. Override exact
lowercase gateway names through the store's `agent_limits.payment_paths` map.
Fulfillment carrier comes from Shopify tracking-company evidence, with a TCC
shipping-line fallback. Shipping does not imply payment, including COD.

Before deploying, configure subscriptions, confirm a signed test event and
checkout carrying `gk_correlation`, and protect `/crm/orders` with the operator
access work tracked by DEL-009. Production has not been enabled by DEL-006.


## Admin setup and monitoring

Open `/admin` → **Pedidos y atribución** to set the Shopify domain, campaign
WhatsApp number, and custom gateway names. Existing agent budget settings remain
intact. Domains must use `*.myshopify.com`; the form rejects domains already owned
by another profile. Signing-secret readiness shows only configured/missing; the
secret remains environment-managed.

The panel shows the callback address for the current browser origin. Open the
public HTTPS app address before copying it to Shopify. Saving configuration does
not create Shopify subscriptions or backfill historical orders. Follow the panel's
subscription instructions, then check actual receipt in its recent-event monitor.
Counts and the latest 20 events are scoped to the active store; raw customer
payloads and secrets are omitted. Refresh after test delivery or to inspect errors.
Successful processing also refreshes connected Admin panels through store PubSub.
