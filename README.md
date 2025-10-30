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
2. **VM**: SSH Port 22 のインターネット公開、古い OS (Ubuntu 20.04)、過剰なクラウド権限 (VM 作成可能)
3. **MongoDB**: 古いバージョン (4.4)、認証あり (ただし弱い設定)
4. **Network**: MongoDB へのアクセス制限が不十分 (AKS subnet のみ許可だが、NSG ルールが広範)
5. **Storage**: Public Blob Access 有効 (バックアップが公開閲覧可能)

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
│  │  │  VNet: vnetdev (10.0.0.0/16)                    │   │   │
│  │  │                                                        │   │   │
│  │  │  ┌──────────────────────────────────────┐            │   │   │
│  │  │  │ Subnet: aks-subnet (10.0.1.0/24)    │            │   │   │
│  │  │  │                                       │            │   │   │
│  │  │  │  ┌─────────────────────────────┐    │            │   │   │
│  │  │  │  │  AKS: aks-dev           │    │            │   │   │
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
│  │  │  │  │  VM: <MONGODB_VM_NAME>           │    │            │   │   │
│  │  │  │  │  ├─ Ubuntu 20.04 LTS (古い)  │    │            │   │   │
│  │  │  │  │  ├─ MongoDB 4.4 (古いバージョン) │◄───┼─── AKS Pods (NSG制限あり)
│  │  │  │  │  ├─ Port 27017 (認証あり)   │    │            │   │   │
│  │  │  │  │  ├─ Port 22 (SSH公開) ⚠️    │◄───┼─── Internet
│  │  │  │  │  └─ 過剰なVM権限 ⚠️         │    │            │   │   │
│  │  │  │  └─────────────────────────────┘    │            │   │   │
│  │  │  └──────────────────────────────────────┘            │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │                                                               │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  ACR: <ACR_NAME>[hash] (Premium/Basic)                │   │   │
│  │  │  └─ guestbook:latest                                 │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │             ▲                                                │   │
│  │             │ AcrPull Role                                  │   │
│  │             │                                                │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  Storage: <STORAGE_ACCOUNT_NAME>[hash]                             │   │   │
│  │  │  ├─ Container: backups                               │   │   │
│  │  │  └─ Public Blob Access: Enabled ⚠️                   │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │             ▲                                                │   │
│  │             │ Daily Backup (cron 2:00 AM JST)               │   │
│  │             │                                                │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  Log Analytics: <LOG_ANALYTICS_NAME>                          │   │   │
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

## � 認証アーキテクチャ

このプロジェクトでは、複数の認証メカニズムを組み合わせてセキュアなデプロイを実現しています。

### 認証フロー図

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Runner                             │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  1. Azure Login (Service Principal)                         │   │
│  │     ├─ Client ID (from AZURE_CREDENTIALS)                   │   │
│  │     ├─ Client Secret                                        │   │
│  │     ├─ Tenant ID                                            │   │
│  │     └─ Subscription ID                                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                            ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  2. Deploy Infrastructure (Bicep)                           │   │
│  │     └─ Create Managed Identities                            │   │
│  │        ├─ AKS Kubelet Identity (AcrPull権限)               │   │
│  │        └─ VM System Assigned Identity (Storage権限)        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                            ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  3. ACR Login & Push                                        │   │
│  │     └─ az acr login (Service Principal経由)                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                            ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  4. AKS kubectl Access                                      │   │
│  │     └─ az aks get-credentials (Service Principal経由)      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Runtime Authentication                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  AKS → ACR (Image Pull)                                     │   │
│  │  └─ AKS Kubelet Managed Identity + AcrPull Role            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  VM → Storage Account (Backup Upload)                      │   │
│  │  └─ VM System Assigned Managed Identity                    │   │
│  │     + Storage Blob Data Contributor Role                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  App → MongoDB (Database Access)                            │   │
│  │  └─ MONGO_URI環境変数 (MongoDB接続文字列)                  │   │
│  │     mongodb://<username>:<password>@<VM_IP>:27017/guestbook │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 認証方式の詳細

#### 1. **Service Principal (GitHub Actions → Azure)**

**用途**: CI/CD パイプラインから Azure リソースをデプロイ・管理

**権限**: Contributor (サブスクリプションスコープ)

**作成方法**:

