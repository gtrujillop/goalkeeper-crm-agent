# Shopify-backed WhatsApp sales assistant

Analysis of merged main `eb9c838`, 2026-09-05. This is a proposed design;
the live AI adapter and the capabilities below are not implemented.
Implementation scope: [DEL-010](../deliverables/DEL-010-ai-whatsapp-sales-assistant.md).

## Desired customer experience

The assistant should hold a natural Spanish conversation, remember the customer's
size, budget and playing surface, ask only for missing information, and recommend
a small number of relevant products with explanations grounded in actual product
data. It should identify itself honestly as the store's virtual assistant and
transfer to a person when requested or when the available facts are insufficient.

For example, a customer says “Busco guantes talla 9 para sintética.” The assistant
remembers talla 9, asks about budget if needed, searches the catalogue, and explains
the differences between available matching models. Follow-up questions such as
“¿Y el segundo sirve para entrenar?” retain the identities of the recommendations.
Prices, sizes and performance claims must come from retrieved data; no example
product or price is a substitute for an actual lookup.

WhatsApp remains the primary sales channel. The assistant can explain approved
bank-transfer/COD options and prepare the purchase for a manager in the CRM.
Shopify checkout is optional, offered when appropriate to the customer's choice.
See [native WhatsApp orders](../product/whatsapp-orders.md).

## What is already built and what is missing

| Area | Observed implementation | Required change |
| --- | --- | --- |
| WhatsApp transport | Signed webhooks, durable events, workers and outbound Meta adapter | Connect the real AI and catalogue adapters to this path |
| AI provider | `Agent.Engine` defaults to `AI.FakeProvider`; incoming WhatsApp processing only supplies a messaging adapter | Add a real provider, runtime configuration, store enablement and explicit failure behavior |
| Memory | Engine sends only the latest inbound message | Load bounded recent history, confirmed facts and a summary with provenance |
| Catalogue | Live Storefront adapter exists; engine defaults to `Catalogue.Fake` | Wire the live adapter and extend retrieval |
| Product knowledge | Search returns titles, variants, availability, quantity, prices and links; capped at 10 products / 25 variants | Retrieve descriptions, options and relevant attributes; fetch a specific product/variant and handle pagination |
| Tool protocol | Generic object schemas; tool output uses `inspect`; no provider call IDs | Strict parameter schemas, domain validation, structured results and proper call/output correlation |
| Sales | Native order entry exists for managers; agent tools only search/create Shopify carts | Initially hand off with a structured native order draft; keep payment verification with staff |
| Runtime | WhatsApp worker holds a database transaction/advisory lock through processing | Move network calls outside long transactions while preserving durable per-conversation ordering |
| Limits | Tool/token limits exist; usage and estimated cost are simplistic | Bound output and time before requests, record actual usage and model-based cost, enforce store budgets |

Source files: `lib/store_crm/agent/engine.ex`, `lib/store_crm/ai/provider.ex`,
`lib/store_crm/ai/fake_provider.ex`, `lib/store_crm/catalogue/shopify.ex`,
`lib/store_crm/messaging.ex`, `lib/store_crm/messaging/process_webhook_worker.ex`,
`lib/store_crm/messaging/whatsapp.ex`, and `compose.yaml`.
Compose currently does not forward an OpenAI API key. Merely setting one in `.env`
would not implement or activate the integration.

## Proposed request flow

1. Verify and persist the WhatsApp event, deduplicate it, and enqueue processing.
2. Resolve the store/customer/conversation and check automation ownership.
3. Build context from recent customer and manager messages, confirmed customer
   facts, relevant order/opportunity state, and versioned store policies. Exclude
   unrelated customers, secrets, unnecessary personal data and private operator
   notes. Preserve product/variant references from earlier recommendations.
