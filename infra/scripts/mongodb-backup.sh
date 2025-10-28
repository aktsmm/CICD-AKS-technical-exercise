#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"
STORAGE_ACCOUNT="__STORAGE_ACCOUNT__"
CONTAINER_NAME="__CONTAINER_NAME__"

# MongoDB バックアップ（認証なしでダンプ）
mongodump --out ${BACKUP_DIR}/dump_${TIMESTAMP}

# 圧縮
cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP}
rm -rf dump_${TIMESTAMP}

# Azure Storage にアップロード（Managed Identity 使用）
az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login || echo "Backup upload failed but continuing"

# ローカルバックアップは7日間保持
find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
