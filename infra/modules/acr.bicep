// ================================================================
// acr.bicep - Azure Container Registry + Private Endpoint
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Private Endpoint 配置先サブネット ID')
param subnetId string

@description('Private DNS Zone ID (azurecr.io)')
param privateDnsZoneId string

@description('ACR からイメージを Pull するマネージド ID のプリンシパル ID 一覧')
param pullPrincipalIds array = []

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Container Registry
// ──────────────────────────────────────────────
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: take(padLeft('${toLower(replace(prefix, '-', ''))}acr', 5, 'a'), 50)
  location: location
  tags: tags
  sku: {
    name: 'Premium' // Premium が Private Link に対応
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// ──────────────────────────────────────────────
// RBAC - AcrPull ロール
// ──────────────────────────────────────────────
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource pullRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in pullPrincipalIds: {
    scope: acr
    name: guid(acr.id, principalId, acrPullRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ──────────────────────────────────────────────
// Private Endpoint
// ──────────────────────────────────────────────
resource peAcr 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-acr'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-plsc-acr'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: ['registry']
        }
      }
    ]
  }
}

resource peAcrDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peAcr
  name: 'dnsgroupacr'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'acr'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output acrId string = acr.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
