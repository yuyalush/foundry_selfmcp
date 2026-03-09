// ================================================================
// alerts.bicep - アラートルール
//   - MCP サーバエラー率 > 5%     → メール通知
//   - APIM レイテンシ P95 > 5秒   → メール通知
//   - SQL CPU > 80% (5分間)       → メール通知
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('アクショングループ ID')
param actionGroupId string

@description('Log Analytics ワークスペース ID')
param logAnalyticsWorkspaceId string

@description('Application Insights リソース ID')
param appInsightsId string

@description('SQL Database リソース ID (SQL CPU アラート用)')
param sqlDbId string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Alert - MCP サーバ エラー率 > 5%
// Application Insights の AppRequests テーブルを用いた
// Log Analytics スケジュールクエリアラート
// ──────────────────────────────────────────────
resource alertMcpErrorRate 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: '${prefix}-alert-mcp-error-rate'
  location: location
  tags: tags
  properties: {
    displayName: 'MCP Server Error Rate > 5%'
    description: 'MCP サーバのエラー率が 5% を超えた場合にアラートを発報する'
    severity: 2
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
AppRequests
| summarize total = count(), failed = countif(Success == false)
| extend errorRate = iff(total > 0, (failed * 100.0) / total, 0.0)
| project errorRate
'''
          timeAggregation: 'Average'
          metricMeasureColumn: 'errorRate'
          operator: 'GreaterThan'
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ──────────────────────────────────────────────
// Alert - APIM レイテンシ P95 > 5秒
// Log Analytics の AzureDiagnostics (GatewayLogs) を用いた
// スケジュールクエリアラート
// ──────────────────────────────────────────────
resource alertApimLatency 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: '${prefix}-alert-apim-latency-p95'
  location: location
  tags: tags
  properties: {
    displayName: 'APIM Latency P95 > 5s'
    description: 'APIM の P95 レイテンシが 5 秒 (5000ms) を超えた場合にアラートを発報する'
    severity: 2
    enabled: true
    scopes: [logAnalyticsWorkspaceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
AzureDiagnostics
| where Category == "GatewayLogs"
| where isnotempty(DurationMs)
| summarize P95 = percentile(DurationMs, 95)
| project P95
'''
          timeAggregation: 'Average'
          metricMeasureColumn: 'P95'
          operator: 'GreaterThan'
          threshold: 5000
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
  }
}

// ──────────────────────────────────────────────
// Alert - SQL CPU > 80% (5分間)
// SQL Database のメトリクスアラート
// ──────────────────────────────────────────────
resource alertSqlCpu 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-alert-sql-cpu'
  location: 'global'
  tags: tags
  properties: {
    description: 'SQL Database の CPU 使用率が 80% を超えた場合にアラートを発報する'
    severity: 2
    enabled: true
    scopes: [sqlDbId]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpuAlert'
          metricName: 'cpu_percent'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output alertMcpErrorRateId string = alertMcpErrorRate.id
output alertApimLatencyId string = alertApimLatency.id
output alertSqlCpuId string = alertSqlCpu.id
