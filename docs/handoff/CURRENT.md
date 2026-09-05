# Current session handoff

| Field | Value |
| --- | --- |
| Updated | 2026-09-05 |
| Active deliverable | [DEL-006: Orders and attribution](../deliverables/DEL-006-orders-and-attribution.md) |
| Status | In Progress |
| Branch | `deliverable/DEL-006-orders-attribution` |
| Pull request | — |
| Production | No |

## Current objective

Review the WhatsApp-first DEL-006 workflow and prepare its pull request.

## Completed

- Branched from updated `main` at `076c618` (DEL-005 PR #4 merge).
- Reconciled DEL-005 status to Done after the user's merge confirmation.
- Implemented signed Shopify webhook ingestion, atomic event/job persistence,
  idempotent lifecycle projections, conservative identity matching, signed cart
  correlation, and reliable paid-opportunity conversion.
- Added `/crm/orders` for direct purchases, identity reconciliation, event history,
  payment/fulfillment context, evidence-backed first/last attribution, and internal
  delivery follow-up tasks.
- Added Meta referral capture, Google redirect tokens, and derived customer totals.
- Added Admin setup and monitoring for DEL-006: domain, campaign WhatsApp number,
  payment mappings, masked signing-secret status, setup instructions, campaign
  link, reception/error counts, attribution counts, and recent store-scoped events.
- Added native WhatsApp order entry from conversations with agreed item and
  delivery snapshots, server-computed totals, transfer/COD methods, and explicit
  opportunity linkage, independently of Shopify.
- Added auditable independent payment/fulfillment transitions, submission
  deduplication, store scoping and stale-screen rejection. Both channels appear
  in order lists, customer context, attribution and follow-up.
- Admin now shows native orders and pending transfer/COD counts above the optional
  Shopify integration setup.
- Updated durable product boundaries in AGENTS.md and linked product/domain docs
  following the owner's confirmation that WhatsApp sales remain outside Shopify.
- Applied `20260905170604_add_orders_and_attribution` and
  `20260905173634_add_native_whatsapp_orders` to the local development DB.

## Required context

- [DEL-006](../deliverables/DEL-006-orders-and-attribution.md), including its Required context links.

## Validation

- `docker compose exec -e MIX_ENV=test app mix precommit`: 65 tests, 0 failures.
- Tests cover signature verification, job persistence, duplicates, lifecycle order,
  refunds, paid opportunity conversion, identity conflicts, store isolation,
  unknown revenue, token expiry/replay, redirect routing, and LiveView follow-up.

- Local `/crm/orders` returned HTTP 200; inspected its empty-state layout in
  headless Chrome at 390px phone and 1440px desktop widths. Populated-order actions have LiveView coverage.

- Admin setup/monitoring tests cover validation, persistence, clearing, store
  isolation, refresh, and secret masking. Phone and desktop browser layouts checked.
- The user configured the Shopify webhook secret in local `.env`; the app was
  recreated and the running container confirms it is present without revealing it.
- Public ngrok health returned HTTP 200 after startup.
- Shopify Admin orders/paid test received on 2026-09-05 at 23:18:51 UTC: ngrok
  recorded HTTP 200 and the store-scoped event is processed with no error. This
  validates signed sample delivery; a real checkout correlation check remains pending.
- The campaign WhatsApp destination was previously unset and was not changed.

- Native order tests cover totals, snapshots, duplicate creation, opportunity
  conversion, independent COD payment/delivery, refunds, invalid transitions,
  store isolation and stale forms. Native entry inspected at 390px and 1440px.

## Next actions / external requirements

1. Review conversation → Registrar pedido → payment/delivery → attribution,
   then open the DEL-006 PR.
2. For the optional Shopify channel, configure its signing secret/subscriptions
   and validate checkout correlation/webhook delivery before enabling that channel.
   Native WhatsApp orders do not require this setup.
3. DEL-009 must protect native order creation/detail routes, `/crm/orders`, `/crm`,
   and `/admin` and replace the development Manager actor label before production.

## Repository state

- Branch is `deliverable/DEL-006-orders-attribution`; base commit is `076c618`.
- DEL-006 implementation and documentation are uncommitted. No DEL-006 PR exists.
- No production deployment or live commerce/message side effects performed.
