#!/usr/bin/env bash
# Quick health check — shows cert expiry and renewal status.
# Run anytime: bash check-ssl.sh

DOMAIN="r1.onyxour.com"
PORT="2087"

echo "=== SSL Certificate Status ==="
echo ""

# Expiry from live server
echo "[ Server certificate ]"
EXPIRY=$(echo | openssl s_client -connect "${DOMAIN}:${PORT}" -servername "${DOMAIN}" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
echo "  Domain  : ${DOMAIN}:${PORT}"
echo "  Expires : ${EXPIRY:-could not connect}"

# Days remaining
if [[ -n "${EXPIRY}" ]]; then
    EXPIRY_EPOCH=$(date -d "${EXPIRY}" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "${EXPIRY}" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
    if (( DAYS_LEFT <= 14 )); then
        echo "  ⚠️  WARN: Only ${DAYS_LEFT} days left — renewal may not have run!"
    else
        echo "  ✅ ${DAYS_LEFT} days remaining"
    fi
fi

echo ""
echo "[ Certbot renewal status ]"
certbot certificates -d "${DOMAIN}" 2>/dev/null || echo "  certbot not found or cert not issued yet"

echo ""
echo "[ Systemd timer ]"
systemctl status certbot.timer --no-pager -l 2>/dev/null || echo "  certbot.timer not found"

echo ""
echo "[ Last renewal log ]"
tail -20 /var/log/marzban-ssl-renew.log 2>/dev/null || echo "  No renewal log yet — hook hasn't run."
