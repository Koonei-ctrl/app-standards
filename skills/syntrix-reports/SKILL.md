---
name: syntrix-reports
description: Draft Syntrix report config files (.syntrix-report.json — funnel, metric, cohort or attribution) that the app owner imports into the Syntrix dashboard by drag-and-drop, built on the events this app sends under the standard (session_start, funnel_started, funnel_step_completed with step, generate_lead, funnel_completed, begin_checkout, purchase, recovery events). Use when asked to "make a Syntrix report", "funnel report for our quiz", "where do people drop off", "checkout conversion report", "revenue by campaign in Syntrix", "build a report JSON", "import a report into Syntrix", or after `syntrix-setup` to give the owner ready-made reports.
---

# Syntrix reports

Turns a plain question ("where do people drop off before the paywall?") into
a report config file the app owner imports into Syntrix. **No data is
queried and no API is called** — the output is a JSON file; Syntrix runs it
after import.

Schemas here are traced from Syntrix's report validators and engines
(2026-10-07, commit `e81c4f4`). They replace the older standalone
`syntrix-report-builder` skill, which is missing `os`, funnel-wide filters,
`landing_page`, granularity `all`, and the traps below.

## Inputs

- Standard: `references/standard.md` (in this skill's folder) — Event flows and Allowed
  Syntrix fields. These are the events reports can count.
- Examples: `examples/*.syntrix-report.json` next to this file — valid,
  import-ready starting points for the standard flows.
- If the repo is available: the app's Syntrix call sites (from
  `syntrix-setup` / `discovery.md` §3), to confirm which events and `step`
  numbers it really fires, and whether the funnel is tracked at all (EV-02).
- Otherwise ask the owner to open **Reports → any builder → event picker**
  in Syntrix and paste the list. Custom events appear there as
  `custom:<name>`.

## Steps

1. **Pin the question** to one report type (table below). If it doesn't fit
   one, say so instead of forcing it.
2. **Confirm the events exist** for this app (repo or event picker). Never
   reference an event or `step` value you haven't seen.
3. **Start from the closest example**, adjust, and check every value against
   the enums below.
4. **Write the file** as `<slug>.syntrix-report.json` (scratchpad, or where
   the user asks — not in the app repo unless asked), and tell the owner:
   Syntrix → **Reports** → drag the file onto the page (or **Import**) →
   pick a date range → run. If import shows an error, paste it back.
5. **List the caveats** that apply to this report (see Traps).

## Envelope

```json
{
  "syntrixReportExport": "v1",
  "report": {
    "reportType": "funnel",
    "name": "Funnel to purchase",
    "description": "One line on what it answers and any caveat",
    "config": { },
    "templateId": null
  }
}
```

- `reportType`: `funnel` | `metric` | `cohort` | `attribution`.
- `name` ≤ 120 chars, specific. A name already used in the store gets
  "(imported)" appended, so re-importing is safe.
- **Never put `from` / `to` in `config`** — a report is a definition; the
  date range is picked when it runs.

## Event names in configs

| App sends (standard) | Reference it as |
| --- | --- |
| `generate_lead`, `begin_checkout`, `purchase`, `cart_recovery_opened`, `begin_recovery_checkout`, `page_view` | the name as-is |
| `session_start`, `funnel_started`, `funnel_step_completed`, `funnel_completed`, any other app-specific name | `custom:<name>` |
| A field in the event data (e.g. `step` on `funnel_step_completed`) | filter `{ "field": "custom_data", "key": "step", "op": "eq", "value": "3" }` — value always a string |

Cohort and attribution need the exact form: a standard name with `custom:`,
or a custom name without it, matches nothing (attribution with a misspelled
standard name fails when run). Funnels are more forgiving, but use the same
forms everywhere.

## Report types

Filters everywhere: `{ "field", "op": "eq" | "contains" | "starts_with", "value": "<string>", "key"?: "<custom_data key>" }`.
`eq` and `starts_with` are **case-sensitive**; `contains` is not.

### funnel — ordered drop-off

```json
{
  "steps": [
    { "eventType": "custom:funnel_started", "label": "Started" },
    { "eventType": "begin_checkout", "label": "Saw prices" }
  ],
  "groupBy": "session",
  "filters": [],
  "timeWindowHours": null,
  "breakdown": "os"
}
```
- `steps`: 2–25, strict order (step N after step N−1). ≤ 5 filters per step.
- `filters` (optional): ≤ 5, applied to **every** step — use for "this funnel
  for one market / campaign" instead of repeating a filter per step.
- Filter fields: `page_url`, `country`, `device_type`, `os`, `utm_source`,
  `utm_medium`, `utm_campaign`, `custom_data`.
