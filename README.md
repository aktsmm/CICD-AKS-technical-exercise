# 🧙‍♂️ CICD-AKS-Technical Exercise

クラウド環境を構築し、セキュリティリスクをデモンストレーションするプロジェクト

## 📋 プロジェクト概要

### 構成要素

- **AKS (Azure Kubernetes Service)** - コンテナ化された BBS App
- **VM (MongoDB)** - Ubuntu 20.04 + MongoDB 4.4 データベース
- **ACR (Azure Container Registry)** - Dockerイメージレジストリ
- **Storage Account** - バックアップ用 Blob Storage
- **Azure Monitor** - 監査ログ収集

### 意図的な脆弱性

1. **AKS**: Cluster Admin 権限の不適切な付与
2. **VM**: SSH Port 22 のインターネット公開、古い OS (Ubuntu 20.04)
3. **MongoDB**: 認証なし、全 IP からアクセス可能、古いバージョン (4.4)
4. **Storage**: Public Blob Access 有効

## 🏗️ アーキテクチャ

### システム構成図

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Azure Subscription                         │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Resource Group: rg-cicd-aks                     │   │
│  │                                                               │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  VNet: vnet-wiz-dev (10.0.0.0/16)                    │   │   │
│  │  │                                                        │   │   │
│  │  │  ┌──────────────────────────────────────┐            │   │   │
│  │  │  │ Subnet: aks-subnet (10.0.1.0/24)    │            │   │   │
│  │  │  │                                       │            │   │   │
│  │  │  │  ┌─────────────────────────────┐    │            │   │   │
│  │  │  │  │  AKS: aks-wiz-dev           │    │            │   │   │
│  │  │  │  │  ├─ Node Pool: 2 nodes      │    │            │   │   │
│  │  │  │  │  │  Standard_DS2_v2          │    │            │   │   │
│  │  │  │  │  ├─ Pod: guestbook-app (×2) │    │            │   │   │
│  │  │  │  │  └─ Service: LoadBalancer   │◄───┼─── External IP
│  │  │  │  └─────────────────────────────┘    │            │   │   │
│  │  │  └──────────────────────────────────────┘            │   │   │
│  │  │                                                        │   │   │
│  │  │  ┌──────────────────────────────────────┐            │   │   │
│  │  │  │ Subnet: mongo-subnet (10.0.2.0/24)  │            │   │   │
│  │  │  │                                       │            │   │   │
│  │  │  │  ┌─────────────────────────────┐    │            │   │   │
│  │  │  │  │  VM: vm-mongo-dev           │    │            │   │   │
│  │  │  │  │  ├─ Ubuntu 20.04 LTS        │    │            │   │   │
│  │  │  │  │  ├─ MongoDB 4.4              │◄───┼─── AKS Pods
│  │  │  │  │  ├─ Port 27017 (全開放)     │    │            │   │   │
│  │  │  │  │  └─ Port 22 (SSH公開) ⚠️    │◄───┼─── Internet
│  │  │  │  └─────────────────────────────┘    │            │   │   │
│  │  │  └──────────────────────────────────────┘            │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │                                                               │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  ACR: acrwizdev[hash] (Premium/Basic)                │   │   │
│  │  │  └─ guestbook:latest                                 │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │             ▲                                                │   │
│  │             │ AcrPull Role                                  │   │
│  │             │                                                │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  Storage: stwizdev[hash]                             │   │   │
│  │  │  ├─ Container: backups                               │   │   │
│  │  │  └─ Public Blob Access: Enabled ⚠️                   │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │             ▲                                                │   │
│  │             │ Daily Backup (cron 2:00 AM JST)               │   │
│  │             │                                                │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  Log Analytics: log-wiz-dev                          │   │   │
│  │  │  └─ AKS Audit Logs                                   │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### CI/CD フロー図

