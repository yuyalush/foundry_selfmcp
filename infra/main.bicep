// ================================================================
// main.bicep - 全リソースのオーケストレーター
// ================================================================
targetScope = 'resourceGroup'

@description('環境識別子 (dev / stg / prod)')
@allowed(['dev', 'stg', 'prod'])
param environmentName string

@description('デプロイ先リージョン')
param location string = resourceGroup().location

@description('リソース名プレフィックス (デフォルト: rg 名から自動生成)')
param prefix string = 'fmcp-${environmentName}'

@description('APIM Publisher メールアドレス')
param apimPublisherEmail string

@description('APIM Publisher 名')
param apimPublisherName string = 'MCP PoC Admin'

@description('SQL Entra ID 管理者のオブジェクト ID')
param sqlAdminObjectId string

@description('SQL Entra ID 管理者のログイン名')
param sqlAdminLoginName string

@description('デプロイするコンテナイメージ')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('アラート通知先メールアドレス (空の場合はアラートルールを作成しない)')
param alertEmailAddress string = ''

@description('タグ')
param tags object = {
  environment: environmentName
  project: 'foundry-mcp-poc'
  managedBy: 'azd'
}

// ──────────────────────────────────────────────
// 監視
// ──────────────────────────────────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    prefix: prefix
    location: location
    tags: tags
    alertEmailAddress: alertEmailAddress
  }
}

// ──────────────────────────────────────────────
// ネットワーク
// ──────────────────────────────────────────────
module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    prefix: prefix
    location: location
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    logAnalyticsWorkspaceCustomerId: monitoring.outputs.logAnalyticsCustomerId
  }
}

// ──────────────────────────────────────────────
// MCP Server 用 Managed Identity (先行作成してサイクルを解消)
// ──────────────────────────────────────────────
module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    prefix: prefix
    location: location
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Key Vault (先に作成してシークレット格納先を確保)
// ──────────────────────────────────────────────
module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSharedId
    privateDnsZoneId: networking.outputs.privateDnsZoneKeyVaultId
    secretReaderPrincipalIds: [identity.outputs.identityPrincipalId]
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    tags: tags
  }
}

// ──────────────────────────────────────────────
// SQL Database
// ──────────────────────────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSqlId
    privateDnsZoneId: networking.outputs.privateDnsZoneSqlId
    readerPrincipalId: identity.outputs.identityPrincipalId
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminLoginName: sqlAdminLoginName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Azure AI Search
// ──────────────────────────────────────────────
module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSearchId
    privateDnsZoneId: networking.outputs.privateDnsZoneSearchId
    readerPrincipalIds: [identity.outputs.identityPrincipalId]
    indexContributorPrincipalIds: []
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Container Registry
// ──────────────────────────────────────────────
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSharedId
    privateDnsZoneId: networking.outputs.privateDnsZoneAcrId
    pullPrincipalIds: [identity.outputs.identityPrincipalId]
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Container Apps (MCP Server)
// ──────────────────────────────────────────────
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetContainerAppsId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    logAnalyticsWorkspaceKey: monitoring.outputs.logAnalyticsWorkspaceKey
    containerImage: containerImage
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.sqlDbName
    aiSearchEndpoint: aiSearch.outputs.searchEndpoint
    identityId: identity.outputs.identityId
    identityClientId: identity.outputs.identityClientId
    tags: tags
  }
}

// ──────────────────────────────────────────────
// API Management
// ──────────────────────────────────────────────
module apim 'modules/apim.bicep' = {
  name: 'apim'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetApimId
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    mcpBackendUrl: containerApps.outputs.mcpInternalUrl
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    tags: tags
  }
}

// ──────────────────────────────────────────────
// AI Foundry
// ──────────────────────────────────────────────
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry'
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetFoundryId
    privateDnsZoneOpenAiId: networking.outputs.privateDnsZoneOpenAiId
    privateDnsZoneCognitiveId: networking.outputs.privateDnsZoneCognitiveId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    keyVaultId: keyvault.outputs.keyVaultId
    appInsightsId: monitoring.outputs.appInsightsId
    acrLoginServer: acr.outputs.acrLoginServer
    mcpServerUrl: apim.outputs.mcpApiUrl
    tags: tags
  }
}

// ──────────────────────────────────────────────
// アラートルール (全リソースデプロイ後に作成)
// alertEmailAddress が指定された場合のみデプロイ
// (monitoring モジュールの actionGroupId は alertEmailAddress が非空の場合のみ有効)
// ──────────────────────────────────────────────
module alerts 'modules/alerts.bicep' = if (!empty(alertEmailAddress)) {
  name: 'alerts'
  params: {
    prefix: prefix
    location: location
    tags: tags
    actionGroupId: monitoring.outputs.actionGroupId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    appInsightsId: monitoring.outputs.appInsightsId
    sqlDbId: sql.outputs.sqlDbId
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output vnetId string = networking.outputs.vnetId
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output mcpApiUrl string = apim.outputs.mcpApiUrl
output acrLoginServer string = acr.outputs.acrLoginServer
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.acrLoginServer
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output aiSearchEndpoint string = aiSearch.outputs.searchEndpoint
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output foundryProjectName string = aiFoundry.outputs.foundryProjectName
output aiServicesEndpoint string = aiFoundry.outputs.aiServicesEndpoint
output gpt4oDeploymentName string = aiFoundry.outputs.gpt4oDeploymentName
output embeddingDeploymentName string = aiFoundry.outputs.embeddingDeploymentName
output mcpIdentityClientId string = identity.outputs.identityClientId

