# App Tracking, Payment & CRM Integration Standard

The requirements every app must meet. Shared by the `tracking-audit`,
`syntrix-setup`, `stripe-metadata`, `payment-standard`, `crm-webhook`,
`crm-app-data`, `crm-identity`, `syntrix-guide`, `syntrix-debug` and
`syntrix-reports` skills.

**Common to every app:** Stripe (payments), Syntrix (ad-conversion tagging)
and the CRM (every product is connected to it). Wire-level CRM facts —
headers, signing, payload shapes, timeouts — live in `crm-contract.md`;
Syntrix's (host, keys, tracker, S2S, hold, dedup) in
`syntrix-contract.md`.
**Varies per app:** framework, backend, database, URLs, funnel, plans, prices.
Requirements say *what* must be true, never *how* to build it. Page names
describe the role a page plays; each app maps them to its own URLs.

Severity: **Critical** = loses money, loses attribution of real sales, or is a
legal/privacy breach. **High** = corrupts reporting or breaks a flow for some
users. **Medium** = hygiene that prevents future breakage.

---

## Page roles

| Role | Meaning |
| --- | --- |
| Landing page | Where ads and organic links point |
| Funnel | Quiz, questionnaire or onboarding before the paywall |
| Paywall | Shows plans and prices after the funnel |
| Offer page | A landing page with checkout built in (no funnel first) |
| Success page | Shown after payment |
| Logged-in app | The product itself |

A page address is **neutral** if it reveals nothing about why the visitor is
there (e.g. `/start/step-3`). It is **revealing** if it names a topic,
condition, goal or answer (e.g. `/quiz/<condition>/<question>`).

---

## Two pipelines

