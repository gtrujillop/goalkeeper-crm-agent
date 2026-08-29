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

- Progressive customer identity beginning with a normalized phone number.
- Conversations, inbound and outbound messages, and lifecycle states.
- Agent-run, prompt-version, tool-call, and cost-estimate traceability.
- A bounded conversation engine behind provider-neutral adapter behaviours.
- Fake WhatsApp, catalogue, and AI adapters for deterministic automated tests.
- End-to-end conversation scenarios that exercise the application from inbound
  message ingestion through persisted outbound response.
- Baseline behavioral evaluations and human-escalation behavior.

## Acceptance criteria

- [ ] An inbound message creates or resolves the customer by normalized phone number.
- [ ] Messages remain ordered, directional, and traceable to their source.
- [ ] An agent run records its prompt, provider, model, tool calls, result, and estimated cost.
- [ ] The engine stops at configured tool and token limits.
- [ ] Low-confidence or disallowed requests produce a human-takeover state.
- [ ] Duplicate inbound message identifiers are processed only once.
- [ ] End-to-end tests cover a normal answer, tool-backed answer, duplicate message,
      provider failure, bounded-loop termination, and human escalation.
- [ ] End-to-end tests assert persisted state and outbound intent, not private
      implementation details.

## Dependencies

- DEL-001.

## Out of scope

- A terminal or LiveView conversation simulator.
- Real WhatsApp delivery.
- Real Shopify catalogue and cart operations.
- Full manager CRM navigation and opportunity pipeline.

## Delivery notes

The fake adapters are test infrastructure, not a user-facing simulator. They use
the same public application boundaries that real providers will implement in
later deliverables. This lets the tests exercise orchestration and persistence
without network calls, paid API usage, or brittle browser automation.
