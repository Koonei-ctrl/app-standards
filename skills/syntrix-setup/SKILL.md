---
name: syntrix-setup
description: Install or fix Syntrix ad-conversion tracking in any app so it meets the company standard — tracker on the right pages, the right events at the right moments with only the allowed data, the server purchase fallback from the Stripe webhook, and nothing Syntrix already does built by hand. Use when asked to "set up Syntrix", "fix tracking", "fix the pixel", "add conversion events", "purchase events missing", "begin_checkout / generate_lead not firing", or after `tracking-audit` reports EV- or SX- gaps.
---

# Syntrix setup

Brings an app to the standard's **EV** and **SX** requirements (and PV-01 for
Syntrix keys). Works in any stack: Stripe and Syntrix are fixed, everything
else is discovered.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the Page roles, Two
  pipelines, Event flows, Allowed Syntrix fields and EV/SX tables in full.
- Syntrix contract: `references/syntrix-contract.md` — host, keys,
  install snippet with stub, `/track/s2s` body and responses, hold and dedup.
  Read §1–§6 in full. It overrides Syntrix's own integration guide, which has
  the wrong S2S path and host.
- Discovery guide: `references/discovery.md`.

## Steps

1. **Discover** per `discovery.md`. The role → route table and the
   neutral/revealing call for the funnel decide where the tracker may load.

2. **Check** every EV- and SX- requirement (same statuses and evidence rules
   as `tracking-audit`). Show the result as a short table.

3. **Plan** the changes as a list: requirement ID → file → change. Include the
   tests you will add. Then **ask the user to confirm** before editing. Flag
   anything you need from them:
   - The account's Syntrix host (SX-01) — production is
     `https://tracker.trysyntrix.app`; confirm on the store's Sources page in
     the Syntrix dashboard. Never `api.syntrix.com`. If unknown, leave a
     clearly named config value and list it as a blocker.
   - The env var names for the store's public key: one exposed to the
     browser build, one server-only for the relay (same value; values are not
     needed; never print or commit them).

4. **Implement**, matching the repo's own conventions and rules:
   - **Tracker loading (EV-02, EV-11):** load on landing, offer, paywall
     (only when prices show), success, legal and recovery pages; in the funnel
     only if its routes are neutral; never in the logged-in app. Make every
     move into or out of a tracked area a full page load. Keep an explicit
     list of tracked routes and warn in development when the tracker is live
     elsewhere.
   - **No queue loss (EV-12):** emit the `stxq` stub line before the script
     tag (`syntrix-contract.md` §3); Syntrix replays it after init. Only if
     the stub can't be emitted early, wrap calls so they wait for the script
     (poll briefly, give up quietly after a timeout).
   - **Consent (EV-15):** Syntrix has no consent API; the app decides whether
     to render the script at all, and the relay checks the same record.
   - **Dedup (EV-01, EV-04, EV-05):** per-session guard for session/funnel
     events, permanent guard keyed on transaction id for `purchase`. Set the
     guard before firing.
   - **Events:** fire each flow's events at exactly the moments in the Event
     flows tables, with exactly the listed data. Every browser `purchase`
     carries the email (EV-05). `transaction_id` is the Stripe subscription
     id; if a page only has a checkout session id, fetch the receipt from the
     backend.
   - **Server purchase (EV-06, SX-04):** send from the Stripe fulfilment
     handler (fed by a direct Stripe webhook or the CRM relay — see
     `crm-webhook`) for every checkout path, after its event-id dedup so a
     redelivery never sends it twice, using the amount actually charged today.
     `POST <host>/track/s2s` with `X-API-Key` (no `/api/v1`). Build the body
     in one function from named fields only (EV-09): `eventData`
     `{ transaction_id, value, currency }`, `userData` `{ email, externalId,
     country, ipAddress }` where `ipAddress` is the buyer's (Stripe metadata),
     never the webhook request's; a fixed neutral `sourceUrl`; no `eventId`
     (ignored). 202 = queued; retry 5xx/429/network within a total time
     budget, never 4xx; never throws into the webhook; off when the key is
     unset. Check consent first (EV-15) if the app records consent.
   - **Never let tracking throw** into a payment or success flow (EV-10).
   - **Remove** app-built attribution capture (EV-13) and any forwarding of
     product analytics to Syntrix (EV-16). Do not hash email (EV-14).
   - **Build guard (SX-03):** if the framework inlines the public key at
     build time, make the production build/deploy fail when it is missing.

5. **Test.** Add tests in the repo's style that:
   - assert the server relay body contains only allowed fields;
   - assert every browser `purchase` call site passes `transaction_id`,
     `value`, `currency` and `email`;
   - assert no forbidden field (plan name, `items`, URL) appears.
   Run the repo's lint, type-check and tests. Report failures verbatim.

6. **Verify and report.** Re-check EV/SX and show before → after per ID.
   List what can only be verified live, and offer to walk it with
   `syntrix-debug`: browser and server `purchase` for one test order share a
   `transaction_id` and only one is forwarded (the server copy lands ~5 min
   later and is dropped as a duplicate); network tab shows no tracker requests
   in the logged-in app (or in a revealing funnel). Offer `syntrix-reports`
   to give the owner import-ready funnel and revenue reports for the events
   just wired.

## Do not

- Load the tracker on a revealing URL "just to get funnel data".
- Add a server copy of any event other than `purchase`.
- Send plan names, product names, page URLs, answers or goals to Syntrix.
- Commit secrets or real keys.
- Copy snippets from Syntrix's `SYNTRIX-INTEGRATION.md` without checking
  them against `syntrix-contract.md` §8.
