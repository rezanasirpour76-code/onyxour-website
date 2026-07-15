#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# sync-3xui-mirror.sh
#
# Keeps the 3X-UI special-users mirror on VPS2 (Germany, 178.105.14.66) in
# sync with VPS1's (204.168.192.40) current 3X-UI client list.
#
# WHEN TO RUN: after you add / remove / edit any 3X-UI client on VPS1 via the
# panel — ESPECIALLY reality (inbound-8443) memberships — so the Germany
# mirror serves the same UUIDs. The Marzban sales group syncs itself through
# marzban-node; THIS script is only for the 3X-UI special-users group.
#
# Run from the local machine (it has SSH keys to both servers). Safe & atomic:
# it validates the new config with `xray -test` on VPS2 and only swaps + reloads
# if valid; the previous config is backed up. Aborts (mirror untouched) on any
# validation failure.
#
# SOURCE OF TRUTH: the client list is read from VPS1's x-ui DB (clients +
# client_inbounds), NOT from bin/config.json. config.json is a bootstrap file
# that 3X-UI does not rewrite when clients are added via its gRPC API, so it
# goes stale between xray restarts. See the comment in step [1/5].
#
# Separation is preserved: only inbounds 2052/2082/2095/8443 are mirrored;
# the Marzban node (2083/2086/8880) and PriceScout are never touched.
# ---------------------------------------------------------------------------
set -euo pipefail

KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
VPS1="root@204.168.192.40"
VPS2="root@178.105.14.66"
MIRROR_DIR="/usr/local/etc/xray-3xui"
# array keeps the key path intact even if it contains spaces (e.g. Windows)
SSHO=(-i "$KEY" -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Pre-flight: warn about reality (inbound-8443) members with a missing/incorrect
# flow. A reality member without 'xtls-rprx-vision' will NOT be served properly
# even though their sub advertises it. Fix in the panel then re-run. Non-blocking.
#
# The effective per-inbound flow is client_inbounds.flow_override — verified
# against the live xray API (`xray api inbounduser`), which agrees with it
# exactly. clients.flow is a stale/unused default and must NOT be checked here:
# doing so produced false positives for clients whose override is correct.
echo "[0/5] Pre-flight: reality users missing the vision flow ..."
BROKEN=$(ssh "${SSHO[@]}" "$VPS1" "sqlite3 /etc/x-ui/x-ui.db \"SELECT c.email FROM clients c JOIN client_inbounds ci ON ci.client_id=c.id WHERE ci.inbound_id=9 AND c.enable=1 AND COALESCE(ci.flow_override,'')<>'xtls-rprx-vision';\"" 2>/dev/null || true)
if [ -n "$BROKEN" ]; then
  echo "  ⚠️  These reality users have a missing/incorrect flow and will NOT work on"
  echo "      Germany reality (sub may show it, but the server won't serve them):"
  echo "$BROKEN" | sed 's/^/        - /'
  echo "      Fix: in the 3X-UI panel set each one's flow to 'xtls-rprx-vision', then re-run."
else
  echo "  OK — all reality users have the vision flow."
fi

echo "[1/5] Regenerating mirror config (inbound skeleton from config.json, CLIENTS FROM DB) ..."
ssh "${SSHO[@]}" "$VPS1" python3 - > "$TMP/config.json" <<'PY'
import json, sqlite3, sys

# WHY THIS READS THE DB, NOT config.json, FOR THE CLIENT LIST:
# 3X-UI adds/removes clients on the RUNNING xray via its gRPC API (the 'api'
# inbound on 127.0.0.1:62789) WITHOUT rewriting bin/config.json. So config.json
# is only a bootstrap file and goes stale the moment a client is added; it is
# only rewritten when xray restarts. Building the mirror from it silently
# omitted every client created since the last restart (they worked on VPS1 but
# Germany had never heard of them, while this script still reported "in sync").
#
# The DB (clients + client_inbounds) is authoritative and matches the live xray
# API exactly. The per-inbound flow is client_inbounds.flow_override.
#
# The inbound SKELETON (port/protocol/streamSettings/sniffing) still comes from
# config.json on purpose: it is already xray-ready and validated, whereas the
# DB's stream_settings carries panel-only fields (maxClient/minClient/show/...)
# that are not part of xray's schema. Inbound-level edits restart xray anyway,
# which regenerates config.json, so the skeleton does not go stale in practice.

KEEP = {"inbound-2052", "in-2082-tcp", "in-2095-tcp", "inbound-8443"}

cfg = json.load(open("/usr/local/x-ui/bin/config.json"))
db = sqlite3.connect("/etc/x-ui/x-ui.db")
tag_to_id = {tag: iid for iid, tag in db.execute("SELECT id, tag FROM inbounds")}

mir = []
for ib in cfg["inbounds"]:
    tag = ib.get("tag")
    if tag not in KEEP:
        continue
    iid = tag_to_id.get(tag)
    if iid is None:
        sys.stderr.write("ERROR: no inbound id in DB for tag %s\n" % tag)
        sys.exit(1)

    clients = []
    for email, uuid, flow in db.execute(
            "SELECT c.email, c.uuid, COALESCE(ci.flow_override,'') "
            "FROM clients c JOIN client_inbounds ci ON ci.client_id = c.id "
            "WHERE ci.inbound_id = ? AND c.enable = 1 "
            "ORDER BY c.id", (iid,)):
        u = {"id": uuid, "email": email}
        if flow:                       # omit the key entirely when empty (WS inbounds)
            u["flow"] = flow
        clients.append(u)

    # Guard: never publish an empty inbound - that would silently cut everyone off.
    if not clients:
        sys.stderr.write("ERROR: 0 enabled clients for %s - aborting\n" % tag)
        sys.exit(1)

    nib = json.loads(json.dumps(ib))   # deep copy of the validated skeleton
    nib["listen"] = "0.0.0.0"
    nib["settings"] = {
        "clients": clients,
        "decryption": (ib.get("settings") or {}).get("decryption", "none"),
    }
    mir.append(nib)
    sys.stderr.write("      %-15s clients=%d\n" % (tag, len(clients)))

if len(mir) != len(KEEP):
    sys.stderr.write("ERROR: expected %d inbounds, built %d - aborting\n" % (len(KEEP), len(mir)))
    sys.exit(1)

out = {"log": {"loglevel": "warning"},
       "inbounds": mir,
       "outbounds": [{"protocol": "freedom", "tag": "direct"},
                     {"protocol": "blackhole", "tag": "blocked"}],
       "routing": {"rules": []}}
sys.stdout.write(json.dumps(out, indent=2))
PY

if [ ! -s "$TMP/config.json" ]; then
  echo "ERROR: generated config is empty — aborting (mirror untouched)." >&2
  exit 1
fi

echo "[2/5] Uploading to VPS2 ..."
scp "${SSHO[@]}" -q "$TMP/config.json" "$VPS2:/root/mirror-sync-new.json"

echo "[3/5] Validating on VPS2 (xray -test) ..."
if ! ssh "${SSHO[@]}" "$VPS2" "$MIRROR_DIR/xray run -test -c /root/mirror-sync-new.json 2>&1 | tail -1 | grep -q 'Configuration OK'"; then
  echo "ERROR: config failed xray validation on VPS2 — aborting, mirror untouched." >&2
  ssh "${SSHO[@]}" "$VPS2" "rm -f /root/mirror-sync-new.json" || true
  exit 1
fi

echo "[4/5] Backing up + swapping config + reloading mirror ..."
ssh "${SSHO[@]}" "$VPS2" "cp -a $MIRROR_DIR/config.json $MIRROR_DIR/config.json.bak_\$(date +%Y%m%d_%H%M%S) \
  && mv /root/mirror-sync-new.json $MIRROR_DIR/config.json \
  && systemctl restart xray-3xui-mirror && sleep 2 \
  && echo mirror=\$(systemctl is-active xray-3xui-mirror)"

echo "[5/5] Verifying mirror client counts ..."
ssh "${SSHO[@]}" "$VPS2" "python3 -c \"import json;c=json.load(open('$MIRROR_DIR/config.json'));print('mirror:',{i['tag']:len((i.get('settings',{}) or {}).get('clients',[])) for i in c['inbounds']})\""

echo "Done — 3X-UI Germany mirror is in sync."
