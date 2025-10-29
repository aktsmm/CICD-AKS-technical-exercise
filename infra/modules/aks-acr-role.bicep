@description('AKS Kubelet Managed Identity の Principal ID')
param kubeletIdentityPrincipalId string

@description('ACR リソース名')
param acrName string

// ACR リソースの参照
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// AKS に ACR からイメージを pull する権限を付与
resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, kubeletIdentityPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: kubeletIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = aksAcrPull.id
