# DEL-001: Application foundation

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Done |
| Branch | `main` |
| Pull request | Not applicable—bootstrap commit [`47884ee`](https://github.com/gtrujillop/goalkeeper-crm-agent/commit/47884ee) |
| Production | No |
| Production date | — |

## Outcome

Developers can run, test, and extend a production-oriented Phoenix application
locally without paid external services or AI credentials.

## Scope

- Phoenix, LiveView, Ecto, and PostgreSQL application scaffold.
- Docker Compose development environment.
- Oban background-job foundation.
- Provider-neutral AI boundary and deterministic fake provider.
- Liveness and database-readiness endpoints.
- Architecture, operations, integration, and product documentation.

## Acceptance criteria

- [x] The application starts through Docker Compose.
- [x] Database migrations run successfully.
- [x] Liveness and readiness checks return successful responses.
- [x] `mix precommit` passes.
- [x] The code is tracked in the public GitHub repository.

## Dependencies

- None.

## Out of scope

- Customer and conversation domain behavior.
- External WhatsApp, Shopify, advertising, or AI-provider connections.

## Delivery notes

The initial implementation was committed directly because it bootstrapped the
repository. All subsequent feature work follows the deliverable branch and PR
workflow.
