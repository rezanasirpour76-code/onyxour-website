# Onyxour — Project Guide

> 📗 **Persian business context lives in [`docs/PROJECT-GUIDE-fa.md`](docs/PROJECT-GUIDE-fa.md)** — business goals (اهداف تجاری), competitors and differentiation (رقبا و تمایز), and main page structure (ساختار صفحه اصلی). Those sections have **no English equivalent** here; it is live context, not an outdated copy of this file.

## Business Overview

**Onyxour** (onyxour.com) is an Iranian VPN service offering fast, secure internet with **fixed dedicated IP**.

Core value props:
- Fixed dedicated IP per user
- Ultra-high speed (optimized protocols, low ping)
- Stable connection (high uptime, no drops)
- 24/7 Telegram support
- 24-hour free trial (no payment/card required)
- Family plan (shared quota, multiple users)

Pricing: volume-based (Tomans), not monthly subscriptions.
Sales channel: exclusively via Telegram bot `@onyxour_vpn_bot`.

---

## Tech Stack

> ⚠️ Corrected 2026-07-27. The live site is **not** a hand-written vanilla-JS page.

- **Live site:** a **pre-rendered React SPA** exported from a no-code builder (framework "dc" — `<x-dc>`, `dc-root`, "Unpacking" splash). Single-language Persian, brand «اونیکس‌اور».
- **Editable source:** the `<x-dc>` document inside `prerender/source-live.html`. There is **no separate React/JSX project** anywhere on the machine. Per `prerender/README.md` this file is not hand-edited — you re-export from the no-code builder and replace it.
- **Fonts:** the SPA embeds its own fonts in the bundle. (Vazirmatn / Space Grotesk / Playfair Display and the self-hosted `fonts/` setup belonged to the deleted hand-written page.)
- **Backend:** Node.js (if needed)
- **Deploy:** `cd prerender && npm run build && npm run verify`, then **SCP `dist/` to VPS1 nginx** `/var/www/html/`. **Not GitHub Pages.** `git push` only versions the repo — it does not change the live site.

---

## Key Files

| File | Purpose |
|------|---------|
| `prerender/source-live.html` | ⭐ Real source of the live site (no-code `<x-dc>` export) |
| `prerender/prerender.mjs` | Snapshots the SPA → `dist/` (this is what ships) |
| `prerender/dist/` | Build output SCP'd to VPS1 (index.html + robots + sitemap + og + favicons) |
| `prerender/README.md` | Full build + deploy commands |
| `CNAME` | Present, but GitHub Pages is **not** the serving source |
| `CLAUDE.md` | Full project docs (inside repo) |

### 🗑️ Deleted — do not look for these
`onyxour.html`, `index.html`, `upload.sh`, `fonts/Vazirmatn.woff2` (commits `c957cc4` / `83b0f62`) and `onyxour-vpn.html` (commit `c808297`, 2026-07-27) were all **dead hand-written pages** that were never served. `upload.sh` was worse than dead — it SCP'd the repo's `index.html` over the live SPA snapshot at the same path, silently regressing the site. Recoverable from git history if ever needed.

---

## Infrastructure

### Servers

| | VPS1 — Onyxour | VPS2 — PriceScout |
|-|----------------|-------------------|
| **IP** | `204.168.192.40` | `178.105.14.66` |
| **Provider** | Hetzner | Hetzner |
| **Plan** | — | CX23 |
| **Location** | — | Falkenstein, Germany |
| **Purpose** | Onyxour VPN (Marzban) | PriceScout bot **+ Onyxour node** (see below) |
| **SSH key** | `~/.ssh/id_ed25519` | `~/.ssh/id_ed25519` |
| **SSH password** | stored separately | stored separately |

### Onyxour (VPS1)
- **Web root:** `/var/www/html/` — served by **nginx**, populated by SCP of `prerender/dist/`
- **Marzban certs:** `/var/lib/marzban/certs/`
- **SSL hook:** `/etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh`
- **GitHub repo:** `rezanasirpour76-code/onyxour-website` (version control only, not hosting)
- **Domain:** `onyxour.com` → Cloudflare (Full Strict) → **VPS1 nginx**. A `CNAME` file exists in the repo but GitHub Pages does **not** serve the site.

### VPS2 — 178.105.14.66 (Hetzner, fsn1-dc8, instance-id 142530706)

> ⚠️ Corrected 2026-08-20. VPS2 is **not** PriceScout-only. All of the below was
> verified live on the host, read-only.

| Service | Notes |
|---------|-------|
| `pricescout.service` | The bot — Trendyol/Amazon price tracking. `/root/pricescout/bot.py` (venv python3) |
| `pricescout-miniapp.service` | Mini-app |
| `marzban-node` | Onyxour node (container) |
| `xray-3xui-mirror.service` | xray, listening on `:2083` and `:62051` |
| `priceout-floating-ip.service` | PriceScout egress IP — see below |

