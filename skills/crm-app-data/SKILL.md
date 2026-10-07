---
name: crm-app-data
description: Build or fix the App-data endpoint the CRM calls to show live "App context" for a customer — bearer-key auth with the product's crm_ key, lookup by Stripe customer id, RevenueCat rc_ id or email, 404 for unknown customers, a response that matches the CRM's sections/fields envelope, under 5 seconds, read-only, and nothing sensitive. Use when asked to "add app data for the CRM", "CRM app context panel", "app-data endpoint", "CRM shows invalid_response / timeout / no_api_key", "show user info in the CRM", or after `tracking-audit` reports AD- gaps.
---

# CRM App-data endpoint

Brings an app to the standard's **AD** requirements. The endpoint exposes
customer data to a server-to-server caller, so auth and data minimisation
come first.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the AD, CI and PV
  tables.
- Contract: `references/crm-contract.md` §1 and §3 — request,
  responses, envelope schema. Read in full.
- Discovery guide: `references/discovery.md` (sections 1, 6, 7).

## Steps

1. **Discover.** Find any existing App-data route; the user model and where
   it stores email, Stripe customer id and RevenueCat app user id (CI-02,
   CI-03); the subscription/entitlement state; the app's admin URL for a
   user; middleware that would block a server-to-server GET (session auth,
   CSRF, bot protection, locale redirects).

2. **Agree the panel contents with the user** before writing code. Propose
   2–4 sections from what the app actually has, e.g. *Account* (user id,
   signup date, last active, locale), *Subscription* (status badge, plan
   code, renews/ends), *Usage* (a few counts), plus `externalUrl` to the
   app's admin. Check every field against AD-06 and drop anything sensitive
   — funnel answers, goals, symptoms, health data, free-text the user wrote,
   tokens, payment details.

3. **Check** AD-01 … AD-09 for an existing endpoint. Table with `file:line`.

4. **Plan** and **ask the user to confirm**. Include the env var for the
   accepted keys and what the operator does in the CRM: create an API key on
   the Integration page (or reuse the newest one), put it in the app's env,
   save the App-data URL, press "Test".

5. **Implement**, in the repo's conventions:
   - Route excluded from user-session auth / CSRF / redirects (AD-08).
   - Auth: `Authorization: Bearer <key>`; constant-time compare against each
     key in an env list (e.g. `CRM_APP_DATA_KEYS`); 401 with an empty body
     otherwise. The CRM always sends its **newest** active key — when the
     operator creates a new one, the app must accept it at once.
   - Lookup order (AD-02): `customerId` starting `cus_` → user by Stripe
     customer id; starting `rc_` → strip the prefix, user by RevenueCat app
     user id (= `appUserId` when CI-03 is met); then `email`, trimmed and
     case-insensitive. Nothing found → 404.
   - Build the envelope in one function from named fields (AD-03). Respect
     the limits: ≤10 sections, ≤40 fields each, label ≤100, text ≤2000,
     badge ≤80. Dates as ISO strings. Plan as the neutral plan code.
   - Indexed queries only, no third-party calls (AD-04). Read-only, no
     caching keyed only on the URL (AD-07).
   - Ignore unknown params including `simulate` and `productSlug` (AD-05).

6. **Test (AD-09).** Copy the envelope Zod schema from `crm-contract.md` into
   the test (or the repo's validator equivalent) and assert the response
   parses. Cover 401 (missing, wrong key), 404, lookup by `cus_`, `rc_`,
   email in different case. Run lint, type-check, tests; report failures
   verbatim.

7. **Verify and report.** Before → after per ID. Manual check: CRM
   Integration page → App-data → "Test" with a real test-mode customer shows
   the panel; a transaction in the CRM shows "App context".

## Do not

- Return sensitive or free-text user content, even "just for support".
- Accept the key from a query string or cookie.
- Return 200 with empty `sections` for an unknown customer — return 404.
- Call Stripe, RevenueCat or other services on the request path.
