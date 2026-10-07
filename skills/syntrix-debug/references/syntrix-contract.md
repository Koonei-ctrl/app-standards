# Syntrix contract

What an app integrating Syntrix needs to know about what Syntrix actually
does on the wire: tracker, browser ingest, server (S2S) ingest, dedup and
forwarding. The standard
(`standard.md`, EV- / SX-) says *what* an app must do; this file gives the
facts needed to build and debug it. Traced from the Syntrix code on
2026-10-07 (commit `e81c4f4`). **Where Syntrix's own `SYNTRIX-INTEGRATION.md`
disagrees, this file follows the code** — that guide has the wrong S2S path,
wrong host, and wrong hold/dedup rules (see §8).

---

## 1. Hosts

| Environment | Host (serves tracker **and** API) |
| --- | --- |
| Production (`production-live`) | `https://tracker.trysyntrix.app` |
| Internal / dogfood (`production-internal`) | `https://syntrix-tracker.lumendeals.com` (likely; confirm with the operator) |

- `api.syntrix.com` is **not** a real host — it only appears in the old guide.
- Tracking routes live at the host root (`/lib/…`, `/track/…`).
  `…/api/v1/track/s2s` is a 404.
- The merchant's **Sources** page in the dashboard shows the exact snippet and
  host for that account — always confirm the host there (SX-01).

## 2. Keys

| Key | Format | Used for |
| --- | --- | --- |
| Store **public key** (`api_keys.key`) | 32 hex chars, no prefix | Browser tracker (`data-api-key`), `POST /track/s2s` and `/track/m` (`X-API-Key`). **The same key for browser and server.** |
| Store **secret** (`api_keys.secret`) | 64 hex chars | Only `Authorization: Bearer` on `/api/v1/events/batch` and `/api/v1/events/webhook`. Most apps never need it |

- The public key has no allowed-origin restriction, no debug flag and no type
  column. It is "public" because it ships in the browser — but apps still keep
  the server relay's copy in server env and never log it.

## 3. Browser tracker

### Install

```html
<script>window.stxq=window.stxq||function(){(window.stxq.q=window.stxq.q||[]).push(arguments)};</script>
<script async src="https://tracker.trysyntrix.app/lib/stxq.min.js" data-api-key="<public key>"></script>
```

- **The stub line is required** if anything calls `stxq(…)` before the
  script finishes loading. The tracker drains `window.stxq.q` after init
  (queued `init` first, then everything else), but it does **not** create the
  stub itself — without it an early call throws `ReferenceError` and is lost
  (EV-12). The Syntrix guide's snippet has no stub.
- Only `GET /lib/stxq.min.js` is served (`/lib/stxq.js` is not).
  `Cache-Control: public, max-age=300`. A legacy `/tracker.js` (`ppLayer`
  global) still exists — never use it.
- Script tag attributes read: `data-api-key` (or `?id=` on the src) and
  `data-debug="true"`. **The ingest host is derived from the script src**
  (src minus `/lib/stxq.min.js`); there is no `data-endpoint`.

### Commands (`window.stxq`)

| Command | Effect |
| --- | --- |
| `stxq('init', apiKey, { endpoint, debug, autoTrack, loadPixels })` | Manual init; usually unnecessary (auto-init from the script tag) |
| `stxq('track', eventType, eventData, { skipBrowserPixels })` | Sends one event |
| `stxq('identify', userId, traits)` | Sets the user id for later events; sends an `Identify` event only if `traits` is given |
| `stxq('debug', true \| false)` | Toggles console logging |

There is **no `consent` command** and no TCF / GPC / Consent Mode handling.

### What `track` sends

`POST <host>/track/e`, body `text/plain` JSON (no CORS preflight),
`fetch` normally, `sendBeacon` during unload / SPA navigation.

- PII (`email`, `phone`, `externalId` / `external_id`) goes **inside
  `eventData`** — the browser path has no `userData` object.
- Page keys (`pageUrl`, `pageTitle`, `url`, `path`, `referrer`, …) are pulled
  out of `eventData` into the `page` block.
