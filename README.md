# 🧙‍♂️ CICD-AKS-Technical Exercise

クラウド環境を構築し、セキュリティリスクをデモンストレーションするプロジェクト

## 📋 プロジェクト概要

### 構成要素

- **AKS (Azure Kubernetes Service)** - コンテナ化された BBS App
- **VM (MongoDB)** - Ubuntu 20.04 + MongoDB 4.4 データベース
- **ACR (Azure Container Registry)** - Docker イメージレジストリ
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
│  │              Resource Group: <YOUR_RG_NAME>                  │   │
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

- **Azure CLI** インストール済み ([インストールガイド](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli))
- **Azure サブスクリプション** (無料試用版可)
- **GitHub アカウント**
- **Git** インストール済み

> **Note**: このREADMEでは `<YOUR_RG_NAME>` をリソースグループ名のプレースホルダーとして使用しています。
> 実際のリソースグループ名は `infra/main.bicep` の `targetScope` と `rg` モジュールで定義されています。
> デフォルト: `rg-cicd-aks` (環境によって変更可能)

### 1️⃣ リポジトリのフォーク

このリポジトリを自分の GitHub アカウントにフォークします。

### 2️⃣ Azure 認証

```powershell
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 3️⃣ サービスプリンシパル作成

```powershell
az ad sp create-for-rbac `
  --name "sp-wiz-exercise" `
  --role contributor `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> `
  --sdk-auth > azure-credentials.json
```

生成された `azure-credentials.json` の内容をコピーします。

### 4️⃣ GitHub シークレット設定

フォークしたリポジトリで: **Settings** > **Secrets and variables** > **Actions** > **New repository secret**

| Secret 名               | 値                                      |
| ----------------------- | --------------------------------------- |
| `AZURE_CREDENTIALS`     | azure-credentials.json の内容全体       |
| `AZURE_SUBSCRIPTION_ID` | Azure サブスクリプション ID             |
| `MONGO_ADMIN_PASSWORD`  | MongoDB 管理者パスワード (任意の文字列) |

### 5️⃣ ワークフロー実行

**Actions** タブ > **Deploy Infrastructure** > **Run workflow** をクリック

または、コードを変更して push:

```powershell
git clone https://github.com/<YOUR_USERNAME>/CICD-AKS-technical-exercise.git
cd CICD-AKS-technical-exercise

# 任意の変更を加える
git add .
git commit -m "Trigger deployment"
git push
```

GitHub Actions が自動的に:

1. **インフラデプロイ** (AKS, ACR, MongoDB VM, Storage など)
2. **アプリケーションデプロイ** (Docker build & push, kubectl apply)

を実行します。デプロイには約**15-20 分**かかります。

### 6️⃣ アプリケーションへアクセス

```powershell
# AKS認証情報取得
az aks get-credentials --resource-group <YOUR_RG_NAME> --name aks-wiz-dev --overwrite-existing

# External IP取得
kubectl get svc guestbook-service -n default
```

ブラウザで `http://<EXTERNAL-IP>` を開きます。

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
# リソースグループ名を設定
$RG_NAME = "<YOUR_RG_NAME>"

# Storage Public Access
$STORAGE_NAME = (az storage account list --resource-group $RG_NAME --query "[0].name" -o tsv)
az storage account show `
  --name $STORAGE_NAME `
  --query allowBlobPublicAccess

# SSH公開確認
$NSG_NAME = "vm-mongo-dev-nsg"
az network nsg rule show `
  --resource-group $RG_NAME `
  --nsg-name $NSG_NAME `
  --name Allow-SSH-Internet

# MongoDB認証なし確認
$MONGO_IP = (az vm show -g $RG_NAME -n vm-mongo-dev --show-details --query publicIps -o tsv)
# 認証なしで接続可能 (脆弱性)
mongosh "mongodb://${MONGO_IP}:27017/guestbook"

# Kubernetes RBAC
kubectl get clusterrolebindings developer-cluster-admin -o yaml
```

## 📊 アプリケーションアクセス

### LoadBalancer External IP の取得

```powershell
# AKSクラスター認証情報を取得
az aks get-credentials --resource-group <YOUR_RG_NAME> --name aks-wiz-dev --overwrite-existing

# External IPを確認
kubectl get svc guestbook-service -n default
```

ブラウザでアクセス: `http://<EXTERNAL-IP>`

### wizexercise.txt 確認

```powershell
# Pod内ファイル確認
$POD_NAME = (kubectl get pods -l app=guestbook -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /app/wizexercise.txt
```

## 🛠️ トラブルシューティング

### LoadBalancer External IP が pending のまま

```powershell
# Service状態確認
kubectl get svc guestbook-service -n default

# AKS LoadBalancer設定確認
kubectl describe svc guestbook-service -n default

# 通常2-3分で割り当て完了
```

### MongoDB に接続できない

```powershell
# VM IPアドレス確認
$MONGO_IP = (az vm show `
  -g <YOUR_RG_NAME> `
  -n vm-mongo-dev `
  --show-details `
  --query publicIps -o tsv)

# NSG確認 (Port 27017が開いているか)
az network nsg rule list `
  --resource-group <YOUR_RG_NAME> `
  --nsg-name vm-mongo-dev-nsg `
  --query "[?destinationPortRange=='27017']"

# Deploymentの環境変数を確認
kubectl get deployment guestbook-app -o yaml | grep MONGO_URI
```

### ACR 認証エラー

```powershell
# AKS Managed IdentityにAcrPull権限があるか確認
$AKS_KUBELET_ID = (az aks show -g <YOUR_RG_NAME> -n aks-wiz-dev --query identityProfile.kubeletidentity.objectId -o tsv)
$ACR_ID = (az acr show -g <YOUR_RG_NAME> -n $(az acr list -g <YOUR_RG_NAME> --query "[0].name" -o tsv) --query id -o tsv)

az role assignment list --assignee $AKS_KUBELET_ID --scope $ACR_ID
```

## 🧹 リソース削除

```powershell
# すべてのリソースを削除
az group delete --name <YOUR_RG_NAME> --yes --no-wait

# サービスプリンシパル削除
$SP_ID = (az ad sp list --display-name "sp-wiz-exercise" --query "[0].appId" -o tsv)
az ad sp delete --id $SP_ID
```

## � 関連ドキュメント

- [環境情報](docs/ENVIRONMENT_INFO.md) - デプロイ環境の詳細
- [トラブルシューティング履歴](Docs_issue_point/) - Phase 02-11 の問題解決記録
- [Azure セットアップ](docs/AZURE_SETUP_INFO.md) - Azure 構成手順

## ⚠️ セキュリティに関する注意

このプロジェクトは**教育目的**で意図的に脆弱性を含んでいます:

- ✅ **デモ環境専用** - 本番環境では使用しないでください
- ✅ **定期的な削除** - 使用後は必ずリソースを削除してください
- ✅ **コスト管理** - AKS/VM 稼働でコストが発生します

## �📝 ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) を参照してください。

## 🤝 コントリビューション

Issue や Pull Request は歓迎します！
