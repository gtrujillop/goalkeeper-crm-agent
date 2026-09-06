# DEL-010: AI WhatsApp sales assistant

| Field | Value |
| --- | --- |
| Created | 2026-09-05 |
| Status | Backlog |
| Branch | `deliverable/DEL-010-ai-whatsapp-sales` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

Customers receive natural, context-aware Spanish WhatsApp assistance grounded in
the live product catalogue and approved store policies, with immediate human
takeover and WhatsApp purchases supported outside Shopify.

## Scope

- Real AI provider and live catalogue wiring with store-specific enablement.
- Bounded conversation memory, confirmed facts and approved policy context.
- Rich product/variant retrieval and validated, traceable tool calls.
- Manager-review mode followed by restricted text auto-replies.
- Structured native order drafts for manager confirmation; optional Shopify carts.
- Durable processing, safe delivery handling, cost limits and quality evaluations.

## Acceptance criteria

- [ ] Designated WhatsApp test conversations use the real model and live catalogue.
- [ ] Multi-turn replies retain size, budget and recommended product references.
- [ ] Product claims and current prices are backed by retrieved store data.
- [ ] Missing facts, unreliable physical stock and provider failures trigger clarification or handoff.
- [ ] Transfer/COD purchases produce reviewable native drafts without requiring Shopify checkout.
- [ ] Human takeover suppresses in-flight automated replies and tools respect store boundaries.
- [ ] Strict tool contracts and business validation reject invalid or unauthorized actions.
- [ ] Network calls do not hold long database transactions; retries preserve processing progress and handle ambiguous sends.
- [ ] Manager review, usage/cost visibility, budgets and store enablement are available.
- [ ] Evaluations cover grounded recommendations, memory, failures, duplicates and takeover races.

## Required context

- [Integration analysis](../ai/shopify-whatsapp-integration.md)
- [Agent design](../ai/agent-design.md)
- [Traceability and evaluations](../ai/traceability-and-evaluations.md)
- [Shopify integration](../integrations/shopify.md)
- [Native WhatsApp orders](../product/whatsapp-orders.md)

## Dependencies

- DEL-002 orchestration foundation; DEL-003 catalogue; DEL-004 WhatsApp transport.
- DEL-005 manager workspace; DEL-006 native orders.
- DEL-009 operator authorization before production; DEL-007 owns production rollout.
- Approved product/policy data and an explicit physical-stock confirmation process.

## Out of scope

- Automatic payment verification, refunds, discounts or inventory synchronization.
- Autonomous confirmation of native orders without manager review.
- Voice/image understanding, fine-tuning and a vector database.

## Delivery notes

Defined following the owner's request for integration analysis after DEL-006
merged. Implementation has not started; provider/model selection and business
policy readiness are tracked in the linked analysis. No live AI was enabled.
