# Current session handoff

| Field | Value |
| --- | --- |
| Updated | 2026-08-29 |
| Active deliverable | [DEL-002: Conversation core](../deliverables/DEL-002-conversation-core.md) |
| Status | In Progress |
| Branch | `deliverable/DEL-002-conversation-core` |
| Pull request | — |
| Production | No |

## Current objective

Prepare the completed store-scoped conversation core for review. There is no
terminal or LiveView simulator in scope.

## Completed on this branch

- Refined DEL-002 around an application-level conversation engine and E2E tests.
- Defined configurable store profiles with Colombia as the seeded default and a
  future Spain profile as an example.
- Updated related product, domain, AI, and deliverable documentation.
- Added this persistent AI-session handoff mechanism.
- Added store profiles, progressive phone identities, conversations, explicitly
  ordered messages, agent runs, tool calls, and human handoffs.
- Added a bounded conversation engine with provider-neutral AI, catalogue, and
  messaging adapters plus store-required Oban ingestion.
- Seeded the Colombia profile and implemented E.164 normalization that preserves
  explicit international numbers.
- Added deterministic end-to-end coverage for all DEL-002 scenarios, token limits,
  regional context, and automation suppression during human ownership.

## Required context

- [DEL-002](../deliverables/DEL-002-conversation-core.md)
- [Project context](PROJECT-CONTEXT.md)
- [Markets and store profiles](../product/markets-and-store-profiles.md)
- [Domain model](../domain/domain-model.md)
- [System architecture](../architecture/system-architecture.md)
- [AI agent design](../ai/agent-design.md)
- [AI traceability and evaluations](../ai/traceability-and-evaluations.md)

## Next actions

1. Review the DEL-002 implementation and commit it.
2. Open the DEL-002 pull request and record its URL in the deliverable and board.
3. Run the review checks and address findings before merge.

## Validation

- Last full check: `mix precommit` on 2026-08-29 after implementing DEL-002.
- Result: 20 tests, 0 failures.

## Blockers and external requirements

- No current implementation blocker.
- Real OpenAI API, Shopify, and WhatsApp credentials are not required for DEL-002.
- ChatGPT Plus supports AI-assisted development but production OpenAI API usage
  will require separate API billing in a later deliverable.

## Repository state

- The uncommitted DEL-002 implementation follows commit `98949fb` (`Add persistent AI session handoff`).
- The working branch tracks `origin/deliverable/DEL-002-conversation-core`.
- Inspect Git for commits made after this handoff; Git remains authoritative for
  exact history and working-tree state.
