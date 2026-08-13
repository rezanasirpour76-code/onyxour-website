// رگرسیون‌تست فیکس XSS در ../subscription.html (خطوط ~۵۹۹-۶۰۲).
// اینجا زندگی می‌کند چون puppeteer از قبل فقط در همین پکیج نصب است.
//   node prerender/verify-subscription-xss.mjs
import puppeteer from 'puppeteer';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

// همان کنوانسیون prerender.mjs — کرومیوم دانلودی puppeteer اینجا نصب نیست
const browser = await puppeteer.launch({
  executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
});
const p = await browser.newPage();
const file = process.argv[2]
  ? resolve(process.argv[2])
  : resolve(dirname(fileURLToPath(import.meta.url)), '..', 'subscription.html');
await p.goto('file://' + file.replace(/\\/g, '/'));

const r = await p.evaluate(() => {
  const evil = '<img src=x onerror="window.__pwned=1"> DE Node';
  window.__pwned = undefined;
  renderConfigsFromLinks(['vless://u@h:443?x=1#' + encodeURIComponent(evil)]);
  const list = document.getElementById('configList');
  const name = list.querySelector('.cfg-name');
  return {
    injectedEls: list.querySelectorAll('img, script, iframe').length,
    pwned: window.__pwned,
    text: name.textContent,
    textNodesOnly: [...name.childNodes].every(n => n.nodeType === 3),
    copyRoundTrip: decodeURIComponent(list.querySelector('.cfg-icon').getAttribute('data-uri')),
  };
});

await browser.close();
console.log(r);
if (r.injectedEls !== 0) throw new Error('XSS: payload شد element');
if (r.pwned !== undefined) throw new Error('XSS: onerror اجرا شد');
if (!r.textNodesOnly) throw new Error('XSS: remark به‌عنوان HTML پارس شد');
if (!r.text.includes('<img')) throw new Error('remark باید عیناً به‌صورت متن دیده شود');
if (!r.copyRoundTrip.startsWith('vless://')) throw new Error('دکمهٔ کپی خراب شد');
console.log('OK — remark به‌عنوان متن رندر شد، هیچ element/اجرایی نبود');
