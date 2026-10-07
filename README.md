# app-standards

AI coding skills that check and fix any of our apps against one standard for
**Syntrix tracking, Stripe payments, Stripe metadata and CRM integration**.

Stripe, Syntrix and the CRM are the same in every app. Everything else
(framework, backend, database, URLs) is different, and the skills discover it
in each repo. They work in any coding agent that supports
[Agent Skills](https://agentskills.io) (`SKILL.md`): Claude Code, Codex,
Cursor, GitHub Copilot, Gemini CLI, Windsurf, Antigravity, OpenCode, Roo,
Kiro and more.

> Written for our own developers and our own stack. It's public so it's easy
> to install anywhere. The CRM skills only work with our CRM.

## Read the standard

The standard every app follows, written to be read by people:

| # | Document | Covers |
| --- | --- | --- |
| 1 | [Overview](docs/01-overview.md) | How Stripe, Syntrix and the CRM fit together; page roles; severity |
| 2 | [Tracking (Syntrix pixel)](docs/02-tracking.md) | Tracker install, event flows A–D, allowed data, server purchase, dedup, consent |
| 3 | [Payments](docs/03-payments.md) | Access via webhook only, plan types, trials, discounts, wallets |
| 4 | [Stripe metadata](docs/04-stripe-metadata.md) | The eight keys, which object gets what, upsells |
| 5 | [CRM integration](docs/05-crm-integration.md) | Webhook receiver, App-data endpoint, customer identity |
| 6 | [Privacy](docs/06-privacy.md) | What data may go where |
| 7 | [New app checklist](docs/07-new-app-checklist.md) | Step-by-step checklist for every new app |

Start with [`docs/`](docs/README.md). The skills below apply the same
standard to your code.

- [Read the standard](#read-the-standard)
- [Install](#install)
- [Quick start](#quick-start)
- [How to call a skill](#how-to-call-a-skill)
- [The skills](#the-skills)
- [Maintaining this repo](#maintaining-this-repo)

---

## Install

Choose where to install:

| | Global | Project |
| --- | --- | --- |
| Installed in | your home folder | the app repo, committed to git |
| Works in | every repo you open | only that repo |
| Who gets it | only you | everyone who clones the repo |
| Updating | once per machine | once per app repo |
| Best for | your own work across all our apps | sharing with the team: no setup, same version for everyone |

You can do both. If a skill is installed in both places, the project copy
usually wins.

### Any tool: the `skills` CLI (recommended)

[`skills`](https://github.com/vercel-labs/skills) installs into 70+ agents and
asks which ones you use.

**Global:**

```bash
npx skills add Koonei-ctrl/app-standards -g
```

**Project:** run this in the app repo's root, then commit what it creates:

```bash
npx skills add Koonei-ctrl/app-standards --copy
git add .agents .claude   # plus any other tool folders it created
git commit -m "Add app-standards skills"
```

`--copy` writes real files instead of symlinks, so the commit works for
everyone who clones the repo.

Use your package manager's runner if you prefer. The command is the same:

| Package manager | Global | Project |
| --- | --- | --- |
| npm | `npx skills add Koonei-ctrl/app-standards -g` | `npx skills add Koonei-ctrl/app-standards --copy` |
| Bun | `bunx skills add Koonei-ctrl/app-standards -g` | `bunx skills add Koonei-ctrl/app-standards --copy` |
| pnpm | `pnpm dlx skills add Koonei-ctrl/app-standards -g` | `pnpm dlx skills add Koonei-ctrl/app-standards --copy` |
| Yarn (v2+) | `yarn dlx skills add Koonei-ctrl/app-standards -g` | `yarn dlx skills add Koonei-ctrl/app-standards --copy` |

Yarn 1 has no `dlx`, so use `npx` there. The examples below use `npx`.
Swap in your runner the same way.

Install for specific tools only, without prompts:

```bash
# global
npx skills add Koonei-ctrl/app-standards -g -a claude-code -a cursor -a codex -y
# project
npx skills add Koonei-ctrl/app-standards --copy -a claude-code -a cursor -a codex -y
```

Agent names include `claude-code`, `codex`, `cursor`, `github-copilot`,
`gemini-cli`, `windsurf`, `antigravity`, `opencode`, `roo`, `kiro-cli`, `amp`
and `cline`. To update, run the same command again. For a project install,
commit the result.

### Claude Code: plugin (gets updates)

**Global:** run in Claude Code:

```
/plugin marketplace add Koonei-ctrl/app-standards
/plugin install app-standards@app-standards
```

**Project:** add this to the app repo's `.claude/settings.json` and commit it.
When a teammate opens the repo and trusts the folder, Claude Code offers to
install the plugin:

```json
{
  "extraKnownMarketplaces": {
    "app-standards": {
      "source": { "source": "github", "repo": "Koonei-ctrl/app-standards" }
    }
  },
  "enabledPlugins": {
    "app-standards@app-standards": true
  }
}
```

Only the settings file goes into the repo, not the skills, so everyone stays
on the latest version. Update with `/plugin marketplace update app-standards`.

### Manual copy

Copy every folder under `skills/` into your tool's skills folder. Copy whole
folders, because each skill keeps its `references/` inside it.

**Global:**

```bash
git clone https://github.com/Koonei-ctrl/app-standards.git ~/app-standards
mkdir -p ~/.claude/skills   # use the global folder from the table
cp -R ~/app-standards/skills/* ~/.claude/skills/
```

**Project:** run in the app repo's root, then commit:

```bash
git clone https://github.com/Koonei-ctrl/app-standards.git /tmp/app-standards
mkdir -p .agents/skills     # use the project folder from the table
cp -R /tmp/app-standards/skills/* .agents/skills/
git add .agents && git commit -m "Add app-standards skills"
```

`.agents/skills/` is read by Codex, Cursor, Copilot, Gemini CLI, Antigravity
and OpenCode. Claude Code, Windsurf, Roo and Kiro need their own folder, so
copy the skills there as well if your team uses those tools.

| Tool | Global (all your projects) | Project (this repo only) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex (CLI / IDE) | `~/.codex/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` |
| GitHub Copilot (VS Code / CLI) | `~/.copilot/skills/` | `.agents/skills/` |
| Gemini CLI | `~/.gemini/skills/` | `.agents/skills/` |
| Antigravity | `~/.gemini/antigravity/skills/` | `.agents/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` | `.windsurf/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.agents/skills/` |
| Roo Code | `~/.roo/skills/` | `.roo/skills/` |
| Kiro | `~/.kiro/skills/` | `.kiro/skills/` |

Restart the tool (or open a new chat) after copying. To update, pull this
repo and copy again. For a project install, commit the result.

### Claude.ai / Claude Desktop

Zip a single skill folder (e.g. `skills/tracking-audit/`) and upload it under
**Settings → Capabilities → Skills**. This is only useful for
`syntrix-guide` and `syntrix-reports`. The other skills need your code, so use
a coding agent for them.

### Tools without skill support

If your tool can't load skills (for example a browser-based app builder), point it
at the file directly:

> Read `skills/tracking-audit/SKILL.md` and the files in
> `skills/tracking-audit/references/`, then follow the steps on this repo.

Results are less reliable than in a tool that loads skills.

---

## Quick start

Open the app's repo in your agent and ask:

```
audit tracking in this app
```

You get a report: what's done, partial, missing or wrong, the top risks, and
which skill fixes each gap. Then run the fixers it names, one area at a time,
and run the audit again:

```
tracking-audit → fixers (syntrix-setup, stripe-metadata, payment-standard,
crm-webhook, crm-app-data, crm-identity) → tracking-audit
```

Skills that change code **always show a plan and wait for your OK** before
editing. They work in Stripe **test mode** only.

---

## How to call a skill

Skills load automatically when your request matches what they do. You don't
have to name them: "why is Meta not getting purchases?" loads `syntrix-debug`.

To pick one explicitly:

| Tool | How |
| --- | --- |
| Claude Code | `/tracking-audit` (or any skill name) |
| Codex | `$tracking-audit`, or pick it from `/skills` |
| Any tool | Name it in the request: "use the tracking-audit skill on this repo" |

If a skill doesn't trigger, name it. If the wrong one triggers, name the one
you want.

---

## The skills

| Skill | What it does | Edits code? |
| --- | --- | --- |
| [`tracking-audit`](#tracking-audit) | Checks the whole standard and writes a report for the product owner | No |
| [`syntrix-setup`](#syntrix-setup) | Installs or fixes the Syntrix tracker, events and the server purchase fallback | Yes, after you confirm |
| [`stripe-metadata`](#stripe-metadata) | Puts the eight standard metadata keys on every Stripe object, with a test | Yes, after you confirm |
| [`payment-standard`](#payment-standard) | Checks and fixes webhook, payment methods, plan types, trials, discounts | Yes, after you confirm |
| [`crm-webhook`](#crm-webhook) | Builds or fixes the endpoint that receives the CRM's signed Stripe events | Yes, after you confirm |
| [`crm-app-data`](#crm-app-data) | Builds or fixes the App-data endpoint the CRM calls for a customer's app context | Yes, after you confirm |
| [`crm-identity`](#crm-identity) | Email, Stripe customer id, upsell markers, RevenueCat `logIn`, CRM checkout API | Yes, after you confirm |
| [`syntrix-guide`](#syntrix-guide) | Answers "how does Syntrix do X" and writes small Syntrix snippets | No |
| [`syntrix-debug`](#syntrix-debug) | Follows an event hop by hop to find where it's lost | No |
| [`syntrix-reports`](#syntrix-reports) | Drafts `.syntrix-report.json` files to import into the Syntrix dashboard | No (writes a report file) |

Every requirement has an ID: **EV** events, **SX** Syntrix config, **PAY**
payments, **MD** Stripe metadata, **WH** CRM webhook, **AD** CRM App-data,
**CI** CRM identity, **PV** privacy. Reports and plans refer to these IDs, and
[`references/standard.md`](references/standard.md) defines them.

### tracking-audit

Read-only check of one app against the whole standard.

- **Use it:** before paid traffic goes to an app, after big checkout changes,
  or to find out where an app stands.
- **Ask:**
  - "audit tracking in this app"
  - "is this app connected to the CRM properly?"
  - "audit only payments" (areas: `events`, `syntrix`, `payments`,
    `metadata`, `crm`, `privacy`)
- **You get:** a Markdown report: a verdict, a pass/partial/missing/wrong
  count per area, top risks in business terms, a check of each flow, items to
  check outside the code (Stripe dashboard, Syntrix, CRM, RevenueCat), and
  `file:line` evidence for every requirement. It's saved outside the repo
  unless you ask otherwise.
- **Next:** run the fixer skill the report names for each gap.

### syntrix-setup

Installs or fixes Syntrix tracking (EV, SX).

- **Use it:** a new app needs tracking, or the audit shows EV/SX gaps.
- **Ask:**
  - "set up Syntrix in this app"
  - "begin_checkout isn't firing on the paywall"
  - "add the server purchase fallback"
- **What it does:** maps your pages (landing, funnel, paywall, offer,
  success, logged-in app) and decides where the tracker may load. Then it
  wires each event at the right moment with only the allowed fields, and adds
  the server `purchase` from the Stripe webhook. It adds tests that lock the
  payloads.
- **Have ready:** the Syntrix host and public-key env var names. It never
  needs the key values.
- **Next:** `syntrix-debug` to verify live, `syntrix-reports` for dashboards.

### stripe-metadata

Puts the same eight metadata keys on every Stripe object, on every checkout
path (MD).

- **Use it:** Stripe rows can't be matched to your orders, metadata is missing
  on subscriptions, or the audit shows MD gaps.
- **Ask:**
  - "fix Stripe metadata"
  - "metadata is missing on the subscription"
- **What it does:** finds every place a customer, subscription, intent or
  checkout session is created (hosted, built-in, CRM API, upsells) and shows a
  matrix of objects by path. It builds the metadata once per checkout, moves
  anything sensitive out, and adds a test that asserts the exact key set.
- **Decide with it:** where `appUserId`, `orderId`, country, language and
  funnel session id come from in this app.

### payment-standard

Checks and fixes the payment flow (PAY).

- **Use it:** access isn't granted after payment, a free trial doesn't bill,
  Apple Pay or Google Pay doesn't show, or the audit shows PAY gaps.
- **Ask:**
  - "check the payment flow"
  - "free trial isn't charging after it ends"
  - "Apple Pay button doesn't appear"
- **What it does:** confirms that access is granted only by a verified,
  idempotent webhook. It walks each plan type (upfront, free trial, paid
  trial) through the code, and checks wallets, currency, discounts and the
  statement descriptor. It flags anything that affects existing subscribers
  before changing it.
- **Next:** it ends with a test-mode script: one purchase per plan type, and
  a trial test clock advanced to the end.

### crm-webhook

Builds or fixes the endpoint that receives Stripe events forwarded by the CRM
(WH).

- **Use it:** connecting an app to the CRM, CRM deliveries failing, or moving
  from a direct Stripe webhook to the CRM relay.
- **Ask:**
  - "set up the CRM webhook"
  - "CRM test ping fails"
  - "move our Stripe webhook to the CRM relay"
- **What it does:** verifies `X-CRM-Signature` on the raw body. Stripe's SDK
  can't verify it, so don't try. It handles each event once, shared with any
  direct Stripe webhook, answers quickly, and returns status codes that match
  the CRM's retry rules. It adds signed-body tests.
- **Operator steps it lists:** save the URL on the product's Integration page
  in the CRM, put the `whsec_…` secret in env, press "Send test ping".

### crm-app-data

Builds or fixes the endpoint the CRM calls to show "App context" for a
customer (AD).

- **Use it:** support wants app info in the CRM, or the CRM shows
  `invalid_response`, timeout or `no_api_key`.
- **Ask:**
  - "add the app-data endpoint for the CRM"
  - "CRM app context panel shows invalid_response"
- **What it does:** first agrees with you what the panel shows (2–4
  sections, nothing sensitive). Then it builds a bearer-key endpoint that
  looks users up by `cus_…`, `rc_…` or email, returns 404 for unknown users,
  and matches the CRM's envelope schema. It adds tests that validate against
  that schema.

### crm-identity

Makes the app record identity so the CRM can join one person's web, mobile
and tracking records (CI, MD-08).

- **Use it:** customers are duplicated in the CRM, web and app subscribers
  aren't merged, upsells aren't grouped with their order, or you're setting up
  RevenueCat.
- **Ask:**
  - "customers are duplicated in the CRM"
  - "upsells don't show with the main order"
  - "check our RevenueCat logIn"
- **What it does:** sets the email on every Stripe customer and guest charge,
  stores the Stripe customer id on the user, and marks upsells with
  `type`/`offerId`. On mobile it calls RevenueCat `logIn(appUserId)` before any
  purchase. Fixes apply to new customers only, and it tells you how many
  existing records stay unjoined.

### syntrix-guide

Answers questions about how Syntrix behaves, from facts traced from its code.

- **Use it:** any "how does Syntrix…" question, or a small snippet outside a
  full setup.
- **Ask:**
  - "what's the S2S endpoint and which key goes where?"
  - "why does my server purchase show up 5 minutes late?"
  - "can I set my own eventId?"
- **Note:** Syntrix's own `SYNTRIX-INTEGRATION.md` is wrong on the S2S path,
  host, hold and dedup. This skill follows the code, and
  [`references/syntrix-contract.md`](references/syntrix-contract.md) §8 lists
  the differences.

### syntrix-debug

Finds where an event is lost: tracker load → config → browser or S2S ingest →
5-minute hold → dedup → mappings → destination.

- **Use it:** a purchase doesn't show in Syntrix or Meta, events are doubled,
  you get 401/404 from Syntrix, or you're verifying a setup live.
- **Ask:**
  - "purchase isn't showing in Syntrix"
  - "Meta is getting double purchases"
  - "server purchase never arrives"
- **You get:** a table of each hop with its status and evidence, the root
  cause in one sentence, and who fixes it (the app via `syntrix-setup`, or the
  Syntrix operator). It asks you to check the network tab and the Syntrix
  dashboard where needed.

### syntrix-reports

Turns a question into a report file you import into Syntrix.

- **Use it:** you want a funnel, conversion, revenue or cohort report.
- **Ask:**
  - "where do people drop off before the paywall?"
  - "revenue by campaign"
  - "funnel report for our quiz, split by iOS/Android"
- **You get:** a `<name>.syntrix-report.json` file. Import it in Syntrix:
  **Reports** → drag the file onto the page → pick a date range → run. Ready
  examples are in
  [`skills/syntrix-reports/examples/`](skills/syntrix-reports/examples/).
- **Watch out:** metric reports count `purchase` twice (browser and server
  copies). For order counts and revenue, the skill uses attribution or funnel
  reports.
- **Replaces** the older `syntrix-report-builder` skill, so uninstall that one.

---

## Maintaining this repo

The single source of truth is the root [`references/`](references/) folder:

| File | Holds |
| --- | --- |
| [`standard.md`](references/standard.md) | Every requirement and its ID, flows, allowed fields, metadata keys |
| [`syntrix-contract.md`](references/syntrix-contract.md) | Syntrix hosts, keys, tracker, S2S, hold, dedup, traced from Syntrix code |
| [`crm-contract.md`](references/crm-contract.md) | CRM headers, signing, payloads, timeouts, traced from CRM code |
| [`discovery.md`](references/discovery.md) | How a skill maps an unknown app |

Each skill carries copies in `skills/<name>/references/`, because most tools
install a skill folder on its own. **Never edit the copies.** To change the
standard:

1. Edit the file in root `references/`.
2. Run `scripts/sync-references.sh` to refresh the copies.
3. Update the matching page in [`docs/`](docs/) so the readable version
   says the same thing.
4. Bump `version` in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json).
5. Commit and push. Developers get it on their next update.

`scripts/sync-references.sh --check` fails if any copy is out of date. Run it
in CI or a pre-commit hook.

When the CRM or Syntrix changes, update its contract file with the commit you
traced it from.
