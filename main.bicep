// ==========================================================================
// DNS Private Resolver — Design Comparison
// ==========================================================================
//
// Scenario A (rg-dns-vnetlinks):
//   Hub + spokes + private DNS zone linked to ALL VNets.
//   Every VNet resolves private DNS natively via VNet links.
//   Resolver is deployed for cost-parity comparison only.
//
// Scenario B (rg-dns-forwarding):
//   Hub + spokes + private DNS zone linked to HUB ONLY.
//   Spoke VNets resolve private DNS through a forwarding ruleset
//   that routes queries via the resolver's outbound → inbound path.
//
// Both scenarios use identical hub/spoke topologies so the only
// variable is the DNS resolution mechanism.
// ==========================================================================

targetScope = 'subscription'

param location string
param scenarioAResourceGroup string = 'rg-dns-vnetlinks'
param scenarioBResourceGroup string = 'rg-dns-forwarding'
param zoneName string = 'contoso.internal'

// ── Resource Groups ────────────────────────────────────────────────────

resource rgA 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: scenarioAResourceGroup
  location: location
}

resource rgB 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: scenarioBResourceGroup
  location: location
}

// ========================================================================
//  SCENARIO A — VNet Links
// ========================================================================

module hubA 'modules/hub.bicep' = {
  scope: rgA
  name: 'hubA'
  params: {
    location: location
    hubVnetName: 'vnet-hub-a'
    resolverName: 'dnspr-hub-a'
    deployResolver: true // deployed for cost parity; not required for resolution
  }
}

module spoke1A 'modules/spoke.bicep' = {
  scope: rgA
  name: 'spoke1A'
  params: {
    location: location
    spokeVnetName: 'vnet-spoke1-a'
    spokeVnetAddressPrefix: '10.1.0.0/16'
    spokeSubnetPrefix: '10.1.0.0/24'
    hubVnetId: hubA.outputs.hubVnetId
    hubVnetName: hubA.outputs.hubVnetName
  }
}

module spoke2A 'modules/spoke.bicep' = {
  scope: rgA
  name: 'spoke2A'
  params: {
    location: location
    spokeVnetName: 'vnet-spoke2-a'
    spokeVnetAddressPrefix: '10.2.0.0/16'
    spokeSubnetPrefix: '10.2.0.0/24'
    hubVnetId: hubA.outputs.hubVnetId
    hubVnetName: hubA.outputs.hubVnetName
  }
}

// Hub → Spoke peerings (Scenario A)
module hubToSpoke1A 'modules/hubToSpokePeering.bicep' = {
  scope: rgA
  name: 'hubToSpoke1A'
  params: {
    hubVnetName: hubA.outputs.hubVnetName
    spokeVnetId: spoke1A.outputs.spokeVnetId
    spokeVnetName: spoke1A.outputs.spokeVnetName
  }
}

module hubToSpoke2A 'modules/hubToSpokePeering.bicep' = {
  scope: rgA
  name: 'hubToSpoke2A'
  params: {
    hubVnetName: hubA.outputs.hubVnetName
    spokeVnetId: spoke2A.outputs.spokeVnetId
    spokeVnetName: spoke2A.outputs.spokeVnetName
  }
}

module zoneA 'modules/privatezone.bicep' = {
  scope: rgA
  name: 'zoneA'
  params: {
    zoneName: zoneName
  }
}

// Link private DNS zone to hub + both spokes
module vnetLinksA 'modules/vnetlinks.bicep' = {
  scope: rgA
  name: 'vnetLinksA'
  params: {
    privateDnsZoneId: zoneA.outputs.privateDnsZoneId
    vnetLinks: [
      { name: 'link-hub-a', vnetId: hubA.outputs.hubVnetId }
      { name: 'link-spoke1-a', vnetId: spoke1A.outputs.spokeVnetId }
      { name: 'link-spoke2-a', vnetId: spoke2A.outputs.spokeVnetId }
    ]
  }
}

// ========================================================================
//  SCENARIO B — Forwarding Rulesets
// ========================================================================

