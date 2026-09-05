# WhatsApp integration

## Boundary

Use the official WhatsApp Business Platform/Cloud API directly. Do not automate
WhatsApp Web.

The initial production strategy does not use WhatsApp Business App
Coexistence. Once the store number is registered with Cloud API, managers send
manual replies from the Goalkeeper CRM inbox rather than the WhatsApp Business
mobile app. Human takeover changes conversation ownership and suppresses AI; it
does not change the delivery channel, so manager replies still travel through
Cloud API.

Coexistence and third-party BSP inboxes remain possible future alternatives,
but are not dependencies for initial production delivery.

The adapter owns provider-specific authentication, payloads, status mapping,
media retrieval, and error handling. The conversation domain receives normalized
commands and events.

## Inbound processing

1. Verify webhook authenticity.
2. Persist the provider event ID and minimally necessary raw payload.
3. Return a successful response quickly.
4. Deduplicate retries.
5. Normalize messages and delivery events asynchronously.
6. Capture referral and advertising metadata when provided.
7. Resolve the WhatsApp identity to a CRM customer.

## Progressive identity

The first interaction normally provides only the WhatsApp identifier, normalized
phone number, provider-visible profile information, and message content. This is
sufficient to create a valid CRM customer.

Do not request name, email, address, identification, or location simply to
complete a profile. Ask product questions only when they improve assistance, and
request fulfillment information only after the customer selects a purchase path
that requires it.

## Outbound processing

Outbound messages are represented locally before delivery. Workers use an
idempotency key and record provider message IDs and delivery state.

```text
pending -> accepted -> sent -> delivered -> read
                    \-> failed
```

## Ordering and concurrency

Only one agent run may process a conversation at a time. Begin with database
locking and unique Oban jobs. A supervised process per active conversation may
be explored later, while PostgreSQL remains canonical.

## Human handoff

Human ownership is an explicit state transition. A handoff includes a reason,
conversation summary, relevant customer facts, recommended products, and any
unfinished operation. Automatic replies remain disabled until ownership is
released.

## Messaging policy

Before outbound or lifecycle messaging, check consent, opt-out state, applicable
WhatsApp session/template rules, quiet hours, and frequency limits. Store policy
decisions and the template version used.

## Open questions

- Timing and rollback plan for migrating the existing store number from the
  WhatsApp Business app to direct Cloud API
- Media retention duration
- Supported languages for the first production release
