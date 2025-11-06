# ローカル秘匿ファイル管理ガイド

最終更新: 2025-11-05

本ドキュメントでは、ローカル開発・テスト時に利用する秘匿情報ファイルと、それらの `.gitignore` による保護について説明する。

## 1. ローカル秘匿ファイル一覧

### 1.1 MongoDB 認証情報

**ファイル名:** `mongo_password.txt`

**内容:**

```bash
MONGO_USER="mongoadmin"
MONGO_PASSWORD="<GitHub Secrets に保存済み>"
```

**用途:**

- ローカルでの MongoDB バックアップスクリプトテスト
- VM 接続時の手動バックアップ検証
- 開発環境でのデータベース操作

**GitHub Actions での管理:**

- **Variables:** `MONGO_ADMIN_USER` (値: `mongoadmin`)
- **Secrets:** `MONGO_ADMIN_PASSWORD` (機密情報のため非表示)
- **利用ワークフロー:** `backup-schedule.yml` (Scheduled Mongo Backup)

**利用方法:**

```bash
# シェルに読み込む
source mongo_password.txt

# または、スクリプト内で
source /path/to/mongo_password.txt
echo "User: $MONGO_USER"
```

**セキュリティ対策:**

```bash
# ファイル権限を所有者のみ読み書き可能に制限
chmod 600 mongo_password.txt

# 使用後は削除
rm mongo_password.txt
```

---

### 1.2 Azure Service Principal 認証情報

**ファイル名:** `azure-credentials.json`

**内容例:**

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**用途:**

- GitHub Actions Secret `AZURE_CREDENTIALS` の再発行時の元ファイル
- ローカルでの Azure CLI 認証テスト

**生成コマンド:**

```bash
az ad sp create-for-rbac \
  --name gh-aks-oidc \
  --role Contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth > azure-credentials.json
```

**GitHub Actions での管理:**

- **Secrets:** `AZURE_CREDENTIALS` (JSON 全体)
- **利用ワークフロー:** `policy-deploy.yml` (Deploy Policy Guardrails)

**取り扱い注意:**

- Secret 更新後は**即座に削除**するか、暗号化して安全な場所に保管
- 絶対に Git リポジトリにコミットしない

---

### 1.3 環境変数ファイル

**ファイルパターン:** `.env`, `*.env`, `.env.local`

**内容例:**

```bash
# Azure 環境情報
AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_RESOURCE_GROUP="rg-bbs-cicd-aks"
AZURE_LOCATION="japaneast"

# MongoDB 接続情報
MONGO_HOST="10.1.2.4"
MONGO_PORT="27017"
MONGO_USER="mongoadmin"
MONGO_PASSWORD="<GitHub Secrets に保存済み>"

# Storage アカウント情報
STORAGE_ACCOUNT_NAME="stwizdev72s324bzptokg"
STORAGE_CONTAINER_NAME="backups"

# ACR 情報
ACR_NAME="acrwizdev72s324bzptokg"
IMAGE_NAME="guestbook"
IMAGE_TAG="latest"
```

**用途:**

- ローカル開発環境での環境変数設定
- テストスクリプト実行時の設定読み込み
- CI/CD パイプラインのローカル再現

**利用方法:**

```bash
# 環境変数として読み込み
export $(cat .env | xargs)

# または direnv を使用
direnv allow .
```

**GitHub Actions での管理:**

- 各値は個別に Secrets または Variables として管理
- 詳細は `docs/Secrets_and_Variables_Setup.md` を参照

---

### 1.4 その他の秘匿ファイル

**ファイルパターン:** `*.secret`, `*.credentials`, `*.key`, `*.pem`

**用途:**

- SSH 秘密鍵 (`id_rsa`, `vm_key.pem`)
- API キー保存ファイル (`api-key.secret`)
- 証明書ファイル (`*.pfx`, `*.p12`)

**セキュリティ対策:**

```bash
# SSH 鍵の権限設定
chmod 600 ~/.ssh/id_rsa

# 証明書ファイルの保護
chmod 400 certificate.pem
```

---

## 2. .gitignore による保護

以下のパターンが `.gitignore` に登録されており、Git リポジトリにコミットされないよう保護されている:

```gitignore
# 秘匿情報ファイル
mongo_password.txt
azure-credentials.json
*.secret
*.credentials
*.key
*.pem

# 環境変数ファイル
.env
*.env
.env.local
.env.*.local

# Azure 設定情報
docs/AZURE_SETUP_INFO.md

# ドキュメントディレクトリ (作業履歴・トラブルシューティング)
Docs_issue_point/
Docs_work_history/

# IDE・エディタ設定
.vscode/
.idea/
*.swp
*.swo
*~

# OS 生成ファイル
.DS_Store
Thumbs.db
```

