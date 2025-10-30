# Phase 20: MongoDB 認証スクリプト修正

**日時**: 2025 年 10 月 31 日  
**対象環境**:

- rg-bbs-cicd-aks1111 (1 回目デプロイ)
- rg-bbs-cicd-aks001 (2 回目デプロイ - VM 削除)
- 次回デプロイで完全修正予定

**関連コミット**:

- `7d48fdd` - Bicep リポジトリ URL 修正
- `f0aeeb4` - forceUpdateTag 追加
- `8e8afc0` - setup-mongodb-auth.sh 修正（grep pattern 改善）
- `f2aa642` - setup-mongodb-auth.sh 修正（YAML インデント保持）
- `4846a85` - Bicep に sleep 10 追加（暫定対応）
- `4be92de` - MongoDB readiness check 実装（恒久対応）

---

## 問題の概要

### 症状

- アプリケーションが HTTP 500 エラーを返す
- アプリログに `MongoServerError: Authentication failed` が記録
- MongoDB ユーザー `mongoadmin` が作成されていない

### 影響範囲

- すべてのデプロイメントで MongoDB 認証が失敗
- Wiz Technical Exercise の要件「データが MongoDB に保存されていることを証明する」が満たせない

---

## 根本原因分析

### 調査プロセス

#### 1. アプリケーション側の確認

```bash
kubectl logs -l app=guestbook --tail=50
```

**結果**:

```
❌ MongoDB接続失敗: MongoServerError: Authentication failed.
  code: 18,
  codeName: 'AuthenticationFailed'
```

#### 2. MongoDB サービスの確認

```bash
az vm run-command invoke -g rg-bbs-cicd-aks1111 -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "systemctl status mongod --no-pager | head -20"
```

**結果**: MongoDB サービスは正常に動作中

#### 3. MongoDB 認証テスト

```bash
az vm run-command invoke -g rg-bbs-cicd-aks1111 -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "mongo admin -u mongoadmin -p dhs7XVDulERmTGwL --eval 'db.getUsers()' --quiet"
```

**結果**: `Error: Authentication failed.` - ユーザーが存在しない

#### 4. VM 拡張ログの確認

```bash
az vm run-command invoke -g rg-bbs-cicd-aks1111 -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "cat /var/lib/waagent/custom-script/download/0/stdout | grep -A 20 'MongoDB Installation Completed'"
```

**重要な発見**:

```
=== MongoDB Installation Completed Successfully ===
=== Setting up MongoDB Authentication ===
Using MongoDB service: mongod
Using config file: /etc/mongod.conf
=== Creating MongoDB Admin User ===
MongoDB shell version v4.4.29
connecting to: mongodb://127.0.0.1:27017/admin?compressors=disabled&gssapiServiceName=mongodb
Error: couldn't connect to server 127.0.0.1:27017, connection attempt failed: SocketException: Error connecting to 127.0.0.1:27017 :: caused by :: Connection refused
```

**setup-mongodb-auth.sh は実行されているが、接続に失敗している**

#### 5. MongoDB 設定ファイルの確認

```bash
az vm run-command invoke -g rg-bbs-cicd-aks1111 -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "cat /etc/mongod.conf | grep -A 3 security"
```

**結果**:

```yaml
security:
  #authorization: enabled
```

**重大な発見**: `authorization` がコメントアウトされている！

---

## 根本原因

### 問題 1: Bicep ファイルの誤ったリポジトリ URL

**ファイル**: `infra/modules/vm-mongodb.bicep` (Line 157-159)

**問題のコード**:

```bicep
fileUris: [
  'https://raw.githubusercontent.com/aktsmm/wiz-technical-exercise/main/infra/scripts/install-mongodb.sh'
  'https://raw.githubusercontent.com/aktsmm/wiz-technical-exercise/main/infra/scripts/setup-mongodb-auth.sh'
  'https://raw.githubusercontent.com/aktsmm/wiz-technical-exercise/main/infra/scripts/setup-backup.sh'
]
```

**問題点**:

- リポジトリ名が `wiz-technical-exercise` (存在しない)
- 正しくは `CICD-AKS-technical-exercise`
- スクリプトのダウンロードは成功していたが、古いバージョンの可能性

**修正** (コミット `7d48fdd`):

