#!/bin/bash
# =============================================
# ONYXOUR VPN — Full Audit Script
# Run on VPS1:  bash audit.sh
# (or from a workstation:  ssh root@204.168.192.40 'bash -s' < audit.sh)
# =============================================

echo "======================================"
echo "  ONYXOUR VPN — بررسی کامل سرور"
echo "  $(date)"
echo "======================================"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 منابع سرور"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "--- CPU / RAM / Disk ---"
top -bn1 | grep "Cpu(s)" | awk '{print "CPU: " $2 "% used"}'
free -h | awk '/^Mem:/ {print "RAM: " $3 " used of " $2}'
df -h / | awk 'NR==2 {print "Disk: " $3 " used of " $2 " (" $5 ")"}'

echo ""
echo "--- BBR ---"
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc

echo ""
echo "--- File Descriptor Limit ---"
cat /proc/sys/fs/file-max
ulimit -n

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔵 3X-UI — وضعیت"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl is-active x-ui 2>/dev/null || echo "x-ui service: not found (may be different name)"
ps aux | grep -E "(x-ui|xray)" | grep -v grep | head -5

echo ""
echo "--- پورت‌های 3X-UI ---"
ss -tlnp | grep -E "(2082|2095|2052|2053|443|22795|2096)" | sort

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 Marzban — وضعیت"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /opt/marzban && docker compose ps 2>/dev/null

echo ""
echo "--- نسخه Xray مرزبان ---"
docker exec marzban-marzban-1 xray version 2>/dev/null | head -2

echo ""
echo "--- پورت‌های مرزبان ---"
ss -tlnp | grep -E "(2086|2083|8880|2087)" | sort

echo ""
echo "--- سلامت کانتینر MySQL مرزبان (کرش/ری‌استارت؟) ---"
# Recurring-crash guard: host mysql-server must NOT reappear and steal /var/lib/mysql.
# See known issue: broken host pkg chown-ing the nested datadir → InnoDB error 13 → SIGABRT.
echo -n "RestartCount / OOMKilled: "
docker inspect marzban-mysql-1 --format 'restarts={{.RestartCount}} oom={{.State.OOMKilled}} status={{.State.Status}}' 2>/dev/null
echo -n "InnoDB perm/crash errors since current start: "
MYSQL_STARTED=$(docker inspect -f '{{.State.StartedAt}}' marzban-mysql-1 2>/dev/null)
docker logs marzban-mysql-1 --since "$MYSQL_STARTED" 2>&1 | grep -cE "error 13|got signal|Assertion failure" || echo 0
echo -n "host mysql-server pkg present (should be none): "
dpkg -l 2>/dev/null | grep -E "^ii\s+mysql-server" | awk '{print $2}' | tr '\n' ' '; echo "(none = good)"
echo -n "host mysql.service state (should be masked/not-found): "
systemctl is-enabled mysql.service 2>&1

echo ""
echo "--- لاگ آخر مرزبان (۱۵ خط) ---"
docker logs marzban-marzban-1 --tail 15 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  Xray Config مرزبان — اینباندها"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat /var/lib/marzban/xray_config.json | python3 -c "
import json,sys
cfg = json.load(sys.stdin)
for ib in cfg.get('inbounds', []):
    print(f\"TAG: {ib.get('tag','?')} | PORT: {ib.get('port','?')} | PROTO: {ib.get('protocol','?')}\")
    net = ib.get('streamSettings',{}).get('network','?')
    sec = ib.get('streamSettings',{}).get('security','?')
    sni = ib.get('streamSettings',{}).get('realitySettings',{}).get('serverNames',[''])[0] if sec=='reality' else ''
    print(f\"  Network: {net} | Security: {sec}\" + (f' | SNI: {sni}' if sni else ''))
"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Nginx — وضعیت"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
nginx -t 2>&1
systemctl is-active nginx
echo "--- کانفیگ onyxour ---"
cat /etc/nginx/conf.d/onyxour.conf 2>/dev/null || cat /etc/nginx/sites-enabled/default 2>/dev/null | head -30

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 ربات تلگرام (MirzaBot)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl is-active apache2
ss -tlnp | grep ":88 "
echo "--- webhook تنظیم شده؟ ---"
CFG=/var/www/html/mirzabotconfig/config.php
# MirzaBot stores the bot token in $APIKEY (NOT bot_token/BOT_TOKEN).
TOKEN=$(grep -oP "APIKEY\s*=\s*['\"]\K[0-9]+:[A-Za-z0-9_-]+" "$CFG" 2>/dev/null | head -1)
if [ -n "$TOKEN" ]; then
  # Bot identity
  curl -s "https://api.telegram.org/bot${TOKEN}/getMe" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)['result']
    print('Bot:', '@'+d.get('username','?'), '|', d.get('first_name',''), '| id', d.get('id'))
except Exception as e:
    print('getMe failed:', e)
"
  # Webhook registration
  curl -s "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" | python3 -c "
import json,sys,re
d=json.load(sys.stdin)['result']
url=re.sub(r'[0-9]{6,}:[A-Za-z0-9_-]{30,}','<TOKEN>',d.get('url','') or '(empty)')
print('Webhook URL:', url)
print('Pending updates:', d.get('pending_update_count',0))
if d.get('last_error_message'):
    import datetime
    ts=d.get('last_error_date',0)
    print('Last error:', d['last_error_message'], '@', datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC') if ts else '?')
"
  # LIVE reachability: does the endpoint actually answer, not just 'is a URL registered'?
  RAWURL=$(curl -s "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'].get('url',''))")
  if [ -n "$RAWURL" ]; then
    echo -n "Live webhook POST test: "
    curl -s -o /dev/null -w "HTTP %{http_code} (connect=%{time_connect}s total=%{time_total}s)\n" \
      -X POST -H "Content-Type: application/json" -d '{}' --max-time 15 "$RAWURL"
  fi
else
  echo "توکن پیدا نشد — مسیر یا نام متغیر config.php را چک کن (انتظار: \$APIKEY)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 SSL گواهی‌ها"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for domain in r1.onyxour.com vpn.onyxour.com; do
  echo -n "$domain: "
  echo | openssl s_client -connect ${domain}:443 -servername ${domain} 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter || echo "SSL نگرفت"
done
echo -n "Marzban cert: "
openssl x509 -noout -dates -in /var/lib/marzban/certs/fullchain.pem 2>/dev/null | grep notAfter || echo "فایل پیدا نشد"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 ترافیک ماه جاری"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
vnstat -i eth0 --oneline 2>/dev/null || vnstat --oneline 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 پورت‌های باز کل سرور"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ss -tlnp | sort

echo ""
echo "======================================"
echo "✅ بررسی تموم شد"
echo "======================================"
