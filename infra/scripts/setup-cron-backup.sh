#!/bin/bash
################################################################################
# MongoDB バックアップ cron 設定スクリプト
# 用途: VM 上で1日3回自動バックアップを実行する cron ジョブを設定
################################################################################

set -euo pipefail

BACKUP_SCRIPT="/usr/local/bin/mongodb-backup.sh"
CRON_USER="root"

# バックアップスクリプトの存在確認
if [ ! -x "$BACKUP_SCRIPT" ]; then
  echo "ERROR: Backup script not found at $BACKUP_SCRIPT"
  echo "Please run setup-backup.sh first"
  exit 1
fi

# cron ジョブ設定
# - 02:00 JST (17:00 UTC 前日) - 深夜バックアップ
# - 10:00 JST (01:00 UTC) - 午前バックアップ
# - 18:00 JST (09:00 UTC) - 夕方バックアップ

CRON_JOBS=(
  "0 17 * * * $BACKUP_SCRIPT >> /var/log/mongodb-backup.log 2>&1  # Daily 02:00 JST"
  "0 1 * * * $BACKUP_SCRIPT >> /var/log/mongodb-backup.log 2>&1   # Daily 10:00 JST"
  "0 9 * * * $BACKUP_SCRIPT >> /var/log/mongodb-backup.log 2>&1   # Daily 18:00 JST"
)

echo "Setting up MongoDB backup cron jobs for user: $CRON_USER"

# 既存の mongodb-backup cron ジョブを削除
crontab -u "$CRON_USER" -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -u "$CRON_USER" - || true

# 新しい cron ジョブを追加
(
  crontab -u "$CRON_USER" -l 2>/dev/null || true
  for job in "${CRON_JOBS[@]}"; do
    echo "$job"
  done
) | crontab -u "$CRON_USER" -

echo "✅ Cron jobs configured successfully:"
crontab -u "$CRON_USER" -l | grep "$BACKUP_SCRIPT"

echo ""
echo "📋 Backup Schedule (JST):"
echo "  - 02:00 JST (17:00 UTC) - 深夜バックアップ"
echo "  - 10:00 JST (01:00 UTC) - 午前バックアップ"
echo "  - 18:00 JST (09:00 UTC) - 夕方バックアップ"
echo ""
echo "📁 Log file: /var/log/mongodb-backup.log"
echo ""
echo "🔧 Manual execution:"
echo "  sudo $BACKUP_SCRIPT"
