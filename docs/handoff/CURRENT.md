# Current session handoff

| Field | Value |
| --- | --- |
| Updated | 2026-09-05 |
| Active deliverable | [DEL-010: AI WhatsApp sales assistant](../deliverables/DEL-010-ai-whatsapp-sales-assistant.md) |
| Status | Selected; implementation not started |
| Current branch | `main` |
| Implementation branch to create | `deliverable/DEL-010-ai-whatsapp-sales` |
| Pull request | — |
| Production | No |

## Completed

- DEL-006 merged in PR #5 as `eb9c838`; AI analysis recorded in `2a27635`.
- Inventory clarification recorded in `6046431`.
- Owner selected DEL-010 for the next session, beginning with OpenAI GPT-5.6 Luna
  and Gemini 3.1 Flash-Lite. Updated deliverable, board and durable AI design with
  Admin configuration/usage reporting, spending controls and comparison scope.
- No real AI adapter, paid comparison or automatic AI traffic has been enabled.

## Required context

- Read [DEL-010](../deliverables/DEL-010-ai-whatsapp-sales-assistant.md) completely
  and its Required context links, especially the integration analysis sections on
  selected providers, sustainable operation, Admin and the comparison plan.

## Next session: concrete actions

1. Start from updated main; create `deliverable/DEL-010-ai-whatsapp-sales` and mark
   DEL-010 In Progress in the deliverable and board.
2. Inspect existing Engine, provider behaviour, Shopify adapter and webhook worker.
   Build the common usage/budget ledger and provider contracts with deterministic
   tests before real calls. Preserve immediate takeover and durable processing.
3. Implement both selected Req adapters and runtime wiring, bounded memory/tools,
   rich catalogue retrieval, and the dedicated Admin AI section. Verify current
   model IDs, API contracts and rates against official provider documentation.
4. Build the shared Spanish replay/evaluation set and runner. Obtain numerical
   evaluation/operating budgets and verify credentials before paid calls; these
   missing values do not block implementation or fake-adapter tests.
5. Run the capped comparison, record evidence, choose a primary model, and proceed
   through manager review before restricted automatic replies. No winner assumed.

## Validation

- `docker compose exec -e MIX_ENV=test app mix precommit`: 65 tests, 0 failures for this documentation update.
- Prior baseline: 65 tests, 0 failures. No provider quality/cost benchmark run.
- Shopify signed Admin sample previously processed successfully; real checkout
  correlation remains untested and is separate from native WhatsApp sales.

## External requirements

- Approved sales/delivery policies and sufficiently detailed product data.
- Numerical budgets, provider API access and credentials are not yet verified.
- DEL-009 operator access before production; DEL-007 owns production rollout.
