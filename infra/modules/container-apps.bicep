// ================================================================
// container-apps.bicep - Container Apps Environment + MCP Server App
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Container Apps 環境配置先サブネット ID')
param subnetId string

@description('Log Analytics ワークスペース ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics ワークスペースの共有キー')
@secure()
param logAnalyticsWorkspaceKey string

@description('デプロイするコンテナイメージ (例: myacr.azurecr.io/mcp-server:latest)')
param containerImage string

@description('Application Insights 接続文字列')
@secure()
param appInsightsConnectionString string

@description('SQL Server FQDN')
param sqlServerFqdn string

@description('SQL Database 名')
param sqlDatabaseName string

@description('AI Search エンドポイント')
param aiSearchEndpoint string

@description('MCP Server 用 Managed Identity リソース ID')
param identityId string

@description('MCP Server 用 Managed Identity クライアント ID')
param identityClientId string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Container Apps Environment (VNET 統合)
// ──────────────────────────────────────────────
resource caEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${prefix}-cae'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: logAnalyticsWorkspaceKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true // Internal ingress のみ (APIM 経由でのみアクセス可)
    }
    zoneRedundant: false
  }
}

// ──────────────────────────────────────────────
// Container App - MCP Server
// ──────────────────────────────────────────────
resource mcpServerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${prefix}-mcp'
  location: location
  tags: union(tags, { 'azd-service-name': 'mcp-server' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: caEnv.id
    configuration: {
      ingress: {
        external: false         // Internal のみ
        targetPort: 8000
        transport: 'http'
        allowInsecure: false
      }
      dapr: {
        enabled: false
      }
      secrets: [
        {
          name: 'appinsights-connection-string'
          value: appInsightsConnectionString
        }
      ]
      registries: [
        {
          server: split(containerImage, '/')[0]
          identity: identityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-server'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'SQL_SERVER'
              value: sqlServerFqdn
            }
            {
              name: 'SQL_DATABASE'
              value: sqlDatabaseName
            }
            {
              name: 'AI_SEARCH_ENDPOINT'
              value: aiSearchEndpoint
            }
            {
              name: 'AI_SEARCH_INDEX'
              value: 'metadata-index'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: identityClientId
            }
            {
              name: 'PORT'
              value: '8000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// ──────────────────────────────────────────────
// Diagnostics - Container Apps Environment → Log Analytics
// ──────────────────────────────────────────────
resource caEnvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: caEnv
  name: 'cae-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Diagnostics - MCP Server Container App → Log Analytics
// ──────────────────────────────────────────────
resource mcpAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mcpServerApp
  name: 'mcp-app-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output caEnvId string = caEnv.id
output mcpAppId string = mcpServerApp.id
output mcpAppFqdn string = mcpServerApp.properties.configuration.ingress.fqdn
output mcpInternalUrl string = 'https://${mcpServerApp.properties.configuration.ingress.fqdn}/mcp'

