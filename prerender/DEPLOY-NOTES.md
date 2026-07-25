# ⚠️ onyxour.com — Hosting, Deploy & SEO Prerender (updated 2026-07-25)

## Correction: the root site is NOT on GitHub Pages

The root marketing site **`onyxour.com` is served by VPS1 nginx** (`204.168.192.40`) from `/var/www/html/index.html`, with **Cloudflare (Full Strict)** proxying in front. **Deploy = SCP to VPS1, not `git push`.**

- The repo's `CNAME` and the static `onyxour.html` / `index.html` are **legacy** and are **not** in the serving path.
- **VPS2 has no web server** — it never serves the root domain.
- `app.onyxour.com` (PriceScout Mini App) and `vpn.onyxour.com` (x-ui) are separate hosts, out of scope.

## What the live site actually is

The live page is a **client-side-rendered single-file bundler SPA**: a small shell + a gzipped `__bundler/template` blob that a runtime script unpacks into `blob:` URLs and mounts by `document.documentElement.replaceWith(...)` (React transpiled in-browser by Babel). There is **no source project / package.json** for it anywhere — you cannot bolt on vite-ssg / react-snap.

Consequence: raw HTML alone had **no crawlable content** — Google, Telegram/Twitter/Facebook scrapers, and slow/throttled clients saw only an `Unpacking…` splash.

## The SEO fix (Route A — SPA snapshot), shipped 2026-07-25

Repo directory **`prerender/`** contains a Puppeteer tool that:

1. renders the **source** headlessly (see "Source of truth" below),
2. extracts the real `#dc-root` DOM + styles,
3. neutralizes session-scoped `blob:` / `@font-face`,
4. grafts a **static, styled snapshot** into the raw shell, and injects `<html lang="fa" dir="rtl">` + description / Open Graph / Twitter / canonical meta + standalone favicon `<link>` tags,
5. leaves the bundler machinery **byte-untouched**, so JS clients still get the identical React app (the whole-`<html>` `replaceWith` swap atomically discards the snapshot — verified `#dc-root` == 1, no duplication, no console errors).

Outputs (all deployed to `/var/www/html/`): `index.html`, `robots.txt`, `sitemap.xml`, `og-image.png` (1200×630 brand card), plus the favicon files below.

Commits on `main`: `145aae5` (prerender tooling) and `a288297` (favicons + versioned source). Full steps: `prerender/README.md`.

## 🔑 Source of truth = `prerender/source-live.html` (NOT the live URL)

The build input is the **raw bundler export**, versioned in the repo as `prerender/source-live.html`, rendered via a localhost server.

**Do NOT render from `https://onyxour.com/`** — once the snapshot is deployed, the live URL serves the snapshot, so re-rendering live would "snapshot the snapshot." The build aborts if it detects an already-prerendered file (`__prerender-root`).

## Favicons (fixes Google Search showing no icon)

Google's favicon crawler needs a real, crawlable `/favicon.ico` (it also probes that path directly); a data-URI SVG in `<head>` is not enough. `prerender/favicon.mjs` renders the brand mark (dark rounded square + orange `#FF5C00` ring) into standalone files at the site root:

- `favicon.ico` — multi-size 16/32/48, PNG-embedded
- `favicon-16x16.png`, `favicon-32x32.png`
- `apple-touch-icon.png` — 180×180, opaque (iOS masks it)

`prerender.mjs` injects the `<link rel="icon">` / `<link rel="apple-touch-icon">` tags into the head **and** repoints the post-swap "re-apply favicon" script at `/favicon.ico`, so the standalone icon is present in both the static snapshot and the live JS-rendered DOM. Google picks it up on its next re-crawl (days–weeks); nudge via Search Console → URL Inspection → Request Indexing.

## 🔴 Regression risk — do this after EVERY SPA redesign

Editing / re-exporting the SPA produces a **new bundler file** that **wipes the snapshot + meta + favicon links** (back to CSR-only, invisible to crawlers).

