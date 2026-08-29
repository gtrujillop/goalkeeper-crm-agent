# AI agent design

## Role

The agent is a bounded sales assistant. It identifies customer needs, retrieves
verified information through application tools, explains a small number of good
choices, helps create a cart, and requests human help when necessary.

It is not the source of truth for CRM state, price, inventory, orders, payment,
consent, or authorization.

## Provider boundary

Define an application behaviour with normalized request and response types:

```text
StoreCRM.AI.Provider
├── StoreCRM.AI.OpenAI
└── StoreCRM.AI.Fake
```

Additional providers can be introduced only when evaluation evidence supports
the work.

## Initial tools

```text
search_products(requirements)
get_product(product_id)
create_cart(variant_id, quantity)
request_human_handoff(reason, summary)
```

Tool arguments use strict schemas. Tools have timeouts, authorization policies,
idempotency where applicable, and compact outputs.

## Agent loop

1. Assemble instructions, recent messages, conversation summary, confirmed
   customer facts, and applicable policies.
2. Ask the model for a response or tool call.
3. Validate each tool request.
4. Authorize and execute allowed tools.
5. Return tool results to the model.
6. Stop after a configured iteration limit.
7. Persist the final outbound intent before delivery.

## Context strategy

PostgreSQL is the canonical conversation history. The prompt receives only what
is useful for the current turn:

- Stable behavioral instructions
- Versioned business policies
- A compact older-conversation summary
- Recent messages
- Confirmed customer preferences
- Current opportunity state

Provider conversation state may improve convenience but cannot be the only copy.

## Handoff conditions

- Customer requests a person
- Low confidence or contradictory catalogue information
- Complaint, damage, return, or refund
- Identity or order cannot be verified
- Exceptional discount or large team purchase
- Tool failure prevents a grounded answer
- Repeated misunderstanding
- Tool iteration limit reached

## Deferred techniques

Do not begin with multi-agent orchestration, fine-tuning, a vector database, or a
general autonomous planning framework. Add them only for a demonstrated use case.