| | Ad conversions (Syntrix) | Product analytics (app's own) |
| --- | --- | --- |
| Reaches | Meta, GA4, TikTok, Google Ads, Klaviyo via Syntrix | The app's own database only |
| May carry | email, transaction id, value, currency, Stripe customer id, country, step number, recovery fields | step numbers, question ids, answer positions, plan, goals |

Syntrix does by itself (apps must NOT build these): capturing ad click ids,
UTMs and referrer; visitor cookie and browser id; automatic `page_view` with
the URL on load and on client-side navigation; hashing email per destination;
dedup of `purchase` by `transaction_id` (and browser `begin_checkout` by
session). Every server event is held ~5 minutes before processing, so the
browser `purchase` normally lands first and wins; the first stored copy wins
and later copies are dropped.

Syntrix does **not**: create the `stxq` command stub, fire `session_start`,
or handle consent. Those are the app's job (EV-01, EV-12, EV-15).

---

## Event flows

### Flow A — landing → funnel → paywall → hosted checkout

| # | Moment | Event | Data | Once per |
| --- | --- | --- | --- | --- |
| 1 | Lands on any tracked page | `session_start` (custom) | none | Browser session |
| 2 | First funnel screen shown | `funnel_started` (custom) | none | Funnel session |
| 3 | Each funnel step completed | `funnel_step_completed` (custom) | `step` | Step per funnel session |
| 4 | Email submitted in the funnel | `generate_lead` | `email` | Funnel session |
| 5 | Last funnel step completed | `funnel_completed` (custom) | none | Funnel session |
| 6 | Paywall shows **prices** | `begin_checkout` | `email`, `checkoutUrl` | Funnel session |
| 7 | Success page loads | `purchase` (browser) | `transaction_id`, `value`, `currency`, `email` | Transaction id, ever |
| 8 | Stripe confirms to server | `purchase` (server) | + `externalId`, `country` | Transaction id, ever |

Steps 2–5 only when funnel addresses are neutral. If revealing: the tracker
stays out of the funnel, steps 2/3/5 are skipped, and `generate_lead` fires at
step 6 together with `begin_checkout`. If the funnel shows no prices (e.g. a
referral/contraindication outcome), steps 6–8 do not happen.

### Flow B — offer page with checkout built in

| # | Moment | Event | Data | Once per |
| --- | --- | --- | --- | --- |
| 1 | Lands | `session_start` | none | Browser session |
| 2 | Email **submitted** in checkout form, before the payment request | `begin_checkout` | `email`, `checkoutUrl` | Browser session |
| 3 | Payment confirms on the page | `purchase` (browser) | `transaction_id`, `value`, `currency`, `email` | Transaction id, ever |
| 4 | Stripe confirms to server | `purchase` (server) | as Flow A step 8 | Transaction id, ever |

No `generate_lead`. A funnel run after payment fires no further Syntrix events
and does not fire `purchase` again.

### Flow C — Apple Pay / Google Pay

| # | Moment | Event | Data | Once per |
| --- | --- | --- | --- | --- |
| 1 | Wallet sheet opens | `begin_checkout` | `email` if known, `checkoutUrl` | Browser session (shared with card form) |
| 2 | Sheet returns paid | `purchase` (browser) | `transaction_id`, `value`, `currency`, `email` from the sheet | Transaction id, ever |
| 3 | Stripe confirms to server | `purchase` (server) | as Flow A step 8 | Transaction id, ever |

### Flow D — abandoned-checkout recovery link

| # | Moment | Event | Data |
| --- | --- | --- | --- |
| 1 | Recovery link reopens paywall | `cart_recovery_opened` | `email`, `recovery_source`, `recovery_campaign_id` |
| 2 | Paywall shows prices | `begin_recovery_checkout` **instead of** `begin_checkout` | `email`, `checkoutUrl` |
| 3 | Payment | `purchase` browser + server | as Flow A |

### Product analytics events (app's own pipeline)

`landing_viewed`, `funnel_started`/`quiz_started`, `quiz_question_answered`
(question id, answer **position**, step, time on screen), `quiz_completed`,
`email_captured`, `result_viewed`, `paywall_viewed` (when prices render),
`checkout_started`, `subscription_activated` (server), `subscription_cancelled`
(server), `first_session_completed` (activation).

---

## Allowed Syntrix fields

| Field | Format | Events | Rule |
| --- | --- | --- | --- |
| `email` | plaintext, lower-case | `generate_lead`, `begin_checkout`, every `purchase` | Never hashed. Mandatory on every browser `purchase` |
| `transaction_id` | Stripe **subscription** id | `purchase` | Identical on browser and server copies. Never order id / checkout session id |
| `value` | number, major units | `purchase` | Amount **charged today** (0 free trial, intro price for intro offers) |
| `currency` | ISO-4217 upper-case | `purchase` | Same as the charge |
| `checkoutUrl` | link back to checkout | `begin_checkout`, `begin_recovery_checkout` | Expiring, no personal or sensitive data |
| `externalId` | Stripe customer id | server `purchase` | |
| `country` | ISO-3166 alpha-2 | server `purchase` | Market charged |
| `step` | integer, 1-based | `funnel_step_completed` | Position only |
| `recovery_source`, `recovery_campaign_id` | text | `cart_recovery_opened` | |

Never: plan names, product names, `items`/`content_ids`, real page URL (server
`sourceUrl` is a fixed constant), goals, answers, categories, question ids.

Placement: in the browser every field goes in the `stxq('track', name, data)`
data object; on the server `email`, `externalId`, `country` (and the buyer's
`ipAddress`) go in `userData`, the rest in `eventData`
(`syntrix-contract.md` §3–4).

---

## Stripe metadata

Eight keys, every value a string, missing = `""`.

| Key | Holds |
| --- | --- |
| `appUserId` | App's user id, minted before checkout |
| `orderId` | App's id for this purchase attempt |
| `plan` | Neutral plan code |
| `shape` | `upfront` \| `free-trial` \| `paid-trial` |
| `country` | Market charged, ISO-3166 alpha-2 |
| `language` | Locale the buyer was reading |
| `ipAddress` | Leftmost `x-forwarded-for` entry (or verified CDN header) |
| `funnelSessionId` | Funnel session that led to the purchase, or `""` |

| Stripe object | Keys |
| --- | --- |
| Customer | all except `shape` |
| Subscription | all eight |
| PaymentIntent / SetupIntent | all except `shape`, plus `subscriptionId` |
| Checkout Session (hosted) | all eight on `metadata` **and** `subscription_data.metadata` |

---

## Requirements

### Events — EV

| ID | Requirement | Severity |
| --- | --- | --- |
| EV-01 | `session_start` fires once per browser session on every tracked page | High |
| EV-02 | Funnel events (`funnel_started`, `funnel_step_completed`, `funnel_completed`) fire only when funnel addresses are neutral; otherwise the tracker is absent from the funnel | Critical if tracker runs on revealing URLs |
| EV-03 | `generate_lead` fires at the Flow A moment (funnel email submit, or paywall price render when funnel is untracked), browser only, with `email` | High |
| EV-04 | `begin_checkout` fires at the moment defined for each flow (A: prices render; B: email submit before payment request; C: wallet sheet opens), browser only, once per session, with `email` and `checkoutUrl` | High |
| EV-05 | Browser `purchase` fires at every place a payment can complete (success page, in-page card confirm, wallet), once per transaction id ever, with `transaction_id` = subscription id, `value` charged today, `currency`, `email` | Critical |
| EV-06 | Server `purchase` is sent from the Stripe webhook for **every** checkout path (hosted and built-in), with the same `transaction_id`/`value`/`currency` as the browser copy | Critical |
| EV-07 | Recovery: `cart_recovery_opened` and `begin_recovery_checkout` (instead of `begin_checkout`); recovery token removed from the address before the tracker loads | Medium |
| EV-08 | No event other than `purchase` has a server copy | High |
| EV-09 | Syntrix events carry only the allowed fields; payload built in one place from named fields, covered by a test | Critical |
| EV-10 | A tracking failure can never block or break a payment or the page after it | Critical |
| EV-11 | Tracker never loads in the logged-in app or on revealing URLs; moving into/out of tracked pages is a full page load (the tracker reports client-side navigations) | Critical |
| EV-12 | Calls made before the Syntrix script finishes loading are not lost: the standard `stxq` stub is defined before any call (Syntrix drains `stxq.q` but does not create the stub), or calls wait for the script | High |
| EV-13 | No app-built attribution capture (click ids, UTMs, `_fbc`/`_fbp`, referrer) — Syntrix does it | Medium |
| EV-14 | Email sent plaintext to Syntrix, never pre-hashed | High |
| EV-15 | A recorded consent refusal suppresses both browser and server Syntrix events — Syntrix has no consent API, so the app does not load the tracker and does not call the relay | Critical (EU) |
| EV-16 | Product analytics is a separate pipeline, never forwarded to Syntrix; fires after the action is saved; stores ids/positions, never answer text | Critical |

### Syntrix configuration — SX

| ID | Requirement | Severity |
| --- | --- | --- |
| SX-01 | Tracker script and ingest API use the account's own Syntrix host, confirmed with the operator (production: `https://tracker.trysyntrix.app`; the vendor guide's `api.syntrix.com` does not exist). The relay posts to `<host>/track/s2s`, not under `/api/v1` | Critical |
| SX-02 | Browser and relay use the store's public key (`data-api-key`, `X-API-Key`); the relay reads it from server env. The store secret never reaches a browser or mobile binary | Critical |
| SX-03 | A production build/deploy fails if the browser key is missing where the framework inlines it at build time | High |
| SX-04 | Server relay treats 202 as success, retries 5xx / 429 / network errors a few times within a total time budget, never retries 4xx, never throws into the webhook, records failures, and is fully off when its key is unset | High |

