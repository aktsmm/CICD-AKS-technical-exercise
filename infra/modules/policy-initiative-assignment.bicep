targetScope = 'subscription'

@description('割り当て対象のポリシー イニシアチブ ID (例: /providers/Microsoft.Authorization/policySetDefinitions/e3ec7e09-768c-4b64-882c-fcada3772047)')
param policySetDefinitionId string

@description('ポリシー割り当てのリソース名 (スコープ内で一意)')
param assignmentName string

@description('ポリシー割り当ての表示名')
param displayName string

@description('ポリシー割り当ての説明')
param assignmentDescription string = ''

@description('コンプライアンス違反時に表示するメッセージ')
param nonComplianceMessage string = 'Review compliance results for this policy assignment.'

@description('イニシアチブに渡すパラメーター。不要な場合は空のオブジェクトのまま。')
param policyParameters object = {}

@description('特定のポリシー参照の効果を上書きする設定。ポリシー除外が必要な場合に利用します。')
param policyOverrides array = []

// デモ環境の評価用としてサブスクリプション全体にガードレールを適用する共通モジュール。
resource initiativeAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: assignmentName
  scope: subscription()
  properties: {
    displayName: displayName
    description: assignmentDescription
    policyDefinitionId: policySetDefinitionId
    nonComplianceMessages: [
      {
        message: nonComplianceMessage
      }
    ]
    parameters: policyParameters
    overrides: length(policyOverrides) == 0 ? null : policyOverrides
    enforcementMode: 'Default'
  }
}

output policyAssignmentId string = initiativeAssignment.id
