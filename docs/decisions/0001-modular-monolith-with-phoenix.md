# ADR-0001: Use a Phoenix modular monolith

- Status: Proposed
- Date: 2026-08-29

## Context

The store is small and requires low operational cost, but the project should
provide meaningful learning beyond the author's existing Rails experience. The
system contains transactional CRM behavior, concurrent conversations, durable
jobs, webhooks, a real-time internal interface, and multiple external APIs.

## Decision

Build the initial system as an Elixir/Phoenix modular monolith using LiveView,
Ecto, PostgreSQL, and Oban.

## Consequences

Positive:

- New experience with OTP, supervision, message passing, and functional design
- One language and deployment for API, workers, and internal UI
- Small and economical operational footprint
- Clear path to real-time CRM updates

Negative:

- Smaller AI-library ecosystem than Python or TypeScript
- New language and runtime increase initial delivery time
- Care is needed to avoid treating in-memory processes as durable state

## Revisit when

A proven ML workload requires a Python service, or an integration demonstrates
an independent deployment or scaling requirement.
