#!/usr/bin/env bash
# Deploy index.html to VPS1 via SCP (password auth)
# Usage: bash upload.sh
set -euo pipefail

SERVER="root@204.168.192.40"
REMOTE="/var/www/html/index.html"
LOCAL="$(dirname "$0")/index.html"

echo "Deploying to $SERVER..."
scp "$LOCAL" "$SERVER:$REMOTE"
echo "Done — $(wc -c < "$LOCAL") bytes uploaded."
