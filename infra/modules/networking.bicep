@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

// VNet作成
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet${environment}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-mongo'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output aksSubnetId string = vnet.properties.subnets[0].id
output mongoSubnetId string = vnet.properties.subnets[1].id
output vnetName string = vnet.name
