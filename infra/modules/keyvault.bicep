// ================================================================
// keyvault.bicep - Azure Key Vault + Private Endpoint
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Private Endpoint 配置先サブネット ID')
param subnetId string

@description('Private DNS Zone ID (vaultcore.azure.net)')
param privateDnsZoneId string

@description('Key Vault へのアクセスを許可するマネージド ID のプリンシパル ID 一覧')
param secretReaderPrincipalIds array = []

@description('Application Insights 接続文字列 (Key Vault にシークレットとして格納)')
@secure()
param appInsightsConnectionString string = ''

@description('Log Analytics ワークスペース ID (診断設定用)')
param logAnalyticsWorkspaceId string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// Key Vault
// ──────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${prefix}-kv'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// ──────────────────────────────────────────────
// RBAC - シークレット閲覧者ロール付与
// ──────────────────────────────────────────────
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource secretReaderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in secretReaderPrincipalIds: {
    scope: keyVault
    name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ──────────────────────────────────────────────
// Private Endpoint
// ──────────────────────────────────────────────
resource peKeyVault 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-kv'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-plsc-kv'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource peKeyVaultDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peKeyVault
  name: 'dnsgroupkv'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vaultcore'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Secrets - Application Insights 接続文字列
// ──────────────────────────────────────────────
resource secretAppInsights 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(appInsightsConnectionString)) {
  parent: keyVault
  name: 'appinsights-connection-string'
  properties: {
    value: appInsightsConnectionString
    attributes: {
      enabled: true
    }
  }
}

// ──────────────────────────────────────────────
// Diagnostics - Key Vault 監査ログ → Log Analytics
// ──────────────────────────────────────────────
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'kv-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        // 監査ログ: すべての操作 (アクセス・拒否・管理操作)
        category: 'AuditEvent'
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
// Outputs
// ──────────────────────────────────────────────
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
