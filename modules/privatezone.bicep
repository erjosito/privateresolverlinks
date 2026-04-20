// Private DNS Zone with a sample A record

param zoneName string = 'contoso.internal'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName
  location: 'global'
}

resource sampleRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: 'test-app'
  properties: {
    ttl: 300
    aRecords: [
      {
        ipv4Address: '10.0.1.10'
      }
    ]
  }
}

resource wildcardRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: 'db'
  properties: {
    ttl: 300
    aRecords: [
      {
        ipv4Address: '10.0.1.20'
      }
    ]
  }
}

output privateDnsZoneId string = privateDnsZone.id
output privateDnsZoneName string = privateDnsZone.name
