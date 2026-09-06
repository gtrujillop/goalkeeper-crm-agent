# DEL-010: AI WhatsApp sales assistant

| Field | Value |
| --- | --- |
| Created | 2026-09-05 |
| Status | Selected |
| Branch | `deliverable/DEL-010-ai-whatsapp-sales` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

Customers receive natural, context-aware Spanish WhatsApp assistance grounded in
the live product catalogue and approved store policies, with immediate human
takeover and WhatsApp purchases supported outside Shopify.

## Scope

- OpenAI GPT-5.6 Luna and Gemini 3.1 Flash-Lite adapters and comparative evaluation.
- Live catalogue wiring with store-specific enablement.
- Dedicated Admin AI configuration, model usage statistics and enforced budgets.
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
- [ ] Both selected provider adapters pass contract tests and a capped comparison records quality, latency and total cost per conversation.
- [ ] Admin configures store AI mode, approved provider/model, versioned sales instructions and budget thresholds without exposing secrets.
- [ ] Admin reports usage/spend by model and date, remaining budget, latency/failures and conversation/run details; estimates are distinguished from invoices.
- [ ] Concurrent requests reserve cost before calling providers; daily/monthly/conversation limits include retries, summaries and fallbacks.
- [ ] Exhausted/unconfigured budgets, unknown prices and uncertain usage cannot cause unbounded spend; operators see why AI stops.
- [ ] Compact context, bounded outputs/tools and burst grouping limit usage; non-conversational events do not invoke AI.
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
- Approved product/policy data. Shopify is the confirmed cross-channel inventory
  source; retain the existing operational stock-update process.

## Out of scope

- Automatic payment verification, refunds, discounts or inventory synchronization.
- Autonomous confirmation of native orders without manager review.
- Voice/image understanding, fine-tuning and a vector database.
- Local model hosting and providers beyond the selected OpenAI/Gemini pair.

## Delivery notes

Defined following the owner's request for integration analysis after DEL-006
merged. The owner selected this deliverable for the next session with OpenAI
GPT-5.6 Luna and Gemini 3.1 Flash-Lite. Implementation has not started. The linked
analysis records Admin scope, sustainability requirements and evaluation plan.
Numerical budgets and API credential readiness remain to be established before
paid calls. No live AI was enabled.

Owner confirmed Shopify stock is updated after all sales, with a matching XLSX
inventory document. Live AI stock reads use Shopify; spreadsheet ingestion and
automated inventory writes remain outside this scope.
