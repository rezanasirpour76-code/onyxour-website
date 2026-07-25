# Onyxour prerender (Route A — SPA snapshot)

`onyxour.com` is served by **VPS1 nginx** (`204.168.192.40`) from
`/var/www/html/index.html` — **not** GitHub Pages. Cloudflare (Full Strict)
proxies to it. Deploy = **SCP to VPS1**, not `git push`.

The live page is a single-file **bundler SPA**: a shell + a gzipped
`__bundler/template` blob that a runtime unpacks into `blob:` URLs and mounts by
`document.documentElement.replaceWith(...)` (React transpiled in-browser by
Babel). Raw HTML therefore shows only an `Unpacking...` splash — bad for
crawlers and slow/throttled clients.

## Source of truth: `source-live.html`

The build input is **`source-live.html`** — the RAW bundler export, versioned in
this repo. **NOT the live URL:** once the snapshot is deployed, fetching
`https://onyxour.com/` returns the snapshot, so re-rendering live would
snapshot the snapshot. `source-live.html` is the original bundler HTML (kept
from the pre-prerender backup). The build refuses to run if it detects an
already-prerendered file (`__prerender-root`).

## What this does

`prerender.mjs` serves `source-live.html` on localhost, renders it headlessly,
extracts the real `#dc-root` DOM + styles, neutralizes session-scoped
`blob:`/`@font-face`, and grafts that static styled snapshot into the raw shell
— plus `<html lang="fa" dir="rtl">`, SEO/OG/Twitter/canonical meta, and
standalone favicon `<link>`s (it also repoints the post-swap re-apply-favicon
script at `/favicon.ico`). **All bundler machinery is left untouched**, so JS
clients still get the identical app; the whole-`<html>` swap atomically
discards the snapshot (no duplication).

`favicon.mjs` renders the brand mark (dark rounded square + orange ring) into
`favicon.ico` (16/32/48 multi-size), `favicon-16x16.png`, `favicon-32x32.png`,
`apple-touch-icon.png` (180). `og-image.mjs` renders the 1200×630 social card.

## Run

```bash
cd prerender
npm install            # puppeteer (local dev machine only — never on a VPS)
npm run build          # -> dist/{index.html,robots.txt,sitemap.xml,og-image.png,favicon.ico,*.png}
npm run verify         # static + JS-mount + favicon checks
```

## Deploy (VPS1)

Backup first, keep the old build until confirmed:

```bash
ssh root@204.168.192.40 'cp /var/www/html/index.html /var/www/html/index.html.pre-prerender.$(date +%Y%m%d-%H%M%S)'
for f in index.html robots.txt sitemap.xml og-image.png favicon.ico favicon-16x16.png favicon-32x32.png apple-touch-icon.png; do
  scp dist/$f root@204.168.192.40:/var/www/html/$f
done
ssh root@204.168.192.40 'nginx -t && systemctl reload nginx'   # try_files already serves these; no config change
```

Cloudflare serves the HTML `DYNAMIC` (uncached) → no purge needed. Static assets
(favicons, og-image) are new files with no prior cached version.

## ⚠️ Re-run after every SPA redesign

Editing/re-exporting the SPA produces a new bundler file that **wipes the
snapshot + meta + favicon links** (CSR-only again). After a redesign:
**replace `source-live.html` with the new raw bundler export**, then
`npm run build && npm run verify`, then redeploy `dist/`. Favicons only need
regenerating if the brand mark changes.

## Fallback (only if `verify` shows duplication)

Serve the original SPA to real users and the static snapshot to crawler UAs via
an nginx `map $http_user_agent` (dynamic rendering). Not needed while the
whole-`<html>` swap keeps `#dc-root` count at 1.
