---
name: crm-identity
description: Make an app record customer identity the way the CRM needs to join one person across web (Stripe), mobile (RevenueCat) and tracking — email on every Stripe customer and guest charge, Stripe customer id stored on the user, upsell charges marked type/offerId, RevenueCat logIn with the app's own user id and $email set, correct use of the CRM checkout API, and CRM keys kept per environment. Use when asked to "fix CRM data", "customers duplicated in the CRM", "web and app subscribers not merged", "upsells not grouped with orders", "RevenueCat app_user_id", "integrate app data with the CRM", or after `tracking-audit` reports CI- or MD-08 gaps.
---

# CRM customer identity

Brings an app to the standard's **CI** requirements and **MD-08**. Most
fixes are small, but they only help customers created after the change, so
also report how many existing records stay unjoined.

## Inputs

- Standard: `references/standard.md` (in this skill's folder). Read the CI table, MD
  table and the Stripe metadata section.
- Contract: `references/crm-contract.md` §4–6.
- Discovery guide: `references/discovery.md` (sections 1, 4, 7).

## Steps

1. **Discover**: every place a Stripe customer, PaymentIntent (incl.
   upsells / one-click offers) or checkout session is created; the user
   model fields; any call to the CRM checkout API; for mobile apps, the
   RevenueCat SDK setup, when `logIn` runs and with which id, and which
   attributes are set; env var names for CRM keys.

2. **Check** CI-01 … CI-07 and MD-08, per path. Mark CI-05 Unverifiable
   (RevenueCat dashboard + CRM settings) with what to check. Table with
   `file:line`.

3. **Plan** and **ask the user to confirm**. Resolve with them:
   - The RevenueCat id: `appUserId` (the app's own user id, already in
     Stripe metadata). If the app currently calls `logIn` with something
     else, switching changes the RevenueCat customer for existing users —
     RevenueCat aliases the ids on `logIn`, but confirm the user accepts it.
   - The offer codes for upsells: neutral (`o1`, `upsell-2`), never product
     or condition names.
   - Whether the product overrides the upsell marker keys in CRM settings
     (default `type` / `upsell` / `offerId`).
   - Any schema change (adding `stripe_customer_id` to users) follows the
     repo's migration rules, additive only, with a backfill plan.

4. **Implement**:
   - **CI-01:** set `email` (trimmed, lower-case) when creating or updating
     the Stripe customer; on guest PaymentIntents set `receipt_email`.
   - **CI-02:** persist the Stripe customer id on the user when it is
     created (not only in the webhook), indexed.
   - **MD-08:** add `type: "upsell"` and `offerId` to the upsell
     PaymentIntent metadata, alongside the standard keys. Main charges never
     carry `type: "upsell"`.
   - **CI-03 / CI-04 (mobile):** call `Purchases.logIn(appUserId)` right
     after sign-in / account creation and before showing the paywall; call
     `Purchases.logOut()` on sign-out; set `$email` via `setEmail` (or the
     SDK's equivalent). The app must have `appUserId` before purchase — if a
     purchase can happen before an account exists, mint the id first (same
     rule as the Stripe metadata standard).
   - **CI-06:** if using `/saas/v1/checkout/sessions`, call it from the
     server with the `crm_` key, pass `customerEmail`, put the eight
     standard metadata keys in both `stripeOverrides.metadata` and
     `stripeOverrides.subscription_data.metadata`, no `saas_*` keys, and on
     timeout look up the order instead of creating a second session.
   - **CI-07:** separate env vars per environment; a startup or build check
     that a `crm_test_` key is not configured in production.

5. **Test.** Assert: customer create calls include lower-case email; upsell
   PaymentIntent metadata has `type` and `offerId` and main charges don't;
   CRM checkout call includes metadata in both places and no `saas_` key;
   mobile: `logIn` is called with `appUserId` before purchase (unit test the
   auth/purchase flow or the wrapper). Run lint, type-check, tests; report
   failures verbatim.

6. **Verify and report.** Before → after per ID. Manual checks: a test
   purchase shows the email on the Stripe customer; an upsell in test mode
   appears grouped with its order in the CRM transactions page; in
   RevenueCat, a sandbox purchase shows the `appUserId` as the customer id.
   Tell the user plainly:
   - Existing customers created without these fields stay unjoined unless
     backfilled.
   - The CRM does not yet read RevenueCat's nested `$email` attribute and
     does not yet merge `rc_<appUserId>` with the Stripe customer carrying
     the same `metadata.appUserId` — both are CRM-side changes
     (`crm-contract.md` §6).

## Do not

- Use email as the RevenueCat app user id.
- Put product, condition or plan names in offer codes or metadata.
- Overwrite or set `saas_*` metadata keys — the CRM owns them.
- Ship a `crm_test_` key to production or a `crm_` key to a client.
