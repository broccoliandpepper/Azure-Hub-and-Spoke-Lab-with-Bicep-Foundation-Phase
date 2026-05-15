// Paramètre qui définit la région Azure du déploiement
param location string

// Restreint les valeurs possibles pour l'environnement de déploiement
@allowed([
  'dev'
  'test'
  'prod'
])
// Paramètre qui spécifie l'environnement de déploiement, utilisé notamment pour nommer les ressources
param environment string

// Appel du module réutilisable de création de VNet pour le hub
// hubVnet : identifiant local du module dans le code Bicep
module hubVnet './modules/vnet.bicep' = {
  // deployHubVnet : nom du déploiement du module dans Azure Resource Manager
  name: 'deployHubVnet'
  params: {
    location: location
    // vnet-hub-${environment} : nom de la ressource Azure créée pour le VNet du hub
    vnetName: 'vnet-hub-${environment}'
    // addressPrefixes : espace d'adressage IP du VNet du hub
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        // GatewaySubnet : subnet réservé à la VPN Gateway Azure
        name: 'GatewaySubnet'
        addressPrefix: '10.0.1.0/24'
      }
      {
        // AzureFirewallSubnet : subnet réservé à Azure Firewall
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.2.0/24'
      }
      {
        // HubMgmtSubnet : subnet de gestion/administration du hub
        name: 'HubMgmtSubnet'
        addressPrefix: '10.0.3.0/24'
      }
    ]
  }
}

// Création de la NSG du subnet web
module webNsg './modules/nsg.bicep' = {
  name: 'deployWebNsg'
  params: {
    location: location
    nsgName: 'nsg-web-${environment}'
    securityRules: [
      {
        name: 'Allow-HTTP-From-AppGateway'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: '172.16.0.0/24'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-HTTPS-From-AppGateway'
        priority: 110
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '172.16.0.0/24'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-SSH-From-VPN'
        priority: 120
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '10.250.0.0/24'
        destinationAddressPrefix: '*'
      }
    ]
  }
}

// Création de la route table du subnet web
// Cette route table sera destinée à être associée au WebSubnet
module webRouteTable './modules/routeTable.bicep' = {
  name: 'deployWebRouteTable'
  params: {
    location: location
    routeTableName: 'rt-web-${environment}'
    // Aucune route personnalisée pour le moment
    routes: []
    // La propagation BGP reste autorisée par défaut
    disableBgpRoutePropagation: false
  }
}

// Appel du module réutilisable de création de VNet pour le spoke public
module spokePublicVnet './modules/vnet.bicep' = {
  name: 'deploySpokePublicVnet'
  params: {
    location: location
    vnetName: 'vnet-spoke-public-${environment}'
    addressPrefixes: [
      '172.16.0.0/16'
    ]
    subnets: [
      {
        // AppGatewaySubnet : subnet destiné à héberger Application Gateway
        name: 'AppGatewaySubnet'
        addressPrefix: '172.16.0.0/24'
      }
      {
        // WebSubnet : subnet destiné aux ressources web du spoke public
        // La NSG web est attachée à ce subnet
        name: 'WebSubnet'
        addressPrefix: '172.16.1.0/24'
        networkSecurityGroupId: webNsg.outputs.nsgId
        routeTableId: webRouteTable.outputs.routeTableId
      }
    ]
  }
}

// Création de la NSG du subnet serveur
module serverNsg './modules/nsg.bicep' = {
  name: 'deployServerNsg'
  params: {
    location: location
    nsgName: 'nsg-server-${environment}'
    securityRules: [
      {
        name: 'Allow-SSH-From-VPN'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: '10.250.0.0/24'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-App-Traffic-From-WebSubnet'
        priority: 110
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '8080'
        sourceAddressPrefix: '172.16.1.0/24'
        destinationAddressPrefix: '*'
      }
    ]
  }
}

