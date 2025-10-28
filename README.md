# 🧙‍♂️ Wiz Technical Exercise

Wiz 社の技術面接課題：意図的に脆弱なクラウド環境を構築し、セキュリティリスクをデモンストレーションするプロジェクト

## 📋 プロジェクト概要

### 構成要素

- **AKS (Azure Kubernetes Service)** - コンテナ化された掲示板アプリ
- **VM (MongoDB)** - Ubuntu 18.04 + MongoDB データベース
- **Storage Account** - バックアップ用 Blob Storage
- **Azure Monitor** - 監査ログ収集

### 意図的な脆弱性

1. **AKS**: Cluster Admin 権限の不適切な付与
2. **VM**: SSH Port 22 のインターネット公開、古い OS
3. **MongoDB**: 認証なし、全 IP からアクセス可能
4. **Storage**: Public Blob Access 有効

## 🚀 クイックスタート

### 前提条件

- Azure CLI インストール済み
- Azure サブスクリプション
- GitHub アカウント
- kubectl, docker インストール済み

### 1️⃣ Azure 認証

```powershell
# Azureにログイン
az login

# サブスクリプションID取得
$SUBSCRIPTION_ID = az account show --query id -o tsv
Write-Host "Subscription ID: $SUBSCRIPTION_ID"

# サブスクリプションを設定（複数ある場合）
az account set --subscription $SUBSCRIPTION_ID
```

### 2️⃣ サービスプリンシパル作成

```powershell
# Service Principal作成（GitHub Actions用）
$SP_OUTPUT = az ad sp create-for-rbac `
  --name "sp-wiz-exercise" `
  --role Contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID" `
  --sdk-auth

# JSONをファイルに保存
$SP_OUTPUT | Out-File -FilePath "azure-credentials.json" -Encoding utf8

# 確認
Write-Host "Service Principal JSON saved to: azure-credentials.json"
Get-Content "azure-credentials.json"
```

### 3️⃣ ACR 作成（手動、必須）

```powershell
# リソースグループ作成
az group create `
  --name "rg-wiz-exercise" `
  --location "japaneast"

# Azure Container Registry作成
az acr create `
  --resource-group "rg-wiz-exercise" `
  --name "acrwizexercise" `
  --sku Standard `
  --location "japaneast"

# 作成確認
az acr list --resource-group "rg-wiz-exercise" -o table
```

### 4️⃣ GitHub シークレット設定

GitHub Repository Settings > Secrets and variables > Actions

- `AZURE_CREDENTIALS`: azure-credentials.json の内容
- `AZURE_SUBSCRIPTION_ID`: サブスクリプション ID
- `MONGO_ADMIN_PASSWORD`: MongoDB 管理者パスワード

### 5️⃣ デプロイ

```powershell
git init
git add .
git commit -m "Initial commit: Wiz Technical Exercise"
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/wiz-technical-exercise.git
git push -u origin main
```

GitHub Actions が自動的にデプロイを開始します。

## 📂 ディレクトリ構造

```
wiz-technical-exercise/
├── app/                          # Node.jsアプリケーション
│   ├── app.js                   # Express.jsサーバー
│   ├── Dockerfile               # コンテナイメージ定義
│   ├── package.json             # 依存関係
│   ├── wizexercise.txt          # デモ用ファイル
│   ├── views/                   # EJSテンプレート
│   │   └── index.ejs           # 掲示板UI
│   └── k8s/                     # Kubernetesマニフェスト
│       ├── deployment.yaml      # アプリデプロイ
│       ├── service.yaml         # Kubernetes Service
│       ├── ingress.yaml         # Ingress (App Gateway)
│       ├── ingress-nginx.yaml   # Ingress (NGINX代替)
│       └── rbac-vulnerable.yaml # 脆弱なRBAC設定
├── infra/                       # Infrastructure as Code (Bicep)
│   ├── main.bicep              # メインテンプレート
│   ├── parameters.json         # パラメータ（未使用）
│   └── modules/                # Bicepモジュール
│       ├── aks.bicep           # AKSクラスター
│       ├── vm-mongodb.bicep    # MongoDB VM
│       ├── storage.bicep       # Storage Account
│       ├── networking.bicep    # VNet/Subnet
│       └── monitoring.bicep    # Log Analytics
└── .github/
    └── workflows/               # GitHub Actions
        ├── infra-deploy.yml    # インフラデプロイ
        └── app-deploy.yml      # アプリデプロイ

```

## 🔐 セキュリティ検証

### 脆弱性確認

```powershell
# 1. Storage Public Access 確認
$STORAGE_NAME = az storage account list `
  --resource-group "rg-wiz-exercise" `
  --query "[0].name" -o tsv

