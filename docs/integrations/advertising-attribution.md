# Advertising attribution

## Objective

Relate an advertising touchpoint to a WhatsApp conversation, Shopify cart, and
eventual paid order without guessing when identity cannot be established.

Attribution is optional evidence. Customers may arrive through organic search,
direct visits, referrals, direct WhatsApp contact, organic social content, or an
unknown source. These are valid states and must not be converted into synthetic
campaigns.

Keep acquisition source, conversation entry point, and order channel as separate
fields because they describe different moments in the relationship.

## Data model

```text
campaigns
ad_groups
ads
touchpoints
```

A touchpoint may initially be anonymous. It records platform, external campaign
identifiers, allowed click identifiers, UTM values, landing token, timestamp,
raw metadata, and the time at which customer identity was resolved.

## Meta and Instagram

For click-to-WhatsApp interactions, preserve referral and advertisement metadata
provided with the inbound webhook. Resolve it to the customer after resolving
the WhatsApp identity.

## Google Ads

A practical first-party correlation flow is:

1. Send the ad to a redirect endpoint controlled by the store.
2. Capture allowed campaign parameters.
3. Create a short-lived opaque tracking token.
4. Redirect to WhatsApp with the token in a prefilled message.
5. Extract the token from the first customer message.
6. Connect the touchpoint to the customer and conversation.
7. Carry that touchpoint into the cart correlation record.

If the token is missing or invalid, mark the visit unattributed instead of
inferring a connection.

## Direct and organic purchases

A Shopify order can exist without an advertisement or prior conversation. Record
the best supported source, such as `organic_search`, `direct_shopify`, `referral`,
or `unknown`. Attribution reporting must include unattributed revenue rather than
silently excluding it.

## Initial reporting

Implement first-touch and last-touch attribution first:

- Leads by channel and campaign
- Qualified opportunities
- Carts created
- Paid orders
- Revenue
- Conversion rate
- Cost per acquired customer when spend data is available

Defer custom multi-touch models until there is sufficient volume to justify
them.

## DEL-006 implementation

Inbound WhatsApp referral objects are retained as `meta` touchpoints with
`provider_referral` confidence. Instagram origin remains visible in the original
provider metadata; the application does not infer Instagram from an absent URL.

Configure the store's `agent_limits.acquisition_whatsapp_number` as international
digits, without `+`, to enable `GET /r/:store/google`. The endpoint permits only
UTM fields, `gclid`, `gbraid`, and `wbraid`, creates a one-hour signed opaque token,
and redirects to the configured WhatsApp number. It never accepts a destination
URL from the visitor. A `[gk:...]` token in an inbound message claims that anonymous
touchpoint once for the resolved store/customer/conversation. Expired, altered,
foreign-store, and replayed tokens cannot claim another customer's evidence.
The `google` source describes this campaign entry route; `redirect_token`
confidence is first-party correlation evidence, not independent validation of a
Google ad click or campaign spend.

`/crm/orders` offers first- and last-touch paid-order count and gross revenue by
source, separated by currency. Each order exposes both touchpoints, their IDs,
timestamps, confidence, and underlying metadata. Only touchpoints preceding the
order are eligible. Identity conflicts suppress attribution; missing evidence is
explicitly unknown and remains in report totals. Gross paid revenue includes
subsequently cancelled/refunded orders; refund amounts are shown separately.
No campaign spend or cost-per-acquisition is invented.


The Admin **Pedidos y atribución** panel now manages the campaign WhatsApp number
and displays a Google campaign-link template after it is saved. Use a number
connected to this CRM's Meta Cloud API account so the inbound token can resolve.
Admin also shows total Google redirect visits, those associated with customers,
and received Meta referral records. These are evidence counts, not verified ad
spend or distinct-person counts. Purchase attribution remains in `/crm/orders`.


Native WhatsApp orders use their explicitly selected conversation/customer as
purchase identity evidence. They participate in the same first-/last-touch
reports as Shopify purchases without a cart or Shopify order. The channel stays
`whatsapp`; bank transfer and COD are payment methods, not acquisition sources.
Confirmed unpaid COD sales remain visible as orders but enter paid-revenue
reporting only when a manager records receipt of funds.
