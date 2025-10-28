#!/bin/bash
set -ex  # 詳細ログ出力を有効化

echo "=== Starting MongoDB Installation ==="

# MongoDB インストール (Ubuntu リポジトリから)
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb || {
  echo "ERROR: Failed to install mongodb package"
  exit 1
}

echo "=== MongoDB Installed ==="

# MongoDB の設定ファイルパスを確認
if [ -f /etc/mongodb.conf ]; then
  MONGO_CONF="/etc/mongodb.conf"
elif [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
else
  echo "ERROR: MongoDB config file not found"
  exit 1
fi

echo "=== Configuring MongoDB (Config: $MONGO_CONF) ==="

# 脆弱性: 認証無効、全IPからアクセス許可
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' "$MONGO_CONF" || echo "bind_ip setting not found, skipping"
sed -i 's/#port = 27017/port = 27017/' "$MONGO_CONF" || echo "port setting not found, skipping"

# MongoDB サービスを再起動
if systemctl list-unit-files | grep -q mongodb.service; then
  SERVICE_NAME="mongodb"
elif systemctl list-unit-files | grep -q mongod.service; then
  SERVICE_NAME="mongod"
else
  echo "ERROR: MongoDB service not found"
  exit 1
fi

echo "=== Starting MongoDB Service: $SERVICE_NAME ==="

systemctl restart $SERVICE_NAME || {
  echo "ERROR: Failed to restart MongoDB"
  systemctl status $SERVICE_NAME --no-pager || true
  exit 1
}

systemctl enable $SERVICE_NAME

echo "=== MongoDB Installation Completed Successfully ==="
