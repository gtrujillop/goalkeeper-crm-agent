# Markets and store profiles

## Decision

The application supports configurable store profiles. The initial and default
profile represents the Colombian business, but Colombia-specific behavior is not
hardcoded into the conversation engine.

A store profile is a business context, not a Git branch and not a fork of the
application. For example:

| Setting | Colombia store | Future Spain store |
| --- | --- | --- |
| Market | `CO` | `ES` |
| Default locale | `es-CO` | `es-ES` |
| Default currency | `COP` | `EUR` |
| Business timezone | `America/Bogota` | `Europe/Madrid` |
| Default phone region | `CO` / `+57` | `ES` / `+34` |
| Policies | Colombia policy versions | Spain policy versions |
| Payments and logistics | Colombia provider configuration | Spain provider configuration |

The MVP operates one Colombia profile. The data model and service boundaries
must nevertheless make the active store explicit so another profile can be
introduced without duplicating the codebase or migrating Colombia data.

## Configuration owned by a store profile

- Public and internal store name.
- Market/country and enabled locales.
- Default customer and operator locale.
- Currency and display formatting preferences.
- Business timezone.
- Default phone-number parsing region.
- Shopify shop and administrative links.
- WhatsApp business account and phone-number mapping.
- Payment and logistics capabilities.
- Versioned shipping, returns, warranty, sizing, discount, privacy, and consent
  policies.
- Customer-facing terminology and approved message templates.
- AI instructions, knowledge sources, feature flags, and cost limits.

Secrets are referenced by profile configuration but remain in the deployment's
secret manager or environment. They are never stored in ordinary settings or
committed to the repository.

## Data isolation

Customers, identities, conversations, messages, opportunities, commerce
sessions, orders, prompts, policies, and integration events belong to a store
profile. Queries and background jobs always carry the store identifier.

Provider identifiers are unique within the relevant store/provider account. A
person appearing in both Colombia and Spain is not silently merged across stores.
Cross-store relationship views may be added later with explicit consent and
auditable matching rules.

## Language and regional behavior

- The Colombia profile starts conversations in natural Colombian Spanish.
- A customer's explicit language preference can override the store default when
  that language is supported by the profile.
- Original messages are preserved; translations never replace evidence.
- Timestamps are persisted in UTC and displayed using the profile timezone.
- Money always carries an ISO currency code; it never relies only on the profile
  default.
- Phone numbers are stored in E.164. The profile region is only a parsing default
  when the customer did not supply an explicit international prefix.
- Addresses use country-aware fields and validation rather than US-specific
  assumptions.

## Colombia default

The seeded profile uses `CO`, `es-CO`, COP, `America/Bogota`, and phone region
`CO`. Its initial commerce context includes Shopify with Mercado Pago, bank
transfer, and TCC cash on delivery where the store makes those options available.

Prices, delivery coverage, fees, payment availability, and promised dates must
come from current store configuration or an authorized integration. The AI must
not infer them from general knowledge about Colombia.

## Adding another store

Opening a Spain operation should require creating a separate store profile,
connecting its provider accounts, loading reviewed policies and content, and
running market-specific evaluation cases. It should not require a long-lived Git
branch or a separate deployment unless operational or regulatory isolation later
justifies that choice.

Before activating any market, the store must validate local privacy, consumer,
commerce, messaging, tax, payment, and retention requirements with appropriate
professional guidance.