4. Ask the model to respond or request a permitted tool. Recommended first adapter:
   OpenAI Responses API via the existing Req client. Function calling lets the
   application execute tools and return correlated outputs; strict schemas improve
   argument conformance, while application code still checks authorization and
   business validity. See [OpenAI function calling](https://developers.openai.com/api/docs/guides/function-calling).
5. Execute store-scoped `search_products`, `get_product`, policy lookup and
   explicit human-handoff tools. Convert validated search filters to Shopify
   queries in application code. Preserve provider call IDs and required response
   items across bounded tool rounds. Treat product descriptions and customer text
   as data, never as instructions that override policy.
6. Generate a brief, grounded Spanish answer. Recheck pause/ownership and the
   conversation revision immediately before delivery; suppress stale replies if
   a manager intervened or newer customer messages invalidate the answer.
7. Persist the response, delivery outcome, prompt/model version, consulted product
   IDs, tool results, usage and latency. Resume failed processing independently
   of inbound-message deduplication. Handle ambiguous outbound network failures
   explicitly: blindly retrying a send can duplicate a customer message.

Choose the model through Spanish sales evaluations measuring answer quality,
latency and cost; keep it configurable. An initial implementation needs neither
fine-tuning nor a vector database. Retrieve current commercial facts on demand.
If catalogue size later justifies semantic search, revalidate selected variants
and prices against the live source before making an offer.

## Selected providers and sustainable operation

The owner selected OpenAI GPT-5.6 Luna (`gpt-5.6-luna`) and Google Gemini
3.1 Flash-Lite (`gemini-3.1-flash-lite`) as the first two evaluation candidates.
Neither is yet the production winner. Verify exact API availability, tool contracts
and current prices during implementation; do not silently substitute another model.
Use Req adapters behind the existing provider boundary with normalized usage and
provider-specific tool-call handling. Retain deterministic fakes for ordinary tests.
Claude, DeepSeek and other providers are deferred. Local/open-weight hosting is a
future alternative; the owner has no hosting hardware. Business knowledge comes
from retrieval, policies and memory, not initial fine-tuning.

Use one bounded assistant, compact recent history and summaries, a few relevant
catalogue results, short outputs and bounded tool rounds/retries. Group bursts of
customer messages. Duplicate webhooks, delivery receipts and bookkeeping must not
invoke a model. Cache stable policy/product descriptions with explicit freshness;
recheck selected prices and inventory. Account for summary generation, evaluations,
retries and any fallback calls in the same spending ledger.

Before each paid request, atomically reserve a conservative maximum request cost
against store daily/monthly and per-conversation budgets, including concurrent runs.
Bound input and all billable output/reasoning; retain the price/version used for
accounting. Reconcile provider usage on completion. Unknown usage after a timeout
must retain a conservative charge/reservation until resolved; retries need their
own allowance. Unknown pricing or absent budget configuration must not permit
unbounded paid calls. Exhaustion stops AI and routes to human handling with an
operator notification. Fallbacks are explicit and share the same budget; never
silently upgrade to a more expensive model.

The owner has not supplied a numerical monthly budget or paid evaluation cap.
Implementation and fake-adapter tests can proceed; obtain those values before
paid evaluation/automatic traffic. Do not treat the earlier illustrative token
cost comparison as measured usage or an approved spending allowance.

## Admin AI configuration and usage

Provide a dedicated, store-scoped Admin section with:

- Enable/pause AI, provider/model selection from the supported allowlist, and
  manager-review versus automatic-reply mode. Save versioned sales instructions
  and policy references; editable instructions cannot override application rules.
- Daily/monthly and per-conversation spending limits, warning thresholds and
  remaining budget including outstanding reservations.
- Environment-managed credential readiness without showing or editing API keys.
- Date/model filters; input, cached input, output and billable reasoning usage
  where reported; request/conversation counts, estimated spend, average cost per
  conversation, latency, failures and handoffs. Avoid double-counting reasoning
  tokens included in provider output totals.
- Conversation/run drill-down showing model, tools, usage and escalation reason.
  Separate calculated API cost from the provider invoice; expose missing usage.

Test store isolation, concurrent budget reservations, exhausted budgets, uncertain
usage, failed calls, pricing changes and takeover during generation. DEL-009 owns
real operator authentication/authorization before production.

## Provider comparison plan

Run the two candidates against the same versioned Spanish sales scenarios,
catalogue fixtures, policies and bounded context. Start with deterministic adapter
contract tests and a replay runner, then a capped paid comparison targeting 50–100
reviewed scenarios. Use anonymized historical examples when available and clearly
label synthetic fixtures. Cover size/budget changes, prior recommendations, COD,
transfers, inventory changes, unavailable facts and handoff.

Record per-scenario total cost across all calls, latency, tool correctness,
groundedness, memory, tone and manager corrections. Invented commercial facts,
unauthorized payment confirmation and cross-customer leakage fail the evaluation.
Choose the primary model by cost per successfully handled conversation, not token
price alone; record results and any explicitly configured fallback. No comparative
quality results or live provider validation exist yet.

## Catalogue and policy readiness

Product descriptions alone may not support informed goalkeeper advice. Audit
the published catalogue for sizes, surface suitability, cut, palm/latex, intended
use and durability guidance. Store missing facts as approved structured catalogue
attributes or curated store knowledge. Never infer a technical guarantee from a
product name. Retrieve only relevant products; do not send the whole catalogue
with every message. Handle unpublished items, missing variants, null inventory,
rate limits, timeouts and partial GraphQL errors as explicit unavailable data.

Store policy context needs approved delivery coverage/fees/times, COD conditions,
bank-transfer instructions, returns/warranty and discount authority. Collect only
necessary order details. Customer claims and uploaded payment receipts must not
automatically mark an order paid. Audio and image understanding are later scope;
the first pilot covers text with a clear handoff for unsupported media.

**Confirmed inventory source (owner, 2026-09-05):** Shopify inventory is updated
after every sale, including WhatsApp and direct sales. The owner also maintains a
matching XLSX inventory document. Use Shopify for live AI availability answers;
the spreadsheet can support reconciliation without an initial runtime import.
The cross-channel stock question is resolved. Native CRM order creation itself
still performs no stock adjustment; preserve the existing update process to avoid
double-decrementing inventory. Recheck the selected variant before confirmation;
a lookup is not a reservation. Escalate missing inventory or reported discrepancies.
See [inventory responsibilities](../integrations/shopify.md#inventory-across-sales-channels).

## Delivery stages and evidence

1. Real adapter and live retrieval, with memory, policy context, grounding and
   explicit handoff. Verify using local fixtures and designated test conversations.
2. Manager-review mode: draft replies and native order summaries, inspect grounding
   and correct memory errors before enabling automatic sends.
3. Restricted text auto-replies for opted-in pilot traffic. Existing takeover must
   suppress in-flight responses. Native purchases remain manager-confirmed;
   automated payment, refunds and stock writes are outside this scope.
4. Production rollout through DEL-007 after DEL-009 route/operator protection and
   documented quality, spend and latency gates.

Evaluate multi-turn size/budget changes, reference to a previous recommendation,
unavailable stock, missing attributes, changed prices, Shopify/model failures,
cross-store isolation, instruction injection, human takeover during generation,
burst messages, duplicate webhooks and send retry ambiguity. Assess Spanish tone
and recommendation relevance with a reviewed conversation set. A model's own
confidence number is not adequate evidence of factual correctness. Verify the
applicable WhatsApp messaging-window/template rules before enabling live sends.

## Related design

- [Agent design](agent-design.md)
- [Traceability and evaluations](traceability-and-evaluations.md)
- [Shopify integration](../integrations/shopify.md)
