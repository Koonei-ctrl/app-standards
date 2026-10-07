---
name: tracking-audit
description: Read-only audit of an app against the company standard — Syntrix tracking, Stripe payments, Stripe metadata and CRM integration (webhook receiver, App-data endpoint, customer identity) — producing a report a product owner can act on — what is done, partial, missing or wrong, and what each gap costs. Use when asked to "audit tracking", "check the standard", "is Syntrix/Stripe set up correctly", "is this app connected to the CRM properly", "what's missing in tracking/payments/CRM integration", "compliance check for pixel/payments/metadata", or before launching paid traffic on an app.
---

# Tracking, payment & CRM audit

Checks one app against the standard and reports. **Never edits code.** Fixes
belong to `syntrix-setup`, `stripe-metadata`, `payment-standard`,
`crm-webhook`, `crm-app-data` and `crm-identity`.

## Inputs

- The standard: `references/standard.md` (in this skill's folder). Read it
  in full first. Every requirement has an ID (EV-, SX-, PAY-, MD-, WH-, AD-,
  CI-, PV-).
- The CRM contract: `references/crm-contract.md` — needed to judge WH,
  AD and CI (exact headers, signature, envelope).
- The Syntrix contract: `references/syntrix-contract.md` — needed to
  judge EV and SX (host, key, S2S path and body, stub, hold, dedup). A relay
  posting to `/api/v1/track/s2s` or `api.syntrix.com` is **Wrong** (SX-01).
- The discovery guide: `references/discovery.md`.
- Optional argument: an area to limit the audit to (`events`, `syntrix`,
  `payments`, `metadata`, `crm` (WH + AD + CI), `privacy`). Default:
  everything.

## Steps

1. **Discover.** Follow `discovery.md` and build the app map. Fill the
   role → route table and mark each route neutral or revealing.

2. **Evaluate every requirement ID** in scope. For each, decide one status:

   | Status | Meaning |
   | --- | --- |
   | Pass | Met, with evidence |
   | Partial | Met on some paths, missing on others (e.g. metadata on built-in checkout but not hosted) |
   | Missing | Not implemented |
   | Wrong | Implemented in a way that violates the requirement |
   | N/A | The flow doesn't exist in this app (e.g. no wallet, no funnel) — say why |
   | Unverifiable | Depends on something outside the repo (Syntrix host confirmation, Stripe dashboard setting, DPA) — say what to check and where |

   Rules:
   - **Evidence is `file:line` you actually read.** No status without it,
     except N/A and Unverifiable, which carry a reason.
   - Check **every** path, not the first one found. A purchase that can
     complete in three places needs three browser `purchase` calls (EV-05),
     and each checkout path needs a server copy (EV-06).
   - Trace payloads to their source: confirm `transaction_id` is the
     subscription id, `value` is the amount charged today, and every browser
     `purchase` carries the email.
   - For the event flows, walk each flow the app has (A–D) in order and
     compare moment, event, data and dedup window against the tables.
   - Grep for forbidden fields in Syntrix payloads and Stripe metadata (plan
     names in `items`, page URLs, answers, goals).
   - CRM: if the app has both a direct Stripe webhook and a CRM receiver,
     confirm they share one fulfilment handler and one dedup on event id
     (PAY-03, WH-03). Trace every field the App-data endpoint returns against
     AD-06. An app with no App-data endpoint is **Missing**, not N/A, unless
     it has no user accounts. CI-03/04 are N/A for web-only apps.

3. **Rank gaps** by severity from the standard (Critical → High → Medium),
   then by how many users/sales they touch.

4. **Write the report** (format below). Save it as
   `tracking-audit-<YYYY-MM-DD>.md` in the scratchpad or a temp directory —
   not in the repo unless asked. If an artifact/page publishing tool is
   available, offer to publish it as a shareable page for the product owner.

5. **Hand off.** End by naming which fixer skill covers each failing area,
   and `syntrix-debug` for the live checks the code can't prove.

## Report format

Written for a product owner: plain words first, code references last.

```markdown
# <App name> — tracking & payment audit (<date>)

## Verdict
<One sentence: ready for paid traffic or not, and the single biggest reason.>

| Area | Pass | Partial | Missing | Wrong |
| --- | --- | --- | --- | --- |
| Events (EV) | | | | |
| Syntrix config (SX) | | | | |
| Payments (PAY) | | | | |
| Stripe metadata (MD) | | | | |
| CRM webhook (WH) | | | | |
| CRM App-data (AD) | | | | |
| CRM identity (CI) | | | | |
| Privacy (PV) | | | | |

## Top risks
1. **<Plain-language problem>** — <business effect: e.g. "wallet sales reach
   Meta with no email, so they can't be attributed to the ad that paid for
   them">. Fix with `<skill>`. (<IDs>)
2. …
3. …

## Flow check
<For each flow the app has: a table of the standard's steps with ✅ / ⚠️ / ❌
and a one-line note.>

## Needs checking outside the code
<Unverifiable items: what to check, where (Stripe dashboard, Syntrix account,
CRM Integration page and delivery log, RevenueCat dashboard, legal).>

## All requirements
| ID | Requirement | Status | Note |
| --- | --- | --- | --- |

## Technical evidence
| ID | Evidence (`file:line`) | Detail |
| --- | --- | --- |
```

Keep the business-effect wording concrete: name the money or attribution lost,
the user who gets stuck, or the data that leaks. Never soften a Critical.
