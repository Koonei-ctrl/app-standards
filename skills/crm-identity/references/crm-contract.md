# CRM integration contract

The exact wire contract between a product app and the CRM (`crm_api` +
`crm_saas`). The standard (`standard.md`, WH- / AD- / CI-) says *what* must be
true; this file gives the facts needed to build it. Traced from the CRM code
on 2026-10-07 (commit `5cd3663`). Where the CRM's own developer docs disagree,
this file follows the code.

The operator finds everything below on the product's **Integration** page in
the CRM (`/p/<productId>/playground`): API key, webhook URL + signing secret,
App-data URL, test buttons, delivery log.

---

## 1. Product API key

| Fact | Value |
| --- | --- |
| Format | `crm_live_<32 chars>` or `crm_test_<32 chars>` (41 chars total) |
| Mode | `live` when the product's Stripe key is `sk_live_…`, otherwise `test` |
| Shown | Once, at creation. The CRM stores a SHA-256 hash and an encrypted copy |
| Used for | App → CRM calls (`Authorization: Bearer <key>`) **and** CRM → app App-data calls (the CRM sends the same key) |
| Rotation | "Rotate" issues a new key and revokes every older key **immediately** — no overlap window |
| Rate limit | None |

The key is a server secret. It never goes into a browser bundle, a mobile app
binary, logs or error reports.

## 2. Outbound webhook (CRM → app)

The CRM owns the product's Stripe webhook subscription and forwards **every**
Stripe event it receives for the product to one app URL. The body is the raw
`Stripe.Event` JSON, unchanged, so a handler written for Stripe works once its
signature check is swapped.

### Request

```
POST <app webhook url>
Content-Type: application/json
X-CRM-Signature: t=<unix seconds>,v1=<hex>
X-CRM-Event-Id: <event.id>          # Stripe's own evt_… id
X-CRM-Event-Type: <event.type>
```

### Signature

```
v1 = hex( HMAC_SHA256( key = signing_secret, message = `${t}.${rawBody}` ) )
```

- `signing_secret` is the full string **including** its `whsec_` prefix — do
  not base64-decode it. (Same scheme as Stripe, but Stripe's SDK
  `constructEvent` will not verify it: the header name differs.)
- Compare in constant time. Reject when `|now - t| > 300` seconds (the CRM
  does not enforce this; the receiver must).
- The secret is generated when the operator first saves the URL. Rotating it
  replaces it **immediately** (no grace period).

Reference verification (Node / Bun):

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

### Events

- Every type the CRM subscribes to at Stripe: `customer.*`,
  `customer.subscription.*`, `invoice.*`, `charge.*` (incl. refunds and
  disputes), `checkout.session.*`, `payment_intent.*`, `refund.*`,
  `radar.early_fraud_warning.*`, `payment_method.*`, `promotion_code.*`,
  `coupon.*`. No whitelist per app — the app ignores what it doesn't need.
- One synthetic type: `crm.ping` (from the "Send test ping" button). Shape is
  a Stripe-like event with `data.object.message`, `livemode: false`.
- RevenueCat events are **not** forwarded.

### Delivery and retries

| Response | CRM treats it as |
| --- | --- |
| 2xx within 8 s | `success` — never sent again (unless the operator presses Retry) |
| 5xx, network error, or no answer in 8 s | `retrying` — retried after 4 s, 8 s, 16 s, 32 s, then a sweep every 30 min until 15 attempts or 3 days |
| Any other status (3xx, 4xx) | `failed` — **terminal**, never retried automatically |

- The same `event.id` is sent on every retry, sweep, manual retry and on
  Stripe's own redeliveries. Delivery order is not guaranteed; an event can
  arrive hours late.
- Manual retry from the delivery log resends the same id and body to the
  **current** URL.

### Operator procedure for rotating the secret

Rotation is immediate on the CRM side and signature failures are terminal, so:
rotate in the CRM → put the new secret in the app's env and deploy → open the
delivery log and **Retry** every delivery that failed in between. Apps accept
a list of secrets so the old one can be kept during the switch-over.

## 3. App-data endpoint (CRM → app, read-only)

When an operator opens a transaction or subscriber in the CRM, the CRM calls
the app live to show an "App context" panel. Nothing is stored; no paging.

### Request

```
GET <app-data url>?customerId=…&email=…&customerName=…&subscriptionId=…&chargeId=…&paymentIntentId=…&productSlug=…
Authorization: Bearer <product API key>       # the newest active crm_… key
User-Agent: crm-koonei/1.0 (app-data)
Accept: application/json
```

- At least one of `customerId` / `email` is present. Empty identifiers are
  omitted. `productSlug` is always sent.
- `customerId` is a Stripe customer id (`cus_…`) for web customers, or
  `rc_<app_user_id>` for RevenueCat (mobile) customers.
- Transaction page sends `customerId, email, customerName, chargeId`.
  Subscriber page sends `customerId, email, customerName, subscriptionId`.
