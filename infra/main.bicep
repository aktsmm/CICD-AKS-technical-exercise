targetScope = 'subscription'

@description('リソースグループ名')
param resourceGroupName string = 'rg-bbs-cicd-aks'

@description('デプロイ先リージョン')
param location string = 'japaneast'

@description('環境名')
param environment string = 'dev'

@description('MongoDB管理者pass')
@secure()
param mongoAdminPassword string

@description('デプロイタイムスタンプ!! (ユニークなデプロイ名生成)')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

// リソースグループ作成
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// ネットワーキング
module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networking-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// Log Analytics (監査ログ用)
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  name: 'monitoring-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// Storage Account (脆弱な構成)
module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    // 脆弱性: Public Access有効
    allowPublicBlobAccess: true
  }
}

// Azure Container Registry (脆弱な構成)
module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
  }
}

// MongoDB VM (脆弱な構成)
module mongoVM 'modules/vm-mongodb.bicep' = {
  scope: rg
  name: 'mongodb-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    adminPassword: mongoAdminPassword
    mongoAdminPassword: mongoAdminPassword
    subnetId: networking.outputs.mongoSubnetId
    storageAccountName: storage.outputs.storageAccountName
    backupContainerName: storage.outputs.containerName
    // 脆弱性: SSH公開
    allowSSHFromInternet: true
  }
}

// AKSクラスター
module aks 'modules/aks.bicep' = {
  scope: rg
  name: 'aks-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    subnetId: networking.outputs.aksSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

// 脆弱性: MongoDB VMに過剰なクラウド権限(Contributor)を付与
module vmRoleAssignment 'modules/vm-role-assignment.bicep' = {
  scope: rg
  name: 'vm-role-${deploymentTimestamp}'
  params: {
    vmPrincipalId: mongoVM.outputs.vmIdentityPrincipalId
  }
}

// MongoDB VMにStorage Blob Data Contributor権限を付与（バックアップ用）
module vmStorageRole 'modules/vm-storage-role.bicep' = {
  scope: rg
  name: 'vm-storage-role-${deploymentTimestamp}'
  params: {
    vmPrincipalId: mongoVM.outputs.vmIdentityPrincipalId
    storageAccountName: storage.outputs.storageAccountName
  }
}

// AKS に ACR からイメージを pull する権限を付与
module aksAcrRole 'modules/aks-acr-role.bicep' = {
  scope: rg
  name: 'aks-acr-role-${deploymentTimestamp}'
  params: {
    kubeletIdentityPrincipalId: aks.outputs.kubeletIdentity
    acrName: acr.outputs.acrName
  }
}

module diagnostics 'modules/diagnostics.bicep' = {
  scope: rg
  name: 'diagnostics-${deploymentTimestamp}'
  params: {
    workspaceId: monitoring.outputs.workspaceId
    storageAccountName: storage.outputs.storageAccountName
    acrName: acr.outputs.acrName
    aksName: aks.outputs.clusterName
    vmName: mongoVM.outputs.vmName
    nsgName: mongoVM.outputs.nsgName
    vnetName: networking.outputs.vnetName
  }
}

// Microsoft cloud security benchmark v2 の割り当て。GUID 指定で定義リネーム時も影響を受けません。
module policyMcsb 'modules/policy-initiative-assignment.bicep' = {
  name: 'policy-mcsb-${deploymentTimestamp}'
  params: {
    policySetDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/e3ec7e09-768c-4b64-882c-fcada3772047'
    assignmentName: 'asgmt-mcsb-${environment}'
    displayName: 'Microsoft cloud security benchmark v2 (${environment})'
    assignmentDescription: 'Assigns the Microsoft cloud security benchmark initiative to monitor the intentionally vulnerable demo scope.'
    nonComplianceMessage: 'Use Defender for Cloud to review the Microsoft cloud security benchmark posture for this demo environment.'
    // Microsoft.MobileNetwork プロバイダー依存ポリシーだけを無効化して登録制限に対応
    policyOverrides: [
      {
        kind: 'PolicyEffect'
        policyDefinitionReferenceId: 'SimGroupCMKsEncryptDataRest'
        value: {
          effect: 'Disabled'
        }
      }
    ]
  }
}

// CIS Microsoft Azure Foundations Benchmark v1.4.0 の割り当て。正式 GUID 参照で安定配信。
module policyCis 'modules/policy-initiative-assignment.bicep' = {
  name: 'policy-cis140-${deploymentTimestamp}'
  params: {
    policySetDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/c3f5c4d9-9a1d-4a99-85c0-7f93e384d5c5'
    assignmentName: 'asgmt-cis140-${environment}'
    displayName: 'CIS Microsoft Azure Foundations Benchmark v1.4.0 (${environment})'
    assignmentDescription: 'Assigns the CIS v1.4.0 initiative so compliance drift can be reviewed without remediating intentional findings.'
    nonComplianceMessage: 'Track CIS v1.4.0 recommendations after each deployment to confirm known gaps remain observable.'
  }
}

output aksClusterName string = aks.outputs.clusterName
output mongoVMPublicIP string = mongoVM.outputs.publicIP
output mongoVMPrivateIP string = mongoVM.outputs.privateIP
output storageAccountName string = storage.outputs.storageAccountName
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
