targetScope = 'subscription'

@description('環境名。割り当ての表示名やタグ付けに利用します。')
param environment string = 'dev'

@description('デプロイタイムスタンプ (モジュール名を一意化)')
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')

// Microsoft cloud security benchmark v2 を適用するガードレール。
module policyMcsb 'modules/policy-initiative-assignment.bicep' = {
  name: 'policy-mcsb-${deploymentTimestamp}'
  params: {
    policySetDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/MCSBv2'
    assignmentName: 'asgmt-mcsb-${environment}'
    displayName: 'Microsoft cloud security benchmark v2 (${environment})'
    assignmentDescription: 'Assigns the Microsoft cloud security benchmark initiative to monitor the intentionally vulnerable demo scope.'
    nonComplianceMessage: 'Use Defender for Cloud to review the Microsoft cloud security benchmark posture for this demo environment.'
  }
}

// CIS Microsoft Azure Foundations Benchmark v1.4.0 を適用するガードレール。
module policyCis 'modules/policy-initiative-assignment.bicep' = {
  name: 'policy-cis140-${deploymentTimestamp}'
  params: {
    policySetDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/CISv1_4_0'
    assignmentName: 'asgmt-cis140-${environment}'
    displayName: 'CIS Microsoft Azure Foundations Benchmark v1.4.0 (${environment})'
    assignmentDescription: 'Assigns the CIS v1.4.0 initiative so compliance drift can be reviewed without remediating intentional findings.'
    nonComplianceMessage: 'Track CIS v1.4.0 recommendations after each deployment to confirm known gaps remain observable.'
  }
}

output mcsbAssignmentId string = policyMcsb.outputs.policyAssignmentId
output cisAssignmentId string = policyCis.outputs.policyAssignmentId
