// Onyxour prerender — Route A: snapshot the live SPA.
//
// The live site (https://onyxour.com/) is a single-file bundler export: a tiny
// shell + a gzipped __bundler/template blob that a runtime script unpacks into
// blob: URLs and mounts by doing document.documentElement.replaceWith(...).
// Crawlers and no-JS / slow clients therefore see only an "Unpacking..." splash.
//
// This script:
//   1. fetches the RAW bundler HTML (the exact bytes nginx serves),
//   2. renders the live page headlessly and extracts the real #dc-root DOM
//      + the app's <style> blocks,
//   3. neutralizes session-scoped blob: URLs / @font-face (dead once static),
//   4. grafts that static, styled snapshot into the RAW shell in place of the
//      splash, and injects <html lang/dir> + SEO/OG/Twitter/canonical meta,
//   5. keeps ALL bundler machinery untouched, so JS clients still get the
//      identical React app — the whole-<html> replaceWith swap atomically
//      discards our snapshot (no duplication, no hydration mismatch).
//
// Output: dist/index.html, dist/robots.txt, dist/sitemap.xml
// Re-run this after any SPA redesign, then redeploy dist/ to VPS1.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createServer } from 'node:http';
import puppeteer from 'puppeteer';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIST = join(HERE, 'dist');
// Source of truth = the RAW bundler export, versioned in the repo. NOT the live
// URL: once the snapshot is deployed, fetching live would re-snapshot the
// snapshot. After an SPA redesign, replace source-live.html with the new export.
const SRC = join(HERE, 'source-live.html');

const TITLE = 'Onyxour VPN — اینترنت آزاد، امن و پرسرعت';
const DESC  = 'VPN با IP ثابت اختصاصی، سرعت بالا و پشتیبانی ۲۴/۷. آزمایش رایگان ۲۴ ساعته بدون نیاز به پرداخت.';
const CANON = 'https://onyxour.com/';
const OGIMG = 'https://onyxour.com/og-image.png';
const TODAY = new Date().toISOString().slice(0, 10);

const META = `
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${DESC}">
  <link rel="canonical" href="${CANON}">
  <meta name="theme-color" content="#0a0a0a">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Onyxour VPN">
  <meta property="og:locale" content="fa_IR">
  <meta property="og:url" content="${CANON}">
  <meta property="og:title" content="${TITLE}">
  <meta property="og:description" content="${DESC}">
  <meta property="og:image" content="${OGIMG}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${TITLE}">
  <meta name="twitter:description" content="${DESC}">
  <meta name="twitter:image" content="${OGIMG}">`;

// Standalone favicon files (Google Search reads a real /favicon.ico, not a
// data: URI). Kept alongside the template's inline SVG icon — browsers merge
// all rel=icon candidates.
const FAVICONS = `
  <link rel="icon" href="/favicon.ico" sizes="any">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">`;

