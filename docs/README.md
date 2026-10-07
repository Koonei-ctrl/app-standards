# App Tracking, Payment & CRM Standard

How every one of our apps handles **ad tracking (the pixel), payments, Stripe
metadata and the CRM connection**. Every app we build follows the same
pattern. Only the framework, URLs, funnel and plans differ.

Read this before building a new app or changing checkout, tracking or
webhooks in an existing one.

| # | Document | Read it when you… |
| --- | --- | --- |
| 1 | [Overview](01-overview.md) | are new here: how the pieces fit, page roles, severity |
| 2 | [Tracking (Syntrix pixel)](02-tracking.md) | add the tracker, fire events, send the server purchase |
| 3 | [Payments](03-payments.md) | build checkout, webhooks, plans, trials, wallets |
| 4 | [Stripe metadata](04-stripe-metadata.md) | create any Stripe object |
| 5 | [CRM integration](05-crm-integration.md) | connect an app to the CRM: webhook, App-data, identity |
| 6 | [Privacy](06-privacy.md) | handle anything personal or sensitive |
| 7 | [New app checklist](07-new-app-checklist.md) | launch a new app or audit an old one |

## How to read it

- **Every rule has an ID** (EV-05, PAY-01, …). Code reviews, audits and the
  skills all refer to these IDs.
- **Severity** says what breaking a rule costs:
  - **Critical:** loses money, loses attribution of real sales, or breaks
    privacy law.
  - **High:** corrupts reporting or breaks a flow for some users.
  - **Medium:** hygiene that prevents future breakage.
- The standard says **what** must be true, not **how** to build it. Use your
  app's own framework and conventions.

## Source of truth

These docs explain the standard for people. The exact wording the skills
check against lives in [`../references/`](../references/):

- [`standard.md`](../references/standard.md): every rule and its ID.
- [`syntrix-contract.md`](../references/syntrix-contract.md): Syntrix wire
  facts, traced from Syntrix code.
- [`crm-contract.md`](../references/crm-contract.md): CRM wire facts, traced
  from CRM code.

If a doc here and `references/` ever disagree, `references/` wins. Fix the
doc in the same change.

## Applying it

You don't have to check all of this by hand. With the skills installed (see
the [main README](../README.md)), ask your coding agent:

```
audit tracking in this app
```

The audit reports every rule as pass, partial, missing or wrong, and names
the skill that fixes each gap.
