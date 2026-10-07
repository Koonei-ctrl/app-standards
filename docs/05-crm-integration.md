# 5. CRM integration

Every product is connected to the CRM. Three connections, each with its own
rules:

| Connection | Direction | What it does | IDs |
| --- | --- | --- | --- |
| [Webhook receiver](#webhook-receiver) | CRM → app | The CRM forwards every Stripe event for the product, signed | WH |
| [App-data endpoint](#app-data-endpoint) | CRM → app | The CRM asks the app for live context when support opens a customer | AD |
| [Customer identity](#customer-identity) | App → Stripe / RevenueCat | The app records the ids the CRM needs to join one person's records | CI |

Everything an operator needs is on the product's **Integration** page in the
CRM: API key, webhook URL and signing secret, App-data URL, test buttons and
the delivery log.

## Product API key

| Fact | Value |
| --- | --- |
| Format | `crm_live_<32 chars>` or `crm_test_<32 chars>` |
| Mode | `live` when the product's Stripe key is live, otherwise `test` |
| Shown | Once, when created |
| Used for | App → CRM calls **and** CRM → app App-data calls (the same key) |
| Rotation | Revokes every older key **immediately**, with no overlap |

It's a server secret. It never goes into a browser bundle, a mobile app,
logs or error reports. Use separate env vars per environment, and never a
`crm_test_` key in production (CI-07).

---

## Webhook receiver

The CRM owns the product's Stripe webhook and forwards **every** Stripe event
to one app URL. The body is the raw Stripe event JSON, unchanged. Only the
signature header differs.

### Request

```
POST <app webhook url>
Content-Type: application/json
X-CRM-Signature: t=<unix seconds>,v1=<hex>
X-CRM-Event-Id: <Stripe evt_… id>
X-CRM-Event-Type: <event type>
```

### Verifying the signature (WH-01, WH-02)

```
v1 = hex( HMAC_SHA256( key = signing_secret, message = `${t}.${rawBody}` ) )
```

- The secret is the full string **including** `whsec_`. Don't base64-decode
  it.
- Stripe's SDK (`stripe.webhooks.constructEvent`) **can't** verify this. It
  expects a `Stripe-Signature` header and always fails.
- Verify the **raw body**, before `JSON.parse`. A re-serialised body won't
  match.
- Compare in constant time. Reject a timestamp more than 5 minutes off. The
  CRM doesn't check this; the app must.
- Accept a **list** of secrets from env (current + previous), so rotation
  needs no code change (WH-09).

```ts
import { createHmac, timingSafeEqual } from "node:crypto";

export function verifyCrmSignature(rawBody: string, header: string | null, secrets: string[], toleranceSec = 300): boolean {
  if (!header) return false;
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=", 2) as [string, string]));
  const t = Number(parts.t);
  if (!Number.isFinite(t) || Math.abs(Date.now() / 1000 - t) > toleranceSec) return false;
  const given = Buffer.from(parts.v1 ?? "", "hex");
  return secrets.some((secret) => {
    const expected = createHmac("sha256", secret).update(`${t}.${rawBody}`).digest();
    return given.length === expected.length && timingSafeEqual(given, expected);
  });
}
```

### What the receiver does

1. Read the raw body as text. Verify. Bad or missing signature, or a stale
   timestamp → **400/401**, nothing written.
2. `crm.ping`, unknown event types, or a `livemode` that doesn't match the
   environment → **200**, nothing written (WH-06, WH-08).
3. Claim `event.id` atomically. Already claimed → **200**. The claim is
   shared with any direct Stripe webhook, because the ids are identical
   (WH-03).
4. Record the event durably, return **200**, process it in a queue or after
   the response (WH-04). The CRM waits 8 seconds at most.
5. Transient failure (database down, Stripe timeout) → **5xx**, and release
   the claim so the retry can process it.
6. A valid event the app can't act on (unknown customer, order already
   cancelled) → log it and return **200**. Retrying won't change anything.

### Status codes and retries (WH-05)

| App returns | CRM does |
| --- | --- |
| 2xx within 8 s | Success. Never sent again (unless an operator presses Retry) |
| 5xx, network error, or no answer in 8 s | Retries after 4, 8, 16 and 32 s, then every 30 min, up to 15 attempts or 3 days |
| 3xx or 4xx | **Failed, terminal.** Never retried automatically |

So: **2xx** for processed, duplicate, ignored and ping. **5xx** only for
transient failures. **4xx** only for a bad signature or malformed body.

### Late and out-of-order events (WH-07)

Events can arrive hours late, in any order. For subscription state, compare
the event against what's stored (status, `current_period_end`, the event's
`created`), or re-fetch the subscription from Stripe, before writing. Never
apply an event blindly.

### Rotating the secret

Rotation in the CRM is immediate, and signature failures are terminal. So:

1. Rotate in the CRM.
2. Add the new secret to the app's env list (keep the old one) and deploy.
3. In the CRM delivery log, **Retry** every delivery that failed in between.
4. Later, remove the old secret.

### Tests (WH-10)

Sign test bodies with the same HMAC. Cover: a valid signature, a wrong
secret, the previous secret still accepted, a stale timestamp, a duplicate id
processed once, `crm.ping`, and an unknown type.

### Going live

1. Save the URL on the product's Integration page. Copy the `whsec_…` secret
   into the app's env.
2. Press **Send test ping**. The delivery log shows 2xx.
3. Make one test-mode purchase. The log shows `checkout.session.completed`
   2xx and access is granted.
4. Press **Retry** on that delivery. Nothing is processed twice.
5. If the app had a direct Stripe webhook, remove it in the Stripe dashboard
   **only after** the relay is verified.

---

## App-data endpoint

When an operator opens a transaction or subscriber, the CRM calls the app
live and shows an **App context** panel. Nothing is stored. Every app with
user accounts has this endpoint.

### Request

```
GET <app-data url>?customerId=…&email=…&customerName=…&subscriptionId=…&chargeId=…&productSlug=…
Authorization: Bearer <newest active crm_… key>
Accept: application/json
```

- `customerId` is `cus_…` for web customers, or `rc_<app_user_id>` for
  RevenueCat (mobile) customers.
- At least one of `customerId` or `email` is sent. Empty values are left out.
- The CRM's **Test** button may add `simulate=…` and dummy ids. Ignore any
  parameter you don't use (AD-05).
- HTTPS in production. **Timeout: 5 seconds.**

### What the endpoint does

1. **Auth (AD-01):** compare the bearer key in constant time against a list
   of keys from env. Anything else → **401**, empty body. The CRM always
   sends its newest key, so a newly created key must work right away. Never
   accept the key from a query string or cookie.
2. **Find the user (AD-02):**
    - `customerId` starts with `cus_` → the stored Stripe customer id;
    - starts with `rc_` → strip the prefix, look up the RevenueCat app user
      id;
    - otherwise `email`, trimmed and case-insensitive;
    - nothing found → **404**. Not 200 with empty data, not 500.
3. **Respond (AD-03):** JSON in the CRM's envelope, built in one function.
4. Indexed lookups only. No calls to Stripe, RevenueCat or anything else
   (AD-04). Read-only, and never cached across users (AD-07).
5. Exclude the route from session auth, CSRF, bot protection and locale
   redirects (AD-08).

| App returns | CRM shows |
| --- | --- |
| 200 + valid envelope | The panel |
| 404 | "No record" (normal for an unknown customer) |
| Other non-2xx | An upstream error |
| Non-JSON or wrong shape | `invalid_response` |
| No answer in 5 s | Timeout |

### Response envelope

```json
{
  "status": { "label": "Active", "tone": "success" },
  "externalUrl": "https://admin.example.com/users/u_123",
  "sections": [
    { "title": "Account", "fields": [
      { "type": "text", "label": "User id", "value": "u_123" },
      { "type": "datetime", "label": "Signed up", "value": "2026-09-01T10:00:00Z" },
      { "type": "badge", "label": "Plan", "value": "P2", "tone": "default" }
    ]},
    { "title": "Usage", "fields": [
      { "type": "number", "label": "Sessions (30d)", "value": 14 },
      { "type": "boolean", "label": "Onboarding done", "value": true }
    ]}
  ]
}
```

- `sections` is required: at most 10 sections, 40 fields each.
- Field types: `text`, `number`, `boolean`, `date`, `datetime`, `badge`,
  `link`, `code`.
- Limits: label ≤ 100, text ≤ 2000, badge ≤ 80 characters. Dates are ISO
  strings.
- Tones: `default`, `muted`, `success`, `warning`, `danger`.
- The full Zod schema is in
  [`crm-contract.md` §3](../references/crm-contract.md). Copy it into the
  endpoint's tests (AD-09).

### What to show (AD-06, Critical)

| Show | Never show |
| --- | --- |
| Account status, user id, signup date, last active, locale | Passwords, tokens, keys |
| Subscription status, plan **code**, renews or ends on | Full payment details |
| A few usage counts | Funnel answers, goals, symptoms, health data |
| A link to the user in the app's admin | Anything the user typed in free text |

Agree on 2–4 sections per app before building.

---

## Customer identity

The CRM joins one person's web (Stripe), mobile (RevenueCat) and tracking
records. It can only do that if the app records the right ids.

| ID | The app must… | Why |
| --- | --- | --- |
| CI-01 | Set `email` (trimmed, lower-case) on every Stripe customer; on guest payments, set `receipt_email` | The CRM joins guest charges and Syntrix data by email |
| CI-02 | Store the Stripe customer id on its user record, indexed | `cus_…` App-data lookups resolve |
| CI-03 | Mobile: call RevenueCat `logIn(appUserId)` (the same `appUserId` as in Stripe metadata) once the user is known and **before** any purchase; `logOut()` on sign-out | Anonymous RevenueCat ids can never be joined to the web record |
| CI-04 | Mobile: set the RevenueCat `$email` attribute at login | Lets the CRM match mobile customers by email |
| CI-05 | RevenueCat posts to the CRM webhook with the CRM-generated auth value, and production entitlement ids are entered in the CRM | Mobile subscriptions show in the CRM |
| CI-06 | Use the CRM checkout API correctly (below) | Orders and metadata line up |
| CI-07 | Separate CRM key and webhook secret per environment; never a test key in production | Live data stays live |

- Never use the email as the RevenueCat app user id.
- If a purchase can happen before an account exists, mint `appUserId` first,
  the same rule as for Stripe metadata.
- These fixes only help customers created **after** the change. Existing
  records stay unjoined unless backfilled.

**Known CRM-side gaps** (the app should still do the above):

- The CRM doesn't yet read RevenueCat's nested `$email` attribute.
- It doesn't yet merge `rc_<appUserId>` with the Stripe customer carrying the
  same `metadata.appUserId`.

### Checkout through the CRM API (optional)

```
POST <CRM_API_URL>/saas/v1/checkout/sessions
Authorization: Bearer crm_live_…

{ "planId": "...", "customerEmail": "...", "successUrl": "https://...", "cancelUrl": "https://...",
  "discountCode": "OPTIONAL",
  "stripeOverrides": { "metadata": {...}, "subscription_data": { "metadata": {...} } } }

→ 201 { "url", "sessionId" }
```

- Call it from the **server**, with the `crm_` key.
- Pass `customerEmail`.
- Put the eight [metadata keys](04-stripe-metadata.md) in **both**
  `stripeOverrides.metadata` and `stripeOverrides.subscription_data.metadata`.
- Never set `saas_*` keys. The CRM stamps those itself.
- There's no idempotency key. On a timeout or 5xx, look the order up instead
  of blindly creating a second session.
- Errors: 404 unknown plan or code; 409 archived plan, inactive code or no
  Stripe credentials; 400 if the overrides contain `line_items` or `mode`.

## Requirements

| ID | Requirement | Severity |
| --- | --- | --- |
| WH-01 | One receiver route; verifies `X-CRM-Signature` on the raw body before parsing; rejects failures with no side effects | Critical |
| WH-02 | Timestamps more than 5 minutes off are rejected | High |
| WH-03 | Each `event.id` processed once, shared with any direct Stripe endpoint | Critical |
| WH-04 | Answers 2xx within 8 s; slow work runs after a durable record | High |
| WH-05 | Status codes follow the CRM's retry rules | High |
| WH-06 | Unknown types and `crm.ping` get 2xx with no side effects | Medium |
| WH-07 | Correct when events are late (up to 3 days) or out of order | High |
| WH-08 | Events whose `livemode` doesn't match the environment are acknowledged and ignored | Medium |
| WH-09 | Signing secret read from server env, as a list | Medium |
| WH-10 | Tests: valid, bad signature, stale timestamp, duplicate, ping, unknown type | Medium |
| AD-01 | Bearer `crm_…` key, constant-time compared against an env list; otherwise 401 | Critical |
| AD-02 | Lookup by `cus_`, then `rc_`, then email; 404 when not found | High |
| AD-03 | Response matches the CRM envelope exactly; built in one function | High |
| AD-04 | Well inside 5 s: indexed lookups, no third-party calls | High |
| AD-05 | Ignores unknown query parameters | Medium |
| AD-06 | Only support and billing data; nothing sensitive | Critical |
| AD-07 | Read-only, not cached across users | Medium |
| AD-08 | HTTPS; excluded from session auth, CSRF and bot protection | Medium |
| AD-09 | Tests: 401, 404, lookup by `cus_`, `rc_` and email, schema validation | Medium |
| CI-01 – CI-07 | See [Customer identity](#customer-identity) | High / Medium |

**Skills:** `crm-webhook`, `crm-app-data` and `crm-identity` build and fix
these.