```bicep
fileUris: [
  'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/install-mongodb.sh'
  'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-mongodb-auth.sh'
  'https://raw.githubusercontent.com/aktsmm/CICD-AKS-technical-exercise/main/infra/scripts/setup-backup.sh'
]
```

### 問題 2: VM 拡張が再実行されない

**問題点**:

- Bicep を修正してデプロイしても、VM 拡張は「既に成功している」ため再実行されない
- Azure は VM 拡張の冪等性を保つため、同じ設定では再実行しない

**修正** (コミット `f0aeeb4`):

**ファイル**: `infra/modules/vm-mongodb.bicep`

```bicep
// パラメータ追加 (Line 28)
@description('VM拡張の強制更新タグ')
param forceUpdateTag string = utcNow()

// VM 拡張に適用 (Line 155)
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vm
  name: 'install-mongodb'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: forceUpdateTag  // 毎回拡張を再実行
    settings: {
      fileUris: [...]
    }
  }
}
```

**効果**:

- `utcNow()` が毎デプロイで一意のタイムスタンプを生成
- `forceUpdateTag` が変わると VM 拡張が強制的に再実行される

### 問題 3: setup-mongodb-auth.sh のロジック不具合

**ファイル**: `infra/scripts/setup-mongodb-auth.sh`

**問題のコード** (Line 39):

```bash
if ! grep -q "authorization: enabled" "$MONGO_CONF"; then
  echo "=== Creating MongoDB Admin User ==="
  # ユーザー作成処理...
else
  echo "✅ MongoDB authentication is already enabled"
fi
```

**問題点**:

1. **コメント行にマッチ**: `grep -q "authorization: enabled"` は `#authorization: enabled` にもマッチする
2. **誤判定**: コメントアウトされていても「既に有効」と判定し、ユーザー作成をスキップ
3. **フォールバック不足**: 認証が有効でもユーザーが存在しない場合の処理がない

**デフォルト設定の問題**:
MongoDB 4.4 のデフォルト `/etc/mongod.conf` には以下が含まれる:

```yaml
security:
  #authorization: enabled
```

これは「認証機能の例」としてコメントで記載されているだけで、実際には無効。

**修正** (コミット `8e8afc0`):

```bash
# 修正1: 正規表現でコメント行を除外 (Line 39)
if ! grep -q "^[[:space:]]*authorization:[[:space:]]*enabled" "$MONGO_CONF"; then
  echo "=== Creating MongoDB Admin User ==="
  # ユーザー作成処理...
else
  echo "⚠️ MongoDB authentication is already enabled"

  # 修正2: フォールバック処理を追加 (Line 88-121)
  echo "=== Testing if admin user exists ==="
  if ! mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })" 2>/dev/null; then
    echo "⚠️ Admin user does not exist, recreating..."

    # 一時的に認証を無効化
    sudo sed -i 's/^[[:space:]]*authorization:[[:space:]]*enabled/#authorization: enabled/' "$MONGO_CONF"
    sudo systemctl restart $SERVICE_NAME
    sleep 5

    # ユーザー作成
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
    " || echo "WARNING: User creation failed"

    # 認証を再度有効化
    sudo sed -i 's/#authorization: enabled/authorization: enabled/' "$MONGO_CONF"
    sudo systemctl restart $SERVICE_NAME
    sleep 5

    # 再テスト
    mongo admin -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASSWORD}" --eval "db.adminCommand({ listDatabases: 1 })" && \
      echo "✅ MongoDB Authentication is now working!" || \
      echo "❌ Authentication test still failed"
  else
    echo "✅ Admin user already exists and is working"
  fi
fi
```

**改善点**:

1. **正規表現の厳密化**: `^[[:space:]]*authorization:[[:space:]]*enabled`
   - `^` で行頭から開始（`#` で始まる行は除外）
   - `[[:space:]]*` で空白を許容
2. **フォールバック処理**: 認証有効でもユーザーが存在しない場合
   - 一時的に認証を無効化
   - ユーザーを作成
   - 認証を再有効化
3. **ログの改善**: 各ステップで詳細なログを出力

### 問題 4: YAML インデント保持の不具合（2 回目デプロイで発見）

**環境**: rg-bbs-cicd-aks001

