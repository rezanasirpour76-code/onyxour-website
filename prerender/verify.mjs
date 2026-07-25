// Verify dist/index.html: (1) static/no-JS view has real content + meta,
// (2) JS clients still mount the app cleanly with no duplication / console errors.
// Serves dist/ over localhost (closer to prod than file://).

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import puppeteer from 'puppeteer';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIST = join(HERE, 'dist');
const html = readFileSync(join(DIST, 'index.html'), 'utf8');

// ---- Static checks (what a no-JS crawler sees: the raw bytes) ----
const staticChecks = {
  'html lang=fa':            /<html[^>]*\blang="fa"/i.test(html),
  'html dir=rtl':            /<html[^>]*\bdir="rtl"/i.test(html),
  'meta description':        /<meta\s+name="description"/i.test(html),
  'canonical':               /rel="canonical"\s+href="https:\/\/onyxour\.com\/"/i.test(html),
  'og:title':                /property="og:title"/i.test(html),
  'og:image':                /property="og:image"/i.test(html),
  'twitter:card':            /name="twitter:card"/i.test(html),
  'real heading in body':    /چرا اونیکس|پلن خود را|ONYXOUR/i.test(html),
  'telegram bot link':       /t\.me\/onyxour_vpn_bot/i.test(html),
  // only LIVE blob refs matter (CSS url(blob:) / src|href="blob:"); the bundler
  // runtime source legitimately mentions the word "blob:" in a code comment.
  'favicon.ico link':        /<link[^>]+rel="icon"[^>]+href="\/favicon\.ico"/i.test(html),
  'favicon 32 png link':     /<link[^>]+href="\/favicon-32x32\.png"/i.test(html),
  'apple-touch-icon link':   /<link[^>]+rel="apple-touch-icon"[^>]+href="\/apple-touch-icon\.png"/i.test(html),
  'no live blob: ref':       !/(url\(\s*["']?blob:|(?:src|href)=["']blob:)/i.test(html),
  'snapshot #dc-root == 1':  (html.match(/id="dc-root"/g) || []).length === 1,
  'bundler machinery intact': /__bundler\/template/.test(html) && /replaceWith\(doc\.documentElement\)/.test(html),
};

// favicon files must exist and be non-trivial
for (const f of ['favicon.ico', 'favicon-32x32.png', 'favicon-16x16.png', 'apple-touch-icon.png']) {
  const p = join(DIST, f);
  staticChecks[`file ${f}`] = existsSync(p) && statSync(p).size > 100;
}

console.log('\n== STATIC (no-JS crawler) checks ==');
let ok = true;
for (const [k, v] of Object.entries(staticChecks)) {
  console.log(`  ${v ? '✔' : '✗'} ${k}`);
  if (!v) ok = false;
}

// ---- Dynamic check: serve + render, confirm the app mounts cleanly ----
const server = createServer((req, res) => {
  const p = req.url === '/' ? '/index.html' : req.url;
  try {
    const body = readFileSync(join(DIST, p.replace(/^\//, '')));
    const type = p.endsWith('.png') ? 'image/png' : p.endsWith('.xml') ? 'application/xml'
      : p.endsWith('.txt') ? 'text/plain' : 'text/html; charset=utf-8';
    res.writeHead(200, { 'content-type': type });
    res.end(body);
  } catch { res.writeHead(404); res.end('nf'); }
});
await new Promise(r => server.listen(0, r));
const port = server.address().port;

const browser = await puppeteer.launch({
  headless: 'new', args: ['--no-sandbox'],
  executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
});
const consoleErrors = [];
try {
  const page = await browser.newPage();
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));

  // static snapshot #dc-root count comes from the raw served bytes (no race)
  const preSwap = (html.match(/id="dc-root"/g) || []).length;

  await page.goto(`http://localhost:${port}/`, { waitUntil: 'domcontentloaded' });

  // wait for the app to finish the whole-<html> swap and re-mount
  await page.waitForFunction(
    () => document.getElementById('dc-root') && document.querySelectorAll('h1,h2').length >= 4,
    { timeout: 60000 }
  ).catch(() => {});
  await new Promise(r => setTimeout(r, 2000));

  const post = await page.evaluate(() => ({
    dcRoots: document.querySelectorAll('#dc-root').length,
    headings: document.querySelectorAll('h1,h2').length,
    textLen: (document.body.innerText || '').replace(/\s+/g, ' ').trim().length,
    hasErrOverlay: !!document.getElementById('__bundler_err'),
  }));

  console.log('\n== DYNAMIC (JS client) checks ==');
  console.log('  #dc-root in served static HTML :', preSwap, '(expect 1)');
  console.log('  #dc-root after app mount        :', post.dcRoots, '(expect 1 — no duplication)');
  console.log('  headings after mount            :', post.headings);
  console.log('  body text chars after mount     :', post.textLen);
  console.log('  bundler error overlay shown     :', post.hasErrOverlay, '(expect false)');
  console.log('  console/page errors             :', consoleErrors.length ? consoleErrors : 'none');

  if (post.dcRoots !== 1) { ok = false; console.log('  ✗ DUPLICATION or missing root'); }
  if (post.hasErrOverlay) { ok = false; console.log('  ✗ bundler error overlay present'); }
} finally {
  await browser.close();
  server.close();
}

console.log('\n' + (ok ? '✔ ALL CHECKS PASSED' : '✗ SOME CHECKS FAILED'));
process.exit(ok ? 0 : 1);
