# Secrets 管理クイックリファレンス

最終更新: 2025-11-05

プロジェクトで利用する GitHub Secrets / Variables とローカル秘匿ファイルの扱いを素早く確認するための早見表。運用リハーサル時のチェックリストとして活用する。

## GitHub Secrets

| 名前                  | 用途                                            | メモ                                                                    |
| --------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| AZURE_CLIENT_ID       | Azure AD アプリ (gh-aks-oidc) のクライアント ID | `az ad app show --id gh-aks-oidc --query appId -o tsv` で再取得可能     |
| AZURE_TENANT_ID       | 認証に利用するテナント ID                       | `az account show --query tenantId -o tsv`                               |
| AZURE_SUBSCRIPTION_ID | デプロイ対象サブスクリプション                  | `az account show --query id -o tsv`                                     |
| AZURE_CREDENTIALS     | JSON 形式の Service Principal 認証情報          | `az ad sp create-for-rbac --sdk-auth > azure-credentials.json` で再発行 |
| MONGO_ADMIN_PASSWORD  | MongoDB 管理者のパスワード                      | ランダム生成し GitHub Secret に直接入力                                 |

> 提示 URL 参照: [GitHub Actions Secrets 管理](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)

## GitHub Variables

| 名前                      | 推奨値                               | 用途                                           |
| ------------------------- | ------------------------------------ | ---------------------------------------------- |
| AZURE_LOCATION            | japaneast                            | デプロイ既定のリージョン                       |
| AZURE_RESOURCE_GROUP      | rg-bbs-cicd-aks                      | すべてのワークフローで参照するリソースグループ |
| AZURE_GITHUB_PRINCIPAL_ID | 60603759-feba-41e2-9b02-9dc78248bdf3 | GitHub Actions サービスプリンシパル Object ID  |
| AZURE_GRANT_GITHUB_OWNER  | false                                | Owner を付与したい場合のみ true                |
| IMAGE_NAME                | guestbook                            | ACR に push するコンテナイメージ名             |
| MONGO_VM_NAME (任意)      | vm-mongo-dev                         | バックアップ用 Azure VM の論理名               |

## Bicep Parameters

- `automationPrincipalObjectId`: GitHub Actions のサービスプリンシパル Object ID。新しいリソースグループでもロール割り当てが自動化されるよう `infra/parameters/main-dev.parameters.json` で管理。
- `grantAutomationPrincipalOwner`: Owner 付与が必要な場合のみ `true` に変更（既定 `false`）。

## ローカル秘匿ファイル

`.gitignore` で除外されている主なファイル:

```text
docs/AZURE_SETUP_INFO.md
mongo_password.txt
*.secret
*.credentials
.env
*.env
```

- `azure-credentials.json`: Secret 更新時のみ生成し、反映後は削除または暗号化保管。
- `.env` / `*.env`: ローカル検証専用。git へは決してコミットしない。

## 定期ヘルスチェック手順例

```bash
# GitHub リポジトリに登録済みの Secrets/Variables をブラウザで確認
# Settings → Secrets and variables → Actions を開き、期限切れや不要項目がないかチェック

# Azure CLI で Service Principal 情報を再確認
az ad sp show --id gh-aks-oidc --query "{appId:appId, objectId:id}" -o jsonc  # AppID と ObjectID を可視化

# バックアップ用 VM 名の変化があれば GitHub Variable を忘れず更新
# PowerShell 例: 現在値を即座にメモできるよう控える
```

## 運用ヒント

1. Secrets/Variables 更新後は `infra-deploy` と `backup-schedule` を `workflow_dispatch` で手動実行して OIDC 認証と VM 連携を検証する。
2. 役割縮小の観点から GitHub Secrets の編集権限は最小限に保つ。
3. 監査向けには更新履歴を `Docs_work_history` フォルダーに記録し、誰がいつ変更したかを明確化する。

## 参考資料

- [GitHub Actions Secrets 管理](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)
- [GitHub Actions Variables 管理](https://docs.github.com/actions/learn-github-actions/variables)
- #microsoft.docs.mcp [Azure CLI での Service Principal 作成](https://learn.microsoft.com/cli/azure/create-an-azure-service-principal-azure-cli)