```powershell
az ad sp create-for-rbac \
  --name "spexercise" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
```

**GitHub Secrets に設定**:

- `AZURE_CREDENTIALS`: 生成された JSON 全体

**セキュリティ考慮事項**:

- ✅ 最小権限の原則: Contributor role に制限
- ✅ スコープ制限: 特定サブスクリプションのみ
- ⚠️ 改善案: リソースグループスコープに制限可能

#### 2. **AKS Managed Identity (AKS → ACR)**

**用途**: AKS が ACR からコンテナイメージをプル

**認証方式**: Kubelet Managed Identity + Azure RBAC

**自動構成**: Bicep デプロイ時に自動設定

```bicep
// infra/modules/aks-acr-role.bicep
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksPrincipalId, acrId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
                                            '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

**動作確認**:

```powershell
# AKS Kubelet IdentityのObject ID取得
$KUBELET_ID = az aks show -g <RG_NAME> -n aks-dev \
  --query identityProfile.kubeletidentity.objectId -o tsv

# ACRへのロール割り当て確認
az role assignment list --assignee $KUBELET_ID --scope <ACR_RESOURCE_ID>
```

**利点**:

- ✅ イメージプルシークレット不要
- ✅ 認証情報のローテーション不要
- ✅ Azure RBAC 統合

#### 3. **VM Managed Identity (VM → Storage Account)**

**用途**: MongoDB VM がバックアップを Storage Account にアップロード

**認証方式**: System Assigned Managed Identity + Azure RBAC

**自動構成**: Bicep デプロイ時に自動設定

```bicep
// infra/modules/vm-mongodb.bicep
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  identity: {
    type: 'SystemAssigned'  // Managed Identity有効化
  }
}

// infra/modules/vm-storage-role.bicep
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
                                            'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: vmPrincipalId
  }
}
```

**バックアップスクリプトでの使用**:

```bash
# /usr/local/bin/mongodb-backup.sh (VM内)
az login --identity  # Managed Identityでログイン
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name backups \
  --name "backup-$(date +%Y%m%d-%H%M%S).gz" \
  --file /tmp/backup.gz \
  --auth-mode login  # Azure ADトークン使用
```

**利点**:

- ✅ アクセスキー不要
- ✅ 自動ローテーション
- ✅ 監査ログ統合

#### 4. **MongoDB 認証 (App → MongoDB)**

**用途**: アプリケーションから MongoDB への接続

**認証方式**: Username/Password 認証

**接続文字列**:

```javascript
// Kubernetes Deploymentで環境変数として注入
const MONGO_URI =
  process.env.MONGO_URI ||
  "mongodb://<username>:<password>@<VM_IP>:27017/guestbook";
```

**Kubernetes Secret 管理**:

```yaml
# app/k8s/deployment.yaml
env:
  - name: MONGO_URI
    value: "mongodb://adminuser:<password>@<MONGO_VM_IP>:27017/guestbook"
  - name: MONGO_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mongodb-secret # 推奨: Secret使用
        key: password
```

**⚠️ セキュリティ上の注意**:

- 現在の実装: 環境変数に平文保存 (デモ用)
- 本番推奨: Kubernetes Secrets または Azure Key Vault 使用

#### 5. **kubectl Access (GitHub Actions → AKS)**

**用途**: CI/CD から Kubernetes マニフェストをデプロイ

**認証フロー**:

```yaml
# .github/workflows/app-deploy.yml
- name: Azure Login
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }} # Service Principal

- name: Set AKS Context
  run: |
    az aks get-credentials \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --name aks-dev \
      --overwrite-existing
    # ~/.kube/config に認証情報が保存される
```

**動作原理**:

1. Service Principal で Azure にログイン
2. AKS API 経由で一時的な kubeconfig 取得
3. kubectl が自動的にトークンリフレッシュ

### 認証トラブルシューティング

#### ACR Image Pull エラー

```powershell
# エラー: "Failed to pull image: unauthorized"

# 確認1: Kubelet IdentityのAcrPull権限
$KUBELET_ID = az aks show -g <RG_NAME> -n aks-dev \
  --query identityProfile.kubeletidentity.objectId -o tsv
az role assignment list --assignee $KUBELET_ID

# 確認2: ACRリソースID
$ACR_ID = az acr show -n <ACR_NAME> --query id -o tsv

