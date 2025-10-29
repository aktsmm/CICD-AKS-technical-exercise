targetScope = 'subscription'

@description('リソースグループ名')
param resourceGroupName string = 'rg-wiz-exercise'

@description('デプロイ先リージョン')
param location string = 'japaneast'

@description('環境名')
param environment string = 'dev'

@description('MongoDB管理者パスワード')
@secure()
param mongoAdminPassword string

@description('デプロイタイムスタンプ (ユニークなデプロイ名生成)')
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

output aksClusterName string = aks.outputs.clusterName
output mongoVMPublicIP string = mongoVM.outputs.publicIP
output storageAccountName string = storage.outputs.storageAccountName
