@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('Log Analytics Workspace ID')
param workspaceId string

var workbookName = 'workbook-security-${environment}'
var workbookDisplayName = 'Security Dashboard - ${environment}'

// Azure Workbook for Security Monitoring
// 監査ログとDefender アラートを可視化するダッシュボード
resource securityWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(workbookName)
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    category: 'security'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '## Security Monitoring Dashboard\n\nこのワークブックは、Azure Activity Log の監査ログと Microsoft Defender for Cloud のアラートをリアルタイムで可視化します。'
          }
          name: 'text-header'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(24h)\n| where CategoryValue == "Administrative" or CategoryValue == "Security"\n| summarize Count = count() by OperationNameValue, CallerIpAddress, CategoryValue\n| order by Count desc\n| take 20'
            size: 0
            title: '過去24時間の監査ログ (Administrative & Security)'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'Count'
                  formatter: 8
                  formatOptions: {
                    palette: 'blue'
                  }
                }
              ]
            }
          }
          name: 'query-activity-log'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SecurityAlert\n| where TimeGenerated > ago(7d)\n| summarize Count = count() by AlertName, AlertSeverity, ProductName\n| order by Count desc'
            size: 0
            title: '過去7日間の Defender アラート'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'AlertSeverity'
                  formatter: 18
                  formatOptions: {
                    thresholdsOptions: 'icons'
                    thresholdsGrid: [
                      {
                        operator: '=='
                        thresholdValue: 'High'
                        representation: 'critical'
                        text: '{0}{1}'
                      }
                      {
                        operator: '=='
                        thresholdValue: 'Medium'
                        representation: 'warning'
                        text: '{0}{1}'
                      }
                      {
                        operator: 'Default'
                        thresholdValue: null
                        representation: 'info'
                        text: '{0}{1}'
                      }
                    ]
                  }
                }
              ]
            }
          }
          name: 'query-defender-alerts'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(7d)\n| where CategoryValue == "Policy"\n| summarize Count = count() by OperationNameValue, Resource\n| order by Count desc\n| take 10'
            size: 0
            title: '過去7日間の Azure Policy イベント'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'barchart'
          }
          name: 'query-policy-events'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by bin(TimeGenerated, 1h), CategoryValue\n| render timechart'
            size: 0
            title: '過去24時間のアクティビティタイムライン'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'timechart'
          }
          name: 'query-timeline'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SecurityRecommendation\n| where TimeGenerated > ago(1d)\n| summarize arg_max(TimeGenerated, *) by RecommendationName\n| summarize Count = count() by RecommendationSeverity\n| order by Count desc'
            size: 0
            title: 'セキュリティ推奨事項 (重要度別)'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'piechart'
          }
          name: 'query-recommendations'
        }
      ]
      styleSettings: {}
      fromTemplateId: 'sentinel-UserWorkbook'
    })
    sourceId: workspaceId
    version: '1.0'
  }
}

output workbookId string = securityWorkbook.id
output workbookName string = securityWorkbook.name
