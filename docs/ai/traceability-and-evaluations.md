# AI traceability and evaluations

## Agent run record

Record for every run:

- Customer, conversation, and input message identifiers
- Model provider and exact model identifier
- Provider response and request identifiers
- Prompt and tool-schema versions
- Input message references and customer facts supplied
- Tool calls, validated arguments, results, and duration
- Final outbound message
- Token usage, latency, retry count, and estimated cost
- Error or escalation outcome
- Subsequent human correction, if any

Store observable behavior, not hidden model reasoning.

## Prompt versioning

Prompts are version-controlled artifacts with an identifier recorded on every
run. A prompt change is deployed only after replaying the evaluation set.

## Evaluation dataset

Build the initial dataset from anonymized historical customer conversations.
Each case records expected and forbidden behavior rather than requiring one
exact sentence.

```json
{
  "messages": ["I need gloves for artificial turf"],
  "expected_behaviors": [
    "asks_for_size",
    "asks_about_training_or_match_use"
  ],
  "forbidden_behaviors": [
    "claims_inventory_without_tool",
    "invents_discount"
  ]
}
```

## Test layers

- Unit tests for business rules and tool validation
- Contract tests for provider adapters
- Integration tests with recorded or sandbox provider responses
- Conversation-level behavioral evaluations
- Production sampling and human review

## Release gates

Track at least groundedness, correct tool choice, correct handoff, policy
compliance, latency, and estimated cost. Model, prompt, context, and tool changes
must be independently identifiable in results.