**症状**:

```
mongod[18204]: Unrecognized option: security
mongod.service: Failed with result 'exit-code'
```

**MongoDB 設定ファイルの問題**:

```yaml
security:
authorization: enabled # ← インデントなし！YAMLの構文エラー
```

**原因分析**:

setup-mongodb-auth.sh の 114 行目（フォールバック処理内）:

```bash
# 問題のコード
sudo sed -i 's/#authorization: enabled/authorization: enabled/' "$MONGO_CONF"
```

この sed コマンドは `#authorization: enabled` を `authorization: enabled` に置換するが、**インデントを追加しない**。

YAML では**インデントが構文の一部**であり、以下のように 2 スペースのインデントが必須:

```yaml
security:
  authorization: enabled # 正しい
```

インデントなしだと:

```yaml
security:
authorization: enabled # MongoDB起動失敗
```

**修正** (コミット `f2aa642`):

```bash
# 修正前（インデントが失われる）
sudo sed -i 's/#authorization: enabled/authorization: enabled/' "$MONGO_CONF"

# 修正後（2スペースのインデントを保持）
sudo sed -i 's/#authorization: enabled/  authorization: enabled/' "$MONGO_CONF"
```

**影響**:

- 1 回目のデプロイ (rg-bbs-cicd-aks1111): grep pattern の問題で実行されず
- 2 回目のデプロイ (rg-bbs-cicd-aks001): フォールバック処理が実行されたが、インデントエラーで MongoDB 起動失敗
- 3 回目のデプロイ: 両方の修正が反映され、正常動作予定

### 問題 5: MongoDB 起動待機時間の不足（3 回目デプロイで発見）

**環境**: rg-bbs-cicd-aks-001

**症状**:

```
Error: couldn't connect to server 127.0.0.1:27017, connection attempt failed: SocketException: Error connecting to 127.0.0.1:27017 :: caused by :: Connection refused
WARNING: User might already exist, continuing...
```

**VM 拡張ログ**:

```
=== MongoDB Installation Completed Successfully ===
=== Setting up MongoDB Authentication ===
=== Creating MongoDB Admin User ===
Error: couldn't connect to server 127.0.0.1:27017
```

**原因分析**:

Bicep の`commandToExecute`（修正前）:

```bash
bash install-mongodb.sh && MONGO_ADMIN_PASSWORD="..." bash setup-mongodb-auth.sh
```

**問題点**:

1. install-mongodb.sh が MongoDB を起動（`systemctl restart mongod`）
2. **起動には数秒かかるが、即座に次のスクリプトへ**
3. setup-mongodb-auth.sh が MongoDB 接続を試行
4. まだ起動していないため `Connection refused`

**タイミング図**:

```
Time: 0s         2s         4s         6s
      |          |          |          |
install-mongodb.sh ━━━━━┓
                         ┗━> systemctl restart mongod
                                      ┗━━━> MongoDB起動中...
setup-mongodb-auth.sh ━━━━━━━━> mongo admin (接続失敗！)
                                              ↑
                                        まだ起動していない
```

**暫定対応** (コミット `4846a85`):

Bicep に固定 sleep を追加:

```bash
bash install-mongodb.sh && sleep 10 && MONGO_ADMIN_PASSWORD="..." bash setup-mongodb-auth.sh
```

**問題点**:

- 固定 10 秒は環境によっては不足または過剰
- スクリプト側で制御すべき

**恒久対応** (コミット `4be92de`):

setup-mongodb-auth.sh にポーリングループを追加:

```bash
# MongoDB が起動するまで待機
echo "=== Waiting for MongoDB to be ready ==="
MAX_RETRIES=30  # 最大60秒待機（2秒 × 30回）
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if mongo --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
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
```

**適用箇所**（3 箇所に追加）:

1. 初回起動後（install-mongodb.sh 実行後）
2. 認証有効化後の再起動（76 行目付近）
3. フォールバック処理での再起動 2 回（130 行目、165 行目付近）

**利点**:

- ✅ **インテリジェント待機**: 起動完了次第すぐ進む（最大 60 秒まで待機）
- ✅ **確実性向上**: `db.adminCommand('ping')` で実際の接続確認
- ✅ **タイムアウト処理**: 60 秒経過してもダメならエラー終了
- ✅ **ログ出力**: 進捗状況が可視化される

