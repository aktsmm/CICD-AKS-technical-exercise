# Phase31 RBAC Owner 重複割り当て検知とワークフロー改修 (2025-11-05)

## サマリ

- 事象: `1. Deploy Infrastructure` ワークフローが Bicep デプロイ中に `RoleAssignmentExists` エラーで失敗。
- 原因: GitHub Actions 用サービス プリンシパル (Object ID `60603759-feba-41e2-9b02-9dc78248bdf3`) に Owner ロールが既に割り当て済みで、`rbac-bootstrap-owner.bicep` が同一ロールを再付与しようとした。
- 影響: サブスクリプション スコープのロール割り当てモジュールが失敗し、以降のリソース展開が実行されなかった。
- 対応: ワークフローで Owner ロールの既存有無を事前判定し、必要時のみ Bicep パラメーターを `true` に設定。また、RBAC 付与に先立ってリソースグループを確実に作成するステップを追加。

## 詳細

- 発生日時: 2025-11-05 20:45 UTC 頃 (Run #145)。
- エラー抜粋: `RoleAssignmentExists` (`rbac-owner-20251104204536`)。
- 参考資料: [Azure CLI az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment) – `--assignee-object-id` や `list` コマンドのパラメーター仕様。

## 調査メモ

1. GitHub Actions ログで `Ensure RBAC for GitHub Actions Principal` ステップ完了後、`azure/arm-deploy@v1` が `DeploymentFailed` を返していることを確認。
2. `az role assignment list --subscription <SUB_ID> --assignee-object-id 60603759-feba-41e2-9b02-9dc78248bdf3 --role Owner -o table` をローカルで実行し、既存割り当てを確認。
3. `infra/modules/rbac-bootstrap-owner.bicep` が GUID ベースで一意のロール割り当て名を生成しているため、Azure 側で重複検出され失敗すると判明。

## 対応

1. `.github/workflows/infra-deploy.yml` に Owner ロール判定ロジックを追加。
   - `az role assignment list` で Owner 割り当てが存在する場合は `GRANT_OWNER_PARAMETER=false` をセット。
   - 未存在かつ変数が `true` の場合のみ `GRANT_OWNER_PARAMETER=true` とし、Bicep に渡す。
2. 同ステップで `az role assignment create` へ `--assignee-object-id` を使用し、Graph API 呼び出しに頼らない形へ統一。
3. RBAC 処理前に `Ensure Resource Group Exists (bootstrap phase)` を追加し、`az group create` でリソースグループを先に用意してから権限を付与。
4. 修正を `main` ブランチへコミットし、再デプロイで Owner 重複が発生してもスキップされることを確認予定。

## 再発防止 / TODO

- Owner 権限の付与が不要になったら GitHub 変数 `AZURE_GRANT_GITHUB_OWNER` を `false` に戻す運用を徹底。
- 既存ロール割り当てを定期棚卸しするスクリプトを追加検討 (`az role assignment list --include-derived-role` などで取得)。
- リソースグループ新設パターン向けに、RBAC ステップの前に `az group exists` を行うワークフロー変更が必要な場合は本実装を踏襲する。
