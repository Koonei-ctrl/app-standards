# Discovery: map an unknown app before checking or changing it

Apps share Stripe, Syntrix and the CRM and nothing else. Before evaluating or editing,
build a map of this app. Do it once per run and reuse it.

Prefer an Explore subagent for the sweep when one is available; keep only the
map, not the file dumps.

## 1. Stack

- Read the root manifest(s): `package.json` (and workspace packages),
  `composer.json`, `pyproject.toml`/`requirements.txt`, `Gemfile`, `go.mod`.
- Note: frontend framework (Next.js, Remix, Nuxt, SvelteKit, plain SPA…),
  backend (same app, separate API, serverless functions), language, test runner,
  package manager, monorepo layout.
- Read the repo's `CLAUDE.md`, `AGENTS.md`, `README`, `docs/adr/` or similar.
  **Repo rules win over this plugin's defaults on *how*; this standard wins on
  *what*.** If they conflict on *what*, report it — don't silently pick one.

## 2. Page roles → URLs

Map each role from the standard to this app's routes:

| Role | Route(s) | Neutral or revealing? |
| --- | --- | --- |
| Landing page(s) | | |
| Funnel | | |
| Paywall | | |
| Offer page(s) | | |
| Success page | | |
| Logged-in app | | |
| Recovery landing | | |

Find routes from the router (file-based `app/`, `pages/`, `routes/`, or a
router config). A route is **revealing** if any path segment names a topic,
condition, goal, symptom, answer or product category.

## 3. Syntrix

Search for: `syntrix`, `stxq`, `stxq.q`, `stxq.min.js`, `track/s2s`,
`X-API-Key`, `trysyntrix`, `api.syntrix.com` (wrong host), `ppLayer` /
`tracker.js` (legacy tracker), `SYNTRIX_`.
Record: where the script tag is mounted, which pages it loads on, every call
site and its event name and payload, the server relay (if any) and where it is
called from, env var names, host used, whether the `stxq` stub is defined
before the script tag, and the S2S request body shape (`eventData` vs
`userData`) — compare against `syntrix-contract.md`.

Also search for app-built attribution capture that should not exist:
`fbclid`, `gclid`, `ttclid`, `utm_`, `_fbc`, `_fbp`, `document.referrer`,
`captureAttribution`, `fbq(`, `gtag(`, `ttq.` (other pixels running alongside).

## 4. Stripe

Search for: `stripe.checkout.sessions.create`, `customers.create`,
`subscriptions.create`, `paymentIntents`, `setupIntents`, `paymentRequest`,
`PaymentElement`, `ExpressCheckoutElement`, `constructEvent`, `webhook`,
`metadata`, `statement_descriptor`, `trial_period_days`, `coupon`,
`discounts`, `adaptive_pricing`, `save_default_payment_method`.

Record: each checkout path (hosted vs built-in), the plan/price catalogue and
where plan type and trial length live, the webhook route(s), which Stripe
events are handled, how entitlement/access is stored and where it is granted,
the success page and what it does.

## 5. Product analytics and consent

Search for the app's own event tracking (`track(`, `analytics`, `posthog`,
`mixpanel`, `segment`, an `/events` endpoint) and consent handling (`consent`,
cookie banner). Record whether any product event is forwarded to Syntrix.

## 6. Tests and CI

Find the test runner and existing tests around billing and analytics. Fixers
add tests in the same style and location.

## 7. CRM integration

Search for: `X-CRM-Signature`, `X-CRM-Event-Id`, `crm.ping`, `crm_live_`,
`crm_test_`, `CRM_` env vars, `app-data`, `appData`, `saas/v1`,
`checkout/sessions`, `whsec_`, `upsell`, `offerId`.

Record: the CRM webhook receiver route (if any) and whether it shares the
fulfilment handler and dedup store with a direct Stripe webhook; the
App-data route (if any), its auth and how it finds a user; where the user
record stores the Stripe customer id and email; how upsell charges are
created and their metadata; whether checkout goes through the CRM API.

Mobile apps: search for `react-native-purchases`, `purchases_flutter`,
`RevenueCat`, `Purchases.configure`, `logIn(`, `setEmail`, `setAttributes`.
Record when `logIn` is called relative to purchase, and with which id.

## Output

A short map (stack, role → route table, Syntrix sites, Stripe sites, webhook,
CRM receiver / App-data / identity, analytics, tests) that later steps cite
by `file:line`.
