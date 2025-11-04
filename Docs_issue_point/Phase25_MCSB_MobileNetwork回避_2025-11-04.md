# Phase25: MCSB v2 が要求する Microsoft.MobileNetwork プロバイダー制限対応 (2025-11-04)

## 事象概要

- `azure/arm-deploy@v1` で `infra/main.bicep` をサブスクリプションデプロイすると、Microsoft cloud security benchmark (MCSB) v2 イニシアチブの割り当てが `InvalidPolicyParameters` で失敗。
- 詳細ログでは、ポリシー定義 `SimGroupCMKsEncryptDataRest` が `Microsoft.MobileNetwork/simGroups` リソース型を参照し、対象サブスクリプションで未登録のリソースプロバイダー `Microsoft.MobileNetwork` を要求していた。
- セキュリティポリシー上、当該プロバイダー登録が禁止されており、登録試行 (`az provider register --namespace Microsoft.MobileNetwork`) もブロックされた。

## 原因

- MCSB v2 (policySetDefinitionId `e3ec7e09-768c-4b64-882c-fcada3772047`) には、モバイルネットワーク SIM グループ向けポリシー `SimGroupCMKsEncryptDataRest` が含まれている。
- サブスクリプションに `Microsoft.MobileNetwork` プロバイダーを登録できない場合、このポリシーの割り当てが失敗し、イニシアチブ全体のデプロイが止まる。

## 対応内容

1. 共通モジュール `infra/modules/policy-initiative-assignment.bicep` に `policyOverrides` パラメーターを追加。
   - `overrides` プロパティへ必要な設定だけを渡せるようにし、デフォルトでは null を渡すことで既存利用へ影響しないようにした。
2. `infra/main.bicep` の MCSB 割り当てで `policyOverrides` を指定し、問題のポリシー参照を無効化。
   - `policyDefinitionReferenceId: 'SimGroupCMKsEncryptDataRest'`
   - `effect: 'Disabled'`
3. コミット ID `ef476fa` (`fix: Microsoft.MobileNetwork 依存ポリシーを除外`) で main ブランチへ反映。

## 再発防止・確認ポイント

- Microsoft Learn ではポリシー割り当てにおける `overrides` の利用が解説されている（[Azure Policy assignment structure – Overrides](https://learn.microsoft.com/azure/governance/policy/concepts/assignment-structure#overrides)）。
- MCSB など大型イニシアチブを適用する際は、サブスクリプションのプロバイダー登録方針と照らし合わせ、必要に応じて `policyOverrides` や `notScopes` を用意する。
- `az deployment sub what-if --template-file infra/main.bicep --parameters @infra/parameters/main-dev.parameters.json` でデプロイ前に差分を確認すると安全。
- 将来的にプロバイダー登録方針が変更された場合は、当該 override を削除して元の効果に戻すこと。

## 参考リンク

- ワークフロー: GitHub Actions `Deploy Infrastructure` (最新実行で検証予定)
- 公式ドキュメント: [Azure Policy assignment structure – Overrides](https://learn.microsoft.com/azure/governance/policy/concepts/assignment-structure#overrides)
