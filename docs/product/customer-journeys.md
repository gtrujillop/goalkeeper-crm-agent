# Customer journeys

## Acquisition is optional evidence

A customer may discover the store through an Instagram advertisement, organic
Instagram content, Google advertising, organic search, a referral, a direct
visit, or an unknown source. The CRM must never require or invent attribution.

Keep three concepts distinct:

```text
acquisition source: how the person first discovered the store, when known
conversation entry point: how a particular conversation began
order channel: where a particular purchase was completed
```

## Assisted WhatsApp journey

```text
Known or unknown source
        |
        v
WhatsApp conversation
        |
        v
Product and size assistance
        |
        v
Purchase intent
        |
        +-- Bank transfer
        +-- Shopify checkout with Mercado Pago
        +-- Cash on delivery through TCC
        |
        v
Fulfillment and shipment
        |
        v
Post-delivery WhatsApp follow-up
```

Early conversation data is deliberately minimal. The system initially receives
the WhatsApp identifier, phone number, display information made available by the
provider, and message content. Product-discovery questions may capture size,
surface, training or match use, and budget because they improve assistance. Do
not request formal identity, email, or address until required for a transaction.

### Bank transfer

```text
awaiting_payment
-> proof_received
-> manually_verified
-> paid
```

Initially, a human verifies proof of payment. The model must never infer that an
image proves settlement. After verification, represent the sale in Shopify when
that is the chosen operational process so inventory and commerce reporting remain
consistent.

### Shopify and Mercado Pago

The agent creates a Shopify cart for the selected variant and sends its checkout
URL. Shopify and the configured gateway determine payment outcome.

```text
recommendation
-> Shopify cart
-> checkout
-> Shopify reports paid order
-> CRM marks opportunity won
```

Use opaque correlation tokens to relate the cart and resulting order to the CRM
customer, conversation, opportunity, and reliable touchpoint.

### Cash on delivery through TCC

Only after the customer commits to purchase, collect the fulfillment information
required by the logistics process. Require explicit confirmation of product,
variant, total, payment method, recipient, and delivery destination.

```text
pending_customer_confirmation
-> confirmed
-> ready_for_fulfillment
-> shipped
-> delivered
-> payment_collected
```

Delivery and payment collection are separate facts. A delivery may fail, be
rescheduled, or return to the store.

## Direct Shopify journey

Some customers purchase without a WhatsApp conversation:

```text
Known or unknown source
-> Shopify storefront
-> Mercado Pago checkout
-> Shopify paid-order event
-> create or resolve CRM customer
-> add order summary to relationship timeline
-> fulfillment through the existing process
-> post-delivery WhatsApp follow-up when eligible
```

The first known CRM activity may be a paid order. This is a valid relationship
record and does not require a synthetic lead conversation.

## Post-delivery relationship

When reliable delivery information indicates completion, schedule a follow-up.
Before sending, enforce WhatsApp eligibility, consent, opt-out, quiet-hour, and
frequency policies.

Possible outcomes:

```text
satisfied
size_issue
product_issue
delivery_issue
no_response
```

Issues create a human task. Positive feedback updates the customer timeline and
may support a future, appropriately timed relationship workflow.

## Assisted-sale classification

An order is assisted only when a specific conversation materially contributed to
the purchase, preferably through a correlated commerce session. A historical,
unrelated conversation is insufficient.

```text
assisted_sale: true | false
order_channel: shopify | bank_transfer | cash_on_delivery
acquisition_source: known source | unknown
```