```
┌────────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                            │
│                     (aktsmm/CICD-AKS-technical-exercise)           │
└────────────────────────────────────────────────────────────────────┘
                                  │
                    git push (infra/** or app/**)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                              │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  Workflow 1: Deploy Infrastructure                        │    │
│  │  Trigger: infra/** changes                                │    │
│  │  ┌─────────────────────────────────────────────────────┐  │    │
│  │  │  1. Checkov Scan (IaC Security)                     │  │    │
│  │  │     └─ Check Bicep templates                        │  │    │
│  │  └─────────────────────────────────────────────────────┘  │    │
│  │  ┌─────────────────────────────────────────────────────┐  │    │
│  │  │  2. Deploy Azure Resources (Bicep)                  │  │    │
│  │  │     ├─ VNet + Subnets                               │  │    │
│  │  │     ├─ AKS Cluster                                  │  │    │
│  │  │     ├─ ACR (with unique suffix)                     │  │    │
│  │  │     ├─ MongoDB VM + Managed Identity                │  │    │
│  │  │     ├─ Storage Account                              │  │    │
│  │  │     ├─ Log Analytics                                │  │    │
│  │  │     ├─ NSG (SSH + MongoDB public) ⚠️                │  │    │
│  │  │     └─ RBAC (Vulnerable ClusterAdmin) ⚠️            │  │    │
│  │  └─────────────────────────────────────────────────────┘  │    │
│  │  ┌─────────────────────────────────────────────────────┐  │    │
│  │  │  3. Wait for AKS Provisioning                       │  │    │
│  │  │     └─ Poll every 30s (max 15min)                   │  │    │
│  │  └─────────────────────────────────────────────────────┘  │    │
│  │  ┌─────────────────────────────────────────────────────┐  │    │
│  │  │  4. Save Outputs as Artifacts                       │  │    │
│  │  │     ├─ AKS_CLUSTER_NAME                             │  │    │
│  │  │     ├─ ACR_NAME                                     │  │    │
│  │  │     └─ MONGO_VM_IP                                  │  │    │
│  │  └─────────────────────────────────────────────────────┘  │    │
│  └───────────────────────────────────────────────────────┘    │
│                                  │                               │
│                   workflow_run trigger (on success)             │
│                                  ▼                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Workflow 2: Build and Deploy Application                 │  │
│  │  Trigger: app/** changes OR infra success                 │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  1. Check Resource Group Existence                  │  │  │
│  │  │     └─ Fail early if RG not found                   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  2. Trivy Container Scan                            │  │  │
│  │  │     └─ Scan for CVEs (CRITICAL/HIGH)                │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  3. Build & Push Docker Image                       │  │  │
│  │  │     ├─ Build: guestbook:${GITHUB_SHA}               │  │  │
│  │  │     ├─ Push to ACR                                  │  │  │
│  │  │     └─ Tag as :latest                               │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  4. Deploy to AKS                                   │  │  │
│  │  │     ├─ kubectl apply -f k8s/rbac-vulnerable.yaml ⚠️ │  │  │
│  │  │     ├─ kubectl apply -f k8s/deployment.yaml         │  │  │
│  │  │     ├─ kubectl apply -f k8s/service.yaml            │  │  │
│  │  │     └─ Update image: ACR/guestbook:${GITHUB_SHA}    │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Deployed Application                             │
│                                                                      │
│  Browser → http://<EXTERNAL_IP> → LoadBalancer                     │
│                                        └─ AKS Pods (guestbook-app)  │
│                                               └─ MongoDB VM          │
└─────────────────────────────────────────────────────────────────────┘
```

### セキュリティスキャンフロー

