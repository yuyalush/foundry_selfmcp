// ================================================================
// networking.bicep - VNET・サブネット・NSG・Private DNS Zone
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('タグ')
param tags object = {}

// ──────────────────────────────────────────────
// VNET
// ──────────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: '${prefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'snet-foundry'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-apim'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: nsgApim.id }
        }
      }
      {
        name: 'snet-container-apps'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-search'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-sql'
        properties: {
          addressPrefix: '10.0.5.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-shared'
        properties: {
          addressPrefix: '10.0.6.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.7.0/27'
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// NSG - APIM サブネット用
// ──────────────────────────────────────────────
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-apim'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAPIMManagementInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowAPIMClientInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// Private DNS Zones
// ──────────────────────────────────────────────
var privateDnsZoneNames = [
  'privatelink${environment().suffixes.sqlServerHostname}'  // SQL
  'privatelink.search.windows.net'                          // AI Search
  'privatelink.vaultcore.azure.net'                         // Key Vault
  'privatelink.monitor.azure.com'                           // Monitor
  'privatelink.oms.opinsights.azure.com'                    // Log Analytics
  'privatelink.ods.opinsights.azure.com'                    // Log Analytics
  'privatelink.azurecr.io'                                  // Container Registry
  'privatelink.cognitiveservices.azure.com'                 // AI Services / Foundry
  'privatelink.openai.azure.com'                            // OpenAI
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [
  for zoneName in privateDnsZoneNames: {
    name: zoneName
    location: 'global'
    tags: tags
  }
]

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for (zoneName, i) in privateDnsZoneNames: {
    parent: privateDnsZones[i]
    name: '${prefix}-link'
    location: 'global'
    properties: {
      virtualNetwork: { id: vnet.id }
      registrationEnabled: false
    }
  }
]

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────
output vnetId string = vnet.id
output vnetName string = vnet.name

output subnetFoundryId string = vnet.properties.subnets[0].id
output subnetApimId string = vnet.properties.subnets[1].id
output subnetContainerAppsId string = vnet.properties.subnets[2].id
output subnetSearchId string = vnet.properties.subnets[3].id
output subnetSqlId string = vnet.properties.subnets[4].id
output subnetSharedId string = vnet.properties.subnets[5].id

output privateDnsZoneSqlId string = privateDnsZones[0].id
output privateDnsZoneSearchId string = privateDnsZones[1].id
output privateDnsZoneKeyVaultId string = privateDnsZones[2].id
output privateDnsZoneAcrId string = privateDnsZones[6].id
output privateDnsZoneOpenAiId string = privateDnsZones[8].id