**Bicep 側の変更**:

固定 sleep を削除（スクリプト内で制御するため）:

```bash
# 修正後
bash install-mongodb.sh && MONGO_ADMIN_PASSWORD="..." bash setup-mongodb-auth.sh
```

**影響**:

- 1 回目のデプロイ (rg-bbs-cicd-aks1111): grep pattern の問題で実行されず
- 2 回目のデプロイ (rg-bbs-cicd-aks001): フォールバック処理が実行されたが、インデントエラーで MongoDB 起動失敗
- 3 回目のデプロイ: 両方の修正が反映され、正常動作予定

---

## 解決策の実装

### 修正の流れ

```
1. Bicep リポジトリ URL 修正 (7d48fdd)
   ↓
2. forceUpdateTag 追加 (f0aeeb4)
   ↓
3. setup-mongodb-auth.sh 修正 - grep pattern (8e8afc0)
   ↓
4. 1回目デプロイ (rg-bbs-cicd-aks1111)
   → フォールバック処理実行 → YAMLインデントエラー発見
   ↓
5. setup-mongodb-auth.sh 修正 - YAMLインデント保持 (f2aa642)
   ↓
6. 2回目デプロイで完全修正予定
```

### GitHub Actions ワークフロー

**トリガー方法**:

1. https://github.com/aktsmm/CICD-AKS-technical-exercise/actions/workflows/infra-deploy.yml
2. "Run workflow" ボタンをクリック
3. ブランチ: `main`
4. "Run workflow" を実行

**実行内容**:

- Bicep テンプレートのデプロイ
- VM 拡張の実行（`forceUpdateTag` により強制再実行）
- setup-mongodb-auth.sh が正しく実行される

---

## 検証手順

### デプロイ完了後の確認

#### 1. MongoDB ユーザーの確認

```bash
az vm run-command invoke \
  -g rg-bbs-cicd-aks1111 \
  -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "mongo admin -u mongoadmin -p dhs7XVDulERmTGwL --eval 'db.getUsers()'"
```

**期待結果**:

```json
{
  "_id": "admin.mongoadmin",
  "userId": UUID("..."),
  "user": "mongoadmin",
  "db": "admin",
  "roles": [
    { "role": "root", "db": "admin" },
    ...
  ]
}
```

#### 2. アプリケーション Pod の再起動

```bash
kubectl rollout restart deployment guestbook-app
kubectl wait --for=condition=ready pod -l app=guestbook --timeout=120s
```

#### 3. アプリケーションログの確認

```bash
kubectl logs -l app=guestbook --tail=20
```

**期待結果**:

```
🚀 Server running on port 3000
✅ MongoDB接続成功
```

#### 4. ブラウザでアクセス

```bash
# Ingress External IP を取得
kubectl get ingress guestbook-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# ブラウザで開く
Start-Process "http://<EXTERNAL_IP>"
```

**期待結果**:

- ゲストブックページが正常に表示される
- メッセージを投稿できる
- 投稿したメッセージが表示される

#### 5. MongoDB にデータが保存されているか確認

```bash
az vm run-command invoke \
  -g rg-bbs-cicd-aks1111 \
  -n vm-mongo-dev \
  --command-id RunShellScript \
  --scripts "mongo guestbook -u mongoadmin -p dhs7XVDulERmTGwL --authenticationDatabase admin --eval 'db.messages.find().pretty()'"
```

**期待結果**:

```json
{
  "_id": ObjectId("..."),
  "message": "投稿したメッセージ",
  "timestamp": ISODate("...")
}
```

---

## 学んだ教訓

### 1. VM 拡張の冪等性

**問題**: Azure VM 拡張は同じ設定では再実行されない

**対策**:

- `forceUpdateTag` パラメータを使用
- `utcNow()` で毎回異なる値を生成
- CI/CD で自動的に強制再実行

### 2. grep の落とし穴

**問題**: `grep -q "authorization: enabled"` がコメント行にもマッチ

**対策**:

- 正規表現で行頭を指定: `^[[:space:]]*authorization:[[:space:]]*enabled`
- コメント記号を除外するパターンを使用
- テストケースを作成して検証

