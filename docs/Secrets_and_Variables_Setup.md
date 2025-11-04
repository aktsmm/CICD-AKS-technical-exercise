# Secrets と環境変数の管理ガイド

最終更新: 2025-11-05

本ドキュメントでは GitHub Actions から利用するシークレット・変数の一覧と、Azure 側での取得／再発行手順、ローカルでの秘匿ファイルの扱いをまとめる。

## 1. GitHub Secrets (機密情報)

- **`AZURE_CLIENT_ID`**

  - 用途: Azure AD アプリ (Service Principal) のクライアント ID。
  - 取得: `az ad app show --id gh-aks-oidc --query appId -o tsv`
  - 補足: アプリ名を変更している場合は対象アプリの Object ID または App ID を指定して取得する。

- **`AZURE_TENANT_ID`**

  - 用途: 認証に利用するテナント ID。
  - 取得: `az account show --query tenantId -o tsv`
  - 補足: `az login` 済みのアカウントが対象テナントに紐づいていることを確認する。

- **`AZURE_SUBSCRIPTION_ID`**

  - 用途: デプロイ先サブスクリプションの識別子。
  - 取得: `az account show --query id -o tsv`
  - 補足: `az account set --subscription <name-or-id>` で対象サブスクリプションを選択後に実行する。

- **`AZURE_CREDENTIALS`**

  - 用途: Policy Guardrails ワークフローなど、一部処理でまだ Service Principal 認証 JSON を利用する場合に保持。
  - 再発行: 以下コマンドで JSON を生成し、その内容を Secret に保存する。

    ```bash
    az ad sp create-for-rbac \
      --name gh-aks-oidc \
      --role Contributor \
      --scopes /subscriptions/<subscription-id> \
      --sdk-auth > azure-credentials.json
    ```

  - 補足: 出力した `azure-credentials.json` は Secret 更新後すぐに削除するか安全な場所へ保管する。

- **`MONGO_ADMIN_PASSWORD`**
  - 用途: MongoDB 管理者 (mongoadmin) アカウントのパスワード。
  - 取り扱い: セキュアなランダム値を生成し、GitHub Secret に直接入力する。
  - 補足: 実運用を想定して複雑性ポリシーを満たすこと。

> GitHub での登録手順: `Settings` → `Secrets and variables` → `Actions` → `New repository secret` から上記値を登録する。

## 2. GitHub Variables (非機密設定)

| 名前                   | 推奨値            | 用途/補足                                                                                                         |
| ---------------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------- |
| `AZURE_LOCATION`       | `japaneast`       | 既定のデプロイリージョン。Bicep/Actions 双方で参照。                                                              |
| `AZURE_RESOURCE_GROUP` | `rg-bbs-cicd-aks` | すべての GitHub Actions (特に backup ワークフロー) がこの値を利用。リソースグループを変更した場合は忘れずに更新。 |
| `IMAGE_NAME`           | `guestbook`       | コンテナビルド後に ACR へ push するイメージ名。                                                                   |
| `MONGO_VM_NAME` (任意) | `vm-mongo-dev`    | `3. Scheduled Mongo Backup` を複数環境で使い分ける場合に設定。未定義時は既定値 `vm-mongo-dev` を利用。            |

変数は `Settings` → `Secrets and variables` → `Actions` → `Variables` から登録する。

## 3. ローカル秘匿ファイルと .gitignore

ローカルで一時的に保持する認証情報は `.gitignore` によりコミット対象から除外する。

```text
# 抜粋 (.gitignore)
docs/AZURE_SETUP_INFO.md
mongo_password.txt
*.secret
*.credentials
.env
*.env
```

推奨されるローカルファイル例:

- `azure-credentials.json`: `AZURE_CREDENTIALS` 秘密情報の元ファイル。用途後は削除または暗号化保管。
- `.env` / `*.env`: 端末上での一時検証に利用。リポジトリへは決してコミットしない。

## 4. メンテナンスポイント

1. **更新タイミング**: Service Principal の資格情報を再発行した場合、`AZURE_CREDENTIALS` と `AZURE_CLIENT_ID` の整合性を必ず確認する。
2. **検証**: Secrets/Variables 更新後は対象ワークフロー (`infra-deploy`, `app-deploy`, `cleanup`, `backup-schedule`) を `workflow_dispatch` で一度手動実行し、OIDC ログインや VM コマンド実行が成功することを確認する。
3. **アクセス最小化**: GitHub 上で Secrets の閲覧・更新権限を必要最小限のメンバーに限定する。

## 5. 参考ドキュメント

- [GitHub Actions Secrets 管理](https://docs.github.com/actions/security-guides/using-secrets-in-github-actions)
- [GitHub Actions Variables 管理](https://docs.github.com/actions/learn-github-actions/variables)
- [Azure CLI での Service Principal 作成 (`az ad sp create-for-rbac --sdk-auth`)](https://learn.microsoft.com/cli/azure/create-an-azure-service-principal-azure-cli)
