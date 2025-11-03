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

@description('AKS 拡張カテゴリ (Guard / CSI など) の診断ログを収集する場合に true。対応リソースが存在しない環境では false を維持してください。')
param enableAksExtendedCategories bool = false

@description('Cluster Autoscaler ログを収集する場合に true。クラスター構成で autoscaler が無効な場合は false のままにしてください。')
param enableAksClusterAutoscalerLogs bool = false

@description('NSG のフロー系ログ (RuleCounter / FlowEvent) を有効化する場合に true。Network Watcher フロー ログ設定が必要です。')
param enableNsgFlowLogs bool = false

@description('仮想ネットワーク VMProtectionAlerts を収集する場合に true。DDoS Protection プランが必須です。')
param enableVnetVmProtectionAlerts bool = false

@description('仮想ネットワーク名 (VMProtectionAlerts 収集時に利用)')
param vnetName string = ''

// MS Learn: AKS monitoring data reference に列挙されたカテゴリをベースに配列を構成
// https://learn.microsoft.com/azure/aks/monitor-aks-reference#resource-logs
var baseAksLogCategories = [
  'kube-apiserver'
  'kube-controller-manager'
  'kube-scheduler'
  'kube-audit'
  'kube-audit-admin'
]

var extendedAksLogCategories = [
  'guard'
  'csi-azuredisk-controller'
  'csi-azurefile-controller'
  'csi-snapshot-controller'
]

var aksLogCategories = concat(
  baseAksLogCategories,
  enableAksClusterAutoscalerLogs ? [ 'cluster-autoscaler' ] : [] ,
  enableAksExtendedCategories ? extendedAksLogCategories : []
)

var mongoDcrName = 'dcr-linux-${vmName}'
var mongoDcrAssociationName = 'ama-${vmName}'

// MS Learn: NSG ログカテゴリ (Event / RuleCounter / FlowEvent)
// https://learn.microsoft.com/azure/virtual-network/virtual-network-nsg-manage-log#log-categories
var nsgLogCategories = enableNsgFlowLogs ? [
  'NetworkSecurityGroupEvent'
  'NetworkSecurityGroupRuleCounter'
  'NetworkSecurityGroupFlowEvent'
] : [
  'NetworkSecurityGroupEvent'
]

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
    logs: [for category in aksLogCategories: {
      category: category
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }]
    metrics: [
      { category: 'AllMetrics', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

resource mongoVm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmName
}

// DCR で AMA から Log Analytics へ Linux ゲストデータを送信
resource mongoVmDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: mongoDcrName
  location: resourceGroup().location
  properties: {
    description: 'Collect Linux guest perf counters and syslog for MongoDB VM.'
    destinations: {
      logAnalytics: [
        {
          name: 'law-default'
          workspaceResourceId: workspaceId
        }
      ]
      azureMonitorMetrics: {
        name: 'azureMonitorMetrics-default'
      }
    }
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource60'
          samplingFrequencyInSeconds: 60
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory(_Total)\\% Available Memory'
            '\\LogicalDisk(*)\\% Free Space'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'daemon'
          ]
          logLevels: [
            'Error'
            'Warning'
            'Info'
          ]
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'azureMonitorMetrics-default'
        ]
      }
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'law-default'
        ]
      }
    ]
  }
}

resource mongoVmDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: mongoDcrAssociationName
  scope: mongoVm
  properties: {
    dataCollectionRuleId: mongoVmDataCollectionRule.id
  }
}

resource vmDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'vm-to-la'
  scope: mongoVm
  properties: {
    workspaceId: workspaceId
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
    logs: [for category in nsgLogCategories: {
      category: category
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = if (enableVnetVmProtectionAlerts) {
  name: vnetName
}

resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableVnetVmProtectionAlerts) {
  name: 'vnet-to-la'
  scope: virtualNetwork
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'VMProtectionAlerts', enabled: true, retentionPolicy: { enabled: false, days: 0 } }
    ]
  }
}

