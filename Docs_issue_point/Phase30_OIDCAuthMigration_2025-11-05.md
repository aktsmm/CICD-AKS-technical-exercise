# Phase30 Service Principal 認証から OIDC 認証への移行 (2025-11-05)

## サマリ

- 目的: GitHub Actions から Azure への認証方式を Service Principal (シークレット) ベースから OIDC (ワークロード ID フェデレーション) へ移行。
- 対象: `1. Deploy Infrastructure`, `2-1. Build and Deploy Application`, `2-2. Deploy Policy Guardrails` を含む全ワークフロー。
- 成果: ランナーにシークレットを渡さずに認証できるようになり、`azure/login@v1` は `client-id`/`tenant-id`/`subscription-id` と `id-token: write` 権限で実行。フェデレーションクレデンシャルを環境・ブランチ単位で登録済み。

## 実施内容

1. **Azure AD アプリ登録の整備**

   - アプリ名: `gh-aks-oidc`
   - 既存 Service Principal を継続利用しつつ、フェデレーションクレデンシャルを追加。
   - 付与ロール: サブスクリプション `/subscriptions/832c4080-181c-476b-9db0-b3ce9596d40a` に対して `Contributor`。今後のロール割り当て作成のため `User Access Administrator` 付与を検討中。

2. **フェデレーションクレデンシャル**

   - main ブランチ用: `repo:aktsmm/CICD-AKS-technical-exercise:ref:refs/heads/main`
   - 環境 `aks-demo` 用: `repo:aktsmm/CICD-AKS-technical-exercise:environment:aks-demo`
   - 追加方法 (PowerShell 一時ファイル利用):

     ```powershell
     $payload = '{"name":"github-actions-env-aks-demo","issuer":"https://token.actions.githubusercontent.com","subject":"repo:aktsmm/CICD-AKS-technical-exercise:environment:aks-demo","audiences":["api://AzureADTokenExchange"]}'
     $tmp = New-TemporaryFile
     Set-Content -Path $tmp -Value $payload
     az ad app federated-credential create --id 55acf860-6c18-454d-94e2-c0b60fd09e0a --parameters $tmp
     Remove-Item $tmp
     ```

   - 参考: [Workload identity federation for GitHub Actions](https://learn.microsoft.com/entra/workload-id/workload-identity-federation#creating-federated-credentials-for-github-actions)

3. **GitHub Secrets / Variables**

   - Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `MONGO_ADMIN_PASSWORD`
   - Variables: `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`, `IMAGE_NAME`
   - 旧 `AZURE_CREDENTIALS` (Service Principal JSON) は利用停止。

4. **ワークフロー修正**

   - 各 `azure/login@v1` ステップで OIDC を利用する設定へ変更 (`permissions: id-token: write` を維持)。
   - `.github/workflows/infra-deploy.yml` に RBAC ロール割り当てステップを追加し、MongoDB VM Managed Identity と AKS Kubelet Identity へ必要ロールを付与。
   - `workflow_run` 依存関係を最新版のワークフロー名 (番号付き) に更新。
   - `3. Scheduled Mongo Backup` を GitHub Variables (`MONGO_VM_NAME`) で切り替え可能にし、VM 未存在時はスキップ警告のみでジョブ失敗を避けるよう調整。

5. **Issue 管理**
   - フェデレーションクレデンシャル不足による `AADSTS700213` 対応は [Phase29](./Phase29_OIDCEnvironmentCredential_2025-11-05.md) を参照。

## TODO / チェック事項

- 新規に環境を作成する際は `repo:...:environment:<環境名>` 用フェデレーションクレデンシャルを追加する運用をルール化。
- `az ad app federated-credential list --id 55acf860-6c18-454d-94e2-c0b60fd09e0a` を定期的に確認し、重複や不足を棚卸し。
- RBAC 割り当てが失敗しないよう、`User Access Administrator` ロール付与状況を確認。
- `Docs_work_history` にも作業履歴として記録済み (Phase23)。