### Payments — PAY

| ID | Requirement | Severity |
| --- | --- | --- |
| PAY-01 | Access is granted only from a verified Stripe event — received from the CRM relay (WH-) or the app's own Stripe endpoint — never from the success redirect, a client callback or the checkout response | Critical |
| PAY-02 | Webhook verifies the signature against the raw request body (`Stripe-Signature` on a direct Stripe endpoint, `X-CRM-Signature` on the CRM relay) | Critical |
| PAY-03 | Each Stripe event is processed once even if delivered twice, concurrently, or through both the CRM relay and a direct Stripe endpoint (atomic claim on the Stripe event id / pending order) | Critical |
| PAY-04 | The fulfilment handler handles `checkout.session.completed`, `customer.subscription.created/updated/deleted`, `setup_intent.succeeded` | Critical |
| PAY-05 | No Stripe customer/subscription is created until every rejection check has passed (existing account, bad promo, plan not sold in market) | High |
| PAY-06 | Card, Link, Apple Pay, Google Pay offered. Wallet uses the **merchant** country, checks availability per wallet, asks no billing address, and wallet setup errors cannot break the card form | High |
| PAY-07 | Charge is in the currency of the quoted price (Stripe adaptive/automatic currency conversion off) | High |
| PAY-08 | Plan types `upfront`, `free-trial`, `paid-trial` supported; the client branches on what the server returns (payment vs setup), never on the plan name | High |
| PAY-09 | Free trial: the saved card becomes the subscription's default payment method; trial cancels if no card | Critical |
| PAY-10 | Intro discounts apply to `upfront` plans only | Critical |
| PAY-11 | A trial plan with no trial length is rejected when configured | High |
| PAY-12 | Statement descriptor and product names are explicit and neutral | High |
| PAY-13 | Success page handles the gap before the webhook lands without granting access itself; any unauthenticated receipt lookup returns only transaction id, value, currency, email, for a recent paid session | Medium |

