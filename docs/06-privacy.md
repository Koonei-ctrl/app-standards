# 6. Privacy

Our funnels can collect sensitive answers (conditions, goals, symptoms). The
whole standard is built so that this data stays in the app's own database
and never reaches ad platforms, Stripe, the CRM, logs or error reports.

## Where data may go

| Data | App DB | Syntrix / ad platforms | Stripe metadata | CRM App-data | Logs / error reports |
| --- | --- | --- | --- | --- | --- |
| Email | Yes | Yes (plaintext; Syntrix hashes it) | On the customer | Yes | Avoid |
| Transaction id, value, currency | Yes | Yes | Yes | Yes | Yes |
| Neutral plan code | Yes | **No** | Yes | Yes | Yes |
| Funnel step number | Yes | Yes (`step`) | **No** | — | Yes |
| Funnel answers, goals, symptoms | Yes | **Never** | **Never** | **Never** | **Never** |
| Descriptive plan or product names | Yes | **Never** | **Never** | Plan code only | Avoid |
| Page URLs | Yes | Only neutral ones (by the tracker); never sent by hand | **No** | — | Yes |
| Buyer IP address | As needed | Server purchase only | `ipAddress` | — | Avoid |
| Secrets and keys | Server env only | **Never** | **Never** | **Never** | **Never** |

"—" = the standard has no rule for it; use judgement. "Avoid" is guidance, not a rule.

## Rules

| ID | Rule | Severity |
| --- | --- | --- |
| PV-01 | The Stripe secret, Stripe webhook secret, Syntrix store secret, CRM product API key and CRM webhook secret never reach a browser bundle or mobile binary, and are never logged | Critical |
| PV-02 | Funnel answer content is never logged, error-reported or sent to any third party | Critical |
| PV-03 | EU traffic: a DPA with Syntrix covering the data category | Critical (EU) |

These rules elsewhere protect the same data:

- **Revealing URLs** keep the tracker out (EV-02, EV-11). See
  [Overview](01-overview.md#neutral-vs-revealing-urls).
- **Only allowed fields** go to Syntrix (EV-09).
- **Product analytics** stores ids and answer positions, never answer text
  (EV-16).
- **Stripe metadata** holds nothing sensitive (MD-04).
- **App-data** returns support data only (AD-06).
- **Neutral names**: statement descriptor, product names, plan codes and
  offer codes (PAY-12, MD-08).

## In practice

- Name funnel routes by position (`/start/step-3`), not by topic.
- Store answers as question id + answer **position**. Show text from your own
  content, not from the analytics record.
- Strip sensitive fields from error-reporting payloads (Sentry `beforeSend`
  or similar), and never log full request bodies on funnel routes.
- Keep every secret in server env. Check that no secret-named variable
  carries a public prefix (`NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_`…).
