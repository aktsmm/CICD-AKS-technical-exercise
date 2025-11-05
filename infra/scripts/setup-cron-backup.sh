#!/bin/bash
################################################################################
# MongoDB バックアップ cron 設定スクリプト
# 用途: VM 上で1時間おきに自動バックアップを実行する cron ジョブを設定
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
# - 毎時0分 - 1時間おきバックアップ (ログファイルへ出力)

CRON_JOBS=(
  "0 * * * * $BACKUP_SCRIPT >> /var/log/mongodb-backup.log 2>&1  # Hourly backup"
)

echo "Setting up MongoDB backup cron jobs for user: $CRON_USER"

# 既存の mongodb-backup cron ジョブを削除（重複防止）
existing_cron=$(crontab -u "$CRON_USER" -l 2>/dev/null || true)
filtered_cron=$(echo "$existing_cron" | grep -v "$BACKUP_SCRIPT" || true)

# 新しい cron ジョブを追加
(
  if [ -n "$filtered_cron" ]; then
    echo "$filtered_cron"
  fi
  for job in "${CRON_JOBS[@]}"; do
    echo "$job"
  done
) | crontab -u "$CRON_USER" -

echo "✅ Cron jobs configured successfully:"
crontab -u "$CRON_USER" -l | grep "$BACKUP_SCRIPT"

echo ""
echo "📋 Backup Schedule:"
echo "  - Every hour at :00 minutes (1時間おき)"
echo ""
echo "📁 Log file: /var/log/mongodb-backup.log"
echo ""
echo "🔧 Manual execution:"
echo "  sudo $BACKUP_SCRIPT"