After any redesign you MUST:

```bash
cd prerender
npm install                       # first time only; local dev machine only, never on a VPS

# 1. Replace the build input with the NEW raw bundler export:
#    overwrite prerender/source-live.html with the new single-file export.

# 2. Rebuild + verify:
npm run build                     # -> dist/ (index.html, robots.txt, sitemap.xml, og-image.png, favicons)
npm run verify                    # static + JS-mount + favicon checks must pass

# 3. Backup, then deploy to VPS1:
ssh root@204.168.192.40 'cp /var/www/html/index.html /var/www/html/index.html.pre-prerender.$(date +%Y%m%d-%H%M%S)'
for f in index.html robots.txt sitemap.xml og-image.png favicon.ico favicon-16x16.png favicon-32x32.png apple-touch-icon.png; do
  scp dist/$f root@204.168.192.40:/var/www/html/$f
done
ssh root@204.168.192.40 'nginx -t && systemctl reload nginx'
```

Favicons only need regenerating if the brand mark changes.

> Puppeteer's bundled Chromium download can flake on Windows. If so, point it at system Chrome:
> `export PUPPETEER_EXECUTABLE_PATH="C:/Program Files/Google/Chrome/Application/chrome.exe"`

## Cloudflare notes

- The HTML returns `cf-cache-status: DYNAMIC` — **Cloudflare does not cache the page**, so deploys go live immediately and **no cache purge is needed**. Favicons / og-image are new files with no prior cached version.
- The certbot token in `/root/.secrets/cloudflare.ini` is **DNS-scoped only — it cannot purge cache** (purge API returns code 10000). If a purge is ever required, use the Cloudflare dashboard (single URL) or create a token with the **Cache Purge** permission. Do **not** change DNS / SSL settings.

## Deploy safety rules (followed for these changes)

- Back up any file before overwriting (timestamped `*.pre-prerender.*` / `*.pre-favicon.*`); keep the old build until confirmed.
- `nginx -t` first; `systemctl reload nginx` only if it passes — never `restart`.
- Never touch marzban-node, 3X-UI, xray-3xui-mirror, pricescout, or `app.onyxour.com`.

## Rollback for the 2026-07-25 deploys

```bash
# revert to pre-favicon state (snapshot without favicons):
ssh root@204.168.192.40 'cp /var/www/html/index.html.pre-favicon.20260725-164442 /var/www/html/index.html && nginx -t && systemctl reload nginx'
# (optionally remove the icon files:)
ssh root@204.168.192.40 'rm -f /var/www/html/favicon.ico /var/www/html/favicon-16x16.png /var/www/html/favicon-32x32.png /var/www/html/apple-touch-icon.png'

# revert all the way to the original CSR-only SPA (no prerender at all):
ssh root@204.168.192.40 'cp /var/www/html/index.html.pre-prerender.20260725-155834 /var/www/html/index.html && nginx -t && systemctl reload nginx'
```

## Verified live (2026-07-25)

- Raw `<head>`: `lang="fa" dir="rtl"` + description + canonical + OG + Twitter + `og:image` + 4 favicon `<link>`s.
- Favicon files: `/favicon.ico` (200, `image/x-icon`), `/favicon-16x16.png`, `/favicon-32x32.png`, `/apple-touch-icon.png` (200, `image/png`).
- Raw `<body>` with JS disabled: 2,528 chars of real content — nav, hero, 5 feature cards, full pricing table (all tiers + Tomans), how-it-works, setup guide, all Telegram handles (`@onyxour_vpn_bot`, `@onyxourvpn`, `@r_nsr_0`).
- Real users (JS on): unchanged React app (particles, plan toggle) — `#dc-root` == 1, no errors.

---

## Known minor limitation

After the JS swap, the app's own template `<html>` lacks `lang`/`dir` (only the static / no-JS view has them). This is fine for indexing (crawlers use the initial HTML response) and isn't worth editing the opaque bundler template.