### Metadata — MD

| ID | Requirement | Severity |
| --- | --- | --- |
| MD-01 | All eight keys present | High |
| MD-02 | Keys placed on every Stripe object per the table, on **both** checkout paths | High |
| MD-03 | Every value a string; missing = `""` (never `"undefined"`/`"null"`) | Medium |
| MD-04 | No funnel answers, goals, symptoms, scores or other sensitive data in metadata | Critical |
| MD-05 | A test asserts the exact key set | Medium |
| MD-06 | `ipAddress` is the leftmost `x-forwarded-for` entry (or a verified CDN header) | Medium |
| MD-07 | `country` is the market charged as quoted, not a guess from IP (the CRM reads `customer.metadata.country` for its country reports) | Medium |
| MD-08 | Every upsell charge carries `type: "upsell"` and `offerId: <neutral offer code>` (or the product's configured keys) on the PaymentIntent, so the charge shows them and the CRM groups it with the main order; non-upsell charges never carry `type: "upsell"` | High |

### CRM webhook receiver — WH

The CRM forwards every Stripe event for the product to one app URL, signed
with `X-CRM-Signature` (`crm-contract.md` §2). Apps with a Stripe-driven
backend receive it; it replaces (or sits beside) a direct Stripe webhook.

| ID | Requirement | Severity |
| --- | --- | --- |
| WH-01 | One receiver route for CRM events; it verifies `X-CRM-Signature` (HMAC-SHA256 of `t.rawBody` with the full `whsec_…` secret, constant-time compare) on the raw body before parsing, and rejects failures without side effects | Critical |
| WH-02 | Timestamp older or newer than 5 minutes is rejected | High |
| WH-03 | Each `event.id` is processed once (atomic claim), shared with any direct Stripe endpoint the app also has — the ids are identical | Critical |
| WH-04 | Answers 2xx within 8 seconds; slow work runs after a durable record of the event (queue / outbox), never inline before the response | High |
| WH-05 | Status codes follow the CRM's retry rules: 2xx for processed, duplicate, ignored and `crm.ping`; 5xx only for transient failures (so the CRM retries); 4xx only for bad signature / malformed body (terminal) | High |
| WH-06 | Unknown or unhandled event types and `crm.ping` are acknowledged 2xx with no side effects | Medium |
| WH-07 | Handlers are correct when events arrive late (up to 3 days) or out of order: state changes compare the event's object state or `created` against what is stored, or re-fetch from Stripe, instead of applying blindly | High |
| WH-08 | Events whose `livemode` doesn't match the app's environment are acknowledged and ignored | Medium |
| WH-09 | The signing secret is read from server env and accepts a list (current + previous) so rotation needs no code change | Medium |
| WH-10 | Tests cover: valid signature, bad signature, stale timestamp, duplicate delivery processed once, ping, unknown type | Medium |

### CRM App-data endpoint — AD

The CRM calls the app live to show an "App context" panel on transactions
and subscribers (`crm-contract.md` §3). Every app with user accounts exposes
it.

| ID | Requirement | Severity |
| --- | --- | --- |
| AD-01 | `GET` endpoint authenticated by `Authorization: Bearer <product crm_… key>`, constant-time compared against keys held in server env (a list, for rotation); anything else gets 401 and no data | Critical |
| AD-02 | Finds the user by `customerId` (`cus_…` → stored Stripe customer id; `rc_<id>` → RevenueCat app user id) then by `email` (trimmed, case-insensitive); returns 404 when no user matches — never 200 with an empty body, never 500 | High |
| AD-03 | Response is JSON matching the CRM envelope exactly (`sections` required, field types and length limits respected); built in one function from named fields | High |
| AD-04 | Responds well inside 5 seconds: indexed lookups only, no third-party calls on the request path | High |
| AD-05 | Ignores unknown query params (`simulate`, `productSlug`, future ones); uses `productSlug` only to pick the product when one backend serves several | Medium |
| AD-06 | Returns only what an operator needs for support and billing (account status, plan code, dates, usage counts, a link to the app's admin). Never passwords, tokens, keys, full payment details, funnel answers, goals, symptoms, health or other sensitive content | Critical |
| AD-07 | Read-only: no writes, no side effects, not cached across users | Medium |
| AD-08 | Served over `https` in production; the route is excluded from user-session auth, CSRF and bot protection that would block a server-to-server call | Medium |
| AD-09 | Tests cover: 401 without/with wrong key, 404 for unknown customer, lookup by `cus_`, `rc_` and email, response validates against the envelope schema | Medium |

### CRM customer identity — CI

What the app must record so the CRM can join one person's web, mobile and
tracking records (`crm-contract.md` §4–6).

| ID | Requirement | Severity |
| --- | --- | --- |
| CI-01 | Every Stripe customer has `email` set, trimmed and lower-case; one-time / guest payments carry it as `receipt_email` or billing email | High |
| CI-02 | The app stores the Stripe customer id on its user record (indexed), so `cus_…` lookups resolve | High |
| CI-03 | Mobile apps call RevenueCat `logIn(appUserId)` — the same `appUserId` sent in Stripe metadata — once the user is known and before any purchase; purchases are never made under an anonymous RevenueCat id when an account exists | High |
| CI-04 | Mobile apps set the RevenueCat `$email` attribute at login | Medium |
| CI-05 | RevenueCat is configured to post to the CRM webhook with the CRM-generated `Authorization` value, and the production entitlement ids are entered in the CRM | Medium |
| CI-06 | If the app creates checkout through the CRM API (`/saas/v1/checkout/sessions`): called server-side only; passes `customerEmail`; sends the standard metadata through `stripeOverrides.metadata` and `stripeOverrides.subscription_data.metadata`; never sets `saas_*` keys; never blindly retries into a second session | High |
| CI-07 | CRM product API key and CRM webhook secret are separate env vars per environment; test-mode keys (`crm_test_`) are never used in production or vice versa | High |

### Privacy — PV

| ID | Requirement | Severity |
| --- | --- | --- |
| PV-01 | Stripe secret, Stripe webhook secret, Syntrix store secret, CRM product API key and CRM webhook secret never reach the browser bundle or a mobile binary, and are never logged | Critical |
| PV-02 | Funnel answer content is never logged, error-reported or sent to any third party | Critical |
| PV-03 | EU traffic: consent banner live and a DPA with Syntrix covering the data category | Critical (EU) |
