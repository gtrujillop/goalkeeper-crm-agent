# Goalkeeper CRM Agent

An AI-assisted conversational commerce and customer relationship platform for a
small Shopify store selling goalkeeper gloves and other wearables.

The product will connect WhatsApp, Shopify, advertising attribution, a CRM, and
AI-assisted sales conversations. It is deliberately designed as an economical
modular monolith that can grow without beginning as a distributed system.

## Intended outcomes

- Answer routine WhatsApp questions quickly and accurately.
- Recommend products using live Shopify catalogue and inventory data.
- Preserve a traceable history for every customer and interaction.
- Connect advertising touchpoints, conversations, carts, and purchases.
- Support human takeover whenever automation is uncertain or inappropriate.
- Help build long-term customer relationships and repeat purchases.
- Provide a substantial learning project in Elixir, OTP, event-driven design,
  AI tool use, evaluations, and production integrations.

## Proposed technology

- Elixir and Phoenix
- Phoenix LiveView for the internal CRM interface
- Ecto and PostgreSQL
- Oban for durable background jobs
- A transactional outbox for internal domain events
- Direct adapters for WhatsApp Cloud API, Shopify, and AI providers
- OpenTelemetry-compatible instrumentation

The current architectural recommendation is recorded in
[ADR-0001](docs/decisions/0001-modular-monolith-with-phoenix.md).

## Documentation map

- [Current AI session handoff](docs/handoff/CURRENT.md)
- [Durable project context](docs/handoff/PROJECT-CONTEXT.md)
- [Delivery board](docs/deliverables/README.md)
- [Product vision and scope](docs/product/vision-and-scope.md)
- [Markets and store profiles](docs/product/markets-and-store-profiles.md)
- [Customer journeys](docs/product/customer-journeys.md)
- [Operator experience and cost guardrails](docs/product/operator-experience-and-cost.md)
- [System architecture](docs/architecture/system-architecture.md)
- [Domain model](docs/domain/domain-model.md)
- [WhatsApp integration](docs/integrations/whatsapp.md)
- [Shopify and purchase attribution](docs/integrations/shopify.md)
- [Advertising attribution](docs/integrations/advertising-attribution.md)
- [AI agent design](docs/ai/agent-design.md)
- [AI traceability and evaluations](docs/ai/traceability-and-evaluations.md)
- [Security, privacy, and consent](docs/operations/security-privacy-consent.md)
- [Operations and cost controls](docs/operations/operations-and-costs.md)
- [Deployment and cloud practices](docs/operations/deployment-and-cloud-practices.md)
- [Delivery roadmap](docs/roadmap/delivery-plan.md)
- [Architecture decisions](docs/decisions/README.md)

## Guiding principle

The model may decide which information or action it needs. Deterministic
application code decides whether that action is authorized and how it is
performed.

Shopify remains the commerce system of record. This application owns customer
relationships, conversations, attribution evidence, follow-up, and AI-assisted
sales; it links to Shopify for detailed commerce administration.

## Current status

The executable foundation is now in place:

- Phoenix 1.8 application with LiveView and PostgreSQL
- Oban-backed durable job infrastructure
- Docker Compose development environment
- liveness and database-readiness endpoints
- provider-neutral AI boundary with a deterministic fake provider for development
- initial automated tests and a passing `mix precommit` check
- store-scoped customers, phone identities, conversations, and ordered messages
- a bounded, traceable conversation engine with deterministic fake adapters
- human escalation, duplicate suppression, and persisted outbound intents
- a live Shopify catalogue and test-cart workspace at <http://localhost:4000/shopify>

The DEL-002 conversation core is implemented on its delivery branch. The next
planned slices connect the Shopify catalogue and real WhatsApp messaging before
the manager CRM workspace. External credentials are intentionally not required
for the deterministic conversation-core tests.

## Local development

Docker is the only host dependency required:

```bash
cp .env.example .env
docker compose up --build
```

Open <http://localhost:4000>. The application applies migrations as it starts.
Its health endpoints are:

- `GET /health/live` for process liveness
- `GET /health/ready` for application and database readiness

Run the complete local quality gate with:

```bash
docker compose run --rm -e MIX_ENV=test app mix precommit
```

Stop the services without deleting the database volume:

```bash
docker compose down
```
