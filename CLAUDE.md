# Onyxour — راهنمای کامل پروژه

## معرفی کسب‌وکار

**Onyxour** یک سرویس VPN ایرانی است که اینترنت آزاد، امن و پرسرعت را با IP ثابت اختصاصی ارائه می‌دهد.

### ارزش‌های اصلی
- **IP ثابت اختصاصی** — هر کاربر یک IP ثابت دارد (Fixed Dedicated IP)
- **سرعت بالا** — پروتکل‌های بهینه، پینگ پایین، مناسب استریم و گیمینگ
- **اتصال پایدار** — آپتایم بالا، بدون قطعی در ساعات شلوغ
- **پشتیبانی ۲۴/۷** — پاسخگویی از طریق تلگرام در هر ساعت
- **آزمایش رایگان ۲۴ ساعته** — بدون نیاز به پرداخت یا کارت اعتباری
- **پلن خانوادگی** — یک اشتراک برای چند کاربر

### مدل قیمت‌گذاری
قیمت‌ها **بر اساس حجم مصرف** (تومان) تعیین می‌شوند — هر چه بیشتر بخری به‌صرفه‌تر می‌شود.

**پلن شخصی:**
| حجم | قیمت |
|-----|------|
| 10 GB | ۱۸۰,۰۰۰ تومان |
| 20 GB | ۳۴۸,۰۰۰ تومان |
| 30 GB | ۵۰۵,۰۰۰ تومان |
| 40 GB | ۶۵۱,۰۰۰ تومان |
| 50 GB ⭐ پرفروش | ۷۸۵,۰۰۰ تومان |
| 100 GB ⭐ بهترین ارزش | ۱,۵۱۴,۰۰۰ تومان |
| 200 GB | ۲,۹۱۴,۰۰۰ تومان |
| 1000 GB | ۱۴,۰۰۰,۰۰۰ تومان |

**پلن خانوادگی (۲۰٪ گران‌تر از شخصی):**
| حجم | قیمت |
|-----|------|
| 10 GB | ۲۱۶,۰۰۰ تومان |
| 20 GB | ۴۱۸,۰۰۰ تومان |
| 30 GB | ۶۰۶,۰۰۰ تومان |
| 40 GB | ۷۸۱,۰۰۰ تومان |
| 50 GB ⭐ پرفروش | ۹۴۲,۰۰۰ تومان |
| 100 GB ⭐ بهترین ارزش | ۱,۸۱۷,۰۰۰ تومان |
| 200 GB | ۳,۴۹۷,۰۰۰ تومان |
| 1000 GB | ۱۶,۸۰۰,۰۰۰ تومان |

---

## اطلاعات برند و تماس

