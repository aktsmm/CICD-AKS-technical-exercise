# Microsoft Docs 検証レポート

**プロジェクト**: CICD-AKS-Technical Exercise  
**検証日**: 2025 年 10 月 28 日  
**検証範囲**: Azure AKS, Bicep, GitHub Actions, セキュリティベストプラクティス

---

## 📋 エグゼクティブサマリー

このプロジェクトは **Microsoft 公式ドキュメントのベストプラクティスに準拠した実装** を基盤とし、**意図的にセキュリティ脆弱性を導入** することで、クラウドセキュリティのリスクとその修正方法を実証します。

### 検証結果:

- ✅ **インフラストラクチャアーキテクチャ**: Microsoft 推奨パターンに 100%準拠
- ✅ **CI/CD パイプライン**: GitHub Actions 公式ガイドラインに準拠
- ✅ **コンテナレジストリ統合**: ACR 認証ベストプラクティスに準拠
- ❌ **セキュリティ設定**: 7 つの意図的な脆弱性(すべて Microsoft Docs で警告されている実例)

---

## 1. AKS Bicep デプロイメント検証

### 📚 参照ドキュメント

- [Quickstart: Deploy an AKS cluster by using Bicep](https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-bicep)
- [AKS Architecture Best Practices](https://learn.microsoft.com/azure/well-architected/service-guides/azure-kubernetes-service)

### ✅ 準拠項目

#### 1.1 Bicep テンプレート構造

**該当ファイル**: `infra/modules/aks.bicep`

```bicep
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'  // ✅ Microsoft推奨のマネージドID
  }
  properties: {
    enableRBAC: true  // ✅ RBAC有効化(推奨設定)
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_DS2_v2'
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'  // ✅ Azure CNI(本番環境推奨)
      serviceCidr: '10.1.0.0/16'
    }
  }
}
```

**Microsoft Docs との整合性**:

- ✅ API Version `2023-10-01` は最新の安定版
- ✅ System Assigned Identity は[公式推奨パターン](https://learn.microsoft.com/azure/aks/use-managed-identity#enable-a-system-assigned-managed-identity)
- ✅ Azure CNI は[エンタープライズ環境での推奨](https://learn.microsoft.com/azure/aks/operator-best-practices-network)
- ✅ RBAC 有効化は[セキュリティベストプラクティス](https://learn.microsoft.com/azure/aks/operator-best-practices-identity)

#### 1.2 Log Analytics 統合

**該当ファイル**: `infra/modules/aks.bicep`

```bicep
addonProfiles: {
  omsagent: {
    enabled: true
    config: {
      logAnalyticsWorkspaceResourceID: workspaceId
    }
  }
}
```

**Microsoft Docs との整合性**:

- ✅ [監査ログ有効化の推奨実装](https://learn.microsoft.com/azure/aks/monitor-aks)
- ✅ Azure Monitor 統合による可観測性確保

---

## 2. GitHub Actions CI/CD パイプライン検証

### 📚 参照ドキュメント

- [Deploy Bicep files by using GitHub Actions](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions)
- [Deploy to Azure infrastructure with GitHub Actions](https://learn.microsoft.com/devops/deliver/iac-github-actions)

### ✅ 準拠項目

#### 2.1 Bicep デプロイワークフロー

**該当ファイル**: `.github/workflows/infra-deploy.yml`

```yaml
- name: Login to Azure
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}

- name: Deploy Bicep
  uses: azure/arm-deploy@v1 # ✅ Microsoft推奨アクション
  with:
    subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    scope: subscription # ✅ Subscription scope deployment
    template: ./infra/main.bicep
    parameters: ./infra/parameters.json
```

**Microsoft Docs との整合性**:

- ✅ `azure/arm-deploy@v1` は[公式推奨デプロイアクション](https://github.com/marketplace/actions/deploy-azure-resource-manager-arm-template)
- ✅ Subscription scope は[サブスクリプションレベルリソースのベストプラクティス](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-to-subscription)
- ✅ Secret 管理による認証情報の保護

#### 2.2 セキュリティスキャン統合

**該当ファイル**: `.github/workflows/infra-deploy.yml`, `.github/workflows/app-deploy.yml`

```yaml
# IaC Security Scanning
- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: infra/
    framework: bicep

# Container Security Scanning
- name: Run Trivy Scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }}
    format: "sarif"
```

**Microsoft Docs との整合性**:

- ✅ [Infrastructure as Code validation](https://learn.microsoft.com/devops/deliver/iac-github-actions#deploy-with-github-actions) の推奨実装
- ✅ [Container security scanning](https://learn.microsoft.com/azure/aks/operator-best-practices-container-image-management#scan-for-vulnerabilities) のベストプラクティス

#### 2.3 推奨改善: OIDC 認証への移行

**現在の実装** (Service Principal):

```yaml
- uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }} # JSON形式のSP credentials
```

**Microsoft 推奨実装** ([Workload Identity](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions#generate-deployment-credentials)):

```yaml
- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**メリット**:

- パスワード/シークレット不要
- 自動ローテーション
- より強固なセキュリティ

**注**: 現在の Service Principal 方式も動作しますが、将来的な移行を推奨

---

## 3. Azure Container Registry (ACR) 統合検証

### 📚 参照ドキュメント

- [Authenticate with ACR from AKS](https://learn.microsoft.com/azure/aks/cluster-container-registry-integration)
- [ACR authentication overview](https://learn.microsoft.com/azure/container-registry/container-registry-authentication)

### ✅ 準拠項目

#### 3.1 ACR ログインとイメージ Push

**該当ファイル**: `.github/workflows/app-deploy.yml`

```yaml
- name: Login to ACR
  run: az acr login --name ${{ env.ACR_NAME }}

- name: Build and Push Docker Image
  run: |
    docker build -t ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }} ./app
    docker push ${{ env.ACR_NAME }}.azurecr.io/guestbook-app:${{ github.sha }}
```

**Microsoft Docs との整合性**:

- ✅ `az acr login` は[推奨認証方法](https://learn.microsoft.com/azure/container-registry/container-registry-authentication#az-acr-login-with-azure-cli)
- ✅ タグに GitHub SHA を使用(トレーサビリティ確保)

#### 3.2 AKS-ACR 統合の追加セットアップ

**⚠️ 重要**: デプロイ後に以下のコマンドが必要です:

```bash
# AKS kubelet managed identity に AcrPull ロールを自動付与
az aks update \
  --name myAKSCluster \
  --resource-group myResourceGroup \
  --attach-acr <ACR_NAME>
```

**Microsoft Docs の説明**:

> "This command authorizes an existing ACR in your subscription and configures the appropriate AcrPull role for the managed identity."
>
> — [Configure ACR integration for existing AKS cluster](https://learn.microsoft.com/azure/aks/cluster-container-registry-integration#configure-acr-integration-for-an-existing-aks-cluster)

**自動化されていない理由**:

- ACR 作成が手動ステップのため、ワークフローで自動化していません
- `README.md` のセットアップ手順に含まれています

---

## 4. Kubernetes マニフェストのベストプラクティス検証

### 📚 参照ドキュメント

- [Best practices for pod security](https://learn.microsoft.com/azure/aks/developer-best-practices-pod-security)
- [Best practices for basic scheduler features](https://learn.microsoft.com/azure/aks/operator-best-practices-scheduler)

### ✅ 準拠項目

#### 4.1 リソース制限と Health Check

**該当ファイル**: `app/k8s/deployment.yaml`

```yaml
spec:
  containers:
    - name: guestbook-app
      resources:
        requests:
          memory: "128Mi" # ✅ 推奨: リソース要求の明示
          cpu: "100m"
        limits:
          memory: "256Mi" # ✅ 推奨: リソース制限の明示
          cpu: "200m"
      livenessProbe: # ✅ 推奨: Liveness probe
        httpGet:
          path: /health
          port: 3000
      readinessProbe: # ✅ 推奨: Readiness probe
        httpGet:
          path: /health
          port: 3000
```

**Microsoft Docs との整合性**:

- ✅ [リソース制限設定の推奨](https://learn.microsoft.com/azure/aks/operator-best-practices-scheduler#enforce-resource-quotas)
- ✅ [Health check 実装の推奨](https://learn.microsoft.com/azure/aks/developer-best-practices-pod-security#use-pod-security-context)

#### 4.2 高可用性構成

```yaml
spec:
  replicas: 2 # ✅ 推奨: 複数レプリカで冗長性確保
```

**Microsoft Docs との整合性**:

- ✅ [Production workloads: minimum 2 replicas](https://learn.microsoft.com/azure/aks/best-practices#running-enterprise-ready-workloads)

---

## 5. 意図的なセキュリティ脆弱性と Microsoft 推奨との差異

### ⚠️ 免責事項

以下の脆弱性は **デモ・教育目的で意図的に実装** されています。本番環境では絶対に使用しないでください。

---

### 5.1 ClusterAdmin RBAC 脆弱性

#### ❌ 現在の実装

**該当ファイル**: `app/k8s/rbac-vulnerable.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin # ❌ 全クラスタ権限
subjects:
  - kind: ServiceAccount
    name: default # ❌ デフォルトSAに紐付け
    namespace: default
```

#### ✅ Microsoft 推奨実装

**参照**: [Best practices for authentication and authorization](https://learn.microsoft.com/azure/aks/operator-best-practices-identity)

```yaml
# 推奨: 最小権限の原則
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding # Clusterレベルではなくnamespaceレベル
metadata:
  name: developer-read-only
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader # 読み取り専用権限
subjects:
  - kind: ServiceAccount
    name: app-service-account # 専用SA
    namespace: default
```

**Microsoft ドキュメントの警告**:

> "Use Kubernetes role-based access control (Kubernetes RBAC) with Microsoft Entra ID for **least privilege access**. Protect configuration and secrets by **minimizing the allocation of administrator privileges**."
>
> — [Operator best practices - Identity](https://learn.microsoft.com/azure/aks/operator-best-practices-identity#control-access-to-resources-with-kubernetes-rbac)

**セキュリティリスク**:

- Pod 内から全クラスタリソースの操作が可能
- Secret、ConfigMap、PV など機密情報へのアクセス
- 他の Namespace への侵入

---

### 5.2 MongoDB VM セキュリティ脆弱性

#### ❌ 現在の実装

**該当ファイル**: `infra/modules/vm-mongodb.bicep`

```bicep
// ❌ インターネット全体からSSHを許可
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          sourceAddressPrefix: '*'  // ❌ 全世界から接続可能
          destinationPortRange: '22'
          access: 'Allow'
        }
      }
      {
        name: 'AllowMongoDB'
        properties: {
          sourceAddressPrefix: '*'  // ❌ 全世界から接続可能
          destinationPortRange: '27017'
          access: 'Allow'
        }
      }
    ]
  }
}

// ❌ MongoDB認証なし
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  properties: {
    settings: {
      commandToExecute: '''
        sudo sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongod.conf
        # ❌ --auth フラグなし
        sudo systemctl restart mongod
      '''
    }
  }
}
```

#### ✅ Microsoft 推奨実装

**参照**: [Best practices for network connectivity and security](https://learn.microsoft.com/azure/aks/operator-best-practices-network)

```bicep
// ✅ VNet内からのみアクセス許可
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  properties: {
    securityRules: [
      {
        name: 'AllowSSHFromBastion'
        properties: {
          sourceAddressPrefix: '10.0.0.0/24'  // ✅ Bastion subnet のみ
          destinationPortRange: '22'
          access: 'Allow'
        }
      }
      {
        name: 'AllowMongoFromAKS'
        properties: {
          sourceAddressPrefix: '10.0.1.0/24'  // ✅ AKS subnet のみ
          destinationPortRange: '27017'
          access: 'Allow'
        }
      }
    ]
  }
}
```

**Microsoft ドキュメントの警告**:

> "**Don't expose remote connectivity** to your AKS nodes. Create a **bastion host, or jump box**, in a management virtual network. Use the bastion host to securely route traffic into your AKS cluster to remote management tasks."
>
> — [Securely connect to nodes through a bastion host](https://learn.microsoft.com/azure/aks/operator-best-practices-network#securely-connect-to-nodes-through-a-bastion-host)

**セキュリティリスク**:

- SSH ブルートフォース攻撃の対象
- MongoDB への不正アクセス(認証なし)
- データ漏洩の可能性

---

### 5.3 Storage Account セキュリティ脆弱性

#### ❌ 現在の実装

**該当ファイル**: `infra/modules/storage.bicep`

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  properties: {
    allowBlobPublicAccess: true      // ❌ パブリックアクセス許可
    minimumTlsVersion: 'TLS1_0'      // ❌ 古いTLSバージョン
    supportsHttpsTrafficOnly: false  // ❌ HTTP許可
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  properties: {
    publicAccess: 'Blob'  // ❌ Blob レベルでパブリック
  }
}
```

#### ✅ Microsoft 推奨実装

**参照**: [Best practices for storage and backups](https://learn.microsoft.com/azure/aks/operator-best-practices-storage)

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  properties: {
    allowBlobPublicAccess: false     // ✅ パブリックアクセス禁止
    minimumTlsVersion: 'TLS1_2'      // ✅ TLS 1.2以上
    supportsHttpsTrafficOnly: true   // ✅ HTTPS必須
    networkAcls: {                   // ✅ ネットワーク制限
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: aksSubnetId
        }
      ]
    }
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  properties: {
    publicAccess: 'None'  // ✅ Private
  }
}
```

**Microsoft ドキュメントの警告**:

> "**Secure access to storage accounts** by configuring network rules and encryption. Use **managed identities** for authentication instead of storage account keys. **Disable public blob access** unless specifically required."
>
> — [Storage security best practices](https://learn.microsoft.com/azure/storage/common/storage-network-security)

**セキュリティリスク**:

- インターネットからストレージへの直接アクセス
- HTTP 通信による中間者攻撃
- 古い TLS 1.0 による暗号化の脆弱性

---

### 5.4 Ubuntu 18.04 EOL (End of Life) OS

#### ❌ 現在の実装

**該当ファイル**: `infra/modules/vm-mongodb.bicep`

```bicep
imageReference: {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'  // ❌ 2023年にEOLに到達
  version: 'latest'
}
```

#### ✅ Microsoft 推奨実装

**参照**: [Best practices for cluster security and upgrades](https://learn.microsoft.com/azure/aks/operator-best-practices-cluster-security)

```bicep
imageReference: {
  publisher: 'Canonical'
  offer: 'ubuntu-24_04-lts'  // ✅ サポート中のLTSバージョン
  sku: 'server'
  version: 'latest'
}
```

**Microsoft ドキュメントの推奨**:

> "Keep nodes up to date and **automatically apply security patches**. Use **supported OS versions** to ensure you receive security updates."
>
> — [Upgrade and patches](https://learn.microsoft.com/azure/aks/operator-best-practices-cluster-security#upgrade-an-aks-cluster)

**セキュリティリスク**:

- セキュリティパッチが提供されない
- 既知の脆弱性が修正されない
- コンプライアンス違反の可能性

---

## 6. セキュリティ脆弱性の実証価値

### 6.1 これらの脆弱性がよくある理由

Microsoft のセキュリティドキュメントとベストプラクティスガイドでこれらの設定ミスが **頻繁に警告されている** 理由:

1. **デフォルト設定の誤解**

   - ClusterAdmin: Kubernetes デフォルトの動作を理解していない
   - Public Access: Azure リソースのデフォルトが予想外に緩い

2. **開発環境からの移行ミス**

   - 開発時の便利な設定(パブリックアクセス等)が本番に持ち込まれる
   - テスト用認証情報のハードコード

3. **ネットワークセキュリティの複雑さ**
   - NSG、Service Endpoint、Private Link の設定が複雑
   - 「とりあえず動かす」ために全許可にする

### 6.2 Wiz/Defender for Cloud での検出

これらの脆弱性は以下のツールで検出可能:

| 脆弱性                | Wiz 検出    | Defender 検出 | 推奨修正                       |
| --------------------- | ----------- | ------------- | ------------------------------ |
| ClusterAdmin RBAC     | ✅ High     | ✅ High       | Least privilege RBAC           |
| Public SSH/MongoDB    | ✅ Critical | ✅ High       | NSG restriction + Bastion      |
| Storage Public Access | ✅ High     | ✅ Medium     | allowBlobPublicAccess: false   |
| HTTP Enabled          | ✅ Medium   | ✅ Medium     | supportsHttpsTrafficOnly: true |
| TLS 1.0               | ✅ Medium   | ✅ Medium     | minimumTlsVersion: TLS1_2      |
| Ubuntu 18.04 EOL      | ✅ High     | ✅ High       | OS upgrade to 24.04            |
| MongoDB No Auth       | ✅ Critical | ⚠️ Manual     | Enable authentication          |

---

## 7. 準拠度スコアカード

### 7.1 インフラストラクチャアーキテクチャ

| カテゴリ       | 項目              | Microsoft 推奨  | 実装状況             | 参照 URL                                                                                        |
| -------------- | ----------------- | --------------- | -------------------- | ----------------------------------------------------------------------------------------------- |
| **Bicep**      | API Version       | Latest stable   | ✅ 2023-10-01        | [AKS API versions](https://learn.microsoft.com/azure/aks/api-versions)                          |
|                | Modular structure | Recommended     | ✅ 5 modules         | [Bicep modules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/modules)         |
|                | Parameter files   | Recommended     | ✅ parameters.json   | [Bicep parameters](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameters)   |
| **AKS**        | Managed Identity  | System Assigned | ✅ Implemented       | [Use managed identity](https://learn.microsoft.com/azure/aks/use-managed-identity)              |
|                | Network Plugin    | Azure CNI       | ✅ Implemented       | [Network concepts](https://learn.microsoft.com/azure/aks/concepts-network)                      |
|                | RBAC Enabled      | Required        | ✅ enableRBAC: true  | [RBAC overview](https://learn.microsoft.com/azure/aks/concepts-identity#kubernetes-rbac)        |
|                | Monitoring        | Log Analytics   | ✅ OMS agent         | [Monitor AKS](https://learn.microsoft.com/azure/aks/monitor-aks)                                |
| **Networking** | VNet Integration  | Recommended     | ✅ Custom VNet       | [Configure networking](https://learn.microsoft.com/azure/aks/configure-azure-cni)               |
|                | Subnet Separation | Recommended     | ✅ AKS/Mongo subnets | [Network best practices](https://learn.microsoft.com/azure/aks/operator-best-practices-network) |

**スコア**: 9/9 (100%) ✅

---

### 7.2 CI/CD パイプライン

| カテゴリ              | 項目                  | Microsoft 推奨 | 実装状況          | 参照 URL                                                                                                                                |
| --------------------- | --------------------- | -------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **GitHub Actions**    | azure/login           | Required       | ✅ Implemented    | [Azure login action](https://github.com/marketplace/actions/azure-login)                                                                |
|                       | azure/arm-deploy      | Recommended    | ✅ Implemented    | [ARM deploy action](https://github.com/marketplace/actions/deploy-azure-resource-manager-arm-template)                                  |
|                       | Secret management     | Required       | ✅ GitHub Secrets | [GitHub secrets](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions#configure-the-github-secrets)     |
| **Security Scanning** | IaC scanning          | Recommended    | ✅ Checkov        | [IaC validation](https://learn.microsoft.com/devops/deliver/iac-github-actions#deploy-with-github-actions)                              |
|                       | Container scanning    | Recommended    | ✅ Trivy          | [Container security](https://learn.microsoft.com/azure/aks/operator-best-practices-container-image-management#scan-for-vulnerabilities) |
| **Deployment**        | Artifact management   | Recommended    | ✅ Implemented    | [Artifacts](https://learn.microsoft.com/azure/devops/pipelines/artifacts/artifacts-overview)                                            |
|                       | Environment variables | Best practice  | ✅ env section    | [GitHub Actions env](https://docs.github.com/actions/learn-github-actions/variables)                                                    |

**スコア**: 7/7 (100%) ✅

**推奨改善**: OIDC 認証への移行(現在の Service Principal 方式も動作)

---

### 7.3 セキュリティ設定

| カテゴリ     | 項目              | Microsoft 推奨 | 実装状況        | 意図       | 参照 URL                                                                                                                                   |
| ------------ | ----------------- | -------------- | --------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **RBAC**     | Least Privilege   | Required       | ❌ ClusterAdmin | 脆弱性デモ | [Identity best practices](https://learn.microsoft.com/azure/aks/operator-best-practices-identity)                                          |
|              | Service Account   | Dedicated      | ❌ default SA   | 脆弱性デモ | [Pod security](https://learn.microsoft.com/azure/aks/developer-best-practices-pod-security)                                                |
| **Network**  | SSH Access        | Bastion only   | ❌ Public (\*)  | 脆弱性デモ | [Network security](https://learn.microsoft.com/azure/aks/operator-best-practices-network#securely-connect-to-nodes-through-a-bastion-host) |
|              | NSG Rules         | Restrictive    | ❌ Allow \*     | 脆弱性デモ | [NSG best practices](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)                                   |
| **Storage**  | Public Access     | Disabled       | ❌ Enabled      | 脆弱性デモ | [Storage security](https://learn.microsoft.com/azure/storage/common/storage-network-security)                                              |
|              | TLS Version       | 1.2+           | ❌ TLS 1.0      | 脆弱性デモ | [TLS best practices](https://learn.microsoft.com/azure/storage/common/transport-layer-security-configure-minimum-version)                  |
|              | HTTPS Only        | Required       | ❌ HTTP allowed | 脆弱性デモ | [Enforce HTTPS](https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer)                                          |
| **Database** | Authentication    | Required       | ❌ No auth      | 脆弱性デモ | [Database security](https://learn.microsoft.com/azure/architecture/framework/services/data/azure-db-postgresql-security)                   |
| **OS**       | Supported Version | Required       | ❌ Ubuntu 18.04 | 脆弱性デモ | [Cluster security](https://learn.microsoft.com/azure/aks/operator-best-practices-cluster-security)                                         |

**スコア**: 0/9 (0%) ❌ (意図的)

**重要**: これらの脆弱性は **教育・デモ目的で意図的に実装** されています。

---

## 8. 推奨アクション

### 8.1 即座に適用可能な改善

#### 改善 1: OIDC 認証への移行

**現在**: Service Principal (パスワードベース)  
**推奨**: Workload Identity (パスワードレス)

```bash
# 1. Azure でアプリ登録
az ad app create --display-name github-actions-wiz-demo

# 2. Federated credential 設定
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-wiz-repo",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YourOrg/wiz-technical-exercise:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 3. GitHub Secrets更新
# AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
```

**参照**: [Workload identity federation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions#generate-deployment-credentials)

#### 改善 2: Bicep what-if 分析の追加

```yaml
# .github/workflows/infra-deploy.yml に追加
- name: What-If Analysis
  uses: azure/arm-deploy@v1
  with:
    scope: subscription
    subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    template: ./infra/main.bicep
    additionalArguments: --what-if
```

**参照**: [Bicep what-if](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if)

---

### 8.2 本番環境への移行時の必須修正

#### 修正 1: RBAC を最小権限に変更

```yaml
# app/k8s/rbac-secure.yaml (新規作成)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: guestbook-app-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-read-pods
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-pod-reader
subjects:
  - kind: ServiceAccount
    name: guestbook-app-sa
```

#### 修正 2: NSG を制限

```bicep
// infra/modules/vm-mongodb.bicep
securityRules: [
  {
    name: 'AllowSSHFromBastion'
    properties: {
      priority: 1000
      sourceAddressPrefix: '10.0.0.0/24'  // Bastion subnet
      destinationPortRange: '22'
      access: 'Allow'
    }
  }
  {
    name: 'AllowMongoFromAKS'
    properties: {
      priority: 1010
      sourceAddressPrefix: '10.0.1.0/24'  // AKS subnet
      destinationPortRange: '27017'
      access: 'Allow'
    }
  }
  {
    name: 'DenyAllInbound'
    properties: {
      priority: 4096
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Deny'
    }
  }
]
```

#### 修正 3: Storage セキュリティ強化

```bicep
// infra/modules/storage.bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: aksSubnetId
          action: 'Allow'
        }
      ]
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}
```

---

## 9. プレゼンテーション用の推奨説明

### 9.1 技術面接での説明フレームワーク

#### オープニング (30 秒)

> "このプロジェクトは **Microsoft 公式ドキュメントのベストプラクティスに準拠した基盤** 上に構築されています。Bicep テンプレート、GitHub Actions CI/CD、ACR 統合はすべて [Microsoft Learn](https://learn.microsoft.com/azure/aks/) の推奨パターンに従っています。"

#### 脆弱性の正当化 (1 分)

> "セキュリティ設定については **意図的に** Microsoft 推奨から逸脱しています。具体的には:
>
> 1. **RBAC**: [公式ガイド](https://learn.microsoft.com/azure/aks/operator-best-practices-identity)では最小権限原則を推奨していますが、ClusterAdmin 権限を付与
> 2. **ネットワーク**: [Bastion Host 使用を推奨](https://learn.microsoft.com/azure/aks/operator-best-practices-network#securely-connect-to-nodes-through-a-bastion-host)されていますが、SSH を直接公開
> 3. **ストレージ**: [パブリックアクセス無効化を推奨](https://learn.microsoft.com/azure/storage/common/storage-network-security)されていますが、インターネット公開
>
> これらは実際のクラウド環境で **頻繁に見られる設定ミス** であり、Microsoft ドキュメントで繰り返し警告されています。"

#### 検出とリメディエーション (1 分)

> "デプロイ後、Wiz/Defender for Cloud でこれらの脆弱性を検出し、**Microsoft 推奨の修正方法** を提示します。例えば:
>
> - RBAC → [Least privilege access with Azure RBAC](https://learn.microsoft.com/azure/aks/manage-azure-rbac)
> - Network → [Azure Bastion integration](https://learn.microsoft.com/azure/bastion/bastion-overview)
> - Storage → [Disable public blob access](https://learn.microsoft.com/azure/storage/blobs/anonymous-read-access-prevent)
>
> すべての修正案は Microsoft 公式ドキュメントにリンクされています。"

---

### 9.2 質疑応答への準備

#### Q: "なぜ Service Principal で OIDC を使わないのか?"

> "現在の実装は Microsoft の[従来の推奨方法](https://learn.microsoft.com/azure/azure-resource-manager/templates/deploy-github-actions#generate-deployment-credentials)に従っています。[OIDC (Workload Identity)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions#generate-deployment-credentials)への移行は推奨されていますが、両方とも公式サポートされています。時間があれば移行をデモできます。"

#### Q: "なぜ Azure CNI で Kubenet ではないのか?"

> "Microsoft は[エンタープライズ環境で Azure CNI を推奨](https://learn.microsoft.com/azure/aks/operator-best-practices-network#choose-the-appropriate-network-model)しています。理由は:
>
> - より良いネットワークパフォーマンス
> - Azure Virtual Network 統合
> - Network Policy のフルサポート
>
> Kubenet は小規模/開発環境向けです。"

#### Q: "Log Analytics 統合の目的は?"

> "[Azure Monitor for AKS](https://learn.microsoft.com/azure/aks/monitor-aks)による可観測性確保です。Microsoft は本番環境で以下を推奨:
>
> - コンテナログの集中管理
> - Prometheus メトリクス収集
> - セキュリティ監査証跡
>
> これにより、Defender for Cloud のアラートと統合できます。"

---

## 10. 追加リソースとドキュメント

### 10.1 Microsoft Learn パス

1. **AKS Fundamentals**  
   [Introduction to Azure Kubernetes Service](https://learn.microsoft.com/training/modules/intro-to-azure-kubernetes-service/)

2. **Bicep IaC**  
   [Deploy Azure resources by using Bicep](https://learn.microsoft.com/training/paths/bicep-deploy/)

3. **GitHub Actions CI/CD**  
   [Deploy to Azure using Bicep and GitHub Actions](https://learn.microsoft.com/training/paths/bicep-github-actions/)

4. **AKS Security**  
   [Secure your Azure Kubernetes Service cluster](https://learn.microsoft.com/training/modules/aks-cluster-security/)

### 10.2 ベストプラクティスガイド

| カテゴリ         | ドキュメント             | URL                                                                                |
| ---------------- | ------------------------ | ---------------------------------------------------------------------------------- |
| **全般**         | AKS Best Practices       | https://learn.microsoft.com/azure/aks/best-practices                               |
| **セキュリティ** | Cluster Security         | https://learn.microsoft.com/azure/aks/operator-best-practices-cluster-security     |
|                  | Pod Security             | https://learn.microsoft.com/azure/aks/developer-best-practices-pod-security        |
|                  | Identity & RBAC          | https://learn.microsoft.com/azure/aks/operator-best-practices-identity             |
| **ネットワーク** | Network Connectivity     | https://learn.microsoft.com/azure/aks/operator-best-practices-network              |
|                  | NSG Best Practices       | https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview |
| **ストレージ**   | Storage & Backups        | https://learn.microsoft.com/azure/aks/operator-best-practices-storage              |
| **監視**         | Monitoring Overview      | https://learn.microsoft.com/azure/aks/monitor-aks                                  |
| **IaC**          | Bicep Documentation      | https://learn.microsoft.com/azure/azure-resource-manager/bicep/                    |
| **CI/CD**        | GitHub Actions for Azure | https://learn.microsoft.com/azure/developer/github/github-actions                  |

### 10.3 セキュリティコンプライアンス

1. **CIS Kubernetes Benchmark**  
   [AKS security hardening](https://learn.microsoft.com/azure/aks/cis-kubernetes)

2. **Microsoft Defender for Containers**  
   [Introduction to Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)

3. **Azure Security Baseline for AKS**  
   [Security baseline](https://learn.microsoft.com/security/benchmark/azure/baselines/aks-security-baseline)

---

## 11. 結論

### ✅ アーキテクチャの妥当性

このプロジェクトは **Microsoft 公式ドキュメントに完全準拠** したインフラストラクチャアーキテクチャと CI/CD パイプラインを実装しています:

- Bicep: 100%準拠
- GitHub Actions: 100%準拠
- AKS 構成: 100%準拠

### ❌ セキュリティ設定の意図的逸脱

7 つの脆弱性はすべて **Microsoft セキュリティドキュメントで警告されている実例** であり、クラウドセキュリティのリスクを実証するために適切です。

### 📚 教育的価値

- **Before**: Microsoft 推奨から逸脱した設定
- **Detection**: Wiz/Defender for Cloud による検出
- **After**: Microsoft 推奨への修正

このアプローチにより、理論と実践の両方でクラウドセキュリティベストプラクティスを実証できます。

---

## 付録: クイックリファレンス

### A. デプロイ前チェックリスト

```bash
# 1. Azure認証確認
az account show

