#!/usr/bin/env bash
# /etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh
#
# Certbot deploy hook — runs automatically after every successful renewal.
# Copies the new cert/key into Marzban's config directory and restarts the
# service so the new certificate takes effect immediately.
#
# Install:
#   sudo cp deploy-hook.sh /etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh
#   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/marzban-ssl.sh

set -euo pipefail

DOMAIN="r1.onyxour.com"
CERT_SRC="/etc/letsencrypt/live/${DOMAIN}"
MARZBAN_DIR="/var/lib/marzban"
LOG_FILE="/var/log/marzban-ssl-renew.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== SSL renewal deploy hook started for ${DOMAIN} ==="

# Only run when certbot renewed our domain's cert
if [[ "${RENEWED_DOMAINS:-}" != *"${DOMAIN}"* ]]; then
    log "Domain ${DOMAIN} not in RENEWED_DOMAINS — skipping."
    exit 0
fi

# Copy certs into Marzban's directory
log "Copying certificates to ${MARZBAN_DIR}..."
cp -f "${CERT_SRC}/fullchain.pem" "${MARZBAN_DIR}/certs/fullchain.pem"
cp -f "${CERT_SRC}/privkey.pem"   "${MARZBAN_DIR}/certs/privkey.pem"
chmod 640 "${MARZBAN_DIR}/certs/privkey.pem"

# Restart Marzban
log "Restarting Marzban..."
if systemctl is-active --quiet marzban; then
    systemctl restart marzban
    log "Marzban restarted successfully."
else
    log "WARNING: Marzban service is not active — skipping restart."
fi

log "=== Deploy hook completed ==="