az storage account show `
  --name $STORAGE_NAME `
  --resource-group "rg-wiz-exercise" `
  --query "{PublicAccess:allowBlobPublicAccess, TLS:minimumTlsVersion, HttpsOnly:supportsHttpsTrafficOnly}" `
  -o table

# 2. SSH公開確認
az network nsg rule show `
  --resource-group "rg-wiz-exercise" `
  --nsg-name "nsg-mongo-dev" `
  --name "AllowSSH" `
  --query "{Name:name, Source:sourceAddressPrefix, Port:destinationPortRange, Access:access}" `
  -o table

# 3. MongoDB NSG確認
az network nsg rule show `
  --resource-group "rg-wiz-exercise" `
  --nsg-name "nsg-mongo-dev" `
  --name "AllowMongoDB" `
  --query "{Name:name, Source:sourceAddressPrefix, Port:destinationPortRange}" `
  -o table

# 4. Kubernetes RBAC確認
kubectl get clusterrolebindings developer-cluster-admin -o yaml
```

## 📊 アプリケーションアクセス

### Ingress IP の取得

```powershell
# Application Gateway Ingress使用時
kubectl get ingress guestbook-ingress

# NGINX Ingress使用時
kubectl get svc ingress-nginx-controller -n ingress-nginx

# IPアドレスのみ取得
$INGRESS_IP = kubectl get ingress guestbook-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Application URL: http://$INGRESS_IP"
```

ブラウザでアクセス: `http://<INGRESS_IP>`

### wizexercise.txt 確認

```powershell
# 1. Web経由で確認
$INGRESS_IP = kubectl get ingress guestbook-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Invoke-WebRequest -Uri "http://$INGRESS_IP/wizfile" -UseBasicParsing | Select-Object -ExpandProperty Content

# 2. Pod内で直接確認
$POD_NAME = kubectl get pods -l app=guestbook -o jsonpath='{.items[0].metadata.name}'
kubectl exec $POD_NAME -- cat /app/wizexercise.txt

# 3. すべてのPodで確認
kubectl get pods -l app=guestbook -o jsonpath='{.items[*].metadata.name}' | ForEach-Object {
    $pod = $_
    Write-Host "`n=== Pod: $pod ==="
    kubectl exec $pod -- cat /app/wizexercise.txt
}
```

## 🛠️ トラブルシューティング

### Ingress が動作しない

```powershell
# NGINX Ingress Controller インストール
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# NGINX版Ingressに切り替え
kubectl delete ingress guestbook-ingress
kubectl apply -f app/k8s/ingress-nginx.yaml
```

### MongoDB に接続できない

```powershell
# 1. VM IPアドレス確認
$MONGO_IP = az vm list-ip-addresses `
  --resource-group "rg-wiz-exercise" `
  --name "vm-mongo-dev" `
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" `
  -o tsv

Write-Host "MongoDB VM IP: $MONGO_IP"

# 2. MongoDB接続テスト (Podから)
$POD_NAME = kubectl get pods -l app=guestbook -o jsonpath='{.items[0].metadata.name}'
kubectl exec $POD_NAME -- nc -zv $MONGO_IP 27017

# 3. Deploymentの環境変数を更新
kubectl set env deployment/guestbook-app MONGO_URI="mongodb://${MONGO_IP}:27017/guestbook"

# 4. 再起動を待つ
kubectl rollout status deployment/guestbook-app
```

## 🧹 リソース削除

```powershell
# 1. リソースグループ内のリソース確認
az resource list --resource-group "rg-wiz-exercise" -o table

# 2. すべてのAzureリソースを削除
Write-Host "Deleting resource group: rg-wiz-exercise..."
az group delete `
  --name "rg-wiz-exercise" `
  --yes `
  --no-wait

# 3. 削除状態を確認
az group list --query "[?name=='rg-wiz-exercise']" -o table

# 4. Service Principal削除
$SP_ID = az ad sp list `
  --display-name "sp-wiz-exercise" `
  --query "[0].appId" `
  -o tsv

if ($SP_ID) {
    Write-Host "Deleting Service Principal: $SP_ID"
    az ad sp delete --id $SP_ID
    Write-Host "Service Principal deleted successfully"
} else {
    Write-Host "Service Principal not found"
}

# 5. ローカルファイル削除（オプション）
if (Test-Path "azure-credentials.json") {
    Remove-Item "azure-credentials.json" -Force
    Write-Host "azure-credentials.json deleted"
}
```

## 📝 ライセンス

このプロジェクトは Wiz Technical Exercise のデモ用です。
