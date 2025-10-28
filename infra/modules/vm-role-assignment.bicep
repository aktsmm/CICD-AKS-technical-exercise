@description('VM の Managed Identity Principal ID')
param vmPrincipalId string

// Contributor ロール定義 ID (組み込みロール)
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// 脆弱性: MongoDB VMにContributor権限を付与（VM作成可能な過剰な権限）
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
