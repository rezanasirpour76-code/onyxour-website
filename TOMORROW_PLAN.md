# VPS2 (Germany) permanent VPN — ✅ COMPLETED 2026-07-03

_Both user groups are now served from Germany (VPS2 178.105.14.66) in addition to
Helsinki (VPS1 204.168.192.40), kept **deliberately separate**. Iran/Turkey clients
auto-select Germany because it's faster. Verified from Iran (sales, 147ms) and Turkey
(special users, 86ms); the balancer picks Germany over Helsinki in both._

## Final architecture on VPS2 (all side-by-side, isolated)
```
VPS2 178.105.14.66 (Hetzner, Falkenstein, Ubuntu 24.04, BBR+fq)
├── PriceScout          systemd, NO listening ports  → untouched throughout
├── marzban-node        Docker (network_mode host)   → Marzban SALES group
│     xray pid, ports 2083/2086/8880 + control 62050/62051
│     runs pinned xray 26.6.27 (mounted, XRAY_EXECUTABLE_PATH) to match VPS1 REALITY
└── xray-3xui-mirror    systemd standalone xray 26.6.27 → 3X-UI SPECIAL group
      ports 2052/2082/2095/8443, same UUIDs + same REALITY privateKey as VPS1
```
Separation = **two distinct xray processes + non-overlapping port sets + separate
UUID/DB**. Marzban ports {2083,2086,8880} vs 3X-UI ports {2052,2082,2095,8443} never
collide. Cross-auth impossible. Confirmed at process level (different PIDs).

## Group 1 — Marzban sales (native node) — DONE
- `marzban-node` container on VPS2, client cert from panel `/api/node/settings`.
- Registered in panel as **Germany-VPS2** (id 1) → status **connected**, auto-syncs users.
- Panel `hosts`: added Germany rows (append-only, existing untouched):
  - `VLESS Reality` → `178.105.14.66:2083` (sni dl.google.com) — primary, secure, fast
  - `VLESS WS 8880` → `178.105.14.66:8880` — direct fallback
- Users keep same UUID + same sub link; Germany configs just get added; balancer auto-picks.

## Group 2 — 3X-UI special (mirror + externalProxy) — DONE
- Standalone `xray-3xui-mirror` on VPS2 mirrors all 4 inbounds (2052/2082/2095/8443),
  same UUIDs + same REALITY key (pubkey `vIyShfoX…`, sid `8b2c37e2be360fea`, sni dl.google.com).
- Delivery method chosen: **Reality only (secure)**. On VPS1:
  - Appended Germany `externalProxy` to reality inbound id9: `dest=178.105.14.66:8443`.
  - Migrated all **26** special users onto the reality inbound (additive; WS untouched).
- **Fork gotcha (important):** this 3X-UI is a custom fork of mhsanaei/3x-ui (v3.4.2) with
  a normalized schema + a native (unused) node system. It keeps **dual bookkeeping**:
  `client_inbounds` (drives the xray runtime config) AND `inbounds.settings` JSON (drives
  the **subscription** generator). The sub also needs `clients.flow='xtls-rprx-vision'`.
  Adding a client to reality **via the panel** updates all of these correctly. Direct DB
  edits must touch all three or the sub won't show the reality config. (We fixed all three.)
- Result per special user: 3× WS Helsinki (unchanged) + Reality Helsinki + Reality Germany.

## Keeping the 3X-UI mirror in sync — `sync-3xui-mirror.sh` (repo root)
- The Marzban group self-syncs via the node. The 3X-UI mirror is a **snapshot**.
- **After adding/removing/editing any 3X-UI client on VPS1 (via the panel — especially
  reality/inbound-8443 membership), run from the local machine:** `bash sync-3xui-mirror.sh`
- It regenerates the mirror config from VPS1's runtime config.json, validates with
  `xray -test` on VPS2, backs up + swaps + reloads the mirror. Aborts (mirror untouched)
  on any validation failure. Only mirrors inbounds 2052/2082/2095/8443 (separation kept).

## Firewall / ports (VPS2) — verified 2026-07-03
- All VPN ports externally OPEN: 2052,2082,2083,2086,2095,8443,8880. SSH 22 open.
- No host firewall (ufw inactive; iptables only Docker's auto chains). No restrictive
  Hetzner cloud FW on VPN ports. PriceScout exposes **no** ports.

## Phase 5 — PriceScout egress IP isolation — ✅ DONE 2026-07-03
Floating IP **91.98.101.23** (Hetzner, Falkenstein) assigned to VPS2. Goal met:
**PriceScout egresses via 91.98.101.23; VPN + everything else via the main 178.105.14.66.**
- Floating IP added to `eth0`; Hetzner allows outbound from it (verified `--interface`).
- Isolation by **cgroup v2** (PriceScout runs as root, so UID match won't do): mark
  `pricescout.service` cgroup in `mangle OUTPUT` → `nat POSTROUTING SNAT --to-source 91.98.101.23`.
- IPv6 leak closed: system prefers IPv6, and the Floating IP is v4-only, so
  `ip6tables OUTPUT -m cgroup … -j REJECT` forces PriceScout to IPv4 (targets are dual-stack).
- **⚠️ Gotcha:** the iptables cgroup2 `--path` match binds to the cgroup **object at add-time**;
  pricescout's cgroup is recreated on every restart → rules go stale. Fixed by re-binding on
  each start via a **`ExecStartPre` drop-in** (binds before the bot's first packet — no race;
  a mid-run `ExecStartPost` del+add would briefly leak, so it's NOT used).
- Persistence: `priceout-floating-ip.service` (enabled, owns the IP) + script
  `/usr/local/sbin/priceout-floating-ip.sh` (modes ip-up/down, rules-up/down) +
  pricescout drop-in `10-floating-egress.conf` (ExecStartPre=rules-up, ExecStopPost=rules-down).
- Verified: bot scrape egress = 91.98.101.23 (api.ipify/icanhazip/httpbin); all 45 xray/VPN
  flows = 178.105.14.66; v6 REJECT + v4 SNAT counters incrementing. rp_filter=2 (loose) is
  what lets replies to the Floating IP return. **Full rollback:** `systemctl disable --now
  priceout-floating-ip` + remove the drop-in. Net backups in `/root/backups/netphase5-*`.
- **Not yet tested across a real reboot** (avoided rebooting to not disrupt VPN users); the
  mechanism is standard + enabled. Reboot at a low-traffic time to fully confirm boot-time.

## Remaining / optional
1. **Optional hardening:** restrict node control ports **62050/62051 to VPS1 only**
   (currently world-open; 62050 is mutual-TLS protected, 62051 xray-API is not). Would add
   host iptables allow-from-204.168.192.40 + drop. Not done (misconfig could drop the node).
2. **CX32 rescale — NOT needed** (VPS2 idle: load ~0, ~720MB/3.8GB used with everything running).

## Backups (created this run)
- VPS1 `/root/backups/pre-vps2-20260703_100801/`: `x-ui.db`, `marzban_full.sql`,
  `marzban.env`, `xray_config.json`, `hosts_before.txt`, `hosts_api_before/after.json`,
  and 3X-UI DB snapshots `x-ui.db.pre-step2`, `x-ui.db.pre-flowfix`, `x-ui.db.pre-settingsfix`.
- VPS2: `/root/backup_speedtest_config.json`; mirror keeps `config.json.bak_*` on each sync.
- Temp `xray-speedtest` (VPS2:8443) removed — the permanent mirror reality inbound replaced it.