// Kill session-scoped blob: URLs and @font-face (dead once served static; the
// real fonts come back with the app after the swap). Fallback font stack still
// renders Persian text fine in the pre-swap / no-JS view.
function neutralizeBlobs(s) {
  return s
    .replace(/@font-face\s*\{[^}]*\}/gi, '')
    .replace(/url\(\s*["']?blob:[^)]*\)/gi, 'none')
    .replace(/\bblob:[^\s"')]+/g, '');
}

async function main() {
  console.log('[1/5] Reading raw bundler source:', SRC);
  const raw = readFileSync(SRC, 'utf8');
  console.log('      raw shell bytes:', raw.length);
  if (!/__bundler\/template/.test(raw)) {
    throw new Error('source-live.html has no __bundler/template — not a raw bundler export. Inspect before proceeding.');
  }
  if (/__prerender-root/.test(raw)) {
    throw new Error('source-live.html is ALREADY a prerendered snapshot. Replace it with the raw bundler export (e.g. the pre-prerender backup) before building.');
  }

  console.log('[2/5] Rendering source headlessly (served on localhost)...');
  // Serve the self-contained bundler on localhost so the runtime mounts exactly
  // as in production (blob: assets are built from its own inlined manifest).
  const server = createServer((req, res) => {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(raw);
  });
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;

  const browser = await puppeteer.launch({
    headless: 'new', args: ['--no-sandbox'],
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 900, deviceScaleFactor: 1 });
    await page.goto(`http://localhost:${port}/`, { waitUntil: 'networkidle2', timeout: 60000 });
    // Wait until the React app has mounted (splash gone + real headings present).
    await page.waitForFunction(
      () => !document.getElementById('__bundler_thumbnail') &&
            document.querySelectorAll('h1,h2').length >= 4 &&
            document.getElementById('dc-root'),
      { timeout: 60000 }
    );
    // Give animations/fonts a beat to settle.
    await new Promise(r => setTimeout(r, 1500));

    const snap = await page.evaluate(() => {
      const root = document.getElementById('dc-root');
      const styles = Array.from(document.querySelectorAll('style'))
        .map(s => s.textContent).join('\n');
      // Strip any scripts that ended up inside the root subtree.
      const clone = root.cloneNode(true);
      clone.querySelectorAll('script').forEach(n => n.remove());
      return {
        rootHTML: clone.outerHTML,
        styles,
        headings: Array.from(document.querySelectorAll('h1,h2')).map(h => h.textContent.trim()).filter(Boolean),
        textLen: (document.body.innerText || '').replace(/\s+/g, ' ').trim().length,
        tgLinks: [...new Set(Array.from(document.querySelectorAll('a[href*="t.me"],a[href*="tg://"]')).map(a => a.getAttribute('href')))]
      };
    });
    console.log('      captured #dc-root, headings:', snap.headings.length, ' text chars:', snap.textLen, ' tg links:', snap.tgLinks.length);

    console.log('[3/5] Neutralizing blob:/@font-face in snapshot...');
    const styles = neutralizeBlobs(snap.styles);
    const rootHTML = neutralizeBlobs(snap.rootHTML);
    const beforeBlobs = (snap.styles + snap.rootHTML).match(/blob:/g)?.length || 0;
    const afterBlobs = (styles + rootHTML).match(/blob:/g)?.length || 0;
    console.log('      blob refs:', beforeBlobs, '->', afterBlobs);

    console.log('[4/5] Grafting snapshot into raw shell + injecting meta...');
    let out = raw;

    // (a) <html> -> <html lang="fa" dir="rtl">
    out = out.replace(/<html(\s[^>]*)?>/i, '<html lang="fa" dir="rtl">');

    // (b) inject SEO/OG meta + favicon links right after <meta charset...>
    out = out.replace(/(<meta\s+charset=["'][^"']*["']\s*\/?>)/i, `$1${META}${FAVICONS}`);

    // (c) neutralize splash body-centering so real content flows normally
    out = out.replace(/body\s*\{\s*background:\s*#0a0a0a;[^}]*\}/i, 'body { background: #0a0a0a; }');

    // (c2) drop the now-inaccurate <noscript> "requires JavaScript" message —
    // real content renders without JS after prerendering. Keep the <style> that
    // hides the loading pill for no-JS clients.
    out = out.replace(/<div[^>]*>\s*This page requires JavaScript to display\.\s*<\/div>\s*/i, '');

    // (d) replace the splash thumbnail div with the static snapshot
    //     (the SVG splash contains no nested <div>, so non-greedy is safe)
    const prerenderBlock =
      `<div id="__prerender-root">\n<style id="__prerender-styles">\n${styles}\n</style>\n${rootHTML}\n</div>`;
    const thumbRe = /<div id="__bundler_thumbnail">[\s\S]*?<\/div>\s*(?=<div id="__bundler_loading")/i;
    if (!thumbRe.test(out)) {
      throw new Error('Could not locate splash thumbnail div — structure changed. Inspect before proceeding.');
    }
    out = out.replace(thumbRe, prerenderBlock + '\n  ');

    // (e) point the post-swap "re-apply favicon" script at the real file too,
    // so the standalone favicon is present in the live JS-rendered DOM as well.
    const beforeIcon = out;
    out = out.replace(/var ICON="data:image\/svg\+xml,[^"]*";/, 'var ICON="/favicon.ico";');
    out = out.replace(/l\.setAttribute\('type','image\/svg\+xml'\);/, "l.setAttribute('type','image/x-icon');");
    console.log('      re-apply favicon script patched:', out !== beforeIcon);

    // sanity: bundler machinery must survive untouched
    for (const marker of ['__bundler/manifest', '__bundler/template', 'replaceWith(doc.documentElement)']) {
      if (!out.includes(marker)) throw new Error('Lost bundler marker: ' + marker);
    }

    console.log('[5/5] Writing dist/ ...');
    mkdirSync(DIST, { recursive: true });
    writeFileSync(join(DIST, 'index.html'), out, 'utf8');
    writeFileSync(join(DIST, 'robots.txt'),
      `User-agent: *\nAllow: /\n\nSitemap: https://onyxour.com/sitemap.xml\n`, 'utf8');
    writeFileSync(join(DIST, 'sitemap.xml'),
      `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url>\n    <loc>https://onyxour.com/</loc>\n    <lastmod>${TODAY}</lastmod>\n    <changefreq>weekly</changefreq>\n    <priority>1.0</priority>\n  </url>\n</urlset>\n`, 'utf8');

    console.log('\n✔ Done.');
    console.log('  dist/index.html :', out.length, 'bytes (raw shell was', raw.length + ')');
    console.log('  headings in snapshot:', snap.headings.join(' | '));
    console.log('  telegram links preserved:', snap.tgLinks.join(', '));
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch(e => { console.error('PRERENDER FAILED:', e); process.exit(1); });
