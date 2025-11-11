#!/bin/bash
set -ex  # 詳細ログ出力を有効化

echo "=== Starting MongoDB Installation ==="

# apt リストのクリーンアップと再初期化
rm -rf /var/lib/apt/lists/*
apt-get clean
apt-get update

# 必要なパッケージをインストール
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  gnupg \
  curl \
  ca-certificates

# MongoDB 公式リポジトリの GPG キーを追加 (apt-key 非推奨のため keyring へ保存)
mkdir -p /usr/share/keyrings
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-org-4.4.gpg

# MongoDB リポジトリを追加 (MongoDB 4.4 - 2020年リリース、要件を満たす古いバージョン)
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-org-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# パッケージリストを更新
apt-get update

# MongoDB をインストール (4.4 系をバージョン固定で取得)
MONGO_VERSION="4.4.29"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  mongodb-org=${MONGO_VERSION} \
  mongodb-org-server=${MONGO_VERSION} \
  mongodb-org-shell=${MONGO_VERSION} \
  mongodb-org-mongos=${MONGO_VERSION} \
  mongodb-org-tools=${MONGO_VERSION} || {
  echo "ERROR: Failed to install mongodb-org package"
  exit 1
}

echo "=== MongoDB Installed ==="

# MongoDB の設定ファイルパスを確認
if [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
elif [ -f /etc/mongodb.conf ]; then
  MONGO_CONF="/etc/mongodb.conf"
elif [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
else
  echo "ERROR: MongoDB config file not found"
  exit 1
fi

echo "=== Configuring MongoDB (Config: $MONGO_CONF) ==="

# 脆弱性: 認証無効、全IPからアクセス許可
# MongoDB 4.4 は YAML 形式の設定ファイルを使用
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' "$MONGO_CONF" || \
  sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' "$MONGO_CONF" || \
  echo "bind_ip setting not found, manually configuring..."

# YAML 形式で bindIp が見つからない場合、追加
if ! grep -q "bindIp:" "$MONGO_CONF"; then
  cat >> "$MONGO_CONF" << 'EOF'

# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
EOF
fi

# MongoDB サービスを再起動
if systemctl list-unit-files | grep -q mongod.service; then
  SERVICE_NAME="mongod"
elif systemctl list-unit-files | grep -q mongodb.service; then
  SERVICE_NAME="mongodb"
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

echo "=== Capturing MongoDB Version Evidence ==="

VERSION_LOG="/var/log/mongodb-version.log"
mkdir -p "$(dirname "$VERSION_LOG")"

{
  echo "[$(date -Is)] mongo --version"
  mongo --version
  echo "[$(date -Is)] mongod --version"
  mongod --version
} | tee "$VERSION_LOG"

echo "=== MongoDB Installation Completed Successfully ==="
