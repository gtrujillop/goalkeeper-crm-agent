# ADR-0004: Use Render for the initial deployment

- Status: Proposed
- Date: 2026-08-29

## Context

The production system must be inexpensive and easy to maintain for a small store
while providing experience with portable containers, infrastructure as code,
continuous delivery, managed data services, health checks, observability, and
secure runtime configuration.

The initial system needs an always-available webhook endpoint, Phoenix LiveView,
Oban background processing, and reliable PostgreSQL. Operating Kubernetes or a
large public-cloud platform would add cost and distract from product and AI
engineering.

## Decision

Deploy a Dockerized Phoenix release to a Render web service with paid managed
Render PostgreSQL. Run Oban in the web service initially. Describe infrastructure
in `render.yaml` and deploy automatically after CI succeeds on the main branch.

Use Fly.io as the preferred alternative if a deployment spike shows a meaningful
cost, latency, capability, or regional-availability advantage.

## Consequences

Positive:

- Small initial production footprint
- Managed TLS, routing, deployment, PostgreSQL, and recovery
- Infrastructure configuration can live with the application
- Docker and Phoenix releases reduce platform lock-in
- Web and worker roles can be split without a new codebase

Negative:

- Paid always-available compute and PostgreSQL create a fixed baseline cost
- Platform-specific Blueprint configuration must be maintained
- Less direct infrastructure learning than building on AWS or GCP
- Some advanced availability and networking controls depend on higher plans

## Validation spike

Before accepting this ADR:

1. Deploy a minimal Phoenix release from the repository.
2. Verify LiveView connectivity and webhook reachability.
3. Run an Oban job across a deployment and confirm retry behavior.
4. Run and roll forward a database migration.
5. Exercise point-in-time or logical-backup restoration in a non-production
   database.
6. Measure latency from the store's primary customer geography.
7. Record the actual monthly baseline and compare it with Fly.io.

## Revisit when

- Regional latency is unacceptable.
- Platform cost becomes disproportionate to traffic.
- Availability requirements require multi-region operation.
- Database, compliance, or networking requirements exceed platform capabilities.
- The team is prepared to assume more infrastructure responsibility.
