// ================================================================
// ai-search.bicep - Azure AI Search + Private Endpoint
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Private Endpoint 配置先サブネット ID')
param subnetId string

@description('Private DNS Zone ID (search.windows.net)')
param privateDnsZoneId string

@description('AI Search への読み取りアクセスを許可するマネージド ID のプリンシパル ID 一覧')
param readerPrincipalIds array = []

@description('AI Search へのインデックス書き込みアクセスを許可するプリンシパル ID 一覧')
param indexContributorPrincipalIds array = []

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Azure AI Search
// ──────────────────────────────────────────────
resource searchService 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: '${prefix}-search'
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
    disableLocalAuth: false // メタデータ初期ロード時のみ API キー使用可
    semanticSearch: 'standard'
  }
}

// ──────────────────────────────────────────────
// RBAC - Search Index Data Reader
// ──────────────────────────────────────────────
var searchIndexDataReaderRoleId = '1407120a-92aa-4202-b7e9-c0e197c71c8f'

resource readerRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in readerPrincipalIds: {
    scope: searchService
    name: guid(searchService.id, principalId, searchIndexDataReaderRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataReaderRoleId)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ──────────────────────────────────────────────
// RBAC - Search Index Data Contributor (メタデータ初期ロード用)
// ──────────────────────────────────────────────
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'

resource indexContributorRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in indexContributorPrincipalIds: {
    scope: searchService
    name: guid(searchService.id, principalId, searchIndexDataContributorRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ──────────────────────────────────────────────
// Private Endpoint
// ──────────────────────────────────────────────
resource peSearch 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-search'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-plsc-search'
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: ['searchService']
        }
      }
    ]
  }
}

resource peSearchDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peSearch
  name: 'dnsgroupsearch'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'search'
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
output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
output searchEndpoint string = 'https://${searchService.name}.search.windows.net'