- The CRM's test button may add `simulate=ok|timeout|500|404|invalid|nonjson`
  and dummy ids (`cus_test123`, `test@example.com`). Unknown params must be
  ignored.
- URL must be `https://` in production. Timeout: **5 s**.

### Responses

| App returns | CRM shows |
| --- | --- |
| 200 + valid envelope | The panel |
| 404 | "No record" (the normal answer for an unknown customer) |
| Other non-2xx | Upstream error with the status |
| Non-JSON or schema mismatch | `invalid_response` with the failing path |
| No answer in 5 s | Timeout |

### Envelope (validated by the CRM with Zod)

```ts
const Tone = z.enum(["default", "muted", "success", "warning", "danger"]);
const label = z.string().min(1).max(100);
const Field = z.discriminatedUnion("type", [
  z.object({ type: z.literal("text"),     label, value: z.string().max(2000), tone: Tone.optional() }),
  z.object({ type: z.literal("number"),   label, value: z.number(), tone: Tone.optional(), suffix: z.string().max(40).optional() }),
  z.object({ type: z.literal("boolean"),  label, value: z.boolean(), tone: Tone.optional() }),
  z.object({ type: z.literal("date"),     label, value: z.string(), tone: Tone.optional() }),   // ISO date
  z.object({ type: z.literal("datetime"), label, value: z.string(), tone: Tone.optional() }),   // ISO datetime
  z.object({ type: z.literal("badge"),    label, value: z.string().max(80), tone: Tone.optional() }),
  z.object({ type: z.literal("link"),     label, value: z.string().url(), text: z.string().max(120).optional() }),
  z.object({ type: z.literal("code"),     label, value: z.string().max(2000) }),
]);
const Envelope = z.object({
  status: z.object({ label: z.string().min(1).max(40), tone: Tone.optional() }).optional(),
  externalUrl: z.string().url().optional(),      // deep link to the user in the app's own admin
  sections: z.array(z.object({ title: z.string().min(1).max(80), fields: z.array(Field).max(40) })).max(10), // required
  note: z.string().max(2000).optional(),
});
```

Example:

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

## 4. Stripe data the CRM reads

| CRM needs | Where the app puts it |
| --- | --- |
| Customer email (joins guest charges, Syntrix attribution) | `customer.email`; for guest charges `receipt_email` / billing email. Trimmed, lower-case |
| Country | `customer.metadata.country` (then `locale`/`language`, Stripe `preferred_locales`, address). Charges: card country, then `charge.metadata.country` |
| Upsell grouping | `charge.metadata.type = "upsell"` and `charge.metadata.offerId = <offer code>` (key names can be overridden per product in CRM settings: `upsellMarkerKey`, `upsellMarkerValue`, `upsellOfferKey`). Set on the PaymentIntent; confirm the resulting charge carries them |
| Plan / product | `metadata.saas_plan_id`, `saas_product_id` — stamped by the CRM itself on checkout sessions it creates and on plan prices. Apps never set or overwrite `saas_*` keys |

## 5. CRM checkout API (optional)

Apps may create hosted Checkout Sessions through the CRM instead of calling
Stripe directly:

```
POST <CRM_API_URL>/saas/v1/checkout/sessions
Authorization: Bearer crm_live_…
{ "planId": "...", "customerEmail": "...", "successUrl": "https://...", "cancelUrl": "https://...",
  "discountCode": "OPTIONAL", "stripeOverrides": { "metadata": {...}, "subscription_data": { "metadata": {...} } } }
→ 201 { "url", "sessionId" }
```

- 404 unknown plan / discount code; 409 archived plan, inactive code, or no
  Stripe credentials; 400 if `stripeOverrides` contains `line_items` or
  `mode`. Errors are `{ error, details?, requestId? }`.
- `metadata`, `subscription_data`, `payment_intent_data` in
  `stripeOverrides` are merged one level deep; the CRM's own keys win.
- No idempotency-key support: the app must not blindly retry a 5xx/timeout
  into a second session for the same order.

## 6. RevenueCat (mobile apps)

- RevenueCat posts to `POST <CRM_API_URL>/webhooks/revenuecat/<productId>`
  with a fixed `Authorization` header value the operator generates in the CRM
  and pastes into RevenueCat. Configured in the RevenueCat dashboard, not in
  app code.
- The CRM counts only `environment = PRODUCTION`, skips stores in the
  product's excluded list (default `STRIPE`, since web sales come in through
  Stripe directly), and filters to the configured entitlement ids.
- CRM customer id is `rc_<app_user_id>`. With RevenueCat's default anonymous
  ids (`$RCAnonymousID:…`) there is no key to join a mobile subscriber to the
  same person's web (Stripe) record.
- Email: the CRM mapper currently reads a flat `subscriber_attributes_email`
  / `email` field; RevenueCat's standard `$email` attribute arrives nested
  (`subscriber_attributes.$email.value`) and is **not yet read** — a CRM-side
  gap. Apps still set `$email`; it starts working when the CRM is fixed.