# 修正: 権限が不足している場合
az role assignment create \
  --assignee $KUBELET_ID \
  --role AcrPull \
  --scope $ACR_ID
```

#### VM Backup Upload エラー

```powershell
# エラー: "AuthorizationPermissionMismatch"

# VM Managed Identity取得
$VM_PRINCIPAL_ID = az vm show -g <RG_NAME> -n <MONGODB_VM_NAME> \
  --query identity.principalId -o tsv

# Storage Account権限確認
az role assignment list --assignee $VM_PRINCIPAL_ID

# 修正: Storage Blob Data Contributor追加
az role assignment create \
  --assignee $VM_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope <STORAGE_ACCOUNT_RESOURCE_ID>
```

## � プレースホルダーと設定箇所

このドキュメントでは、環境非依存にするためプレースホルダーを使用しています。実際の設定箇所は以下の通りです。

### プレースホルダー一覧と設定ファイル

| プレースホルダー         | 説明                         | 設定箇所                                                                                                                           | デフォルト値                       |
| ------------------------ | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `<RESOURCE_GROUP_NAME>`  | リソースグループ名           | `infra/main.bicep` (Line 4)<br>`.github/workflows/infra-deploy.yml` (Line 18)<br>`.github/workflows/app-deploy.yml` (Line 26)      | `rg-bbs-cicd-aks001001`            |
| `<AKS_CLUSTER_NAME>`     | AKS クラスター名             | `infra/modules/aks.bicep` (Line 13)<br>※ `aks${environment}` のパターン                                                            | `aksdev` (environment='dev'の場合) |
| `<ACR_NAME>`             | Azure Container Registry 名  | `infra/modules/acr.bicep`<br>※ `acr${environment}${uniqueString}` のパターン<br>`.github/workflows/app-deploy.yml` (ACR_NAME 変数) | `acrdev` + ハッシュ                |
| `<STORAGE_ACCOUNT_NAME>` | Storage Account 名           | `infra/modules/storage.bicep`<br>※ `stwiz${environment}${uniqueString}` のパターン                                                 | `stwizdev` + ハッシュ              |
| `<MONGODB_VM_NAME>`      | MongoDB 仮想マシン名         | `infra/modules/vm-mongodb.bicep`<br>※ `vm-mongo-${environment}` のパターン                                                         | `vm-mongo-dev`                     |
| `<LOG_ANALYTICS_NAME>`   | Log Analytics Workspace 名   | `infra/modules/log-analytics.bicep`<br>※ `log-${environment}` のパターン                                                           | `log-dev`                          |
| `<SUBNET_AKS_NAME>`      | AKS 用サブネット名           | `infra/modules/vnet.bicep`                                                                                                         | `snet-aks`                         |
| `<SUBNET_VM_NAME>`       | VM 用サブネット名            | `infra/modules/vnet.bicep`                                                                                                         | `snet-vm` または `snet-mongo`      |
| `<VM_NSG_NAME>`          | VM Network Security Group 名 | `infra/modules/vm-mongodb.bicep`                                                                                                   | `vm-mongo-dev-nsg`                 |
| `<VM_PIP_NAME>`          | VM Public IP 名              | `infra/modules/vm-mongodb.bicep`                                                                                                   | `vm-mongo-dev-pip`                 |
| `<VM_NIC_NAME>`          | VM Network Interface 名      | `infra/modules/vm-mongodb.bicep`                                                                                                   | `vm-mongo-dev-nic`                 |
| `<VM_OSDISK_NAME>`       | VM OS Disk 名                | `infra/modules/vm-mongodb.bicep`                                                                                                   | `vm-mongo-dev_OsDisk`              |

### 主要設定ファイルの編集箇所

#### 1. `infra/main.bicep` (リソースグループと Environment)

```bicep
// Line 4: リソースグループ名
param resourceGroupName string = 'rg-bbs-cicd-aks001001'

// Line 10: 環境名 (dev, prod, staging等)
param environment string = 'dev'
```

#### 2. `.github/workflows/infra-deploy.yml` (CI/CD 設定)

```yaml
# Line 18: リソースグループ名
env:
  RESOURCE_GROUP: rg-bbs-cicd-aks001001
```

#### 3. `.github/workflows/app-deploy.yml` (アプリデプロイ設定)

```yaml
# Line 26: リソースグループ名
env:
  RESOURCE_GROUP: rg-bbs-cicd-aks001001
  ACR_NAME: acrdev # Line 27: ACR名
