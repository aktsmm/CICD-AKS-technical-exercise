@description('VM の Managed Identity Principal ID')
param vmPrincipalId string

@description('Storage Account 名')
param storageAccountName string

// Storage Blob Data Contributor ロール定義 ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// 既存のStorage Accountを参照
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// VMにStorage Blob Data Contributor権限を付与（バックアップ用）
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, vmPrincipalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = storageRoleAssignment.id