- Every event gets a fresh `eventId = evt_stx_<time36>_<rand>`, shared with
  the browser pixels fired for it. An `eventId` you put in `eventData` is not
  used.
- The body also carries anonymous id, session id, fingerprint, device, UTMs,
  click ids, **all of `document.cookie`**, and current URL params.

### Automatic behaviour

- `page_view` on load (after `/track/config`) and on `history.pushState` /
  `popstate`. **Not** on `replaceState` or `hashchange`.
- **No automatic `session_start`** — the standard's `session_start` is a
  custom event the app fires.
- Captures click ids (fbclid, gclid, msclkid, ttclid, twclid, li_fat_id,
  rdt_cid, epik persisted 7 d; wbraid/gbraid/dclid etc. URL-only), UTMs from
  the current URL, a 30-day `_stx_attribution` cookie of all landing URL
  params (cleared on purchase), and reads `_fbc`/`_fbp`/`_gcl_*`/`_ga`/`_ttp`
  etc. It does not write `_fbc`/`_fbp`. Apps build none of this (EV-13).
- First-party cookies on the root domain: `_stx_aid` (365 d), `_stx_fp`
  (fingerprint, 365 d), `_stx_sid` (**24 h fixed session**, rotated after a
  purchase), `_stx_ga4_*`.
- On init it calls `GET /track/config?id=<key>` and loads the browser pixels
  the merchant configured (Meta, GA4, Google Ads, TikTok, Snapchat, Bing,
  Pinterest, GTM, Klaviyo, Clarity, custom JS). Every `track` call fires them
  too, in plaintext advanced matching.
- No client-side dedup by `transaction_id`. Firing `purchase` twice in the
  browser sends it twice; dedup happens on the server (§5) — but apps still
  guard it (EV-05).

### Debug

`data-debug="true"`, `init(key, { debug: true })` or `stxq('debug')` → logs
`[Syntrix] …` to the console. `window.__stxDebug` holds the pixel config and
the last 50 fires per pixel. There is **no** debug switch in the dashboard's
API-key settings.

## 4. Server ingest (S2S)

```
POST https://tracker.trysyntrix.app/track/s2s
X-API-Key: <store public key>
Content-Type: application/json

{
  "eventType": "purchase",
  "eventData": { "transaction_id": "sub_…", "value": 29.99, "currency": "USD" },
  "userData":  { "email": "buyer@example.com", "externalId": "cus_…", "country": "US",
                 "ipAddress": "203.0.113.7", "userAgent": "…" },
  "sourceUrl": "https://example.com/checkout",
  "timestamp": "2026-10-07T10:00:00Z"
}
```

- Only `eventType` is required. `userData` accepts `email`, `phone`,
  `firstName`, `lastName`, `externalId` (/`external_id`/`customer_id`),
  `city`, `state`, `country`, `zip`, `ipAddress`, `userAgent` and click ids
  (`fbc`, `fbp`, `gclid`, `fbclid`, `msclkid`, `ttclid`, …).
- Order id is read from `eventData.transaction_id` (then `transactionId`,
  `order_id`, `orderId`, `order_number`, `orderNumber`).
- `sourceUrl` becomes the page URL — the standard requires a fixed neutral
  constant.
- `timestamp` sets the event time; omit it and Syntrix uses `now − 5 min`.
- IP precedence: top-level `ipAddress` → the matched browser event's IP → 
  `userData.ipAddress` → request headers. From a Stripe webhook, **never send
  the webhook request's own IP**; send the buyer's IP (Stripe metadata
  `ipAddress`) in `userData.ipAddress` so the browser match wins when it
  exists.
- Syntrix enriches the server event with IP / UA / click ids from a browser
  event matched by `transaction_id`, else same email within 24 h, else same
  IP within 24 h.
- `body.eventId` is ignored. Use `dedupeKey` for exact-match dedup if needed.

### Responses

