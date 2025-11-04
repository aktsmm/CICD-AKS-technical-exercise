#!/bin/bash
set -e
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"
STORAGE_ACCOUNT="__STORAGE_ACCOUNT__"
CONTAINER_NAME="__CONTAINER_NAME__"
LOG_FILE="/var/log/mongodb-backup.log"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup (legacy script)..." | tee -a "$LOG_FILE"

mongodump --out ${BACKUP_DIR}/dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"

cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"
rm -rf dump_${TIMESTAMP}

az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login 2>&1 | tee -a "$LOG_FILE" || {
  echo "[$(date)] ERROR: Upload failed" | tee -a "$LOG_FILE"
  exit 0
}

find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete

PUBLIC_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${BACKUP_FILE}"
SAS_EXPIRY=$(date -u -d "+1 day" "+%Y-%m-%dT%H:%MZ")
SAS_TOKEN=$(az storage blob generate-sas \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --permissions r \
  --expiry ${SAS_EXPIRY} \
  --https-only \
  --auth-mode login 2>/dev/null || true)

if [ -n "$SAS_TOKEN" ]; then
  echo "[$(date)] SAS URL: ${PUBLIC_URL}?${SAS_TOKEN}" | tee -a "$LOG_FILE"
else
  echo "[$(date)] WARNING: SAS generation failed; fallback URL: ${PUBLIC_URL}" | tee -a "$LOG_FILE"
fi

echo "[$(date)] Backup completed: ${PUBLIC_URL}" | tee -a "$LOG_FILE"
