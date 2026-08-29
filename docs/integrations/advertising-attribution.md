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
