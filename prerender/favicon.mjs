// Generate standalone favicon files from the Onyxour brand mark
// (dark rounded square + orange ring — identical to the inline SVG in <head>).
//
// Outputs into dist/:
//   favicon-16x16.png, favicon-32x32.png   (transparent rounded corners)
//   apple-touch-icon.png (180x180)         (opaque full-bleed square, iOS masks it)
//   favicon.ico                            (multi-size 16/32/48, PNG-embedded)
//
// No image libraries: PNGs are rendered by headless Chrome, and the .ico is a
// hand-built PNG-embedded ICO (supported by all modern browsers + Google).

import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIST = join(HERE, 'dist');
mkdirSync(DIST, { recursive: true });

// The brand mark, parameterized. rounded=true → rx=6 (transparent corners);
// rounded=false → rx=0 full square (used for the opaque apple icon).
const mark = (rounded) =>
  `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>` +
  `<rect width='32' height='32' rx='${rounded ? 6 : 0}' fill='#0a0a0a'/>` +
  `<circle cx='16' cy='16' r='8' fill='none' stroke='#FF5C00' stroke-width='4'/></svg>`;

async function renderPng(page, size, { rounded, opaque }) {
  const html = `<!doctype html><meta charset="utf-8">
    <style>html,body{margin:0;padding:0}svg{display:block}</style>
    <div style="width:${size}px;height:${size}px">
      <svg xmlns='http://www.w3.org/2000/svg' width='${size}' height='${size}' viewBox='0 0 32 32'>
        <rect width='32' height='32' rx='${rounded ? 6 : 0}' fill='#0a0a0a'/>
        <circle cx='16' cy='16' r='8' fill='none' stroke='#FF5C00' stroke-width='4'/>
      </svg>
    </div>`;
  await page.setViewport({ width: size, height: size, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'domcontentloaded' });
  const el = await page.$('div');
  return await el.screenshot({ omitBackground: !opaque }); // Buffer (PNG)
}

// Build a PNG-embedded ICO from [{size, data:Buffer}].
function buildIco(images) {
  const count = images.length;
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);      // reserved
  header.writeUInt16LE(1, 2);      // type = icon
  header.writeUInt16LE(count, 4);  // image count
  const entries = [];
  const blobs = [];
  let offset = 6 + count * 16;
  for (const img of images) {
    const e = Buffer.alloc(16);
    e.writeUInt8(img.size >= 256 ? 0 : img.size, 0); // width  (0 = 256)
    e.writeUInt8(img.size >= 256 ? 0 : img.size, 1); // height
    e.writeUInt8(0, 2);                    // palette
    e.writeUInt8(0, 3);                    // reserved
    e.writeUInt16LE(1, 4);                 // color planes
    e.writeUInt16LE(32, 6);                // bits per pixel
    e.writeUInt32LE(img.data.length, 8);   // size of PNG data
    e.writeUInt32LE(offset, 12);           // offset of PNG data
    entries.push(e);
    blobs.push(img.data);
    offset += img.data.length;
  }
  return Buffer.concat([header, ...entries, ...blobs]);
}

const browser = await puppeteer.launch({
  headless: 'new', args: ['--no-sandbox'],
  executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
});
try {
  const page = await browser.newPage();

  const png16 = await renderPng(page, 16, { rounded: true,  opaque: false });
  const png32 = await renderPng(page, 32, { rounded: true,  opaque: false });
  const png48 = await renderPng(page, 48, { rounded: true,  opaque: false });
  const png180 = await renderPng(page, 180, { rounded: false, opaque: true });

  writeFileSync(join(DIST, 'favicon-16x16.png'), png16);
  writeFileSync(join(DIST, 'favicon-32x32.png'), png32);
  writeFileSync(join(DIST, 'apple-touch-icon.png'), png180);

  const ico = buildIco([
    { size: 16, data: png16 },
    { size: 32, data: png32 },
    { size: 48, data: png48 },
  ]);
  writeFileSync(join(DIST, 'favicon.ico'), ico);

  console.log('✔ favicon-16x16.png :', png16.length, 'bytes');
  console.log('✔ favicon-32x32.png :', png32.length, 'bytes');
  console.log('✔ apple-touch-icon.png (180):', png180.length, 'bytes');
  console.log('✔ favicon.ico (16/32/48):', ico.length, 'bytes');
} finally {
  await browser.close();
}
