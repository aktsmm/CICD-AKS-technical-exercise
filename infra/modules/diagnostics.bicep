targetScope = 'resourceGroup'

@description('Log Analytics Workspace のリソース ID')
param workspaceId string

@description('Storage Account 名')
param storageAccountName string

@description('Azure Container Registry 名')
param acrName string

@description('AKS クラスター名')
param aksName string

// リソースグループのアクティビティログを送信
resource rgDiagnostic 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'rg-activitylog-to-la'
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'Administrative', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Security', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'ServiceHealth', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Alert', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Recommendation', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Policy', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Autoscale', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'ResourceHealth', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'storage-to-la'
  scope: storageAccount
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'StorageAudit', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource acrRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'acr-to-la'
  scope: acrRegistry
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'ContainerRegistryLoginEvents', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'ContainerRegistryRepositoryEvents', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'ContainerRegistryContentTrustEvents', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' existing = {
  name: aksName
}

resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'aks-to-la'
  scope: aksCluster
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'kube-apiserver', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-controller-manager', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-scheduler', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'cluster-autoscaler', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-audit', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-audit-admin', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'guard', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'cloud-controller-manager', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'csi-azuredisk-controller', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'csi-azurefile-controller', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}
