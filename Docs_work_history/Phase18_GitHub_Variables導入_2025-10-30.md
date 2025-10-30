# Phase 18: GitHub Variables 導入によるハードコード解消

## 📅 作業日時
2025年10月30日

---

## 🎯 目的

ワークフローファイル内のハードコードされた設定値（リソースグループ名、リージョン、イメージ名）をGitHub Variablesに移行し、保守性と柔軟性を向上させる。

---

## 📋 背景

### 問題点

従来の設定では、以下の値がワークフローファイルに直接記述されていました：

```yaml
# .github/workflows/infra-deploy.yml
env:
    RESOURCE_GROUP: rg-bbs-cicd-aks001  # ハードコード
    LOCATION: japaneast                  # ハードコード

# .github/workflows/app-deploy.yml
env:
    IMAGE_NAME: guestbook                # ハードコード
    RESOURCE_GROUP: rg-bbs-cicd-aks001  # ハードコード
```

**課題**:
- ❌ 値を変更する度にコード修正が必要
- ❌ 複数ファイルで同じ値を重複管理
- ❌ リソースグループ名の変更履歴が複雑（過去に複数回変更）
- ❌ 環境（dev/staging/prod）の切り替えが困難

### リソースグループ名の変遷

```
rg-cicd-aks-bbs
  → rg-cicd-aks-bbs01
  → rg-bbs-icd-aks01
  → rg-bbs-aks
  → rg-bbs-cicd-aks001001
  → rg-bbs-cicd-aks001 ← 現在
```

---

## 🔧 実装内容

### 1. ワークフローファイルの修正

#### **infra-deploy.yml**

**変更前**:
```yaml
env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    RESOURCE_GROUP: rg-bbs-cicd-aks001
    LOCATION: japaneast
```

**変更後**:
```yaml
env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
    LOCATION: ${{ vars.AZURE_LOCATION }}
```

---

#### **app-deploy.yml**

**変更前**:
```yaml
env:
    IMAGE_NAME: guestbook
    RESOURCE_GROUP: rg-bbs-cicd-aks001
```

**変更後**:
```yaml
env:
    IMAGE_NAME: ${{ vars.IMAGE_NAME }}
    RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
```

---

### 2. 不要なアーティファクトダウンロード削除

ユーザーの指摘により、使用されていないアーティファクトダウンロードステップを削除：

**削除したコード** (app-deploy.yml):
```yaml
- name: Download Infra Outputs
  uses: actions/download-artifact@v4
  with:
      name: infra-outputs
  continue-on-error: true

- name: Get Infrastructure Details
  id: infra
  run: |
      # Try to load from artifact first
      if [ -f outputs/infra-outputs.txt ]; then
        echo "Loading from artifact..."
        source outputs/infra-outputs.txt
      else
        echo "Artifact not found, querying Azure directly..."
        # Fallback: Query Azure directly
        AKS_CLUSTER_NAME=$(az aks list -g ${{ env.RESOURCE_GROUP }} --query "[0].name" -o tsv)
        MONGO_VM_IP=$(az vm list-ip-addresses -g ${{ env.RESOURCE_GROUP }} -n vm-mongo-dev --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)
      fi
```

**最適化後**:
```yaml
- name: Get Infrastructure Details
  id: infra
  run: |
      echo "Querying Azure for infrastructure details..."
      
      # AKSクラスター名を取得
      AKS_CLUSTER_NAME=$(az aks list -g ${{ env.RESOURCE_GROUP }} --query "[0].name" -o tsv)
      
      # MongoDB VMのプライベートIPを取得（VNet内通信用）
      MONGO_VM_IP=$(az vm list-ip-addresses -g ${{ env.RESOURCE_GROUP }} -n vm-mongo-dev --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)

      echo "AKS Cluster: ${AKS_CLUSTER_NAME}"
      echo "MongoDB VM IP: ${MONGO_VM_IP}"

      echo "aks_name=${AKS_CLUSTER_NAME}" >> $GITHUB_OUTPUT
      echo "mongo_ip=${MONGO_VM_IP}" >> $GITHUB_OUTPUT
```

**理由**:
- `workflow_run` トリガーでは別ワークフローのアーティファクトに直接アクセス不可
- フォールバックとして実装されていたAzure直接クエリのみで十分
- 無駄なエラーログを削減

---

### 3. GitHub Variables 設定

#### 設定場所
```
GitHub Repository > Settings > Secrets and variables > Actions > Variables タブ
```

#### 設定した変数

| Variable名 | 値 | 用途 |
|-----------|-----|------|
| `AZURE_RESOURCE_GROUP` | `rg-bbs-cicd-aks001` | Azureリソースグループ名 |
| `AZURE_LOCATION` | `japaneast` | Azureリージョン |
| `IMAGE_NAME` | `guestbook` | Dockerイメージ名 |

