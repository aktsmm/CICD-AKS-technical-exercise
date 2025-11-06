# Phase41: Policy Guardrails のリージョン不整合による再デプロイ失敗 (2025-11-06)

## 背景

GitHub Actions ワークフロー `2-2. Deploy Azure Policy Guardrails` で、環境変数 `AZURE_LOCATION` を `eastus` に切り替えて再実行したところ、Azure Policy の割り当て処理が `AlreadyExistServicePrincipalInDifferentRegion` エラーで失敗した。インフラワークフロー側は正常にリージョン切替が完了しており、ポリシー側のみが失敗していた。

## 発生した症状

- `azure/arm-deploy@v1` ステップが `FailedIdentityOperation` を返し、`LocationInAAD: 'japaneast', LocationInModel: 'eastus'` が検出された。
- 既存のポリシー割り当て (`asgmt-cis140-dev`, `asgmt-mcsb-dev`) に紐づくシステム割り当て ID が `japaneast` 固定で作成されていたため、新しいリージョンでの再デプロイが拒否された。

## 調査メモ

1. GitHub Actions のログから、`policy-guardrails-13-eastus` デプロイで Azure Policy 割り当てが既存 ID に対してリージョン不整合を起こしていることを確認。
2. Azure CLI でポリシー割り当ての `location` を確認し、すべて `japaneast` に固定されていたことを突き止めた。
3. 公式ドキュメント「[Azure Policy assignment structure – Identity](https://learn.microsoft.com/ja-jp/azure/governance/policy/concepts/assignment-structure#identity)」で、マネージド ID を伴う割り当ては `location` を必須とし、変更できない制約を再確認。

```bash
# 既存ポリシー割り当てのリージョンを確認する例
az policy assignment show \
  --name asgmt-cis140-dev \
  --scope /subscriptions/$SUBSCRIPTION_ID \
  --query location -o tsv  # AAD 上のマネージド ID がどのリージョンに固定されているか把握する
```

## 根本原因

- Azure Policy のシステム割り当てマネージド ID は作成時のリージョンで固定され、あとから変更不可。
- GitHub Actions 側で `AZURE_LOCATION` を切り替えても、既存ポリシー割り当てのリージョンが変わらないため、AAD に存在するマネージド ID と Bicep テンプレートが要求するリージョンが一致せずにエラーとなった。

## 対応内容

1. ワークフローの「Resolve Deployment Location」ステップに、既存ポリシー割り当て (`asgmt-cis140-dev` / `asgmt-mcsb-dev` / `asgmt-storage-public-dev`) の `location` を照会する処理を追加。
2. 既存割り当てが見つかった場合は、そのリージョンで `LOCATION` を上書きし、ワークフロー全体が既存リージョンに合わせて再実行されるようにした。
3. 環境名は `infra/parameters/policy-dev.parameters.json` から `jq` で読み取り、パラメータ未設定時は `dev` をデフォルトとした。
4. 変更をコミット (`♻️ 既存ポリシー割り当てのリージョンを自動適用`) し、`main` ブランチへプッシュ。

```bash
# 既存ポリシー割り当てを削除して新リージョンで作り直す場合の参考手順
az policy assignment delete \
  --name asgmt-cis140-dev \
  --scope /subscriptions/$SUBSCRIPTION_ID  # 既存リージョン固定を解除するために割り当てを削除

az policy assignment delete \
  --name asgmt-mcsb-dev \
  --scope /subscriptions/$SUBSCRIPTION_ID  # もう一方の割り当ても削除してリージョン競合を防ぐ
```

> **TIP:** 発見済みのマネージド ID を削除せずにリージョンを切り替えると、AAD 側のサービスプリンシパルがリージョン不整合で再利用できない。リージョンを変更したい場合は、既存割り当ての削除 → 新リージョンでの再発行、またはユーザー割り当て ID の採用を検討すること。

## 再発防止策・学び

- リージョンを可変にするワークフローでは、既存リソース (特にマネージド ID) のリージョン固定制約を事前に確認し、差分があれば自動的に揃える処理を組み込む。
- 公式ドキュメントで示されているように、ポリシー割り当ての `location` はマネージド ID 利用時に必須であり、`global` は指定できず、変更も不可。再デプロイ時は既存値を尊重するか、明示的に割り当てを再作成する。
- GitHub Actions 内で `jq` を利用する場合は、`apt-get install jq` が不要な Ubuntu ランナーで実行していることを確認済み。別ランナーを利用する際は前提ツールの有無をチェックすること。

## 参考リンク

- [Azure Policy assignment structure – Identity](https://learn.microsoft.com/ja-jp/azure/governance/policy/concepts/assignment-structure#identity)
