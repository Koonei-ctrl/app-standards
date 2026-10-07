---
name: syntrix-debug
description: Find out why Syntrix events are missing, late, duplicated or not reaching Meta / GA4 / TikTok / Klaviyo — walk the path tracker load → /track/config → /track/e or /track/s2s → 5-minute server hold → transaction_id dedup → destination event mappings → forwarding, checking each hop with the browser, curl and the Syntrix CRM API. Use when someone says "purchase not showing in Syntrix", "Meta isn't getting purchases", "server purchase never arrives", "events are doubled", "Syntrix 401 / 404", "begin_checkout missing", "tracker not loading", or wants to verify a Syntrix integration live after `syntrix-setup`.
---

# Syntrix debug

Locates where an event is lost, using the real pipeline. Diagnoses first;
fixes go through `syntrix-setup` (app side) or are reported to the Syntrix
operator (account / destination side).

## Inputs

- Contract: `references/syntrix-contract.md` (in this skill's folder). Read §3–§6 in
  full.
- Standard: `references/standard.md` (EV-, SX-).
- The symptom: which event, browser or server copy, which destination, when.
- Access to the store's Syntrix dashboard (Events and Event Forwarder Debug
  pages) — ask the user to check them, or to ask the Syntrix operator.

## The pipeline — check in order, stop at the first broken hop

1. **Tracker loads** (browser events only). Network tab:
   `GET <host>/lib/stxq.min.js` → 200. Wrong host or `/lib/stxq.js` → 404.
   Script on the page? (EV-11: it must *not* be on logged-in or revealing
   pages.)
2. **Config**: `GET <host>/track/config?id=<key>` → `success: true`. Fails
   → wrong key or host; browser pixels won't load, but `/track/e` still works.
3. **Early calls**: `ReferenceError: stxq is not defined` in the console →
   the stub line is missing (contract §3, EV-12).
4. **Browser send**: turn on debug (`stxq('debug')` in the console or
   `data-debug="true"`), reproduce, look for `POST <host>/track/e` → 200
   `{ ok: true }`. Check the request body: `eventType` canonical
   snake_case; `email`, `transaction_id`, `value`, `currency` inside
   `eventData`.
5. **Server send**: find the relay's log line or reproduce with curl from
   the server (never paste the key into chat output):
   `POST <host>/track/s2s` with `X-API-Key` → **202 `queued: true`**.
   - 404 `NOT_FOUND` → the URL has `/api/v1` in it.
   - 401 → missing/wrong `X-API-Key` (must be the store's public key).
   - 500 → malformed JSON.
   - Relay never called → check the webhook handler path and dedup (EV-06),
     and the relay's "off when key unset" switch.
6. **Hold**: a server event appears ~5 minutes after 202 — by design. If
   checked earlier, wait and re-check.
7. **Arrival**: the dashboard **Events** page — search the order's
   `transaction_id` (the Stripe subscription id) or the test email; both the
   browser and server copies should appear, one marked duplicate.
8. **Dedup**: if the event arrived but wasn't forwarded, it may be marked
   duplicate. Purchase: same `transaction_id` already stored (first stored
   wins). Doubles at Meta usually mean the two copies carried **different**
   `transaction_id`s (e.g. checkout session id vs subscription id — EV-05).
9. **Mapping**: in the dashboard, the destination's `eventMappings`. A
   destination with mappings skips any event not listed. A server `lead`
   reaches Meta as `lead` (no alias on S2S).
10. **Forwarding**: dashboard Event Forwarder Debug page shows the payload
    and the destination's response per event. Destination errors (bad pixel
    id, expired token) are account fixes for the operator.

## Report

One short table: hop → status (✅ / ❌ / not checked) → evidence (request,
status code, log line, `file:line`). Then the root cause in one sentence and
who fixes it: the app (hand off to `syntrix-setup` with the EV/SX id) or
the Syntrix operator (destination, mapping, key).

## Do not

- Fire test events at production destinations without telling the user —
  use the destination's test event code / a test store where possible.
- Print API keys or customer emails in the report.
- "Fix" a missing event by adding a server copy of a non-purchase event
  (EV-08).
