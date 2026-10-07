---
name: syntrix-guide
description: Answer how-to questions about Syntrix, our server-side ad-conversion tracker, from facts traced from its code — install snippet and stub, stxq commands, what fires automatically, browser vs server (S2S) ingest, keys and hosts, the 5-minute server hold, purchase dedup on transaction_id, event names and aliases, hashing, destinations and event mappings. Use when someone asks "how does Syntrix work", "how do I send an event to Syntrix", "what's the S2S endpoint", "which key goes where", "why is my server purchase delayed", "does Syntrix dedup", "what host do I use", "can I set my own eventId", or wants to write Syntrix code outside the full `syntrix-setup` flow.
---

# Syntrix guide

For developers adding Syntrix to their app: answers questions about how
Syntrix behaves and writes small Syntrix snippets correctly. For bringing a
whole app up to the standard, hand off to `syntrix-setup`; for "events
aren't showing up", `syntrix-debug`.

## Inputs

- Contract: `references/syntrix-contract.md` (in this skill's folder). **Read it in full
  before answering.** It is traced from the Syntrix code and overrides
  Syntrix's own `SYNTRIX-INTEGRATION.md`, which is wrong on the S2S path,
  host, hold and dedup (contract §8).
- Standard: `references/standard.md` — the Two pipelines, Event flows
  and Allowed Syntrix fields sections.

## How to answer

1. **Answer from the contract**, citing the section. If the contract doesn't
   cover it and the Syntrix repo is available (`apps/api/src/…`), read the
   code and say which file you checked. Never fill gaps from the Syntrix
   guide or from memory.
2. **Our apps follow the standard, not Syntrix's full feature set.** Syntrix
   accepts `items`, `content_ids`, plan names, page URLs and server copies of
   any event; the standard forbids them (EV-08, EV-09). When a question is
   about one of our apps, give the standard-compliant answer and say why the
   richer option is off-limits. When it's about a non-standard use (e.g. a
   plain e-commerce store), say so and answer from the contract alone.
3. **Snippets** use the real host (`https://tracker.trysyntrix.app`, unless
   the operator confirms another — SX-01), include the `stxq` stub, put
   browser PII inside `eventData`, put S2S PII inside `userData`, use
   canonical snake_case names, and never hash email.
4. Say what the answer **can't** guarantee: anything that depends on the
   merchant's destination config or `eventMappings` in the dashboard (an
   event missing from a destination's mappings is skipped for it), the
   or the account's host.

## Facts people most often get wrong

- S2S is `POST <host>/track/s2s` — not under `/api/v1` — with
  `X-API-Key: <the same public key the browser uses>`. 202 means queued.
- Every S2S event waits 5 minutes. First stored copy wins the
  `transaction_id` dedup, so the browser copy wins only if it lands within
  that hold.
- Syntrix has no automatic `session_start`.
- Your own `eventId` is ignored on S2S; dedup is `transaction_id`.
- `lead` → `generate_lead` aliasing happens on the browser path only.
- Debug is `data-debug="true"` or `stxq('debug')`, not a dashboard switch.

## Do not

- Quote `api.syntrix.com` or `/api/v1/track/s2s`.
- Put the store secret in client code, or the relay's key in logs.
- Recommend pre-hashing email or phone.
