# Phase26: Deploy Policy Guardrails の override スキーマ不一致修正 (2025-11-04)

## 事象概要

- GitHub Actions ワークフロー `Deploy Policy Guardrails` の実行が、MCSB v2 イニシアチブ割り当て時に `InvalidPolicyParameters` エラーで失敗した。
- エラーログでは、`overrides[*].value` が文字列でシリアライズされており、Azure Policy の仕様と一致しないと報告された。

## 原因

- `infra/policy-guardrails.bicep` で `policyOverrides` の `value` を `'Disabled'` のような単一文字列で指定していた。
- Azure Policy の override スキーマでは、`value` に効果 (`effect`) を含むオブジェクトを渡す必要があるため、文字列形式は検証で弾かれる。

## 対応内容

1. `infra/policy-guardrails.bicep` の override 設定を修正し、`value: { effect: 'Disabled' }` を渡すように変更。
   - これにより、`SimGroupCMKsEncryptDataRest` のポリシーだけを安全に無効化でき、モバイルネットワークプロバイダー不要でデプロイが成功する。
2. 既存のドキュメント `Phase25_MCSB_MobileNetwork回避_2025-11-04.md` を更新し、最新の override 記述 (`value.effect = 'Disabled'`) に合わせて記載を調整。
3. 修正後、`pwsh` から `az deployment sub what-if --location japaneast --template-file infra/policy-guardrails.bicep` を実行し、override の差分が意図通りか事前確認する運用手順を追記。

## 再発防止・実務ヒント

- override を導入する際は、1) `az deployment sub what-if` で差分を確認、2) GitHub Actions で dry-run 相当の `what-if` を組み込むと、スキーマミスを早期検知できる。
- 複数のポリシー定義参照を無効化する場合は、`selectors.in` に配列で追加し同じ `value` オブジェクトを再利用すると記述ミスが減る。
- `Microsoft.MobileNetwork` のように登録禁止のプロバイダーがある環境では、イニシアチブ更新時に `az policy definition list --subscription <SUB_ID> --query "[?policyType=='BuiltIn']"` を用い、新しい参照リソースが含まれていないか定期的に点検すると安心。

## 参考リンク

- [Azure Policy assignment structure – Overrides](https://learn.microsoft.com/azure/governance/policy/concepts/assignment-structure#overrides)
- 修正対象ファイル: `infra/policy-guardrails.bicep`
