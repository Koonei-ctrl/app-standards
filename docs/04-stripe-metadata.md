# 4. Stripe metadata

Every Stripe object carries the same eight metadata keys. This is how a
Stripe row is matched to our own order, how the CRM shows country and
groups upsells, and how support finds the user.

## The eight keys

Every value is a **string**. A missing value is `""`, never `"undefined"` or
`"null"` (MD-03).

| Key | Holds | Example |
| --- | --- | --- |
| `appUserId` | The app's user id, minted **before** checkout | `"u_8f2k1"` |
| `orderId` | The app's id for this purchase attempt | `"ord_51x9"` |
| `plan` | Neutral plan code | `"P2"` |
| `shape` | `upfront`, `free-trial` or `paid-trial` | `"free-trial"` |
| `country` | Market charged, ISO-3166 alpha-2 | `"DE"` |
| `language` | Locale the buyer was reading | `"de"` |
| `ipAddress` | Leftmost `x-forwarded-for` entry, or a verified CDN header | `"203.0.113.7"` |
| `funnelSessionId` | Funnel session that led here, or `""` | `"fs_a1b2"` |

- **`country`** is the market whose price was charged, not a guess from the
  IP (MD-07). The CRM's country reports read `customer.metadata.country`.
- **`ipAddress`** comes from the leftmost `x-forwarded-for` entry, or the CDN's
  verified client-IP header (MD-06). The server purchase sends it to Syntrix.
- If the app has no funnel, `funnelSessionId` is still sent, as `""`.

## Which object gets which keys (MD-02)

| Stripe object | Keys |
| --- | --- |
| Customer | All except `shape` |
| Subscription | All eight |
| PaymentIntent / SetupIntent | All except `shape`, **plus** `subscriptionId` |
| Checkout Session (hosted) | All eight, on `metadata` **and** `subscription_data.metadata` |
| Upsell PaymentIntent | As a PaymentIntent, **plus** `type: "upsell"` and `offerId` |

This applies on **every** checkout path: hosted, built-in, wallet, upsells,
and checkout created through the CRM API. Missing a path is the most common
mistake.

## How to build it

1. Before the first Stripe call, make sure `appUserId` and `orderId` exist.
   If they don't, mint the app's own ids. Don't create Stripe objects early
   just to get ids.
2. Build the metadata object **once** per checkout, in one function, from
   named fields.
3. Reuse it on every Stripe object. Add `shape` on the subscription and
   session, and `subscriptionId` on the intent once the subscription exists.

```ts
// Example shape only. Build it in your app's own conventions.
const metadata = {
  appUserId: user.id,
  orderId: order.id,
  plan: plan.code,              // "P2", never a descriptive name
  country: market.country,      // market charged
  language: locale,
  ipAddress: clientIp(req),     // leftmost x-forwarded-for
  funnelSessionId: funnelSessionId ?? "",
};

stripe.customers.create({ email, metadata });
stripe.subscriptions.create({ ..., metadata: { ...metadata, shape } });
```

## Upsells (MD-08)

One-click and post-purchase upsell charges must carry, on the PaymentIntent:

- `type: "upsell"`
- `offerId: "<neutral offer code>"`, e.g. `o1` or `upsell-2`, never a
  product or condition name.

The CRM uses these to group the upsell with its main order. Main charges
**never** carry `type: "upsell"`. A product can override these key names in
CRM settings; if it does, use those.

## CRM checkout API

If the app creates hosted checkout through the CRM
(`POST /saas/v1/checkout/sessions`), put the same keys in **both**
`stripeOverrides.metadata` and `stripeOverrides.subscription_data.metadata`.
Never set or overwrite `saas_*` keys. The CRM owns them. See
[CRM integration](05-crm-integration.md#checkout-through-the-crm-api-optional).

## Never in metadata (MD-04, Critical)

Funnel answers, goals, symptoms, scores, health data, or descriptive plan
names. Stripe metadata is visible to anyone with dashboard access and flows
into the CRM. Keep that data in the app's own database.

## Changing keys safely

If the webhook already reads a key, don't rename it without updating the
webhook in the same change. Keep reading the old key until no existing
subscription depends on it.

## Test (MD-05)

One test per checkout path that asserts:

- the **exact, sorted key set** on each Stripe call (upsell intents: the set
  plus `type` and `offerId`);
- no value is `undefined` or `"undefined"`.

Then check in the Stripe dashboard (test mode) that a new customer,
subscription and intent each show the keys.

## Requirements

| ID | Requirement | Severity |
| --- | --- | --- |
| MD-01 | All eight keys present | High |
| MD-02 | Keys on every Stripe object per the table, on every checkout path | High |
| MD-03 | Every value a string; missing = `""` | Medium |
| MD-04 | No funnel answers, goals, symptoms, scores or other sensitive data | Critical |
| MD-05 | A test asserts the exact key set | Medium |
| MD-06 | `ipAddress` = leftmost `x-forwarded-for` entry, or a verified CDN header | Medium |
| MD-07 | `country` = the market charged, not an IP guess | Medium |
| MD-08 | Upsell charges carry `type: "upsell"` and `offerId`; other charges never carry `type: "upsell"` | High |

**Skill:** `stripe-metadata` checks and fixes this.
