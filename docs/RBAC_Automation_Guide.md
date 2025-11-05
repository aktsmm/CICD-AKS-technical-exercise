# RBAC自動化ガイド

## 概要
今回実行したService Principalへのロール割り当て処理をGitHub Actionsで自動化する方法を説明します。

## 🎯 実行した処理の内訳

### 1. Azure CLIログイン
```powershell
az login --tenant 04879edd-d806-4f5d-86b8-d3a171c883fa
```
- **目的**: Azureテナントに認証
- **自動化可否**: ✅ GitHub Actions Secretsで可能

### 2. サブスクリプション設定
```powershell
az account set --subscription 832c4080-181c-476b-9db0-b3ce9596d40a
```
- **目的**: 操作対象サブスクリプションを指定
- **自動化可否**: ✅ ワークフロー環境変数で可能

### 3. ロール割り当て
```powershell
az role assignment create \
  --assignee-object-id ba5e5bf1-4e1b-484a-a4cd-d8b9be224de3 \
  --assignee-principal-type ServicePrincipal \
  --role "Resource Policy Contributor" \
  --scope "/subscriptions/832c4080-181c-476b-9db0-b3ce9596d40a"
```
- **目的**: Service Principalに必要な権限を付与
- **自動化可否**: ⚠️ 条件付き可能
- **制約**: 実行する側が**Owner**または**User Access Administrator**ロールを持つ必要がある

### 4. ロール確認
```powershell
az role assignment list \
  --assignee-object-id ba5e5bf1-4e1b-484a-a4cd-d8b9be224de3 \
  --output table
```
- **目的**: 割り当てが成功したか検証
- **自動化可否**: ✅ 完全に自動化可能

---

## 🚀 自動化の実装方法

### **Option 1: セットアップ専用ワークフロー作成** (推奨)

#### ファイル: `.github/workflows/setup-rbac.yml`
新しく作成したワークフローを使用します。

#### 前提条件
1. **管理者権限を持つService Principalを作成**:
   ```bash
   # 新しいService Principalを作成
   az ad sp create-for-rbac --name "sp-wizexercise-admin" \
     --role "User Access Administrator" \
     --scopes "/subscriptions/832c4080-181c-476b-9db0-b3ce9596d40a"
   ```

2. **GitHub Secretsに追加**:
   - `AZURE_CREDENTIALS_ADMIN`: 管理者Service Principalの認証情報
   ```json
   {
     "clientId": "<admin-sp-client-id>",
     "clientSecret": "<admin-sp-client-secret>",
     "subscriptionId": "832c4080-181c-476b-9db0-b3ce9596d40a",
     "tenantId": "04879edd-d806-4f5d-86b8-d3a171c883fa"
   }
   ```

#### 実行方法
1. GitHubリポジトリの **Actions** タブに移動
2. **"0. Setup RBAC for Service Principal"** ワークフローを選択
3. **"Run workflow"** をクリック
4. 必要に応じてObject IDとSubscription IDを確認/変更
5. **"Run workflow"** を実行

#### メリット
- ✅ **再現性が高い**: パラメータ化されたワークフローで誰でも実行可能
- ✅ **監査証跡**: GitHub Actions実行履歴で誰がいつ実行したか記録
- ✅ **エラーハンドリング**: 失敗時の原因が明確
- ✅ **ドキュメント化**: ワークフロー自体がドキュメント

#### デメリット
- ⚠️ **追加Secret必要**: 管理者権限のService Principalが別途必要
- ⚠️ **セキュリティリスク**: 高権限Secretの管理が必要

---

### **Option 2: 既存ワークフローに権限チェック追加**

#### 実装内容
`policy-guardrails.yml`に新しいステップを追加しました:
- Azure Loginの直後に**権限検証ステップ**を挿入
- Resource Policy Contributorロールが無い場合、コマンド例を表示
- 実際のエラーを確認するため、警告のみで処理継続

#### 実行方法
自動実行されます(変更なし)。権限不足の場合はログに修正コマンドが表示されます。

#### メリット
- ✅ **追加Secret不要**: 既存の構成で動作
- ✅ **フェイルファスト**: 権限不足を早期検出
- ✅ **修正ガイド付き**: エラー時のコマンド例を自動表示

#### デメリット
- ❌ **自動修正不可**: 最終的には手動実行が必要
- ❌ **ワークフロー複雑化**: チェックロジックが追加される

---

## 📊 比較表

| 観点 | Option 1: セットアップワークフロー | Option 2: 権限チェック追加 | 現状(手動実行) |
|------|-----------------------------------|---------------------------|---------------|
| **自動化レベル** | 完全自動化 | 半自動(検出のみ) | 手動 |
| **追加Secret** | 必要(ADMIN) | 不要 | 不要 |
| **実行頻度** | 初回のみ | 毎回チェック | 問題発生時のみ |
| **セキュリティ** | 中(高権限Secret) | 高(既存Secretのみ) | 高 |
| **運用負荷** | 低 | 中 | 高(エラー時) |
| **推奨ケース** | チーム開発/複数環境 | 個人開発/単一環境 | 一度きりセットアップ |

---

## 🎓 推奨アプローチ

### **今回のケース(Wiz面接用)**
**現状維持(手動実行)を推奨**

理由:
1. ✅ **一度きりの操作**: ロール割り当ては初回セットアップ時のみ必要
2. ✅ **セキュリティ**: 高権限Secretを追加する必要がない
3. ✅ **シンプル**: 不要な自動化を避けられる
4. ✅ **既に完了**: 今回の手動実行で完了済み

### **本番環境/チーム開発の場合**
**Option 1(セットアップワークフロー)を推奨**

理由:
1. ✅ **再現性**: 環境構築手順が自動化・標準化される
2. ✅ **監査**: 誰がいつ権限変更したか記録される
3. ✅ **スケール**: 複数環境(dev/staging/prod)への展開が容易
4. ✅ **オンボーディング**: 新メンバーが簡単にセットアップ可能

---

## 📝 次のステップ

### 今すぐ実行
```bash
# GitHub Actions "2-2. Deploy Azure Policy Guardrails" を再実行
# https://github.com/aktsmm/CICD-AKS-technical-exercise/actions
```

### 将来的な改善案
1. **Terraform/Bicepでの管理**:
   ```hcl
   # terraform/rbac.tf
   resource "azurerm_role_assignment" "policy_contributor" {
     scope                = data.azurerm_subscription.primary.id
     role_definition_name = "Resource Policy Contributor"
     principal_id         = azuread_service_principal.github.object_id
   }
   ```

2. **Azure CLIスクリプト化**:
   ```bash
   # Scripts/Setup-RBAC.sh
   #!/bin/bash
   SP_OBJECT_ID=$1
   SUBSCRIPTION_ID=$2
   
   az role assignment create \
     --assignee-object-id "$SP_OBJECT_ID" \
     --assignee-principal-type ServicePrincipal \
     --role "Resource Policy Contributor" \
     --scope "/subscriptions/$SUBSCRIPTION_ID"
   ```

---

## 🔗 参考資料

### Microsoft Learn
- [Azure RBAC built-in roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- [az role assignment create](https://learn.microsoft.com/cli/azure/role/assignment#az-role-assignment-create)
- [GitHub Actions Azure Login](https://github.com/Azure/login)

### プロジェクト内ドキュメント
- [README.md](../README.md) - 全体的なセットアップ手順
- [Architecture_06_セキュリティコントロール実装.md](Architecture_06_セキュリティコントロール実装.md) - RBACとAzure Policyの設計
