# ADR-0002: Use a PostgreSQL outbox instead of Kafka

- Status: Proposed
- Date: 2026-08-29

## Context

The design benefits from events, retries, asynchronous work, and auditability.
The expected initial volume does not justify operating Kafka, and the application
already requires PostgreSQL.

## Decision

Write domain events to a transactional outbox and process them with Oban. Event
handlers must be idempotent.

## Consequences

Positive:

- Atomic business changes and event publication
- One durable storage system to operate and back up
- Event-driven learning without distributed infrastructure
- Straightforward replay and inspection

Negative:

- Lower independent throughput than a dedicated log platform
- Application code owns outbox cleanup and replay semantics
- Consumers share a database-level scaling boundary

## Revisit when

Measured event volume, independent consumers, retention, or replay requirements
exceed what PostgreSQL and Oban can comfortably provide.
