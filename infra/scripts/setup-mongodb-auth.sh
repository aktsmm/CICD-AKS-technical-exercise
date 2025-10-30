#!/bin/bash
set -e

echo "=== Setting up MongoDB Authentication ===" | tee -a /var/log/mongodb-auth-setup.log

MONGO_ADMIN_USER="${MONGO_ADMIN_USER:-mongoadmin}"
MONGO_ADMIN_PASSWORD="${MONGO_ADMIN_PASSWORD}"

if [ -z "$MONGO_ADMIN_PASSWORD" ]; then
  echo "ERROR: MONGO_ADMIN_PASSWORD environment variable is required" | tee -a /var/log/mongodb-auth-setup.log
  exit 1
fi

if systemctl list-unit-files | grep -q mongod.service; then
  SERVICE_NAME="mongod"
elif systemctl list-unit-files | grep -q mongodb.service; then
  SERVICE_NAME="mongodb"
else
  echo "ERROR: MongoDB service not found" | tee -a /var/log/mongodb-auth-setup.log
  exit 1
fi

if [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
elif [ -f /etc/mongodb.conf ]; then
  MONGO_CONF="/etc/mongodb.conf"
else
  echo "ERROR: MongoDB config file not found" | tee -a /var/log/mongodb-auth-setup.log
  exit 1
fi

echo "Using MongoDB service: $SERVICE_NAME" | tee -a /var/log/mongodb-auth-setup.log
echo "Using config file: $MONGO_CONF" | tee -a /var/log/mongodb-auth-setup.log

# 起動待機
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if mongo admin --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "✅ MongoDB is ready!" | tee -a /var/log/mongodb-auth-setup.log
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for MongoDB... ($RETRY_COUNT/$MAX_RETRIES)" | tee -a /var/log/mongodb-auth-setup.log
  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "❌ ERROR: MongoDB did not start within expected time" | tee -a /var/log/mongodb-auth-setup.log
  exit 1
fi

# 認証が未設定なら設定
if ! grep -q "^[[:space:]]*authorization:[[:space:]]*enabled" "$MONGO_CONF"; then
  echo "=== Creating MongoDB Admin User ===" | tee -a /var/log/mongodb-auth-setup.log
  mongo admin --eval "
    db.createUser({
      user: '${MONGO_ADMIN_USER}',
      pwd: '${MONGO_ADMIN_PASSWORD}',
      roles: [
        { role: 'root', db: 'admin' },
        { role: 'userAdminAnyDatabase', db: 'admin' },
        { role: 'dbAdminAnyDatabase', db: 'admin' },
        { role: 'readWriteAnyDatabase', db: 'admin' }
      ]
    })
  " || echo "WARNING: User might already exist, continuing..."

  echo "=== Enabling MongoDB Authentication ===" | tee -a /var/log/mongodb-auth-setup.log
  if grep -q "^security:" "$MONGO_CONF"; then
    sed -i '/^security:/a\  authorization: enabled' "$MONGO_CONF"
  elif grep -q "^#security:" "$MONGO_CONF"; then
    sed -i 's/^#security:/security:/' "$MONGO_CONF"
    sed -i '/^security:/a\  authorization: enabled' "$MONGO_CONF"
  else
    cat >> "$MONGO_CONF" << 'EOF'

# Security Settings
security:
  authorization: enabled
EOF
  fi

  echo "=== Restarting MongoDB with Authentication ===" | tee -a /var/log/mongodb-auth-setup.log
  sudo systemctl restart $SERVICE_NAME

  # 再起動待機
  for i in {1..30}; do
    if mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
      echo "✅ MongoDB is ready after restart!" | tee -a /var/log/mongodb-auth-setup.log
      break
    fi
    sleep 2
  done

  echo "=== Testing MongoDB Authentication ===" | tee -a /var/log/mongodb-auth-setup.log
  sleep 3
  if ! mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })"; then
    echo "❌ ERROR: MongoDB authentication test failed" | tee -a /var/log/mongodb-auth-setup.log
    exit 1
  fi
  echo "✅ MongoDB Authentication is working!" | tee -a /var/log/mongodb-auth-setup.log
else
  echo "⚠️ MongoDB authentication is already enabled" | tee -a /var/log/mongodb-auth-setup.log
fi

unset MONGO_ADMIN_PASSWORD
echo "=== MongoDB Authentication Setup Completed ===" | tee -a /var/log/mongodb-auth-setup.log
