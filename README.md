# Lab Azure Hub-and-Spoke en Bicep — Phase Fondation

## Objectif

Cette phase met en place la **fondation réseau** d’une architecture **Hub-and-Spoke** dans Azure avec **Bicep**.

L’objectif est de construire un socle :
- **modulaire**
- **lisible**
- **évolutif**
- et **à coût quasi nul**

avant d’ajouter des composants plus avancés dans les phases suivantes.

---

## Principes de cette fondation

Cette fondation a été pensée pour :

- préparer les futurs composants réseau et sécurité
- réserver les subnets nécessaires à la suite
- mettre en place la segmentation Hub / Spokes
- appliquer une première couche de sécurité réseau
- rester dans un périmètre **low cost**

### Ressources volontairement non déployées à ce stade
Afin de limiter les coûts, cette phase **ne déploie pas encore** :

- Azure Firewall
- VPN Gateway
- Application Gateway
- Virtual Machines
- Private Endpoints réels
- Public IP
- NAT Gateway
- Bastion

Les subnets nécessaires à ces composants sont cependant déjà prévus.

---

## Ce que couvre la phase fondation

### Réseau
- 1 **Hub VNet**
- 1 **Spoke Public VNet**
- 1 **Spoke Private VNet**

### Subnets

#### Hub
- `GatewaySubnet`
- `AzureFirewallSubnet`
- `HubMgmtSubnet`

#### Spoke Public
- `AppGatewaySubnet`
- `WebSubnet`

#### Spoke Private
- `ServerSubnet`
- `PrivateEndpointSubnet`

### Sécurité
- 1 **Network Security Group** pour `WebSubnet`
- 1 **Network Security Group** pour `ServerSubnet`

### Routage
- 1 **Route Table** pour `WebSubnet`
- 1 **Route Table** pour `ServerSubnet`

### Connectivité
- VNet peering **Hub -> Spoke Public**
- VNet peering **Spoke Public -> Hub**
- VNet peering **Hub -> Spoke Private**
- VNet peering **Spoke Private -> Hub**

---

## Architecture logique

### Hub VNet
- Nom : `vnet-hub-${environment}`
- CIDR : `10.0.0.0/16`

Subnets :
- `GatewaySubnet` → `10.0.1.0/24`
- `AzureFirewallSubnet` → `10.0.2.0/24`
- `HubMgmtSubnet` → `10.0.3.0/24`

---

### Spoke Public VNet
- Nom : `vnet-spoke-public-${environment}`
- CIDR : `172.16.0.0/16`

Subnets :
- `AppGatewaySubnet` → `172.16.0.0/24`
- `WebSubnet` → `172.16.1.0/24`

Associations :
- `WebSubnet` reçoit la NSG `nsg-web-${environment}`
- `WebSubnet` reçoit la Route Table `rt-web-${environment}`

---

### Spoke Private VNet
- Nom : `vnet-spoke-private-${environment}`
- CIDR : `192.168.0.0/16`

Subnets :
- `ServerSubnet` → `192.168.1.0/24`
- `PrivateEndpointSubnet` → `192.168.2.0/24`

Associations :
- `ServerSubnet` reçoit la NSG `nsg-server-${environment}`
- `ServerSubnet` reçoit la Route Table `rt-server-${environment}`

---

## Règles de sécurité

### NSG `nsg-web-${environment}`
Appliquée à `WebSubnet`.

Règles :
- autorise **TCP 80** depuis `AppGatewaySubnet` (`172.16.0.0/24`)
- autorise **TCP 443** depuis `AppGatewaySubnet` (`172.16.0.0/24`)
- autorise **TCP 22** depuis le futur pool VPN `10.250.0.0/24`

---

### NSG `nsg-server-${environment}`
Appliquée à `ServerSubnet`.

Règles :
- autorise **TCP 8080** depuis `WebSubnet` (`172.16.1.0/24`)
- autorise **TCP 22** depuis le futur pool VPN `10.250.0.0/24`

---

## Routage

### Route Table `rt-web-${environment}`
Associée à `WebSubnet`.

Dans cette phase :
- elle est créée
- elle est attachée au subnet
- elle ne contient pas encore de routes personnalisées (`routes: []`)

---

### Route Table `rt-server-${environment}`
Associée à `ServerSubnet`.

Dans cette phase :
- elle est créée
- elle est attachée au subnet
- elle ne contient pas encore de routes personnalisées (`routes: []`)

---

## Peerings

Cette fondation crée les 4 peerings suivants :

- `peer-hub-to-spoke-public`
- `peer-spoke-public-to-hub`
- `peer-hub-to-spoke-private`
- `peer-spoke-private-to-hub`

