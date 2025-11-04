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

var defenderPlanNames = [
  'VirtualMachines'
  'AppServices'
  'StorageAccounts'
  'SqlServers'
  'SqlServerVirtualMachines'
  'KubernetesService'
  'ContainerRegistry'
]

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

resource subscriptionActivityDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'activitylog-to-law-${environment}'
  scope: subscription()
  properties: {
    workspaceId: monitoring.outputs.workspaceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Autoscale'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
    ]
  }
}

resource defenderForCloudPlans 'Microsoft.Security/pricings@2022-03-01' = [for planName in defenderPlanNames: {
  name: planName
  properties: {
    pricingTier: 'Standard'
  }
}]

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

output aksClusterName string = aks.outputs.clusterName
output mongoVMPublicIP string = mongoVM.outputs.publicIP
output mongoVMPrivateIP string = mongoVM.outputs.privateIP
output storageAccountName string = storage.outputs.storageAccountName
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output kubeletIdentityPrincipalId string = aks.outputs.kubeletIdentity
output mongoVMIdentityPrincipalId string = mongoVM.outputs.vmIdentityPrincipalId
