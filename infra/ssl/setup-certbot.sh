#!/usr/bin/env bash
# One-time setup: install certbot, issue certificate, wire up auto-renewal.
#
# Run once on the server as root:
#   sudo bash setup-certbot.sh

set -euo pipefail

DOMAIN="r1.onyxour.com"
EMAIL="reza.nasirpour76@gmail.com"
MARZBAN_DIR="/var/lib/marzban"
HOOK_DST="/etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh"

echo ">>> Installing certbot..."
apt-get update -qq
apt-get install -y certbot

echo ">>> Creating Marzban certs directory..."
mkdir -p "${MARZBAN_DIR}/certs"

echo ">>> Issuing certificate for ${DOMAIN}..."
# Uses standalone mode — temporarily binds port 80.
# Stop any service on port 80 before running, or use --webroot if nginx/apache is running.
certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    -d "${DOMAIN}"

echo ">>> Copying initial certs..."
cp -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "${MARZBAN_DIR}/certs/fullchain.pem"
cp -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "${MARZBAN_DIR}/certs/privkey.pem"
chmod 640 "${MARZBAN_DIR}/certs/privkey.pem"

echo ">>> Installing deploy hook..."
cp -f "$(dirname "$0")/deploy-hook.sh" "${HOOK_DST}"
chmod +x "${HOOK_DST}"

echo ">>> Enabling certbot systemd timer (auto-renewal)..."
systemctl enable --now certbot.timer

echo ">>> Testing renewal dry-run..."
certbot renew --dry-run

echo ""
echo "✅ Done! Certificate issued and auto-renewal configured."
echo "   Cert path : /etc/letsencrypt/live/${DOMAIN}/"
echo "   Marzban   : ${MARZBAN_DIR}/certs/"
echo "   Hook      : ${HOOK_DST}"
echo "   Timer     : $(systemctl status certbot.timer | grep Active)"
