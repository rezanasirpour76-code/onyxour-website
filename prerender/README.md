# Onyxour prerender (Route A — SPA snapshot)

`onyxour.com` is served by **VPS1 nginx** (`204.168.192.40`) from
`/var/www/html/index.html` — **not** GitHub Pages. Cloudflare (Full Strict)
proxies to it. Deploy = **SCP to VPS1**, not `git push`.

The live page is a single-file **bundler SPA**: a shell + a gzipped
`__bundler/template` blob that a runtime unpacks into `blob:` URLs and mounts by
`document.documentElement.replaceWith(...)` (React transpiled in-browser by
Babel). Raw HTML therefore shows only an `Unpacking...` splash — bad for
crawlers and slow/throttled clients.

## What this does

`prerender.mjs` renders the live page headlessly, extracts the real `#dc-root`
DOM + styles, neutralizes session-scoped `blob:`/`@font-face`, and grafts that
static styled snapshot into the raw shell — plus `<html lang="fa" dir="rtl">`
and SEO/OG/Twitter/canonical meta. **All bundler machinery is left untouched**,
so JS clients still get the identical app; the whole-`<html>` swap atomically
discards the snapshot (no duplication).

## Run

```bash
cd prerender
npm install            # puppeteer (local dev machine only — never on a VPS)
npm run build          # -> dist/index.html, robots.txt, sitemap.xml, og-image.png
npm run verify         # static + JS-mount checks (no duplication, no console errors)
```

## Deploy (VPS1)

Backup first, keep the old build until confirmed:

```bash
ssh root@204.168.192.40 'cp /var/www/html/index.html /var/www/html/index.html.pre-prerender.$(date +%Y%m%d-%H%M%S)'
scp dist/index.html   root@204.168.192.40:/var/www/html/index.html
scp dist/robots.txt   root@204.168.192.40:/var/www/html/robots.txt
scp dist/sitemap.xml  root@204.168.192.40:/var/www/html/sitemap.xml
scp dist/og-image.png root@204.168.192.40:/var/www/html/og-image.png
ssh root@204.168.192.40 'nginx -t && systemctl reload nginx'   # try_files already serves these; no config change
```

Then purge Cloudflare cache for `https://onyxour.com/` **only** (never full-zone).

## ⚠️ Re-run after every SPA redesign

Editing the SPA regenerates the bundler file and **wipes the snapshot +
meta** (CSR-only again). Always re-run `npm run build` and redeploy `dist/`
after any change to the live SPA, or SEO silently regresses.

## Fallback (only if `verify` shows duplication)

Serve the original SPA to real users and the static snapshot to crawler UAs via
an nginx `map $http_user_agent` (dynamic rendering). Not needed while the
whole-`<html>` swap keeps `#dc-root` count at 1.
