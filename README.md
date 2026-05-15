# Azure Hub-and-Spoke Lab with Bicep — Foundation Phase

> This lab is designed as a learning resource to discover and practice Bicep by building an Azure Hub-and-Spoke network architecture. It is intended for self-taught architects, cloud engineers, and curious students who want to gain solid foundations in infrastructure as code with Bicep, starting from a modular, scalable, and educational base.

## Objective

This phase sets up the **network foundation** of a **Hub-and-Spoke** architecture in Azure using **Bicep**.

The goal is to build a foundation that is:
- **modular**
- **readable**
- **scalable**
- and **low cost**

before adding more advanced components in later phases.

---

## Foundation Principles

This foundation is designed to:

- prepare for future network and security components
- reserve the necessary subnets for the next steps
- implement Hub / Spoke segmentation
- apply an initial layer of network security
- remain within a **low cost** perimeter

### Resources intentionally not deployed at this stage
To keep costs low, this phase **does not yet deploy**:

- Azure Firewall
- VPN Gateway
- Application Gateway
- Virtual Machines
- Real Private Endpoints
- Public IP
- NAT Gateway
- Bastion

The subnets required for these components are already planned.

---

## What the Foundation Phase Covers

### Network
- 1 **Hub VNet**
- 1 **Public Spoke VNet**
- 1 **Private Spoke VNet**

### Subnets

#### Hub
- `GatewaySubnet`
- `AzureFirewallSubnet`
- `HubMgmtSubnet`

#### Public Spoke
- `AppGatewaySubnet`
- `WebSubnet`

#### Private Spoke
- `ServerSubnet`
- `PrivateEndpointSubnet`

### Security
- 1 **Network Security Group** for `WebSubnet`
- 1 **Network Security Group** for `ServerSubnet`

### Routing
- 1 **Route Table** for `WebSubnet`
- 1 **Route Table** for `ServerSubnet`

### Connectivity
- VNet peering **Hub -> Public Spoke**
- VNet peering **Public Spoke -> Hub**
- VNet peering **Hub -> Private Spoke**
- VNet peering **Private Spoke -> Hub**

---

## Logical Architecture

### Hub VNet
- Name: `vnet-hub-${environment}`
- CIDR: `10.0.0.0/16`

Subnets:
- `GatewaySubnet` → `10.0.1.0/24`
- `AzureFirewallSubnet` → `10.0.2.0/24`
- `HubMgmtSubnet` → `10.0.3.0/24`

---

### Public Spoke VNet
- Name: `vnet-spoke-public-${environment}`
- CIDR: `172.16.0.0/16`

Subnets:
- `AppGatewaySubnet` → `172.16.0.0/24`
- `WebSubnet` → `172.16.1.0/24`

Associations:
- `WebSubnet` is associated with NSG `nsg-web-${environment}`
- `WebSubnet` is associated with Route Table `rt-web-${environment}`

---

### Private Spoke VNet
- Name: `vnet-spoke-private-${environment}`
- CIDR: `192.168.0.0/16`

Subnets:
- `ServerSubnet` → `192.168.1.0/24`
- `PrivateEndpointSubnet` → `192.168.2.0/24`

Associations:
- `ServerSubnet` is associated with NSG `nsg-server-${environment}`
- `ServerSubnet` is associated with Route Table `rt-server-${environment}`

---

## Security Rules

### NSG `nsg-web-${environment}`
Applied to `WebSubnet`.

Rules:
- allow **TCP 80** from `AppGatewaySubnet` (`172.16.0.0/24`)
- allow **TCP 443** from `AppGatewaySubnet` (`172.16.0.0/24`)
- allow **TCP 22** from the future VPN pool `10.250.0.0/24`

---

### NSG `nsg-server-${environment}`
Applied to `ServerSubnet`.

Rules:
- allow **TCP 8080** from `WebSubnet` (`172.16.1.0/24`)
- allow **TCP 22** from the future VPN pool `10.250.0.0/24`

---

## Routing

### Route Table `rt-web-${environment}`
Associated with `WebSubnet`.

In this phase:
- it is created
- it is attached to the subnet
- it does not yet contain custom routes (`routes: []`)

---

### Route Table `rt-server-${environment}`
Associated with `ServerSubnet`.

In this phase:
- it is created
- it is attached to the subnet
- it does not yet contain custom routes (`routes: []`)

---

## Peerings

This foundation creates the following 4 peerings:

- `peer-hub-to-spoke-public`
- `peer-spoke-public-to-hub`
- `peer-hub-to-spoke-private`
- `peer-spoke-private-to-hub`

### Why 4 peerings?
An Azure peering is **unidirectional**.  
For bidirectional communication between two VNets, you must create peering in both directions.