### 3. デフォルト設定の確認

**問題**: MongoDB のデフォルト設定にコメント例が含まれている

**対策**:

- デフォルト設定ファイルを確認
- コメント行を考慮したスクリプト作成
- 実際の環境で動作検証

### 4. フォールバック処理の重要性

**問題**: 「認証有効」だが「ユーザー不在」の状態に対応していない

**対策**:

- 実際に認証テストを実行
- 失敗した場合の復旧処理を実装
- エラーハンドリングとログの充実

### 5. GitHub リポジトリ名の管理

**問題**: Bicep に古いリポジトリ名がハードコードされていた

**対策**:

- 変数化やパラメータ化を検討
- コードレビューでリポジトリ URL をチェック
- CI/CD で URL の有効性を検証

### 6. YAML 構文とインデントの重要性 ⭐ 新規追加

**問題**: sed コマンドで YAML を編集する際、インデントが失われる

**具体例**:

```bash
# 誤った置換（インデント消失）
sed -i 's/#authorization: enabled/authorization: enabled/' /etc/mongod.conf

# 結果（構文エラー）
security:
authorization: enabled  # MongoDB起動失敗
```

**対策**:

- sed の置換文字列に**必要なスペースを明示的に含める**
- YAML 構文チェッカーでテスト
- MongoDB 起動ログでエラーを早期検出

**正しい実装**:

```bash
# 正しい置換（インデント保持）
sed -i 's/#authorization: enabled/  authorization: enabled/' /etc/mongod.conf

# 結果（正常）
security:
  authorization: enabled  # MongoDB正常起動
```

**教訓**:

- 構成ファイル編集スクリプトでは**空白文字も含めて完全一致**を確認
- YAML や Python など**インデント依存言語**では特に注意
- 手動テスト環境で実際の設定ファイルを確認

### 7. 非同期処理と起動待機 ⭐ 新規追加

**問題**: サービス起動コマンド（`systemctl restart`）は非同期で、即座に次の処理へ進む

**具体例**:

```bash
# 問題のあるコード
systemctl restart mongod
mongo admin --eval "db.createUser(...)"  # 接続失敗！
```

**MongoDB 起動タイムライン**:

```
0s: systemctl restart mongod (コマンド完了)
1s: [MongoDB] プロセス起動開始
2s: [MongoDB] 設定ファイル読み込み
3s: [MongoDB] ポート27017をLISTEN
4s: [MongoDB] 起動完了 ← この時点でやっと接続可能
```

**対策（悪い例）**:

```bash
systemctl restart mongod
sleep 10  # 固定待機：環境によって過剰または不足
```

**対策（良い例 - ポーリングループ）**:

```bash
systemctl restart mongod

# インテリジェント待機
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
```

**利点**:

- ✅ **最適な待機時間**: 起動完了次第すぐ進む（高速環境では 2 秒、遅い環境では必要なだけ待機）
- ✅ **確実性**: 実際に接続して確認（`ping`コマンド）
- ✅ **タイムアウト**: 無限ループを防ぐ（最大 60 秒）
- ✅ **デバッグ容易**: 進捗ログで問題を早期発見

**適用すべきケース**:

- データベース起動（MongoDB, PostgreSQL, MySQL など）
- Web サーバー起動（nginx, Apache）
- コンテナ起動（Docker, Kubernetes Pod）
- ネットワークサービス全般

**教訓**:

- `systemctl start/restart` は**コマンド発行の成功**であり、**サービス起動完了ではない**
- 固定 sleep よりポーリングループが推奨
- ヘルスチェックコマンドを活用（`ping`, `status`, `curl`など）

---

## 関連ドキュメント

- **Phase 17**: MongoDB 認証実装（初回）
- **Phase 18**: GitHub Variables 設定
- **Phase 19**: Ingress Controller 実装
- **Azure VM 拡張**: https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux

---

## 今後の改善案

### 1. スクリプトのテスト自動化

