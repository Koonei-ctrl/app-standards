---
name: stripe-metadata
description: Make any app send the company-standard Stripe metadata — the same eight keys (appUserId, orderId, plan, shape, country, language, ipAddress, funnelSessionId) on the customer, subscription, payment/setup intent and checkout session, on every checkout path (including checkout created through the CRM API), as strings, with nothing sensitive, upsell charges marked type/offerId for the CRM, and a test that locks the key set. Use when asked to "fix Stripe metadata", "add metadata to Stripe", "match Stripe rows to our orders", "metadata missing on subscription", or after `tracking-audit` reports MD- gaps.
---

# Stripe metadata

Brings an app to the standard's **MD** requirements. Works in any stack.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the Stripe metadata
  section and the MD table.
- Discovery guide: `references/discovery.md` (sections 1, 4, 6 are
  enough).

## Steps

1. **Discover** every place the app creates a Stripe customer, subscription,
   payment/setup intent or checkout session — on **every** checkout path
   (hosted and built-in, plus checkout created through the CRM API
   `/saas/v1/checkout/sessions`, and upsell / one-click PaymentIntents).
   Missing one path is the most common failure.

2. **Check** MD-01 … MD-08 per path and per Stripe object. Show a matrix:
   object × path → keys present / missing / wrong.

3. **Plan** and **ask the user to confirm** before editing. Resolve with them:
   - Where each value comes from in this app (user id, order id, market
     country, locale, funnel session id). If the app has no concept for one
     (e.g. no funnel), the key is still sent as `""`.
   - Whether `appUserId` / `orderId` exist before checkout. If not, the plan
     includes minting them before the first Stripe call, and storing them in
     the app's own pending-order record. Any schema change follows the repo's
     migration rules (additive only, unless the repo says otherwise).

4. **Implement:**
   - Build the metadata object **once** per checkout and reuse it on every
     Stripe object, adding `shape` on the subscription (and checkout session)
     and `subscriptionId` on the intent once the subscription exists.
   - Hosted checkout: set it on both the session's `metadata` and
     `subscription_data.metadata`. Through the CRM API, the same two places
     inside `stripeOverrides`; never set `saas_*` keys (the CRM owns them).
   - Upsell PaymentIntents also get `type: "upsell"` and `offerId` (MD-08),
     or the marker keys configured for the product in the CRM.
   - Every value a string; missing → `""` (MD-03). `ipAddress` from the
     leftmost `x-forwarded-for` entry, or the CDN header the app is behind
     (MD-06). `country` is the market whose price was charged (MD-07).
   - Move anything sensitive currently in metadata (answers, goals, scores,
     descriptive plan names) into the app's own database (MD-04). Neutral plan
     codes only.
   - Do not rename keys the webhook already reads without updating the
     webhook in the same change, and keep reading the old key until existing
     subscriptions no longer depend on it.

5. **Test (MD-05).** Add a test per checkout path asserting the exact sorted
   key set on each Stripe call (upsell intents: the set plus `type` and
   `offerId`), and that no value is `undefined`/`"undefined"`.
   Run lint, type-check and tests; report failures verbatim.

6. **Verify and report:** before → after matrix. Tell the user to confirm in
   the Stripe dashboard (test mode) that a new customer, subscription and
   intent each show the keys, with no `"undefined"` values.

## Do not

- Put funnel answers, goals, symptoms or anything sensitive in metadata.
- Create Stripe objects earlier than before just to have ids — mint the app's
  own ids instead.
- Touch live-mode keys or data.