// Création de la route table du subnet serveur
// Cette route table sera destinée à être associée au ServerSubnet
module serverRouteTable './modules/routeTable.bicep' = {
  name: 'deployServerRouteTable'
  params: {
    location: location
    routeTableName: 'rt-server-${environment}'
    // Aucune route personnalisée pour le moment
    routes: []
    // La propagation BGP reste autorisée par défaut
    disableBgpRoutePropagation: false
  }
}

// Appel du module réutilisable de création de VNet pour le spoke privé
module spokePrivateVnet './modules/vnet.bicep' = {
  name: 'deploySpokePrivateVnet'
  params: {
    location: location
    vnetName: 'vnet-spoke-private-${environment}'
    addressPrefixes: [
      '192.168.0.0/16'
    ]
    subnets: [
      {
        // ServerSubnet : subnet destiné aux serveurs internes du spoke privé
        // La NSG server est attachée à ce subnet
        name: 'ServerSubnet'
        addressPrefix: '192.168.1.0/24'
        networkSecurityGroupId: serverNsg.outputs.nsgId
        routeTableId: serverRouteTable.outputs.routeTableId
      }
      {
        // PrivateEndpointSubnet : subnet destiné aux Private Endpoints
        name: 'PrivateEndpointSubnet'
        addressPrefix: '192.168.2.0/24'
      }
    ]
  }
}

// Peering du hub vers le spoke public
module hubToSpokePublicPeering './modules/peering.bicep' = {
  name: 'deployHubToSpokePublicPeering'
  params: {
    sourceVnetName: 'vnet-hub-${environment}'
    remoteVnetId: spokePublicVnet.outputs.vnetId
    peeringName: 'peer-hub-to-spoke-public'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

// Peering du spoke public vers le hub
module spokePublicToHubPeering './modules/peering.bicep' = {
  name: 'deploySpokePublicToHubPeering'
  params: {
    sourceVnetName: 'vnet-spoke-public-${environment}'
    remoteVnetId: hubVnet.outputs.vnetId
    peeringName: 'peer-spoke-public-to-hub'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

// Peering du hub vers le spoke privé
module hubToSpokePrivatePeering './modules/peering.bicep' = {
  name: 'deployHubToSpokePrivatePeering'
  params: {
    sourceVnetName: 'vnet-hub-${environment}'
    remoteVnetId: spokePrivateVnet.outputs.vnetId
    peeringName: 'peer-hub-to-spoke-private'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

// Peering du spoke privé vers le hub
module spokePrivateToHubPeering './modules/peering.bicep' = {
  name: 'deploySpokePrivateToHubPeering'
  params: {
    sourceVnetName: 'vnet-spoke-private-${environment}'
    remoteVnetId: hubVnet.outputs.vnetId
    peeringName: 'peer-spoke-private-to-hub'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

// Outputs des identifiants des VNets pour les modules suivants
output hubVnetId string = hubVnet.outputs.vnetId
output spokePublicVnetId string = spokePublicVnet.outputs.vnetId
output spokePrivateVnetId string = spokePrivateVnet.outputs.vnetId

// Outputs des identifiants des NSG pour réutilisation éventuelle
output webNsgId string = webNsg.outputs.nsgId
output serverNsgId string = serverNsg.outputs.nsgId

// Outputs des identifiants des route tables pour réutilisation éventuelle
output webRouteTableId string = webRouteTable.outputs.routeTableId
output serverRouteTableId string = serverRouteTable.outputs.routeTableId

// Outputs des identifiants des peerings
output hubToSpokePublicPeeringId string = hubToSpokePublicPeering.outputs.peeringId
output spokePublicToHubPeeringId string = spokePublicToHubPeering.outputs.peeringId
output hubToSpokePrivatePeeringId string = hubToSpokePrivatePeering.outputs.peeringId
output spokePrivateToHubPeeringId string = spokePrivateToHubPeering.outputs.peeringId
