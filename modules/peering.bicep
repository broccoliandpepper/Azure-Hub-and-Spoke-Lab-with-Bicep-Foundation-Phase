// Nom du VNet source sur lequel on crée le peering
param sourceVnetName string

// ID du VNet distant (remote) vers lequel on établit le peering
param remoteVnetId string

// Nom du peering dans Azure
param peeringName string

// Autorise ou non l'accès au réseau distant
param allowVirtualNetworkAccess bool = true

// Autorise ou non le trafic transféré depuis le réseau distant
param allowForwardedTraffic bool = true

// Autorise ou non l'utilisation de la gateway distante
param useRemoteGateways bool = false

// Autorise ou non ce VNet à annoncer sa gateway au VNet distant
param allowGatewayTransit bool = false

// Référence à un VNet existant dans le même resource group
resource sourceVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: sourceVnetName
}

// Création du peering depuis le VNet source vers le VNet distant
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: peeringName
  parent: sourceVnet
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    useRemoteGateways: useRemoteGateways
    allowGatewayTransit: allowGatewayTransit
  }
}

// Retourne l'identifiant du peering créé
output peeringId string = peering.id

// Retourne le nom du peering créé
output peeringNameOut string = peering.name
