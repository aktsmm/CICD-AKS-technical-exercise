# Phase29 OIDC 環境向けフェデレーションクレデンシャル不足 (2025-11-05)

## サマリ

- 事象: GitHub Actions 環境 `aks-demo` で実行した `azure/login` が OIDC フェデレーション認証に失敗。
- 原因: Azure AD アプリ `gh-aks-oidc` に登録されているフェデレーションクレデンシャルが main ブランチ用 (`repo:...:ref:refs/heads/main`) のみで、環境コンテキスト (`repo:...:environment:aks-demo`) が未登録だった。
- 影響: `Deploy to AKS` ジョブが Azure CLI ログインに失敗し、アプリケーション デプロイが停止。

## 詳細

- 発生日時: 2025-11-04 18:49 UTC 頃 (Run #195)。
- エラー内容: `AADSTS700213: No matching federated identity record found for ... environment:aks-demo`。
- GitHub Actions の subject 仕様: 環境ごとに `repo:<owner>/<repo>:environment:<env>` が割り当てられる。
- 参照ドキュメント: [Workload identity federation for GitHub Actions](https://learn.microsoft.com/entra/workload-id/workload-identity-federation#creating-federated-credentials-for-github-actions)。

## 対応

1. 以下 JSON を用意し、PowerShell から一時ファイル経由で登録。

   ```powershell
   $fcFile = New-TemporaryFile
   Set-Content -Path $fcFile -Value '{"name":"github-actions-env-aks-demo","issuer":"https://token.actions.githubusercontent.com","subject":"repo:aktsmm/CICD-AKS-technical-exercise:environment:aks-demo","audiences":["api://AzureADTokenExchange"]}'
   az ad app federated-credential create --id 55acf860-6c18-454d-94e2-c0b60fd09e0a --parameters $fcFile
   Remove-Item $fcFile
   ```

2. 登録後、`az ad app federated-credential list --id 55acf860-6c18-454d-94e2-c0b60fd09e0a` で反映を確認。
3. `Deploy to AKS` ワークフローを再実行予定。

## 再発防止 / TODO

- 新しい GitHub Actions 環境を作成する際は、subject `repo:...:environment:<環境名>` 用フェデレーションを事前追加する運用に変更する。
- 既存環境の棚卸しと不足登録の自動化 (`az ad app federated-credential list` → 差分作成) をタスク化。
- Azure アプリに `User Access Administrator` 以上が付与されているかを定期チェックし、ロール割り当て処理が失敗しないよう監視。
