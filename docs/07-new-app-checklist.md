# 7. New app checklist

Work through this in order for every new app, and before paid traffic goes
to an existing one. Each item links to the rule it comes from.

The fastest way to check is to ask your coding agent: `audit tracking in this
app`. It checks every item below and writes the report.

## 1. Design (before writing code)

- [ ] Map the [page roles](01-overview.md#page-roles) to this app's URLs
- [ ] Funnel URLs are **neutral** (`/start/step-3`), so the funnel can be
      tracked (EV-02)
- [ ] List the tracked routes: landing, offer, paywall, success, legal,
      recovery. Not the logged-in app (EV-11)
- [ ] Decide which flows the app has: [A, B, C, D](02-tracking.md#event-flows)
- [ ] Plans have neutral codes, a shape (`upfront`, `free-trial` or
      `paid-trial`) and a trial length where needed (PAY-08, PAY-11)
- [ ] Decide the 2–4 App-data panel sections with support (AD-06)

## 2. Accounts and keys

- [ ] Syntrix store created. Host confirmed on its **Sources** page (SX-01)
- [ ] Syntrix public key in env: one var for the browser build, one
      server-only for the relay (SX-02)
- [ ] Product created in the CRM. API key generated (`crm_test_` for test)
- [ ] CRM keys and webhook secrets are separate per environment (CI-07)
- [ ] No secret has a public env prefix (PV-01)
- [ ] EU traffic: consent banner and a Syntrix DPA in place (PV-03)

## 3. Tracking

- [ ] Tracker snippet **with the `stxq` stub** on tracked pages only (EV-12)
- [ ] Production build fails without the browser key (SX-03)
- [ ] Full page loads into and out of tracked areas (EV-11)
- [ ] `session_start` once per browser session (EV-01)
- [ ] Funnel events, `generate_lead` and `begin_checkout` at the right moments
      (EV-02 – EV-04)
- [ ] Browser `purchase` at **every** place a payment completes, with the
      subscription id, value charged today, currency and email (EV-05)
- [ ] Server `purchase` from the fulfilment handler, for every checkout path
      (EV-06, SX-04)
- [ ] Recovery events and token removal, if the app has recovery links
      (EV-07)
- [ ] Only allowed fields, built in one place, with a test (EV-09)
- [ ] Tracking can't break payment (EV-10)
- [ ] No home-made UTM or click-id capture; email not hashed (EV-13, EV-14)
- [ ] Consent refusal stops the tracker and the relay (EV-15)
- [ ] Product analytics is separate (EV-16)

## 4. Payments

- [ ] Rejection checks run before any Stripe object is created (PAY-05)
- [ ] Access granted only in the fulfilment handler (PAY-01)
- [ ] Signature verified on the raw body; each event processed once
      (PAY-02, PAY-03)
- [ ] All required Stripe events handled (PAY-04)
- [ ] Card, Link, Apple Pay, Google Pay; wallet errors can't break the card
      form (PAY-06)
- [ ] Adaptive currency conversion off (PAY-07)
- [ ] Free trial: card becomes the default payment method (PAY-09)
- [ ] Intro discounts on upfront plans only (PAY-10)
- [ ] Neutral statement descriptor and product names (PAY-12)
- [ ] Success page never grants access (PAY-13)

## 5. Stripe metadata

- [ ] The eight keys on every Stripe object, on every checkout path
      (MD-01, MD-02)
- [ ] Strings only; missing = `""` (MD-03)
- [ ] Nothing sensitive (MD-04)
- [ ] Correct `ipAddress` and `country` (MD-06, MD-07)
- [ ] Upsells carry `type` and `offerId` (MD-08)
- [ ] Test asserts the exact key set (MD-05)

## 6. CRM

- [ ] Webhook receiver: signature, replay window, dedup, fast 2xx, correct
      status codes, ping, late events (WH-01 – WH-10)
- [ ] App-data endpoint: auth, lookup, 404, envelope, speed, nothing
      sensitive, tests (AD-01 – AD-09)
- [ ] Email on every Stripe customer; Stripe customer id stored on the user
      (CI-01, CI-02)
- [ ] Mobile: RevenueCat `logIn(appUserId)` before purchase, `$email` set,
      RevenueCat → CRM webhook configured (CI-03 – CI-05)
- [ ] CRM checkout API used correctly, if used (CI-06)

## 7. Verify live (test mode)

- [ ] CRM **Send test ping** → 2xx in the delivery log
- [ ] One purchase per plan type → access granted, the delivery log shows 2xx
- [ ] Close the tab before the success page → access is still granted
- [ ] Free-trial test clock advanced to the end → it bills
- [ ] Browser and server `purchase` share the `transaction_id`; only one
      reaches Meta (the server copy lands about 5 min later as a duplicate)
- [ ] No tracker requests in the logged-in app or a revealing funnel
      (network tab)
- [ ] Stripe dashboard: customer, subscription and intent show the eight
      keys, with no `"undefined"`
- [ ] CRM App-data **Test** with a real test customer shows the panel
- [ ] RevenueCat sandbox purchase shows `appUserId` as the customer id
      (mobile)

## 8. After launch

- [ ] Import the starter reports from
      [`skills/syntrix-reports/examples/`](../skills/syntrix-reports/examples/)
      into Syntrix
- [ ] Re-run the audit after any change to checkout, tracking or webhooks
