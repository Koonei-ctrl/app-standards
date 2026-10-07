---
name: payment-standard
description: Check and fix any app's Stripe payment flow against the company standard — access granted only by a verified, idempotent webhook; card, Link, Apple Pay and Google Pay; upfront, free-trial and paid-trial plans that charge what the page promised; trial cards actually billed; intro discounts only on upfront plans; neutral statement descriptor. Use when asked to "check payments", "fix the payment flow", "Stripe webhook", "free trial not billing", "Apple Pay not showing", "access not granted after payment", or after `tracking-audit` reports PAY- gaps.
---

# Payment standard

Brings an app to the standard's **PAY** requirements (and PV-01 for Stripe
secrets). Payment code moves money: be conservative, confirm before editing,
test mode only.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the Payments-related
  sections and the PAY table.
- Discovery guide: `references/discovery.md`.

## Steps

1. **Discover** per `discovery.md`: every checkout path, the plan catalogue
   (where plan type, price, intro discount and trial length live), the
   webhook route(s), handled Stripe events, where access is stored and
   granted, the success page, wallet setup.

2. **Check** PAY-01 … PAY-13 and PV-01. For each, trace the real code path:
   - **PAY-01:** search for anything that grants access outside the webhook
     (success page, client callback, checkout response, polling that writes).
   - **PAY-02/03:** signature verification on the raw body; dedup on event id
     with an atomic insert/claim, and safe under concurrent duplicate delivery.
     Events may arrive from the CRM relay (`X-CRM-Signature`), a direct Stripe
     endpoint (`Stripe-Signature`), or both — both must feed one handler and
     one dedup. The CRM receiver itself is checked and fixed by `crm-webhook`.
   - **PAY-04:** each required Stripe event has a handler that does the right
     thing for every checkout path.
   - **PAY-05:** order of operations before the first Stripe create call.
   - **PAY-06:** payment method types; wallet country source (must be the
     merchant's); per-wallet availability check; billing address not
     required; wallet setup wrapped so it cannot break the card form.
   - **PAY-07:** adaptive/automatic currency conversion explicitly off.
   - **PAY-08 … PAY-11:** walk each plan type through the code — what is
     charged today, which intent the client confirms, trial settings,
     `save_default_payment_method: "on_subscription"` (or equivalent default
     payment method handling), coupon only on upfront, trial without length
     rejected where plans are configured.
   - **PAY-12:** statement descriptor set explicitly; product/plan names
     neutral.
   - **PAY-13:** success page behaviour before the webhook lands; any
     unauthenticated receipt endpoint's scope.
   Show the result as a table with `file:line` evidence.

3. **Plan** fixes ordered Critical → High → Medium, and **ask the user to
   confirm** before editing. Call out anything that affects existing
   subscribers (e.g. changing default payment method handling, plan
   validation) and anything requiring Stripe dashboard changes.

4. **Implement** in the repo's conventions:
   - Keep one fulfilment handler; if there are several delivery routes
     (direct Stripe, CRM relay), they share it and its dedup. Building or
     changing the CRM receiver route is `crm-webhook`'s job — hand off rather
     than duplicating it here.
   - Make fulfilment idempotent and atomic.
   - Never move access-granting out of the webhook "temporarily".
   - Follow the repo's migration rules for any schema change.

5. **Test.** Add or extend tests for: duplicate webhook delivery processed
   once; each plan type's subscription parameters (trial days, default
   payment method, coupon only on upfront); trial without length rejected;
   access not granted by the success path. Run lint, type-check and tests;
   report failures verbatim.

6. **Verify and report:** before → after per PAY ID. Give a manual test-mode
   script: one purchase per plan type with Stripe CLI webhook forwarding;
   close the tab before the success page and confirm access is still granted;
   advance a free-trial test clock to its end and confirm it bills.

## Do not

- Use live keys, live data or real cards.
- Grant access anywhere but the webhook.
- Apply intro discounts to trial plans.
- Weaken a check to make a test pass.
