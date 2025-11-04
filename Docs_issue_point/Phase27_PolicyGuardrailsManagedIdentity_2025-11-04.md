# Phase27: Deploy Policy Guardrails のポリシー公開・割り当て安定化対応 (2025-11-04)

## 事象概要

- GitHub Actions ワークフロー `Deploy Policy Guardrails` が複数回失敗し、Microsoft Cloud Security Benchmark (MCSB) のカスタムイニシアチブ公開とポリシー割り当てが完了しなかった。
- 主なエラーは以下の 4 点。
  1. `az policy set-definition create` が `--definitions` に渡した JSON を `OrderedDict(...)` と解釈し、「list type value expected」として失敗。
  2. 同コマンドに `--mode All` を渡したところ「unrecognized arguments: --mode All」となり失敗。
  3. 既存定義を更新する際に `--version` を渡した結果、「Policy set definition version changes are not supported.」と返され失敗。
  4. Bicep で `Modify` / `deployIfNotExists` を含むポリシー割り当てを行った際、マネージド ID を付与していなかったため「Policy assignments must include a 'managed identity'」で失敗。

## 原因

- PowerShell スクリプトが `ConvertTo-Json` で生成したオブジェクト (PSCustomObject) をそのままファイル参照 (`@path`) に渡したため、Azure CLI が JSON 配列ではなく `OrderedDict` 表記を受け取った。CLI の仕様は #microsoft.docs.mcp [az policy set-definition create](https://learn.microsoft.com/ja-jp/cli/azure/policy/set-definition?view=azure-cli-latest) で定義されており、`--definitions` は JSON 配列を期待する。
- `az policy set-definition create` では `--mode` パラメーターがサポートされておらず、CLI が不明な引数として拒否した。
- ポリシーイニシアチブは現時点で単一バージョンのみ許容されるため、既存定義へ `--version` を渡すと CLI がエラーを返す。
- MCSB イニシアチブには `Modify` / `deployIfNotExists` 効果が含まれており、#microsoft.docs.mcp [Azure Policy の修復ガイド](https://learn.microsoft.com/ja-jp/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#deploy-policy-definition) にもある「マネージド ID が必須」という要件を満たしていなかった。

## 対応内容

1. `.github/workflows/policy-guardrails.yml` の「Publish Custom MCSB Policy Set」ステップを改修。
   - JSON ファイルを分割して一時ディレクトリに書き出し、`--definitions`, `--params`, `--metadata`, `--definition-groups` に `@file` 形式で渡すよう変更。
   - CLI が未対応の `--mode` を削除し、`properties.version` も事前に除去してから create/update を実行。
2. `infra/modules/policy-initiative-assignment.bicep` に `enableManagedIdentity` / `managedIdentityLocation` パラメーターを追加し、必要時のみ `identity` と `location` を設定できるよう拡張。
3. `infra/policy-guardrails.bicep` で上記パラメーターを有効化し、両方のポリシー割り当てにシステム割り当てマネージド ID を付与。
4. 修正後にワークフロー #25 を実行し、ポリシー定義公開 → 割り当て →Bicep デプロイまでが成功することを確認。

## 再発防止・実務ヒント

- CLI 呼び出し前に `az policy set-definition create -h` をチェックし、引数仕様が変更されていないか必ず確認する。長期運用では CLI バージョン差異に注意。
- PowerShell で JSON を扱う場合、`ConvertFrom-Json` → `ConvertTo-Json` を使うか、一時ファイルを `Set-Content` で書き出してから `@path` 渡しを徹底すると構造崩れを防げる。
- ポリシー割り当てでマネージド ID を有効化した後は、その ID の `principalId` へ `Contributor` や `Resource Policy Contributor` など必要権限を付与しないと修復が動作しない。`az role assignment create --assignee <principalId>` をワークフローに組み込むと自動化しやすい。
- エラー診断時には `az deployment operation sub list --name <deploymentName>` を併用し、どのポリシー割り当てが失敗しているか詳細を把握すると早く切り分けられる。

## 参考リンク

- Azure CLI `az policy set-definition create` リファレンス: <https://learn.microsoft.com/ja-jp/cli/azure/policy/set-definition?view=azure-cli-latest>
- Azure Policy 修復ガイド (マネージド ID 要件): <https://learn.microsoft.com/ja-jp/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#deploy-policy-definition>
- 修正対象ファイル: `.github/workflows/policy-guardrails.yml`, `infra/modules/policy-initiative-assignment.bicep`, `infra/policy-guardrails.bicep`
