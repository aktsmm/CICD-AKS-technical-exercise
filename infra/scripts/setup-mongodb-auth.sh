#!/bin/bash
set -e

echo "=== Setting up MongoDB Authentication ==="

# パラメータから認証情報を取得
MONGO_ADMIN_USER="${MONGO_ADMIN_USER:-mongoadmin}"
MONGO_ADMIN_PASSWORD="${MONGO_ADMIN_PASSWORD}"

if [ -z "$MONGO_ADMIN_PASSWORD" ]; then
  echo "ERROR: MONGO_ADMIN_PASSWORD environment variable is required"
  exit 1
fi

# MongoDB サービス名を検出
if systemctl list-unit-files | grep -q mongod.service; then
  SERVICE_NAME="mongod"
elif systemctl list-unit-files | grep -q mongodb.service; then
  SERVICE_NAME="mongodb"
else
  echo "ERROR: MongoDB service not found"
  exit 1
fi

# MongoDB 設定ファイルを検出
if [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
elif [ -f /etc/mongodb.conf ]; then
  MONGO_CONF="/etc/mongodb.conf"
else
  echo "ERROR: MongoDB config file not found"
  exit 1
fi

echo "Using MongoDB service: $SERVICE_NAME"
echo "Using config file: $MONGO_CONF"

# 認証がまだ有効でない場合のみ設定
if ! grep -q "authorization: enabled" "$MONGO_CONF"; then
  echo "=== Creating MongoDB Admin User ==="
  
  # 管理者ユーザーを作成（認証無効の状態で）
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
  " || {
    echo "WARNING: User might already exist, continuing..."
  }

  echo "=== Enabling MongoDB Authentication ==="
  
  # security セクションが存在するか確認
  if grep -q "^security:" "$MONGO_CONF"; then
    # 既存の security セクションに authorization を追加
    sed -i '/^security:/a\  authorization: enabled' "$MONGO_CONF"
  elif grep -q "^#security:" "$MONGO_CONF"; then
    # コメントアウトされている場合は有効化
    sed -i 's/^#security:/security:\n  authorization: enabled/' "$MONGO_CONF"
  else
    # security セクションが存在しない場合は追加
    cat >> "$MONGO_CONF" << 'EOF'

# Security Settings
security:
  authorization: enabled
EOF
  fi

  echo "=== Restarting MongoDB with Authentication ==="
  systemctl restart $SERVICE_NAME
  sleep 5

  # 認証のテスト
  echo "=== Testing MongoDB Authentication ==="
  mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })" && \
    echo "✅ MongoDB Authentication is working!" || \
    echo "❌ Authentication test failed"

else
  echo "✅ MongoDB authentication is already enabled"
fi

echo "=== MongoDB Authentication Setup Completed ==="
