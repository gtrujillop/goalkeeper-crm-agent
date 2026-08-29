# Project context

## Goal

Build a low-cost, trustworthy conversational CRM for a small Shopify store that
sells goalkeeper gloves and wearables. It should automate routine WhatsApp sales
assistance, retain customer relationship history, support repeat purchases, and
give the owner or manager an exception-driven workspace with immediate human
takeover.

## Business journeys

Customers may arrive from Instagram ads, Google, organic discovery, referrals,
or an unknown source. They may ask about products, sizes, price, stock, delivery,
or payment in WhatsApp, or purchase directly through Shopify without a preceding
conversation. Supported Colombian purchase paths include Shopify checkout with
Mercado Pago, bank transfer, and TCC cash on delivery when eligible. Fulfilled
orders may lead to WhatsApp delivery confirmation and relationship follow-up.

Early WhatsApp identity commonly consists only of a phone number and
provider-visible information. Collect personal or fulfillment details
progressively, only when the transaction requires them. Never manufacture a
known acquisition source when evidence is absent.

## Product boundary

Shopify owns catalogue, variants, inventory, checkout, orders, payments, refunds,
and fulfillment. This application stores concise projections and deep links to
Shopify; it does not recreate Shopify administration.

The CRM owns customers and their provider identities, conversations and messages,
opportunities, relationship facts, consent, attribution evidence, follow-up work,
human handoffs, and AI/tool traceability.

## Market model

The seeded store profile is Colombia: `CO`, `es-CO`, COP,
`America/Bogota`, and phone region `CO`. Market settings, policies, provider
accounts, prompts, and data are store-scoped. A future Spain operation uses a
separate store profile in the same application rather than a code fork.

## Technical direction

- Elixir, Phoenix LiveView, Ecto, and PostgreSQL.
- Modular monolith with Oban and a transactional outbox.
- Provider-neutral adapters for WhatsApp, Shopify, and AI.
- Deterministic fake adapters for automated tests; no disposable simulator UI.
- Application-owned bounded agent loop with explicit authorization and audit data.
- Docker Compose locally and a simple managed deployment initially.

## Sources of truth

- [Product vision](../product/vision-and-scope.md)
- [Customer journeys](../product/customer-journeys.md)
- [Markets and store profiles](../product/markets-and-store-profiles.md)
- [Domain model](../domain/domain-model.md)
- [System architecture](../architecture/system-architecture.md)
- [AI agent design](../ai/agent-design.md)
- [Delivery board](../deliverables/README.md)
- [Architecture decisions](../decisions/README.md)

This file changes only when durable project context changes. Current work belongs
in [CURRENT.md](CURRENT.md).
