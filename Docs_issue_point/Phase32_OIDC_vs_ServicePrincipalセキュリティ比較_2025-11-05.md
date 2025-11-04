# Phase32 OIDC 認証と Service Principal シークレット認証のセキュリティ比較 (2025-11-05)

## サマリ

- GitHub Actions の `azure/login` を旧来のサービス プリンシパル (クライアント シークレット) 認証から OIDC 連携へ移行した理由を整理。
- 現行環境 (リポジトリ `aktsmm/CICD-AKS-technical-exercise`、アプリ `gh-aks-oidc`) では、OIDC を使うことでシークレット永久管理から脱却し、実行ごとに短命トークンを払い出している。
- Microsoft の推奨事項どおり、OIDC はシークレット漏洩リスクを低減し、権限管理・監査の一元化が可能 [参考: OIDC の利点](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure?tabs=azure-portal%2Cgithub-cli%2Cgithub-actions#benefits-of-using-oidc)。

## このリポジトリでの具体的な違い

| 観点 | 旧方式: Service Principal シークレット | 現行: GitHub OIDC フェデレーション |
| --- | --- | --- |
| 認証情報の保管 | `AZURE_CREDENTIALS` Secret に JSON を長期保存。漏洩時は SP ローテーションが必要。 | GitHub が発行する一時トークンを `azure/login` が直接取得。リポジトリに永続シークレットを保存しない。 |
| 有効期限 | クライアント シークレットを最大 2 年で手動更新。期限切れがデプロイブロッカーになりやすい。 | 各ワークフロー実行時に数分で失効するトークンを払い出し。自動ローテーション。 |
| スコープ制御 | 同じ SP 資格情報を複数ジョブが使い回し、最小権限の適用が難しい。 | フェデレーションクレデンシャルを subject ごと (例: `repo:...:ref:refs/heads/main` / `environment:aks-demo`) に作成し、必要なワークフローだけにアクセス許可。 |
| RBAC 管理 | 手動で SP にロールを割り当て。複数環境での差分管理が煩雑。 | `infra-deploy` ワークフローで OIDC プリンシパルに必要なロールを自動付与 (`AZURE_GITHUB_PRINCIPAL_ID` を変数化)。 |
| 監査 | シークレット使用履歴が GitHub 側で追跡しづらい。押下履歴も残りにくい。 | Azure AD 側で発行されたトークンごとにサインインログが残り、GitHub Actions の Run ID と紐付け可能。 |
| インシデント対応 | シークレット流出時は全ワークフロー停止→SP 再作成→Secret 再登録が必要。 | フェデレーション資格は漏洩しても利用できず、必要なら Azure Portal から個別のクレデンシャルを削除するだけで済む。 |

## 実際に実施した設定

1. Azure AD アプリ `gh-aks-oidc` に GitHub OIDC プロバイダーを登録。Subject 例: `repo:aktsmm/CICD-AKS-technical-exercise:ref:refs/heads/main`、`repo:aktsmm/CICD-AKS-technical-exercise:workflow_dispatch`、`repo:aktsmm/CICD-AKS-technical-exercise:environment:aks-demo`。
2. GitHub リポジトリ変数で `AZURE_GITHUB_PRINCIPAL_ID` (アプリの Object ID) を保持し、RBAC ブートストラップで利用。
3. `.github/workflows/infra-deploy.yml` で `azure/login@v1` の OIDC モードを採用し、Owner 付与や Resource Group 作成を自動化。
4. シークレット側には OIDC ログインで不要となった `AZURE_CREDENTIALS` を段階的に撤去予定。残す場合でもバックアップ用途のみ。

## なぜ OIDC の方がセキュアか (この環境での根拠)

- **シークレットレス運用**: ワークフロー実行ごとに `actions.tokens.githubusercontent.com` 経由で署名付きトークンを発行。GitHub の Secret 設定画面に長期資格情報を保持せず、GitHub の権限を持つユーザーでも Azure への直接ログインはできない。
  👉 実例: `AZURE_CLIENT_ID`・`AZURE_TENANT_ID` は残るが、クライアントシークレットは不要になった。
- **環境ごとの認可**: `repo:...:environment:aks-demo` のように subject を分けることで、`aks-demo` 環境のワークフロー以外が同じプリンシパルを使用できない。Pull Request からの不正実行を防ぎつつ、本番相当の RBAC を最小限に制限できる。
- **短命トークンによる爆発半径の縮小**: トークンは数分で失効するため、実行ログが漏れても再利用が困難。Service Principal シークレットの場合は漏洩後に即座に Azure 側で無効化しない限り悪用されるリスクが高い。
- **監査ログの可視性向上**: Azure AD のサインインログに GitHub の `workflow` クレームが含まれるため、`infra-deploy` 実行者と Run ID を特定できる。障害解析やコンプライアンスで証跡を提示しやすい。
- **自動ローテーションと最小権限の運用負荷軽減**: `infra-deploy` ワークフローで Owner 付与やリソースグループ権限をチェックし、自動調整。OIDC だからこそ Object ID を変えずにロール管理でき、シークレット期限切れ対応が不要になる。

## 追加の実務 Tip

- フェデレーション subject を追加したら、`az ad app federated-credential list --id <appId>` を記録して棚卸しする。
- Owner 権限が不要なときは GitHub 変数 `AZURE_GRANT_GITHUB_OWNER` を早めに `false` に戻し、`Docs_work_history` にログを残す。
- `az login --scope https://management.azure.com//.default` でローカル検証する場合も、同じアプリの OIDC 設定を使うと権限が揃い、動作差異を減らせる。
