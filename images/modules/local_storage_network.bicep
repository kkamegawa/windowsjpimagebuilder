@description('Network location')
param location string = resourceGroup().location
@description('Network Name')
param vnetName string
@description('Network Address range')
param vnetAddressPrefix string = '10.3.0.0/16'
@description('Storage Account Name')
param storageAccountName string

var subnets = [
  {
    name: 'default'
    subnetPrefix: '10.3.0.0/24'
    serviceEndpoints: [
    ]
  }
  {
    name: 'Storage'
    subnetPrefix: '10.3.1.0/28'
    serviceEndpoints: [
      'Microsoft.Storage'
    ]
  }
]
var nsgGroups = [
  {
    name: 'httpinbound1'
    description: 'inbound http via xxx'
    destinationAddressPrefix: 'VirtualNetwork'
    destinationPortRanges: [
      '80'
      '443'
    ]
    direction: 'inbound'
    priority: 100
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
  {
    name: 'httpinbound2'
    description: 'inbound http via xxx'
    destinationAddressPrefix: 'VirtualNetwork'
    destinationPortRanges: [
      '80'
      '443'
    ]
    direction: 'inbound'
    priority: 110
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
]

resource nsgforSubnet 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'subnetNetworkSecurity'
  location: location
  properties: {
    securityRules: [ for nsg in nsgGroups:{
      name: nsg.name
      properties: {
        access: 'Allow'
        description: nsg.description
        destinationAddressPrefix: nsg.destinationAddressPrefix
        destinationPortRanges: nsg.destinationPortRanges
        direction: 'Inbound'
        priority: nsg.priority
        protocol: nsg.protocol
        sourceAddressPrefix: nsg.sourceAddressPrefix
        sourcePortRange: nsg.sourcePortRange
      }
    }]
  }
}

var nsgGroupID = nsgforSubnet.id

resource vnetsubnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' = [for (subnet, i) in subnets : {
  name: subnet.name
  parent: virtualNetwork
  properties: {
    addressPrefix: subnet.subnetPrefix
    networkSecurityGroup:{
      id: nsgGroupID
    }
    serviceEndpoints: [for endpoint in subnet.serviceEndpoints: {
      service: endpoint
    }]
  }
}]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets:[ for subnet in subnets:{
      name: subnet.name
      properties:{
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}
