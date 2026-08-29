# Deployment and cloud practices

## Recommendation

Deploy the initial production system to Render as a Dockerized Phoenix release
with managed Render PostgreSQL.

The initial topology is deliberately small:

```text
GitHub repository
        |
        | merge to main
        v
Render web service
Phoenix + LiveView + Oban
        |
        | private connection
        v
Managed Render PostgreSQL

External APIs:
- WhatsApp Cloud API
- Shopify
- AI provider
- Error monitoring
```

Run Phoenix and Oban within the same application instance at low traffic. Split
the web and worker process types later without changing the codebase or Docker
image.

The platform decision remains proposed until a small deployment spike validates
cost, regional latency, database recovery, and provider webhook behavior. See
[ADR-0004](../decisions/0004-render-for-initial-deployment.md).

## Why Render

Render provides an appropriate abstraction for a small store:

- Managed application runtime, routing, TLS, and PostgreSQL
- Health checks and controlled deployments
- Background worker support
- Infrastructure definitions through `render.yaml`
- Private application-to-database networking
- Managed database backup and recovery capabilities on paid plans
- A portable application artifact because the system remains a normal Docker
  image and Phoenix release

Fly.io is the preferred alternative when learning lower-level infrastructure,
regional placement, and machine lifecycle is more important than minimizing
operational attention. Large public-cloud platforms and Kubernetes are deferred
until a demonstrated requirement justifies them.

## Container and release strategy

Generate a production release configuration using Phoenix tooling:

```bash
mix phx.gen.release --docker
```

The Docker build should:

1. Pin Elixir, Erlang/OTP, and base operating-system image versions.
2. Compile dependencies and assets in a builder stage.
3. Produce an Elixir release.
4. Copy only runtime artifacts into a minimal runner image.
5. Run as a non-root user.
6. Contain no development credentials or `.env` files.

Avoid mutable `latest` image tags. The same image should be usable for web,
worker, migration, and administrative release commands.

## Repository deployment assets

```text
Dockerfile
.dockerignore
render.yaml
.github/
  workflows/
    ci.yml
    security.yml
config/
  runtime.exs
rel/
  overlays/
    bin/
      migrate
```

`render.yaml` should eventually declare:

- Web service and region
- Managed PostgreSQL
- Health-check path
- Environment and secret references
- Pre-deploy migration command
- Graceful shutdown duration
- Worker service when it becomes necessary

Keep the application and database in the same region. Choose the closest
available region based on measured latency to customers and external providers,
not developer location alone.

## Continuous delivery

```text
Pull request
    |
    v
Format, compile, test, static and dependency checks
    |
    v
Merge to main
    |
    v
Build immutable image
    |
    v
Run backward-compatible migrations
    |
    v
Start new release
    |
    v
Readiness succeeds
    |
    v
Route production traffic
```

Suggested CI commands:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix sobelow --config
mix deps.audit
```

Adopt checks incrementally, but never deploy a revision that fails compilation or
tests.

## Health checks

Expose separate endpoints:

```text
GET /health/live
GET /health/ready
```

Liveness proves that the Phoenix process can answer HTTP requests. It must not
depend on PostgreSQL or external providers.

Readiness verifies that required configuration is present and PostgreSQL is
usable. It must not call WhatsApp, Shopify, or an AI provider; their outages
should trigger circuit breakers and operational alerts rather than application
restart loops.

Configure the platform deployment check against `/health/ready`.

## Database and migration practices

Use paid managed PostgreSQL for production because CRM and message history are
irreplaceable business data.

- Connect over the provider's private network.
- Keep the database inaccessible from the public internet when possible.
- Use a deliberately bounded Ecto connection pool.
- Configure connection and statement timeouts.
- Use point-in-time recovery and periodic portable logical exports.
- Test restoration before relying on the backup policy.
- Monitor capacity and slow queries.

Run migrations as a release or pre-deploy command, not independently from every
application instance at startup.

Use expand-and-contract migrations:

1. Add a compatible table, column, or index.
2. Deploy code that supports old and new representations.
3. Backfill asynchronously when needed.
4. Add constraints after validation.
5. Remove obsolete fields in a later release.

Avoid destructive schema changes in the same deployment that stops using the old
schema.

## Oban process strategy

Initially, run small queues inside the web service:

```elixir
config :store_crm, Oban,
  repo: StoreCRM.Repo,
  queues: [
    inbound_messages: 5,
    agent_runs: 3,
    outbound_messages: 5,
    integrations: 3,
    lifecycle: 1
  ]
