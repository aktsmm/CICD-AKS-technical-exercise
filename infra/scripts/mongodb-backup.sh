#!/bin/bash
set -euo pipefail
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"
STORAGE_ACCOUNT="__STORAGE_ACCOUNT__"
CONTAINER_NAME="__CONTAINER_NAME__"
MONGO_USER="__MONGO_USER__"
MONGO_PASSWORD="__MONGO_PASSWORD__"
LOG_FILE="/var/log/mongodb-backup.log"

log_line() {
  echo "[$(date)] $*" | tee -a "$LOG_FILE"
}


mkdir -p "$BACKUP_DIR"
log_line "Starting backup..."

log_line "Attempting Managed Identity login..."
if ! az login --identity 2>&1 | tee -a "$LOG_FILE"; then
  log_line "WARNING: Managed Identity login failed"
fi

if ! mongodump \
  --host localhost \
  --port 27017 \
  --username "$MONGO_USER" \
  --password "$MONGO_PASSWORD" \
  --authenticationDatabase admin \
  --out ${BACKUP_DIR}/dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"; then
  log_line "ERROR: mongodump failed"
  exit 1
fi

cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"
rm -rf dump_${TIMESTAMP}

FILE_PATH="${BACKUP_DIR}/${BACKUP_FILE}"
FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)

if ! az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --overwrite \
  --auth-mode login 2>&1 | tee -a "$LOG_FILE"; then
  log_line "ERROR: Upload failed"
  exit 1
fi

find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete
PUBLIC_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${BACKUP_FILE}"

SUMMARY=$(cat <<EOF
File: ${BACKUP_FILE}
Size: ${FILE_SIZE}
URL: ${PUBLIC_URL}
cURL: curl -O "${PUBLIC_URL}"
EOF
)

log_line "Backup completed and uploaded to ${PUBLIC_URL}"
echo "$SUMMARY"
echo "MongoDB backup completed successfully." >> "$LOG_FILE"
echo "$SUMMARY" >> "$LOG_FILE"
