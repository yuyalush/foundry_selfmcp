// ================================================================
// keyvault-rbac.bicep - Key Vault への RBAC ロール割り当て (単体)
//
// main.bicep から循環依存なしに後付けで RBAC を付与するためのヘルパーモジュール。
// existing リソース参照はモジュール境界内で解決される。
// ================================================================
@description('Key Vault 名')
param keyVaultName string

@description('ロールを付与するマネージド ID のプリンシパル ID')
param principalId string

@description('Azure RBAC ロール定義 ID (GUID のみ、subscriptionResourceId は内部で解決)')
param roleDefinitionId string

// ──────────────────────────────────────────────
// 対象 Key Vault への参照
// ──────────────────────────────────────────────
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// ──────────────────────────────────────────────
// ロール割り当て
// ──────────────────────────────────────────────
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