### Pourquoi 4 peerings ?
Un peering Azure est **unidirectionnel**.  
Pour une communication bidirectionnelle entre deux VNets, il faut créer le peering dans les deux sens.

### Paramètres utilisés
- `allowVirtualNetworkAccess = true`
- `allowForwardedTraffic = true`
- `useRemoteGateways = false`
- `allowGatewayTransit = false`

Ces paramètres préparent une architecture plus avancée pour la suite, tout en restant simples dans cette phase.

---

## Structure du projet

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

## Fichiers

### `main.foundation.bicep`
Fichier principal de déploiement de la fondation.

Il :
- reçoit les paramètres
- appelle les modules
- crée les VNets
- crée les NSG
- crée les Route Tables
- attache les NSG aux subnets concernés
- attache les Route Tables aux subnets concernés
- crée les peerings
- expose les outputs nécessaires aux phases suivantes

---

### `modules/vnet.bicep`
Module de création de VNet.

Fonctionnalités :
- création du VNet
- création des subnets
- attachement optionnel d’une NSG via `networkSecurityGroupId`
- attachement optionnel d’une Route Table via `routeTableId`

---

### `modules/nsg.bicep`
Module de création de Network Security Group.

Fonctionnalités :
- création d’une NSG
- création dynamique des règles à partir d’un tableau `securityRules`

---

### `modules/routeTable.bicep`
Module de création de Route Table.

Fonctionnalités :
- création d’une Route Table
- création dynamique des routes à partir d’un tableau `routes`
- prise en charge de `disableBgpRoutePropagation`

---

### `modules/peering.bicep`
Module de création de VNet peering.

Fonctionnalités :
- création du peering depuis un VNet source vers un VNet distant
- configuration des options de connectivité

---

## Paramètres

Dans `main.foundation.bicep` :

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
Région Azure du déploiement.

Exemple :
- `westeurope`

### `environment`
Environnement cible.

Valeurs autorisées :
- `dev`
- `test`
- `prod`

Ce paramètre est utilisé pour :
- nommer les ressources
- distinguer les environnements

Exemples :
- `vnet-hub-dev`
- `nsg-web-dev`
- `rt-server-dev`

---

## Outputs exposés

Le template expose notamment :

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

Ces outputs seront réutilisables dans les phases suivantes.

---

## Déploiement

### 1. Créer le Resource Group
```bash
az group create \
  --name rg-lab-hubspoke-foundation-dev \
  --location westeurope
```

### 2. Déployer la fondation
```bash
az deployment group create \
  --resource-group rg-lab-hubspoke-foundation-dev \
  --template-file main.foundation.bicep \
  --parameters @parameters/foundation.dev.bicepparam
```

---

## Coût et philosophie low cost

Cette phase a été conçue pour rester dans un périmètre **quasi sans coût**.

### Choix retenus
- pas de compute
- pas de firewall
- pas de gateway
- pas d’IP publique
- pas de service managé lourd

### À noter
- les VNets, subnets, NSG et Route Tables ont un coût négligeable dans ce contexte
- les peerings peuvent générer un coût si du trafic circule, mais dans une fondation sans workload actif ce coût reste très faible

---

## Concepts Bicep pratiqués dans cette phase

- `param`
- `@allowed`
- `module`
- `resource`
- `resource existing`
- `output`
- interpolation de chaînes
- tableaux d’objets
- boucles `for`
- propriétés optionnelles
- `contains()`
- `union()`
- opérateur ternaire `? :`
- dépendances implicites entre modules

---

## Ce que cette fondation ne fait pas encore

La phase fondation ne déploie pas encore :

- routes personnalisées avancées
- Azure Firewall
- VPN Gateway
- Application Gateway
- Virtual Machines
- Private Endpoints réels
- Private DNS
- Storage Account
- Public IP
- NAT Gateway
- Bastion

---

## Prochaine étape

La suite du lab pourra introduire des ressources plus fonctionnelles, selon le besoin :

1. **VMs de test**
2. **Private Endpoint**
3. **VPN Gateway**
4. **Application Gateway**
5. **Azure Firewall**
6. **Routage avancé**
7. **Sécurité renforcée**

---

## Résumé

La phase fondation construit un socle Hub-and-Spoke Azure en Bicep :

- 3 VNets
- 7 subnets
- 2 NSG
- 2 Route Tables
- 4 peerings
- structure modulaire
- coût quasi nul
- architecture prête pour la suite

C’est une base propre, lisible, pédagogique et évolutive pour les prochaines phases du lab.