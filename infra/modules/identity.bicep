// ================================================================
// identity.bicep - MCP Server 用 User-Assigned Managed Identity
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// User-Assigned Managed Identity
// ──────────────────────────────────────────────
resource mcpIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-id-mcp'
  location: location
  tags: tags
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output identityId string = mcpIdentity.id
output identityPrincipalId string = mcpIdentity.properties.principalId
output identityClientId string = mcpIdentity.properties.clientId
