# 🧙‍♂️ CICD-AKS-Technical Exercise

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
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 2️⃣ サービスプリンシパル作成

```powershell
az ad sp create-for-rbac `
  --name "sp-wiz-exercise" `
  --role contributor `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> `
  --sdk-auth > azure-credentials.json
```

### 3️⃣ ACR 作成（手動、必須）

```powershell
az group create --name rg-wiz-exercise-001 --location japaneast
az acr create `
  --resource-group rg-wiz-exercise-001 `
  --name acrwizexercise `
  --sku Basic
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
# Storage Public Access
$STORAGE_NAME = "<storage-name>"
az storage account show `
  --name $STORAGE_NAME `
  --query allowBlobPublicAccess

# SSH公開確認
$NSG_NAME = "vm-mongo-dev-nsg"
az network nsg rule show `
  --resource-group rg-wiz-exercise-001 `
  --nsg-name $NSG_NAME `
  --name Allow-SSH-Internet

# Kubernetes RBAC
kubectl get clusterrolebindings developer-cluster-admin -o yaml
```

## 📊 アプリケーションアクセス

### Ingress IP の取得

```powershell
kubectl get ingress guestbook-ingress
# または
kubectl get svc -n ingress-nginx  # NGINX使用時
```

ブラウザでアクセス: `http://<INGRESS_IP>`

### wizexercise.txt 確認

```powershell
# Web経由
curl http://<INGRESS_IP>/wizfile

# Pod内
$POD_NAME = kubectl get pods -l app=guestbook -o jsonpath='{.items[0].metadata.name}'
kubectl exec $POD_NAME -- cat /app/wizexercise.txt
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
# VM IPアドレス確認
az vm show `
  -g rg-wiz-exercise-001 `
  -n vm-mongo-dev `
  --show-details `
  --query publicIps -o tsv

# Deploymentの環境変数を更新
kubectl set env deployment/guestbook-app MONGO_URI="mongodb://<MONGO_IP>:27017/guestbook"
```

## 🧹 リソース削除

```powershell
# すべてのリソースを削除
az group delete --name rg-wiz-exercise-001 --yes --no-wait

# サービスプリンシパル削除
$SP_ID = az ad sp list --display-name "sp-wiz-exercise" --query "[0].appId" -o tsv
az ad sp delete --id $SP_ID
```

## 📝 ライセンス

このプロジェクトは Wiz Technical Exercise のデモ用です。
