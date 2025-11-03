# Phase24: azure/arm-deploy で .bicepparam が読み込めない事象対応 (2025-11-04)

## 事象概要

- GitHub Actions ワークフロー `Deploy Infrastructure #124` が失敗。
- `azure/arm-deploy@v1` のテンプレート検証で以下エラーが発生。
  - `ERROR: unrecognized template parameter 'using '../main.bicep'... Allowed parameters: deploymentTimestamp, environment, location, mongoAdminPassword, resourceGroupName`
- `.bicepparam` ファイル内のコメントや `using` 宣言がそのままテンプレート パラメーターとして解釈されていた。

## 原因

- `azure/arm-deploy@v1` は内部的に `az deployment sub create ... --parameters @file` を実行する。
- 現時点の Azure CLI は ARM 形式(JSON/YAML)のみサポートし、Bicep パラメータファイル (`.bicepparam`) を直接解釈できない。
- そのためコメントや `using` 宣言を含む `.bicepparam` を指定すると、CLI が未対応形式として処理しエラー終了する。

## 対応内容

1. `.bicepparam` を削除し、ARM パラメーター形式の JSON ファイルへ置き換え。
   - `infra/parameters/main-dev.parameters.json`
   - `infra/parameters/policy-dev.parameters.json`
2. GitHub Actions ワークフローを更新し、`@<path>.parameters.json` を読み込むよう修正。
   - `.github/workflows/infra-deploy.yml`
   - `.github/workflows/policy-guardrails.yml`
3. 秘匿情報(`mongoAdminPassword`)は従来通り GitHub Secrets から上書きして注入。
4. コミット ID `f8f4a2a` で main ブランチへ反映済み。

## 再発防止・確認ポイント

- GitHub Actions で Bicep を扱う際は、パラメーター ファイルは JSON/YAML を利用する。
- ローカルテスト例: `az deployment sub create --template-file infra/main.bicep --parameters @infra/parameters/main-dev.parameters.json mongoAdminPassword=$env:MONGO_ADMIN_PASSWORD`
- 将来的に `.bicepparam` を利用する場合は、Azure CLI バージョンアップでサポートされているか事前検証が必須。
- ドキュメントや README のリソースグループ名表記が `rg-bbs-cicd-aks` に統一されていることも併せて確認。

## リンク

- エラーとなったワークフロー実行: Deploy Infrastructure #124
- 修正コミット: `f8f4a2a` (`fix: ワークフローで JSON パラメーターファイルを参照`)
- 参考: Microsoft Learn "Parameter files" (<https://learn.microsoft.com/azure/azure-resource-manager/templates/parameter-files?tabs=azure-cli>)
