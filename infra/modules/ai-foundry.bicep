// ================================================================
// ai-foundry.bicep - Azure AI Foundry Hub + Project + GPT-4o デプロイ
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Private Endpoint 配置先サブネット ID')
param subnetId string

@description('Private DNS Zone ID (openai.azure.com)')
param privateDnsZoneOpenAiId string

@description('Private DNS Zone ID (cognitiveservices.azure.com)')
param privateDnsZoneCognitiveId string

@description('Log Analytics ワークスペース ID')
param logAnalyticsWorkspaceId string

@description('Key Vault リソース ID')
param keyVaultId string

@description('Application Insights リソース ID')
param appInsightsId string

@description('ACR ログインサーバ名')
param acrLoginServer string

@description('MCP Server URL (APIM Gateway 経由)')
param mcpServerUrl string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// AI Services (Foundry Hub のバッキングリソース)
// ──────────────────────────────────────────────
resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${prefix}-aiservices'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    customSubDomainName: '${prefix}-aiservices'
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// GPT-4o デプロイ
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10 // 10K TPM
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// ──────────────────────────────────────────────
// AI Foundry Hub
// ──────────────────────────────────────────────
resource foundryHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: '${prefix}-hub'
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: '${prefix} Foundry Hub'
    description: 'MCP PoC - Azure AI Foundry Hub'
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    containerRegistry: null
    publicNetworkAccess: 'Disabled'
    storageAccount: null // Hub は Storage 不要
  }
}

// ──────────────────────────────────────────────
// AI Foundry Project
// ──────────────────────────────────────────────
resource foundryProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: '${prefix}-project'
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: '${prefix} Data Agent Project'
    description: 'データ照会エージェント用プロジェクト'
    hubResourceId: foundryHub.id
    publicNetworkAccess: 'Disabled'
  }
}

// ──────────────────────────────────────────────
// Private Endpoint - AI Services
// ──────────────────────────────────────────────
resource peAiServices 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-aiservices'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-plsc-aiservices'
        properties: {
          privateLinkServiceId: aiServices.id
          groupIds: ['account']
        }
      }
    ]
  }
}

resource peAiServicesDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peAiServices
  name: 'dnsgroupaiservices'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'openai'
        properties: {
          privateDnsZoneId: privateDnsZoneOpenAiId
        }
      }
      {
        name: 'cognitive'
        properties: {
          privateDnsZoneId: privateDnsZoneCognitiveId
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output aiServicesId string = aiServices.id
output aiServicesName string = aiServices.name
output aiServicesPrincipalId string = aiServices.identity.principalId
output aiServicesEndpoint string = aiServices.properties.endpoint
output foundryHubId string = foundryHub.id
output foundryHubName string = foundryHub.name
output foundryProjectId string = foundryProject.id
output foundryProjectName string = foundryProject.name
output foundryProjectPrincipalId string = foundryProject.identity.principalId
