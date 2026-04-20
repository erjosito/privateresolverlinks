# DNS Private Resolver — Design Comparison

Compare two Azure DNS resolution approaches in identical hub-and-spoke topologies.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  SCENARIO A: VNet Links            SCENARIO B: Forwarding Rulesets  │
│  (rg-dns-vnetlinks)                (rg-dns-forwarding)              │
│                                                                      │
│  ┌─────────┐                       ┌─────────┐                      │
│  │  Hub     │ ◄── VNet Link ──►    │  Hub    │ ◄── VNet Link ──►   │
│  │  VNet    │     to DNS Zone      │  VNet   │     to DNS Zone     │
│  │ Resolver │                      │ Resolver│                      │
│  └────┬─────┘                      └────┬────┘                      │
│       │ peering                         │ peering                   │
│  ┌────┴────┐                       ┌────┴────┐                      │
│  │ Spoke 1 │ ◄── VNet Link ──►    │ Spoke 1 │ ◄── Ruleset Link    │
│  │ Spoke 2 │     to DNS Zone      │ Spoke 2 │     (no zone link)  │
│  └─────────┘                       └─────────┘                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Scenario A — VNet Links

- Private DNS zone is linked to **all** VNets (hub + spokes)
- Every VNet resolves records natively via Azure-provided DNS
- DNS Private Resolver is deployed for cost parity but **not required**
- Simplest configuration; scales linearly with VNet count

## Scenario B — Forwarding Rulesets

- Private DNS zone is linked to **hub only**
- Forwarding ruleset with VNet links to spoke VNets
- Resolution flow: `spoke client → Azure DNS → forwarding ruleset → outbound endpoint → inbound endpoint → private zone`
- Spokes use **default Azure-provided DNS** (no custom DNS servers)
- Centralised control: add/remove zones from the ruleset without touching spoke VNets

## Deploy

```bash
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters parameters/main.bicepparam
```

## File Structure

```
├── main.bicep                    # Subscription-scoped orchestrator
├── parameters/
│   └── main.bicepparam           # Deployment parameters
├── modules/
│   ├── hub.bicep                 # Hub VNet + DNS Private Resolver
│   ├── spoke.bicep               # Spoke VNet + spoke→hub peering
│   ├── hubToSpokePeering.bicep   # Hub→spoke peering
│   ├── privatezone.bicep         # Private DNS zone + sample records
│   ├── vnetlinks.bicep           # VNet links to private DNS zone
│   └── forwardingrules.bicep     # Forwarding ruleset + VNet links
└── README.md
```

## Key Differences

| Aspect              | Scenario A (VNet Links)                     | Scenario B (Forwarding Rulesets)                         |
|---------------------|---------------------------------------------|----------------------------------------------------------|
| Zone visibility     | Direct link to every VNet                   | Zone linked to hub only                                  |
| Spoke DNS config    | Default Azure DNS                           | Default Azure DNS                                        |
| Resolver required   | No (deployed for parity)                    | Yes (inbound + outbound endpoints)                       |
| Scaling model       | 1 VNet link per spoke per zone              | 1 ruleset VNet link per spoke (covers all rules)         |
| Centralised control | Must add VNet link per new spoke/zone combo | Add rules to ruleset; spoke links are zone-agnostic      |
| Cost                | Zone link = free; resolver = ~$0.42/hr each | Same resolver cost; ruleset = free; links = free         |

## Clean Up

```bash
az group delete --name rg-dns-vnetlinks --yes --no-wait
az group delete --name rg-dns-forwarding --yes --no-wait
```