#### 設定手順

1. リポジトリの **Settings** タブを開く
2. 左メニューから **Secrets and variables** > **Actions** を選択
3. **Variables** タブをクリック
4. **New repository variable** をクリック
5. Name と Value を入力して **Add variable**

---

### 4. ドキュメント作成

#### GitHub_Variables_Setup.md

詳細な設定ガイドを作成：
- Variables と Secrets の違い
- 設定手順（スクリーンショット付き説明）
- 使い分けガイド
- トラブルシューティング

**場所**: `Docs_Secrets/GitHub_Variables_Setup.md`  
**注意**: `.gitignore` により Git 管理外（ローカルのみ）

#### README.md 更新

関連ドキュメントセクションにリンクを追加：

```markdown
## 📚 関連ドキュメント

- [環境情報](docs/ENVIRONMENT_INFO.md) - デプロイ環境の詳細
- [トラブルシューティング履歴](Docs_issue_point/) - Phase 02-11 の問題解決記録
- [Azure セットアップ](docs/AZURE_SETUP_INFO.md) - Azure 構成手順
- **[GitHub Secrets 設定](Docs_Secrets/GitHub_Secrets_Configuration.md)** - 必須Secrets設定ガイド
- **[GitHub Variables 設定](Docs_Secrets/GitHub_Variables_Setup.md)** - リソースグループ名などの設定ガイド
```

---

## 📂 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `.github/workflows/infra-deploy.yml` | Variables 参照に変更 |
| `.github/workflows/app-deploy.yml` | Variables 参照 + アーティファクトステップ削除 |
| `Docs_Secrets/GitHub_Variables_Setup.md` | 新規作成（設定ガイド） |
| `README.md` | ドキュメントリンク追加 |

---

## 🔄 Git コミット履歴

```bash
# 1. アーティファクトダウンロード削除
15b123b - refactor: Remove unnecessary artifact download, query Azure directly

# 2. Variables 導入
10273ab - refactor: Use GitHub Variables for resource group and location

# 3. ドキュメント作成
534437d - docs: Add GitHub Variables setup guide

# 4. 一時的なハードコード復帰（Variables未設定時）
f5f850a - fix: Revert to hardcoded values for immediate deployment

# 5. Variables 設定完了後に再度変更
a2e6f18 - refactor: Use GitHub Variables (now properly configured)
```

---

## ✅ 動作確認

### 1. GitHub Variables 確認

```
Repository > Settings > Secrets and variables > Actions > Variables

✅ AZURE_LOCATION = japaneast
✅ AZURE_RESOURCE_GROUP = rg-bbs-cicd-aks001
✅ IMAGE_NAME = guestbook
```

### 2. ワークフロー実行確認

GitHub Actions ログで変数が正しく展開されることを確認：

```bash
# インフラデプロイログ
Resource Group: rg-bbs-cicd-aks001
Location: japaneast

# アプリデプロイログ
Image Name: guestbook
Resource Group: rg-bbs-cicd-aks001
```

---

## 🎯 メリット

### 1. 保守性向上
- ✅ 設定値の一元管理（GitHub UI）
- ✅ コード変更不要で値を更新可能
- ✅ 変更履歴が GitHub UI で追跡可能

### 2. 柔軟性向上
- ✅ 環境切り替えが容易（dev/staging/prod）
- ✅ 複数リソースグループの運用に対応
- ✅ GitHub Environments と組み合わせ可能

### 3. セキュリティ
- ✅ Secrets と Variables の明確な使い分け
- ✅ 機密情報（パスワード）は Secrets でマスク
- ✅ 非機密情報（RG名）は Variables で可視化

### 4. コード品質
- ✅ ハードコード解消
- ✅ DRY原則の遵守（重複排除）
- ✅ ベストプラクティスに準拠

---

## 🆚 Secrets vs Variables の使い分け

| 項目 | Secrets | Variables |
|------|---------|-----------|
| **用途** | 機密情報 | 非機密な設定値 |
| **暗号化** | ✅ 暗号化保存 | ❌ 平文保存 |
| **ログ表示** | `***` でマスク | そのまま表示 |
| **アクセス方法** | `${{ secrets.NAME }}` | `${{ vars.NAME }}` |
| **値の確認** | 不可 | 可能 |

### このプロジェクトでの使い分け

**Secrets（機密情報）**:
- `AZURE_CREDENTIALS` - Azure認証情報
- `AZURE_SUBSCRIPTION_ID` - サブスクリプションID
- `MONGO_ADMIN_PASSWORD` - MongoDBパスワード

