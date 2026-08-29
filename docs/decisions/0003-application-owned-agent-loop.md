# ADR-0003: Own the initial AI agent loop

- Status: Proposed
- Date: 2026-08-29

## Context

The initial assistant requires a small set of tools, durable CRM state, explicit
authorization, traceability, and human handoff. General agent frameworks could
duplicate application state and hide important behavior the project is intended
to teach.

## Decision

Implement a bounded provider-neutral tool loop inside the application. PostgreSQL
stores canonical context and trace records. AI providers are accessed through an
adapter behaviour.

## Consequences

Positive:

- Explicit control of authorization, retries, tool results, and handoff
- Clear traceability and provider portability
- Small dependency and operational surface
- Direct learning about AI application engineering

Negative:

- The application owns orchestration and evaluation infrastructure
- Advanced graph workflows require additional implementation
- Provider response normalization must be maintained

## Revisit when

Agent workflows require durable branching, complex human approval graphs, or
features whose implementation cost is demonstrably lower with a framework.
