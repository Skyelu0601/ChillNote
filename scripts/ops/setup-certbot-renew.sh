#!/bin/bash

# 安装 ChillNote API 的 Certbot 自动续签计划任务。
# 用法：
#   sudo bash scripts/ops/setup-certbot-renew.sh
# 可选环境变量：
#   CERTBOT_SCHEDULE_HOURS="3,15"
#   CERTBOT_SCHEDULE_MINUTE="17"

set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "❌ 请使用 root 运行此脚本"
    echo "   用法: sudo bash scripts/ops/setup-certbot-renew.sh"
    exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
    echo "❌ 未检测到 certbot，请先安装 certbot"
    exit 1
fi

SCHEDULE_HOURS="${CERTBOT_SCHEDULE_HOURS:-3,15}"
SCHEDULE_MINUTE="${CERTBOT_SCHEDULE_MINUTE:-17}"
CRON_FILE="/etc/cron.d/certbot-renew"

cat >"$CRON_FILE" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

${SCHEDULE_MINUTE} ${SCHEDULE_HOURS} * * * root certbot renew --quiet --no-random-sleep-on-renew
EOF

chmod 644 "$CRON_FILE"

echo "✅ 已写入自动续签任务: $CRON_FILE"
cat "$CRON_FILE"

echo
echo "📌 建议现在手动验证一次："
echo "   certbot renew --dry-run --no-random-sleep-on-renew"