```bash
# テスト用スクリプト
#!/bin/bash
# test-mongodb-auth.sh

# テストケース1: コメントアウトされた行を除外
echo "security:" > /tmp/test.conf
echo "  #authorization: enabled" >> /tmp/test.conf
if grep -q "^[[:space:]]*authorization:[[:space:]]*enabled" /tmp/test.conf; then
  echo "FAIL: Should not match commented line"
else
  echo "PASS: Correctly ignores commented line"
fi

# テストケース2: 有効な行にマッチ
echo "security:" > /tmp/test.conf
echo "  authorization: enabled" >> /tmp/test.conf
if grep -q "^[[:space:]]*authorization:[[:space:]]*enabled" /tmp/test.conf; then
  echo "PASS: Correctly matches active line"
else
  echo "FAIL: Should match active line"
fi
```

### 2. VM 拡張の成功/失敗通知

- Azure Monitor アラートを設定
- 失敗時に Slack/Teams 通知
- GitHub Actions で VM 拡張ログを自動取得

### 3. MongoDB ユーザー作成の検証

- CI/CD パイプラインに検証ステップを追加
- デプロイ後に自動的に認証テストを実行
- 失敗した場合はロールバック

### 4. ドキュメントの改善

- スクリプトに詳細なコメントを追加
- README に既知の問題と回避策を記載
- トラブルシューティングガイドを作成

### 5. YAML 編集スクリプトのテスト

```bash
# YAMLインデント検証スクリプト
#!/bin/bash
# test-yaml-indent.sh

# テスト用設定ファイル作成
cat > /tmp/test-mongod.conf << 'EOF'
security:
  #authorization: enabled
EOF

# sed実行
sed -i 's/#authorization: enabled/  authorization: enabled/' /tmp/test-mongod.conf

# 検証
if grep -q "^  authorization: enabled" /tmp/test-mongod.conf; then
  echo "PASS: Indentation preserved (2 spaces)"
else
  echo "FAIL: Indentation lost"
  cat /tmp/test-mongod.conf | grep -A 1 security
fi

# MongoDB構文チェック（mongod --configがあれば）
# mongod --config /tmp/test-mongod.conf --version 2>&1 | grep -i "unrecognized" && echo "FAIL: Config syntax error"
```

---

## ステータス

### 1 回目デプロイ (rg-bbs-cicd-aks1111)

- [x] 問題の特定完了
- [x] 根本原因の分析完了（問題 3 まで）
- [x] Bicep ファイル修正 (7d48fdd)
- [x] forceUpdateTag 追加 (f0aeeb4)
- [x] setup-mongodb-auth.sh 修正 - grep pattern (8e8afc0)
- [x] デプロイ実行
- [x] 新たな問題発見（YAML インデント）

### 2 回目デプロイ (rg-bbs-cicd-aks001)

- [x] YAML インデントエラー確認
- [x] setup-mongodb-auth.sh 修正 - インデント保持 (f2aa642)
- [x] VM 削除（手動）
- [x] GitHub にプッシュ完了

### 3 回目デプロイ (rg-bbs-cicd-aks-001)

- [x] デプロイ実行
- [x] 新たな問題発見（MongoDB 起動待機不足）
- [x] 暫定対応: Bicep に sleep 10 追加 (4846a85)
- [x] 恒久対応: ポーリングループ実装 (4be92de)
- [x] GitHub にプッシュ完了

### 次回デプロイ（進行中）

- [ ] Infrastructure Deploy 実行中
- [ ] MongoDB ユーザー作成確認
- [ ] MongoDB サービス起動確認
- [ ] アプリケーション動作確認
- [ ] 全 8 要件の検証

**次のアクション**: GitHub Actions のデプロイ完了を待ち、検証手順を実行

**全修正完了**: コミット 4be92de で全ての既知の問題に対処済み

---

## トラブルシューティング履歴

### 発生した問題と解決

| #   | 問題                       | 原因                 | 解決策               | コミット |
| --- | -------------------------- | -------------------- | -------------------- | -------- |
| 1   | スクリプトダウンロード失敗 | 誤ったリポジトリ URL | URL 修正             | 7d48fdd  |
| 2   | VM 拡張が再実行されない    | 冪等性による         | forceUpdateTag 追加  | f0aeeb4  |
| 3   | grep がコメント行にマッチ  | 正規表現不十分       | 行頭アンカー追加     | 8e8afc0  |
| 4   | MongoDB 起動失敗           | YAML インデント消失  | sed 置換文字列修正   | f2aa642  |
| 5   | MongoDB 接続失敗（起動前） | 起動待機時間不足     | ポーリングループ実装 | 4be92de  |

