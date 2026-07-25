// Generate dist/og-image.png (1200x630) from the Onyxour brand splash.
// On-brand: dark bg, orange nebula glow, ONYXOUR wordmark (orange "OUR"),
// Persian tagline. No external assets — pure inline HTML/SVG screenshot.

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync } from 'node:fs';
import puppeteer from 'puppeteer';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIST = join(HERE, 'dist');

const HTML = `<!doctype html><html><head><meta charset="utf-8">
<style>
  html,body{margin:0;padding:0}
  .card{width:1200px;height:630px;position:relative;overflow:hidden;
    background:#0a0a0a;font-family:'Segoe UI',Tahoma,Arial,sans-serif}
  .nebula{position:absolute;left:50%;top:44%;transform:translate(-50%,-50%);
    width:900px;height:900px;border-radius:50%;
    background:radial-gradient(circle,rgba(249,115,22,.55) 0%,rgba(249,115,22,.16) 45%,rgba(249,115,22,0) 70%)}
  .star{position:absolute;background:#fff;border-radius:50%;opacity:.5}
  .wrap{position:absolute;inset:0;display:flex;flex-direction:column;
    align-items:center;justify-content:center;text-align:center}
  .word{font-weight:800;font-size:150px;letter-spacing:-4px;color:#f5f5f5;line-height:1}
  .word b{color:#F97316;font-weight:800}
  .vpn{color:#787878;font-size:44px;font-weight:700;vertical-align:super;margin-left:14px}
  .tag{margin-top:26px;color:#e6e6e6;font-size:40px;font-weight:600;direction:rtl}
  .sub{margin-top:14px;color:#F97316;font-size:26px;font-weight:700;letter-spacing:2px}
</style></head>
<body>
  <div class="card">
    <div class="nebula"></div>
    <div class="star" style="left:180px;top:120px;width:5px;height:5px"></div>
    <div class="star" style="left:980px;top:100px;width:4px;height:4px;opacity:.4"></div>
    <div class="star" style="left:300px;top:520px;width:4px;height:4px;opacity:.45"></div>
    <div class="star" style="left:900px;top:540px;width:5px;height:5px"></div>
    <div class="star" style="left:1050px;top:330px;width:4px;height:4px;opacity:.35"></div>
    <div class="star" style="left:140px;top:340px;width:4px;height:4px;opacity:.35"></div>
    <div class="wrap">
      <div class="word">ONYX<b>OUR</b><span class="vpn">VPN</span></div>
      <div class="tag">اینترنت آزاد، امن و پرسرعت با IP ثابت اختصاصی</div>
      <div class="sub">BORDERLESS · FAST · SECURE</div>
    </div>
  </div>
</body></html>`;

const browser = await puppeteer.launch({
  headless: 'new', args: ['--no-sandbox'],
  executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
});
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
  await page.setContent(HTML, { waitUntil: 'networkidle0' });
  mkdirSync(DIST, { recursive: true });
  const el = await page.$('.card');
  await el.screenshot({ path: join(DIST, 'og-image.png') });
  console.log('✔ Wrote dist/og-image.png (1200x630)');
} finally {
  await browser.close();
}
