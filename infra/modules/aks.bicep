@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('サブネットID')
param subnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

var clusterName = 'aks-wiz-${environment}'

// AKSクラスター
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      loadBalancerSku: 'standard'
    }
    // 監査ログ有効化
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    // 脆弱性注意: RBACは有効だが、後でCluster Admin権限を不適切に付与
    enableRBAC: true
  }
}

output clusterName string = aks.name
output clusterFqdn string = aks.properties.fqdn
output kubeletIdentity string = aks.properties.identityProfile.kubeletidentity.objectId
