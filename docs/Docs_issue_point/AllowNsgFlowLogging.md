# AllowNsgFlowLogging 登録が必要なケースの対処メモ

## 事象概要

- NSG フローログ (`az network watcher flow-log create` など) を有効化しようとした際に、`AllowNsgFlowLogging` フィーチャーが未登録だとエラーになる。
- 事前にフィーチャー登録とプロバイダー再登録を行わないと、CLI/Portal 双方で NSG フローログの有効化が失敗する。

## 再現条件

1. 対象サブスクリプションで `Microsoft.Network` のプレビュー フィーチャー `AllowNsgFlowLogging` が未登録。
2. Network Watcher > NSG フローログ有効化 (または `az network watcher flow-log create`) を実施。
3. `FeatureNotRegistered` などのエラーで処理が中断。

## 対処手順 (PowerShell + Azure CLI)

```powershell
# ==========================================
# 🧩 AllowNsgFlowLogging の有効化確認と登録
# ==========================================

# 1. 対象サブスクリプションを指定
$subscriptionId = "<Your-Subscription-ID>"
az account set --subscription $subscriptionId

# 2. 現在の登録状態を確認
Write-Host "🔍 現在の登録状態を確認中..."
az feature show `
    --namespace Microsoft.Network `
    --name AllowNsgFlowLogging `
    --query "properties.state" `
    --output tsv

# 3. 登録処理（未登録 or Registered でない場合）
Write-Host "⚙️ AllowNsgFlowLogging を登録します..."
az feature register `
    --namespace Microsoft.Network `
    --name AllowNsgFlowLogging

# 4. 反映待ち (2〜5 分程度)
Write-Host "⏳ 登録の反映を待機中...（2〜5分）"
Start-Sleep -Seconds 180

# 5. プロバイダーを再登録
Write-Host "🔁 Microsoft.Network プロバイダーを再登録..."
az provider register --namespace Microsoft.Network

# 6. 状態確認
Write-Host "✅ 現在の登録状態:"
az feature show `
    --namespace Microsoft.Network `
    --name AllowNsgFlowLogging `
    --query "properties.state" `
    --output tsv
```

### 実務 Tip

- 待機時間は `Registered` へ遷移するまで複数回 `az feature show` を確認する。`Registered` が返ってから Flow Log を再実行すれば成功する。
- スクリプトを CI で回す場合は、`az feature show` が `Registered` を返すまでポーリングすると無駄な待機を減らせる。

## 参考情報

- #microsoft.docs.mcp [az feature register | Microsoft Learn](https://learn.microsoft.com/en-us/cli/azure/feature/registration?view=azure-cli-latest) — フィーチャー登録手順
- #microsoft.docs.mcp [Flow logging for network security groups](https://learn.microsoft.com/en-us/azure/network-watcher/nsg-flow-logs-overview#troubleshooting-common-problems) — NSG フローログ有効化時のトラブルシューティング
