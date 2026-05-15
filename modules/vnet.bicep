// Région Azure dans laquelle le VNet sera créé
param location string

// Nom du VNet dans Azure
param vnetName string

// Tableau des plages d'adressage du VNet
param addressPrefixes array

// Tableau des subnets à créer dans le VNet
// Chaque objet subnet doit contenir au minimum :
// - name
// - addressPrefix
//
// Il peut aussi contenir optionnellement :
// - networkSecurityGroupId
// - routeTableId
param subnets array = []

// Création du VNet Azure
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      // Boucle sur chaque objet subnet fourni dans le tableau subnets
      for subnet in subnets: {
        name: subnet.name
        properties: union(
          // Propriétés minimales toujours présentes
          {
            addressPrefix: subnet.addressPrefix
          },

          // Ajoute la référence à la NSG si networkSecurityGroupId est fourni
          contains(subnet, 'networkSecurityGroupId')
            ? {
                networkSecurityGroup: {
                  id: subnet.networkSecurityGroupId
                }
              }
            : {},

          // Ajoute la référence à la route table si routeTableId est fourni
          contains(subnet, 'routeTableId')
            ? {
                routeTable: {
                  id: subnet.routeTableId
                }
              }
            : {}
        )
      }
    ]
  }
}

// Retourne l'identifiant Azure du VNet
output vnetId string = vnet.id

// Retourne le nom du VNet
output vnetNameOut string = vnet.name
