targetScope = 'subscription'

@description('Log Analytics Workspace のリソース ID')
param workspaceId string

@description('ワークスペース設定名（通常は "default"）')
param settingName string = 'default'

// Microsoft Defender for Cloud を Log Analytics Workspace に接続
resource defenderWorkspaceSetting 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = {
  name: settingName
  properties: {
    scope: subscription().id
    workspaceId: workspaceId
  }
}

output workspaceSettingId string = defenderWorkspaceSetting.id
output workspaceSettingName string = defenderWorkspaceSetting.name