### エラーメッセージ対応表

| エラーメッセージ                             | 原因                     | 対処法                              |
| -------------------------------------------- | ------------------------ | ----------------------------------- |
| `MongoServerError: Authentication failed`    | ユーザー未作成           | setup-mongodb-auth.sh 実行          |
| `ECONNREFUSED 10.0.2.4:27017`                | MongoDB 停止中           | `systemctl start mongod`            |
| `Unrecognized option: security`              | YAML 構文エラー          | インデント修正（2 スペース）        |
| `couldn't connect to server 127.0.0.1:27017` | MongoDB 起動前に接続試行 | ポーリングループで起動待機（60 秒） |
| `Connection refused`                         | サービス未起動           | `db.adminCommand('ping')`で確認     |

---

## Problem 6: Bash 構文エラー (2025-10-31 追加)

### 症状

**GitHub Actions デプロイ時**:

```
VMExtensionProvisioningError: VM has reported a failure when processing extension 'install-mongodb'
Error message: 'Enable failed: failed to execute command: command terminated with exit status=2
setup-mongodb-auth.sh: line 50: syntax error near unexpected token `fi'
```

### 根本原因

**エラーハンドリング追加時の構造破壊 (commit dabe689)**:

```bash
# ❌ 間違い
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if ! mongo admin --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "❌ ERROR: MongoDB is not running after initial startup"
    exit 1
  fi
  echo "✅ MongoDB is ready!"
  break
  fi  # ← 余分な fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
```

**問題点**:

1. `if` 内で `break` した後に余分な `fi` がある
2. ロジックが逆転（失敗時に exit、成功時にメッセージ＋ break の順序が不適切）

### 修正内容 (commit 24fe747)

```bash
# ✅ 正しい構造
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if mongo admin --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "✅ MongoDB is ready!"
    break
  fi  # ← 正しい位置
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for MongoDB... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 2
done
```

**変更点**:

- `if !` → `if` に修正（成功時に break する正しいロジック）
- 余分な `fi` と `break` の位置を修正
- エラーチェックはループ終了後に実施

---

## Problem 7: else 前の改行欠如 (2025-10-31 追加)

### 症状

**Bash 構文チェックエラー**:

```bash
./setup-mongodb-auth.sh: line 141: syntax error near unexpected token `else'
./setup-mongodb-auth.sh: line 141: `  echo "✅ MongoDB Authentication is working!"else'
```

### 根本原因

**Line 126 の改行漏れ (commit 24fe747 直後)**:

```bash
# ❌ 間違い
  echo "✅ MongoDB Authentication is working!"else
  echo "⚠️ MongoDB authentication is already enabled"
```

**Bash の文法**:

- `else` は独立した行として記述する必要がある
- 同一行に複数のステートメントを配置できない

### 修正内容 (commit 968341e)

```bash
# ✅ 正しい構造
  echo "✅ MongoDB Authentication is working!"

else
  echo "⚠️ MongoDB authentication is already enabled"
```

**変更点**:

- `echo` と `else` の間に改行追加

---

## 最終リファクタリング (2025-10-31)

### 変更内容 (commit 282f8c9)

**改善点**:

1. **全ログを `/var/log/mongodb-auth-setup.log` に記録**

   ```bash
   echo "=== MongoDB ready ===" | tee -a /var/log/mongodb-auth-setup.log
   ```

2. **複雑なフォールバック処理削除**

   - 既存ユーザー再作成ロジックを削除
   - 初回セットアップに集中

3. **セキュリティ強化**

   ```bash
   unset MONGO_ADMIN_PASSWORD  # メモリからパスワード削除
   ```

4. **sed の `\n` 問題を 2 段階処理で解決**

   ```bash
   # ❌ 問題のあるコード
   sed -i 's/^#security:/security:\n  authorization: enabled/' "$MONGO_CONF"

   # ✅ 修正後
   sed -i 's/^#security:/security:/' "$MONGO_CONF"
   sed -i '/^security:/a\  authorization: enabled' "$MONGO_CONF"
   ```

**統計**:

- 123 行削除、28 行追加
- スクリプトサイズ: 205 行 → 110 行（46%削減）

---

## 付録: リソースグループ一括削除スクリプト

**用途**: テスト環境の迅速なクリーンアップ

**ファイル**: `Scripts/ResourceDelete.ps1`

```powershell
# ===============================================
# ⚡ 指定サブスクリプション内で、指定文字列を含むリソースグループを並列削除
# PowerShell 7.x 対応
# ===============================================

