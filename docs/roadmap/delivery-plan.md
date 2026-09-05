# Delivery plan

## Phase 0: Discovery and foundations

- Collect and anonymize frequent historical conversations.
- Normalize Shopify product metadata.
- Document shipping, return, warranty, sizing, and discount policies.
- Decide WhatsApp direct API versus provider.
- Confirm consent and privacy requirements.
- Establish success metrics and an evaluation baseline.

## Phase 1: Conversation core

Deliver the conversation engine and exercise it through deterministic end-to-end
tests using fake provider adapters. No temporary simulator UI is required.

- Phoenix application and Ecto foundation
- Customer, conversation, message, and agent-run schemas
- AI provider behaviour and fake provider
- Fake WhatsApp and catalogue adapters
- Bounded tool loop
- Prompt versioning
- Behavioral evaluation harness
- End-to-end conversation scenarios covering persistence and outbound intent

## Phase 2: Shopify vertical slice

- Search real products and variants
- Retrieve current price and availability
- Create a cart
- Persist commerce-session correlation
- Use sandbox or test-store order events

## Phase 3: WhatsApp sandbox

- Webhook verification and deduplication
- Inbound normalization
- Per-conversation job serialization
- Outbound delivery and status tracking
- Explicit human takeover

## Phase 4: CRM dashboard

- Customer search and profile
- Unified activity timeline
- Conversation viewer
- Opportunity pipeline
- Concise orders with links to authoritative details in Shopify
- Progressive customer identities and confirmed facts
- Internal notes and follow-up tasks
- AI enable/disable control
- Exception-driven inbox and mobile-first manager actions

## Phase 5: Purchase and attribution loop

- Shopify paid, canceled, fulfilled, and refunded events
- Opportunity conversion
- Instagram referral metadata
- Google redirect-token flow
- First-touch and last-touch reporting

The major milestone is one journey connected end to end:

```text
ad click -> WhatsApp conversation -> recommendation -> cart -> paid order -> CRM
```

## Phase 6: Controlled production pilot

- Operator authentication, store-scoped roles, and protected CRM/admin routes
- Internal and trusted-customer traffic
- Daily conversation review
- Kill-switch exercise
- Cost, latency, accuracy, and conversion monitoring
- Progressive traffic rollout

## Phase 7: Retention workflows

- Post-purchase care guidance
- Satisfaction follow-up
- Consent-aware replenishment estimates
- Returning-customer personalization
- Segmentation and cohort reporting

## Definition of done for MVP

- Every inbound message is traceable and deduplicated.
- Agent claims about products come from Shopify tools.
- Human takeover is immediate and reliable.
- A paid Shopify order can be connected to its customer and conversation.
- Ad source is shown when a reliable token or referral is available.
- Prompt/model/tool versions and cost are visible for every agent run.
- The evaluation suite prevents known unsafe or incorrect behaviors.
