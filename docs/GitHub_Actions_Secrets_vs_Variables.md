# GitHub Actions における Secrets と Variables の使い分けメモ

最終更新: 2025-11-05

リポジトリ内で扱う機密情報と公開してよい設定値の線引きを明確にし、Azure OIDC サービスプリンシパル周りで再び混乱しないように整理する。

## 1. 役割の違い

| 種別      | 特徴                                                                                               | 主な用途                                                                         |
| --------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Secrets   | GitHub Actions の実行時のみ復号される。UI やログから内容が参照できない。                           | パスワード、クライアントシークレット、証明書、接続文字列など厳重に保護すべき値。 |
| Variables | 平文で保持されるが、書き換えは権限者に限定される。ワークフローから環境変数として簡単に参照できる。 | リージョン名やリソースグループ名など、隠す必要はないが変更し得る設定値。         |

> 参考: [GitHub Actions の Secrets と Variables の違い](https://docs.github.com/actions/learn-github-actions/variables) (#microsoft.docs.mcp)

## 2. Azure OIDC サービスプリンシパルで必要な値

| 項目                               | 参照元                                            | 保存先                                 | メモ                                                                                        |
| ---------------------------------- | ------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------- |
| クライアント ID (`appId`)          | `az ad sp show --id <ObjectId> --query appId`     | `AZURE_CLIENT_ID` (Secret)             | OIDC でログインする際に必要。機密扱いではないが既存運用との整合性で Secret 管理。           |
| テナント ID                        | `az account show --query tenantId`                | `AZURE_TENANT_ID` (Secret)             | 一意性の高い情報だが従来どおり Secret にまとめる。                                          |
| (オプション) サブスクリプション ID | `az account show --query id`                      | `AZURE_SUBSCRIPTION_ID` (Secret)       | OIDC ログイン後に対象サブスクリプションへ切り替える。                                       |
| Object ID (`id`)                   | `az ad sp show --id <AZURE_CLIENT_ID> --query id` | `AZURE_GITHUB_PRINCIPAL_ID` (Variable) | RBAC 付与時に必要。公開しても影響がないので Variable 管理とし、Bicep/ワークフローから参照。 |
| Owner 付与フラグ                   | 任意                                              | `AZURE_GRANT_GITHUB_OWNER` (Variable)  | 通常は `false`。Owner が必要な場合のみ `true` に切り替える。                                |

## 3. ワークフローの挙動

- `infra-deploy` ワークフローは `AZURE_GITHUB_PRINCIPAL_ID` を参照して、Bicep と CLI の両レイヤーで User Access Administrator (必要なら Owner) を自動付与する。値が未設定だと RBAC ブートストラップが実行されない。
- 逆に `AZURE_CLIENT_ID` を Variables に設定しても RBAC 作成コマンドは Object ID を要求するため、失敗する点に注意。Object ID との混同から今回のエラーが発生した。

## 4. チェックリスト

1. サービスプリンシパルを新規作成・再登録したら `az ad sp show --id <appId>` で Object ID を確認。
2. `AZURE_CLIENT_ID` (Secret) と `AZURE_GITHUB_PRINCIPAL_ID` (Variable) の両方を最新化。
3. `AZURE_GRANT_GITHUB_OWNER` が意図せず `true` のままになっていないかを確認。
4. `infra/parameters/main-dev.parameters.json` の `automationPrincipalObjectId` を `AZURE_GITHUB_PRINCIPAL_ID` と同じ値にそろえる。

## 5. 実務メモ

- Object ID は GUID だが機密ではないため Variable 管理で問題ない。
- シークレットに誤って保存した場合でも、Variable にコピーし直せばワークフローは期待どおり動作する。不要になった Secret は削除しておくとリストが整理される。
- 監査用には `Docs_work_history` に更新日時と担当者を記録すると履歴管理が楽になる。
