# DEL-004: WhatsApp messaging

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Done |
| Branch | `main` |
| Pull request | [#3](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/3) |
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

- [x] Duplicate webhook deliveries never create duplicate customer messages.
- [x] Accepted inbound events are persisted before asynchronous processing.
- [x] Messages within one conversation are processed in order.
- [x] Outbound status transitions are visible and auditable.
- [x] Human takeover prevents further automated replies immediately.
- [x] Invalid signatures and unsupported payloads are rejected safely.

## Dependencies

- DEL-002.

## Out of scope

- Broad production rollout.
- Marketing broadcasts and retention campaigns.

## Delivery notes

The direct Meta Cloud API remains the preferred low-cost starting integration,
subject to account and operational validation.

Implemented on `deliverable/DEL-004-whatsapp-messaging` with store-scoped account
mapping, raw signed webhook persistence, idempotent Oban processing, PostgreSQL
advisory-lock serialization per customer, Cloud API text and locale-template
delivery, delivery-event audit records, transient retries, and an atomic manager
takeover operation. The agent rechecks ownership immediately before emitting a
reply to close the in-flight takeover race.

Merged to `main` in pull request [#3](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/3)
as merge commit `bb35d8e` on 2026-08-29. Production remains `No`; only Meta's
Cloud API test number was used for live validation.

Local validation on 2026-08-29: `mix precommit` passed with 33 tests and 0
failures. Live Meta test-number validation succeeded on 2026-08-29 using the
Cloud API test number: a signed inbound text was persisted and processed, the
agent response was sent, and `sent`, `delivered`, and `read` transitions were
persisted. The live store number remains on the WhatsApp Business app and is
preserved as an inactive CRM mapping.
