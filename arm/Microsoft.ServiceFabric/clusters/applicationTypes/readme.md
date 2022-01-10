# ServiceFabric Clusters ApplicationTypes `[Microsoft.ServiceFabric/clusters/applicationTypes]`

This module deploys ServiceFabric Clusters ApplicationTypes.
// TODO: Replace Resource and fill in description

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.ServiceFabric/clusters/applicationTypes` | 2021-06-01 |
| `Microsoft.ServiceFabric/clusters/applicationTypes/versions` | 2021-06-01 |

## Parameters

| Parameter Name | Type | Default Value | Possible Values | Description |
| :-- | :-- | :-- | :-- | :-- |
| `cuaId` | string |  |  | Optional. Customer Usage Attribution ID (GUID). This GUID must be previously registered |
| `location` | string | `[resourceGroup().location]` |  | Optional. Location for all resources. |
| `name` | string | `defaultApplicationType` |  | Optional. Application type name. |
| `properties` | object | `{object}` |  | Optional. The application type name properties. |
| `serviceFabricClusterName` | string |  |  | Required. Name of the Serivce Fabric cluster. |
| `tags` | object | `{object}` |  | Optional. Tags of the resource. |
| `versions` | _[versions](versions/readme.md)_ array | `[]` |  | Optional. Array of Versions to create. |

### Parameter Usage: `<ParameterPlaceholder>`

// TODO: Fill in Parameter usage

### Parameter Usage: `tags`

Tag names and tag values can be provided as needed. A tag can be left without a value.

```json
"tags": {
    "value": {
        "Environment": "Non-Prod",
        "Contact": "test.user@testcompany.com",
        "PurchaseOrder": "1234",
        "CostCenter": "7890",
        "ServiceName": "DeploymentValidation",
        "Role": "DeploymentValidation"
    }
}
```

## Outputs

| Output Name | Type | Description |
| :-- | :-- | :-- |
| `applicationTypeName` | string | The resource name of the Application type. |
| `applicationTypeResourceGroup` | string | The resource group of the Application type. |
| `applicationTypeResourceID` | string | The resource ID of the Application type. |

## Template references

- [Clusters/Applicationtypes](https://docs.microsoft.com/en-us/azure/templates/Microsoft.ServiceFabric/2021-06-01/clusters/applicationTypes)
- [Clusters/Applicationtypes/Versions](https://docs.microsoft.com/en-us/azure/templates/Microsoft.ServiceFabric/2021-06-01/clusters/applicationTypes/versions)