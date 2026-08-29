# DEL-007: Controlled production pilot

| Field | Value |
| --- | --- |
| Created | 2026-08-29 |
| Status | Backlog |
| Branch | `deliverable/DEL-007-production-pilot` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

The integrated system serves a limited set of real conversations safely, with
known operating cost, observable quality, and a tested shutdown path.

## Scope

- Production deployment, managed PostgreSQL, secrets, backups, and HTTPS.
- Webhook registration and production integration credentials.
- Kill switch and operator runbooks.
- Cost, latency, failure, accuracy, and conversion monitoring.
- Daily conversation review and progressive traffic rollout.
- Restore, rollback, and incident exercises.

## Acceptance criteria

- [ ] Production health checks and alerts are operational.
- [ ] Secrets are absent from source control and application logs.
- [ ] The kill switch is exercised successfully.
- [ ] Database backup and restore procedures are verified.
- [ ] AI and infrastructure spend remain within documented budgets.
- [ ] Pilot conversations are reviewed against the evaluation rubric.
- [ ] Traffic can be increased or returned to human-only handling safely.

## Dependencies

- DEL-003.
- DEL-004.
- DEL-005.
- Critical purchase handling from DEL-006.

## Out of scope

- Fully unattended rollout to every customer.
- High-availability multi-region infrastructure.

## Delivery notes

Production is a separate state from merged code. Record deployment evidence and
the first verified production date in this file.