# 🔧 設定パラメータ（必要に応じて変更）
$subscriptionId = "832c4080-181c-476b-9db0-b3ce9596d40a"
$keyword = "aks"                           # 削除対象に含めたいキーワード
$maxParallel = 8                            # 並列削除数（5〜8 推奨）
$force = $true                              # 確認スキップ

# サブスクリプション設定
az account set --subscription $subscriptionId | Out-Null
Write-Host "🎯 対象サブスクリプション: $subscriptionId"
Write-Host "🔍 リソースグループ名に '$keyword' を含むものを検索中..." -ForegroundColor Cyan

# ターゲットリスト抽出
$allGroups = az group list --query "[].name" -o tsv
$targetGroups = $allGroups | Where-Object { $_ -match "(?i)$keyword" }

if (-not $targetGroups) {
    Write-Host "✅ '$keyword' を含むリソースグループは見つかりませんでした。" -ForegroundColor Green
    return
}

Write-Host "🧾 削除対象リソースグループ（$($targetGroups.Count) 件）:" -ForegroundColor Yellow
$targetGroups | ForEach-Object { Write-Host " - $_" }

# 確認 or 強制削除
if (-not $force) {
    $confirmation = Read-Host "⚠️ 本当に削除しますか？ (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "🚫 削除を中止しました。" -ForegroundColor Gray
        return
    }
} else {
    Write-Host "⚡ 強制削除モードで実行します（確認なし）" -ForegroundColor Red
}

# 並列削除処理（PowerShell 7.x）
$targetGroups | ForEach-Object -Parallel {
    $rg = $_
    Write-Host "🗑 [$($using:subscriptionId)] $rg の削除を開始..." -ForegroundColor Red
    az group delete -n $rg --subscription $using:subscriptionId --yes --no-wait
} -ThrottleLimit $maxParallel

Write-Host "✨ 全削除リクエストを送信しました（最大 $maxParallel 並列）" -ForegroundColor Green
```

**使用例**:

```powershell
# Scripts ディレクトリから実行
cd d:\00_temp\wizwork\Scripts
.\ResourceDelete.ps1

# 実行結果例
🎯 対象サブスクリプション: 832c4080-181c-476b-9db0-b3ce9596d40a
🔍 リソースグループ名に 'aks' を含むものを検索中...
🧾 削除対象リソースグループ（3 件）:
 - rg-bbs-cicd-aks-00001
 - rg-bbs-cicd-aks001
 - rg-bbs-cicd-aks1111
⚡ 強制削除モードで実行します（確認なし）
🗑 [832c4080-...] rg-bbs-cicd-aks-00001 の削除を開始...
🗑 [832c4080-...] rg-bbs-cicd-aks001 の削除を開始...
🗑 [832c4080-...] rg-bbs-cicd-aks1111 の削除を開始...
✨ 全削除リクエストを送信しました（最大 8 並列）
```

**機能**:

- ✅ 並列削除（最大 8 並列）で高速化
- ✅ キーワードマッチング（大文字小文字区別なし）
- ✅ 強制モード（`$force = $true`）で確認スキップ
- ✅ PowerShell 7.x の `-Parallel` 機能活用

**注意事項**:

- ⚠️ `--no-wait` を使用しているため、削除完了を待たずに次へ進む
- ⚠️ 削除状態確認: `az group list --query "[?starts_with(name, 'rg-bbs-cicd-aks')].{Name:name, State:properties.provisioningState}" -o table`

---

**作成者**: GitHub Copilot  
**作成日時**: 2025-10-31  
**最終更新**: 2025-10-31 (Problem 6, 7 追加、リファクタリング、削除スクリプト追加)

```

---

**作成者**: GitHub Copilot
**作成日時**: 2025-10-31
**最終更新**: 2025-10-31 (YAML インデント問題追加)
```