Active connections to VPS1 `204.168.192.40` are **normal**: VPS2 carries Onyxour
traffic as well as PriceScout. Do not treat them as an anomaly.

- **GitHub repo:** `rezanasirpour76-code/pricescout`

#### PriceScout floating-IP egress (91.98.101.23)

> ✅ Verified in the Hetzner console 2026-08-20: Floating IP **"PriceScout-IP"**
> `91.98.101.23`, project **15002563**, assigned to server **ubuntu-4gb-fsn1-2**
> (VPS2), Falkenstein. rDNS `static.23.101.98.91.clients.your-server.de`.
> This assignment is the *entire* reason the SNAT works — it is what Hetzner's
> anti-spoof checks against. See the silent failure mode below.

`priceout-floating-ip.service` → `/usr/local/sbin/priceout-floating-ip.sh`.
Gives PriceScout a fixed egress IP distinct from the host primary.

- **Mechanism:** `mangle OUTPUT` sets mark `0x64` on packets matching a cgroup2
  match on `system.slice/pricescout.service`; `nat POSTROUTING` SNATs
  `mark 0x64 -o eth0` to `91.98.101.23`. PriceScout-scoped by construction —
  nothing else on the box can reach the rule.
- Rules are re-added on every pricescout start via `ExecStartPre`, because the
  cgroup2 match binds to the cgroup **object** at add time and the cgroup is
  recreated on each restart. That part of the design is sound — leave it alone.
- **The address is NOT on eth0, and does not need to be.** `ip_up()` does add
  `91.98.101.23/32`, but the address has been absent since **Jul 31 06:07:55**,
  wiped when unattended-upgrades restarted `systemd-networkd` and eth0 was
  rebuilt from netplan (which carries only the DHCPv4 lease + static IPv6).
  Repeated **Aug 11 06:04:38**. `Type=oneshot` + `RemainAfterExit=yes` means
  systemd still reports the unit `active (exited)` and never re-runs `ip_up`.
- PriceScout has worked ~19 days without it. **Egress:** Hetzner anti-spoof
  accepts a source IP *assigned* to the server, regardless of host config.
  **Ingress:** `nf_nat` PREROUTING reverses the translation
  (`dst 91.98.101.23 → 178.105.14.66`) *before* the local-delivery routing
  decision, so no local address is ever required.
- **`ss` will mislead you here.** SNAT happens in POSTROUTING, *after* the socket
  layer, so `ss` reports PriceScout's sockets on `178.105.14.66`. Only the wire
  packet carries the float. Use `conntrack -L`: the reply tuple shows
  `dst=91.98.101.23`, and the absence of `[UNREPLIED]` proves return traffic is
  arriving on it.

##### ⚠️ Counter trap

`mangle` MARK is **per-packet**. `nat` SNAT is **per-connection** — the nat table
is conntrack-driven, so POSTROUTING is traversed only for the first packet of a
flow. Measured 2026-08-19: MARK ≈ **172k packets** vs SNAT ≈ **1,018 connections**.
They are **not comparable**; reading one for the other manufactures a false
anomaly. The SNAT rule averages **exactly 60.00 B/pkt** — every match is a TCP SYN.

##### ⚠️ Two failure modes with no local symptom

1. If `91.98.101.23` is **unassigned in the Hetzner console**, anti-spoof begins
   dropping PriceScout's egress silently — no interface change, no log entry, no
   failed unit. Because the address is on no interface, nothing on the host would
   reveal it.
2. **Current state does not predict post-reboot state.** At the next reboot
   `ip_up` runs again and the `/32` returns. Anything concluded from today's
   `ip addr` is a snapshot, not the steady state.

##### ⚠️ unattended-upgrades reverts manual network config on VPS2

`apt-daily-upgrade.service` restarting `systemd-networkd` rebuilds eth0 from
netplan and drops foreign addresses. Observed twice (Jul 31, Aug 11) — a
**recurring pattern on this host, not a one-off**. Any manual `ip addr add` on
VPS2 is temporary by default. To persist it, put it in netplan or make the unit
re-run; do not assume a one-shot `ip addr add` survives.

#### ⚠️ Hetzner Cloud Firewall on VPS2 — read before attaching one

As of 2026-08-20, project **15002563** contains a firewall named `firewall-1`
with **3 rules**, "Applied to: 0 Servers", status **"Not applied"**, created
about one month ago. **VPS2 therefore has NO cloud firewall protection.** A
firewall object exists — it is simply not attached. (For contrast, project
**14376238** has its own `firewall-1` with **19 rules**, fully applied to VPS1.)

**Those 3 rules have NOT been reviewed. Do not attach `firewall-1` as-is** — its
ruleset must first be checked against the mandatory inbound list below, or SSH
and marzban-node could both break.

