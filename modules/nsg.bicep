// Région Azure de la NSG
param location string

// Nom de la ressource NSG dans Azure
param nsgName string

// Tableau des règles de sécurité à créer dans la NSG
param securityRules array = []

// Création de la NSG Azure
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // Création dynamique des règles à partir du tableau securityRules
      for rule in securityRules: {
        name: rule.name
        properties: {
          priority: rule.priority
          direction: rule.direction
          access: rule.access
          protocol: rule.protocol
          sourcePortRange: rule.sourcePortRange
          destinationPortRange: rule.destinationPortRange
          sourceAddressPrefix: rule.sourceAddressPrefix
          destinationAddressPrefix: rule.destinationAddressPrefix
        }
      }
    ]
  }
}

// Retourne l'identifiant Azure de la NSG
output nsgId string = nsg.id

// Retourne le nom de la NSG
output nsgNameOut string = nsg.name
