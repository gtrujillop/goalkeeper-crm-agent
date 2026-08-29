# Product vision and scope

## Problem

Potential customers may arrive through advertisements, organic search, direct
store visits, referrals, or unknown sources. Some ask repetitive questions
through WhatsApp before purchasing; others buy directly from Shopify without a
conversation. Manually managing relationship context and follow-up is
time-consuming, difficult to trace, and makes assisted sales hard to understand.

## Vision

Create a trustworthy digital sales assistant that gives each customer useful,
personal attention while maintaining a unified CRM history. The platform should
help customers select products and sizes, create a path to checkout, identify
when a human is needed, and support relevant long-term relationships after a
purchase.

## Initial market and expansion

The initial store profile serves Colombia with `es-CO`, COP, an
`America/Bogota` business timezone, and Colombian payment and logistics context.
Those values are configurable profile defaults rather than global constants. A
future Spain operation would use a separate store profile, provider accounts,
policies, and data context while sharing the application code. See
[Markets and store profiles](markets-and-store-profiles.md).

## Primary users

### Customer

Wants fast, accurate advice about products, size, stock, price, delivery, and
store policies.

### Store operator

Needs a unified view of customers, conversations, opportunities, purchases,
pending tasks, acquisition evidence when known, and AI decisions. Must be able
to take control of any conversation immediately.

The operator should work from a short queue of business exceptions. Technical
details such as model calls, webhooks, and tool execution belong in an advanced
diagnostic view.

## System ownership

Shopify remains authoritative for products, variants, inventory, prices,
discounts, checkout, customers created during checkout, orders, payments,
refunds, and fulfillment records.

The CRM owns conversations, customer relationship history, preferences learned
through interaction, opportunities, attribution evidence, follow-up tasks,
post-delivery feedback, and AI traceability. It presents concise order summaries
and links the operator to Shopify Admin for complete order management.

## MVP capabilities

- Receive and send WhatsApp messages through the official platform.
- Identify or create a customer from an inbound interaction.
- Persist raw and normalized messages.
- Ask product-discovery questions.
- Search live Shopify products and variants.
- Recommend no more than three appropriate products.
- Create a Shopify cart or checkout path.
- Receive Shopify order events and connect purchases to customers.
- Represent direct Shopify purchases even when no earlier conversation exists.
- Show the customer journey in an internal CRM timeline.
- Open customer, product, and order details in Shopify Admin.
- Transfer conversations to a human with a useful summary.
- Record agent inputs, outputs, tool calls, latency, and cost.

## Explicitly deferred

- Automatic refunds, discounts, or order modifications
- Multiple cooperating AI agents
- Fine-tuning
- Local model hosting
- Voice-note and image analysis
- Advanced multi-touch attribution
- Mass marketing campaigns
- Kafka, Kubernetes, microservices, and a dedicated vector database
- Reimplementation of Shopify order, payment, refund, inventory, or fulfillment
  administration

## Success measures

- Median first-response time
- Percentage of conversations resolved without human intervention
- Human handoff rate and reasons
- Product recommendation to cart conversion
- Cart to paid-order conversion
- Attributed revenue by source and campaign
- Revenue with unknown or organic acquisition source
- Repeat purchase rate
- Incorrect or unsupported answer rate
- AI and messaging cost per conversation and per paid order

## Product safety boundaries

The system must not invent inventory, prices, discounts, delivery promises,
customer identity, payment status, or order status. Consequential actions must
be implemented and authorized by application code.

Customer profiles must be valid with only a WhatsApp identity or only a Shopify
identity. Additional personal data is collected progressively and only when a
purchase or fulfillment workflow requires it.
