#!/usr/bin/env bash
# Deploy index.html to VPS1 via pscp (PuTTY)
set -euo pipefail

SERVER="root@204.168.192.40"
REMOTE="/var/www/html/index.html"
LOCAL="$(dirname "$0")/index.html"
HOSTKEY="ssh-ed25519 255 SHA256:gYL7ZU/FWbHOgXE7MBYyCW5ZZbiHkxqEouC4az1j6qY"
PSCP="/c/Program Files/PuTTY/pscp.exe"

if [[ ! -f "$PSCP" ]]; then
  echo "Error: pscp not found at $PSCP"
  exit 1
fi

echo "Deploying to $SERVER..."
"$PSCP" -pw "aUx9wMUp4jLr" -hostkey "$HOSTKEY" "$LOCAL" "$SERVER:$REMOTE"
echo "Done — $(wc -c < "$LOCAL") bytes uploaded."
