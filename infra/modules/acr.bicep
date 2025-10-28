@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

var acrName = 'acrwiz${environment}'

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true  // 脆弱性: Admin user 有効化
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: false
  }
}

output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
