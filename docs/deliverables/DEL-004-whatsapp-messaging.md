# DEL-004: WhatsApp messaging

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-004-whatsapp-messaging` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

Customers can exchange reliable, traceable WhatsApp messages with the agent, and
a store manager can immediately take control of any conversation.

## Scope

- WhatsApp Cloud API webhook verification and signature validation.
- Inbound event normalization and idempotent processing.
- Per-conversation job serialization.
- Outbound messages, templates, delivery statuses, and retry policy.
- Explicit automation pause and human takeover.
- WhatsApp sandbox or test-number operation.
- Store-scoped WhatsApp account mapping and locale-specific templates.

## Acceptance criteria

- [ ] Duplicate webhook deliveries never create duplicate customer messages.
- [ ] Accepted inbound events are persisted before asynchronous processing.
- [ ] Messages within one conversation are processed in order.
- [ ] Outbound status transitions are visible and auditable.
- [ ] Human takeover prevents further automated replies immediately.
- [ ] Invalid signatures and unsupported payloads are rejected safely.

## Dependencies

- DEL-002.

## Out of scope

- Broad production rollout.
- Marketing broadcasts and retention campaigns.

## Delivery notes

The direct Meta Cloud API remains the preferred low-cost starting integration,
subject to account and operational validation.