### Parameters used
- `allowVirtualNetworkAccess = true`
- `allowForwardedTraffic = true`
- `useRemoteGateways = false`
- `allowGatewayTransit = false`

These parameters prepare for a more advanced architecture in the future, while keeping things simple in this phase.

---

## Project Structure

```text
.
├── main.foundation.bicep
├── README.md
├── parameters/
│   └── foundation.dev.bicepparam
└── modules/
    ├── vnet.bicep
    ├── nsg.bicep
    ├── routeTable.bicep
    └── peering.bicep
```

---

## Files

### `main.foundation.bicep`
Main deployment file for the foundation.

It:
- receives parameters
- calls modules
- creates VNets
- creates NSGs
- creates Route Tables
- attaches NSGs to the relevant subnets
- attaches Route Tables to the relevant subnets
- creates peerings
- exposes outputs for the next phases

---

### `modules/vnet.bicep`
VNet creation module.

Features:
- creates the VNet
- creates subnets
- optionally attaches an NSG via `networkSecurityGroupId`
- optionally attaches a Route Table via `routeTableId`

---

### `modules/nsg.bicep`
Network Security Group creation module.

Features:
- creates an NSG
- dynamically creates rules from a `securityRules` array

---

### `modules/routeTable.bicep`
Route Table creation module.

Features:
- creates a Route Table
- dynamically creates routes from a `routes` array
- supports `disableBgpRoutePropagation`

---

### `modules/peering.bicep`
VNet peering creation module.

Features:
- creates peering from a source VNet to a remote VNet
- configures connectivity options

---

## Parameters

In `main.foundation.bicep`:

```bicep
param location string

@allowed([
  'dev'
  'test'
  'prod'
])
param environment string
```

### `location`
Azure deployment region.

Example:
- `westeurope`

### `environment`
Target environment.

Allowed values:
- `dev`
- `test`
- `prod`

This parameter is used to:
- name resources
- distinguish environments

Examples:
- `vnet-hub-dev`
- `nsg-web-dev`
- `rt-server-dev`

---

## Exposed Outputs

The template exposes the following:

### VNets
- `hubVnetId`
- `spokePublicVnetId`
- `spokePrivateVnetId`

### NSG
- `webNsgId`
- `serverNsgId`

### Route Tables
- `webRouteTableId`
- `serverRouteTableId`

### Peerings
- `hubToSpokePublicPeeringId`
- `spokePublicToHubPeeringId`
- `hubToSpokePrivatePeeringId`
- `spokePrivateToHubPeeringId`

These outputs can be reused in later phases.

---

## Deployment

### 1. Create the Resource Group
```bash
az group create \
  --name rg-lab-hubspoke-foundation-dev \
  --location westeurope
```

### 2. Deploy the foundation
```bash
az deployment group create \
  --resource-group rg-lab-hubspoke-foundation-dev \
  --template-file main.foundation.bicep \
  --parameters @parameters/foundation.dev.bicepparam
```

---

## Cost and Low-Cost Philosophy

This phase is designed to remain **almost cost-free**.

### Choices made
- no compute
- no firewall
- no gateway
- no public IP
- no heavy managed service

### Note
- VNets, subnets, NSGs, and Route Tables have negligible cost in this context
- peerings may generate a cost if traffic flows, but in a foundation without active workloads this cost remains very low

---

## Bicep Concepts Practiced in this Phase

- `param`
- `@allowed`
- `module`
- `resource`
- `resource existing`
- `output`
- string interpolation
- object arrays
- `for` loops
- optional properties
- `contains()`
- `union()`
- ternary operator `? :`
- implicit dependencies between modules

---

## What this Foundation Does Not Yet Do

The foundation phase does not yet deploy:

- advanced custom routes
- Azure Firewall
- VPN Gateway
- Application Gateway
- Virtual Machines
- Real Private Endpoints
- Private DNS
- Storage Account
- Public IP
- NAT Gateway
- Bastion

---

## Next Steps

The next phases of the lab may introduce more functional resources as needed:

1. **Test VMs**
2. **Private Endpoint**
3. **VPN Gateway**
4. **Application Gateway**
5. **Azure Firewall**
6. **Advanced Routing**
7. **Enhanced Security**

---

## Summary

The foundation phase builds a Hub-and-Spoke Azure base with Bicep:

- 3 VNets
- 7 subnets
- 2 NSGs
- 2 Route Tables
- 4 peerings
- modular structure
- almost zero cost
- architecture ready for the next steps

It is a clean, readable, educational, and scalable base for the next phases of the lab.

---

## Governance Files

- `LICENSE`: MIT License
- `CONTRIBUTING.md`: Contribution Guide
- `CODE_OF_CONDUCT.md`: Code of Conduct
