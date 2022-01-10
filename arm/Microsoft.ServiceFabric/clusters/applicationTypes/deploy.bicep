@description('Required. Name of the Serivce Fabric cluster.')
param serviceFabricClusterName string = ''

@description('Optional. Application type name.')
param name string = 'defaultApplicationType'

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Customer Usage Attribution ID (GUID). This GUID must be previously registered')
param cuaId string = ''

module pid_cuaId '.bicep/nested_cuaId.bicep' = if (!empty(cuaId)) {
  name: 'pid-${cuaId}'
  params: {}
}

resource serviceFabricCluster 'Microsoft.ServiceFabric/clusters@2021-06-01' existing = {
  name: serviceFabricClusterName
}

resource applicationTypes 'Microsoft.ServiceFabric/clusters/applicationTypes@2021-06-01' = {
  name: name
  parent: serviceFabricCluster
  tags: tags
}

@description('The resource name of the Application type.')
output applicationTypeName string = applicationTypes.name

@description('The resource group of the Application type.')
output applicationTypeResourceGroup string = resourceGroup().name

@description('The resource ID of the Application type.')
output applicationTypeResourceID string = applicationTypes.id