| Case | Status | Body |
| --- | --- | --- |
| Accepted (held) | **202** | `{ success: true, queued: true, pendingId, processAfter }` |
| Missing key | 401 | `{ success: false, error: { code: "UNAUTHORIZED", … } }` |
| Unknown key | 401 | `… "Invalid API key"` |
| No `eventType` | 400 | `BAD_REQUEST` |
| Malformed JSON | **500** (not 400) | `SERVER_ERROR` |
| Rate limit | 429 | `RATE_LIMIT_EXCEEDED`, `retryAfter` — 10 000 req / 60 s per key |

A relay treats 2xx as done, retries 5xx/429/network errors within its time
budget, and never retries 4xx (SX-04).

`/track/s2s` is server-to-server only: browser CORS does not allow
`X-API-Key`.

## 5. Hold and dedup

- **Every** S2S event — whatever its type — is held
  `S2S_PROCESSING_DELAY_MS` (default **5 min**) before processing. That is why
  the standard allows a server copy only for `purchase` (EV-08): other server
  events just arrive 5 minutes late.
- Purchase family (`purchase`, `purchase_main`, `purchase_upsell`): deduped
  on merchant + `transaction_id` + event type, **whichever copy is stored
  first wins**. The browser copy wins only if it lands within the hold. A
  browser `purchase` arriving after the server one is the duplicate.
- `begin_checkout`: browser copies dedup per session; server copies dedup on
  same email within 30 min.
- Duplicates are stored with `isDuplicate = true` and never forwarded.
- So `transaction_id` must be byte-identical on both copies (the Stripe
  subscription id, EV-05/06).

## 6. Events, aliases, forwarding

- Canonical names: `page_view, view_item, search, add_to_cart,
  add_to_wishlist, begin_checkout, add_payment_info, purchase, purchase_main,
  generate_lead, sign_up, contact, subscribe, submit_application,
  select_item, donate, find_location, schedule, view_upsell,
  purchase_upsell, view_thank_you, cart_recovery_opened,
  begin_recovery_checkout`.
- `/track/e` and `/track/s2s` accept any name; unknown names are stored as
  `custom` and still forwarded under their raw name (custom events such as
  `session_start`, `funnel_step_completed` work).
- **Aliases differ by path.** The browser maps `Lead`/`lead` →
  `generate_lead`, `InitiateCheckout` → `begin_checkout`, etc. The S2S path
  does not (`lead` stays `lead`). Always send canonical snake_case names.
- Forwarding uses the raw name: per-destination `eventMappings` first (if a
  destination has mappings and the event isn't listed, it is **skipped** for
  that destination), else the default map (`purchase` → Meta `Purchase`,
  Klaviyo `Placed Order`, GA4 `purchase`).
- Email/phone are hashed at dispatch (lower-case + trim + SHA-256). There is
  no "already hashed" check: a pre-hashed email is hashed twice and never
  matches (EV-14).
- No consent field on ingest.

## 7. Mobile

`POST /track/m` with `X-API-Key: <public key>` (native SDK path). Same key as
web. Not covered by the standard yet.

## 8. Where Syntrix's own guide is wrong

| Guide says | Code does |
| --- | --- |
| Host `api.syntrix.com`, S2S at `/api/v1/track/s2s` | `tracker.trysyntrix.app`, `/track/s2s` (no `/api/v1`) |
| Only server `purchase`/`begin_checkout` are held | Every S2S event is held 5 min |
| Browser copy always wins | First stored wins; browser wins only inside the hold |
| Server `begin_checkout` dedups by session | By email within 30 min |
| Set your own matching `eventId` on both sides | S2S `eventId` is ignored; Meta gets `s2s_<transaction_id>` |
| Snippet with no stub | Early `stxq()` calls throw without the stub (§3) |
| Debug mode in API-key settings | Only `data-debug`, `init` option, or `stxq('debug')` |
| Browser PII "in `userData`" | Browser: inside `eventData`; only S2S has `userData` |
| `lead` is an alias of `generate_lead` | Browser path only |
