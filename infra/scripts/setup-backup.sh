#!/bin/bash
set -ex  # 詳細ログ出力を有効化

echo "=== Starting Backup Configuration ==="

STORAGE_ACCOUNT="$1"
CONTAINER_NAME="$2"

if [ -z "$STORAGE_ACCOUNT" ] || [ -z "$CONTAINER_NAME" ]; then
  echo "ERROR: Missing parameters. Usage: $0 <storage_account> <container_name>"
  exit 1
fi

echo "=== Installing Azure CLI ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | bash || {
  echo "ERROR: Failed to install Azure CLI"
  exit 1
}

echo "=== Creating Backup Directory ==="
mkdir -p /var/backups/mongodb
mkdir -p /var/log

echo "=== Creating Backup Script ==="
cat > /usr/local/bin/mongodb-backup.sh << 'EOF'
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

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..." | tee -a "$LOG_FILE"

# Managed Identityで再ログイン（セッション切れ対策）
echo "[$(date)] Logging in with Managed Identity..." | tee -a "$LOG_FILE"
az login --identity 2>&1 | tee -a "$LOG_FILE" || {
  echo "[$(date)] WARNING: Managed Identity login failed" | tee -a "$LOG_FILE"
}

# MongoDB認証情報を使ってバックアップ
if ! mongodump \
  --host localhost \
  --port 27017 \
  --username "${MONGO_USER}" \
  --password "${MONGO_PASSWORD}" \
  --authenticationDatabase admin \
  --out ${BACKUP_DIR}/dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"; then
  echo "[$(date)] ERROR: mongodump failed" | tee -a "$LOG_FILE"
  exit 1
fi

cd ${BACKUP_DIR}
tar -czf ${BACKUP_FILE} dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE"
rm -rf dump_${TIMESTAMP}

if ! az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --name ${BACKUP_FILE} \
  --file ${BACKUP_DIR}/${BACKUP_FILE} \
  --auth-mode login 2>&1 | tee -a "$LOG_FILE"; then
  echo "[$(date)] ERROR: Upload failed" | tee -a "$LOG_FILE"
  exit 1
fi

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
  echo "[$(date)] WARNING: SAS generation failed; falling back to public blob URL" | tee -a "$LOG_FILE"
fi

echo "[$(date)] Backup completed and uploaded: ${PUBLIC_URL}" | tee -a "$LOG_FILE"
EOF

echo "=== Configuring Backup Script ==="
# MongoDB認証情報の取得（環境変数から）
MONGO_USER="${MONGO_ADMIN_USER:-mongoadmin}"
MONGO_PASSWORD="${MONGO_ADMIN_PASSWORD}"

if [ -z "$MONGO_PASSWORD" ]; then
  echo "WARNING: MONGO_ADMIN_PASSWORD not set, backup script may fail"
  MONGO_PASSWORD="changeme"
fi

sed -i "s/__STORAGE_ACCOUNT__/${STORAGE_ACCOUNT}/g" /usr/local/bin/mongodb-backup.sh
sed -i "s/__CONTAINER_NAME__/${CONTAINER_NAME}/g" /usr/local/bin/mongodb-backup.sh
sed -i "s/__MONGO_USER__/${MONGO_USER}/g" /usr/local/bin/mongodb-backup.sh
sed -i "s/__MONGO_PASSWORD__/${MONGO_PASSWORD}/g" /usr/local/bin/mongodb-backup.sh
chmod +x /usr/local/bin/mongodb-backup.sh

echo "=== Logging in with Managed Identity ==="
az login --identity || {
  echo "WARNING: Managed Identity login failed, backup uploads may not work"
}

echo "=== Setting up Cron Job ==="
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongodb-backup.sh") | crontab -

echo "=== Running Initial Backup ==="
/usr/local/bin/mongodb-backup.sh || echo "WARNING: Initial backup failed, will retry via cron"

echo "=== Backup Configuration Completed Successfully ==="