```
┌─────────────────────────────────────────────────────────────────┐
│  Code Commit → GitHub Actions                                   │
│                                                                  │
│  ┌───────────────────┐      ┌───────────────────┐             │
│  │  Checkov (IaC)    │      │  Trivy (Container)│             │
│  │  ├─ Bicep Scan    │      │  ├─ Image Scan    │             │
│  │  └─ Misconfig     │      │  └─ CVE Detection │             │
│  └───────────────────┘      └───────────────────┘             │
│           │                           │                         │
│           └───────────┬───────────────┘                         │
│                       ▼                                         │
│              ┌─────────────────┐                                │
│              │  SARIF Upload   │                                │
│              │  to GitHub      │                                │
│              │  Security Tab   │                                │
│              └─────────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
```

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
az group create --name rg-cicd-bbs2 --location japaneast
az acr create `
  --resource-group rg-cicd-bbs2 `
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
git commit -m "Initial commit: CICD-AKS-Technical Exercise"
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
│       ├── service.yaml         # LoadBalancer Service
│       ├── ingress.yaml         # Ingress (App Gateway)
│       ├── ingress-nginx.yaml   # Ingress (NGINX代替)
│       └── rbac-vulnerable.yaml # 脆弱なRBAC設定
├── infra/                       # Infrastructure as Code (Bicep)
│   ├── main.bicep              # メインテンプレート
│   ├── parameters.json         # パラメータ（未使用）
│   ├── scripts/                # VMカスタマイズスクリプト
│   │   └── install-mongodb.sh  # MongoDB 4.4インストール
│   └── modules/                # Bicepモジュール
│       ├── aks.bicep           # AKSクラスター
│       ├── acr.bicep           # Azure Container Registry
│       ├── aks-acr-role.bicep  # AKS-ACR認証設定
│       ├── vm-mongodb.bicep    # MongoDB VM
│       ├── vm-role-assignment.bicep  # VM Managed Identity
│       ├── vm-storage-role.bicep     # VMストレージ権限
│       ├── storage.bicep       # Storage Account
│       ├── networking.bicep    # VNet/Subnet
│       └── monitoring.bicep    # Log Analytics
├── .github/
│   └── workflows/              # GitHub Actions
│       ├── infra-deploy.yml   # インフラデプロイ
│       ├── app-deploy.yml     # アプリデプロイ
│       └── cleanup.yml        # ワークフロー履歴クリーンアップ
├── pipelines/                  # Azure Pipelines（代替CI/CD）
│   ├── azure-pipelines-infra.yml
│   └── azure-pipelines-app.yml
├── docs/                       # ドキュメント
│   ├── ENVIRONMENT_INFO.md    # 環境情報
│   ├── AZURE_SETUP_INFO.md    # Azureセットアップ手順
│   └── MICROSOFT_DOCS_VALIDATION.md
├── Docs_issue_point/          # トラブルシューティング履歴
│   ├── Phase02_アプリデプロイ問題と解決_2025-10-29.md
│   ├── Phase03_kubectl環境設定_2025-10-29.md
│   ├── Phase04_MongoDBバックアップ実装_2025-10-29.md
│   ├── Phase06_ワークフロー依存関係実装_2025-10-29.md
│   ├── Phase07_AKS-ACR認証エラー解決_2025-10-29.md
│   ├── Phase08_AKSプロビジョニング待機実装_2025-10-29.md
│   ├── Phase09_MongoDB4.4インストール修正_2025-10-29.md
│   ├── Phase10_ACR名前衝突解決_2025-10-29.md
│   └── Phase11_外部アクセス設定_2025-10-30.md
└── Docs_work_history/         # 作業履歴

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
  --resource-group rg-cicd-bbs2 `
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
  -g rg-cicd-bbs2 `
  -n vm-mongo-dev `
  --show-details `
  --query publicIps -o tsv

# Deploymentの環境変数を更新
kubectl set env deployment/guestbook-app MONGO_URI="mongodb://<MONGO_IP>:27017/guestbook"
```

## 🧹 リソース削除

```powershell
# すべてのリソースを削除
az group delete --name rg-cicd-bbs2 --yes --no-wait

# サービスプリンシパル削除
$SP_ID = az ad sp list --display-name "sp-wiz-exercise" --query "[0].appId" -o tsv
az ad sp delete --id $SP_ID
```

## 📝 ライセンス

このプロジェクトは CICD-AKS-Technical Exercise のデモ用です。
