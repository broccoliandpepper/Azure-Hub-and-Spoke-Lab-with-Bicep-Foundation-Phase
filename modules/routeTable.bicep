// Région Azure dans laquelle la route table sera créée
param location string

// Nom de la route table dans Azure
param routeTableName string

// Tableau des routes personnalisées à ajouter à la route table
param routes array = []

// Désactive ou non la propagation des routes BGP
param disableBgpRoutePropagation bool = false

// Création de la route table Azure
resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [
      // Création dynamique des routes à partir du tableau routes
      for route in routes: {
        name: route.name
        properties: union(
          {
            addressPrefix: route.addressPrefix
            nextHopType: route.nextHopType
          },
          // Si nextHopIpAddress existe, on l'ajoute à la route
          contains(route, 'nextHopIpAddress')
            ? {
                nextHopIpAddress: route.nextHopIpAddress
              }
            : {}
        )
      }
    ]
  }
}

// Retourne l'identifiant Azure de la route table
output routeTableId string = routeTable.id

// Retourne le nom de la route table
output routeTableNameOut string = routeTable.name
