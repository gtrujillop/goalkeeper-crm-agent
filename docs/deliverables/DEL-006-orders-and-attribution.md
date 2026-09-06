# DEL-006: Orders and attribution

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | In Review |
| Branch | `deliverable/DEL-006-orders-attribution` |
| Pull request | [#5](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/5) |
| Production | No |
| Production date | — |

## Outcome

The store can register and manage its primary WhatsApp sales outside Shopify,
connect purchases from both channels to customers and conversations, and
understand acquisition evidence without inventing attribution.

## Scope

- Native WhatsApp order registration, agreed item and delivery snapshots, and
  auditable bank-transfer/COD payment and fulfillment tracking outside Shopify.

- Shopify paid, cancelled, fulfilled, and refunded order events.
- Customer and conversation correlation using defensible identity evidence.
- Opportunity conversion and payment-path recording.
- Store-scoped Colombian payment and fulfillment context, initially including
  bank transfer, Mercado Pago, and TCC cash on delivery.
- Instagram referral metadata and Google redirect tokens.
- First-touch and last-touch attribution reporting with confidence/source.
- Direct Shopify purchases with no preceding conversation as a first-class path.

## Acceptance criteria

- [x] A manager can register a WhatsApp sale from its conversation without Shopify.
- [x] Native payment and delivery states change independently with an audit trail.
- [x] Orders, follow-up and attribution include native WhatsApp and Shopify sales.

- [x] Shopify event processing is idempotent and traceable.
- [x] A paid order updates the related opportunity when correlation is reliable.
- [x] Unknown acquisition remains explicitly unknown.
- [x] Direct purchases appear in the CRM and can initiate delivery follow-up.
- [x] Native bank transfer and cash-on-delivery sales are supported alongside Mercado Pago through Shopify.
- [x] First- and last-touch reports expose their underlying evidence.
- [x] Admin exposes order-integration setup, campaign routing, and store-scoped reception/processing evidence.

## Required context

- [Native WhatsApp orders](../product/whatsapp-orders.md)

- [Shopify integration](../integrations/shopify.md)
- [Advertising attribution](../integrations/advertising-attribution.md)
- [Domain model](../domain/domain-model.md)

## Dependencies

- DEL-003.
- DEL-005.

## Out of scope

- Replacing Shopify analytics or advertising-platform reporting.
- Automated media buying or campaign optimization.

## Delivery notes

Identity and attribution confidence must be visible; phone number matching alone
must not silently overwrite contradictory customer evidence.

- Implemented signed `POST /webhooks/shopify` ingestion with shop-domain routing,
  event deduplication, atomic Oban enqueueing, durable payloads, and store-serialized
  order projections for create/update/paid/cancelled/fulfilled/refund events.
- Added signed opaque cart attributes and persisted session/opportunity mappings.
  Only a reliably linked opportunity becomes won on payment; ambiguous identities
  remain in the reconciliation filter and cannot initiate follow-up.
- Added `/crm/orders` with direct purchases, Shopify links, lifecycle event history,
  identity evidence, payment/fulfillment context, and idempotent delivery tasks.
- Captured inbound Meta/Instagram referral evidence and expiring, single-claim
  Google redirect tokens. First/last touch reports retain unknown paid revenue,
  separate currencies, and show source, confidence, timestamps, and raw evidence.
- Added derived customer purchase count, net lifetime value, and last-purchase date
  by currency, without counting duplicate events.
- `mix precommit` passed on 2026-09-05: 65 tests, 0 failures.
- Applied both migrations locally. Shopify webhook subscriptions and signed
  sample delivery are configured and validated; a real checkout-to-order
  correlation check remains before enabling that channel in production.
- Local `/crm/orders` returned HTTP 200; empty-state browser inspection passed at 390px and 1440px widths.

- Added a prominent Admin section for Shopify order and attribution setup, with a
  direct orders link, validated shop domain and campaign WhatsApp destination,
  optional custom payment names, masked signing-secret readiness, subscription
  instructions, and a generated campaign URL.
- Added store-scoped processing/error counts, latest receipt, Meta/Google evidence
  counts, and a bounded recent-event monitor with refresh. The panel distinguishes
  saved configuration from actual event receipt; it does not claim subscriptions
  were created or import historical orders.
- Admin tests cover settings preservation, normalization/clearing, invalid and
  duplicate-domain rejection, monitoring refresh, tenant isolation, and secret
  masking. Browser inspection completed at phone and desktop widths.

- Confirmed the business boundary with the owner: most purchases close entirely
  in WhatsApp by bank transfer or COD; Shopify is another sales channel. Updated
  AGENTS.md, durable context, product/domain/architecture and integration documents.
- Added **Registrar pedido** to conversations and a native order workspace for
  agreed line items, recipient/delivery snapshots, optional opportunity linkage,
  and totals computed by the application. Native orders have no Shopify ID or URL.
- Added auditable native payment, shipping, delivery, return, cancellation and
  completed-full-refund recording. Payment remains independent of shipment;
  verified full receipt converts only the explicit related opportunity.
- Added submission deduplication, store/relationship validation, row-serialized
  updates, stale-screen rejection, and ordered event revisions.
- Both channels appear in orders, customer context, follow-up and attribution.
  Admin now puts native WhatsApp order/pending-payment counts first and labels
  Shopify integration optional.
- Applied `20260905173634_add_native_whatsapp_orders` locally. Form browser
  inspections passed at 390px and 1440px; populated creation, payment, shipment,
  stale forms and cross-channel reporting are covered by deterministic tests.
- No real sale, payment, carrier booking, Shopify write or outbound message was
  created by this development session. Native inventory synchronization is not
  implemented. Operator authentication remains DEL-009 before production.

- Shopify Admin `orders/paid` sample delivery validated on 2026-09-05 at 23:18:51 UTC: HTTP 200, event processed without error. This is sample data, not a real purchase or live checkout correlation test.

- Committed implementation as `e10425b`, pushed the delivery branch, and opened PR [#5](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/5). Status is In Review; production remains No.
