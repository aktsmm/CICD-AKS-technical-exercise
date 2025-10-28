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

@description('デプロイタイムスタンプ (ユニークなデプロイ名生成用)')
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

// MongoDB VM (脆弱な構成)
module mongoVM 'modules/vm-mongodb.bicep' = {
  scope: rg
  name: 'mongodb-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    adminPassword: mongoAdminPassword
    subnetId: networking.outputs.mongoSubnetId
    // 脆弱性: SSH公開、古いOS
    allowSSHFromInternet: true
    useOldOSVersion: true
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

// Azure Container Registry (Private Endpoint付き)
module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr-${deploymentTimestamp}'
  params: {
    location: location
    environment: environment
    vnetId: networking.outputs.vnetId
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
  }
  dependsOn: [
    aks
  ]
}

output aksClusterName string = aks.outputs.clusterName
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output mongoVMPublicIP string = mongoVM.outputs.publicIP
output storageAccountName string = storage.outputs.storageAccountName
