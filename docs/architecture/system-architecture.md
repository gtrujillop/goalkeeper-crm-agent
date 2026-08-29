# System architecture

## Architectural style

Begin as a Phoenix modular monolith with PostgreSQL. Modules communicate through
explicit commands and events while sharing one deployment and database.

```text
Instagram / Google Ads
          |
          v
Attribution capture ------+
                           |
WhatsApp webhook           |
          |                |
          v                v
Message ingestion --> Customer identity
          |                |
          v                v
Conversation worker --> CRM timeline
          |
          v
Agent orchestrator ----> Application tools
          |                  |       |
          |               Shopify  CRM policies
          v
WhatsApp outbound

Shopify webhooks --> Orders --> Opportunities --> Retention workflows
```

## Proposed application boundaries

```text
StoreCRM.Customers
StoreCRM.Conversations
StoreCRM.Catalogue
StoreCRM.Commerce
StoreCRM.Opportunities
StoreCRM.Attribution
StoreCRM.Consent
StoreCRM.Automations
StoreCRM.Agent
StoreCRM.Integrations.WhatsApp
StoreCRM.Integrations.Shopify
StoreCRM.Integrations.OpenAI
```

Each context owns its schemas and exposes a small public API. Integrations must
not write domain tables directly.

## Request and event flow

1. Verify and persist an inbound webhook before processing it.
2. Deduplicate using the provider event or message identifier.
3. Acknowledge the provider quickly.
4. Enqueue normalized processing in Oban.
5. Resolve the customer identity and active conversation.
6. Serialize work per conversation to avoid racing replies.
7. Build agent context from recent messages, confirmed customer facts, and
   applicable business policies.
8. Execute the bounded model/tool loop.
9. Persist the agent run and outbound intent.
10. Send the message through an idempotent outbound worker.
11. Append observable outcomes to the customer timeline.

## Data consistency

- PostgreSQL is canonical for CRM and conversation state.
- Provider payloads are retained for diagnosis, subject to retention policy.
- Business changes and outbox events are written in one transaction.
- Consumers are idempotent and safe to retry.
- External API calls are never placed inside a long database transaction.

## Transactional outbox

Domain operations insert an outbox record in the same transaction as the state
change. Oban delivers it to internal handlers.

Example events:

```text
conversation.started
message.received
agent.recommendation_created
cart.created
order.paid
handoff.requested
customer.opted_out
```

This provides event-driven behavior without operating Kafka at the initial
scale.

## Deployment topology

Initially:

```text
Phoenix web + workers
PostgreSQL
```

Web and job execution may run in one instance at very low traffic. They can be
split into separate process types without changing application boundaries.

## Evolution rules

Extract a service only when there is evidence of an independent scaling,
security, deployment, or ownership requirement. High event volume alone should
first be addressed by workers, partitioning, and backpressure.