```

#### 4. `infra/modules/aks.bicep` (AKS クラスター名)

```bicep
// Line 13: 動的に生成されるクラスター名
var clusterName = 'aks${environment}'
```

#### 5. `pipelines/azure-pipelines.yml` (Azure Pipelines 使用時)

```yaml
# Line 6: リソースグループ名
variables:
  resourceGroup: "rg-bbs-cicd-aks001001"
```

### 命名規則の説明

このプロジェクトでは以下の命名規則を採用しています:

- **環境別サフィックス**: `${environment}` パラメータで dev/prod/staging を切り替え
- **一意性確保**: Storage/ACR は `uniqueString(resourceGroup().id)` でハッシュを追加
- **リソースタイププレフィックス**: Azure 推奨の命名規則に従う
  - `aks-`: AKS Cluster
  - `acr`: Container Registry
  - `st`: Storage Account
  - `vm-`: Virtual Machine
  - `log-`: Log Analytics
  - `snet-`: Subnet

### カスタマイズ方法

1. **リソースグループ名を変更する場合**:

   - `infra/main.bicep` の `resourceGroupName` パラメータを編集
   - `.github/workflows/*.yml` の `RESOURCE_GROUP` 環境変数を同じ値に更新

2. **環境を切り替える場合** (dev → prod):

   - `infra/main.bicep` の `environment` パラメータを変更
   - すべてのリソース名が自動的に `*prod*` になります

3. **個別リソース名をカスタマイズする場合**:
   - 各モジュールの Bicep ファイル (`infra/modules/*.bicep`) を編集
   - 変数セクション (`var xxxx = '...'`) を変更

## 🚀 クイックスタート

### 前提条件

- **Azure CLI** インストール済み ([インストールガイド](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli))
- **Azure サブスクリプション** (無料試用版可)
- **GitHub アカウント**
- **Git** インストール済み

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
  --name "spexercise" `
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
az aks get-credentials --resource-group <YOUR_RG_NAME> --name aks-dev --overwrite-existing

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
$NSG_NAME = "<MONGODB_VM_NAME>-nsg"
az network nsg rule show `
  --resource-group $RG_NAME `
  --nsg-name $NSG_NAME `
  --name Allow-SSH-Internet

# MongoDB認証なし確認
$MONGO_IP = (az vm show -g $RG_NAME -n <MONGODB_VM_NAME> --show-details --query publicIps -o tsv)
# 認証なしで接続可能 (脆弱性)
mongosh "mongodb://${MONGO_IP}:27017/guestbook"

# Kubernetes RBAC
kubectl get clusterrolebindings developer-cluster-admin -o yaml
```

## 📊 アプリケーションアクセス

### LoadBalancer External IP の取得

```powershell
# AKSクラスター認証情報を取得
az aks get-credentials --resource-group <YOUR_RG_NAME> --name aks-dev --overwrite-existing

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
  -n <MONGODB_VM_NAME> `
  --show-details `
  --query publicIps -o tsv)

# NSG確認 (Port 27017が開いているか)
az network nsg rule list `
  --resource-group <YOUR_RG_NAME> `
  --nsg-name <MONGODB_VM_NAME>-nsg `
  --query "[?destinationPortRange=='27017']"

# Deploymentの環境変数を確認
kubectl get deployment guestbook-app -o yaml | grep MONGO_URI
```

### ACR 認証エラー

```powershell
# AKS Managed IdentityにAcrPull権限があるか確認
$AKS_KUBELET_ID = (az aks show -g <YOUR_RG_NAME> -n aks-dev --query identityProfile.kubeletidentity.objectId -o tsv)
$ACR_ID = (az acr show -g <YOUR_RG_NAME> -n $(az acr list -g <YOUR_RG_NAME> --query "[0].name" -o tsv) --query id -o tsv)

az role assignment list --assignee $AKS_KUBELET_ID --scope $ACR_ID
```

## 🧹 リソース削除

```powershell
# すべてのリソースを削除
az group delete --name <YOUR_RG_NAME> --yes --no-wait

# サービスプリンシパル削除
$SP_ID = (az ad sp list --display-name "spexercise" --query "[0].appId" -o tsv)
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
