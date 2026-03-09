// ================================================================
// apim.bicep - Azure API Management (Premium v2, VNET統合) + MCP ポリシー
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('APIM が配置されるサブネット ID')
param subnetId string

@description('APIM Publisher メールアドレス')
param publisherEmail string

@description('APIM Publisher 名')
param publisherName string

@description('MCP Server の内部 URL (Container Apps FQDN)')
param mcpBackendUrl string

@description('Log Analytics ワークスペース ID')
param logAnalyticsWorkspaceId string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// API Management
// ──────────────────────────────────────────────
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: '${prefix}-apim'
  location: location
  tags: tags
  sku: {
    name: 'Premiumv2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
    }
  }
}

// ──────────────────────────────────────────────
// Diagnostics - Log Analytics 連携
// ──────────────────────────────────────────────
resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: 'apim-diagnostics'
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
// Named Value - MCP Backend URL
// ──────────────────────────────────────────────
resource nvMcpBackend 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'mcp-backend-url'
  properties: {
    displayName: 'mcp-backend-url'
    value: mcpBackendUrl
    secret: false
  }
}

// ──────────────────────────────────────────────
// Backend - MCP Server
// ──────────────────────────────────────────────
resource backendMcp 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: 'mcp-server-backend'
  dependsOn: [nvMcpBackend]
  properties: {
    url: mcpBackendUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// ──────────────────────────────────────────────
// API - MCP Server
// ──────────────────────────────────────────────
resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'mcp-server-api'
  properties: {
    displayName: 'MCP Server API'
    description: 'Azure AI Foundry エージェント用 MCP Server'
    path: 'mcp'
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: mcpBackendUrl
  }
}

// ──────────────────────────────────────────────
// API Policy - JWT 検証・レート制限・PII マスキング
// ──────────────────────────────────────────────
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <!-- JWT 検証: Azure AI Foundry / Managed Identity からのトークンのみ許可 -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/${tenant().tenantId}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://mcp-server</audience>
      </audiences>
      <required-claims>
        <claim name="appid" match="any">
          <value>{{foundry-client-id}}</value>
        </claim>
      </required-claims>
    </validate-jwt>
    <!-- レート制限: 100 req/min -->
    <rate-limit calls="100" renewal-period="60" />
    <!-- バックエンドへの転送 -->
    <set-backend-service backend-id="mcp-server-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- PII マスキング: email -->
    <find-and-replace from="([a-zA-Z0-9._%+\-]+)@([a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})" to="***@$2" />
    <!-- PII マスキング: 日本の電話番号 -->
    <find-and-replace from="0[0-9]{1,4}-[0-9]{1,4}-[0-9]{4}" to="***-****-****" />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimSystemIdentityPrincipalId string = apim.identity.principalId
output mcpApiUrl string = '${apim.properties.gatewayUrl}/mcp'
