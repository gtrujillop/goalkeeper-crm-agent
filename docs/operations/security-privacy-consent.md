# Security, privacy, and consent

This document is an engineering baseline, not legal advice. Applicable privacy,
consumer, advertising, and messaging requirements must be reviewed for every
country in which the store operates.

## Core controls

- Verify WhatsApp and Shopify webhook signatures.
- Encrypt transport and use a managed encrypted database.
- Keep provider secrets outside source control.
- Rotate credentials and scope them to the minimum access required.
- Use role-based access for the CRM dashboard.
- Audit human access and consequential actions.
- Avoid putting personal information in logs, model metadata, or URLs.
- Apply retention and deletion policies to raw payloads and message media.
- Back up PostgreSQL and test restoration.

## Consent model

Record channel, purpose, status, disclosure version, source, evidence, and event
time. Transactional and marketing purposes are distinct.

Every outbound workflow checks:

- Current consent and opt-out status
- Messaging eligibility and applicable template/session rules
- Quiet hours
- Frequency cap
- Complaint or suppression status

## AI data minimization

Send only the customer information required for the current task. Prefer opaque
internal identifiers. Do not send payment credentials or unnecessary addresses.

## Customer rights

Design explicit operations to export, correct, suppress, and delete customer
information subject to legitimate retention requirements. Identity merges and
splits must be audited and reversible.

## Incident controls

- Global AI reply kill switch
- Per-conversation human ownership switch
- Provider circuit breakers
- Dead-letter queue inspection
- Alerts for repeated delivery failure or abnormal agent behavior
