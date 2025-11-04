targetScope = 'subscription'

@description('Object ID of the principal to grant Owner role to.')
param principalObjectId string

// Built-in Owner role definition ID
var ownerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')

resource ownerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalObjectId, 'ownerAssignment')
  properties: {
    principalId: principalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleId
  }
}
