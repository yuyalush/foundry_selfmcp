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

// text-embedding-3-large デプロイ (RAG / AI Search 統合用)
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: 'text-embedding-3-large'
  dependsOn: [gpt4oDeployment]
  sku: {
    name: 'GlobalStandard'
    capacity: 30 // 30K TPM
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
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
    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
    }
  }
}

// ──────────────────────────────────────────────
// Hub → AI Services 接続 (モデルカタログ連携)
// ──────────────────────────────────────────────
resource hubAiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: foundryHub
  name: '${prefix}-aiservices-conn'
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
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
    applicationInsights: appInsightsId
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
// Diagnostic Settings - AI Services → Log Analytics
// ──────────────────────────────────────────────
resource aiServicesDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-aiservices'
  scope: aiServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Diagnostic Settings - Foundry Hub → Log Analytics
// ──────────────────────────────────────────────
resource foundryHubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-foundryhub'
  scope: foundryHub
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
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
output gpt4oDeploymentName string = gpt4oDeployment.name
output embeddingDeploymentName string = embeddingDeployment.name
output foundryHubId string = foundryHub.id
output foundryHubName string = foundryHub.name
output foundryHubPrincipalId string = foundryHub.identity.principalId
output foundryProjectId string = foundryProject.id
output foundryProjectName string = foundryProject.name
output foundryProjectPrincipalId string = foundryProject.identity.principalId
