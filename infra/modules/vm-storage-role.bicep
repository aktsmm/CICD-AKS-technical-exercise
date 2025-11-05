@description('VM の Managed Identity Principal ID')
param vmPrincipalId string

@description('Storage Account 名')
param storageAccountName string

@description('既存 Storage Blob Data Contributor ロール割り当て名 (GUID)。未指定の場合は新規作成。')
param existingStorageAssignmentName string = ''

@description('既存 Virtual Machine Contributor ロール割り当て名 (GUID)。未指定の場合は新規作成。')
param existingVmContributorAssignmentName string = ''

// Storage Blob Data Contributor ロール定義 ID
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// Virtual Machine Contributor ロール定義 ID (過剰な権限 - 意図的な脆弱性)
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

var storageRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
var vmContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)

var storageRoleAssignmentName = empty(existingStorageAssignmentName) ? guid(storageAccount.id, vmPrincipalId, storageBlobDataContributorRoleId) : existingStorageAssignmentName
var vmContributorAssignmentName = empty(existingVmContributorAssignmentName) ? guid(resourceGroup().id, vmPrincipalId, vmContributorRoleId) : existingVmContributorAssignmentName

// 既存のStorage Accountを参照
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// VMにStorage Blob Data Contributor権限を付与（バックアップ用）
resource storageRoleAssignmentExisting 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = if (!empty(existingStorageAssignmentName)) {
  name: storageRoleAssignmentName
  scope: storageAccount
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (empty(existingStorageAssignmentName)) {
  name: storageRoleAssignmentName
  scope: storageAccount
  properties: {
    roleDefinitionId: storageRoleDefinitionId
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ⚠️ 脆弱性: VMに過剰な権限を付与 (Virtual Machine Contributor)
// この権限により、VMは他のVMを作成・変更・削除できる
resource vmExcessiveRoleAssignmentExisting 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = if (!empty(existingVmContributorAssignmentName)) {
  name: vmContributorAssignmentName
  scope: resourceGroup()
}

resource vmExcessiveRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (empty(existingVmContributorAssignmentName)) {
  name: vmContributorAssignmentName
  scope: resourceGroup()
  properties: {
    roleDefinitionId: vmContributorRoleDefinitionId
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
    description: '⚠️ 意図的な脆弱性: MongoDB VMに過剰な権限を付与 (他のVM作成可能)'
  }
}

output roleAssignmentId string = empty(existingStorageAssignmentName) ? storageRoleAssignment.id : storageRoleAssignmentExisting.id
output excessiveRoleAssignmentId string = empty(existingVmContributorAssignmentName) ? vmExcessiveRoleAssignment.id : vmExcessiveRoleAssignmentExisting.id
