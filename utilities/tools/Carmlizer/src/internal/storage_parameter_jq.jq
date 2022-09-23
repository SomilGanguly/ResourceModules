{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
            "name": .name,
            "location": .location,
		"tags": .tags,
		"systemAssignedIdentity": .systemAssignedIdentity,
		"storageAccountAccessTier": .accessTier,
		"allowBlobPublicAccess": .allowBlobPublicAccess,
		"publicNetworkAccess": .publicNetworkAccess,
            "storageAccountSku": .sku,
		"userAssignedIdentities": .userAssignedIdentities,
            "storageAccountKind": .kind,
            "minimumTlsVersion": .minimumTlsVersion,
		"networkAcls": .networkAcls,
		"supportsHttpsTrafficOnly": .supportsHttpsTrafficOnly,
		"requireInfrastructureEncryption": .requireInfrastructureEncryption,
		"cMKKeyName": .cMKKeyName,
		"cMKUserAssignedIdentityResourceId": .cMKUserAssignedIdentityResourceId,
		"cMKKeyVaultResourceId": .cMKKeyVaultResourceId,
		"enableHierarchicalNamespace": .isHnsEnabled,
		"blobServices": .blobServices,
		"fileServices": .fileServices,
		"queueServices": .queueServices,
		"tableServices": .tableServices
    }
}| .parameters |= if .userAssignedIdentities==null then del(.userAssignedIdentities) else . end | 
.parameters |= if .tags ==null then del(.tags) else . end |
.parameters |= if .systemAssignedIdentity ==null then del(.systemAssignedIdentity) else . end |
.parameters |= if .cMKKeyName ==null then del(.cMKKeyName) else . end |
.parameters |= if .cMKUserAssignedIdentityResourceId ==null then del(.cMKUserAssignedIdentityResourceId) else . end |
.parameters |= if .cMKKeyVaultResourceId ==null then del(.cMKKeyVaultResourceId) else . end |
.parameters |= if .isHnsEnabled ==null then del(.enableHierarchicalNamespace) else . end |
.parameters |= if .blobServices ==null then del(.blobServices) else . end |
.parameters |= if .fileServices ==null then del(.fileServices) else . end |
.parameters |= if .queueServices ==null then del(.queueServices) else . end |
.parameters |= if .tableServices ==null then del(.tableServices) else . end

