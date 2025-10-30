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

# MongoDB が起動するまで待機
echo "=== Waiting for MongoDB to be ready ==="
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  # MongoDB起動確認
  if mongo admin --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "✅ MongoDB is ready!"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for MongoDB... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "❌ ERROR: MongoDB did not start within expected time"
  exit 1
fi

# 認証がまだ有効でない場合のみ設定（コメントアウトされた行は除外）
if ! grep -q "^[[:space:]]*authorization:[[:space:]]*enabled" "$MONGO_CONF"; then
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
  
  # MongoDB再起動後の待機
  echo "=== Waiting for MongoDB to restart ==="
  MAX_RETRIES=30
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
      echo "✅ MongoDB is ready after restart!"
      break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for MongoDB restart... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
  done

  # 認証のテスト
  echo "=== Testing MongoDB Authentication ==="
  # 最終認証テスト
  sleep 3
  if ! mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })"; then
    echo "❌ ERROR: MongoDB authentication test failed"
    exit 1
  fi
  echo "✅ MongoDB Authentication is working!"else
  echo "⚠️ MongoDB authentication is already enabled"
  
  # 認証が有効でもユーザーが存在しない可能性があるのでテスト
  echo "=== Testing if admin user exists ==="
  if ! mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })" 2>/dev/null; then
    echo "⚠️ Admin user does not exist, recreating..."
    
    # 一時的に認証を無効化
    sudo sed -i 's/^[[:space:]]*authorization:[[:space:]]*enabled/#authorization: enabled/' "$MONGO_CONF"
    sudo systemctl restart $SERVICE_NAME
    
    # MongoDB再起動待機
    echo "=== Waiting for MongoDB to restart (auth disabled) ==="
    MAX_RETRIES=30
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "✅ MongoDB is ready!"
        break
      fi
      RETRY_COUNT=$((RETRY_COUNT + 1))
      echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
      sleep 2
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
      echo "❌ ERROR: MongoDB failed to start within 60 seconds"
      exit 1
    fi
    
    # ユーザー作成
    if ! mongo admin --eval "
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
    "; then
      echo "❌ ERROR: User creation failed"
      exit 1
    fi
    echo "✅ User created successfully"
    
    # 認証を再度有効化
    sudo sed -i 's/#authorization: enabled/  authorization: enabled/' "$MONGO_CONF"
    sudo systemctl restart $SERVICE_NAME
    
    # MongoDB再起動待機（認証有効化後）
    echo "=== Waiting for MongoDB to restart (auth enabled) ==="
    MAX_RETRIES=30
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "✅ MongoDB is ready!"
        break
      fi
      RETRY_COUNT=$((RETRY_COUNT + 1))
      echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
      sleep 2
    done
    sleep 5
    
    # 再テスト
    if ! mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })"; then
      echo "❌ ERROR: MongoDB authentication test failed after user creation"
      exit 1
    fi
    echo "✅ MongoDB Authentication is now working!"
  else
    echo "✅ Admin user already exists and is working"
  fi
fi

echo "=== MongoDB Authentication Setup Completed ==="
