---
name: crm-webhook
description: Build or fix the endpoint where an app receives the CRM's forwarded Stripe events — X-CRM-Signature verification on the raw body, 5-minute replay window, process-once on event id (shared with any direct Stripe webhook), fast 2xx with queued work, status codes that match the CRM's retry rules, crm.ping and unknown types acknowledged, safe with late or out-of-order events. Use when asked to "set up the CRM webhook", "receive events from the CRM", "verify X-CRM-Signature", "CRM deliveries failing", "webhook ping not working", "move our Stripe webhook to the CRM relay", or after `tracking-audit` reports WH- gaps.
---

# CRM webhook receiver

Brings an app to the standard's **WH** requirements, and keeps **PAY-01 …
PAY-04** true while doing it — this endpoint usually grants access. Be
conservative, confirm before editing, test mode only.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the WH and PAY tables.
- Contract: `references/crm-contract.md` §2 — headers, signature,
  events, retry behaviour. Read it in full; the signature is **not**
  verifiable with Stripe's SDK.
- Discovery guide: `references/discovery.md` (sections 1, 4, 6, 7).

## Steps

1. **Discover.** Find any existing CRM receiver, any direct Stripe webhook,
   the fulfilment logic both feed, the dedup store, the queue (if any), and
   how env secrets are loaded. Note whether the framework gives access to the
   raw body on that route (Next.js route handlers: `await req.text()`;
   Express: `express.raw()` on that route only; Hono: `c.req.text()`).

2. **Decide the source with the user** if the app has a direct Stripe
   webhook today:
   - **CRM relay only** (recommended — one Stripe subscription, owned by the
     CRM): the app's Stripe endpoint is removed in the Stripe dashboard
     after the relay is live and verified.
   - **Both**: both routes call the same handler and the same dedup on the
     Stripe event id (WH-03, PAY-03).
   Never run two independent fulfilment paths.

3. **Check** WH-01 … WH-10 (and PAY-01 … 04, PV-01 for the secret). Table
   with `file:line` evidence.

4. **Plan** ordered Critical → High → Medium and **ask the user to confirm**.
   List what the operator must do in the CRM: save the URL on the product's
   Integration page, copy the `whsec_…` secret into the app's env, press
   "Send test ping".

5. **Implement**, in the repo's conventions:
   - Read the raw body as text, verify (`crm-contract.md` reference function),
     then `JSON.parse`. Secrets from an env var holding a comma-separated list
     (WH-09).
   - Bad / missing signature or stale timestamp → 400/401, nothing written.
   - `crm.ping`, unknown types, `livemode` mismatch → 200, nothing written
     (WH-06, WH-08).
   - Claim `event.id` atomically (unique insert, `ON CONFLICT DO NOTHING`,
     or the repo's equivalent); duplicate → 200.
   - Record the event durably, return 200, process in the queue / after the
     response. If the app has no queue and the handler is reliably fast,
     inline processing is acceptable only when total time stays well under
     8 s; say so in the plan.
   - Transient failure (DB down, Stripe API timeout) → 5xx, and release the
     claim so the retry can process it. A valid event the app can't act on
     (unknown customer, already-cancelled order) → log and 200; retrying
     won't change it.
   - Out-of-order safety (WH-07): for subscription state, compare against
     stored state (status, `current_period_end`, event `created`) or re-fetch
     the subscription from Stripe before writing.
   - Server `purchase` to Syntrix (EV-06) moves with fulfilment if it lived
     in the old Stripe handler.

6. **Test (WH-10).** Sign bodies in the test with the same HMAC to cover:
   valid, wrong secret, previous secret still accepted, stale `t`, duplicate
   id processed once, `crm.ping`, unknown type. Run lint, type-check, tests;
   report failures verbatim.

7. **Verify and report.** Before → after per ID. Manual check: in the CRM,
   "Send test ping" → delivery shows 2xx; one test-mode purchase → the
   delivery log shows `checkout.session.completed` 2xx and access is granted;
   press Retry on that delivery → app processes nothing twice. Remind the
   operator of the rotation procedure in `crm-contract.md` §2.

## Do not

- Use `stripe.webhooks.constructEvent` on CRM deliveries — it expects
  `Stripe-Signature` and will always fail.
- Parse JSON before verifying, or verify a re-serialised body.
- Return 4xx for transient errors, or 5xx for events you chose to ignore.
- Remove the direct Stripe webhook before the relay is verified in test mode.
- Log the signing secret or full event payloads containing customer data.