**Variables（非機密情報）**:
- `AZURE_RESOURCE_GROUP` - リソースグループ名
- `AZURE_LOCATION` - リージョン名
- `IMAGE_NAME` - イメージ名

---

## 🔍 検討した他の選択肢

### 選択肢1: タグベースの検索

**方法**: リソースグループにタグを付けて検索

```yaml
RESOURCE_GROUP=$(az group list \
  --tag project=wiz-technical-exercise \
  --query "[0].name" -o tsv)
```

**評価**:
- ❌ 事前にタグ設定が必要
- ❌ 既存RGへの適用に手間

### 選択肢2: AKSリソースから逆引き

**方法**: AKSクラスター名からRGを特定

```yaml
AKS_CLUSTER_NAME="aks-dev"
RESOURCE_GROUP=$(az aks list \
  --query "[?name=='${AKS_CLUSTER_NAME}'].resourceGroup | [0]" -o tsv)
```

**評価**:
- ✅ シンプルで確実
- ⚠️ AKS名のハードコードは残る
- 💡 将来的な改善案として有効

### 選択肢3: 命名規則ベースの検索

**方法**: プレフィックスで検索

```yaml
RESOURCE_GROUP_PREFIX="rg-bbs-cicd-aks"
RESOURCE_GROUP=$(az group list \
  --query "[?starts_with(name, '${RESOURCE_GROUP_PREFIX}')].name | [0]" -o tsv)
```

**評価**:
- ✅ 柔軟性が高い
- ⚠️ 複数マッチのリスク
- 💡 Variables と組み合わせると最適

---

## 📝 今後の改善案

### 1. 環境別Variables（将来対応）

GitHub Environments を使用して環境別に変数を管理：

```yaml
# 開発環境
AZURE_RESOURCE_GROUP = rg-bbs-cicd-aks-dev
AZURE_LOCATION = japaneast

# 本番環境
AZURE_RESOURCE_GROUP = rg-bbs-cicd-aks-prod
AZURE_LOCATION = japanwest
```

### 2. 動的検索とのハイブリッド

フォールバック機構を追加：

```yaml
# まずVariablesを使用
RESOURCE_GROUP="${{ vars.AZURE_RESOURCE_GROUP }}"

# 空の場合は動的検索
if [ -z "$RESOURCE_GROUP" ]; then
  RESOURCE_GROUP=$(az aks list \
    --query "[?name=='aks-dev'].resourceGroup | [0]" -o tsv)
fi
```

### 3. 命名規則の標準化

今後のリソース作成時の命名規則：

```
{service}-{project}-{env}-{region}-{instance}

例:
- rg-bbs-cicd-dev-jpe-001
- aks-bbs-cicd-dev-jpe-001
- vm-bbs-mongo-dev-jpe-001
```

---

## 🛠️ トラブルシューティング

### エラー: Context access might be invalid

**症状**:
```
Context access might be invalid: AZURE_RESOURCE_GROUP
```

**原因**: Variables が未設定

**解決方法**: 
1. GitHub Repository > Settings > Secrets and variables > Actions > Variables
2. 必要な変数を追加

---

### エラー: RESOURCE_GROUP is empty

**症状**:
```
Error: Resource group name is empty
```

**原因**: Variables の名前が間違っている

**確認**:
- ワークフロー: `${{ vars.AZURE_RESOURCE_GROUP }}`
- GitHub設定: Variable名が `AZURE_RESOURCE_GROUP` であることを確認

---

### ワークフローが動かない

**症状**: Variables 導入後にワークフローが失敗

**確認項目**:
1. ✅ GitHub で Variables が設定されているか
2. ✅ Variable名がワークフローと一致しているか
3. ✅ 値が正しく入力されているか（typoチェック）

**一時回避策**:
ハードコードに戻して動作確認：

```yaml
env:
    RESOURCE_GROUP: rg-bbs-cicd-aks001  # 直接指定で確認
```

---

## 📚 参考資料

- [GitHub Actions - Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [GitHub Actions - Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Actions - Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)

---

## ✨ まとめ

Phase 18では、ハードコードされた設定値をGitHub Variablesに移行し、以下を達成しました：

1. ✅ **保守性向上**: 設定値の一元管理
2. ✅ **柔軟性向上**: コード変更不要で値を更新可能
3. ✅ **コード品質**: ハードコード解消、ベストプラクティス準拠
4. ✅ **ワークフロー最適化**: 不要なアーティファクトダウンロード削除
5. ✅ **ドキュメント整備**: 詳細な設定ガイド作成

これにより、今後の運用・保守がより効率的になりました。

---

**作業者**: GitHub Copilot  
**レビュー**: ユーザー確認済み  
**ステータス**: ✅ 完了
