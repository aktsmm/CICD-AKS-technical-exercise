targetScope = 'resourceGroup'

@description('Object ID of the principal to grant RBAC permissions to.')
param principalObjectId string

// Built-in role identifier for User Access Administrator
var userAccessAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f1a07417-d97a-45cb-824c-7a7467783830')

resource userAccessAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalObjectId, 'userAccessAdmin')
  properties: {
    principalId: principalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: userAccessAdminRoleId
  }
}
