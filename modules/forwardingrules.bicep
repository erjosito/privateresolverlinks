// Scenario B: Forwarding ruleset linked to spoke VNets
// Spokes resolve private DNS via: spoke → Azure DNS → forwarding ruleset →
// outbound endpoint → inbound endpoint → private DNS zone (linked to hub only)

param location string
param outboundEndpointId string
param inboundEndpointIp string
param zoneName string = 'contoso.internal'
param spokeVnets array // [ { name: 'link-spoke1', vnetId: '...' }, ... ]

resource forwardingRuleset 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: 'dnsfrs-hub'
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: outboundEndpointId
      }
    ]
  }
}

// Forward the private zone domain to the resolver's inbound endpoint
resource forwardingRule 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  parent: forwardingRuleset
  name: 'rule-${replace(zoneName, '.', '-')}'
  properties: {
    domainName: '${zoneName}.'
    targetDnsServers: [
      {
        ipAddress: inboundEndpointIp
        port: 53
      }
    ]
    forwardingRuleState: 'Enabled'
  }
}

// Link the forwarding ruleset to each spoke VNet
resource rulesetVnetLink 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = [
  for spoke in spokeVnets: {
    parent: forwardingRuleset
    name: spoke.name
    properties: {
      virtualNetwork: {
        id: spoke.vnetId
      }
    }
  }
]