| مورد | مقدار |
|------|-------|
| نام برند (لاتین) | Onyxour |
| نام برند (فارسی) | اونیکسور |
| وب‌سایت | onyxour.com |
| ربات تلگرام | [@onyxour_vpn_bot](https://t.me/onyxour_vpn_bot) |
| پشتیبانی مستقیم | [@r_nsr_0](https://t.me/r_nsr_0) |
| کانال رسمی | [@onyxour_vpn](https://t.me/onyxour_vpn) |

### لوگو
```html
<span style="font-family:'Playfair Display',serif; direction:ltr">
  onyx<span style="color:#F97316">our</span>
  <span style="font-size:0.6em; color:#787878">VPN</span>
</span>
```
- حرف اول `o` در `our` به رنگ نارنجی `#F97316`
- فونت لوگو: Playfair Display
- همیشه LTR و lowercase لاتین

---

## زیرساخت و سرور

### سرورها

| | VPS1 — Onyxour | VPS2 — PriceScout |
|-|----------------|-------------------|
| **IP** | `204.168.192.40` | `178.105.14.66` |
| **پلن** | — | CX23 |
| **موقعیت** | — | Falkenstein, Germany |
| **کاربرد** | Marzban VPN | PriceScout bot |

### VPS1 — Onyxour
| مورد | مقدار |
|------|-------|
| IP سرور | `204.168.192.40` |
| مسیر فایل وب | `/var/www/html/index.html` |
| Marzban certs | `/var/lib/marzban/certs/` |
| SSL hook | `/etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh` |
| روش deploy | SSH با کلید `~/.ssh/id_ed25519` |

### VPS2 — PriceScout
| مورد | مقدار |
|------|-------|
| IP سرور | `178.105.14.66` |
| پلن | CX23 — Hetzner Falkenstein, Germany |
| کاربرد | ربات تجاری ردیابی قیمت (Trendyol / Amazon) |

### ⚠️ وضعیت واقعی دیپلوی (تأییدشده ۲۰۲۶-۰۷-۲۶ با curl روی سایت زنده)

**آنچه واقعاً روی `onyxour.com` سرو می‌شود، این `onyxour.html`/`index.html` نیست.**
سایت زنده یک **SPA (React) پیش‌رندرشده** است — خروجی `prerender/dist/index.html` که از
`prerender/source-live.html` (یک export تک‌فایلیِ سازندهٔ no-code با فریم‌ورک «dc»:
`<x-dc>`، `dc-root`، splash «Unpacking») ساخته می‌شود. امضاها در HTML زنده: `React`،
`__prerender-root`، `__bundler/template`. برند در نسخهٔ زنده «اونیکس‌اور» (فارسی)، تک‌زبانه.

- **مسیر دیپلوی واقعی:** `cd prerender && npm run build && npm run verify` → SCP کردن `dist/`
  به `root@204.168.192.40:/var/www/html/` (پشت Cloudflare Full-Strict). جزئیات در
  [`prerender/README.md`](prerender/README.md) و [`prerender/DEPLOY-NOTES.md`](prerender/DEPLOY-NOTES.md).
- **سورس قابل‌ویرایش سایت زنده:** سند `<x-dc>` داخل `prerender/source-live.html`. **هیچ پروژهٔ
  React/JSX جداگانه‌ای روی ماشین نیست** (کل درایو جستجو شد). طبق README، این فایل دستی نوشته
  نمی‌شود؛ از سازندهٔ no-code دوباره export می‌گیری و جایگزین می‌کنی.

### 🚨 `upload.sh` و `onyxour.html`/`index.html` قدیمی و خطرناک‌اند
`onyxour.html` و `index.html` یک صفحهٔ فرودِ **دست‌نویسِ جدا و مرده‌اند** (دوزبانه fa/en، برند
«Onyxour» لاتین، کلاس‌های `nav-cta`/`price-volume`/`social-link` که در سایت زنده وجود ندارند).
`upload.sh` همان `index.html` مرده را به `/var/www/html/index.html` می‌فرستد — **همان مسیری که
snapshot زنده آنجاست.** ⚠️ **اجرای `bash upload.sh` سایت زندهٔ SPA را با صفحهٔ دست‌نویس رونویسی
می‌کند و سایت را عقب می‌برد. اجرا نکن مگر عمداً بخواهی به صفحهٔ دست‌نویس برگردی.**

### دامنه
| دامنه | هدف |
|-------|-----|
| `onyxour.com` | وب‌سایت اصلی — **VPS1 nginx (`/var/www/html/`) از طریق SCP، نه GitHub Pages** (Cloudflare Full-Strict جلوی آن) |

### GitHub Repository
- **Repo:** `rezanasirpour76-code/onyxour-website`
- **Branch اصلی:** `main`
- **Hosting:** ریشهٔ زنده روی **VPS1 nginx** است (CNAME موجود است ولی GitHub Pages منبعِ سرو نیست)

---

## معماری فنی

### Stack
| لایه | تکنولوژی |
|------|-----------|
| Frontend | HTML، CSS خالص، Vanilla JavaScript |
| Icons | Lucide Icons (CDN: `unpkg.com/lucide@latest`) |
| فونت‌ها | Vazirmatn (**self-hosted** — `fonts/Vazirmatn.woff2`)، Space Grotesk، Playfair Display — **بدون Google Fonts** |
| Backend | Node.js (در صورت نیاز) |
| Deploy زنده | prerender SPA snapshot → SCP به VPS1 nginx (نگاه کن به بخش «وضعیت واقعی دیپلوی» بالا) |

> **توجه:** جدول Stack بالا (Vanilla JS، بدون build tool، ماژول‌های particle/hamburger/…) صفحهٔ
> **دست‌نویسِ `onyxour.html` را توصیف می‌کند که مرده است**. سایت زندهٔ واقعی یک SPA React است (فریم‌ورک «dc»).

### فایل‌های کلیدی
| فایل | هدف |
|------|-----|
| `prerender/source-live.html` | ⭐ **سورس واقعی سایت زنده** — export سازندهٔ no-code (سند `<x-dc>`) |
| `prerender/prerender.mjs` | اسکریپت Route A: snapshot گرفتن از SPA → `dist/` (این چیزی است که دیپلوی می‌شود) |
| `prerender/dist/` | خروجی بیلد که به VPS1 می‌رود (index.html + robots + sitemap + og + favicons) |
| `onyxour.html` | ⚠️ صفحهٔ فرودِ دست‌نویسِ **قدیمی/مرده** — سرو نمی‌شود |
| `index.html` | ⚠️ کپیِ `onyxour.html` — 🚨 `upload.sh` این را روی snapshot زندهٔ SPA رونویسی می‌کند |
| `upload.sh` | 🚨 **اسکریپت دیپلویِ قدیمی و خطرناک** — `index.html` مرده را روی سایت زنده می‌فرستد؛ اجرا نکن |
| `fonts/Vazirmatn.woff2` | فونت self-hosted ورییبل Vazirmatn (~۱۰۸KB، وزن‌های ۱۰۰–۹۰۰) |
| `CNAME` | فایل دامنه (ریشهٔ زنده روی VPS1 است، نه GitHub Pages) |

> **نکته دربارهٔ دو فایل دست‌نویس:** `onyxour.html` و `index.html` بایت‌به‌بایت یکسان نگه داشته می‌شوند،
> ولی **هیچ‌کدام سایت زنده نیستند**. تا وقتی تکلیفشان روشن نشده (حذف یا جایگزینیِ رسمیِ SPA)، ویرایششان
> هیچ اثری روی `onyxour.com` ندارد.

---

## قراردادهای طراحی

### زبان و جهت
- تمام متن‌های رو‌به‌رو با کاربر باید **فارسی** باشند
- جهت layout: **RTL** — همیشه `dir="rtl"` روی `<html>` و `direction: rtl` در CSS
- اعداد، قیمت‌ها و رشته‌های فنی (مثل AES-256، WireGuard): LTR با `direction: ltr`

### فونت
```css
font-family: 'Vazirmatn', 'Tahoma', system-ui, sans-serif; /* متن فارسی */
font-family: 'Space Grotesk', system-ui, sans-serif;        /* اعداد و لاتین */
font-family: 'Playfair Display', Georgia, serif;            /* لوگو */
```

> **فونت self-hosted:** Vazirmatn به‌صورت **فایل محلی** سرو می‌شود، نه Google Fonts. یک فایل ورییبل `fonts/Vazirmatn.woff2` (وزن‌های ۱۰۰–۹۰۰) با `@font-face`:
> ```css
> @font-face {
>   font-family: 'Vazirmatn';
>   src: url('fonts/Vazirmatn.woff2') format('woff2');
>   font-weight: 100 900;
>   font-display: swap;
> }
> ```
> در `<head>` هم `<link rel="preload" href="fonts/Vazirmatn.woff2" as="font" type="font/woff2" crossorigin>` گذاشته شده. **هیچ وابستگی به CDN خارجی برای فونت وجود ندارد** — مقاوم در برابر فیلترینگ. اگر فونت را به‌روزرسانی کردید، `fonts/` را هم دیپلوی کنید (`upload.sh` این کار را می‌کند).

### پالت رنگی (تم تاریک — فقط dark theme)
```css
:root {
  --bg:           #0a0a0a;   /* پس‌زمینه اصلی */
  --bg2:          #111111;   /* پس‌زمینه ثانوی */
  --surface:      #181818;   /* کارت‌ها و کامپوننت‌ها */
  --surface2:     #1f1f1f;   /* لایه دوم سطح */
  --border:       #2a2a2a;   /* خطوط جداکننده */
  --border2:      #333333;   /* خطوط پررنگ‌تر */
  --orange:       #F97316;   /* رنگ اصلی برند */
  --orange2:      #FB923C;   /* hover state نارنجی */
  --orange3:      #FED7AA;   /* نارنجی روشن */
  --orange-glow:  rgba(255,107,0,0.18);
  --orange-glow2: rgba(255,107,0,0.08);
  --text:         #f2f2f2;   /* متن اصلی */
  --text2:        #c0c0c0;   /* متن ثانوی */
  --muted:        #787878;   /* متن کم‌رنگ */
  --green:        #22c55e;   /* موفقیت / تأیید */
  --radius:       12px;
}
```

> **توجه:** CLAUDE.md اصلی (خارج از ریپو) از رنگ بنفش `#6c63ff` استفاده می‌کند — اما رنگ واقعی پروژه **نارنجی** `#F97316` است. همیشه از پالت بالا استفاده کنید.

### CSS
- فقط CSS خالص — بدون فریمورک خارجی
- استفاده از CSS custom properties برای همه رنگ‌ها
- موبایل-فرست، مقیاس‌پذیر با `clamp()` برای اندازه فونت
- Breakpointها: `768px` (موبایل)، `1100px` (تبلت)، `600px` (موبایل کوچک)

### JavaScript
- Vanilla JS — بدون فریمورک
- بدون build tool
- ماژول‌های اصلی داخل صفحه:
  - **Particle Network** — canvas animation پس‌زمینه (80 ذره دسکتاپ / 35 موبایل)
  - **Hamburger Menu** — منوی موبایل با آیکن menu/x
  - **Scroll Reveal** — IntersectionObserver برای fade-in کارت‌ها
  - **NAV glass effect** — تاریک شدن navbar هنگام اسکرول
  - **FAB** — دکمه شناور که بعد از hero ظاهر می‌شود
  - **Plan Toggle** — سوئیچ بین پلن شخصی و خانوادگی

---

## ساختار صفحه اصلی

```
NAV (sticky, glass blur on scroll)
  └── لوگو | لینک‌ها | دکمه CTA | hamburger (موبایل)

HERO
  └── particle canvas (fixed, z-index: 0)
  └── shield emblem (SVG، شناور)
  └── pulse rings (3 حلقه)
  └── trial badge | h1 | subtitle | CTA buttons | trust row

STATS BAR (4 ستون)
  └── 24h Free Trial | IP ثابت | 24/7 | 🔒

FEATURES (6 کارت)
  └── IP ثابت | سرعت | پایداری | پشتیبانی | خانوادگی | حریم خصوصی

FREE TRIAL SECTION
  └── ۳ مرحله + دکمه تلگرام

PRICING
  └── toggle (شخصی/خانوادگی) + 8 کارت قیمت

CONTACT
  └── 3 کارت: ربات | پشتیبانی مستقیم | کانال

CTA BANNER

FOOTER
  └── لوگو | copyright | لینک‌ها

FAB (fixed, نارنجی، بعد از hero ظاهر می‌شود)
```

---

## اهداف تجاری و توسعه

### اولویت‌های فعلی
1. **ربات تلگرام** — همه فروش و آزمایش رایگان از طریق `@onyxour_vpn_bot` انجام می‌شود
2. **سادگی** — صفحه یک‌فایلی، بدون پیچیدگی، آماده deploy
3. **تبدیل (Conversion)** — هر بخش صفحه به سمت کلیک روی ربات هدایت می‌کند

### کانال‌های تماس با کاربر
| کانال | هدف |
|-------|-----|
| `@onyxour_vpn_bot` | خرید، آزمایش رایگان، مدیریت حساب |
| `@r_nsr_0` | پشتیبانی فنی مستقیم |
| `@onyxour_vpn` | اطلاعیه، تخفیف، اخبار |

### رقبا و تمایز
- تمرکز روی **IP ثابت** — اکثر VPNهای ایرانی IP ثابت ندارند
- قیمت‌گذاری **بر اساس حجم** — نه اشتراک ماهانه ثابت
- **آزمایش رایگان** بدون نیاز به اطلاعات پرداخت

---

## نکات مهم برای Claude

### چه چیزی باید بسازم/ویرایش کنم؟
- هرگاه متن UI اضافه می‌شود → **فارسی** باشد
- هرگاه رنگ جدید نیاز است → از پالت نارنجی بالا استفاده شود
- هرگاه لینک به ربات نیاز است → `https://t.me/onyxour_vpn_bot`
- ⚠️ **برای تغییر سایت زنده، `onyxour.html`/`index.html` را ویرایش نکن** (مرده‌اند). سایت زنده از
  `prerender/source-live.html` (سازندهٔ no-code) می‌آید؛ بخش «وضعیت واقعی دیپلوی» بالا را ببین.

### چه چیزی نباید انجام شود؟
- تغییر تم به روشن (light mode)
- استفاده از فریمورک CSS خارجی
- اضافه کردن متن انگلیسی به عنوان متن اصلی UI
- استفاده از رنگ بنفش `#6c63ff` (رنگ قدیمی — حذف شده)

### Deploy کردن

**سایت زنده (SPA snapshot) — روش درست:**
```bash
cd prerender
npm run build          # source-live.html → dist/{index.html,robots.txt,sitemap.xml,og-image.png,favicon.*}
npm run verify         # چک static + JS-mount + favicon
# سپس dist/ را با SCP به VPS1 بفرست (دستور کامل در prerender/README.md)
```

**🚨 `bash upload.sh` را اجرا نکن** — snapshot زنده را با `index.html` دست‌نویسِ مرده رونویسی می‌کند.

**push به GitHub (فقط نسخهٔ کنترلِ مخزن — سایت زنده را تغییر نمی‌دهد، چون Hosting روی VPS1 است):**
```bash
git add -A
git commit -m "..."
git push origin main
```
