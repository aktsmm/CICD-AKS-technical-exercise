# Phase 09: MongoDB パッケージインストール失敗

**作成日**: 2025-10-29  
**ステータス**: ✅ 解決済み  
**カテゴリ**: VM 拡張機能・パッケージ管理

---

## 🔴 問題

### エラー内容

```
VM has reported a failure when processing extension 'install-mongodb'
(publisher 'Microsoft.Azure.Extensions' and type 'CustomScript').
Error message: 'Enable failed: failed to execute command: command terminated with exit status=1

[stdout]
Reading package lists...
Building dependency tree...
Reading state information...
ERROR: Failed to install mongodb package

[stderr]
E: Unable to locate package mongodb
```

### Infrastructure デプロイの失敗

```
Error: ERROR: "status":"Failed","error":"code":"DeploymentFailed"
ResourceDeploymentFailure:
/Microsoft.Compute/virtualMachines/<MONGODB_VM_NAME>/extensions/install-mongodb
```

---

## 🔍 原因分析

### 根本原因

**Ubuntu 20.04 に `mongodb` パッケージが存在しない**

#### Ubuntu リポジトリの変更履歴

| Ubuntu バージョン | MongoDB パッケージ | 状態            |
| ----------------- | ------------------ | --------------- |
| Ubuntu 18.04 LTS  | `mongodb` 3.6.x    | ✅ 利用可能     |
| Ubuntu 20.04 LTS  | `mongodb`          | ❌ **削除済み** |
| Ubuntu 22.04 LTS  | `mongodb`          | ❌ 削除済み     |

#### 公式アナウンス

Ubuntu 20.04 (Focal Fossa) 以降、MongoDB パッケージは公式リポジトリから削除されました。

**理由:**

- MongoDB のライセンス変更 (AGPL → SSPL)
- ライセンス互換性の問題
- MongoDB 公式リポジトリの使用を推奨

### 元のスクリプトの問題

**`infra/scripts/install-mongodb.sh` (修正前)**

```bash
# MongoDB インストール (Ubuntu リポジトリから)
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb || {
  echo "ERROR: Failed to install mongodb package"
  exit 1
}
```

**実行結果:**

```
E: Unable to locate package mongodb
ERROR: Failed to install mongodb package
exit status=1
```

---

## ✅ 解決策

### 実装: MongoDB 公式リポジトリからのインストール

**`infra/scripts/install-mongodb.sh` (修正後)**

```bash
#!/bin/bash
set -ex

echo "=== Starting MongoDB Installation ==="

# apt リストのクリーンアップ
rm -rf /var/lib/apt/lists/*
apt-get clean
apt-get update

# 必要なパッケージをインストール
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  gnupg \
  curl \
  ca-certificates

# MongoDB 公式リポジトリの GPG キーを追加
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -

# MongoDB リポジトリを追加 (MongoDB 4.4 - 2020年リリース)
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# パッケージリストを更新
apt-get update

# MongoDB をインストール
DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org=4.4.* || {
  echo "ERROR: Failed to install mongodb-org package"
  exit 1
}

echo "=== MongoDB Installed ==="

# MongoDB の設定ファイルパスを確認
if [ -f /etc/mongod.conf ]; then
  MONGO_CONF="/etc/mongod.conf"
elif [ -f /etc/mongodb.conf ]; then
  MONGO_CONF="/etc/mongodb.conf"
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

echo "=== MongoDB Installation Completed Successfully ==="
```

---

## 📊 変更点の詳細

### 1. パッケージ名の変更

| 項目             | 修正前                         | 修正後                         |
| ---------------- | ------------------------------ | ------------------------------ |
| **パッケージ名** | `mongodb`                      | `mongodb-org`                  |
| **リポジトリ**   | Ubuntu 公式                    | MongoDB 公式                   |
| **バージョン**   | 3.6.x (存在しない)             | 4.4.x                          |
| **設定ファイル** | `/etc/mongodb.conf` (ini 形式) | `/etc/mongod.conf` (YAML 形式) |
| **サービス名**   | `mongodb`                      | `mongod`                       |

### 2. 設定ファイル形式の対応

**MongoDB 3.6 (ini 形式)**

```ini
# /etc/mongodb.conf
bind_ip = 127.0.0.1
port = 27017
```

**MongoDB 4.4 (YAML 形式)**

```yaml
# /etc/mongod.conf
net:
  port: 27017
  bindIp: 127.0.0.1
```

### 3. MongoDB バージョンの選択

| バージョン      | リリース日       | Ubuntu 20.04 対応            | 要件適合 (1 年以上古い) |
| --------------- | ---------------- | ---------------------------- | ----------------------- |
| MongoDB 3.6     | 2017 年 11 月    | ❌ Ubuntu リポジトリから削除 | ✅ 8 年前               |
| **MongoDB 4.4** | **2020 年 7 月** | **✅ 公式リポジトリ対応**    | **✅ 5 年前**           |
| MongoDB 5.0     | 2021 年 7 月     | ✅ 対応                      | ✅ 4 年前               |
| MongoDB 6.0     | 2022 年 7 月     | ✅ 対応                      | ✅ 3 年前               |
| MongoDB 7.0     | 2023 年 8 月     | ✅ 対応                      | ✅ 2 年前               |

