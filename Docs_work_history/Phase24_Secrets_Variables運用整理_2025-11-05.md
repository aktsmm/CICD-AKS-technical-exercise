# Phase24 Secrets/Variables 運用整理 (2025-11-05)

## 背景

- OIDC 移行後、GitHub Actions で扱うサービスプリンシパル情報のうち「クライアント ID (appId)」と「Object ID (id)」の使い分けが混乱し、RBAC 付与ステップが失敗していた。
- `AZURE_GITHUB_PRINCIPAL_ID` を Secret に登録してしまい、ワークフローから参照できなかったことが発端。
- 今後もリソースグループを切り替えながら自動デプロイと RBAC ブートストラップを行うため、Secrets/Variables の整理とドキュメント化が必要になった。

## 実施内容

1. **ドキュメント整備**

   - `docs/Secrets_and_Variables_Setup.md` と `docs/Secrets_Quick_Reference.md` に `AZURE_GITHUB_PRINCIPAL_ID` / `AZURE_GRANT_GITHUB_OWNER` を追記。
   - `docs/GitHub_Actions_Secrets_vs_Variables.md` を新規作成し、Secrets と Variables の用途・保管先・参照コマンドを一覧化。
   - メインドキュメントから上記メモへリンクを追加し、迷ったときに即参照できる導線を確保。

2. **Bicep & ワークフロー更新**

   - `infra/main.bicep` に `automationPrincipalObjectId` / `grantAutomationPrincipalOwner` パラメータを追加し、リソースグループ配下で User Access Administrator を自動付与する `modules/rbac-bootstrap.bicep`、必要時のみ Owner を付与する `modules/rbac-bootstrap-owner.bicep` を組み込み。
   - `.github/workflows/infra-deploy.yml` にブートストラップ手順を追加。`AZURE_GITHUB_PRINCIPAL_ID` が設定されている場合、`AZURE_CREDENTIALS` を用いた昇格ログインで RBAC を確認・付与後、OIDC ログインへ切り替えて本デプロイを実施する流れに統一。
   - `infra/parameters/main-dev.parameters.json` にも Object ID を明示し、テンプレート単体で再現できるようにした。

3. **変数設定の再確認**
   - GitHub Repository Variables に `AZURE_GITHUB_PRINCIPAL_ID = 60603759-feba-41e2-9b02-9dc78248bdf3` を登録済みであることを確認。
   - Owner 付与フラグは最小権限維持の観点から `AZURE_GRANT_GITHUB_OWNER = false` のままとし、必要なデプロイ時のみ `true` に切り替える運用を明記。

## 検証

- `az ad sp show --id 60603759-feba-41e2-9b02-9dc78248bdf3 --query "{displayName:displayName,appId:appId,objectId:id}"` を実行し、Object ID が正しく取得・共有されていることを確認。
- Repository Variables の UI 上で `AZURE_GITHUB_PRINCIPAL_ID` が設定されていることを目視確認（スクリーンショットは省略）。
- まだ `1. Deploy Infrastructure` の `workflow_dispatch` 実行は未実施。ドキュメント更新後に最新コミットを対象に手動実行し、RBAC 付与 → OIDC ログイン → デプロイが成功することを確認する必要がある。

## 次のアクション

1. `infra-deploy` ワークフローを `workflow_dispatch` で一度実行し、RBAC ブートストラップと本デプロイが連続成功するか検証する。少なくともリソースグループ作成とロール割り当て部分のログを確認すること。
2. 将来的に別リソースグループへ切り替える場合は、`AZURE_RESOURCE_GROUP` と併せて `automationPrincipalObjectId` の値が最新かをチェックし、本ドキュメントをもとに更新手順を踏襲する。
