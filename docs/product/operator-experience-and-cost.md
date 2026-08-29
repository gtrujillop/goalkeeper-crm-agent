# Operator experience and cost guardrails

## Product principle

The manager works from a short queue of business exceptions. Routine automation
and technical complexity remain out of the way.

## Primary navigation

```text
Inbox | Customers | Orders | Tasks | Dashboard
```

### Inbox

Prioritize conversations requiring action:

- Customer requested a person
- Bank-transfer proof requires verification
- Cash-on-delivery confirmation or address is incomplete
- Complaint, return, size, or delivery problem
- Agent could not produce a grounded answer
- High-value or team purchase

Normal automated conversations remain searchable without filling the attention
queue. A prominent `Take over conversation` action immediately disables AI
replies and assigns the conversation to a person.

### Customer profile

Show known identities, useful confirmed preferences, recent conversation,
current opportunity, concise purchase summaries, tasks, and acquisition evidence
when available. Unknown name, location, and source are acceptable states.

### Orders

Show only relationship-relevant information:

- Customer and related conversation
- Assisted versus direct purchase
- Payment method and high-level status
- Shipment and post-delivery follow-up state
- Acquisition evidence

Provide clear actions such as `Open order in Shopify`, `Open customer in Shopify`,
and `Track shipment with TCC`. Do not reproduce full Shopify order management.

### Tasks

Tasks use business language:

```text
Verify bank transfer
Confirm cash-on-delivery address
Respond to size exchange
Investigate failed delivery
Follow up after delivery
```

### Dashboard

Begin with new leads, conversations needing attention, paid orders, assisted and
direct revenue, conversion, repeat customers, failed deliveries, campaign results
when known, and estimated operating cost.

## Interaction design

- Use business terminology, not agent or infrastructure terminology.
- Make unknown data explicit instead of appearing broken.
- Use progressive disclosure for technical traces.
- Design LiveView screens mobile-first.
- Require few clicks for the most frequent manager actions.
- Keep Shopify as the destination for detailed commerce administration.

## AI usage boundary

Use AI for language understanding, product explanation, comparison, summaries,
issue classification, and response drafting. Use deterministic application code
for order, payment, shipment, consent, attribution, task, and workflow state.

## Cost ledger

Track fixed and variable costs by provider and business outcome:

```text
cloud compute
database
AI input and output
WhatsApp messaging
monitoring and storage
```

Report cost per conversation, assisted cart, paid order, and acquired customer.

## Cost guardrails

- One Phoenix deployment and one paid PostgreSQL database initially
- Embedded Oban workers
- Cost-efficient default model with measured escalation
- Relevant compact context rather than complete customer history
- Hard limits on model turns, tool calls, output, retries, and follow-ups
- No AI calls for deterministic synchronization and status transitions
- Short-lived caching for stable catalogue and policy information
- Daily and monthly usage warnings

When approaching a budget, reduce optional follow-up and high-cost features before
affecting active inbound customer service.

## Usability acceptance criteria

A non-technical manager can:

- Identify what requires attention and why.
- Take over and release a conversation.
- Verify a bank transfer.
- Confirm a cash-on-delivery order.
- Find a customer's relationship history.
- Open authoritative order details in Shopify.
- See known acquisition evidence without requiring it.
- Follow up on delivery and resolve an issue.
- Understand current application and AI cost.
