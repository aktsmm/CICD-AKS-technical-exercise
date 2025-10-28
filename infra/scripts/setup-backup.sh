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
set -e
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/mongodb"
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.tar.gz"
STORAGE_ACCOUNT="__STORAGE_ACCOUNT__"
CONTAINER_NAME="__CONTAINER_NAME__"
LOG_FILE="/var/log/mongodb-backup.log"

echo "[$(date)] Starting backup..." | tee -a "$LOG_FILE"

mongodump --out ${BACKUP_DIR}/dump_${TIMESTAMP} 2>&1 | tee -a "$LOG_FILE" || {
  echo "[$(date)] ERROR: mongodump failed" | tee -a "$LOG_FILE"
  exit 0
}

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
echo "[$(date)] Backup completed: ${BACKUP_FILE}" | tee -a "$LOG_FILE"
EOF

echo "=== Configuring Backup Script ==="
sed -i "s/__STORAGE_ACCOUNT__/${STORAGE_ACCOUNT}/g" /usr/local/bin/mongodb-backup.sh
sed -i "s/__CONTAINER_NAME__/${CONTAINER_NAME}/g" /usr/local/bin/mongodb-backup.sh
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
