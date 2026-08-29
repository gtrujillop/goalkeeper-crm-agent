# DEL-002: Conversation core and simulator

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Selected |
| Branch | `deliverable/DEL-002-conversation-core` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The store team can simulate a complete customer conversation locally while the
system preserves a traceable customer, message, and AI-decision history.

## Scope

- Progressive customer identity beginning with a normalized phone number.
- Conversations, inbound and outbound messages, and lifecycle states.
- Agent-run, prompt-version, tool-call, and cost-estimate traceability.
- A bounded agent loop using fake catalogue, WhatsApp, and AI adapters.
- A simple LiveView conversation simulator.
- Baseline behavioral evaluations and human-escalation behavior.

## Acceptance criteria

- [ ] A simulated inbound message creates or resolves the customer by phone.
- [ ] Messages remain ordered, directional, and traceable to their source.
- [ ] An agent run records its prompt, provider, model, tool calls, result, and estimated cost.
- [ ] The loop stops at configured tool and token limits.
- [ ] Low-confidence or disallowed requests produce a human-takeover state.
- [ ] Reloading the simulator preserves the conversation timeline.
- [ ] Automated tests cover deduplication, identity resolution, limits, and escalation.

## Dependencies

- DEL-001.

## Out of scope

- Real WhatsApp delivery.
- Real Shopify catalogue and cart operations.
- Full manager CRM navigation and opportunity pipeline.

## Delivery notes

This is the next implementation slice and supplies the domain primitives used by
the external integrations and manager workspace.