```

These numbers are starting hypotheses, not capacity targets. External provider
limits and measured latency determine final concurrency.

Every job must be idempotent. Configure a shutdown grace period so running work
has time to finish, while assuming that interrupted work may later be retried.

When workload or availability requires it, run the same image in two roles:

```text
web: Phoenix endpoint, lightweight queues disabled
worker: Oban queues, public endpoint disabled
```

## Runtime configuration and secrets

Production configuration comes from environment variables evaluated in
`runtime.exs`.

Expected secrets include:

```text
SECRET_KEY_BASE
DATABASE_URL
PHX_HOST
OPENAI_API_KEY
SHOPIFY_STORE_DOMAIN
SHOPIFY_ADMIN_ACCESS_TOKEN
SHOPIFY_STOREFRONT_ACCESS_TOKEN
WHATSAPP_ACCESS_TOKEN
WHATSAPP_PHONE_NUMBER_ID
WHATSAPP_APP_SECRET
WHATSAPP_VERIFY_TOKEN
SENTRY_DSN
```

Rules:

- Never commit `.env` or provider credentials.
- Fail startup when required configuration is missing.
- Use separate sandbox and production credentials.
- Grant the minimum Shopify and Meta permissions required.
- Keep `SECRET_KEY_BASE` stable across releases.
- Rotate credentials and audit access.
- Redact tokens and customer data from logs.

## Environments

Begin with local development, CI, and production. Permanent staging creates both
cost and data-management overhead. Add it when customer dependency or integration
risk makes it worthwhile.

Until then:

- Use Shopify and WhatsApp test facilities.
- Use fake integration adapters in automated tests.
- Use temporary review or staging deployments for risky releases.
- Never run tests with production write credentials.

## Observability

Begin with structured logs, error reporting, platform metrics, application
telemetry, and a simple uptime check. Do not initially self-host a large
observability stack.

Propagate a correlation ID through:

```text
webhook
-> message
-> conversation
-> agent run
-> tool call
-> outbound message
-> cart
-> order
```

Monitor and alert on:

- Application and database availability
- Webhook rejection or processing failures
- Oldest queued-job age and exhausted jobs
- Outbound-message failure rate
- External API error and latency trends
- Agent failure and handoff rates
- Token usage and estimated AI cost
- Database capacity and backup failures

Alerts should represent sustained or exhausted failure, not every transient API
error.

## Security baseline

- Terminate HTTPS at the platform and enforce secure cookies.
- Verify all provider webhook signatures.
- Restrict CRM access with authentication and roles.
- Prevent direct public access to PostgreSQL.
- Run the container as a non-root user.
- Scan dependencies and the final image.
- Apply retention rules to raw provider payloads and media.
- Maintain a global AI-reply kill switch.
- Audit human access and consequential actions.

## Cost controls

Initial infrastructure should contain only:

- One small always-available application instance
- One small paid managed PostgreSQL database
- No Redis, Kafka, Kubernetes, Elasticsearch, or vector database
- No separate worker or observability deployment

Application-level limits include:

- Maximum agent turns and tool calls
- Maximum output tokens
- Bounded retries
- Maximum automated follow-ups per customer
- Messaging frequency caps
- Daily or monthly AI-cost alerts

Track infrastructure and provider cost per conversation, cart, and paid order.
Business-unit cost is more actionable than a single monthly API bill.

## Scaling order

1. Optimize queries, indexes, prompts, and model usage.
2. Split web and worker process roles.
3. Increase worker concurrency with provider-aware backpressure.
4. Add a second web instance when availability or traffic requires it.
5. Introduce analytics projections or read replicas when measured queries demand
   them.
6. Extract a service only for a demonstrated scaling, isolation, security, or
   ownership boundary.

## Production launch checklist

- [ ] Immutable Phoenix release builds locally and in CI
- [ ] CI blocks failed tests and compilation warnings
- [ ] `render.yaml` represents production infrastructure
- [ ] Liveness and readiness checks behave correctly
- [ ] Migrations run once and are backward-compatible
- [ ] Paid PostgreSQL recovery and logical exports are configured
- [ ] A backup restoration has been tested
- [ ] Provider webhooks are authenticated and idempotent
- [ ] Oban shutdown and retry behavior has been exercised
- [ ] Secrets are stored in the platform and logs are redacted
- [ ] CRM authentication and authorization are enabled
- [ ] Error monitoring, uptime monitoring, and budget alerts are active
- [ ] AI reply kill switch and human takeover have been tested
- [ ] Production WhatsApp webhook is connected last
