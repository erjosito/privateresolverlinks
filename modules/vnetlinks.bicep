// Scenario A: Link private DNS zone directly to each VNet
// Every linked VNet can resolve records in the private DNS zone natively.

param privateDnsZoneId string
param vnetLinks array // [ { name: 'link-hub', vnetId: '...' }, { name: 'link-spoke1', vnetId: '...' } ]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: last(split(privateDnsZoneId, '/'))
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for link in vnetLinks: {
    parent: privateDnsZone
    name: link.name
    location: 'global'
    properties: {
      virtualNetwork: {
        id: link.vnetId
      }
      registrationEnabled: false
    }
  }
]