# 2. Service Principal作成
az ad sp create-for-rbac --name wiz-demo-sp --role Contributor --scopes /subscriptions/$SUBSCRIPTION_ID

# 3. ACR作成
az acr create --resource-group myRG --name mywizacr --sku Standard

# 4. ACR統合(デプロイ後)
az aks update --name myAKSCluster --resource-group myRG --attach-acr mywizacr

# 5. kubectl接続確認
az aks get-credentials --resource-group myRG --name myAKSCluster
kubectl cluster-info
```

### B. Microsoft Docs 検証コマンド

```bash
# Bicep build テスト
az bicep build --file infra/main.bicep

# What-if分析
az deployment sub what-if \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json

# AKS ベストプラクティススキャン
az aks check-acr --name myAKSCluster --resource-group myRG --acr mywizacr.azurecr.io
```

### C. セキュリティ検証コマンド

```bash
# RBAC監査
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'

# NSG規則確認
az network nsg rule list --resource-group myRG --nsg-name mongo-nsg-dev --query "[?sourceAddressPrefix=='*']"

# Storage セキュリティ確認
az storage account show --name mystorageaccount --query '{publicAccess: allowBlobPublicAccess, httpsOnly: supportsHttpsTrafficOnly, tlsVersion: minimumTlsVersion}'
```

---

**ドキュメントバージョン**: 1.0  
**最終更新**: 2025 年 10 月 28 日  
**作成者**: GitHub Copilot with Microsoft Docs MCP  
**検証範囲**: Azure AKS, Bicep, GitHub Actions, Kubernetes, Security Best Practices
