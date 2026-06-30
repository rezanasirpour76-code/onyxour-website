#!/usr/bin/env bash
# Deploy index.html to VPS1 (Onyxour) over SSH key auth.
# The server is key-only (password auth disabled), so this uses your SSH key.
set -euo pipefail

SERVER="root@204.168.192.40"
REMOTE="/var/www/html/index.html"
LOCAL="$(dirname "$0")/index.html"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "Error: SSH key not found at $SSH_KEY" >&2
  echo "Set SSH_KEY=/path/to/key to override." >&2
  exit 1
fi

echo "Deploying to $SERVER..."
scp -i "$SSH_KEY" "$LOCAL" "$SERVER:$REMOTE"
echo "Done — $(wc -c < "$LOCAL") bytes uploaded."
