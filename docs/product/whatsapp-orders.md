# Native WhatsApp orders

## Ownership

WhatsApp is the primary sales channel. Most customers agree a purchase in their
conversation and pay by bank transfer or cash on delivery. These sales remain
entirely outside Shopify. The CRM owns their order, payment evidence, delivery
snapshot, and operator history. Shopify is an additional sales channel and owns
its own commerce records.

Native order entry works without Shopify credentials, webhooks, carts or order
IDs. Catalogue lookup may still use Shopify; entering a native sale does not
create a Shopify order or reserve/decrement inventory. Inventory synchronization
and a broader stock ledger are not part of this workflow. The owner confirms
Shopify stock is updated after every sale across channels, with a matching XLSX
inventory document. This existing operational process remains responsible for
stock adjustments; see [inventory source](../integrations/shopify.md#inventory-across-sales-channels).

## Operator flow

1. Open the customer's conversation and choose **Registrar pedido**.
2. Enter the agreed products, variants/sizes, quantities, and unit prices.
3. Confirm recipient, phone, address, city, shipping cost, and optional carrier.
4. Choose **Transferencia bancaria** or **Pago contraentrega** and optionally link
   an existing opportunity belonging to this customer.
5. Register the purchase. The server computes the total in the store's currency;
   item, price and recipient snapshots retain the agreement independently of
   subsequent catalogue or profile changes.
6. Manage the order in its CRM detail view. Shopify purchases continue to link
   to Shopify Admin from the same shared orders screen.

A submission key deduplicates repeated creation in the same form session.
Customer and conversation ownership come from the active store and conversation,
not submitted identifiers. A foreign opportunity cannot be attached.

## Independent lifecycles

| Concern | Native states |
| --- | --- |
| Order | confirmed, cancelled |
| Payment | pending_transfer or collect_on_delivery, paid, refunded |
| Delivery | unfulfilled, shipped, delivered, returned |

Registering a purchase confirms the agreement but does not claim funds arrived.
Shipping requires a tracking reference. Shipping and delivery never imply
payment; a TCC delivery and the later remittance to the store are separate facts.
A manager confirms receipt only after verifying the full amount, supplying an
evidence/reference note. The CRM records that assertion; it does not verify bank
settlement automatically or accept a customer message/image as proof.

Payment receipt marks an explicitly linked opportunity won and includes the
purchase in paid-revenue/customer-total reporting. Order cancellation does not
silently refund money. A completed full refund can be recorded separately after
payment; no funds are moved by the CRM. Partial payments/refunds, automated carrier
booking, and editing a confirmed order's commercial snapshot are not implemented.
An unshipped or returned order can be cancelled; shipped orders must first have
their actual delivery/return outcome recorded.

Each change stores the actor label, evidence, before/after states, and an ordered
revision in the same transaction. A stale operator screen cannot overwrite a
newer revision. The current development UI uses the existing `Manager` label;
DEL-009 must supply authenticated operator identity and protect all native-order
routes before production. The stored actor label is not yet verified identity.

## Shared reporting and follow-up

Both channels appear in `/crm/orders`, in the customer's conversation, and in
first-/last-touch attribution. Native sales have an explicit conversation link;
unknown acquisition remains unknown. Only paid orders contribute to paid revenue;
confirmed but unpaid COD orders appear in operational counts. Gross paid revenue
and separately recorded refunds retain the existing reporting convention.

Admin presents WhatsApp order totals, pending transfers and COD collections above
the optional Shopify setup. An internal delivery follow-up task can be created
from the order; creation does not send a WhatsApp message or modify AI ownership.
