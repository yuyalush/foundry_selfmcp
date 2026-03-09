// ================================================================
// monitoring.bicep - Log Analytics Workspace + Application Insights + Action Group
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('アラート通知先メールアドレス (空の場合はアクショングループを作成しない)')
param alertEmailAddress string = ''

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Log Analytics Workspace
// ──────────────────────────────────────────────
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableDataExport: false
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ──────────────────────────────────────────────
// Application Insights (workspace-based)
// ──────────────────────────────────────────────
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-ai'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ──────────────────────────────────────────────
// Action Group - メール通知 (alertEmailAddress が指定された場合のみ作成)
// ──────────────────────────────────────────────
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (!empty(alertEmailAddress)) {
  name: '${prefix}-ag-ops'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'OpsAlert'
    enabled: true
    emailReceivers: [
      {
        name: 'ops-email'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output logAnalyticsCustomerId string = logAnalytics.properties.customerId

@secure()
output logAnalyticsWorkspaceKey string = logAnalytics.listKeys().primarySharedKey

output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output actionGroupId string = !empty(alertEmailAddress) ? actionGroup.id : ''
