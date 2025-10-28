#!/bin/bash
set -e

STORAGE_ACCOUNT="$1"
CONTAINER_NAME="$2"

# Azure CLI インストール
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# バックアップディレクトリ作成
mkdir -p /var/backups/mongodb

# バックアップスクリプトをコピーして設定
cat > /usr/local/bin/mongodb-backup.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"
STORAGE_ACCOUNT="__STORAGE_ACCOUNT__"
CONTAINER_NAME="__CONTAINER_NAME__"

mongodump --out ${BACKUP_DIR}/dump_${TIMESTAMP}
cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP}
rm -rf dump_${TIMESTAMP}

az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login || echo "Upload failed"

find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete
echo "Backup completed: ${BACKUP_FILE}"
EOF

# Storage Account 情報を置換
sed -i "s/__STORAGE_ACCOUNT__/${STORAGE_ACCOUNT}/g" /usr/local/bin/mongodb-backup.sh
sed -i "s/__CONTAINER_NAME__/${CONTAINER_NAME}/g" /usr/local/bin/mongodb-backup.sh

chmod +x /usr/local/bin/mongodb-backup.sh

# Managed Identity でログイン
az login --identity

# Cron ジョブ設定
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongodb-backup.sh >> /var/log/mongodb-backup.log 2>&1") | crontab -

# 初回バックアップを実行（失敗してもスクリプトは続行）
/usr/local/bin/mongodb-backup.sh || echo "Initial backup failed"

echo "Backup setup completed"
