<#
    .SYNOPSIS
    Move resources to a different subscription or resource group.

    .ROLE
    1. The account moving the resources must have at least the following permissions:
    -   Microsoft.Resources/subscriptions/resourceGroups/moveResources/action on the source resource group.
    -   Microsoft.Resources/subscriptions/resourceGroups/write on the destination resource group.

    .DESCRIPTION
    Moves resources from one subscription to another or from one resource group to another in the same subscription. The subscriptions/resource groups need to be in the same tenant.

    .PARAMETER path
    Mandatory. Path of the json file which contains details of the move.

    .EXAMPLE
    .\moveResources -path 'src\resourceMove.json'

    File content of above file -

    {
        "resourcesToMove": [
            {
                "resourceID": "/subscriptions/xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx/resourceGroups/source-rg/providers/Microsoft.Network/networkSecurityGroups/cat115-default-nsg-eastus"
            }
        ],
        "sourceSubscriptionId": "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx",
        "targetSubscriptionId": "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx",
        "destinationRG": "destination-rg"
    }

    Move resources from "source-rg" resource group into "destination-rg" resource group in the same "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx" subscription.

    .EXAMPLE
    .\moveResources -path 'src\resourceMove.json'

    File content of above file -

    {
        "resourcesToMove": [
            {
                "resourceID": "/subscriptions/xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx/resourceGroups/source-rg/providers/Microsoft.Network/networkSecurityGroups/cat115-default-nsg-eastus"
            }
        ],
        "sourceSubscriptionId": "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx",
        "targetSubscriptionId": "yyyyyyy-yyyy-yyyy-yyyy-yyyyyyy",
        "destinationRG": "destination-rg"
    }

    Move resources from "source-rg" resource group into "destination-rg" resource group in the new "yyyyyyy-yyyy-yyyy-yyyy-yyyyyyy" subscription.

#>

function moveResources{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $path
    )
    
    $VerbosePreference= 'Continue'

    $resourceIdArray = (Get-Content $path -Raw| ConvertFrom-Json).resourcesToMove.resourceID
    Write-Verbose "Identified resource Id(s) from the array input:`n$($resourceIdArray)."
    $destinationRG= (Get-Content $path -Raw| ConvertFrom-Json).destinationRG
    Write-Verbose "Identified destination resource group: $($destinationRG)."
    $sourceSubscription= (Get-Content $path -Raw| ConvertFrom-Json).sourceSubscriptionId
    Write-Verbose "Identified source subscription: $($sourceSubscription)."
    $targetSubscription= (Get-Content $path -Raw| ConvertFrom-Json).targetSubscriptionId
    Write-Verbose "Identified destination subscription: $($targetSubscription)."

    if ((Get-AzSubscription -SubscriptionId $sourceSubscription).TenantId -eq (Get-AzSubscription -SubscriptionId $targetSubscription).TenantId)
    {
        Write-Verbose -Message "Source and target subscriptions are in the same tenant ID."
        foreach($resource in $resourceIdArray)
        {
            $sourceRG= $resource.Split("/")[4]
            if (($sourceSubscription -eq $targetSubscription) -and ($sourceRG -eq $destinationRG))
            {
                Write-Error "Source and destination resource groups were found to be same, this does not qualify as the case to run this script."
            }
            
            # Checking if target subscription is registered for the resource provider of the resource to be moved.
            Set-AzContext -Subscription $targetSubscription
            Write-Verbose -Message "Context set."
            $resourceProvider=$resource.Split("/")[6]
            $AvailabilityCheck = (Get-AzResourceProvider -ProviderNamespace $resourceProvider).RegistrationState
            Write-Verbose "Checking if the provider is registered or not."
            if($AvailabilityCheck -eq "NotRegistered")
            {
                Write-Verbose -Message "Registering service."
                Register-AzResourceProvider -ProviderNamespace $resourceProvider
            }
            Write-Verbose -Message "Invoking validation."
            $errorMsg= Invoke-AzResourceAction -Action validateMoveResources -ResourceId "/subscriptions/$sourceSubscription/resourceGroups/$sourceRG" -Parameters @{resources = @("$resource") ; targetResourceGroup = "/subscriptions/$targetSubscription/resourceGroups/$destinationRG"} -Confirm:$False -Force
            if ($errorMsg)
            {
                Write-Error "Validation failed, resource movement cannot be invoked."
            }
        }
        Write-Host  ("Moving resource $resource.")
        Move-AzResource -DestinationResourceGroupName $destinationRG -ResourceId $resourceIdArray -Confirm:$False -Force
    }
    else
    {
        Write-Host -Message "Subscription IDs are not in the same tenant."
    }
}