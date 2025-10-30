@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

var workspaceName = 'log-${environment}'

// Log Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Note: Diagnostic Settings for Activity Log should be configured at subscription level
// This can be done separately using Azure CLI or Portal after deployment

output workspaceId string = workspace.id
output workspaceName string = workspace.name
