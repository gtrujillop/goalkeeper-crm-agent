# DEL-002: Conversation core

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | In Progress |
| Branch | `deliverable/DEL-002-conversation-core` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The application can process a customer conversation end to end while preserving
a traceable customer, message, and AI-decision history. Automated scenarios
verify the engine without introducing a temporary simulator UI.

## Scope

- Store profiles as the root context for customers, conversations, policies, and
  provider configuration, with a seeded Colombia default.
- Progressive customer identity beginning with a normalized phone number.
- Conversations, inbound and outbound messages, and lifecycle states.
- Agent-run, prompt-version, tool-call, and cost-estimate traceability.
- A bounded conversation engine behind provider-neutral adapter behaviours.
- Fake WhatsApp, catalogue, and AI adapters for deterministic automated tests.
- Explicit locale, currency, timezone, and phone-region context throughout a
  conversation and agent run.
- End-to-end conversation scenarios that exercise the application from inbound
  message ingestion through persisted outbound response.
- Baseline behavioral evaluations and human-escalation behavior.

## Acceptance criteria

- [x] A seeded Colombia store profile defaults to `es-CO`, COP,
      `America/Bogota`, and phone region `CO`.
- [x] Store-owned records and background work require an explicit store profile.
- [x] An inbound message creates or resolves the customer by normalized phone number.
- [x] Colombian local numbers normalize to E.164 while explicit international
      numbers remain in their declared region.
- [x] Messages remain ordered, directional, and traceable to their source.
- [x] An agent run records its prompt, provider, model, tool calls, result, and estimated cost.
- [x] The engine stops at configured tool and token limits.
- [x] Low-confidence or disallowed requests produce a human-takeover state.
- [x] Duplicate inbound message identifiers are processed only once.
- [x] End-to-end tests cover a normal answer, tool-backed answer, duplicate message,
      provider failure, bounded-loop termination, and human escalation.
- [x] End-to-end cases use Colombian Spanish by default and prove that store,
      locale, currency, and timezone context survives the full flow.
- [x] End-to-end tests assert persisted state and outbound intent, not private
      implementation details.

## Dependencies

- DEL-001.

## Out of scope

- A terminal or LiveView conversation simulator.
- Activating a second market or building store-profile administration screens.
- Real WhatsApp delivery.
- Real Shopify catalogue and cart operations.
- Full manager CRM navigation and opportunity pipeline.

## Delivery notes

The fake adapters are test infrastructure, not a user-facing simulator. They use
the same public application boundaries that real providers will implement in
later deliverables. This lets the tests exercise orchestration and persistence
without network calls, paid API usage, or brittle browser automation.

Implemented a store-scoped relational conversation core with deterministic phone
identity resolution, ordered messages, agent/tool/handoff traceability, bounded
execution, idempotent inbound ingestion, and an Oban ingestion boundary. The
scenario suite covers normal and tool-backed answers, duplicates, provider
failure, tool and token bounds, low confidence, disallowed actions, explicit
international phone numbers, and suppression while a human owns a conversation.

Validation: `mix precommit` passed on 2026-08-29 with 20 tests and 0 failures.