module hubB 'modules/hub.bicep' = {
  scope: rgB
  name: 'hubB'
  params: {
    location: location
    hubVnetName: 'vnet-hub-b'
    resolverName: 'dnspr-hub-b'
    deployResolver: true
  }
}

module spoke1B 'modules/spoke.bicep' = {
  scope: rgB
  name: 'spoke1B'
  params: {
    location: location
    spokeVnetName: 'vnet-spoke1-b'
    spokeVnetAddressPrefix: '10.1.0.0/16'
    spokeSubnetPrefix: '10.1.0.0/24'
    hubVnetId: hubB.outputs.hubVnetId
    hubVnetName: hubB.outputs.hubVnetName
  }
}

module spoke2B 'modules/spoke.bicep' = {
  scope: rgB
  name: 'spoke2B'
  params: {
    location: location
    spokeVnetName: 'vnet-spoke2-b'
    spokeVnetAddressPrefix: '10.2.0.0/16'
    spokeSubnetPrefix: '10.2.0.0/24'
    hubVnetId: hubB.outputs.hubVnetId
    hubVnetName: hubB.outputs.hubVnetName
  }
}

// Hub → Spoke peerings (Scenario B)
module hubToSpoke1B 'modules/hubToSpokePeering.bicep' = {
  scope: rgB
  name: 'hubToSpoke1B'
  params: {
    hubVnetName: hubB.outputs.hubVnetName
    spokeVnetId: spoke1B.outputs.spokeVnetId
    spokeVnetName: spoke1B.outputs.spokeVnetName
  }
}

module hubToSpoke2B 'modules/hubToSpokePeering.bicep' = {
  scope: rgB
  name: 'hubToSpoke2B'
  params: {
    hubVnetName: hubB.outputs.hubVnetName
    spokeVnetId: spoke2B.outputs.spokeVnetId
    spokeVnetName: spoke2B.outputs.spokeVnetName
  }
}

module zoneB 'modules/privatezone.bicep' = {
  scope: rgB
  name: 'zoneB'
  params: {
    zoneName: zoneName
  }
}

// Link private DNS zone to HUB ONLY (not spokes)
module vnetLinksB 'modules/vnetlinks.bicep' = {
  scope: rgB
  name: 'vnetLinksB'
  params: {
    privateDnsZoneId: zoneB.outputs.privateDnsZoneId
    vnetLinks: [
      { name: 'link-hub-b', vnetId: hubB.outputs.hubVnetId }
    ]
  }
}

// Forwarding ruleset linked to spoke VNets
module forwardingB 'modules/forwardingrules.bicep' = {
  scope: rgB
  name: 'forwardingB'
  params: {
    location: location
    outboundEndpointId: hubB.outputs.outboundEndpointId
    inboundEndpointIp: hubB.outputs.inboundEndpointIp
    zoneName: zoneName
    spokeVnets: [
      { name: 'link-spoke1-b', vnetId: spoke1B.outputs.spokeVnetId }
      { name: 'link-spoke2-b', vnetId: spoke2B.outputs.spokeVnetId }
    ]
  }
}

// ── Outputs ────────────────────────────────────────────────────────────

output scenarioA object = {
  resourceGroup: scenarioAResourceGroup
  mechanism: 'VNet Links — private DNS zone linked to all VNets'
  hubVnet: hubA.outputs.hubVnetName
  spoke1Vnet: spoke1A.outputs.spokeVnetName
  spoke2Vnet: spoke2A.outputs.spokeVnetName
  dnsZone: zoneA.outputs.privateDnsZoneName
}

output scenarioB object = {
  resourceGroup: scenarioBResourceGroup
  mechanism: 'Forwarding Rulesets — ruleset linked to spoke VNets, zone linked to hub only'
  hubVnet: hubB.outputs.hubVnetName
  spoke1Vnet: spoke1B.outputs.spokeVnetName
  spoke2Vnet: spoke2B.outputs.spokeVnetName
  dnsZone: zoneB.outputs.privateDnsZoneName
  resolverInboundIp: hubB.outputs.inboundEndpointIp
}