---

## 3. GitHub Actions での秘匿情報管理

### 3.1 Secrets (機密情報)

| Secret 名               | 内容                             | 対応ローカルファイル        |
| ----------------------- | -------------------------------- | --------------------------- |
| `AZURE_CREDENTIALS`     | Service Principal 認証 JSON      | `azure-credentials.json`    |
| `AZURE_CLIENT_ID`       | Azure AD アプリのクライアント ID | `.env` 内の対応値           |
| `AZURE_TENANT_ID`       | Azure テナント ID                | `.env` 内の対応値           |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID      | `.env` 内の対応値           |
| `MONGO_ADMIN_PASSWORD`  | MongoDB 管理者パスワード         | `mongo_password.txt` 内の値 |

### 3.2 Variables (非機密設定)

| Variable 名            | 内容                                    | 対応ローカルファイル        |
| ---------------------- | --------------------------------------- | --------------------------- |
| `AZURE_LOCATION`       | デプロイ先リージョン (`japaneast`)      | `.env` 内の対応値           |
| `AZURE_RESOURCE_GROUP` | リソースグループ名                      | `.env` 内の対応値           |
| `MONGO_ADMIN_USER`     | MongoDB 管理者ユーザー名 (`mongoadmin`) | `mongo_password.txt` 内の値 |
| `IMAGE_NAME`           | コンテナイメージ名 (`guestbook`)        | `.env` 内の対応値           |

詳細は `docs/Secrets_and_Variables_Setup.md` を参照。

---

## 4. セキュリティベストプラクティス

### 4.1 ファイル権限管理

```bash
# 秘匿ファイルは所有者のみ読み書き可能に
chmod 600 mongo_password.txt
chmod 600 azure-credentials.json
chmod 600 .env

# SSH 鍵は読み取り専用に
chmod 400 ~/.ssh/id_rsa
```

### 4.2 使用後の削除

```bash
# 一時的な秘匿ファイルは使用後すぐに削除
rm -f mongo_password.txt
rm -f azure-credentials.json
rm -f .env.local

# または安全な場所に移動
mv mongo_password.txt ~/secure-vault/
```

### 4.3 Git コミット前のチェック

```bash
# コミット前に秘匿情報が含まれていないか確認
git status
git diff --cached

# もし誤ってステージングした場合
git reset HEAD mongo_password.txt
git reset HEAD .env
```

### 4.4 履歴からの削除 (万が一コミットしてしまった場合)

```bash
# 特定ファイルを Git 履歴から完全削除
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch mongo_password.txt" \
  --prune-empty --tag-name-filter cat -- --all

# または BFG Repo-Cleaner を使用
bfg --delete-files mongo_password.txt
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# 強制プッシュ (注意: チームメンバーに事前通知)
git push origin --force --all
```

---

## 5. トラブルシューティング

### 5.1 ローカルファイルが Git に追跡されてしまう

**原因:** `.gitignore` に追加する前にコミットしてしまった

**解決策:**

```bash
# Git の追跡から削除 (ファイル自体は残す)
git rm --cached mongo_password.txt

# .gitignore に追加
echo "mongo_password.txt" >> .gitignore

# コミット
git add .gitignore
git commit -m "秘匿ファイルを .gitignore に追加"
```

### 5.2 GitHub Actions でパスワードが認識されない

**原因:** Secret 名が一致していない、または値が正しく設定されていない

**確認手順:**

1. `Settings` → `Secrets and variables` → `Actions` で Secret 名を確認
2. ワークフローファイル内の `${{ secrets.SECRET_NAME }}` が正しいか確認
3. Secret を再設定して再実行

### 5.3 ローカルスクリプトで環境変数が読み込まれない

**原因:** `export` せずに変数を定義している

**解決策:**

```bash
# ❌ 誤り
MONGO_PASSWORD="xxx"

# ✅ 正しい
export MONGO_PASSWORD="xxx"

# または source コマンドで読み込む
source mongo_password.txt
```

---

## 6. 参考資料

- [GitHub Actions - Secrets 管理](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)
- [Azure CLI - Service Principal 認証](https://learn.microsoft.com/cli/azure/create-an-azure-service-principal-azure-cli)
- [Git - .gitignore パターン](https://git-scm.com/docs/gitignore)
- [環境変数のベストプラクティス](https://12factor.net/config)
