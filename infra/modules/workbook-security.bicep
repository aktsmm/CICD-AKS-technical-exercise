@description('デプロイ先リージョン')
param location string

@description('環境名')
param environment string

@description('Log Analytics Workspace ID')
param workspaceId string

var workbookName = 'workbook-security-${environment}'
var workbookDisplayName = 'Security Dashboard - ${environment}'

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
            json: '## Security Monitoring Dashboard\n\nこのワークブックは、Azure Activity Log の運用・統制イベントと Microsoft Defender for Cloud のリスクをまとめて把握するためのセキュリティ中枢ビューです。\n\n- 概況と優先度: インシデントと運用失敗を確認\n- ガバナンス: Policy / アクティビティの動向を把握\n- Defender for Cloud: リスクと推奨事項を集約して改善判断'
          }
          name: 'text-header'
        }
        {
          type: 1
          content: {
            json: '### 概況と優先度\n\n面接デモでは以下の流れで状況説明が可能です。\n1. 重大インシデントの担当状況と対応漏れを確認\n2. 失敗した重要操作を洗い出してリスクの芽を把握\n3. 操作数が多い担当者を特定し、レビュー対象を明示'
          }
          name: 'text-overview'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SecurityIncident\n| where TimeGenerated > ago(7d)\n| extend OwnerName = coalesce(Owner.objectName, "Unassigned")\n| summarize IncidentCount = count(), OpenCount = countif(IncidentStatus != "Closed"), LatestUpdate = max(TimeGenerated) by Severity, OwnerName\n| extend SeverityOrder = case(Severity == "High", 0, Severity == "Medium", 1, Severity == "Low", 2, 3)\n| order by SeverityOrder asc, OpenCount desc, IncidentCount desc\n| project-away SeverityOrder\n| take 50'
            size: 0
            title: '重大インシデント担当状況 (過去7日)'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'OpenCount'
                  formatter: 8
                  formatOptions: {
                    palette: 'red'
                  }
                }
              ]
            }
          }
          name: 'query-incidents'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(3d)\n| where ActivityStatusValue == "Failed"\n| where OperationNameValue has_any ("Delete", "Write", "Policy", "RoleAssignment", "Security", "Administration")\n| extend CallerDisplay = coalesce(Caller, CallerUserDisplayName, CallerIpAddress, "Unknown")\n| summarize Failures = count(), LatestFailure = max(TimeGenerated), AffectedResources = dcount(ResourceId) by CallerDisplay, OperationNameValue, ResourceGroup\n| order by Failures desc, LatestFailure desc\n| take 20'
            size: 0
            title: '重要操作の失敗イベント (過去3日)'
            timeContext: {
              durationMs: 259200000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'Failures'
                  formatter: 8
                  formatOptions: {
                    palette: 'red'
                  }
                }
              ]
            }
          }
          name: 'query-failed-critical'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(24h)\n| where CategoryValue in ("Administrative", "Security")\n| summarize Count = count() by OperationNameValue, CallerIpAddress, CategoryValue\n| order by Count desc\n| take 20'
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
            query: 'AzureActivity\n| where TimeGenerated > ago(7d)\n| where CategoryValue in ("Administrative", "Security", "Policy")\n| extend CallerDisplay = coalesce(Caller, CallerUserDisplayName, CallerIpAddress, "Unknown")\n| summarize Operations = count(), DistinctOperations = dcount(OperationNameValue), DistinctResources = dcount(ResourceId) by CallerDisplay\n| order by Operations desc\n| take 10'
            size: 0
            title: 'リソース操作数上位ユーザー (過去7日)'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'Operations'
                  formatter: 8
                  formatOptions: {
                    palette: 'orange'
                  }
                }
              ]
            }
          }
          name: 'query-top-callers'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AzureActivity\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by bin(TimeGenerated, 1h), CategoryValue\n| order by TimeGenerated asc\n| render timechart'
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
          type: 1
          content: {
            json: '### ガバナンス・コンプライアンス\n\nPolicy の適用状況や操作密度を示し、統制の健全性を確認します。'
          }
          name: 'text-governance'
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
          type: 1
          content: {
            json: '### 外部公開リソース監視\n\nIP 制限なしで外部アクセスを許可している構成を棚卸しし、優先的に改善すべき対象を把握します。'
          }
          name: 'text-external-access'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'resources\n| where type =~ "microsoft.network/networksecuritygroups/securityrules"\n| extend access = tostring(properties.access), direction = tostring(properties.direction), source = tostring(properties.sourceAddressPrefix)\n| where access == "Allow" and direction == "Inbound"\n| where source in ("*", "0.0.0.0/0", "Internet")\n| extend NsgId = tostring(split(id, "/securityRules/")[0])\n| project SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, NsgId, RuleName = name, Priority = tostring(properties.priority), DestinationPort = tostring(properties.destinationPortRange), Protocol = tostring(properties.protocol), SourcePrefix = source\n| order by toint(Priority) asc nulls last\n| take 50'
            size: 0
            title: '外部許可 NSG ルール (最新状態)'
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
            visualization: 'table'
          }
          name: 'query-open-nsg-rules'
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'resources\n| where type in~ ("microsoft.storage/storageaccounts", "microsoft.sql/servers", "microsoft.keyvault/vaults", "microsoft.containerregistry/registries", "microsoft.web/sites", "microsoft.dbforpostgresql/servers")\n| extend PublicSetting = coalesce(tostring(properties.publicNetworkAccess), tostring(properties.networkAcls.defaultAction), tostring(properties.networkRuleSet.defaultAction))\n| where PublicSetting in~ ("Enabled", "Allow", "AllNetworks")\n| extend Endpoint = coalesce(tostring(properties.primaryEndpoints.web), tostring(properties.primaryEndpoints.blob), tostring(properties.fullyQualifiedDomainName), tostring(properties.loginServer))\n| project SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, ResourceName = name, ResourceType = type, PublicSetting, Endpoint\n| order by ResourceType asc, ResourceName asc'
            size: 0
            title: '外部公開が有効な PaaS リソース'
            queryType: 1
            resourceType: 'microsoft.resourcegraph/resources'
            visualization: 'table'
          }
          name: 'query-public-paas'
        }
        {
          type: 1
          content: {
            json: '### Microsoft Defender for Cloud\n\nリスクの集中箇所と推奨事項をまとめ、改善アクションを提示します。'
          }
          name: 'text-defender'
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
            query: 'SecurityAlert\n| where TimeGenerated > ago(7d)\n| summarize Alerts = count(), HighSeverity = countif(AlertSeverity == "High") by ResourceGroup\n| order by Alerts desc\n| take 10'
            size: 0
            title: 'Defender アラート密度 (リソースグループ別)'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'table'
            gridSettings: {
              formatters: [
                {
                  columnMatch: 'HighSeverity'
                  formatter: 8
                  formatOptions: {
                    palette: 'red'
                  }
                }
              ]
            }
          }
          name: 'query-defender-density'
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
