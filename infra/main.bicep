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

@description('タグ')
param tags object = {
  environment: environmentName
  project: 'foundry-mcp-poc'
  managedBy: 'azd'
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
  }
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
  }
}

// ──────────────────────────────────────────────
// Key Vault (先に作成してシークレット格納先を確保)
// ──────────────────────────────────────────────
module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  dependsOn: [networking]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSharedId
    privateDnsZoneId: networking.outputs.privateDnsZoneKeyVaultId
    secretReaderPrincipalIds: []
    tags: tags
  }
}

// ──────────────────────────────────────────────
// SQL Database
// ──────────────────────────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'sql'
  dependsOn: [networking]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSqlId
    privateDnsZoneId: networking.outputs.privateDnsZoneSqlId
    readerPrincipalId: containerApps.outputs.mcpIdentityPrincipalId
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminLoginName: sqlAdminLoginName
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Azure AI Search
// ──────────────────────────────────────────────
module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  dependsOn: [networking]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSearchId
    privateDnsZoneId: networking.outputs.privateDnsZoneSearchId
    readerPrincipalIds: [containerApps.outputs.mcpIdentityPrincipalId]
    indexContributorPrincipalIds: []
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Container Registry
// ──────────────────────────────────────────────
module acr 'modules/acr.bicep' = {
  name: 'acr'
  dependsOn: [networking]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSharedId
    privateDnsZoneId: networking.outputs.privateDnsZoneAcrId
    pullPrincipalIds: [containerApps.outputs.mcpIdentityPrincipalId]
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Container Apps (MCP Server)
// ──────────────────────────────────────────────
module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  dependsOn: [networking, monitoring]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetContainerAppsId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    logAnalyticsWorkspaceKey: listKeys(monitoring.outputs.logAnalyticsId, '2023-09-01').primarySharedKey
    containerImage: containerImage
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.sqlDbName
    aiSearchEndpoint: aiSearch.outputs.searchEndpoint
    tags: tags
  }
}

// ──────────────────────────────────────────────
// API Management
// ──────────────────────────────────────────────
module apim 'modules/apim.bicep' = {
  name: 'apim'
  dependsOn: [networking, containerApps]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetApimId
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    mcpBackendUrl: containerApps.outputs.mcpInternalUrl
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    tags: tags
  }
}

// ──────────────────────────────────────────────
// AI Foundry
// ──────────────────────────────────────────────
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry'
  dependsOn: [networking, keyvault, monitoring]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetFoundryId
    privateDnsZoneOpenAiId: networking.outputs.privateDnsZoneOpenAiId
    privateDnsZoneCognitiveId: networking.outputs.privateDnsZoneOpenAiId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsId
    keyVaultId: keyvault.outputs.keyVaultId
    appInsightsId: monitoring.outputs.appInsightsId
    acrLoginServer: acr.outputs.acrLoginServer
    mcpServerUrl: apim.outputs.mcpApiUrl
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Key Vault シークレット閲覧者に MCP Identity を追加 (後付けパッチ)
// ──────────────────────────────────────────────
module keyvaultPatch 'modules/keyvault.bicep' = {
  name: 'keyvault-patch'
  dependsOn: [containerApps]
  params: {
    prefix: prefix
    location: location
    subnetId: networking.outputs.subnetSharedId
    privateDnsZoneId: networking.outputs.privateDnsZoneKeyVaultId
    secretReaderPrincipalIds: [containerApps.outputs.mcpIdentityPrincipalId]
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output vnetId string = networking.outputs.vnetId
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output mcpApiUrl string = apim.outputs.mcpApiUrl
output acrLoginServer string = acr.outputs.acrLoginServer
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output aiSearchEndpoint string = aiSearch.outputs.searchEndpoint
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output foundryProjectName string = aiFoundry.outputs.foundryProjectName
output mcpIdentityClientId string = containerApps.outputs.mcpIdentityClientId
