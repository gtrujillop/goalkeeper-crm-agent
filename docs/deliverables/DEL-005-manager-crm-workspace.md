# DEL-005: Manager CRM workspace

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | In Review |
| Branch | `deliverable/DEL-005-manager-crm` |
| Pull request | [#4](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/4) |
| Production | No |
| Production date | — |

## Outcome

The owner or store manager can quickly understand customer context, handle
exceptions, and advance sales from one mobile-friendly workspace.

## Scope

- Exception-driven inbox and customer search.
- Progressive profile with confirmed facts and identity confidence.
- Unified conversation, activity, and order-summary timeline.
- Opportunity pipeline, notes, and follow-up tasks.
- AI enable/disable, assignment, and takeover actions.
- Concise Shopify order cards linking to Shopify order details.
- Active-store context and locale-aware currency, date, and time presentation.
- Operator administration for store-scoped WhatsApp accounts and essential store settings.

## Acceptance criteria

- [x] A manager can find a customer by phone or known profile information.
- [x] The timeline clearly distinguishes customer, agent, system, and manager activity.
- [x] Conversations needing attention are prioritized with a reason.
- [x] A manager can pause automation and reply without leaving the conversation.
- [x] Shopify order details open in Shopify rather than being reimplemented.
- [x] Primary workflows are usable on a phone-sized viewport.
- [x] An operator can create, edit, activate, and deactivate WABA mappings without using the application console.
- [x] Stored WhatsApp credentials are never rendered back into the administration interface.

## Dependencies

- DEL-002.
- DEL-003 for live product and order links.
- DEL-004 for real message delivery; fake delivery may be used during development.

## Out of scope

- General-purpose CRM customization.
- Shopify inventory or fulfillment administration.

## Delivery notes

Optimize for exceptions and next actions rather than exposing every stored field.

- Added `/crm` with an exception-ranked, searchable conversation inbox and responsive detail workspace.
- Added confirmed customer profile facts, manager assignment, automation controls, direct WhatsApp replies, notes, follow-up tasks, and opportunity stages.
- Added concise order-summary records that link to Shopify Admin; Shopify remains the commerce system of record.
- All records and actions are explicitly scoped to the active store profile, with store-local date/time and currency presentation.
- Automated LiveView coverage exercises search, selection, assignment, takeover, reply, profile confirmation, notes, tasks, opportunities, and external order links.
- Added store-scoped PubSub refreshes after inbound webhook processing and delivery-status changes so open inboxes and timelines update without a browser reload.
- Confirmed the initial operating model: managers reply from this workspace through direct Meta Cloud API; WhatsApp Business App Coexistence is not required.
- Redesigned the inbox around fast WhatsApp handling with explicit AI/human ownership, escalation prompts, clearer conversation states, and a safer reply composer.
- A manual manager reply now atomically pauses AI ownership before delivery, preventing competing automated and human responses.
- Added `/admin` for store-scoped WABA identifiers, account activation, credential readiness, webhook guidance, and operational store settings. Secrets remain environment-managed and masked.
- Latest local validation: `mix precommit` passed on 2026-09-05 with 40 tests and 0 failures.
