// ================================================================
// sql.bicep - Azure SQL Database (Serverless) + Private Endpoint
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('Private Endpoint 配置先サブネット ID')
param subnetId string

@description('Private DNS Zone ID (database.windows.net)')
param privateDnsZoneId string

@description('SQL DB への読み取り専用アクセスを許可するマネージド ID のプリンシパル ID')
param readerPrincipalId string

@description('Entra ID SQL 管理者のオブジェクト ID')
param sqlAdminObjectId string

@description('Entra ID SQL 管理者のログイン名 (UPN またはグループ名)')
param sqlAdminLoginName string

@description('Log Analytics ワークスペース ID (診断設定用)')
param logAnalyticsWorkspaceId string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// SQL Server
// ──────────────────────────────────────────────
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${prefix}-sql'
  location: location
  tags: tags
  properties: {
    // SQL 認証を完全に無効化
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminLoginName
      sid: sqlAdminObjectId
      tenantId: tenant().tenantId
      principalType: 'Group'
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

// ──────────────────────────────────────────────
// SQL Database (Serverless GP, 1-4 vCores)
// ──────────────────────────────────────────────
resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: '${prefix}-db'
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'Japanese_CI_AS'
    maxSizeBytes: 34359738368 // 32 GB
    autoPauseDelay: 60         // 60分で自動一時停止
    minCapacity: '0.5'
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

// ──────────────────────────────────────────────
// Private Endpoint
// ──────────────────────────────────────────────
resource peSql 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-sql'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${prefix}-plsc-sql'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

resource peSqlDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peSql
  name: 'dnsgroupsql'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'database'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Transparent Data Encryption (明示的に有効化)
// ──────────────────────────────────────────────
resource tde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDb
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// ──────────────────────────────────────────────
// Azure RBAC: SQL Server Reader (ARM レベル)
// ※ DB レベルの db_datareader ロールは schema.sql の
//   database/schema.sql にある SQL スクリプトで付与する
// ──────────────────────────────────────────────
var sqlServerReaderRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
resource sqlReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sqlServer.id, readerPrincipalId, sqlServerReaderRoleId)
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sqlServerReaderRoleId)
    principalId: readerPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ──────────────────────────────────────────────
// Diagnostics - SQL DB スロークエリ監査ログ → Log Analytics
// ──────────────────────────────────────────────
resource sqlDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlDb
  name: 'sqldb-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        // クエリ実行統計 (Query Store ランタイム統計 - 長時間クエリの特定に活用)
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        // クエリ待機統計 (Query Store 待機統計 - パフォーマンスボトルネック分析に活用)
        category: 'QueryStoreWaitStatistics'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        // CPU/DTU 等のメトリクス (SQL CPU アラート用)
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
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDbId string = sqlDb.id
output sqlDbName string = sqlDb.name
