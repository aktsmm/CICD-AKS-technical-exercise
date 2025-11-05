#!/bin/bash
################################################################################
# MongoDB オンデマンドバックアップスクリプト
# 用途: 必要なときに手動でバックアップを実行
################################################################################

set -euo pipefail

BACKUP_SCRIPT="/usr/local/bin/mongodb-backup.sh"

if [ ! -x "$BACKUP_SCRIPT" ]; then
  echo "ERROR: Backup script not found at $BACKUP_SCRIPT"
  echo "Please run setup-backup.sh first"
  exit 1
fi

echo "🚀 Starting on-demand MongoDB backup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# バックアップ実行
"$BACKUP_SCRIPT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ On-demand backup completed"
echo ""
echo "📁 Check log: tail -f /var/log/mongodb-backup.log"
echo "📦 List backups: ls -lh /var/backups/mongodb/"
