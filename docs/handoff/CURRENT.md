# Current session handoff

| Field | Value |
| --- | --- |
| Updated | 2026-09-05 |
| Active deliverable | [DEL-005: Manager CRM workspace](../deliverables/DEL-005-manager-crm-workspace.md) |
| Status | In Progress |
| Branch | `deliverable/DEL-005-manager-crm` |
| Pull request | — |
| Production | No |

## Current objective

Open and review the DEL-005 pull request, then validate one manager reply from
Goalkeeper with Meta's test number without migrating the production WhatsApp
number.

## Recently completed

- Implemented `/crm` with a responsive, exception-ranked conversation inbox and customer search by name, email, or normalized phone.
- Added ordered role-aware message history, manager assignment, immediate AI pause/resume, and direct replies through the configured messaging adapter.
- Added progressive confirmed profiles, notes, follow-up tasks, opportunity stages, and Shopify order summary links.
- Added store-scoped CRM persistence and locale-aware store/currency/time presentation.
- Added real-time store-scoped CRM refreshes after inbound WhatsApp processing and delivery-status updates.
- Selected direct Meta Cloud API without Coexistence for the initial production operating model; managers will perform manual takeover and replies in Goalkeeper.
- Redesigned `/crm` for direct WhatsApp operations with prominent AI/human ownership, escalation handling, denser conversation navigation, and a safer reply composer.
- Manager replies now pause AI automatically before delivery to prevent competing responses.
- Added `/admin` to manage store-scoped WABA mappings and activation, inspect masked credential readiness, and edit core store settings without using the console.
- Committed the conversation UX, responsive behavior, direct Cloud API operating model, and administration interface as `4dc044f`.
- Committed the implementation as `d49f92b` and pushed `deliverable/DEL-005-manager-crm` to origin.
- DEL-004 merged to `main` in pull request [#3](https://github.com/gtrujillop/goalkeeper-crm-agent/pull/3) as merge commit `bb35d8e`.
- Added signed Meta webhook verification, durable idempotent event ingestion, and per-customer job serialization.
- Added Cloud API text/template delivery, transient retries, and auditable `sent`, `delivered`, `read`, and failed statuses.
- Added immediate human takeover with an ownership recheck before outbound automation.
- Validated a real inbound and outbound exchange using Meta's Cloud API test number.

## Required context

- [DEL-005](../deliverables/DEL-005-manager-crm-workspace.md)

## Next actions

1. Open a pull request linked to DEL-005 and set the deliverable to `In Review` with the PR URL.
2. Review `/crm` and `/admin` on physical phone and tablet browsers.
3. Perform a live manager-reply check with Meta's test number before merge.
4. Implement [DEL-009](../deliverables/DEL-009-operator-access-and-authorization.md) before production exposure of `/crm` or `/admin`.

## Validation

- DEL-005 `mix precommit` passed on 2026-09-05: 40 tests, 0 failures.
- CRM LiveView tests cover customer search, priority selection, Shopify links, assignment, takeover, manager reply, confirmed profiles, notes, tasks, and opportunities.
- Responsive browser checks completed at 390px phone, 820px portrait tablet, and 1440px desktop widths for `/crm`; `/admin` was also checked at phone and desktop widths.
- Live Meta test-number validation persisted inbound `Hola!!`, sent the deterministic agent reply, and recorded `sent`, `delivered`, and `read`.
- Duplicate delivery, signature rejection, unsupported payload, status auditing, serialization, and takeover suppression have automated coverage.
- The real store number was not migrated and remains on the WhatsApp Business mobile app.

## Blockers and external requirements

- No current repository blocker.
- Meta credentials remain local and must not be committed.
- [DEL-009](../deliverables/DEL-009-operator-access-and-authorization.md) must protect `/crm` and `/admin` and replace hardcoded manager identity before production deployment.
- Keep the live store number outside CRM automation until the DEL-005 manager inbox is production-ready and the direct Cloud API migration and rollback procedure is approved.

## Repository state

- Current branch is `deliverable/DEL-005-manager-crm` at implementation commit `4dc044f`, tracking `origin/deliverable/DEL-005-manager-crm`.
- DEL-005 acceptance criteria are implemented; status remains `In Progress` until review and merge.
- Inspect Git for exact commits after this handoff; Git remains authoritative.
