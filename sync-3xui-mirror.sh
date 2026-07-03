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

echo "[1/5] Regenerating mirror config from VPS1 runtime config.json ..."
ssh "${SSHO[@]}" "$VPS1" python3 - > "$TMP/config.json" <<'PY'
import json, sys
c = json.load(open("/usr/local/x-ui/bin/config.json"))
KEEP = {"inbound-2052", "in-2082-tcp", "in-2095-tcp", "inbound-8443"}
mir = [dict(json.loads(json.dumps(ib)), **{"listen": "0.0.0.0"})
       for ib in c["inbounds"] if ib.get("tag") in KEEP]
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
