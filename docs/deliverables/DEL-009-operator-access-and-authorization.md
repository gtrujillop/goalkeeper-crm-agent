# DEL-009: Operator access and authorization

| Field | Value |
| --- | --- |
| Created | 2026-09-05 |
| Status | Backlog |
| Branch | `deliverable/DEL-009-operator-access` |
| Pull request | — |
| Production | No |
| Production date | — |

## Outcome

Only authorized store operators can access customer conversations and operational
configuration, and every manager action is attributed to the person who performed
it.

## Scope

- Secure operator authentication and session lifecycle.
- Store-scoped operator membership.
- Administrator and manager roles with explicit permissions.
- Route protection for CRM and administration workspaces.
- Real operator identity on conversation assignment, manager messages, notes, and
  other auditable actions.
- Safe invitation, access removal, password reset or equivalent recovery, and
  session revocation workflows.
- Basic access-event auditing and production-safe authentication configuration.

## Acceptance criteria

- [ ] Anonymous visitors cannot access `/crm`, `/admin`, or customer information.
- [ ] A manager can use the conversation workspace but cannot change restricted
      integration or store configuration.
- [ ] An administrator can manage WABA mappings, store settings, and operator
      access for their store only.
- [ ] Conversation assignment, manual replies, notes, and configuration changes
      record the authenticated operator rather than a hardcoded identity.
- [ ] Removing an operator's access prevents new sessions and revokes existing
      sessions within a documented bounded period.
- [ ] Authentication secrets and credentials are absent from source control,
      rendered pages, and application logs.
- [ ] Authorization and store-isolation behavior have automated coverage.
- [ ] Primary sign-in, recovery, and operator-management workflows are usable on
      phone, tablet, and desktop viewports.

## Dependencies

- DEL-005 for the CRM and administration workspaces being protected.

## Out of scope

- Customer authentication or a customer-facing account portal.
- Enterprise SSO, SCIM provisioning, or complex custom role builders.
- Multi-organization reseller or Tech Provider administration.

## Delivery notes

Complete this before exposing `/crm` or `/admin` in production. Prefer a small,
application-owned operator model with secure defaults over an enterprise identity
platform unless deployment requirements establish a clear need for one.
