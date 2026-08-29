# Operations and cost controls

## Initial infrastructure

Operate the smallest useful topology:

- One Phoenix application deployment
- One PostgreSQL database
- Oban jobs stored in PostgreSQL
- Object storage only if retained media requires it

The proposed production platform and release process are documented in
[Deployment and cloud practices](deployment-and-cloud-practices.md).

Avoid Redis, Kafka, Kubernetes, Elasticsearch, a vector database, and separate
analytics infrastructure until measurements demonstrate a need.

## Cost controls

- Use a smaller capable model for normal turns and selectively escalate difficult
  cases.
- Keep prompts stable and compact.
- Summarize old conversations and send only relevant confirmed facts.
- Cache catalogue data briefly, but revalidate price and inventory before claims.
- Cap output length and agent tool iterations.
- Track cost per run, conversation, cart, and paid order.
- Prevent duplicate webhook processing and duplicate outbound messages.
- Apply lifecycle messaging frequency limits.

## Reliability

- Idempotency keys on webhook and outbound processing
- Exponential retry with bounded attempts
- Dead-letter state and replay tooling
- External call timeouts
- Provider circuit breakers
- Per-conversation serialization
- Health checks and queue-latency monitoring

## Observability

Use correlation IDs across webhook, job, agent run, tool call, outbound message,
cart, and order. Capture:

- Request and job latency
- Queue depth and oldest-job age
- External API error rate
- Agent tool and handoff rate
- Message delivery state
- Token usage and estimated cost
- Conversion funnel events

## Scaling sequence

1. Tune queries and indexes.
2. Split web and worker process types.
3. Increase worker concurrency with provider-aware backpressure.
4. Add read replicas or analytics projections if needed.
5. Extract a service only for a proven isolation requirement.
