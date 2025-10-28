#!/bin/bash
set -e

# MongoDB インストール
apt-get update
apt-get install -y mongodb mongodb-clients

# 脆弱性: 認証無効、全IPからアクセス許可
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
sed -i 's/#port = 27017/port = 27017/' /etc/mongodb.conf

systemctl restart mongodb
systemctl enable mongodb

echo "MongoDB installation completed"
