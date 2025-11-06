# Security Monitoring Dashboard - 使用ガイド

## 概要

Log Analytics Workbook を使用したセキュリティ監視ダッシュボードが自動デプロイされます。
このダッシュボードは、Azure Activity Log と Microsoft Defender for Cloud のアラートをリアルタイムで可視化します。

## 自動デプロイ

### ワークフロー統合

`01.infra-deploy.yml` ワークフローが以下を自動実行します:

1. **Bicep デプロイ**: `infra/modules/workbook-security.bicep` が Workbook リソースを作成
2. **出力取得**: Workbook ID と Log Analytics Workspace ID を取得
3. **URL 生成**: Azure Portal 上のダッシュボードへの直接リンクを生成
4. **サマリー出力**: GitHub Actions Summary にダッシュボードリンクを表示

### アクセス方法

#### GitHub Actions から

1. `01.infra-deploy.yml` ワークフローの実行完了後、**Summary** タブを確認
2. 🔗 **Security Dashboard にアクセス** リンクをクリック
3. Azure Portal が開き、ダッシュボードが表示されます

#### Artifact から

1. ワークフロー実行の **Artifacts** セクションから `infra-outputs` をダウンロード
2. `infra-outputs.txt` を開き、`WORKBOOK_URL` の値をコピー
3. ブラウザで URL を開く

#### Azure Portal から直接

1. Azure Portal → **Monitor** → **Workbooks**
2. **Browse** タブを選択
3. サブスクリプションとリソースグループでフィルター
4. 「**Security Dashboard - dev**」を検索して開く

**または、直接リソースにアクセス:**

```
https://portal.azure.com/#@/resource/subscriptions/{subscriptionId}/resourceGroups/rg-bbs-cicd-aks/providers/Microsoft.Insights/workbooks/{workbookId}/overview
```

> **注意**: 古い URL 形式 (`#blade/AppInsightsExtension/UsageNotebookBlade/...`) は使用できません。新しい形式 (`#@/resource/...`) を使用してください。

## ダッシュボード構成

### 📊 表示される情報

#### 1. 過去 24 時間の監査ログ (Administrative & Security)

- **内容**: 管理操作とセキュリティイベントの一覧
- **表示項目**: 操作名、呼び出し元 IP アドレス、カテゴリ、件数
- **用途**: 誰がいつどのような操作を実行したかを追跡

#### 2. 過去 7 日間の Defender アラート

- **内容**: Microsoft Defender for Cloud が検出したセキュリティアラート
- **表示項目**: アラート名、重要度、製品名、件数
- **重要度**: High (🔴), Medium (🟡), Low (🔵) でアイコン表示
- **用途**: セキュリティ脅威の早期検知

#### 3. Azure Policy イベント

- **内容**: 過去 7 日間のポリシー準拠状況
- **表示項目**: 操作名、リソース、イベント数
- **用途**: ガバナンス違反の監視

#### 4. アクティビティタイムライン

- **内容**: 過去 24 時間の時系列アクティビティ
- **表示形式**: 時間軸グラフ（カテゴリ別）
- **用途**: アクティビティのトレンド分析

#### 5. セキュリティ推奨事項 (重要度別)

- **内容**: Defender が提案する改善項目
- **表示形式**: 円グラフ（重要度別分布）
- **用途**: セキュリティ態勢の改善優先順位付け

## 面接デモでの活用

### シナリオ 1: 脆弱性検証後の可視化

```bash
# 1. 脆弱なSSH接続を実行
ssh azureuser@<MONGO_VM_PUBLIC_IP>

# 2. ダッシュボードで確認
# → 「過去24時間の監査ログ」に SSH接続イベントが記録される
# → 呼び出し元IPアドレスが表示される
```

### シナリオ 2: Defender アラートの確認

```bash
# 1. AKSで過剰権限を使用
kubectl get secrets --all-namespaces

# 2. ダッシュボードで確認
# → 「Defender アラート」にKubernetesの異常アクティビティが表示される
# → 重要度 High で🔴アイコン付きで強調表示
```

### シナリオ 3: Policy 違反の監視

```bash
# 1. Azure Policyで拒否された操作を試行
az vm create --resource-group test-rg --name test-vm ...

# 2. ダッシュボードで確認
# → 「Azure Policy イベント」にDeny操作が記録される
# → ポリシー名とリソース名が表示される
```

## デモプレゼンテーション手順

### 1. 導入（30 秒）

「セキュリティ監視を自動化するため、Log Analytics Workbook を IaC で管理しています。」

### 2. 実演（2 分）

1. GitHub Actions Summary から **Security Dashboard** リンクをクリック
2. ダッシュボードが即座に表示されることを確認
3. 各セクションを上から順に説明:
   - 監査ログ: 「過去 24 時間の全管理操作を追跡」
   - Defender アラート: 「脅威検出を重要度別に可視化」
   - Policy イベント: 「ガバナンス準拠をリアルタイム監視」
   - タイムライン: 「アクティビティのトレンドを把握」
   - 推奨事項: 「改善優先度を一目で判断」

### 3. ハイライト（1 分）

- 「このダッシュボードは Bicep で定義され、CI/CD で自動デプロイされます」
- 「コード変更一つで、全環境に統一されたセキュリティ監視を展開できます」
- 「インシデント発生時、このダッシュボードで即座に原因を特定できます」

## カスタマイズ

### クエリの編集

`infra/modules/workbook-security.bicep` の `serializedData` セクションで、各クエリをカスタマイズ可能:

```bicep
query: 'AzureActivity\n| where TimeGenerated > ago(24h)\n...'
```

### 時間範囲の変更

```bicep
timeContext: {
  durationMs: 86400000  // 24時間 = 86400000ms
}
```

### 新しいセクションの追加

`items` 配列に新しいクエリブロックを追加:

```bicep
{
  type: 3
  content: {
    version: 'KqlItem/1.0'
    query: 'YOUR_KUSTO_QUERY'
    title: 'セクションタイトル'
    ...
  }
}
```

## トラブルシューティング

### データが表示されない

**原因**: Log Analytics へのデータ送信に最大 15 分かかる場合があります

**対処**:

1. 診断設定が有効か確認: `infra/main.bicep` の `subscriptionActivityDiagnostics`
2. Defender プランが有効か確認: `infra/main.bicep` の `defenderForCloudPlans`
3. 15 分待機してからダッシュボードを再読み込み

### ワークブックが見つからない

**原因**: デプロイが完了していない

**対処**:

```bash
# デプロイ状態を確認
az deployment sub show \
  --name infra-deployment-XXX \
  --query properties.provisioningState

# ワークブックの存在を確認
az resource list \
  --resource-group rg-bbs-cicd-aks \
  --resource-type Microsoft.Insights/workbooks
```

### クエリエラーが表示される

**原因**: Log Analytics テーブルにデータが未到着

**対処**:

1. Log Analytics Workspace で直接クエリを実行
2. テーブルの存在を確認:
   ```kusto
   AzureActivity | take 1
   SecurityAlert | take 1
   ```

## 参考リンク

- [Azure Workbooks 公式ドキュメント](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)
- [Kusto Query Language (KQL)](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [Log Analytics テーブルリファレンス](https://learn.microsoft.com/azure/azure-monitor/reference/tables/tables-resourcetype)
- [Microsoft Defender for Cloud アラート](https://learn.microsoft.com/azure/defender-for-cloud/alerts-overview)

---

**作成日**: 2025-11-06
**更新日**: 2025-11-06
**バージョン**: 1.0
