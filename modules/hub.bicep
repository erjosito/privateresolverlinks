// Hub VNet with DNS Private Resolver (inbound + outbound endpoints)

param location string
param hubVnetName string = 'vnet-hub'
param hubVnetAddressPrefix string = '10.0.0.0/16'
param resolverName string = 'dnspr-hub'
param deployResolver bool = true

var inboundSubnetName = 'snet-dns-inbound'
var outboundSubnetName = 'snet-dns-outbound'
var defaultSubnetName = 'snet-default'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: inboundSubnetName
        properties: {
          addressPrefix: '10.0.0.0/28'
          delegations: [
            {
              name: 'dns-resolver-delegation'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: outboundSubnetName
        properties: {
          addressPrefix: '10.0.0.16/28'
          delegations: [
            {
              name: 'dns-resolver-delegation'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: defaultSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = if (deployResolver) {
  name: resolverName
  location: location
  properties: {
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = if (deployResolver) {
  parent: resolver
  name: 'in-endpoint'
  location: location
  properties: {
    ipConfigurations: [
      {
        privateIpAllocationMethod: 'Dynamic'
        subnet: {
          id: hubVnet.properties.subnets[0].id
        }
      }
    ]
  }
}

resource outboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = if (deployResolver) {
  parent: resolver
  name: 'out-endpoint'
  location: location
  properties: {
    subnet: {
      id: hubVnet.properties.subnets[1].id
    }
  }
}

output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output inboundEndpointIp string = deployResolver && inboundEndpoint != null ? inboundEndpoint.properties.ipConfigurations[0].privateIpAddress : ''
output outboundEndpointId string = deployResolver ? outboundEndpoint.id : ''
