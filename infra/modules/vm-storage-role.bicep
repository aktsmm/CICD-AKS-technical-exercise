@description('VM の Managed Identity Principal ID')
param vmPrincipalId string

@description('Storage Account 名')
param storageAccountName string

// Storage Blob Data Contributor ロール定義 ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// Virtual Machine Contributor ロール定義 ID (過剰な権限 - 意図的な脆弱性)
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

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

// ⚠️ 脆弱性: VMに過剰な権限を付与 (Virtual Machine Contributor)
// この権限により、VMは他のVMを作成・変更・削除できる
resource vmExcessiveRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmPrincipalId, vmContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
    description: '⚠️ 意図的な脆弱性: MongoDB VMに過剰な権限を付与 (他のVM作成可能)'
  }
}

output roleAssignmentId string = storageRoleAssignment.id
output excessiveRoleAssignmentId string = vmExcessiveRoleAssignment.id
