# Delivery board

This directory is the project's lightweight, repository-native Jira board. Each
`DEL-*.md` file is one independently valuable epic and is the source of truth for
its scope, status, branch, pull request, and production deployment.

## Workflow

| Status | Meaning |
| --- | --- |
| `Backlog` | Defined, but not selected for implementation. |
| `Selected` | Prioritized and ready to begin. |
| `In Progress` | Active implementation exists on its branch. |
| `In Review` | A pull request is open and awaiting validation or review. |
| `Done` | Acceptance criteria passed and the change was merged. |
| `Blocked` | Work cannot continue; the blocker is recorded in the deliverable. |

Only one status may be present in a deliverable's metadata. Moving an item to
`Done` does not imply that it has reached production; deployment is tracked by
the separate `Production` field.

## Board

| ID | Deliverable | Status | Branch | PR | Production |
| --- | --- | --- | --- | --- | --- |
| [DEL-001](DEL-001-application-foundation.md) | Application foundation | Done | `main` | Bootstrap commit | No |
| [DEL-002](DEL-002-conversation-core-and-simulator.md) | Conversation core and simulator | Selected | `deliverable/DEL-002-conversation-core` | — | No |
| [DEL-003](DEL-003-shopify-catalogue-and-cart.md) | Shopify catalogue and cart | Backlog | `deliverable/DEL-003-shopify-catalogue-cart` | — | No |
| [DEL-004](DEL-004-whatsapp-messaging.md) | WhatsApp messaging | Backlog | `deliverable/DEL-004-whatsapp-messaging` | — | No |
| [DEL-005](DEL-005-manager-crm-workspace.md) | Manager CRM workspace | Backlog | `deliverable/DEL-005-manager-crm` | — | No |
| [DEL-006](DEL-006-orders-and-attribution.md) | Orders and attribution | Backlog | `deliverable/DEL-006-orders-attribution` | — | No |
| [DEL-007](DEL-007-controlled-production-pilot.md) | Controlled production pilot | Backlog | `deliverable/DEL-007-production-pilot` | — | No |
| [DEL-008](DEL-008-retention-workflows.md) | Retention workflows | Backlog | `deliverable/DEL-008-retention-workflows` | — | No |

Update this table in the same commit as any deliverable metadata change.

## Branch and pull-request convention

1. Select one deliverable and set its status to `In Progress`.
2. Create its declared branch from an up-to-date `main` branch.
3. Keep commits and pull requests within the deliverable's defined scope.
4. Link the deliverable near the top of the pull-request description.
5. Record the PR URL in both the deliverable and this board, then set `In Review`.
6. After merge and acceptance checks, set the deliverable to `Done` on `main`.
7. Set `Production` to `Yes` only after production verification, recording the
   deployment date and environment evidence in the deliverable.

Use the branch format `deliverable/DEL-###-short-name`. Small corrective work
discovered during an epic stays on that branch only when it is required by the
acceptance criteria; otherwise create a new deliverable.

New deliverables start from [the template](TEMPLATE.md). IDs are sequential and
never reused, even if a deliverable is cancelled.