- `groupBy`: `session` | `visitor` | `identity`.
- `timeWindowHours`: 1–2160 or `null`.
- `breakdown` (optional): `country` | `device_type` | `os` | `utm_source` |
  `utm_medium` | `utm_campaign`. `os` = iOS / Android / Windows / macOS;
  `device_type` = desktop / mobile / tablet.
- Excludes duplicate events; reports revenue at the last step, per currency.

### metric — a number, over time or split

```json
{
  "metric": "unique_visitors",
  "dimension": "landing_page",
  "granularity": "all",
  "filters": [],
  "viz": "table",
  "dimensionLimit": 20
}
```
- `metric`: `event_count` | `unique_visitors` | `unique_identities` |
  `sum_value` | `avg_value`.
- `dimension`: `none` | `event_type` | `platform` | `country` |
  `device_type` | `os` | `landing_page` | `utm_source` | `utm_medium` |
  `utm_campaign`. `landing_page` = the page the visit started on, query
  string stripped. `platform` = `web` / `ios` / `android`.
- `granularity`: `day` | `week` | `month` | `all` (one bucket — use `all`
  for any unique count over a period; summing daily uniques double-counts).
- Filter fields: `event_type`, `platform` (`app` = any non-web), `page_url`,
  `country`, `device_type`, `utm_source`, `utm_medium`, `utm_campaign`,
  `custom_data`. ≤ 10 filters.
- `viz`: `table` | `line` | `bar` | `big_number`. `dimensionLimit` 1–100.

### cohort — return behaviour by entry period

```json
{ "cohortEvent": "generate_lead", "returnEvent": "purchase", "granularity": "week", "periods": 8, "valueType": "percent" }
```
- `granularity`: `day` | `week` | `month`; `periods` 1–60;
  `valueType`: `count` | `percent` | `revenue`.
- Subjects are identified people only (anonymous events don't count).

### attribution — credit by channel

```json
{ "conversionEvent": "purchase", "model": "last_touch", "metric": "revenue", "dimension": "utm_campaign", "limit": 20 }
```
- `model`: `first_touch` | `last_touch` | `linear`; `metric`: `conversions`
  | `revenue`; `dimension`: `source` | `medium` | `campaign` |
  `utm_source` | `utm_medium` | `utm_campaign`; `limit` 1–100.
- Excludes duplicates. **The right report for revenue or order counts.**

## Traps — check every config against these

- **Metric reports count duplicates.** Our apps send every `purchase` from
  the browser *and* the server; Syntrix stores both (one flagged duplicate)
  and the metric engine doesn't skip it. A metric of `purchase` count or
  `sum_value` reads ~2× real. Use **attribution** (or a funnel's last-step
  revenue) for orders and revenue; use metrics for visitors and non-purchase
  events. The same applies to cohort `valueType: "revenue"`.
- **Silent filters.** Import doesn't check filter fields. A misspelled field,
  or `custom_data` without `key`, is ignored — the report runs unfiltered
  and looks plausible. Double-check each one.
- **Custom events in metrics.** A metric `event_type` filter matches the
  custom name only on the fast path (count/unique metrics with no `country`,
  `platform` or `custom_data` filter or dimension); otherwise it reads 0. Use
  a funnel for custom events.
- **Metric `country` filter** reads the event's country, which is often
  empty; the `country` *dimension* falls back to the visit's. Filter funnels
  by country, or split a metric by it, rather than filtering a metric.
- **Untracked funnel.** If the app's funnel URLs are revealing, the tracker
  isn't in the funnel (EV-02): no `funnel_*` events exist. Build landing →
  `begin_checkout` → `purchase` instead.
- **Branches.** A step only some visitors see reads as drop-off. Funnel only
  the steps everyone passes, or one funnel per branch.
- **Substring traps.** `contains "/start"` also matches `/start-over`. Use
  `eq` or a longer value.
- **Purchases that don't reach the browser** (closed tab, blocked script) are
  still sent to the ad platforms by the server copy, but a session funnel may
  not show them. Funnel purchase counts are a floor; Stripe is the truth.
- **Renewals aren't events.** The standard sends `purchase` once per
  subscription, so cohort "repeat purchase" stays near zero by design.
- Recovery: there is no marker on a purchase after a recovery checkout, so
  stop the recovery funnel at `begin_recovery_checkout` — adding `purchase`
  counts unrelated orders.

## Do not

- Add API calls, curl, or keys to the output — import is by file only.
- Put plan names, answers or other sensitive values in filters or names
  (they don't exist in Syntrix data anyway — EV-09).
- Invent enum values, events or `step` numbers.
