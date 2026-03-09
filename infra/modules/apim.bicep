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

@description('Managed Identity バックエンド認証用リソース URI (Container Apps Easy Auth の App ID URI)')
param mcpBackendAudience string = ''

@description('Log Analytics ワークスペース ID')
param logAnalyticsWorkspaceId string

@description('Application Insights リソース ID')
param appInsightsId string

@description('Application Insights インストゥルメンテーションキー')
@secure()
param appInsightsInstrumentationKey string

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
// Named Value - Tenant ID (JWT 検証用)
// ──────────────────────────────────────────────
resource nvTenantId 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'tenant-id'
  properties: {
    displayName: 'tenant-id'
    value: tenant().tenantId
    secret: false
  }
}

// ──────────────────────────────────────────────
// Named Value - Login Endpoint (JWT 検証用 OpenID Config ベース URL)
// ──────────────────────────────────────────────
resource nvLoginEndpoint 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'login-endpoint'
  properties: {
    displayName: 'login-endpoint'
    // environment() 関数でクラウド環境に依存しない URL を設定
    value: environment().authentication.loginEndpoint
    secret: false
  }
}

// ──────────────────────────────────────────────
// Named Value - MCP Backend Resource (Managed Identity 認証用 App ID URI)
// ──────────────────────────────────────────────
resource nvMcpBackendResource 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'mcp-backend-resource'
  properties: {
    displayName: 'mcp-backend-resource'
    // Container Apps に Easy Auth (Azure AD) を設定した場合はその App ID URI を指定する
    // 例: api://<container-app-client-id>
    // 未設定の場合は environment().resourceManager をデフォルトとし、VNET 分離のみでバックエンドを保護する
    value: empty(mcpBackendAudience) ? environment().resourceManager : mcpBackendAudience
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
    path: 'mcp/v1'
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: mcpBackendUrl
  }
}

// ──────────────────────────────────────────────
// API Policy - JWT 検証・レート制限・リクエストサイズ上限・PII マスキング・セキュリティヘッダー
// ──────────────────────────────────────────────
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: mcpApi
  name: 'policy'
  dependsOn: [nvTenantId, nvLoginEndpoint, nvMcpBackendResource]
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <!-- Entra ID JWT 検証: Bearer トークンの署名・オーディエンスを検証 -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized: valid JWT token required">
      <openid-config url="{{login-endpoint}}{{tenant-id}}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://mcp-server</audience>
      </audiences>
    </validate-jwt>
    <!-- レート制限: クライアント ID ごとに 100 req/min -->
    <rate-limit-by-key calls="100" renewal-period="60"
      counter-key="@(context.Request.Headers.GetValueOrDefault(&quot;x-client-id&quot;, context.Request.IpAddress))"
      increment-condition="@(context.Response.StatusCode != 429)" />
    <!-- リクエストサイズ上限 (1 MB) -->
    <choose>
      <when condition="@(context.Request.Headers.GetValueOrDefault(&quot;Content-Length&quot;, &quot;0&quot;).AsInteger() > 1048576)">
        <return-response>
          <set-status code="413" reason="Payload Too Large" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>{"error":"Request payload exceeds the 1 MB limit"}</set-body>
        </return-response>
      </when>
    </choose>
    <!-- Managed Identity によるバックエンド認証 (resource は backend の App ID URI に合わせて設定) -->
    <authentication-managed-identity resource="{{mcp-backend-resource}}" />
    <!-- バックエンドへの転送 -->
    <set-backend-service backend-id="mcp-server-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- PII マスキング: メールアドレス -->
    <find-and-replace from="[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}" to="***@***.***" />
    <!-- PII マスキング: 日本の電話番号 -->
    <find-and-replace from="0[0-9]{1,4}-[0-9]{1,4}-[0-9]{4}" to="***-****-****" />
    <!-- セキュリティヘッダー付与 -->
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="X-XSS-Protection" exists-action="override">
      <value>1; mode=block</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
    <set-header name="Content-Type" exists-action="override">
      <value>application/json</value>
    </set-header>
    <set-body>@{
      return new JObject(
        new JProperty("error", context.LastError.Message),
        new JProperty("statusCode", context.Response.StatusCode)
      ).ToString();
    }</set-body>
  </on-error>
</policies>
'''
  }
}

// ──────────────────────────────────────────────
// Application Insights Logger
// ──────────────────────────────────────────────
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: appInsightsId
  }
}

// ──────────────────────────────────────────────
// API Diagnostics - Application Insights ログ連携
// ──────────────────────────────────────────────
resource mcpApiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
  parent: mcpApi
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: ['x-client-id', 'Content-Type']
        body: { bytes: 0 }
      }
      response: {
        headers: ['Content-Type', 'X-Content-Type-Options']
        body: { bytes: 0 }
      }
    }
    backend: {
      request: {
        headers: ['Content-Type']
        body: { bytes: 0 }
      }
      response: {
        headers: ['Content-Type']
        body: { bytes: 0 }
      }
    }
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output apimId string = apim.id
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimSystemIdentityPrincipalId string = apim.identity.principalId
output mcpApiUrl string = '${apim.properties.gatewayUrl}/mcp/v1'
