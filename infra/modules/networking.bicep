// ================================================================
// networking.bicep - VNET・サブネット・NSG・Private DNS Zone・Bastion・NSG Flow Logs
// ================================================================
@description('リソース名のプレフィックス')
param prefix string

@description('デプロイ先リージョン')
param location string

@description('タグ')
param tags object = {}

@description('NSG フロー ログ Traffic Analytics 送信先 Log Analytics ワークスペース リソース ID (省略可)')
param logAnalyticsWorkspaceId string = ''

@description('NSG フロー ログ Traffic Analytics 送信先 Log Analytics ワークスペース ID (GUID, 省略可)')
param logAnalyticsWorkspaceCustomerId string = ''

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
// NSG - AI Foundry サブネット用 (Private Endpoint)
// ──────────────────────────────────────────────
resource nsgFoundry 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-foundry'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromContainerApps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpsFromApim'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '*'
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
// NSG - Container Apps サブネット用
// ──────────────────────────────────────────────
resource nsgContainerApps 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-container-apps'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromApim'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
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
// NSG - AI Search サブネット用 (Private Endpoint)
// ──────────────────────────────────────────────
resource nsgSearch 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-search'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromContainerApps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '*'
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
// NSG - SQL サブネット用 (Private Endpoint)
// ──────────────────────────────────────────────
resource nsgSql 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-sql'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSqlFromContainerApps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '*'
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
// NSG - Shared サブネット用 (Private Endpoint: Key Vault / Monitor / ACR)
// ──────────────────────────────────────────────
resource nsgShared 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-shared'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsFromContainerApps'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpsFromApim'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.2.0/24'
          destinationAddressPrefix: '*'
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
// NSG - Azure Bastion サブネット用 (必須ルール)
// https://learn.microsoft.com/azure/bastion/bastion-nsg
// ──────────────────────────────────────────────
resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${prefix}-nsg-bastion'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ── Inbound ──────────────────────────────
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['8080', '5701']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      // ── Outbound ─────────────────────────────
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389']
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
        }
      }
      {
        name: 'AllowBastionCommunicationOutbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: ['8080', '5701']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowGetSessionInformationOutbound'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

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
          networkSecurityGroup: { id: nsgFoundry.id }
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
          networkSecurityGroup: { id: nsgContainerApps.id }
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
          networkSecurityGroup: { id: nsgSearch.id }
        }
      }
      {
        name: 'snet-sql'
        properties: {
          addressPrefix: '10.0.5.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: { id: nsgSql.id }
        }
      }
      {
        name: 'snet-shared'
        properties: {
          addressPrefix: '10.0.6.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: { id: nsgShared.id }
        }
      }
      {
        // Standard SKU Bastion requires /26 or larger
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.7.0/26'
          networkSecurityGroup: { id: nsgBastion.id }
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
// Azure Bastion (Standard SKU)
// ──────────────────────────────────────────────
resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${prefix}-pip-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: '${prefix}-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    enableIpConnect: true
    enableShareableLink: false
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          // Reference subnet by name rather than array index to avoid fragility
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureBastionSubnet') }
          publicIPAddress: { id: bastionPip.id }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ──────────────────────────────────────────────
// NSG フロー ログ用ストレージ アカウント
// ストレージ名: 英数字のみ・最大 24 文字 (prefix 16 + 'flowlogs' 8)
// ──────────────────────────────────────────────
var flowLogStorageAccountName = '${take(toLower(replace(prefix, '-', '')), 16)}flowlogs'

resource flowLogStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: flowLogStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// ──────────────────────────────────────────────
// Network Watcher
// ──────────────────────────────────────────────
resource networkWatcher 'Microsoft.Network/networkWatchers@2024-01-01' = {
  name: '${prefix}-nw'
  location: location
  tags: tags
}

// ──────────────────────────────────────────────
// NSG フロー ログ (Traffic Analytics with Log Analytics / Application Insights)
// logAnalyticsWorkspaceId が指定された場合は Traffic Analytics を有効化
// ──────────────────────────────────────────────
var nsgIds = [
  nsgApim.id
  nsgFoundry.id
  nsgContainerApps.id
  nsgSearch.id
  nsgSql.id
  nsgShared.id
]

var nsgShortNames = [
  'apim'
  'foundry'
  'container-apps'
  'search'
  'sql'
  'shared'
]

// logAnalyticsWorkspaceId と logAnalyticsWorkspaceCustomerId は必ずペアで指定すること
var trafficAnalyticsEnabled = !empty(logAnalyticsWorkspaceId) && !empty(logAnalyticsWorkspaceCustomerId)

resource flowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-01-01' = [
  for (nsgId, i) in nsgIds: {
    parent: networkWatcher
    name: 'fl-${prefix}-${nsgShortNames[i]}'
    location: location
    properties: {
      enabled: true
      storageId: flowLogStorage.id
      targetResourceId: nsgId
      retentionPolicy: {
        days: 30
        enabled: true
      }
      format: {
        type: 'JSON'
        version: 2
      }
      flowAnalyticsConfiguration: {
        networkWatcherFlowAnalyticsConfiguration: {
          enabled: trafficAnalyticsEnabled
          workspaceId: trafficAnalyticsEnabled ? logAnalyticsWorkspaceCustomerId : ''
          workspaceRegion: trafficAnalyticsEnabled ? location : ''
          workspaceResourceId: trafficAnalyticsEnabled ? logAnalyticsWorkspaceId : ''
          trafficAnalyticsInterval: 60
        }
      }
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
output privateDnsZoneCognitiveId string = privateDnsZones[7].id
output privateDnsZoneOpenAiId string = privateDnsZones[8].id

output bastionName string = bastion.name