**Outbound: leave completely EMPTY.**
With zero outbound rules Hetzner permits all egress. Add a *single* outbound
rule and everything unlisted is dropped — and PriceScout's destinations
(Telegram + scrape targets) are not enumerable. There is no safe outbound
ruleset here. Leave it empty.

**Inbound: these rules are mandatory.**

| Port | Source | Why |
|------|--------|-----|
| TCP `62050`, `62051` | `204.168.192.40/32` | marzban-node ← VPS1. **Omit these and the node drops — 84 paying customers lose service.** |
| TCP `22` | Any IPv4 (`0.0.0.0/0`) | Admin SSH. Source IP changes — do **not** lock this to a single address. |

**Inbound is otherwise fine, but verify statefulness empirically.**
Hetzner's official docs do not state whether the firewall is stateful, and say
nothing about Floating IP return paths. PriceScout's return traffic arrives as
`src=149.154.166.110:443 → dst=91.98.101.23`, which matches no inbound allow
rule. It survives only if state tracking holds *and* associates the flow with
the float. Neither is documented, so measure it rather than assume it.

Immediately after attaching:

```bash
conntrack -L | grep 149.154.166.110
```

The long-poll flow must still hold `ESTABLISHED` + `[ASSURED]` for 60+ seconds.
If statefulness does not hold, that flow dies immediately and visibly — this
failure is loud, not silent. **Detaching the firewall is a clean rollback.**

---

## Project Conventions

### Language & Direction
- All user-facing text must be in **Persian (Farsi)**
- Layout direction: **RTL** — always `dir="rtl"` on `<html>` and `direction: rtl` in CSS
- Numbers, prices, technical strings: LTR with `direction: ltr`
- Font stack: `'Vazirmatn', 'Tahoma', system-ui, sans-serif`

### Design System (dark theme only)
```css
--bg:      #0a0a0a   /* main background */
--surface: #181818   /* cards */
--border:  #2a2a2a
--orange:  #F97316   /* PRIMARY brand color */
--orange2: #FB923C   /* hover */
--orange3: #FED7AA   /* light orange */
--text:    #f2f2f2
--text2:   #c0c0c0
--muted:   #787878
```

> The purple `#6c63ff` color is **outdated** — do not use. Brand color is orange `#F97316`.

### CSS Rules
- Plain CSS only — no external frameworks
- CSS custom properties for all colors
- Mobile-first, `clamp()` for type scale
- Breakpoints: `600px`, `768px`, `1100px`

> These CSS conventions + the palette above are the **brand truth** and apply to anything new. They are not a description of the live SPA, whose styles come out of the no-code builder.

### JavaScript Rules
- ~~Vanilla JS only, no build tools~~ — described the deleted hand-written page.
- The live site is React (transpiled in-browser by the "dc" runtime). Its modules — particle canvas, hamburger menu, scroll reveal, NAV glass, FAB, plan toggle — belonged to that dead page and are **not** what runs in production.

---

## Telegram Contacts

| Channel | Purpose |
|---------|---------|
| `@onyxour_vpn_bot` | Purchase, free trial, account management |
| `@r_nsr_0` | Direct technical support |
| `@onyxour_vpn` | Announcements, discounts, news |

---

## Logo

```html
onyx<span style="color:#F97316">our</span> <small style="color:#787878">VPN</small>
```
Font: Playfair Display — always LTR, lowercase Latin.

---

## What NOT to do

- Do not switch to light theme
- Do not use CSS frameworks
- Do not use purple `#6c63ff` (old color)
- Do not write UI text in English as primary content
- Do not run `bash upload.sh` — it is deleted, and restoring it from history would overwrite the live SPA snapshot
- Do not assume `git push` deploys the site — it does not. Deploy = SCP `prerender/dist/` to VPS1.
- Do not restore `onyxour.html` / `index.html` / `onyxour-vpn.html` from history expecting them to be live — they never were
- Do not describe VPS2 as PriceScout-only — it also runs `marzban-node` and `xray-3xui-mirror.service`
- Do not compare VPS2's `mangle` MARK counter against its `nat` SNAT counter — per-packet vs per-connection, not the same unit
- Do not "fix" the missing `91.98.101.23` on VPS2's eth0 assuming egress is broken — it isn't. Check `conntrack -L` first
- Do not assume a manual `ip addr add` persists on VPS2 — unattended-upgrades wipes it
- Do not add **any** outbound rule to a VPS2 Hetzner Cloud Firewall — one rule drops everything unlisted, and PriceScout's destinations are not enumerable
- Do not attach a VPS2 firewall without allowing `204.168.192.40/32` inbound on TCP 62050–62051 — marzban-node drops and 84 paying customers lose service
- Do not attach project 15002563's `firewall-1` as-is — its 3 rules are unreviewed and could break SSH and marzban-node
