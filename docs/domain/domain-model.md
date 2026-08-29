# Domain model

## Aggregate overview

```text
Store profile
└── Customer
    ├── Identities
    ├── Facts
    ├── Consents
    ├── Conversations
    │   ├── Messages
    │   ├── Agent runs
    │   └── Handoffs
    ├── Touchpoints
    ├── Opportunities
    ├── Commerce sessions
    └── Orders
        ├── Order items
        ├── Payments
        └── Shipments
```

## Store profile

`store_profiles` is the root business context. It owns market, enabled locales,
default currency, business timezone, phone parsing region, policy versions, and
references to provider configurations. The initial profile is Colombia; another
operation such as Spain is a separate profile using the same application.

All customer, conversation, commerce, prompt, policy, and integration records
carry a store-profile identifier. Uniqueness constraints and queries are scoped
accordingly so records cannot leak between stores.

## Customer and identity

`customers` represents a person known to the store. Provider identifiers belong
in `customer_identities` so a person can be connected to WhatsApp, Shopify, and
email without using any of those values as the primary key.

Important fields include lifecycle stage, preferred language when known, first
and last interaction, order count, last purchase date, and lifetime value.

Customer language and country may differ from the store defaults. Phone numbers
use E.164 normalization; the active profile's region is used only to interpret a
local-format number without an explicit international prefix.

A customer is valid with only a WhatsApp identity or only a Shopify identity.
Early WhatsApp records typically contain a normalized phone number, provider
identifier, optional provider display information, and messages. Name, email,
location, and acquisition source may remain unknown.

Personal and fulfillment information is collected progressively only when a
transaction requires it. Product preferences learned during assistance are not
treated as formal identity information.

Identity resolution must be deterministic where possible. Probabilistic matches
should be proposed for human review rather than silently merged.

Strong evidence includes a matching normalized phone number, verified email, or
signed commerce-session token. Similar names alone are insufficient. Merges must
be auditable and reversible.

## Customer facts

Structured facts capture useful long-term knowledge:

```text
glove_size
preferred_cut
playing_surface
training_frequency
budget_range
preferred_language
```

Every fact records:

- Value
- Source
- Confidence
- Evidence message or order
- Confirmation status
- Validity dates

AI-inferred facts begin as `proposed`. Direct customer statements and purchase
records can be `confirmed` according to explicit application rules.

## Conversations and messages

A customer can have many conversations. Messages preserve provider IDs,
direction, content type, normalized content, raw content reference, delivery
status, and timestamps.

Conversation state:

```text
active
waiting_for_customer
waiting_for_human
human_owned
closed
```

The AI must not reply while a conversation is human-owned.

## Opportunity lifecycle

```text
new_lead
  -> qualified
  -> products_recommended
  -> cart_created
  -> checkout_started
  -> won
```

Alternative terminal or paused states include `lost`, `not_ready`, and
`human_follow_up`.

Paid-order events determine `won`; the language model does not.

## Commerce

`commerce_sessions` correlate a customer, conversation, opportunity, Shopify
cart, checkout URL, and optional campaign touchpoint. Orders and line items retain
snapshots of titles, variants, quantities, and prices so historical records do
not change with the catalogue.

Opportunity, order, payment, and shipment lifecycles remain separate. For
example, a cash-on-delivery order may be confirmed and shipped while payment is
still `collect_on_delivery`.

The CRM stores concise Shopify order references and snapshots for relationships
and reporting. Shopify remains authoritative, and the CRM stores an Admin URL so
the operator can open full order details there.

## Activity timeline

Use normal relational tables for current state plus an append-only
`conversation_events` or `activity_events` table for traceability. Events store
actor, event type, correlation ID, causation ID, payload, occurrence time, and
ingestion time.

This is an audit timeline, not a commitment to full event sourcing.
