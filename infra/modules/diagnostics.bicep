targetScope = 'resourceGroup'

@description('Log Analytics Workspace のリソース ID')
param workspaceId string

@description('Storage Account 名')
param storageAccountName string

@description('Azure Container Registry 名')
param acrName string

@description('AKS クラスター名')
param aksName string

@description('MongoDB VM 名')
param vmName string

@description('MongoDB VM 用 NSG 名')
param nsgName string

@description('仮想ネットワーク名')
param vnetName string

resource storageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  name: '${storageAccountName}/default'
}

resource storageBlobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'storage-blob-to-la'
  scope: storageBlobService
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'StorageRead', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'StorageWrite', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'StorageDelete', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'Transaction', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'Capacity', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
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
      { category: 'cloud-controller-manager', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-apiserver', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-controller-manager', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-scheduler', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'cluster-autoscaler', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-audit', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'kube-audit-admin', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'guard', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'csi-azuredisk-controller', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'csi-azurefile-controller', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'csi-snapshot-controller', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource mongoVm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmName
}

resource vmDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vm-to-la'
  scope: mongoVm
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'SoftwareUpdates', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource mongoNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' existing = {
  name: nsgName
}

resource nsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'nsg-to-la'
  scope: mongoNsg
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'NetworkSecurityGroupEvent', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
      { category: 'NetworkSecurityGroupRuleCounter', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vnet-to-la'
  scope: virtualNetwork
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'VMProtectionAlerts', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}