**選択: MongoDB 4.4**

- ✅ Ubuntu 20.04 対応
- ✅ 2020 年リリース（5 年前）で要件を満たす
- ✅ Long Term Support (LTS) バージョン
- ✅ 安定版として広く使用されている

---

## 🔄 修正後の動作フロー

### Infrastructure デプロイ時

```
1. VM 作成 (Ubuntu 20.04 LTS)
2. Custom Script Extension 実行
   ├─ apt-get update
   ├─ gnupg, curl, ca-certificates インストール
   ├─ MongoDB GPG キーを追加
   ├─ MongoDB 公式リポジトリを追加
   ├─ apt-get update (新しいリポジトリ反映)
   ├─ mongodb-org=4.4.* インストール ✅
   ├─ /etc/mongod.conf を編集 (bindIp: 0.0.0.0)
   ├─ systemctl restart mongod
   └─ systemctl enable mongod
3. MongoDB サービス起動成功 ✅
```

### ログ出力例

```bash
=== Starting MongoDB Installation ===
Get:1 https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 InRelease [4,644 B]
Get:2 https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4/multiverse amd64 Packages [19.3 kB]
Reading package lists... Done
Building dependency tree... Done
The following NEW packages will be installed:
  mongodb-org mongodb-org-database mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools
0 upgraded, 6 newly installed, 0 to remove and 0 not upgraded.
Need to get 95.4 MB of archives.
After this operation, 295 MB of additional disk space will be used.
=== MongoDB Installed ===
=== Configuring MongoDB (Config: /etc/mongod.conf) ===
=== Starting MongoDB Service: mongod ===
● mongod.service - MongoDB Database Server
     Loaded: loaded (/lib/systemd/system/mongod.service; enabled)
     Active: active (running)
=== MongoDB Installation Completed Successfully ===
```

---

## 💡 ベストプラクティス

### 1. パッケージの利用可能性確認

**デプロイ前のテスト:**

```bash
# Docker コンテナで事前確認
docker run -it ubuntu:20.04 bash
apt-get update
apt-cache policy mongodb        # パッケージの存在確認
apt-cache policy mongodb-org    # 代替パッケージの確認
```

### 2. 公式リポジトリの使用

**MongoDB 公式ドキュメント:**
https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/

**メリット:**

- 最新のセキュリティパッチ
- 公式サポート
- バージョン管理の柔軟性

### 3. 設定ファイル形式の確認

```bash
# インストール後に設定ファイルの形式を確認
cat /etc/mongod.conf | head -5

# YAML形式の場合
net:
  port: 27017
  bindIp: 127.0.0.1

# ini形式の場合
bind_ip = 127.0.0.1
port = 27017
```

### 4. サービス名の動的検出

```bash
# サービス名を自動検出
if systemctl list-unit-files | grep -q mongod.service; then
  SERVICE_NAME="mongod"
elif systemctl list-unit-files | grep -q mongodb.service; then
  SERVICE_NAME="mongodb"
fi
```

---

## 🚨 注意事項

### MongoDB のライセンス

**MongoDB 3.6 以前:**

- ライセンス: AGPL v3.0
- Ubuntu リポジトリに含まれていた

**MongoDB 4.0 以降:**

- ライセンス: Server Side Public License (SSPL)
- Ubuntu リポジトリから削除された理由

**SSPL の特徴:**

- オープンソースだが、AGPL より制限が厳しい
- クラウドサービスとして提供する場合、ソースコード公開義務
- 商用利用時は注意が必要

### セキュリティ考慮事項

**今回の設定 (意図的な脆弱性):**

```yaml
net:
  bindIp: 0.0.0.0 # すべての IP からアクセス可能
```

**本番環境での推奨設定:**

```yaml
net:
  bindIp: 127.0.0.1 # ローカルホストのみ
  # または VNet 内の IP のみ

security:
  authorization: enabled # 認証必須化
```

---

## 🔗 関連する問題

### Phase 01 との関係

**Phase 01: 環境準備とインフラ作成**

- Ubuntu 18.04 を使用 → MongoDB パッケージが存在
- Ubuntu 20.04 に変更 → このエラーが発生

**教訓:**

- OS バージョン変更時はパッケージの利用可能性を確認
- 公式リポジトリの使用でバージョン依存を回避

---

## 📚 参考資料

- [MongoDB 公式インストールガイド (Ubuntu)](https://www.mongodb.com/docs/v4.4/tutorial/install-mongodb-on-ubuntu/)
- [Ubuntu パッケージ検索](https://packages.ubuntu.com/)
- [MongoDB ライセンス変更 (SSPL)](https://www.mongodb.com/licensing/server-side-public-license)
- [Azure VM Custom Script Extension](https://learn.microsoft.com/ja-jp/azure/virtual-machines/extensions/custom-script-linux)

---

## 🔄 変更履歴

| 日時       | 変更内容                                           |
| ---------- | -------------------------------------------------- |
| 2025-10-29 | 問題発見: E: Unable to locate package mongodb      |
| 2025-10-29 | 原因特定: Ubuntu 20.04 でパッケージ削除済み        |
| 2025-10-29 | 解決: MongoDB 4.4 を公式リポジトリからインストール |
| 2025-10-29 | 設定対応: YAML 形式の設定ファイルに変更            |
